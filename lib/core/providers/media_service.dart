import 'package:dio/dio.dart';

import '../models/provider_models.dart';
import 'util.dart';

/// Image generation over an OpenAI-compatible /images/generations endpoint —
/// the shape OpenAI, together with most compatible gateways, use today.
class ImageGenerationService {
  ImageGenerationService(this._dio);

  final Dio _dio;

  /// Returns one reference per image: a remote URL, or a `data:` URI when the
  /// provider answers in base64.
  Future<List<String>> generate({
    required ProviderConfig provider,
    required String apiKey,
    required String prompt,
    int count = 1,
    String size = '1024x1024',
  }) async {
    final url = joinEndpoint(provider.baseUrl, '/images/generations',
        ensureV1: provider.ensureV1);
    try {
      final res = await _dio.post<dynamic>(
        url,
        data: <String, dynamic>{
          'model': provider.defaultModel,
          'prompt': prompt,
          'n': count,
          'size': size,
        },
        options: Options(headers: <String, dynamic>{
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        }),
      );
      final data = res.data;
      final out = <String>[];
      if (data is Map<String, dynamic> && data['data'] is List) {
        for (final e in data['data'] as List) {
          if (e is! Map<String, dynamic>) continue;
          final b64 = e['b64_json'] as String?;
          if (b64 != null && b64.isNotEmpty) {
            out.add('data:image/png;base64,$b64');
            continue;
          }
          final u = e['url'] as String?;
          if (u != null && u.isNotEmpty) out.add(u);
        }
      }
      return out;
    } on DioException catch (e) {
      throw Exception(_describe(e));
    }
  }

  static String _describe(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final err = data['error'];
      if (err is Map<String, dynamic>) {
        final msg = err['message'] as String?;
        if (msg != null && msg.isNotEmpty) return msg;
      }
    }
    return e.message ?? 'Image generation failed.';
  }
}

/// Video generation setup. Video endpoints are not standardized across
/// providers, so this speaks the common OpenAI-style request shape and surfaces
/// whatever the provider answers with — a job id, a poll URL, or a status.
class VideoGenerationService {
  VideoGenerationService(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> createJob({
    required ProviderConfig provider,
    required String apiKey,
    required String prompt,
    int durationSeconds = 5,
  }) async {
    final url = joinEndpoint(provider.baseUrl, '/videos/generations',
        ensureV1: provider.ensureV1);
    try {
      final res = await _dio.post<dynamic>(
        url,
        data: <String, dynamic>{
          'model': provider.defaultModel,
          'prompt': prompt,
          'duration': durationSeconds,
        },
        options: Options(headers: <String, dynamic>{
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        }),
      );
      final data = res.data;
      return data is Map<String, dynamic> ? data : {'raw': '$data'};
    } on DioException catch (e) {
      throw Exception(_describe(e));
    }
  }

  static String _describe(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final err = data['error'];
      if (err is Map<String, dynamic>) {
        final msg = err['message'] as String?;
        if (msg != null && msg.isNotEmpty) return msg;
      }
    }
    return e.message ?? 'Video generation failed.';
  }
}
