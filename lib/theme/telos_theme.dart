import 'package:flutter/material.dart';

/// Tactical terminal palette. True black for OLED, one functional accent.
class T {
  static const black = Color(0xFF0B0C0E);
  static const card = Color(0xFF16181D);
  static const line = Color(0xFF2A2E36);
  static const dim = Color(0xFF6B7280);
  static const text = Color(0xFFE6E8EB);
  static const amber = Color(0xFFF5A623);
  static const cyan = Color(0xFF00E5FF);
  static const good = Color(0xFF3DD68C);
  static const bad = Color(0xFFE5484D);

  /// Bundled at three weights (300/400/600), so every device renders the same
  /// thing. The platform stack stays as insurance for any glyph JetBrains Mono
  /// does not cover.
  static const String monoFamily = 'JetBrainsMono';

  static const monoFallback = <String>[
    'SF Mono',
    'Menlo',
    'Consolas',
    'Roboto Mono',
    'monospace',
  ];

  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    color: text,
    fontSize: 13,
    height: 1.45,
  );

  static TextStyle label = mono.copyWith(
    color: dim,
    fontSize: 11,
    letterSpacing: 1.4,
  );

  static TextStyle heading = mono.copyWith(
    fontSize: 15,
    letterSpacing: 2.0,
    fontWeight: FontWeight.w600,
  );

  static TextStyle data = mono.copyWith(fontSize: 13);

  static TextStyle big = mono.copyWith(
    fontSize: 46,
    letterSpacing: 2,
    fontWeight: FontWeight.w300,
    height: 1.1,
  );

  static ThemeData theme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      canvasColor: black,
      colorScheme: const ColorScheme.dark(
        surface: black,
        primary: amber,
        secondary: cyan,
        error: bad,
      ),
      textTheme: TextTheme(
        bodyMedium: mono,
        bodySmall: mono.copyWith(fontSize: 12),
        titleMedium: heading,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: heading,
        iconTheme: const IconThemeData(color: dim, size: 20),
      ),
      dividerColor: line,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
