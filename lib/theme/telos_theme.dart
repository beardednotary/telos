import 'package:flutter/material.dart';

/// Tactical terminal palette. True black for OLED, one functional accent.
class T {
  static const black = Color(0xFF0B0C0E);
  static const card = Color(0xFF16181D);

  /// A band that sits between black and card, for full-bleed sections that
  /// need separating without drawing yet another box.
  static const band = Color(0xFF101216);

  static const line = Color(0xFF2A2E36);
  static const dim = Color(0xFF6B7280);
  static const text = Color(0xFFE6E8EB);
  static const amber = Color(0xFFF5A623);
  static const cyan = Color(0xFF00E5FF);
  static const good = Color(0xFF3DD68C);
  static const bad = Color(0xFFE5484D);

  /// Each resource keeps one colour everywhere it appears, so the numbers are
  /// identifiable before you read the label.
  static const steel = Color(0xFFDDE3EA); // ALLOY

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
    fontSize: 15,
    height: 1.45,
  );

  static TextStyle label = mono.copyWith(
    color: dim,
    fontSize: 12,
    letterSpacing: 1.4,
  );

  /// THE RULE: anything 16px or larger is Light 300 with open tracking. That
  /// is what makes the countdown look carved rather than typed - it is not a
  /// different font, just weight and scale. Below 16px Light goes muddy, so
  /// small labels keep their weight and lean on [micro] instead.
  static TextStyle heading = display.copyWith(
    fontSize: 18,
    letterSpacing: 2.6,
  );

  static TextStyle data = mono.copyWith(fontSize: 15);

  /// The countdown, and nothing else. It should dominate the screen it is on.
  static TextStyle big = mono.copyWith(
    fontSize: 76,
    letterSpacing: -2,
    fontWeight: FontWeight.w300,
    height: 1.0,
  );

  /// A number that is the point of its section: a resource total, an
  /// integrity percentage. Scale contrast is what stops this reading as a
  /// generic dashboard - tiny labels are fine next to something this size.
  static TextStyle numeric = mono.copyWith(
    fontSize: 34,
    fontWeight: FontWeight.w300,
    height: 1.0,
    letterSpacing: -0.5,
  );

  static TextStyle title = display.copyWith(fontSize: 22, letterSpacing: 1.2);

  /// A row label in a list: still display-scale, so still Light.
  static TextStyle row = display.copyWith(fontSize: 18, letterSpacing: 2.0);

  /// Syne, used ONLY for names: sectors, the guild, screen titles. It has no
  /// Light weight, and that is deliberate - a heavy carved display set against
  /// thin machine readout is the whole contrast. Numbers stay in the mono.
  static TextStyle display = const TextStyle(
    fontFamily: 'Syne',
    fontVariations: [FontVariation('wght', 700)],
    color: text,
    fontSize: 22,
    letterSpacing: 1.0,
    // Syne has deep descenders. At 1.15 the tail of a g or y on a wrapped
    // line was being clipped by the line below it, and `even` splits the
    // leading above and below the text rather than piling it all on top,
    // which is what actually leaves room for the descender.
    height: 1.3,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static TextStyle micro = mono.copyWith(
    color: dim,
    fontSize: 11,
    letterSpacing: 1.6,
    height: 1.4,
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
        bodySmall: mono.copyWith(fontSize: 13),
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
