import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/liquid_glass.dart';
import '../chat_controller.dart';

/// The composer: a glass trough pinned above the keyboard whose send button
/// cross-fades into a stop button while a run is live.
class ChatInput extends StatefulWidget {
  const ChatInput({super.key});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    context.read<ChatController>().send(text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, 8 + bottom),
      child: GlassCard(
        alpha: 0.06,
        padding: const EdgeInsets.fromLTRB(14, 4, 6, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                minLines: 1,
                maxLines: 7,
                style: const TextStyle(
                    color: kPrimaryText, fontSize: 16, height: 1.4),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  hintText: 'Message ${chat.mode.label}…',
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 4),
            chat.isRunning
                ? _StopButton(onTap: chat.cancel)
                : _SendButton(enabled: _hasText, onTap: _submit),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.35,
        child: Container(
          margin: const EdgeInsets.all(4),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: kAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_upward_rounded,
              color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: glassFill(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.stop_rounded, color: kDanger, size: 18),
      ),
    );
  }
}
