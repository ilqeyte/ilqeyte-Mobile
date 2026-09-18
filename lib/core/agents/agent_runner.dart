import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../memory/memory_service.dart';
import '../models/chat_models.dart';
import '../models/provider_models.dart';
import '../providers/provider_adapter.dart';
import '../providers/registry.dart';
import '../tools/tool.dart';
import '../tools/tool_registry.dart';
import 'prompts.dart';

typedef ApprovalGate = Future<bool> Function(ToolCall call);

/// The agent loop: stream a completion, run its tool calls (asking before
/// anything destructive), feed the results back, and repeat until the model
/// stops calling tools or the step budget runs out.
///
/// The runner owns no UI and no database. It narrates the run as a stream of
/// [RunEvent]s; the ChatController commits and renders them. That separation
/// keeps the loop testable with a fake adapter.
class AgentRunner {
  AgentRunner({
    required this.dio,
    required this.tools,
    required this.memory,
  });

  final Dio dio;
  final ToolRegistry tools;
  final MemoryService memory;

  static const Uuid _uuid = Uuid();

  Stream<RunEvent> run({
    required AgentRunConfig config,
    required ProviderConfig provider,
    required String? apiKey,
    required List<ChatMessage> history,
    required ApprovalGate requireApproval,
  }) async* {
    if (apiKey == null || apiKey.isEmpty) {
      yield const RunEvent(
        state: RunState.failed,
        error: 'No API key set for this provider. Add one in Settings.',
      );
      return;
    }

    final adapter = adapterFor(provider.protocol, dio);
    final goal = history
        .where((m) => m.role == ChatRole.user)
        .map((m) => m.text)
        .join('\n');

    final system = ChatMessage(
      id: 'system_${config.conversationId}',
      role: ChatRole.system,
      text: await _systemPrompt(config, goal),
      createdAt: DateTime.now(),
    );
    final messages = <ChatMessage>[system, ...history];

    for (var step = 1; step <= config.maxSteps; step++) {
      yield RunEvent(state: RunState.thinking, step: step);

      final request = ChatRequest(
        model: config.model,
        messages: messages,
        tools: tools.specsForMode(config.mode),
        temperature: config.mode == ChatMode.builder ? 0.3 : 0.6,
        maxTokens: 4096,
      );

      final text = StringBuffer();
      final reasoning = StringBuffer();
      List<ToolCall> calls = const [];

      try {
        await for (final delta in adapter.chatStream(
          provider: provider,
          apiKey: apiKey,
          request: request,
        )) {
          if (delta.error != null) {
            await memory.save('Run failed: ${delta.error}', kind: 'lesson');
            yield RunEvent(state: RunState.failed, error: delta.error);
            return;
          }
          if (delta.text != null && delta.text!.isNotEmpty) {
            text.write(delta.text);
            yield RunEvent(token: delta.text);
          }
          if (delta.reasoning != null && delta.reasoning!.isNotEmpty) {
            reasoning.write(delta.reasoning);
            yield RunEvent(reasoning: delta.reasoning);
          }
          if (delta.toolCalls != null) calls = delta.toolCalls!;
          if (delta.done) break;
        }
      } catch (e) {
        await memory.save('Provider call failed: $e', kind: 'lesson');
        yield RunEvent(state: RunState.failed, error: e.toString());
        return;
      }

      final assistant = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        text: text.toString().trim(),
        reasoning: reasoning.isEmpty ? null : reasoning.toString(),
        toolCalls: calls,
        createdAt: DateTime.now(),
      );
      messages.add(assistant);
      yield RunEvent(message: assistant);

      if (calls.isEmpty) {
        yield const RunEvent(state: RunState.done, done: true);
        return;
      }

      yield RunEvent(state: RunState.acting, step: step);

      final ctx = ToolContext(
        workspacePath: config.workspacePath,
        conversationId: config.conversationId,
        memory: memory,
      );

      for (final call in calls) {
        yield RunEvent(toolCall: call);
        final tool = tools[call.name];

        if (tool == null) {
          final result = ToolResult(
            toolCallId: call.id,
            content: 'Unknown tool: ${call.name}',
            isError: true,
          );
          messages.add(_toolMessage(result));
          yield RunEvent(toolResult: result);
          continue;
        }

        if (tool.isSideEffecting && !config.autoApprove) {
          yield RunEvent(
            state: RunState.awaitingApproval,
            toolCall: call,
            step: step,
          );
          final approved = await requireApproval(call);
          yield RunEvent(state: RunState.acting, toolCall: call, step: step);
          if (!approved) {
            final result = ToolResult(
              toolCallId: call.id,
              content: 'The user denied this action; skipping it.',
              isError: true,
            );
            messages.add(_toolMessage(result));
            yield RunEvent(toolResult: result);
            continue;
          }
        }

        ToolResult result;
        try {
          final outcome = await tool.invoke(call.args, ctx);
          result = ToolResult(
            toolCallId: call.id,
            content: outcome.content,
            isError: outcome.isError,
          );
        } catch (e) {
          result = ToolResult(
            toolCallId: call.id,
            content: 'Tool crashed: $e',
            isError: true,
          );
        }
        messages.add(_toolMessage(result));
        yield RunEvent(toolResult: result);
      }
    }

    await memory.save(
      'Hit the step budget (${config.maxSteps}) without finishing.',
      kind: 'lesson',
    );
    yield RunEvent(
      state: RunState.failed,
      error: 'Reached the step budget (${config.maxSteps}). '
          'Continue the conversation to keep going.',
    );
  }

  ChatMessage _toolMessage(ToolResult result) => ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.tool,
        toolResults: [result],
        createdAt: DateTime.now(),
      );

  Future<String> _systemPrompt(AgentRunConfig config, String goal) async {
    final buffer = StringBuffer(baseSystemPrompt(config.mode));
    buffer.write('\n\nWorkspace: ${config.workspacePath}\n');
    buffer.write('All file paths are relative to it, and nothing outside it is reachable.\n');
    final addendum = await memory.promptAddendum(goal);
    if (addendum.isNotEmpty) buffer.write(addendum);
    return buffer.toString();
  }
}
