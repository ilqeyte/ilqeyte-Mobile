import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme/liquid_glass.dart';
import '../../core/services/services.dart';
import '../../core/tools/tool.dart';
import '../settings/widgets/settings_scaffold.dart';

/// The tool catalog as it stands today: built-ins only, but registered through
/// the same seam third-party plugins will use.
class PluginsPage extends StatelessWidget {
  const PluginsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = context.read<Services>().tools.all;

    return SettingsScaffold(
      title: 'Tools & plugins',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const _GatingBanner(),
          const SizedBox(height: 8),
          for (final tool in tools) _ToolTile(tool: tool),
        ],
      ),
    );
  }
}

class _GatingBanner extends StatelessWidget {
  const _GatingBanner();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      alpha: 0.06,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 18, color: kAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Assistant is read-only. Agent and Builder may write files and '
              'save memories — every side effect asks for your approval first.',
              style: const TextStyle(
                  color: kSecondaryText, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});

  final Tool tool;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        alpha: 0.05,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              radius: 10,
              alpha: 0.07,
              padding: const EdgeInsets.all(7),
              child: Icon(
                tool.isSideEffecting
                    ? Icons.build_rounded
                    : Icons.arrow_outward_rounded,
                size: 16,
                color: tool.isSideEffecting ? kAccent : kSecondaryText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tool.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(tool.description,
                      style: const TextStyle(
                          color: kSecondaryText, fontSize: 12.5, height: 1.45)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Tag(tool.category),
                      if (tool.isSideEffecting) const _Tag('needs approval'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: glassFill(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(color: kSecondaryText, fontSize: 10.5)),
    );
  }
}
