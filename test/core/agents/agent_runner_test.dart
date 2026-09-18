import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilqeyte_mobile/core/agents/agent_runner.dart';
import 'package:ilqeyte_mobile/core/memory/memory_service.dart';
import 'package:ilqeyte_mobile/core/models/chat_models.dart';
import 'package:ilqeyte_mobile/core/models/provider_models.dart';
import 'package:ilqeyte_mobile/core/storage/database.dart';
import 'package:ilqeyte_mobile/core/tools/tool_registry.dart';
import 'package:path/path.dart' as p;

import '../helpers/fake_http.dart';

String _frame(Map<String, dynamic> json) => 'data: ${jsonEncode(json)}\n\n';

String _text(String content) =>
    '${_frame({'choices': [{'delta': {'content': content}}]})}data: [DONE]\n\n';

String _toolCall(String id, String name, Map<String, dynamic> args) =>
    '${_frame({
      'choices': [
        {
          'delta': {
            'tool_calls': [
              {
                'index': 0,
                'id': id,
                'function': {'name': name, 'arguments': jsonEncode(args)},
              }
            ]
          }
        }
      ]
    })}data: [DONE]\n\n';

ProviderConfig _provider() => ProviderConfig(
      id: 'p',
      name: 'test',
      kind: ProviderKind.agent,
      protocol: LlmProtocol.openaiCompatible,
      baseUrl: 'https://example.com/v1',
      createdAt: DateTime.now(),
    );

ChatMessage _user(String text) => ChatMessage(
      id: 'u',
      role: ChatRole.user,
      text: text,
      createdAt: DateTime.now(),
    );

void main() {
  late Directory workspace;
  late DatabaseService db;
  late MemoryService memory;
  late AgentRunner runner;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('run_ws_');
    final dbDir = await Directory.systemTemp.createTemp('run_db_');
    db = DatabaseService();
    await db.open(directory: dbDir);
    memory = MemoryService(db);
    runner = AgentRunner(
      dio: Dio(),
      tools: ToolRegistry()..registerAll(defaultTools()),
      memory: memory,
    );
  });

  tearDown(() async {
    await db.close();
    if (await workspace.exists()) await workspace.delete(recursive: true);
  });

  /// Round 1 (system + user on the wire) calls the tool; round 2 — once the
  /// assistant turn and tool report are appended, four messages — answers in
  /// plain text and stops.
  void scriptRound(String toolFixture, String answer) {
    runner.dio.httpClientAdapter = FakeHttpAdapter((body) {
      final count = (body['messages'] as List).length;
      return sseBody(count <= 3 ? toolFixture : _text(answer));
    });
  }

  test('completes a tool round trip and gates the destructive tool', () async {
    scriptRound(
      _toolCall('call_1', 'write_file', {'path': 'notes.txt', 'content': 'hi'}),
      'Done. notes.txt is written.',
    );

    final approved = <ToolCall>[];
    final events = await runner
        .run(
          config: AgentRunConfig(
            mode: ChatMode.agent,
            model: 'gpt-4o-mini',
            workspacePath: workspace.path,
            conversationId: 'run-1',
            maxSteps: 4,
          ),
          provider: _provider(),
          apiKey: 'key',
          history: [_user('Write notes.txt with the text hi.')],
          requireApproval: (call) async {
            approved.add(call);
            return true;
          },
        )
        .toList();

    expect(approved, hasLength(1));
    expect(approved.single.name, 'write_file');
    expect(await File(p.join(workspace.path, 'notes.txt')).readAsString(), 'hi');

    // The loop asks, then acts, then reports — one result per call.
    expect(events.where((e) => e.toolResult != null), hasLength(1));
    final result = events.where((e) => e.toolResult != null).single.toolResult!;
    expect(result.isError, isFalse);
    expect(result.content, contains('Wrote'));

    expect(events.map((e) => e.token ?? '').join(), 'Done. notes.txt is written.');
    expect(events.any((e) => e.state == RunState.awaitingApproval), isTrue);
    expect(events.last.state, RunState.done);
    expect(events.last.done, isTrue);
  });

  test('a denied tool is skipped and the loop still finishes', () async {
    scriptRound(
      _toolCall('call_1', 'write_file', {'path': 'nope.txt', 'content': 'x'}),
      'Understood, skipping that.',
    );

    final events = await runner
        .run(
          config: AgentRunConfig(
            mode: ChatMode.agent,
            model: 'gpt-4o-mini',
            workspacePath: workspace.path,
            conversationId: 'run-2',
            maxSteps: 4,
          ),
          provider: _provider(),
          apiKey: 'key',
          history: [_user('Write nope.txt')],
          requireApproval: (_) async => false,
        )
        .toList();

    final result = events.where((e) => e.toolResult != null).single.toolResult!;
    expect(result.isError, isTrue);
    expect(result.content, contains('denied'));
    expect(File(p.join(workspace.path, 'nope.txt')).existsSync(), isFalse);
    expect(events.last.state, RunState.done);
  });

  test('autoApprove bypasses the gate for side-effecting tools', () async {
    scriptRound(
      _toolCall('call_1', 'write_file', {'path': 'auto.txt', 'content': 'y'}),
      'Auto-approved and written.',
    );

    var gated = 0;
    final events = await runner
        .run(
          config: AgentRunConfig(
            mode: ChatMode.builder,
            model: 'gpt-4o-mini',
            workspacePath: workspace.path,
            conversationId: 'run-3',
            maxSteps: 4,
            autoApprove: true,
          ),
          provider: _provider(),
          apiKey: 'key',
          history: [_user('Write auto.txt')],
          requireApproval: (_) async {
            gated++;
            return true;
          },
        )
        .toList();

    expect(gated, 0);
    expect(await File(p.join(workspace.path, 'auto.txt')).readAsString(), 'y');
    expect(events.last.state, RunState.done);
  });

  test('a missing key fails before any request leaves the device', () async {
    final events = await runner
        .run(
          config: AgentRunConfig(
            mode: ChatMode.agent,
            model: 'gpt-4o-mini',
            workspacePath: workspace.path,
            conversationId: 'run-4',
            maxSteps: 2,
          ),
          provider: _provider(),
          apiKey: '',
          history: const [],
          requireApproval: (_) async => true,
        )
        .toList();

    expect(events, hasLength(1));
    expect(events.single.state, RunState.failed);
    expect(events.single.error, contains('API key'));
  });

  test('exhausting the step budget records a lesson and fails', () async {
    runner.dio.httpClientAdapter = FakeHttpAdapter((_) =>
        sseBody(_toolCall('call_1', 'write_file', {'path': 'loop.txt'})));

    final events = await runner
        .run(
          config: AgentRunConfig(
            mode: ChatMode.agent,
            model: 'gpt-4o-mini',
            workspacePath: workspace.path,
            conversationId: 'run-5',
            maxSteps: 2,
          ),
          provider: _provider(),
          apiKey: 'key',
          history: [_user('Keep writing files')],
          requireApproval: (_) async => true,
        )
        .toList();

    expect(events.last.state, RunState.failed);
    expect(events.last.error, contains('step budget'));

    // The budget exhaustion is exactly what should make the next run smarter.
    final lessons = await memory.recall('step budget');
    expect(lessons, isNotEmpty);
    expect(lessons.first.kind, 'lesson');
  });
}
