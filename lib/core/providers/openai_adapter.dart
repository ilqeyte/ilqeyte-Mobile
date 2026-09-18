import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/chat_models.dart';
import '../models/provider_models.dart';
import 'provider_adapter.dart';
import 'sse.dart';
import 'util.dart';

/// Talks to any OpenAI-compatible endpoint: OpenAI itself, OpenRouter, Groq,
/// Together, DeepSeek, llama.cpp, vLLM, and friends.
class OpenAiCompatibleAdapter extends ProviderAdapter {
  const OpenAiCompatibleAdapter(super.dio);

  @override
  Stream<ChatStreamDelta> chatStream({
    required ProviderConfig provider,
    required String? apiKey,
    required ChatRequest request,
  }) async* {
    final url = joinEndpoint(provider.baseUrl, '/chat/completions');
    final body = <String, dynamic>{
      'model': request.model,
      'messages': request.messages.expand(_encodeMessage).toList(),
      'stream': true,
      'max_tokens': request.maxTokens,
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.tools.isNotEmpty)
        'tools': request.tools.map(_encodeTool).toList(),
    };

    final Response<ResponseBody> response;
    try {
      response = await dio.post<ResponseBody>(
        url,
        data: jsonEncode(body),
        options: Options(
          responseType: ResponseType.stream,
          headers: <String, dynamic>{
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
            if (apiKey != null && apiKey.isNotEmpty)
              'Authorization': 'Bearer $apiKey',
          },
        ),
      );
    } on DioException catch (e) {
      yield ChatStreamDelta(done: true, error: _describe(e));
      return;
    }

    final toolAcc = <int, _ToolAcc>{};

    await for (final frame in sseFrames(response.data!.stream)) {
      if (frame.data == '[DONE]') break;
      final json = tryParseJsonObject(frame.data);
      if (json == null) continue;

      final choices = field<List>(json, 'choices');
      if (choices == null || choices.isEmpty) continue;
      final choice = choices[0];
      if (choice is! Map<String, dynamic>) continue;

      final delta = (choice['delta'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};

      final content = field<String>(delta, 'content');
      if (content != null && content.isNotEmpty) {
        yield ChatStreamDelta(text: content);
      }

      // Some OpenAI-compatible providers stream reasoning on its own key.
      final reason = field<String>(delta, 'reasoning_content') ??
          field<String>(delta, 'reasoning');
      if (reason != null && reason.isNotEmpty) {
        yield ChatStreamDelta(reasoning: reason);
      }

      final toolCalls = field<List>(delta, 'tool_calls');
      if (toolCalls != null) {
        for (final raw in toolCalls) {
          if (raw is! Map) continue;
          final tc = raw.cast<String, dynamic>();
          final index = (tc['index'] as num?)?.toInt() ?? 0;
          final acc = toolAcc.putIfAbsent(index, _ToolAcc.new);
          final fn = (tc['function'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
          final id = field<String>(tc, 'id') ?? field<String>(fn, 'id');
          if (id != null) acc.id = id;
          final name = field<String>(fn, 'name');
          if (name != null) acc.name = name;
          final argsChunk = field<String>(fn, 'arguments');
          if (argsChunk != null) acc.args.write(argsChunk);
        }
      }

      if (field<String>(choice, 'finish_reason') != null) break;
    }

    final calls = _assemble(toolAcc);
    yield ChatStreamDelta(toolCalls: calls.isEmpty ? null : calls, done: true);
  }

  @override
  Future<List<String>> listModels({
    required ProviderConfig provider,
    required String? apiKey,
  }) async {
    final url = joinEndpoint(provider.baseUrl, '/models');
    try {
      final res = await dio.get<dynamic>(
        url,
        options: Options(
          headers: <String, dynamic>{
            if (apiKey != null && apiKey.isNotEmpty)
              'Authorization': 'Bearer $apiKey',
          },
        ),
      );
      final data = res.data;
      if (data is Map<String, dynamic> && data['data'] is List) {
        final out = <String>{};
        for (final e in data['data'] as List) {
          if (e is Map<String, dynamic> && e['id'] is String) {
            out.add(e['id'] as String);
          }
        }
        final sorted = out.toList()..sort();
        return sorted;
      }
    } catch (_) {
      // Best effort — the settings UI tolerates an empty list.
    }
    return const [];
  }

  static Iterable<Map<String, dynamic>> _encodeMessage(ChatMessage m) {
    switch (m.role) {
      case ChatRole.system:
      case ChatRole.user:
        return [
          {'role': m.role.name, 'content': m.text},
        ];
      case ChatRole.assistant:
        return [
          {
            'role': 'assistant',
            if (m.text.isNotEmpty) 'content': m.text,
            if (m.toolCalls.isNotEmpty)
              'tool_calls': [
                for (final tc in m.toolCalls)
                  {
                    'id': tc.id,
                    'type': 'function',
                    'function': {
                      'name': tc.name,
                      'arguments': jsonEncode(tc.args),
                    },
                  },
              ],
          },
        ];
      case ChatRole.tool:
        return [
          for (final r in m.toolResults)
            {
              'role': 'tool',
              'tool_call_id': r.toolCallId,
              'content': r.content,
            },
        ];
    }
  }

  static Map<String, dynamic> _encodeTool(ToolSpec t) => {
        'type': 'function',
        'function': {
          'name': t.name,
          'description': t.description,
          'parameters': t.inputSchema,
        },
      };

  static List<ToolCall> _assemble(Map<int, _ToolAcc> acc) {
    final keys = acc.keys.toList()..sort();
    return [for (final k in keys) acc[k]!.toToolCall()];
  }

  static String _describe(DioException e) {
    final data = e.response?.data;
    String? message;
    if (data is Map<String, dynamic>) {
      final err = data['error'];
      if (err is Map<String, dynamic>) {
        message = (err['message'] as String?) ?? (err['type'] as String?);
      } else if (err is String) {
        message = err;
      }
    }
    return message ?? e.message ?? 'Request failed (${e.type.name}).';
  }
}

class _ToolAcc {
  String id = '';
  String name = '';
  final StringBuffer args = StringBuffer();

  ToolCall toToolCall() {
    final raw = args.toString().trim();
    Map<String, dynamic> parsed = const <String, dynamic>{};
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) parsed = decoded;
      } catch (_) {
        parsed = {'_raw': raw};
      }
    }
    return ToolCall(
      id: id.isEmpty ? 'call_${DateTime.now().millisecondsSinceEpoch}' : id,
      name: name,
      args: parsed,
    );
  }
}
