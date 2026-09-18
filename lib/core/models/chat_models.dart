/// The single internal agent model that every provider adapter normalizes onto.
/// Nothing in here knows about OpenAI or Anthropic — that mapping lives in the
/// adapters, so the agent loop speaks one language.
library;

enum ChatRole { system, user, assistant, tool }

/// The three personalities available directly in the chat UI.
enum ChatMode { assistant, agent, builder }

extension ChatModeX on ChatMode {
  String get label => switch (this) {
        ChatMode.assistant => 'Assistant',
        ChatMode.agent => 'Agent',
        ChatMode.builder => 'Builder',
      };

  String get subtitle => switch (this) {
        ChatMode.assistant => 'Everyday questions and quick tasks',
        ChatMode.agent => 'Autonomous, tool-driven automation',
        ChatMode.builder => 'Plans, writes and ships full-stack software',
      };

  /// Step budget per mode: Assistant barely acts, Builder gets the longest
  /// runway because real software work is many small steps.
  int get maxSteps => switch (this) {
        ChatMode.assistant => 6,
        ChatMode.agent => 24,
        ChatMode.builder => 40,
      };
}

class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> args;

  const ToolCall({required this.id, required this.name, this.args = const {}});

  factory ToolCall.fromJson(Map<String, dynamic> j) => ToolCall(
        id: (j['id'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        args: Map<String, dynamic>.from((j['args'] as Map?) ?? const {}),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'args': args};
}

class ToolResult {
  final String toolCallId;
  final String content;
  final bool isError;

  const ToolResult({
    required this.toolCallId,
    required this.content,
    this.isError = false,
  });

  factory ToolResult.fromJson(Map<String, dynamic> j) => ToolResult(
        toolCallId: (j['toolCallId'] as String?) ?? '',
        content: (j['content'] as String?) ?? '',
        isError: (j['isError'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() =>
      {'toolCallId': toolCallId, 'content': content, 'isError': isError};
}

/// Tool metadata handed to the model alongside its JSON-schema parameters.
class ToolSpec {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  const ToolSpec({
    required this.name,
    required this.description,
    required this.inputSchema,
  });
}

class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final String? reasoning;
  final List<ToolCall> toolCalls;
  final List<ToolResult> toolResults;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    this.text = '',
    this.reasoning,
    this.toolCalls = const [],
    this.toolResults = const [],
    required this.createdAt,
  });

  bool get isUser => role == ChatRole.user;
  bool get isAssistant => role == ChatRole.assistant;
  bool get hasToolCalls => toolCalls.isNotEmpty;

  ChatMessage copyWith({
    String? text,
    String? reasoning,
    List<ToolCall>? toolCalls,
    List<ToolResult>? toolResults,
  }) =>
      ChatMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        reasoning: reasoning ?? this.reasoning,
        toolCalls: toolCalls ?? this.toolCalls,
        toolResults: toolResults ?? this.toolResults,
        createdAt: createdAt,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: (j['id'] as String?) ?? '',
        role: ChatRole.values.byName((j['role'] as String?) ?? 'user'),
        text: (j['text'] as String?) ?? '',
        reasoning: j['reasoning'] as String?,
        toolCalls: ((j['toolCalls'] as List?) ?? const [])
            .map((e) => ToolCall.fromJson(e as Map<String, dynamic>))
            .toList(),
        toolResults: ((j['toolResults'] as List?) ?? const [])
            .map((e) => ToolResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        if (reasoning != null) 'reasoning': reasoning,
        'toolCalls': toolCalls.map((e) => e.toJson()).toList(),
        'toolResults': toolResults.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}

class ChatRequest {
  final String model;
  final List<ChatMessage> messages;
  final List<ToolSpec> tools;
  final double? temperature;
  final int maxTokens;

  const ChatRequest({
    required this.model,
    required this.messages,
    this.tools = const [],
    this.temperature,
    this.maxTokens = 4096,
  });
}

/// One chunk emitted by a provider adapter while streaming a completion.
class ChatStreamDelta {
  final String? text;
  final String? reasoning;
  final List<ToolCall>? toolCalls;
  final bool done;
  final String? error;
  const ChatStreamDelta({
    this.text,
    this.reasoning,
    this.toolCalls,
    this.done = false,
    this.error,
  });
}

/// Coarse loop state. The single expandable indicator in the chat UI mirrors
/// this, so thinking + acting + approval all live in one calm, animated chip.
enum RunState {
  idle,
  thinking,
  acting,
  awaitingApproval,
  done,
  failed,
  cancelled,
  needsProvider,
}

class RunEvent {
  final RunState? state;
  final String? token;
  final String? reasoning;

  /// A finalized assistant message — the controller should persist it.
  final ChatMessage? message;
  final ToolCall? toolCall;
  final ToolResult? toolResult;
  final int? step;
  final String? error;
  final bool done;

  const RunEvent({
    this.state,
    this.token,
    this.reasoning,
    this.message,
    this.toolCall,
    this.toolResult,
    this.step,
    this.error,
    this.done = false,
  });
}

class AgentRunConfig {
  final ChatMode mode;
  final String model;
  final String workspacePath;
  final String conversationId;
  final int maxSteps;
  final bool autoApprove;

  const AgentRunConfig({
    required this.mode,
    required this.model,
    required this.workspacePath,
    required this.conversationId,
    this.maxSteps = 24,
    this.autoApprove = false,
  });
}
