import 'package:flutter_test/flutter_test.dart';
import 'package:ilqeyte_mobile/core/models/provider_models.dart';
import 'package:ilqeyte_mobile/core/providers/builtin_catalog.dart';

void main() {
  test('builtin ids are unique within a kind', () {
    for (final kind in ProviderKind.values) {
      final ids = builtinsFor(kind).map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'duplicate ids for $kind');
    }
  });

  test('builtinsFor returns only that kind, alphabetized', () {
    for (final kind in ProviderKind.values) {
      final list = builtinsFor(kind);
      for (final b in list) {
        expect(b.kind, kind, reason: '${b.id} leaked into $kind');
      }
      final names = list.map((b) => b.name.toLowerCase()).toList();
      expect(names, equals([...names]..sort()),
          reason: '$kind list is not alphabetized');
    }
  });

  test('every entry carries a usable base URL, site and logo URL', () {
    for (final b in builtinProviders) {
      final base = Uri.tryParse(b.baseUrl);
      expect(base?.host.isNotEmpty, isTrue, reason: '${b.id}: bad baseUrl');
      expect(base?.scheme, anyOf('http', 'https'),
          reason: '${b.id}: baseUrl is not http(s)');
      expect(Uri.tryParse(b.site)?.host.isNotEmpty, isTrue,
          reason: '${b.id}: bad site');
      expect(b.logoUrl, contains('favicons'));
    }
  });

  test('builtinById resolves an entry and rejects the wrong kind', () {
    final openai = builtinById('openai', ProviderKind.agent);
    expect(openai, isNotNull);
    expect(openai!.name, 'OpenAI');
    expect(builtinById('openai', ProviderKind.image), isNull);
    expect(builtinById('does-not-exist', ProviderKind.agent), isNull);
  });

  test('the catalog covers every capability kind', () {
    expect(builtinsFor(ProviderKind.agent).length, greaterThan(20));
    expect(builtinsFor(ProviderKind.image), isNotEmpty);
    expect(builtinsFor(ProviderKind.video), isNotEmpty);
  });
}
