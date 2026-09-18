/// Provider configuration. One model for three kinds of capability:
/// [ProviderKind.agent] powers the chat/agent loop, while image and video
/// providers power rich media generation. Settings keeps them strictly apart.
library;

enum ProviderKind { agent, image, video }

enum LlmProtocol { openaiCompatible, anthropic }

extension LlmProtocolX on LlmProtocol {
  String get label => switch (this) {
        LlmProtocol.openaiCompatible => 'OpenAI-compatible',
        LlmProtocol.anthropic => 'Anthropic-compatible',
      };
}

class ProviderConfig {
  final String id;
  final String name;
  final ProviderKind kind;
  final LlmProtocol protocol;
  final String baseUrl;
  final String? defaultModel;
  final bool isDefault;
  final DateTime createdAt;

  const ProviderConfig({
    required this.id,
    required this.name,
    required this.kind,
    required this.protocol,
    required this.baseUrl,
    this.defaultModel,
    this.isDefault = false,
    required this.createdAt,
  });

  factory ProviderConfig.fromJson(Map<String, dynamic> j) => ProviderConfig(
        id: (j['id'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        kind: ProviderKind.values.byName((j['kind'] as String?) ?? 'agent'),
        protocol: LlmProtocol.values
            .byName((j['protocol'] as String?) ?? 'openaiCompatible'),
        baseUrl: (j['baseUrl'] as String?) ?? '',
        defaultModel: j['defaultModel'] as String?,
        isDefault: (j['isDefault'] as bool?) ?? false,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'protocol': protocol.name,
        'baseUrl': baseUrl,
        'defaultModel': defaultModel,
        'isDefault': isDefault,
        'createdAt': createdAt.toIso8601String(),
      };

  ProviderConfig copyWith({
    String? name,
    String? baseUrl,
    String? defaultModel,
    bool? isDefault,
    LlmProtocol? protocol,
  }) =>
      ProviderConfig(
        id: id,
        name: name ?? this.name,
        kind: kind,
        protocol: protocol ?? this.protocol,
        baseUrl: baseUrl ?? this.baseUrl,
        defaultModel: defaultModel ?? this.defaultModel,
        isDefault: isDefault ?? this.isDefault,
        createdAt: createdAt,
      );
}
