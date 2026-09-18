import '../models/chat_models.dart';
import 'file_tools.dart';
import 'memory_tools.dart';
import 'tool.dart';

/// The catalog of everything the agent is allowed to do. Built-ins ship with
/// the app; third-party plugins register through exactly the same [register]
/// call, which is how the catalog grows to hundreds of tools.
class ToolRegistry {
  final Map<String, Tool> _tools = {};

  ToolRegistry();

  void register(Tool tool) => _tools[tool.name] = tool;

  void registerAll(Iterable<Tool> tools) => tools.forEach(register);

  Tool? operator [](String name) => _tools[name];

  List<Tool> get all {
    final list = _tools.values.toList()
      ..sort((a, b) {
        final byCategory = a.category.compareTo(b.category);
        return byCategory != 0 ? byCategory : a.name.compareTo(b.name);
      });
    return List.unmodifiable(list);
  }

  int get count => _tools.length;

  List<ToolSpec> get specs => [for (final t in all) t.spec];

  /// Capability gating by mode: Assistant is read-only, while Agent and
  /// Builder are trusted with side effects.
  List<ToolSpec> specsForMode(ChatMode mode) {
    switch (mode) {
      case ChatMode.assistant:
        return [for (final t in all) if (!t.isSideEffecting) t.spec];
      case ChatMode.agent:
      case ChatMode.builder:
        return specs;
    }
  }
}

/// The toolset that ships in the box.
List<Tool> defaultTools() {
  return [
    const ReadFileTool(),
    const WriteFileTool(),
    const EditFileTool(),
    const ListFilesTool(),
    const SearchFilesTool(),
    const MakeDirectoryTool(),
    const DeletePathTool(),
    const MemorySaveTool(),
    const MemoryRecallTool(),
  ];
}
