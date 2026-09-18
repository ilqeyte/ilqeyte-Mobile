import 'package:flutter/material.dart';

import '../../../core/models/provider_models.dart';
import 'widgets/providers_page.dart';

class ImageProvidersPage extends StatelessWidget {
  const ImageProvidersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProvidersPage(
      kind: ProviderKind.image,
      title: 'Image providers',
      emptyTitle: 'No image provider yet',
      emptyBody: 'Add an endpoint that serves image generation. Agent and chat '
          'work fine without one — this only unlocks generated media.',
    );
  }
}
