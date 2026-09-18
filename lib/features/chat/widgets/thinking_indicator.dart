import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/liquid_glass.dart';
import '../../../core/models/chat_models.dart';
import '../chat_controller.dart';

/// The single, calm indicator for every agent state — thinking, acting,
/// awaiting approval — with its live reasoning one tap away.
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator> {
  bool _expanded = false;

  String _status(ChatController chat) {
    switch (chat.runState) {
      case RunState.thinking:
        return 'Thinking…';
      case RunState.acting:
        return 'Acting · step ${chat.step}';
      case RunState.awaitingApproval:
        return 'Waiting for your approval';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, chat, _) {
        final visible = chat.isRunning;
        final reasoning = chat.streamingReasoning;

        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: visible ? 1 : 0,
              child: visible
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                      child: GlassCard(
                        alpha: 0.06,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: reasoning.isEmpty
                                  ? null
                                  : () => setState(() => _expanded = !_expanded),
                              child: Row(
                                children: [
                                  const _Pulse(),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _status(chat),
                                      style: const TextStyle(
                                        color: kPrimaryText,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (reasoning.isNotEmpty)
                                    AnimatedRotation(
                                      turns: _expanded ? 0.5 : 0,
                                      duration: const Duration(milliseconds: 200),
                                      child: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: kSecondaryText,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_expanded && reasoning.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 140),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    reasoning,
                                    style: const TextStyle(
                                      color: kSecondaryText,
                                      fontSize: 12.5,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ),
        );
      },
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse();

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
      ),
    );
  }
}
