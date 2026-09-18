import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilqeyte_mobile/core/models/provider_models.dart';
import 'package:ilqeyte_mobile/core/providers/builtin_catalog.dart';
import 'package:ilqeyte_mobile/features/settings/widgets/provider_logo.dart';

void main() {
  testWidgets('ProviderLogo falls back to a monogram when the logo fails',
      (tester) async {
    final builtin = builtinById('openai', ProviderKind.agent);
    expect(builtin, isNotNull);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProviderLogo(builtin: builtin!))),
    );
    await tester.pump();

    expect(find.byType(ProviderLogo), findsOneWidget);
  });
}
