import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/provider_models.dart';
import '../storage/database.dart';
import '../storage/vault.dart';
import 'registry.dart';

/// Owns provider configuration for the three capability kinds. Agent, image
/// and video providers are kept in strictly separate lists — settings shows
/// each on its own page — and API keys live only in the secure vault.
class ProviderStore extends ChangeNotifier {
  ProviderStore(this._db, this._vault, this._dio);

  final DatabaseService _db;
  final SecureVault _vault;
  final Dio _dio;

  final Map<ProviderKind, List<ProviderConfig>> _byKind = {};
  final Map<String, String> _keys = {};

  bool _loaded = false;
  bool get isLoaded => _loaded;

  List<ProviderConfig> ofKind(ProviderKind kind) =>
      List.unmodifiable(_byKind[kind] ?? const []);

  /// The provider used when none is chosen explicitly.
  ProviderConfig? defaultOf(ProviderKind kind) {
    final list = _byKind[kind] ?? const [];
    for (final p in list) {
      if (p.isDefault) return p;
    }
    return list.isEmpty ? null : list.first;
  }

  Future<void> load() async {
    final all = _db.providers();
    _byKind.clear();
    for (final p in all) {
      _byKind.putIfAbsent(p.kind, () => []).add(p);
    }
    _loaded = true;
    notifyListeners();
  }

  /// Creates or updates a provider. A null [apiKey] leaves the stored key
  /// untouched; an empty string clears it.
  Future<void> save(
    ProviderConfig config, {
    String? apiKey,
    bool makeDefault = false,
  }) async {
    final updated = makeDefault ? config.copyWith(isDefault: true) : config;
    if (apiKey != null) {
      if (apiKey.isEmpty) {
        await _vault.delete(updated.id);
        _keys.remove(updated.id);
      } else {
        await _vault.write(updated.id, apiKey);
        _keys[updated.id] = apiKey;
      }
    }
    if (makeDefault) {
      for (final p in ofKind(updated.kind)) {
        _db.upsertProvider(p.copyWith(isDefault: p.id == updated.id));
      }
      _byKind[updated.kind] =
          _db.providers(kind: updated.kind);
    } else {
      _db.upsertProvider(updated);
      _byKind.putIfAbsent(updated.kind, () => []);
      final list = _byKind[updated.kind]!;
      final i = list.indexWhere((p) => p.id == updated.id);
      if (i >= 0) {
        list[i] = updated;
      } else {
        list.add(updated);
      }
    }
    notifyListeners();
  }

  Future<void> remove(String id, ProviderKind kind) async {
    await _vault.delete(id);
    _keys.remove(id);
    _db.deleteProvider(id);
    _byKind[kind]?.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<void> setDefault(String id, ProviderKind kind) async {
    for (final p in ofKind(kind)) {
      _db.upsertProvider(p.copyWith(isDefault: p.id == id));
    }
    _byKind[kind] = _db.providers(kind: kind);
    notifyListeners();
  }

  /// The plaintext key for a provider, cached in memory after first use.
  Future<String?> keyOf(String id) async {
    if (_keys.containsKey(id)) return _keys[id];
    final key = await _vault.read(id);
    if (key != null) _keys[id] = key;
    return key;
  }

  /// Best-effort model discovery for the settings form.
  Future<List<String>> modelsFor(ProviderConfig provider) async {
    final adapter = adapterFor(provider.protocol, _dio);
    final key = await keyOf(provider.id);
    return adapter.listModels(provider: provider, apiKey: key);
  }
}
