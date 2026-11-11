import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/telos_theme.dart';

/// Telos is laid out for a phone. On anything wider - an iPad, a phone on
/// its side, a large Split View pane - the same layout sits in a centred
/// column instead of stretching panels and illustrations across the glass.
///
/// The column reports its own width as the screen size, so everything that
/// sizes itself from MediaQuery (illustration heights, sheet layouts) sees
/// the column. Routes, dialogs and bottom sheets all open inside it, because
/// it wraps the app's Navigator.
class WideLayout extends StatelessWidget {
  const WideLayout({super.key, required this.child});

  final Widget child;

  /// Wide enough for the phone layout to breathe, narrow enough that a line
  /// of body text stays easy to read.
  static const double maxWidth = 640;

  /// For [MaterialApp.builder].
  static Widget builder(BuildContext context, Widget? child) =>
      WideLayout(child: child ?? const SizedBox.shrink());

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    if (width <= maxWidth) return child;

    // Insets belong to the glass. Whatever of them the margins already
    // cover (a phone's notch on its side, say) no longer applies inside.
    final margin = (width - maxWidth) / 2;
    EdgeInsets inside(EdgeInsets e) => e.copyWith(
          left: math.max(0.0, e.left - margin),
          right: math.max(0.0, e.right - margin),
        );

    return ColoredBox(
      color: T.band,
      child: Align(
        alignment: Alignment.topCenter,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: const BoxDecoration(
            border: Border.symmetric(vertical: BorderSide(color: T.line)),
          ),
          child: SizedBox(
            width: maxWidth,
            height: double.infinity,
            child: MediaQuery(
              data: media.copyWith(
                size: Size(maxWidth, media.size.height),
                padding: inside(media.padding),
                viewPadding: inside(media.viewPadding),
                viewInsets: inside(media.viewInsets),
                systemGestureInsets: inside(media.systemGestureInsets),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
