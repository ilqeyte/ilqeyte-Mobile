import 'dart:convert';

/// Normalizes a base URL and joins a path onto it, tolerating a missing
/// `/v1` segment, so users can paste either the bare host or a full `/v1`
/// endpoint.
String joinEndpoint(String baseUrl, String path, {bool ensureV1 = true}) {
  var b = baseUrl.trim();
  while (b.endsWith('/')) {
    b = b.substring(0, b.length - 1);
  }
  if (ensureV1 && !b.endsWith('/v1')) b += '/v1';
  return '$b$path';
}

/// Parses a JSON object defensively — a malformed SSE frame must never kill
/// an otherwise healthy run.
Map<String, dynamic>? tryParseJsonObject(String? raw) {
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// Reads a typed field out of a JSON object, or null.
T? field<T>(Map<String, dynamic>? json, String key) {
  if (json == null) return null;
  final value = json[key];
  return value is T ? value : null;
}
