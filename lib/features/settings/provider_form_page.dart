import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme/liquid_glass.dart';
import '../../core/models/provider_models.dart';
import '../../core/providers/builtin_catalog.dart';
import '../../core/providers/provider_store.dart';
import 'widgets/provider_logo.dart';
import 'widgets/settings_scaffold.dart';

/// Creates or edits a [ProviderConfig] of any kind. The API key goes straight
/// to the secure vault — the database never sees it.
class ProviderFormPage extends StatefulWidget {
  const ProviderFormPage({
    super.key,
    required this.kind,
    this.provider,
    this.builtin,
  });

  final ProviderKind kind;
  final ProviderConfig? provider;

  /// A catalog entry the user picked: base URL, protocol and quirks are fixed,
  /// so the form only asks for a key and picks models from a live list.
  final BuiltinProvider? builtin;

  @override
  State<ProviderFormPage> createState() => _ProviderFormPageState();
}

class _ProviderFormPageState extends State<ProviderFormPage> {
  static const Uuid _uuid = Uuid();

  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _key;
  late final TextEditingController _model;

  late LlmProtocol _protocol;
  List<String> _models = [];
  List<String> _selected = [];
  bool _discovering = false;
  String? _error;
  bool _saving = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    final b = widget.builtin;
    _name = TextEditingController(text: p?.name ?? b?.name ?? '');
    _baseUrl = TextEditingController(text: p?.baseUrl ?? b?.baseUrl ?? '');
    _key = TextEditingController();
    _model = TextEditingController(text: p?.defaultModel ?? '');
    _protocol = p?.protocol ?? b?.protocol ?? LlmProtocol.openaiCompatible;
    _selected = p?.models.toList() ?? const [];
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  bool get _isBuiltin => widget.builtin != null;

  bool get _ensureV1 =>
      widget.builtin?.ensureV1 ?? widget.provider?.ensureV1 ?? true;

  /// The key to send to the endpoint right now: whatever is typed, falling back
  /// to the stored key when the field is blank (null keeps it untouched).
  String? get _effectiveKey {
    final typed = _key.text.trim();
    if (typed.isNotEmpty) return typed;
    if (widget.builtin?.localServer ?? false) return 'local';
    return null;
  }

  bool get _isValid =>
      _name.text.trim().isNotEmpty && _baseUrl.text.trim().isNotEmpty;

  /// Tap an undiscovered model to enable and activate it; tap the active one to
  /// disable it; tap another enabled model to promote it to active.
  void _toggleModel(String model) {
    setState(() {
      if (_selected.contains(model)) {
        if (_selected.first == model) {
          _selected.remove(model);
        } else {
          _selected.remove(model);
          _selected.insert(0, model);
        }
      } else {
        _selected.insert(0, model);
      }
    });
  }

