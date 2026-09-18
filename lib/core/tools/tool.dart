import '../memory/memory_service.dart';
import '../models/chat_models.dart';

/// What a tool hands back to the agent loop. [content] is what the model sees
/// on the next turn.
class ToolInvocationResult {
  final String content;
  final bool isError;
  const ToolInvocationResult({required this.content, this.isError = false});
}

/// Everything a tool may touch while serving a run.
class ToolContext {
  final String workspacePath;
  final String conversationId;
  final MemoryService? memory;

  const ToolContext({
    required this.workspacePath,
    required this.conversationId,
    this.memory,
  });
}

/// One capability the agent can invoke. Tools are the app's hands: the catalog
/// starts small and is meant to grow into the hundreds, since anything that
/// implements this interface can be registered.
abstract class Tool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final bool isSideEffecting;
  final String category;

  const Tool({
    required this.name,
    required this.description,
    required this.inputSchema,
    this.isSideEffecting = false,
    this.category = 'Built-in',
  });

  Future<ToolInvocationResult> invoke(
      Map<String, dynamic> args, ToolContext ctx);

  ToolSpec get spec => ToolSpec(
        name: name,
        description: description,
        inputSchema: inputSchema,
      );
}
