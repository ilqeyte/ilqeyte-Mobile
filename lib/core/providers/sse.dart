import 'dart:convert';

/// One Server-Sent Event frame.
class SseFrame {
  final String? event;
  final String data;
  const SseFrame({this.event, required this.data});
}

/// Parses a chunked SSE byte stream into discrete frames.
///
/// Handles LF and CRLF endings and multi-line `data:` fields. Carriage returns
/// are stripped at the byte level, which is safe because 0x0D / 0x0A never
/// appear inside a UTF-8 multi-byte sequence, so the stream can be split even
/// across the middle of an emoji.
Stream<SseFrame> sseFrames(Stream<List<int>> byteStream) async* {
  final List<int> buffer = <int>[];
  await for (final List<int> chunk in byteStream) {
    buffer.addAll(chunk);
    buffer.removeWhere((b) => b == 0x0D);
    int idx;
    while ((idx = _doubleNewlineIndex(buffer)) >= 0) {
      final raw = buffer.sublist(0, idx);
      buffer.removeRange(0, idx + 2);
      final frame = _parseFrame(raw);
      if (frame != null) yield frame;
    }
  }
  if (buffer.isNotEmpty) {
    final frame = _parseFrame(buffer);
    if (frame != null) yield frame;
  }
}

int _doubleNewlineIndex(List<int> b) {
  for (int i = 0; i + 1 < b.length; i++) {
    if (b[i] == 0x0A && b[i + 1] == 0x0A) return i;
  }
  return -1;
}

SseFrame? _parseFrame(List<int> raw) {
  final text = utf8.decode(raw, allowMalformed: true);
  final dataLines = <String>[];
  String? event;
  for (final line in text.split('\n')) {
    if (line.isEmpty) continue;
    if (line.startsWith(':')) continue; // keep-alive comment
    if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      final payload = line.substring(5);
      dataLines.add(payload.startsWith(' ') ? payload.substring(1) : payload);
    }
  }
  if (dataLines.isEmpty) return null;
  return SseFrame(event: event, data: dataLines.join('\n'));
}
