import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/router.dart';
import '../../app/theme/liquid_glass.dart';
import 'shell_controller.dart';
import 'sidebar.dart';

/// The app's frame: a persistent sidebar on wide screens, a slide-in drawer on
/// compact ones, always wrapping a nested [Navigator] so the content stack is
/// independent of the shell.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 840;

    if (wide) {
      return ColoredBox(
        color: kBlack,
        child: Row(
          children: const [
            SizedBox(width: 264, child: Sidebar()),
            Expanded(child: _Body()),
          ],
        ),
      );
    }

    final drawerOpen = context.watch<ShellController>().drawerOpen;

    return ColoredBox(
      color: kBlack,
      child: Stack(
        children: [
          const Positioned.fill(child: _Body()),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !drawerOpen,
              child: AnimatedOpacity(
                opacity: drawerOpen ? 1 : 0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: GestureDetector(
                  onTap: () =>
                      context.read<ShellController>().closeDrawer(),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: glassFill(0.35)),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !drawerOpen,
              child: AnimatedSlide(
                offset: drawerOpen ? Offset.zero : const Offset(-1.15, 0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(width: 288, child: Sidebar()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: AppRouter.contentKey,
      initialRoute: AppRoutes.chat,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
