import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilqeyte_mobile/core/models/chat_models.dart';
import 'package:ilqeyte_mobile/core/models/provider_models.dart';
import 'package:ilqeyte_mobile/core/providers/openai_adapter.dart';

import '../helpers/fake_http.dart';

ProviderConfig _provider() => ProviderConfig(
      id: 'p',
      name: 'test',
      kind: ProviderKind.agent,
      protocol: LlmProtocol.openaiCompatible,
      baseUrl: 'https://example.com/v1',
      createdAt: DateTime.now(),
    );

const ChatRequest _request = ChatRequest(model: 'gpt-4o-mini', messages: []);

String _frame(Map<String, dynamic> json) => 'data: ${jsonEncode(json)}\n\n';

void main() {
  test('streams text deltas in order', () async {
    final dio = Dio()
      ..httpClientAdapter = FakeHttpAdapter((_) => sseBody(
            '${_frame({
              'choices': [
                {'delta': {'content': 'Hello'}}
              ]
            })}'
            '${_frame({
              'choices': [
                {'delta': {'content': ', world'}}
              ]
            })}'
            'data: [DONE]\n\n',
          ));

    final deltas = await OpenAiCompatibleAdapter(dio)
        .chatStream(provider: _provider(), apiKey: 'key', request: _request)
        .toList();

    expect(deltas.map((d) => d.text ?? '').join(), 'Hello, world');
    expect(deltas.last.done, isTrue);
    expect(deltas.last.toolCalls ?? const [], isEmpty);
  });

  test('reassembles a tool call streamed across argument chunks', () async {
    final dio = Dio()
      ..httpClientAdapter = FakeHttpAdapter((_) => sseBody(
            '${_frame({
              'choices': [
                {
                  'delta': {
                    'tool_calls': [
                      {
                        'index': 0,
                        'id': 'call_1',
                        'function': {
                          'name': 'write_file',
                          'arguments': '{"path":',
                        },
                      }
                    ]
                  }
                }
              ]
            })}'
            '${_frame({
              'choices': [
                {
                  'delta': {
                    'tool_calls': [
                      {
                        'index': 0,
                        'function': {'arguments': '"notes.txt","content":"hi"}'},
                      }
                    ]
                  }
                }
              ]
            })}'
            'data: [DONE]\n\n',
          ));

    final deltas = await OpenAiCompatibleAdapter(dio)
        .chatStream(provider: _provider(), apiKey: 'key', request: _request)
        .toList();

    final calls = deltas.last.toolCalls;
    expect(calls, isNotNull);
    expect(calls!.single.id, 'call_1');
    expect(calls.single.name, 'write_file');
    expect(calls.single.args, {'path': 'notes.txt', 'content': 'hi'});
    expect(deltas.last.done, isTrue);
  });

  test('maps reasoning_content onto a reasoning delta', () async {
    final dio = Dio()
      ..httpClientAdapter = FakeHttpAdapter(
          (_) => sseBody(_frame({
                'choices': [
                  {'delta': {'reasoning_content': 'thinking hard'}}
                ]
              })));

    final deltas = await OpenAiCompatibleAdapter(dio)
        .chatStream(provider: _provider(), apiKey: 'key', request: _request)
        .toList();

    expect(deltas.any((d) => d.reasoning == 'thinking hard'), isTrue);
  });

  test('surfaces a provider error as a terminal error delta', () async {
    final dio = Dio()..httpClientAdapter = ErrorHttpAdapter();

    final deltas = await OpenAiCompatibleAdapter(dio)
        .chatStream(provider: _provider(), apiKey: 'bad', request: _request)
        .toList();

    expect(deltas, hasLength(1));
    expect(deltas.single.error, 'Invalid API key');
    expect(deltas.single.done, isTrue);
  });
}
