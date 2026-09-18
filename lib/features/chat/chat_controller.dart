import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/chat_models.dart';
import '../../core/models/provider_models.dart';
import '../../core/services/services.dart';
import '../../core/storage/database.dart';

/// Bridges the agent loop to the UI: streams tokens into the view, gates
/// destructive tools behind one tap, and persists every finalized message.
class ChatController extends ChangeNotifier {
  ChatController(this._services);

  final Services _services;
  static const Uuid _uuid = Uuid();

  final List<ChatMessage> messages = [];

  /// The protocol-accurate transcript for the next send, kept separate from
  /// [messages]: the UI mutates messages (cards attach to a turn) while the
  /// wire format must stay strict.
  final List<ChatMessage> _llmHistory = [];

  RunState runState = RunState.idle;
  ChatMode mode = ChatMode.agent;
  String streamingText = '';
  String streamingReasoning = '';
  String? error;
  int step = 0;
  ToolCall? pendingApproval;
  String? conversationId;

  StreamSubscription<RunEvent>? _sub;
  Completer<bool>? _approval;

  bool get isRunning =>
      runState == RunState.thinking ||
      runState == RunState.acting ||
      runState == RunState.awaitingApproval;

  bool get needsProvider => runState == RunState.needsProvider;

  void setMode(ChatMode mode) {
    if (this.mode != mode) {
      this.mode = mode;
      notifyListeners();
    }
  }

  List<ConversationRow> history({int limit = 40}) =>
      _services.database.conversations(limit: limit);

  /// Starts a run. Everything after this is driven by the incoming
  /// [RunEvent] stream until it completes, fails, or is stopped.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isRunning) return;

    error = null;

    final provider = _services.providers.defaultOf(ProviderKind.agent);
    if (provider == null) {
      runState = RunState.needsProvider;
      notifyListeners();
      return;
    }
    final apiKey = await _services.providers.keyOf(provider.id);
    if (apiKey == null || apiKey.isEmpty) {
      error = 'No API key set for ${provider.name}. Add one in Settings.';
      runState = RunState.failed;
      notifyListeners();
      return;
    }

    final isNew = conversationId == null;
    final id = conversationId ?? _uuid.v4();
    conversationId = id;

    final user = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    messages.add(user);
    _llmHistory.add(user);
    _persistLast();

    if (isNew) {
      _services.database.upsertConversation(
        id: id,
        title: trimmed.length > 64 ? '${trimmed.substring(0, 64)}…' : trimmed,
        mode: mode,
        providerId: provider.id,
        model: provider.defaultModel,
      );
    }

    runState = RunState.thinking;
    notifyListeners();

    final config = AgentRunConfig(
      mode: mode,
      model: provider.defaultModel ?? 'gpt-4o-mini',
      workspacePath: _services.workspacePath,
      conversationId: id,
      maxSteps: mode.maxSteps,
    );

