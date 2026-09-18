import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/liquid_glass.dart';
import '../chat_controller.dart';

/// A pending destructive-tool approval, surfaced right above the input where
/// the user's thumb already is. One tap to allow, one to deny.
class ApprovalBar extends StatelessWidget {
  const ApprovalBar({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final call = chat.pendingApproval;
    if (call == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: GlassCard(
        alpha: 0.08,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.shield_rounded, size: 18, color: kAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${call.name} wants to run. Allow it?',
                style: const TextStyle(color: kPrimaryText, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => chat.respondApproval(false),
              child: const Text('Deny'),
            ),
            FilledButton(
              onPressed: () => chat.respondApproval(true),
              child: const Text('Allow'),
            ),
          ],
        ),
      ),
    );
  }
}
