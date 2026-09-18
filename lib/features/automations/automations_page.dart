import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/router.dart';
import '../../app/theme/liquid_glass.dart';
import '../../core/models/chat_models.dart';
import '../../core/storage/database.dart';
import '../chat/chat_controller.dart';
import '../shell/shell_controller.dart';
import '../settings/widgets/settings_scaffold.dart';

/// Every past run, newest first. Tapping one restores it to the chat — the
/// conversation, its mode and its tool history all come back together.
class AutomationsPage extends StatelessWidget {
  const AutomationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Automations',
      child: Consumer<ChatController>(
        builder: (context, chat, _) {
          final rows = chat.history(limit: 60);
          if (rows.isEmpty) return const _Empty();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ConversationTile(
                  row: row,
                  onTap: () {
                    chat.resume(row.id);
                    context.read<ShellController>().setRoute(AppRoutes.chat);
                    AppRouter.go(AppRoutes.chat);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.row, required this.onTap});

  final ConversationRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlassCard(
        alpha: 0.05,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _statusColor(row.status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('${row.mode.label} · ${_timeAgo(row.updatedAt)}',
                      style: const TextStyle(
                          color: kSecondaryText, fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: kSecondaryText),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'active':
      return kAccent;
    case 'done':
      return kSuccess;
    case 'interrupted':
    case 'failed':
      return kDanger;
    default:
      return kSecondaryText;
  }
}

String _timeAgo(DateTime time) {
  final delta = DateTime.now().difference(time);
  if (delta.inMinutes < 1) return 'just now';
  if (delta.inHours < 1) return '${delta.inMinutes}m ago';
  if (delta.inDays < 1) return '${delta.inHours}h ago';
  return '${delta.inDays}d ago';
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassCard(
              radius: 26,
              alpha: 0.06,
              padding: const EdgeInsets.all(20),
              child: const Icon(Icons.bolt_rounded,
                  size: 32, color: kSecondaryText),
            ),
            const SizedBox(height: 20),
            const Text('No runs yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Every conversation you start is saved here with its mode and '
              'tool history. Send a message and it shows up.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kSecondaryText, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
