import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilqeyte_mobile/core/tools/file_tools.dart';
import 'package:ilqeyte_mobile/core/tools/tool.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory workspace;
  late ToolContext ctx;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('workspace_');
    ctx = ToolContext(workspacePath: workspace.path, conversationId: 'test');
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  test('write creates nested directories and read round-trips', () async {
    final wrote = await const WriteFileTool()
        .invoke({'path': 'sub/dir/a.txt', 'content': 'hello'}, ctx);

    expect(wrote.isError, isFalse);
    expect(
      await File(p.join(workspace.path, 'sub', 'dir', 'a.txt')).readAsString(),
      'hello',
    );

    final read = await const ReadFileTool().invoke({'path': 'sub/dir/a.txt'}, ctx);
    expect(read.isError, isFalse);
    expect(read.content, 'hello');
  });

  test('read reports a missing file instead of throwing', () async {
    final read = await const ReadFileTool().invoke({'path': 'nope.txt'}, ctx);

    expect(read.isError, isTrue);
    expect(read.content, contains('not found'));
  });

  test('a relative path escaping the workspace is refused', () async {
    final wrote = await const WriteFileTool()
        .invoke({'path': '../escape.txt', 'content': 'nope'}, ctx);

    expect(wrote.isError, isTrue);
    expect(
      File(p.join(workspace.parent.path, 'escape.txt')).existsSync(),
      isFalse,
    );
  });

  test('an absolute path is confined to the workspace', () async {
    final read = await const ReadFileTool().invoke({'path': '/etc/passwd'}, ctx);

    expect(read.isError, isTrue);
  });

  test('edit replaces text and fails loudly when the old text is absent',
      () async {
    await const WriteFileTool()
        .invoke({'path': 'e.txt', 'content': 'foo bar baz'}, ctx);

    final edited = await const EditFileTool()
        .invoke({'path': 'e.txt', 'old_text': 'bar', 'new_text': 'qux'}, ctx);

    expect(edited.isError, isFalse);
    expect(
      await File(p.join(workspace.path, 'e.txt')).readAsString(),
      'foo qux baz',
    );

    final missing = await const EditFileTool()
        .invoke({'path': 'e.txt', 'old_text': 'nope', 'new_text': 'x'}, ctx);

    expect(missing.isError, isTrue);
  });

  test('search_files returns matching lines with line numbers', () async {
    await const WriteFileTool()
        .invoke({'path': 'a.txt', 'content': 'first\nneedle line\nthird'}, ctx);

    final found = await const SearchFilesTool()
        .invoke({'pattern': 'needle', 'dir': '.'}, ctx);

    expect(found.isError, isFalse);
    expect(found.content, contains('a.txt:2'));
    expect(found.content, contains('needle line'));
  });

  test('delete removes a file and reports nothing to delete', () async {
    await const WriteFileTool().invoke({'path': 'gone.txt', 'content': 'x'}, ctx);

    final deleted =
        await const DeletePathTool().invoke({'path': 'gone.txt'}, ctx);
    expect(deleted.isError, isFalse);
    expect(File(p.join(workspace.path, 'gone.txt')).existsSync(), isFalse);

    final again =
        await const DeletePathTool().invoke({'path': 'gone.txt'}, ctx);
    expect(again.isError, isTrue);
  });
}