    _sub = _services.runner
        .run(
          config: config,
          provider: provider,
          apiKey: apiKey,
          history: List.of(_llmHistory),
          requireApproval: _requireApproval,
        )
        .listen(_onEvent, onError: _onError, onDone: _onDone);
  }

  void _onEvent(RunEvent e) {
    if (e.state != null) runState = e.state!;
    if (e.step != null) step = e.step!;

    if (e.token != null && e.token!.isNotEmpty) streamingText += e.token!;
    if (e.reasoning != null && e.reasoning!.isNotEmpty) {
      streamingReasoning += e.reasoning!;
    }

    // A turn finished: commit its message and clear the live buffer.
    if (e.message != null) {
      messages.add(e.message!);
      _llmHistory.add(e.message!);
      streamingText = '';
      streamingReasoning = '';
      _persistLast();
    }

    // A tool is about to run — mount a live card on the last assistant turn.
    if (e.toolCall != null) {
      final last = _lastAssistant;
      if (last != null && !last.toolCalls.any((t) => t.id == e.toolCall!.id)) {
        _replaceLastAssistant(
            last.copyWith(toolCalls: [...last.toolCalls, e.toolCall!]));
      }
    }

    // A tool finished: drop its card into the same turn and feed the result
    // back into the wire transcript for the next round.
    if (e.toolResult != null) {
      final result = e.toolResult!;
      final last = _lastAssistant;
      if (last != null) {
        final results = [
          ...last.toolResults.where((r) => r.toolCallId != result.toolCallId),
          result,
        ];
        _replaceLastAssistant(last.copyWith(toolResults: results));
      }
      _llmHistory.add(ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.tool,
        toolResults: [result],
        createdAt: DateTime.now(),
      ));
    }

    if (e.error != null) error = e.error;
    notifyListeners();
  }

  void _onError(Object error, StackTrace stack) {
    this.error = error.toString();
    runState = RunState.failed;
    streamingText = '';
    streamingReasoning = '';
    notifyListeners();
  }

  void _onDone() {
    // An end while text is still buffered means the loop was cut short — keep
    // the partial answer instead of dropping it on the floor.
    if (streamingText.trim().isNotEmpty) {
      final partial = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        text: streamingText.trim(),
        createdAt: DateTime.now(),
      );
      messages.add(partial);
      _llmHistory.add(partial);
      _persistLast();
    }
    streamingText = '';
    streamingReasoning = '';
    final id = conversationId;
    if (id != null) {
      _services.database.touchConversation(
        id,
        status: runState == RunState.failed || runState == RunState.cancelled
            ? 'interrupted'
            : 'done',
      );
    }
    notifyListeners();
  }

  ChatMessage? get _lastAssistant {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isAssistant) return messages[i];
    }
    return null;
  }

  void _replaceLastAssistant(ChatMessage updated) {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isAssistant) {
        messages[i] = updated;
        break;
      }
    }
    _services.database
        .upsertMessage(conversationId!, messages.indexOf(updated), updated);
  }

  void _persistLast() {
    final id = conversationId;
    if (id == null || messages.isEmpty) return;
    _services.database.upsertMessage(id, messages.length - 1, messages.last);
  }

  // ------------------------------ approval ------------------------------

  /// Suspends the loop until the user decides. The request is already rendered
  /// as a card; this is what surfaces the approve affordance.
  Future<bool> _requireApproval(ToolCall call) async {
    _approval = Completer<bool>();
    pendingApproval = call;
    runState = RunState.awaitingApproval;
    notifyListeners();
    return _approval!.future;
  }

  /// One tap to approve, one to deny. Denial is not a failure — the model is
  /// told the action was skipped and can route around it.
  void respondApproval(bool approved) {
    final approval = _approval;
    if (approval == null || approval.isCompleted) return;
    approval.complete(approved);
    _approval = null;
    pendingApproval = null;
    runState = RunState.acting;
    notifyListeners();
  }

  // ------------------------------- control -------------------------------

  void cancel() {
    _sub?.cancel();
    _sub = null;

    final approval = _approval;
    if (approval != null && !approval.isCompleted) approval.complete(false);
    _approval = null;
    pendingApproval = null;

    runState = RunState.cancelled;
    streamingText = '';
    streamingReasoning = '';

    final id = conversationId;
    if (id != null) {
      _services.database.touchConversation(id, status: 'interrupted');
    }
    notifyListeners();
  }

  void newChat() {
    if (isRunning) cancel();
    messages.clear();
    _llmHistory.clear();
    conversationId = null;
    error = null;
    step = 0;
    streamingText = '';
    streamingReasoning = '';
    runState = RunState.idle;
    notifyListeners();
  }

  /// Loads a saved conversation back into the live state so a run can continue
  /// from history.
  Future<void> resume(String runId) async {
    if (isRunning) cancel();

    final row = _services.database.conversation(runId);
    if (row == null) return;

    final loaded = _services.database.messages(runId);
    messages
      ..clear()
      ..addAll(loaded);
    _llmHistory
      ..clear()
      ..addAll(loaded.where((m) => m.role != ChatRole.system));

    conversationId = runId;
    mode = row.mode;
    runState = RunState.idle;
    error = null;
    step = 0;
    streamingText = '';
    streamingReasoning = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
