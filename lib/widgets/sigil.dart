import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/telos_theme.dart';

/// A carved mark for each sector.
///
/// Drawn, not drawn-by-an-artist: every glyph is a handful of straight lines
/// and arcs in a unit square, so the whole system costs nothing to ship and
/// scales to any size. This is the one thing in the app that is a *shape*
/// rather than type in a box, which is most of the reason it exists - five
/// screens that each carry a different mark stop looking like one screen.
class Sigil extends StatelessWidget {
  const Sigil({
    super.key,
    required this.sectorId,
    required this.color,
    this.size = 40,
    this.strokeScale = 1.0,
  });

  final String sectorId;
  final Color color;
  final double size;
  final double strokeScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SigilPainter(sectorId, color, strokeScale),
      ),
    );
  }
}

class _SigilPainter extends CustomPainter {
  _SigilPainter(this.id, this.color, this.strokeScale);

  final String id;
  final Color color;
  final double strokeScale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07 * strokeScale
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;

    Offset p(double x, double y) => Offset(x * s, y * s);
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(p(x1, y1), p(x2, y2), paint);

    switch (id) {
      // MOSSWOOD VERGE - a treeline. Chevron over a stem, notched either side.
      case 'mosswood':
        line(0.5, 0.10, 0.14, 0.52);
        line(0.5, 0.10, 0.86, 0.52);
        line(0.5, 0.10, 0.5, 0.92);
        line(0.26, 0.62, 0.5, 0.44);
        line(0.74, 0.62, 0.5, 0.44);

      // BLACKSTONE HOLLOW - a descent. Nested wedges dropping into a floor.
      case 'blackstone':
        line(0.14, 0.14, 0.5, 0.52);
        line(0.86, 0.14, 0.5, 0.52);
        line(0.26, 0.42, 0.5, 0.68);
        line(0.74, 0.42, 0.5, 0.68);
        line(0.2, 0.9, 0.8, 0.9);

      // THE CINDER ARCHIVE - stacked pages, burned through the middle.
      case 'cinder':
        final r = Rect.fromLTWH(s * 0.16, s * 0.16, s * 0.68, s * 0.68);
        canvas.drawRect(r, paint);
        line(0.3, 0.38, 0.7, 0.38);
        line(0.3, 0.62, 0.7, 0.62);
        // the burn: a gap punched through the stack
        final gap = Paint()..color = T.black;
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(s * 0.5, s * 0.5),
                width: s * 0.2,
                height: s * 0.34),
            gap);

      // RIFTLINE DESCENT - a split. Two halves pulled apart down the middle.
      case 'riftline':
        line(0.5, 0.04, 0.5, 0.96);
        line(0.26, 0.2, 0.12, 0.5);
        line(0.12, 0.5, 0.26, 0.8);
        line(0.74, 0.2, 0.88, 0.5);
        line(0.88, 0.5, 0.74, 0.8);

      // THE SPIRE OF TELOS - a tower, banded, with something at the top.
      case 'spire':
        line(0.5, 0.06, 0.24, 0.94);
        line(0.5, 0.06, 0.76, 0.94);
        line(0.33, 0.52, 0.67, 0.52);
        line(0.28, 0.73, 0.72, 0.73);
        canvas.drawCircle(
            Offset(s * 0.5, s * 0.2), s * 0.07, paint..style = PaintingStyle.fill);

      // Fallback: a plain ring, so a new sector without a glyph still renders.
      default:
        canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.36, paint);
        line(0.5, 0.14, 0.5, 0.86);
    }
  }

  @override
  bool shouldRepaint(covariant _SigilPainter old) =>
      old.id != id || old.color != color || old.strokeScale != strokeScale;
}

/// A sigil set into a bordered plate, for places that need more presence than
/// the bare mark: the session screen, the debrief header.
class SigilPlate extends StatelessWidget {
  const SigilPlate({
    super.key,
    required this.sectorId,
    required this.color,
    this.size = 84,
  });

  final String sectorId;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.35)),
        color: color.withValues(alpha: 0.05),
      ),
      alignment: Alignment.center,
      child: Transform.rotate(
        angle: 0,
        child: Sigil(
          sectorId: sectorId,
          color: color,
          size: size * 0.52,
          strokeScale: max(0.8, 1.1 - size / 400),
        ),
      ),
    );
  }
}
