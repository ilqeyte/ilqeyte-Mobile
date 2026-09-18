import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../app/theme/liquid_glass.dart';
import '../../../core/models/chat_models.dart';
import 'tool_call_card.dart';

/// One turn in the conversation. User messages get a contained glass bubble;
/// assistant messages sit directly on black with their tool cards below, so
/// reasoning and action read as one continuous train of thought.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.streaming = false,
  });

  final ChatMessage message;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) return _userBubble(context);
    return _assistantBubble(context);
  }

  Widget _userBubble(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          child: GlassCard(
            alpha: 0.08,
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SelectableText(
              message.text,
              style: const TextStyle(
                  color: kPrimaryText, fontSize: 15.5, height: 1.45),
            ),
          ),
        ),
      ),
    );
  }

  Widget _assistantBubble(BuildContext context) {
    final text = streaming ? '${message.text} ▍' : message.text;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text.isNotEmpty)
            MarkdownBody(
              data: text,
              selectable: true,
              styleSheet: markdownStyle(),
            ),
          for (final call in message.toolCalls)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ToolCallCard(call: call, result: _resultFor(call.id)),
            ),
        ],
      ),
    );
  }

  ToolResult? _resultFor(String toolCallId) {
    final matches =
        message.toolResults.where((r) => r.toolCallId == toolCallId);
    return matches.isEmpty ? null : matches.first;
  }
}

/// Shared markdown styling: code blocks read as translucent glass, never as
/// harsh bordered boxes.
MarkdownStyleSheet markdownStyle() => MarkdownStyleSheet(
      p: const TextStyle(color: kPrimaryText, fontSize: 15.5, height: 1.55),
      h1: const TextStyle(
          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
      h2: const TextStyle(
          color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600),
      h3: const TextStyle(
          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
      a: const TextStyle(color: kAccent, decoration: TextDecoration.underline),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: const Color(0xFFE5E5EA),
        backgroundColor: glassFill(0.08),
      ),
      codeblockDecoration: BoxDecoration(
        color: glassFill(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: const TextStyle(color: kSecondaryText, height: 1.5),
      listBullet: const TextStyle(color: kSecondaryText),
    );
