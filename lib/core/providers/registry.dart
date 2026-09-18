import 'package:dio/dio.dart';

import '../models/provider_models.dart';
import 'anthropic_adapter.dart';
import 'openai_adapter.dart';
import 'provider_adapter.dart';

/// Picks the adapter that speaks a provider's wire protocol.
ProviderAdapter adapterFor(LlmProtocol protocol, Dio dio) {
  switch (protocol) {
    case LlmProtocol.openaiCompatible:
      return OpenAiCompatibleAdapter(dio);
    case LlmProtocol.anthropic:
      return AnthropicCompatibleAdapter(dio);
  }
}