  /// Probes the endpoint for its model list so the default is picked, not
  /// typed. Failures are soft: the field stays a free-text input.
  Future<void> _discover() async {
    if (_baseUrl.text.trim().isEmpty) return;

    final temp = ProviderConfig(
      id: widget.provider?.id ?? 'temp',
      name: _name.text.trim(),
      kind: widget.kind,
      protocol: _protocol,
      baseUrl: _baseUrl.text.trim(),
      ensureV1: _ensureV1,
      createdAt: DateTime.now(),
    );

    setState(() {
      _discovering = true;
      _error = null;
    });

    try {
      final models = await context
          .read<ProviderStore>()
          .modelsFor(temp, apiKey: _effectiveKey);
      setState(() {
        _models = models;
        _error = models.isEmpty ? 'No models found at that endpoint.' : null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  Future<void> _save() async {
    if (!_isValid) return;

    final store = context.read<ProviderStore>();
    final isFirst = store.ofKind(widget.kind).isEmpty;

    // For a builtin, the model list the user picked is the source of truth and
    // its first entry is the default; otherwise the free-text field is.
    final picked = _isBuiltin ? _selected : null;
    final config = ProviderConfig(
      id: widget.provider?.id ?? _uuid.v4(),
      name: _name.text.trim(),
      kind: widget.kind,
      protocol: _protocol,
      baseUrl: _baseUrl.text.trim(),
      defaultModel: (picked?.isNotEmpty ?? false)
          ? picked!.first
          : (_model.text.trim().isEmpty ? null : _model.text.trim()),
      ensureV1: _ensureV1,
      models: picked ?? widget.provider?.models ?? const [],
      isDefault: widget.provider?.isDefault ?? false,
      createdAt: widget.provider?.createdAt ?? DateTime.now(),
    );

    setState(() => _saving = true);
    try {
      // The first provider of a kind becomes the default automatically;
      // otherwise the choice is preserved from the stored config.
      // A locally-served endpoint has no key, but the agent loop's key check
      // needs a non-empty value — a placeholder keeps it moving.
      await store.save(
        config,
        apiKey: _effectiveKey,
        makeDefault: isFirst || config.isDefault,
      );
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.provider != null;

    return SettingsScaffold(
      title: editing ? 'Edit provider' : 'Add provider',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          if (_isBuiltin) ...[
            _BuiltinHeader(builtin: widget.builtin!),
            const SizedBox(height: 16),
          ] else ...[
            _Field(
              label: 'Name',
              controller: _name,
              hint: 'e.g. Personal OpenAI',
            ),
            const SizedBox(height: 16),
            const _Label('Protocol'),
            const SizedBox(height: 8),
            _ProtocolPicker(
              protocol: _protocol,
              onChanged: (p) => setState(() => _protocol = p),
            ),
            const SizedBox(height: 16),
            _Field(
              label: 'Base URL',
              controller: _baseUrl,
              hint: 'https://api.openai.com/v1',
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: 16),
          ],
          _KeyField(
            controller: _key,
            obscure: _obscureKey,
            placeholder: _isBuiltin && widget.builtin!.localServer
                ? 'Not required — any value works'
                : (editing ? 'Leave blank to keep the stored key' : 'sk-…'),
            onToggle: () => setState(() => _obscureKey = !_obscureKey),
          ),
          const SizedBox(height: 16),
          if (_isBuiltin)
            _BuiltinModels(
              models: _models,
              selected: _selected,
              discovering: _discovering,
              onDiscover: _discover,
              onToggle: _toggleModel,
            )
          else
            _ModelField(
              controller: _model,
              models: _models,
              discovering: _discovering,
              onDiscover: _discover,
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(
                    color: kDanger, fontSize: 12.5, height: 1.4)),
          ],
          const SizedBox(height: 28),
          _SaveButton(enabled: _isValid, saving: _saving, onTap: _save),
        ],
      ),
    );
  }

}

Widget _bareField(
  TextEditingController controller, {
  String? hint,
  TextInputType? keyboardType,
  bool autocorrect = true,
  bool obscure = false,
}) {
  return GlassCard(
    alpha: 0.06,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      autocorrect: autocorrect,
      obscureText: obscure,
      style: const TextStyle(color: kPrimaryText, fontSize: 15),
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        hintText: hint,
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.autocorrect = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 8),
        _bareField(
          controller,
          hint: hint,
          keyboardType: keyboardType,
          autocorrect: autocorrect,
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        text,
        style: const TextStyle(
            color: kSecondaryText, fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _KeyField extends StatelessWidget {
  const _KeyField({
    required this.controller,
    required this.obscure,
    required this.placeholder,
    required this.onToggle,
  });

  final TextEditingController controller;
  final bool obscure;
  final String placeholder;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('API key'),
        const SizedBox(height: 8),
        GlassCard(
          alpha: 0.06,
          padding: const EdgeInsets.only(left: 12, right: 2, top: 3, bottom: 3),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(color: kPrimaryText, fontSize: 15),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    hintText: placeholder,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: kSecondaryText,
                ),
                onPressed: onToggle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProtocolPicker extends StatelessWidget {
  const _ProtocolPicker({required this.protocol, required this.onChanged});

  final LlmProtocol protocol;
  final ValueChanged<LlmProtocol> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: glassFill(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final option in LlmProtocol.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: protocol == option
                        ? glassFill(0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    option.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: protocol == option ? Colors.white : kSecondaryText,
                      fontSize: 13,
                      fontWeight: protocol == option
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fixed identity of a catalog entry: logo, name, endpoint and caveats.
class _BuiltinHeader extends StatelessWidget {
  const _BuiltinHeader({required this.builtin});

  final BuiltinProvider builtin;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      alpha: 0.06,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ProviderLogo(builtin: builtin, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        builtin.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (builtin.experimental) ...[
                      const SizedBox(width: 6),
                      _ExperimentalBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  builtin.baseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kSecondaryText,
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                  ),
                ),
                if (builtin.note != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    builtin.note!,
                    style: const TextStyle(
                      color: kSecondaryText,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperimentalBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: glassFill(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        'experimental',
        style: TextStyle(
          color: kAccent,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Multi-select model list for a builtin endpoint: fetch once, then tap to
/// enable. The first enabled model is the one used by default.
class _BuiltinModels extends StatelessWidget {
  const _BuiltinModels({
    required this.models,
    required this.selected,
    required this.discovering,
    required this.onDiscover,
    required this.onToggle,
  });

  final List<String> models;
  final List<String> selected;
  final bool discovering;
  final VoidCallback onDiscover;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final active = selected.isEmpty ? null : selected.first;
    final chips = models.isEmpty ? selected : models;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _Label('Models'),
            const Spacer(),
            _DiscoverButton(loading: discovering, onTap: onDiscover),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          active == null
              ? 'Fetch the list, then tap the models you want. The first one you '
                  'tap is used by default.'
              : 'Using $active — tap another enabled model to switch, or tap the '
                  'active one to remove it.',
          style: const TextStyle(
            color: kSecondaryText,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final model in chips)
                _ModelChip(
                  label: model,
                  selected: model == active,
                  enabled: selected.contains(model),
                  onTap: () => onToggle(model),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ModelField extends StatelessWidget {
  const _ModelField({
    required this.controller,
    required this.models,
    required this.discovering,
    required this.onDiscover,
  });

  final TextEditingController controller;
  final List<String> models;
  final bool discovering;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Default model'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _bareField(controller, hint: 'gpt-4o-mini')),
            const SizedBox(width: 8),
            _DiscoverButton(loading: discovering, onTap: onDiscover),
          ],
        ),
        if (models.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final model in models)
                _ModelChip(
                  label: model,
                  selected: model == controller.text,
                  onTap: () => controller.text = model,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DiscoverButton extends StatelessWidget {
  const _DiscoverButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: glassFill(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: loading
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                    strokeWidth: 1.8, color: kAccent),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.manage_search_rounded, size: 16, color: kAccent),
                  SizedBox(width: 6),
                  Text('Models',
                      style: TextStyle(
                          color: kAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = false,
  });

  final String label;

  /// The one model in [enabled] that is currently used.
  final bool selected;

  /// Turned on by the user but not the active default.
  final bool enabled;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? kAccent
              : (enabled ? glassFill(0.14) : glassFill(0.08)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (enabled && !selected)
              const Padding(
                padding: EdgeInsets.only(right: 5),
                child: Icon(Icons.check_rounded, size: 13, color: kAccent),
              ),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : kPrimaryText,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.enabled,
    required this.saving,
    required this.onTap,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled && !saving ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.4,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: kAccent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Save provider',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}
