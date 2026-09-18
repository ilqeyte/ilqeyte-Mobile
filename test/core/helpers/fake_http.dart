import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Builds the streamed response body dio hands to an adapter under
/// `ResponseType.stream` — enough to script a provider from a fixture string.
ResponseBody sseBody(String payload) => ResponseBody(
      Stream.fromIterable([Uint8List.fromList(utf8.encode(payload))]),
      200,
      headers: const {'content-type': ['text/event-stream']},
    );

/// A plain JSON response — the shape `/models` answers with.
ResponseBody jsonBody(Map<String, dynamic> payload) => ResponseBody(
      Stream.fromIterable([Uint8List.fromList(utf8.encode(jsonEncode(payload)))]),
      200,
      headers: const {'content-type': ['application/json']},
    );

/// Routes every request through [respond], which gets the decoded request body.
/// Tests key the response off the message count to script multi-round loops.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.respond);

  final ResponseBody Function(Map<String, dynamic> body) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final data = options.data;
    final body = (data is String && data.isNotEmpty)
        ? jsonDecode(data) as Map<String, dynamic>
        : <String, dynamic>{};
    return respond(body);
  }

  @override
  void close({bool force = false}) {}
}

/// Always fails with a shaped [DioException], the way a 401 does.
class ErrorHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: 401,
        data: {'error': {'message': 'Invalid API key'}},
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}
