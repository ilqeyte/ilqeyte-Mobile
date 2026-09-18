import 'dart:ui';

import 'package:flutter/material.dart';

/// Pure black, translucent blur, no gradients, no hairlines. Depth comes
/// entirely from layered translucency — the Liquid Glass directive.

const Color kBlack = Color(0xFF000000);
const Color kAccent = Color(0xFF0A84FF);
const Color kPrimaryText = Color(0xFFF2F2F7);
const Color kSecondaryText = Color(0xFF8E8E93);
const Color kDanger = Color(0xFFFF453A);
const Color kSuccess = Color(0xFF30D158);

/// Translucent white of the given opacity. Uses `fromARGB` deliberately so the
/// code compiles on both pre- and post-`withValues` Flutter versions.
Color glassFill(double opacity) =>
    Color.fromARGB((opacity * 255).round(), 255, 255, 255);

ThemeData liquidGlassTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBlack,
    canvasColor: kBlack,
    colorScheme: const ColorScheme.dark(
      surface: kBlack,
      onSurface: kPrimaryText,
      primary: kAccent,
      onPrimary: Colors.white,
      secondary: Color(0xFFE5E5EA),
      onSecondary: kBlack,
      error: kDanger,
      onError: Colors.white,
    ),
    iconTheme: const IconThemeData(color: kSecondaryText, size: 22),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: kPrimaryText, fontSize: 15.5, height: 1.5),
      bodyLarge: TextStyle(color: kPrimaryText, fontSize: 17, height: 1.5),
      titleLarge:
          TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
      titleMedium:
          TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      labelLarge:
          TextStyle(color: kPrimaryText, fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium:
          TextStyle(color: kSecondaryText, fontSize: 13, fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      hintStyle: TextStyle(color: kSecondaryText),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: kAccent,
      selectionColor: Color(0x330A84FF),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(kSecondaryText),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
    ),
  );
}

/// A blurred, translucent surface — the building block of the whole UI.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 18,
    this.blur = 24,
    this.alpha = 0.05,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double blur;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter:
            ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.mirror),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: glassFill(alpha),
            borderRadius: BorderRadius.circular(radius),
          ),
          child:
              padding == null ? child : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}
