import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/liquid_glass.dart';
import '../../../core/models/chat_models.dart';
import '../chat_controller.dart';

/// The Assistant / Agent / Builder switch. Selection fades between states
/// rather than sliding a thumb — no motion that isn't earned.
class ModeSwitcher extends StatelessWidget {
  const ModeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: glassFill(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in ChatMode.values)
            _Segment(
              label: mode.label,
              selected: chat.mode == mode,
              onTap: () => chat.setMode(mode),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? glassFill(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : kSecondaryText,
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
