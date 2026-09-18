import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/router.dart';
import '../../../app/theme/liquid_glass.dart';
import '../../../core/models/provider_models.dart';
import '../../../core/providers/provider_store.dart';
import '../provider_form_page.dart';
import 'settings_scaffold.dart';

/// A provider list for one capability kind. The agent, image and video settings
/// pages all delegate here — the only differences are [kind] and the copy.
class ProvidersPage extends StatelessWidget {
  const ProvidersPage({
    super.key,
    required this.kind,
    required this.title,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final ProviderKind kind;
  final String title;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context) {
    final providers = context.watch<ProviderStore>().ofKind(kind);

    return SettingsScaffold(
      title: title,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: const Icon(Icons.add_rounded, size: 24),
            onPressed: () => _pushForm(context, null),
          ),
        ),
      ],
      child: providers.isEmpty
          ? _EmptyProviders(
              title: emptyTitle,
              body: emptyBody,
              onAdd: () => _pushForm(context, null),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                for (final provider in providers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ProviderTile(provider: provider, kind: kind),
                  ),
              ],
            ),
    );
  }

  void _pushForm(BuildContext context, ProviderConfig? provider) {
    Navigator.of(context).push(
      AppRouter.fadeRoute(
        (_) => ProviderFormPage(kind: kind, provider: provider),
        const RouteSettings(name: 'provider-form'),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider, required this.kind});

  final ProviderConfig provider;
  final ProviderKind kind;

  void _edit(BuildContext context) {
    Navigator.of(context).push(
      AppRouter.fadeRoute(
        (_) => ProviderFormPage(kind: kind, provider: provider),
        const RouteSettings(name: 'provider-form'),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kBlack,
        title: const Text('Delete provider?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'The API key for ${provider.name} is removed from the secure vault.',
          style: const TextStyle(color: kSecondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: kDanger)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      alpha: 0.05,
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _edit(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          provider.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (provider.isDefault) ...[
                        const SizedBox(width: 8),
                        const _DefaultChip(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(provider.protocol.label,
                      style: const TextStyle(
                          color: kSecondaryText, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(provider.baseUrl,
                      style: const TextStyle(
                          color: kSecondaryText, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  if (provider.defaultModel != null) ...[
                    const SizedBox(height: 2),
                    Text('model: ${provider.defaultModel}',
                        style: const TextStyle(
                            color: kAccent,
                            fontSize: 12,
                            fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
          PopupMenuButton<_Action>(
            color: kBlack,
            icon: const Icon(Icons.more_horiz_rounded,
                color: kSecondaryText, size: 20),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _Action.default_,
                enabled: !provider.isDefault,
                child: const Text('Set as default'),
              ),
              const PopupMenuItem(value: _Action.edit, child: Text('Edit')),
              const PopupMenuItem(value: _Action.delete, child: Text('Delete')),
            ],
            onSelected: (action) async {
              final store = context.read<ProviderStore>();
              switch (action) {
                case _Action.default_:
                  await store.setDefault(provider.id, kind);
                  break;
                case _Action.edit:
                  _edit(context);
                  break;
                case _Action.delete:
                  if (await _confirmDelete(context)) {
                    await store.remove(provider.id, kind);
                  }
                  break;
              }
            },
          ),
        ],
      ),
    );
  }
}

enum _Action { default_, edit, delete }

class _DefaultChip extends StatelessWidget {
  const _DefaultChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: glassFill(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'default',
        style: TextStyle(
            color: kAccent, fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyProviders extends StatelessWidget {
  const _EmptyProviders({
    required this.title,
    required this.body,
    required this.onAdd,
  });

  final String title;
  final String body;
  final VoidCallback onAdd;

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
              child: const Icon(Icons.cloud_off_rounded,
                  size: 32, color: kSecondaryText),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: kSecondaryText, fontSize: 14, height: 1.5)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add provider'),
            ),
          ],
        ),
      ),
    );
  }
}
