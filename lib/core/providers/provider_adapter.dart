import 'package:dio/dio.dart';

import '../models/chat_models.dart';
import '../models/provider_models.dart';

/// Speaks one wire protocol on top of a [ProviderConfig]. Adapters normalize
/// streaming completions and tool calls onto [ChatStreamDelta], so the agent
/// loop never needs to know which provider it is talking to.
abstract class ProviderAdapter {
  const ProviderAdapter(this.dio);

  final Dio dio;

  Stream<ChatStreamDelta> chatStream({
    required ProviderConfig provider,
    required String? apiKey,
    required ChatRequest request,
  });

  /// Optional: enumerate the models this key can see. Returns an empty list
  /// when the provider does not implement a models endpoint.
  Future<List<String>> listModels({
    required ProviderConfig provider,
    required String? apiKey,
  }) async => const [];
}
