import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/liquid_glass.dart';
import '../../../core/models/provider_models.dart';
import '../../../core/providers/provider_store.dart';
import 'widgets/settings_scaffold.dart';

/// Creates or edits a [ProviderConfig] of any kind. The API key goes straight
/// to the secure vault — the database never sees it.
class ProviderFormPage extends StatefulWidget {
  const ProviderFormPage({super.key, required this.kind, this.provider});

  final ProviderKind kind;
  final ProviderConfig? provider;

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
  bool _discovering = false;
  String? _error;
  bool _saving = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _name = TextEditingController(text: p?.name ?? '');
    _baseUrl = TextEditingController(text: p?.baseUrl ?? '');
    _key = TextEditingController();
    _model = TextEditingController(text: p?.defaultModel ?? '');
    _protocol = p?.protocol ?? LlmProtocol.openaiCompatible;
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _name.text.trim().isNotEmpty && _baseUrl.text.trim().isNotEmpty;

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
      createdAt: DateTime.now(),
    );

    setState(() {
      _discovering = true;
      _error = null;
    });

    try {
      final models = await context.read<ProviderStore>().modelsFor(temp);
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

    final config = ProviderConfig(
      id: widget.provider?.id ?? _uuid.v4(),
      name: _name.text.trim(),
      kind: widget.kind,
      protocol: _protocol,
      baseUrl: _baseUrl.text.trim(),
      defaultModel: _model.text.trim().isEmpty ? null : _model.text.trim(),
      isDefault: widget.provider?.isDefault ?? false,
      createdAt: widget.provider?.createdAt ?? DateTime.now(),
    );

    setState(() => _saving = true);
    try {
      // The first provider of a kind becomes the default automatically;
      // otherwise the choice is preserved from the stored config.
      await store.save(
        config,
        apiKey: _key.text,
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
          _KeyField(
            controller: _key,
            obscure: _obscureKey,
            placeholder:
                editing ? 'Leave blank to keep the stored key' : 'sk-…',
            onToggle: () => setState(() => _obscureKey = !_obscureKey),
          ),
          const SizedBox(height: 16),
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
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kAccent : glassFill(0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : kPrimaryText,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
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
