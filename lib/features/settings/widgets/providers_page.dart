import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/router.dart';
import '../../../app/theme/liquid_glass.dart';
import '../../../core/models/provider_models.dart';
import '../../../core/providers/builtin_catalog.dart';
import '../../../core/providers/provider_store.dart';
import '../provider_form_page.dart';
import 'provider_logo.dart';
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _BuiltinGallery(
            kind: kind,
            onPick: (b) => _pushForm(context, null, builtin: b),
          ),
          const SizedBox(height: 22),
          if (providers.isEmpty)
            SizedBox(
              height: 280,
              child: _EmptyProviders(
                title: emptyTitle,
                body: emptyBody,
                onAdd: () => _pushForm(context, null),
              ),
            )
          else ...[
            const _SectionLabel('Your providers'),
            const SizedBox(height: 10),
            for (final provider in providers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ProviderTile(provider: provider, kind: kind),
              ),
          ],
        ],
      ),
    );
  }

  void _pushForm(
    BuildContext context,
    ProviderConfig? provider, {
    BuiltinProvider? builtin,
  }) {
    Navigator.of(context).push(
      AppRouter.fadeRoute(
        (_) => ProviderFormPage(
          kind: kind,
          provider: provider,
          builtin: builtin,
        ),
        const RouteSettings(name: 'provider-form'),
      ),
    );
  }
}

/// Matches a saved config back to its catalog entry by endpoint, so a tile can
/// show a logo without the config carrying a builtin id.
BuiltinProvider? matchBuiltin(ProviderConfig provider) {
  for (final b in builtinProviders) {
    if (b.kind == provider.kind && b.baseUrl == provider.baseUrl) return b;
  }
  return null;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: kSecondaryText,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The catalog: every built-in endpoint for this kind behind a search field.
/// Tapping a card opens the form with everything but the key pre-filled.
class _BuiltinGallery extends StatefulWidget {
  const _BuiltinGallery({required this.kind, required this.onPick});

  final ProviderKind kind;
  final ValueChanged<BuiltinProvider> onPick;

  @override
  State<_BuiltinGallery> createState() => _BuiltinGalleryState();
}

class _BuiltinGalleryState extends State<_BuiltinGallery> {
  late final TextEditingController _search;
  List<BuiltinProvider> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _filtered = builtinsFor(widget.kind);
    _search = TextEditingController();
    _search.addListener(_filter);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? builtinsFor(widget.kind)
          : builtinsFor(widget.kind)
              .where((b) => b.name.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = builtinsFor(widget.kind);
    if (all.isEmpty) return const SizedBox.shrink();
    final searching = _search.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Built-in providers (${all.length})'),
        const SizedBox(height: 8),
        GlassCard(
          alpha: 0.06,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: TextField(
            controller: _search,
            autocorrect: false,
            style: const TextStyle(color: kPrimaryText, fontSize: 15),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              hintText: 'Search ${all.length} providers…',
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_filtered.isEmpty)
          const Text('No provider matches that search.',
              style: TextStyle(color: kSecondaryText, fontSize: 13))
        else if (searching)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in _filtered)
                _BuiltinCard(b, onTap: () => widget.onPick(b)),
            ],
          )
        else
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _BuiltinCard(_filtered[i],
                  onTap: () => widget.onPick(_filtered[i])),
            ),
          ),
      ],
    );
  }
}

class _BuiltinCard extends StatelessWidget {
  const _BuiltinCard(this.builtin, {required this.onTap});

  final BuiltinProvider builtin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlassCard(
        alpha: 0.06,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: SizedBox(
          width: 62,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ProviderLogo(builtin: builtin, size: 32),
                  if (builtin.experimental)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: kAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                builtin.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kPrimaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
    final logo = matchBuiltin(provider);
    return GlassCard(
      alpha: 0.05,
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      child: Row(
        children: [
          if (logo != null) ...[
            ProviderLogo(builtin: logo, size: 36),
            const SizedBox(width: 10),
          ],
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
