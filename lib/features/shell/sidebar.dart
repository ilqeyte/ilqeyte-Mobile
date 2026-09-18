import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/router.dart';
import '../../app/theme/liquid_glass.dart';
import '../../core/models/provider_models.dart';
import '../../core/providers/provider_store.dart';
import '../chat/chat_controller.dart';
import 'shell_controller.dart';

/// The left rail: brand, navigation, and live provider status. On compact
/// widths it slides in as a drawer over a dimmed stage.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key, this.onClose});

  final VoidCallback? onClose;

  static const _items = <_NavItem>[
    _NavItem(
        route: AppRoutes.chat, label: 'Chat', icon: Icons.chat_bubble_outline_rounded),
    _NavItem(
        route: AppRoutes.automations,
        label: 'Automations',
        icon: Icons.bolt_rounded),
    _NavItem(
        route: AppRoutes.plugins,
        label: 'Tools & plugins',
        icon: Icons.extension_outlined),
    _NavItem(route: AppRoutes.settings, label: 'Settings', icon: Icons.settings_rounded),
  ];

  void _navigate(BuildContext context, String route) {
    context.read<ShellController>().setRoute(route);
    AppRouter.go(route);
    onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    final selected = AppRoutes.sectionOf(shell.route);

    return ColoredBox(
      color: kBlack,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: _Brand(),
            ),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: _NewChatButton(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final item in _items)
                    _NavTile(
                      item: item,
                      selected: selected == item.route,
                      onTap: () => _navigate(context, item.route),
                    ),
                ],
              ),
            ),
            const _ProviderStatus(),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlassCard(
          radius: 12,
          alpha: 0.08,
          padding: const EdgeInsets.all(8),
          child: const Icon(Icons.auto_awesome_rounded, size: 18, color: kAccent),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('ilqeyte',
                style: TextStyle(
                    color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
            Text('cloud-brained agent',
                style: TextStyle(color: kSecondaryText, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _NavItem {
  const _NavItem({required this.route, required this.label, required this.icon});

  final String route;
  final String label;
  final IconData icon;
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? glassFill(0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 19, color: selected ? kAccent : kSecondaryText),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: TextStyle(
                  color: selected ? Colors.white : kPrimaryText,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewChatButton extends StatelessWidget {
  const _NewChatButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.read<ChatController>().newChat();
        context.read<ShellController>().setRoute(AppRoutes.chat);
        AppRouter.go(AppRoutes.chat);
      },
      child: GlassCard(
        alpha: 0.07,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: const [
            Icon(Icons.add_rounded, size: 19, color: kAccent),
            SizedBox(width: 10),
            Text('New chat',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// Live provider health at a glance: lit green when an agent brain is wired up.
class _ProviderStatus extends StatelessWidget {
  const _ProviderStatus();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProviderStore>();
    final provider = store.defaultOf(ProviderKind.agent);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => AppRouter.go(AppRoutes.agentProviders),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Icon(
              provider == null ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
              size: 15,
              color: provider == null ? kDanger : kSuccess,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                provider == null ? 'No provider configured' : provider.name,
                style: const TextStyle(color: kSecondaryText, fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

