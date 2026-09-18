import 'package:flutter/material.dart';

import '../../../app/theme/liquid_glass.dart';
import '../../../core/providers/builtin_catalog.dart';

/// A provider logo fetched from [BuiltinProvider.logoUrl], with a monogram
/// fallback so a failed fetch never leaves an empty tile.
class ProviderLogo extends StatelessWidget {
  const ProviderLogo({super.key, required this.builtin, this.size = 40});

  final BuiltinProvider builtin;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: glassFill(0.10),
          child: Image.network(
            builtin.logoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _Monogram(name: builtin.name),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Initials on glass — the offline stand-in for a favicon that never arrived.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final letters = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Center(
      child: Text(
        letters.isEmpty ? '?' : letters,
        style: const TextStyle(
          color: kSecondaryText,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
