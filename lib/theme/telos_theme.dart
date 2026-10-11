import 'package:flutter/material.dart';

/// Cyanotype. A deep blue sheet, white line work, pencil annotation.
///
/// PHASE 0b. Values only again - every token keeps the name it had, so no
/// screen has to move to judge this.
///
/// Not sampled, and deliberately not. Sampling the reference sheets gave
/// dusty teal, because those prints are eighty years old and photographed
/// under warm light - the same mistake as taking a charter's yellowing for
/// a design decision. A cyanotype coming out of the wash is vivid. This is
/// that blue, saturated and properly cold.
///
/// A cyanotype is a negative process, which is why the line work is white.
///
/// This keeps the ground dark, which the app had real reasons for, while
/// being a specific document rather than a generic dark UI.
class T {
  /// The sheet, at its deepest.
  static const black = Color(0xFF06264A);

  /// The sheet proper, as sampled. Cards sit up off the ground.
  static const card = Color(0xFF0E4482);

  /// Between the two, for full-bleed sections that need separating without
  /// drawing yet another box.
  static const band = Color(0xFF0A3566);

  static const line = Color(0xFF2A6BB5);
  static const dim = Color(0xFF7FA8D4);

  /// The line work. White, because the process is a negative.
  static const text = Color(0xFFF0F6FF);

  /// Pencil, annotated over the print. The one warm thing on the sheet.
  static const amber = Color(0xFFFFAE5C);
  static const cyan = Color(0xFF8FD8FF);
  static const good = Color(0xFF5EE0A8);
  static const bad = Color(0xFFFF8070);

  /// Each resource keeps one colour everywhere it appears, so the numbers are
  /// identifiable before you read the label.
  static const steel = Color(0xFFC7D8EA); // ALLOY

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

  /// Quintessential. The printed layer of the form: every label, every
  /// heading, the title block, and running prose.
  ///
  /// A form is printed in one face and filled in with another. Mono used to
  /// be the voice of the whole app, which is the single loudest way a thing
  /// can say a developer made it - no document on earth is set in a
  /// typewriter face throughout. It is now only what gets typed into the
  /// fields: numbers, times, totals. Those need tabular figures and this
  /// face has old-style ones, so the split is practical as well as true.
  static const String printedFamily = 'Quintessential';

  static const TextStyle printed = TextStyle(
    fontFamily: printedFamily,
    color: text,
    fontSize: 16,
    height: 1.5,
  );

  /// Running prose: a journal line, a blurb, anything written in sentences.
  static TextStyle prose = printed.copyWith(fontSize: 17, height: 1.55);

  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    color: text,
    fontSize: 15,
    height: 1.45,
  );

  static TextStyle label = printed.copyWith(
    color: dim,
    fontSize: 14,
    letterSpacing: 1.0,
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

  /// Every label on every screen. Printed, not typed - this one style is
  /// most of what the app looks like.
  static TextStyle micro = printed.copyWith(
    color: dim,
    fontSize: 13,
    letterSpacing: 1.1,
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
