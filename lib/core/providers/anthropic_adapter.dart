import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/chat_models.dart';
import '../models/provider_models.dart';
import 'provider_adapter.dart';
import 'sse.dart';
import 'util.dart';

/// Talks to any Anthropic-compatible endpoint: the Messages API, and proxies
/// that mirror it. Tool calls are mapped onto content blocks, and tool results
/// are folded into a single user turn so the conversation always alternates.
class AnthropicCompatibleAdapter extends ProviderAdapter {
  const AnthropicCompatibleAdapter(super.dio);

  @override
  Stream<ChatStreamDelta> chatStream({
    required ProviderConfig provider,
    required String? apiKey,
    required ChatRequest request,
  }) async* {
    final url = joinEndpoint(provider.baseUrl, '/messages');
    final system = request.messages
        .where((m) => m.role == ChatRole.system)
 .map((m) => m.text)
        .join('\n\n');
    final turns =
        request.messages.where((m) => m.role != ChatRole.system).toList();

    final body = <String, dynamic>{
      'model': request.model,
      'max_tokens': request.maxTokens,
      'stream': true,
      if (system.isNotEmpty) 'system': system,
      'messages': _mergeAdjacent(_encodeTurns(turns)),
      if (request.tools.isNotEmpty)
        'tools': [
          for (final t in request.tools)
            {
              'name': t.name,
              'description': t.description,
              'input_schema': t.inputSchema,
            },
        ],
      if (request.temperature != null) 'temperature': request.temperature,
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
            'anthropic-version': '2023-06-01',
            if (apiKey != null && apiKey.isNotEmpty) 'x-api-key': apiKey,
          },
        ),
      );
    } on DioException catch (e) {
      yield ChatStreamDelta(done: true, error: _describe(e));
      return;
    }

    final blocks = <int, _Block>{};

    await for (final frame in sseFrames(response.data!.stream)) {
      final json = tryParseJsonObject(frame.data);
      if (json == null) continue;
      final type = frame.event ?? (json['type'] as String?);
      switch (type) {
        case 'content_block_start':
          final index = (json['index'] as num?)?.toInt();
          final block = json['content_block'] as Map<String, dynamic>?;
          if (index != null && block != null) {
            blocks[index] = _Block(
              type: (block['type'] as String?) ?? 'text',
              id: block['id'] as String?,
              name: block['name'] as String?,
            );
          }
          break;
        case 'content_block_delta':
          final index = (json['index'] as num?)?.toInt();
          final delta = json['delta'] as Map<String, dynamic>?;
          if (index == null || delta == null) break;
          final block = blocks[index];
          if (block == null) break;
          final dtype = delta['type'] as String?;
          if (dtype == 'text_delta') {
            final t = (delta['text'] as String?) ?? '';
            if (t.isNotEmpty) {
              block.text.write(t);
              yield ChatStreamDelta(text: t);
            }
          } else if (dtype == 'input_json_delta') {
            final pj = (delta['partial_json'] as String?) ?? '';
            if (pj.isNotEmpty) block.json.write(pj);
          } else if (dtype == 'thinking_delta') {
            final th = (delta['thinking'] as String?) ?? '';
            if (th.isNotEmpty) yield ChatStreamDelta(reasoning: th);
          }
          break;
        case 'error':
          final err = json['error'] as Map<String, dynamic>?;
          final msg = (err?['message'] as String?) ?? 'Provider error';
          yield ChatStreamDelta(done: true, error: msg);
          return;
        default:
          break; // message_start, message_delta, message_stop, ping
      }
    }

    final keys = blocks.keys.toList()..sort();
    final toolCalls = <ToolCall>[];
    for (final k in keys) {
      final b = blocks[k]!;
      if (b.type != 'tool_use') continue;
      Map<String, dynamic> input = const <String, dynamic>{};
      final raw = b.json.toString().trim();
      if (raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) input = decoded;
        } catch (_) {
          input = {'_raw': raw};
        }
      }
      toolCalls.add(ToolCall(
        id: b.id ?? 'call_$k',
        name: b.name ?? '',
        args: input,
      ));
    }

    yield ChatStreamDelta(
        toolCalls: toolCalls.isEmpty ? null : toolCalls, done: true);
  }

  static List<Map<String, dynamic>> _encodeTurns(List<ChatMessage> turns) {
    final out = <Map<String, dynamic>>[];
    var i = 0;
    while (i < turns.length) {
      final m = turns[i];
      if (m.role == ChatRole.tool) {
        // Consecutive tool reports must share one user turn.
        final group = <ChatMessage>[];
        while (i < turns.length && turns[i].role == ChatRole.tool) {
          group.add(turns[i]);
          i++;
        }
        out.add({
          'role': 'user',
          'content': [
            for (final g in group)
              for (final r in g.toolResults)
                {
                  'type': 'tool_result',
                  'tool_use_id': r.toolCallId,
                  'content': r.content,
                  if (r.isError) 'is_error': true,
                },
          ],
        });
      } else if (m.role == ChatRole.assistant) {
        out.add({
          'role': 'assistant',
          'content': [
            if (m.text.isNotEmpty) {'type': 'text', 'text': m.text},
            for (final tc in m.toolCalls)
              {
                'type': 'tool_use',
                'id': tc.id,
                'name': tc.name,
                'input': tc.args,
              },
          ],
        });
        i++;
      } else {
        out.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': m.text},
          ],
        });
        i++;
      }
    }
    return out;
  }

  /// Anthropic rejects conversations that do not strictly alternate. Two
  /// user turns in a row can happen when a message lands between the last
  /// reply and the next send, so they are merged here.
  static List<Map<String, dynamic>> _mergeAdjacent(
      List<Map<String, dynamic>> turns) {
    final out = <Map<String, dynamic>>[];
    for (final t in turns) {
      if (out.isNotEmpty &&
          out.last['role'] == 'user' &&
          t['role'] == 'user') {
        (out.last['content'] as List).addAll(t['content'] as List);
      } else {
        out.add(Map<String, dynamic>.from(t));
      }
    }
    return out;
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

class _Block {
  final String type;
  final String? id;
  final String? name;
  final StringBuffer text = StringBuffer();
  final StringBuffer json = StringBuffer();

  _Block({required this.type, this.id, this.name});
}
