import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilqeyte_mobile/core/memory/memory_service.dart';
import 'package:ilqeyte_mobile/core/storage/database.dart';

void main() {
  late DatabaseService db;
  late MemoryService memory;

  setUp(() async {
    final temp = await Directory.systemTemp.createTemp('memory_');
    db = DatabaseService();
    await db.open(directory: temp);
    memory = MemoryService(db);
  });

  tearDown(() async => db.close());

  test('recall finds notes by keyword', () async {
    await memory.save('The user prefers tabs over spaces',
        kind: 'preference', weight: 5);
    await memory.save('Groceries: milk and bread');

    final notes = await memory.recall('tabs');

    expect(notes, hasLength(1));
    expect(notes.single.text, contains('tabs'));
    expect(notes.single.kind, 'preference');
  });

  test('recall ranks heavier notes ahead of lighter ones', () async {
    await memory.save('low weight note about flutter', weight: 1);
    await memory.save('high weight note about flutter', weight: 9);

    final notes = await memory.recall('flutter');

    expect(notes, hasLength(2));
    expect(notes.first.text, contains('high weight'));
  });

  test('recall falls back to recent notes when the query has no keywords',
      () async {
    await memory.save('older note');
    await memory.save('newer note');

    final notes = await memory.recall('???');

    expect(notes, isNotEmpty);
    expect(notes.first.text, 'newer note');
  });

  test('promptAddendum injects remembered lessons into a system prompt',
      () async {
    await memory.save('Deploy with fastlane', kind: 'lesson');

    final addendum = await memory.promptAddendum('How do I deploy?');

    expect(addendum, contains('## Long-term memory'));
    expect(addendum, contains('[lesson] Deploy with fastlane'));
  });

  test('promptAddendum is empty when nothing is remembered', () async {
    expect(await memory.promptAddendum('deploy'), isEmpty);
  });

  test('forget removes a note for good', () async {
    await memory.save('temporary');
    final before = await memory.recall('temporary');
    expect(before, hasLength(1));

    await memory.forget(before.single.id);

    expect(await memory.recall('temporary'), isEmpty);
  });
}
