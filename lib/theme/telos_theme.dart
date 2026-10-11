import 'package:flutter/material.dart';

/// Night Watch. Legacy token names remain during the screen migration.
class T {
  static const black = Color(0xFF1E252B);
  static const card = Color(0xFF272F35);
  static const band = Color(0xFF12181D);
  static const raised = Color(0xFF313B42);
  static const line = Color(0xFF4D5E67);
  static const boundary = Color(0xFF677A83);
  static const dim = Color(0xFFACBBC1);
  static const text = Color(0xFFE6EAEB);
  static const amber = Color(0xFFD3B779);
  static const onAccent = Color(0xFF242920);
  static const cyan = Color(0xFF9EBBC9);
  static const good = Color(0xFFABD1AB);
  static const bad = Color(0xFFED9A94);
  static const steel = text;

  static const body = TextStyle(
    fontFamily: 'IBMPlexSans',
    color: text,
    fontSize: 16,
    height: 1.4,
  );
  static final secondary = body.copyWith(fontSize: 14, color: dim);
  static const display = TextStyle(
    fontFamily: 'IBMPlexSansCondensed',
    fontWeight: FontWeight.w600,
    color: text,
    fontSize: 28,
    height: 1.15,
  );
  static final title = display.copyWith(fontSize: 22);
  static final heading = display.copyWith(fontSize: 18);
  static final row = display.copyWith(fontSize: 18);

  /// Quantities and time keep a fixed-width face. Prose uses Plex Sans.
  static const monoFamily = 'JetBrainsMono';
  static const monoFallback = <String>[
    'SF Mono',
    'Menlo',
    'Consolas',
    'Roboto Mono',
    'monospace',
  ];
  static const mono = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    color: text,
    fontSize: 15,
    height: 1.45,
  );
  static final label = mono.copyWith(
    color: dim,
    fontSize: 12,
    letterSpacing: 1,
  );
  static final micro = label.copyWith(fontSize: 11, letterSpacing: .6);
  static final data = mono.copyWith(fontSize: 15);
  static final big = mono.copyWith(
    fontSize: 76,
    letterSpacing: -2,
    fontWeight: FontWeight.w300,
    height: 1,
  );
  static final numeric = mono.copyWith(
    fontSize: 34,
    letterSpacing: -.5,
    fontWeight: FontWeight.w300,
    height: 1,
  );

  static ThemeData theme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: black,
        canvasColor: black,
        fontFamily: 'IBMPlexSans',
        colorScheme: const ColorScheme.dark(
          surface: black,
          primary: amber,
          onPrimary: onAccent,
          secondary: cyan,
          secondaryContainer: raised,
          onSecondaryContainer: text,
          error: bad,
          onSurface: text,
        ),
        textTheme: TextTheme(
          bodyMedium: body,
          bodySmall: secondary,
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
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: black,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: boundary),
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: band,
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: boundary),
          ),
          labelStyle: secondary,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: card,
          selectedColor: raised,
          checkmarkColor: amber,
          labelStyle: body,
          side: const BorderSide(color: boundary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: amber,
          inactiveTrackColor: line,
          thumbColor: amber,
        ),
        dividerColor: line,
        dividerTheme: const DividerThemeData(color: line, thickness: 1),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: raised,
          contentTextStyle: body,
          actionTextColor: amber,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      );
}
