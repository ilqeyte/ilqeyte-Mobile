import 'package:flutter/material.dart';

import '../../features/automations/automations_page.dart';
import '../../features/shell/shell_controller.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/plugins/plugins_page.dart';
import '../../features/settings/about_page.dart';
import '../../features/settings/agent_providers_page.dart';
import '../../features/settings/image_providers_page.dart';
import '../../features/settings/settings_home_page.dart';
import '../../features/settings/video_providers_page.dart';

/// Flat route table. The shell's nested [Navigator] drives these; pushing a
/// sub-page also updates [ShellController.route] so the sidebar stays in sync.
class AppRouter {
  static const String chat = AppRoutes.chat;
  static const String automations = AppRoutes.automations;
  static const String plugins = AppRoutes.plugins;
  static const String settings = AppRoutes.settings;
  static const String agentProviders = AppRoutes.agentProviders;
  static const String imageProviders = AppRoutes.imageProviders;
  static const String videoProviders = AppRoutes.videoProviders;
  static const String about = AppRoutes.about;

  /// Every transition is a fade — nothing slides, nothing bounces.
  static Route<void> fadeRoute(WidgetBuilder builder, RouteSettings settings) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: child,
        );
      },
    );
  }

  static Route<void>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case chat:
        return fadeRoute((_) => const ChatScreen(), settings);
      case automations:
        return fadeRoute((_) => const AutomationsPage(), settings);
      case plugins:
        return fadeRoute((_) => const PluginsPage(), settings);
      case AppRouter.settings:
        return fadeRoute((_) => const SettingsHomePage(), settings);
      case agentProviders:
        return fadeRoute((_) => const AgentProvidersPage(), settings);
      case imageProviders:
        return fadeRoute((_) => const ImageProvidersPage(), settings);
      case videoProviders:
        return fadeRoute((_) => const VideoProvidersPage(), settings);
      case about:
        return fadeRoute((_) => const AboutPage(), settings);
    }
    return null;
  }
}
