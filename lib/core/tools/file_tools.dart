import 'dart:io';

import 'package:path/path.dart' as p;

import 'tool.dart';

/// Resolves a workspace-relative path and refuses anything that escapes the
/// sandbox. Every file tool funnels through here.
String _resolve(ToolContext ctx, String relative) {
  final root = Directory(ctx.workspacePath).absolute.path;
  final joined = p.join(root, relative.isEmpty ? '.' : relative);
  final normalized = p.normalize(joined);
  // The workspace root itself is a valid target — isWithin() is false for a
  // path that equals the root, so it is allowed explicitly.
  if (normalized != root && !p.isWithin(root, normalized)) {
    throw ArgumentError('Path escapes the workspace: "$relative"');
  }
  return normalized;
}

class ReadFileTool extends Tool {
  const ReadFileTool()
      : super(
          name: 'read_file',
          description: 'Read the full contents of a file inside the workspace.',
          category: 'Files',
          inputSchema: const {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Path relative to the workspace root.'
              }
            },
            'required': ['path'],
          },
        );

  @override
  Future<ToolInvocationResult> invoke(
      Map<String, dynamic> args, ToolContext ctx) async {
    final relative = (args['path'] as String?) ?? '';
    try {
      final file = File(_resolve(ctx, relative));
      if (!await file.exists()) {
        return ToolInvocationResult(
            content: 'File not found: $relative', isError: true);
      }
      final content = await file.readAsString();
      const cap = 20000;
      final body = content.length > cap
          ? '${content.substring(0, cap)}\n...(truncated, ${content.length} chars total)'
          : content;
      return ToolInvocationResult(content: body);
    } catch (e) {
      return ToolInvocationResult(
          content: 'read_file failed: $e', isError: true);
    }
  }
}

class WriteFileTool extends Tool {
  const WriteFileTool()
      : super(
          name: 'write_file',
          description: 'Create or overwrite a file inside the workspace.',
          category: 'Files',
          isSideEffecting: true,
          inputSchema: const {
            'type': 'object',
            'properties': {
              'path': {'type': 'string'},
              'content': {'type': 'string'},
            },
            'required': ['path', 'content'],
          },
        );

  @override
  Future<ToolInvocationResult> invoke(
      Map<String, dynamic> args, ToolContext ctx) async {
    final relative = (args['path'] as String?) ?? '';
    final content = (args['content'] as String?) ?? '';
    try {
      final file = File(_resolve(ctx, relative));
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      return ToolInvocationResult(
          content: 'Wrote ${content.length} characters to $relative.');
    } catch (e) {
      return ToolInvocationResult(
          content: 'write_file failed: $e', isError: true);
    }
  }
}

class EditFileTool extends Tool {
  const EditFileTool()
      : super(
          name: 'edit_file',
          description: 'Replace text inside an existing file. Fails if the old '
              'text is not present, so nothing is silently rewritten.',
          category: 'Files',
          isSideEffecting: true,
          inputSchema: const {
            'type': 'object',
            'properties': {
              'path': {'type': 'string'},
              'old_text': {'type': 'string'},
              'new_text': {'type': 'string'},
              'replace_all': {'type': 'boolean'},
            },
            'required': ['path', 'old_text', 'new_text'],
          },
        );

  @override
  Future<ToolInvocationResult> invoke(
      Map<String, dynamic> args, ToolContext ctx) async {
    final relative = (args['path'] as String?) ?? '';
    final oldText = (args['old_text'] as String?) ?? '';
    final newText = (args['new_text'] as String?) ?? '';
    final replaceAll = (args['replace_all'] as bool?) ?? false;
    if (oldText.isEmpty) {
      return const ToolInvocationResult(
          content: 'old_text must not be empty.', isError: true);
    }
    try {
      final file = File(_resolve(ctx, relative));
      if (!await file.exists()) {
        return ToolInvocationResult(
            content: 'File not found: $relative', isError: true);
      }
      final content = await file.readAsString();
      if (!content.contains(oldText)) {
        return ToolInvocationResult(
            content: 'old_text not found in $relative. Nothing changed.',
            isError: true);
      }
      final updated = replaceAll
          ? content.replaceAll(oldText, newText)
          : content.replaceFirst(oldText, newText);
      await file.writeAsString(updated);
      return ToolInvocationResult(content: 'Edited $relative.');
    } catch (e) {
      return ToolInvocationResult(
          content: 'edit_file failed: $e', isError: true);
    }
  }
}

class ListFilesTool extends Tool {
  const ListFilesTool()
      : super(
          name: 'list_files',
          description: 'List entries in a workspace directory.',
          category: 'Files',
          inputSchema: const {
            'type': 'object',
            'properties': {
              'dir': {
                'type': 'string',
                'description': 'Defaults to the workspace root.'
              },
              'recursive': {'type': 'boolean'},
            },
          },
        );

