import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/router.dart';
import '../../../app/theme/liquid_glass.dart';
import '../../../core/models/provider_models.dart';
import '../../../core/providers/provider_store.dart';
import '../../shell/shell_controller.dart';
import 'widgets/settings_scaffold.dart';

/// The settings index. Provider kinds each get their own page downstream so a
/// new user is never asked to configure more than one thing at a time.
class SettingsHomePage extends StatelessWidget {
  const SettingsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProviderStore>();

    return SettingsScaffold(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const SectionLabel('Providers'),
          _NavRow(
            icon: Icons.smart_toy_rounded,
            title: 'Agent & chat',
            subtitle: 'OpenAI- and Anthropic-compatible LLMs',
            route: AppRoutes.agentProviders,
            count: store.ofKind(ProviderKind.agent).length,
          ),
          _NavRow(
            icon: Icons.image_outlined,
            title: 'Image generation',
            subtitle: 'Media endpoints for still images',
            route: AppRoutes.imageProviders,
            count: store.ofKind(ProviderKind.image).length,
          ),
          _NavRow(
            icon: Icons.video_camera_back_outlined,
            title: 'Video generation',
            subtitle: 'Media endpoints for video',
            route: AppRoutes.videoProviders,
            count: store.ofKind(ProviderKind.video).length,
          ),
          const SectionLabel('System'),
          const _NavRow(
            icon: Icons.extension_outlined,
            title: 'Tools & plugins',
            subtitle: 'Sandboxed file, memory and media tools',
            route: AppRoutes.plugins,
          ),
          const _NavRow(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'ilqeyte mobile',
            route: AppRoutes.about,
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.count,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          context.read<ShellController>().setRoute(route);
          AppShell.go(route);
        },
        child: GlassCard(
          alpha: 0.05,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              GlassCard(
                radius: 10,
                alpha: 0.07,
                padding: const EdgeInsets.all(7),
                child: Icon(icon, size: 18, color: kAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: kSecondaryText, fontSize: 12.5)),
                  ],
                ),
              ),
              if (count != null)
                Text('$count',
                    style: const TextStyle(color: kSecondaryText, fontSize: 13))
              else
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: kSecondaryText),
            ],
          ),
        ),
      ),
    );
  }
}
