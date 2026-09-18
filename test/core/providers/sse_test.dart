import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilqeyte_mobile/core/providers/sse.dart';

void main() {
  test('splits frames on a double newline and joins multi-line data', () async {
    final stream = Stream.fromIterable([
      utf8.encode('data: hello\n'),
      utf8.encode('data: world\n\n'),
    ]);

    final frames = await sseFrames(stream).toList();

    expect(frames, hasLength(1));
    expect(frames.single.data, 'hello\nworld');
    expect(frames.single.event, isNull);
  });

  test('strips carriage returns and drops keep-alive comments', () async {
    final stream = Stream.value(
      utf8.encode(': keep-alive\r\n\r\ndata: {"ok":true}\r\n\r\n'),
    );

    final frames = await sseFrames(stream).toList();

    expect(frames.map((f) => f.data), ['{"ok":true}']);
  });

  test('carries the event field alongside data', () async {
    final stream = Stream.value(
      utf8.encode('event: content_block_delta\ndata: {"a":1}\n\n'),
    );

    final frames = await sseFrames(stream).toList();

    expect(frames.single.event, 'content_block_delta');
    expect(frames.single.data, '{"a":1}');
  });

  test('emits nothing for a frame with no data lines', () async {
    final stream = Stream.value(utf8.encode('event: ping\n\n'));

    expect(await sseFrames(stream).toList(), isEmpty);
  });

  test('flushes a trailing frame that was never terminated', () async {
    final stream = Stream.value(utf8.encode('data: tail'));

    final frames = await sseFrames(stream).toList();

    expect(frames.single.data, 'tail');
  });

  test('survives a chunk boundary splitting a multi-byte character', () async {
    // 🙂 is four bytes; none of them is 0x0A or 0x0D, so splitting the stream
    // inside the glyph still reassembles into one correct frame.
    final bytes = utf8.encode('data: hello 🙂\n\n');
    final splitAt = utf8.encode('data: hello ').length + 2;

    final stream = Stream.fromIterable([
      bytes.sublist(0, splitAt),
      bytes.sublist(splitAt),
    ]);

    final frames = await sseFrames(stream).toList();

    expect(frames.single.data, 'hello 🙂');
  });
}
