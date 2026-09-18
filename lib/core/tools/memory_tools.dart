import '../memory/memory_service.dart';
import 'tool.dart';

class MemorySaveTool extends Tool {
  const MemorySaveTool()
      : super(
          name: 'memory_save',
          description: 'Store a durable note, fact or lesson so future runs '
              'remember it. Use this for anything worth keeping.',
          category: 'Memory',
          inputSchema: const {
            'type': 'object',
            'properties': {
              'text': {'type': 'string'},
              'kind': {
                'type': 'string',
                'description': 'note | lesson | reflection',
              },
              'tags': {'type': 'array', 'items': {'type': 'string'}},
            },
            'required': ['text'],
          },
        );

  @override
  Future<ToolInvocationResult> invoke(
      Map<String, dynamic> args, ToolContext ctx) async {
    final text = (args['text'] as String?) ?? '';
    if (text.isEmpty) {
      return const ToolInvocationResult(
          content: 'text must not be empty.', isError: true);
    }
    final kind = (args['kind'] as String?) ?? 'note';
    final tags = ((args['tags'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
    await ctx.memory?.save(text, kind: kind, tags: tags);
    return const ToolInvocationResult(content: 'Saved to memory.');
  }
}

class MemoryRecallTool extends Tool {
  const MemoryRecallTool()
      : super(
          name: 'memory_recall',
          description: 'Recall notes and lessons relevant to a query.',
          category: 'Memory',
          inputSchema: const {
            'type': 'object',
            'properties': {
              'query': {'type': 'string'},
            },
            'required': ['query'],
          },
        );

  @override
  Future<ToolInvocationResult> invoke(
      Map<String, dynamic> args, ToolContext ctx) async {
    final query = (args['query'] as String?) ?? '';
    final notes = await ctx.memory?.recall(query) ?? const <MemoryNote>[];
    if (notes.isEmpty) {
      return const ToolInvocationResult(content: 'No memories matched.');
    }
    return ToolInvocationResult(
      content: notes.map((n) => '[${n.kind}] ${n.text}').join('\n'),
    );
  }
}
