import 'package:flutter/foundation.dart';

/// Owns the sidebar state (open/closed on compact layouts) and the current
/// route, so the sidebar can highlight the active section.
class ShellController extends ChangeNotifier {
  bool _drawerOpen = false;
  String _route = AppRoutes.chat;

  bool get drawerOpen => _drawerOpen;
  String get route => _route;

  void openDrawer() {
    if (!_drawerOpen) {
      _drawerOpen = true;
      notifyListeners();
    }
  }

  void closeDrawer() {
    if (_drawerOpen) {
      _drawerOpen = false;
      notifyListeners();
    }
  }

  void setRoute(String route) {
    if (_route != route) {
      _route = route;
      notifyListeners();
    }
  }
}

/// Route constants shared by the shell and the router so the sidebar never
/// drifts from the navigator.
class AppRoutes {
  static const String chat = '/';
  static const String automations = '/automations';
  static const String plugins = '/plugins';
  static const String settings = '/settings';
  static const String agentProviders = '/settings/agent-providers';
  static const String imageProviders = '/settings/image-providers';
  static const String videoProviders = '/settings/video-providers';
  static const String about = '/settings/about';

  /// A sub-route still belongs to its parent section for highlighting.
  static String sectionOf(String route) {
    for (final parent in [
      automations,
      plugins,
      agentProviders,
      imageProviders,
      videoProviders,
      about,
      settings,
    ]) {
      if (route == parent || route.startsWith('$parent/')) return parent;
    }
    return chat;
  }
}
