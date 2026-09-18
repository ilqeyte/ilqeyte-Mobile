import 'package:flutter/material.dart';

import '../../core/models/provider_models.dart';
import 'widgets/providers_page.dart';

class VideoProvidersPage extends StatelessWidget {
  const VideoProvidersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProvidersPage(
      kind: ProviderKind.video,
      title: 'Video providers',
      emptyTitle: 'No video provider yet',
      emptyBody: 'Add an endpoint that serves video generation. Agent and chat '
          'work fine without one — this only unlocks generated media.',
    );
  }
}
