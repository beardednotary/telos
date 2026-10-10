import 'package:flutter/material.dart';

/// Working field document: cool paper, graphite, one process red.
///
/// PHASE 0 of the paper conversion. Values only - every name is still the
/// name it was, so no screen had to move to see this. The names are now
/// wrong for what they hold (`black` is paper, `amber` is red) and get
/// renamed to their roles in the next pass, once this has been looked at
/// on a real screen.
///
/// Sampled from the reference documents rather than picked: the greys come
/// off USGS graph paper, the ink off a modern fault plate. Deliberately
/// cool. The warm creams in the old charters are 280 years of oxidation,
/// not a design decision, and this company was working eleven years ago.
class T {
  /// The page.
  static const black = Color(0xFFE8E7E2);

  /// A slip laid on the page. Lighter than the page, as paper on paper is.
  static const card = Color(0xFFF7F6F2);

  /// Between the two, for full-bleed sections that need separating without
  /// drawing yet another box.
  static const band = Color(0xFFF0EFEA);

  static const line = Color(0xFFC8CBC9);
  static const dim = Color(0xFF8B8B85);
  static const text = Color(0xFF2A2A28);

  /// The process red of a printed rule. One mark colour on the page.
  static const amber = Color(0xFFC8402F);
  static const cyan = Color(0xFF2B5E8A);
  static const good = Color(0xFF3F7A52);
  static const bad = Color(0xFF8C2318);

  /// Each resource keeps one colour everywhere it appears, so the numbers are
  /// identifiable before you read the label.
  static const steel = Color(0xFF5A5A54); // ALLOY

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
  static TextStyle display = TextStyle(
    fontFamily: 'Syne',
    fontVariations: const [FontVariation('wght', 700)],
    color: text,
    fontSize: 22,
    letterSpacing: 1.0,
    // Syne has deep descenders. At 1.15 the tail of a g or y on a wrapped
    // line was being clipped by the line below it, and `even` splits the
    // leading above and below the text rather than piling it all on top,
    // which is what actually leaves room for the descender.
    height: 1.3,
    leadingDistribution: TextLeadingDistribution.even,
    // Syne's default g hangs its tail off the bowl as a separate hooked
    // stroke, which at title size reads as two glyphs overlapping. Stylistic
    // set 4 swaps in the font's own closed two-storey g, and touches nothing
    // else.
    fontFeatures: [FontFeature.stylisticSet(4)],
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
      brightness: Brightness.light,
      scaffoldBackgroundColor: black,
      canvasColor: black,
      colorScheme: const ColorScheme.light(
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
