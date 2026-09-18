import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/router.dart';
import '../../../app/theme/liquid_glass.dart';
import '../../../core/models/provider_models.dart';
import '../../../core/providers/provider_store.dart';

/// The first-run and post-failure state: either a warm invitation to connect a
/// provider, or the working empty canvas waiting for a first message.
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key, this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final hasProvider = context.select<ProviderStore, bool>(
      (store) => store.defaultOf(ProviderKind.agent) != null,
    );

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
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 32, color: kAccent),
            ),
            const SizedBox(height: 20),
            Text(
              hasProvider ? 'What should we build?' : 'Connect your first provider',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasProvider
                  ? 'Pick a mode above. Agent and Builder read and write files in your workspace — you approve every change before it lands.'
                  : 'ilqeyte is cloud-brained. Add an OpenAI- or Anthropic-compatible endpoint and the whole app wakes up.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: kSecondaryText, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            if (!hasProvider)
              FilledButton.icon(
                onPressed: () => AppShell.go(AppRoutes.agentProviders),
                icon: const Icon(Icons.cloud_rounded),
                label: const Text('Add provider'),
              ),
            if (error != null) ...[
              const SizedBox(height: 20),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kDanger, fontSize: 13, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
