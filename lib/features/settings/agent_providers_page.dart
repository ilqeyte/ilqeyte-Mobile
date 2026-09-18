import 'package:flutter/material.dart';

import '../../core/models/provider_models.dart';
import 'widgets/providers_page.dart';

class AgentProvidersPage extends StatelessWidget {
  const AgentProvidersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProvidersPage(
      kind: ProviderKind.agent,
      title: 'Agent providers',
      emptyTitle: 'No agent provider yet',
      emptyBody: 'Add an OpenAI- or Anthropic-compatible endpoint. Until then, '
          'chat stays local and read-only.',
    );
  }
}