  @override
  Future<ToolInvocationResult> invoke(
      Map<String, dynamic> args, ToolContext ctx) async {
    final dir = (args['dir'] as String?) ?? '.';
    final recursive = (args['recursive'] as bool?) ?? false;
    try {
      final directory = Directory(_resolve(ctx, dir));
      if (!await directory.exists()) {
        return ToolInvocationResult(
            content: 'Directory not found: $dir', isError: true);
      }
      final entries = <String>[];
      final stream = directory.list(recursive: recursive);
      await for (final entity in stream) {
        final name = p.relative(entity.path, from: directory.path);
        final prefix = entity is Directory ? 'dir ' : 'file';
        entries.add('$prefix $name');
        if (entries.length >= 200) {
          entries.add('...(truncated at 200 entries)');
          break;
        }
      }
      if (entries.isEmpty) {
        return const ToolInvocationResult(content: 'Empty directory.');
      }
      return ToolInvocationResult(content: entries.join('\n'));
    } catch (e) {
      return ToolInvocationResult(
          content: 'list_files failed: $e', isError: true);
    }
  }
}

class SearchFilesTool extends Tool {
  const SearchFilesTool()
      : super(
          name: 'search_files',
          description: 'Grep for text across the workspace. Returns matching '
              'lines with their line numbers.',
          category: 'Files',
          inputSchema: const {
            'type': 'object',
            'properties': {
              'pattern': {'type': 'string'},
              'dir': {'type': 'string'},
            },
            'required': ['pattern'],
          },
        );

  @override
  Future<ToolInvocationResult> invoke(
      Map<String, dynamic> args, ToolContext ctx) async {
    final pattern = (args['pattern'] as String?) ?? '';
    final dir = (args['dir'] as String?) ?? '.';
    if (pattern.isEmpty) {
      return const ToolInvocationResult(
          content: 'pattern must not be empty.', isError: true);
    }
    try {
      final root = Directory(_resolve(ctx, dir));
      final needle = pattern.toLowerCase();
      final matches = <String>[];
      await for (final entity in root.list(recursive: true)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        final size = await entity.length();
        if (size > 1024 * 1024) continue;
        final lines = await entity.readAsLines();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].toLowerCase().contains(needle)) {
            matches.add('${p.relative(entity.path, from: root.path)}:${i + 1}: ${lines[i].trim()}');
            if (matches.length >= 40) break;
          }
        }
        if (matches.length >= 40) break;
      }
      if (matches.isEmpty) {
        return ToolInvocationResult(content: 'No matches for "$pattern".');
      }
      return ToolInvocationResult(content: matches.join('\n'));
    } catch (e) {
      return ToolInvocationResult(
          content: 'search_files failed: $e', isError: true);
    }
  }
}

class MakeDirectoryTool extends Tool {
  const MakeDirectoryTool()
      : super(
          name: 'make_directory',
          description: 'Create a directory inside the workspace.',
          category: 'Files',
          isSideEffecting: true,
          inputSchema: const {
            'type': 'object',
            'properties': {
              'path': {'type': 'string'},
            },
            'required': ['path'],
          },
        );

  @override
  Future<ToolInvocationResult> invoke(
      Map<String, dynamic> args, ToolContext ctx) async {
    final relative = (args['path'] as String?) ?? '';
    try {
      await Directory(_resolve(ctx, relative)).create(recursive: true);
      return ToolInvocationResult(content: 'Created directory $relative.');
    } catch (e) {
      return ToolInvocationResult(
          content: 'make_directory failed: $e', isError: true);
    }
  }
}

class DeletePathTool extends Tool {
  const DeletePathTool()
      : super(
          name: 'delete_path',
          description: 'Delete a file or directory inside the workspace. '
              'Destructive — the user is asked first.',
          category: 'Files',
          isSideEffecting: true,
          inputSchema: const {
            'type': 'object',
            'properties': {
              'path': {'type': 'string'},
            },
            'required': ['path'],
          },
        );

  @override
  Future<ToolInvocationResult> invoke(
      Map<String, dynamic> args, ToolContext ctx) async {
    final relative = (args['path'] as String?) ?? '';
    try {
      final path = _resolve(ctx, relative);
      final file = File(path);
      final directory = Directory(path);
      if (await file.exists()) {
        await file.delete();
        return ToolInvocationResult(content: 'Deleted file $relative.');
      }
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        return ToolInvocationResult(content: 'Deleted directory $relative.');
      }
      return ToolInvocationResult(
          content: 'Nothing to delete at $relative.', isError: true);
    } catch (e) {
      return ToolInvocationResult(
          content: 'delete_path failed: $e', isError: true);
    }
  }
}
