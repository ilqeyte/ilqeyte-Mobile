import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilqeyte_mobile/core/models/chat_models.dart';
import 'package:ilqeyte_mobile/core/models/provider_models.dart';
import 'package:ilqeyte_mobile/core/providers/anthropic_adapter.dart';

import '../helpers/fake_http.dart';

ProviderConfig _provider() => ProviderConfig(
      id: 'p',
      name: 'test',
      kind: ProviderKind.agent,
      protocol: LlmProtocol.anthropic,
      baseUrl: 'https://example.com',
      createdAt: DateTime.now(),
    );

const ChatRequest _request = ChatRequest(model: 'claude-3-5-sonnet', messages: []);

String _event(String type, Map<String, dynamic> json) =>
    'event: $type\ndata: ${jsonEncode(json)}\n\n';

void main() {
  test('streams text from a content block', () async {
    final dio = Dio()
      ..httpClientAdapter = FakeHttpAdapter((_) => sseBody(
            '${_event('content_block_start', {
              'type': 'content_block_start',
              'index': 0,
              'content_block': {'type': 'text', 'text': ''},
            })}'
            '${_event('content_block_delta', {
              'type': 'content_block_delta',
              'index': 0,
              'delta': {'type': 'text_delta', 'text': 'Hello'},
            })}'
            '${_event('content_block_stop', {
              'type': 'content_block_stop',
              'index': 0,
            })}'
            '${_event('message_stop', {'type': 'message_stop'})}',
          ));

    final deltas = await AnthropicCompatibleAdapter(dio)
        .chatStream(provider: _provider(), apiKey: 'key', request: _request)
        .toList();

    expect(deltas.map((d) => d.text ?? '').join(), 'Hello');
    expect(deltas.last.done, isTrue);
  });

  test('reassembles a tool_use block from partial JSON deltas', () async {
    final dio = Dio()
      ..httpClientAdapter = FakeHttpAdapter((_) => sseBody(
            '${_event('content_block_start', {
              'type': 'content_block_start',
              'index': 1,
              'content_block': {
                'type': 'tool_use',
                'id': 'tool_1',
                'name': 'write_file',
              },
            })}'
            '${_event('content_block_delta', {
              'type': 'content_block_delta',
              'index': 1,
              'delta': {'type': 'input_json_delta', 'partial_json': '{"path":'},
            })}'
            '${_event('content_block_delta', {
              'type': 'content_block_delta',
              'index': 1,
              'delta': {
                'type': 'input_json_delta',
                'partial_json': '"notes.txt","content":"hi"}',
              },
            })}'
            '${_event('content_block_stop', {
              'type': 'content_block_stop',
              'index': 1,
            })}'
            '${_event('message_stop', {'type': 'message_stop'})}',
          ));

    final deltas = await AnthropicCompatibleAdapter(dio)
        .chatStream(provider: _provider(), apiKey: 'key', request: _request())
        .toList();

    final calls = deltas.last.toolCalls;
    expect(calls, isNotNull);
    expect(calls!.single.id, 'tool_1');
    expect(calls.single.name, 'write_file');
    expect(calls.single.args, {'path': 'notes.txt', 'content': 'hi'});
  });

  test('surfaces a provider error as a terminal error delta', () async {
    final dio = Dio()..httpClientAdapter = ErrorHttpAdapter();

    final deltas = await AnthropicCompatibleAdapter(dio)
        .chatStream(provider: _provider(), apiKey: 'bad', request: _request())
        .toList();

    expect(deltas, hasLength(1));
    expect(deltas.single.error, 'Invalid API key');
    expect(deltas.single.done, isTrue);
  });
}
