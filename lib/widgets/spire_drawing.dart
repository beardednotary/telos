import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/telos_theme.dart';

/// The Spire, drawn in the same carved strokes as the sigils.
///
/// Every course is a row of cut blocks, laid in a running bond and tapering
/// as it rises, the way the sigil's tower does. The old structure is in
/// stone grey with a string course every ten floors, so its scale reads
/// without counting. The player's floors go on top in amber. Above them sits
/// what the screen's own text describes: cut stone stacked ready, the
/// lifting frame left standing, mortar never mixed.
///
/// All geometry is seeded by course number, so the same floor always has
/// the same joints. No assets.
class SpireDrawing extends StatelessWidget {
  const SpireDrawing({
    super.key,
    required this.historical,
    required this.mine,
  });

  /// Floors standing before the player.
  final int historical;

  /// Floors the player has raised. Past [maxShown] the tower stops growing
  /// on screen and the caller says how many more there are.
  final int mine;

  static const maxShown = 40;
  static const _course = 7.0;
  static const _top = 34.0;
  static const _ground = 10.0;

  @override
  Widget build(BuildContext context) {
    final shown = mine.clamp(0, maxShown);
    final height = _top + (historical + shown) * _course + _ground;
    return LayoutBuilder(
      builder: (_, box) => CustomPaint(
        size: Size(box.maxWidth, height),
        painter: _SpirePainter(historical: historical, mine: shown),
      ),
    );
  }
}

class _SpirePainter extends CustomPainter {
  _SpirePainter({required this.historical, required this.mine});

  final int historical;
  final int mine;

  @override
  void paint(Canvas canvas, Size size) {
    const h = SpireDrawing._course;
    final w = size.width;
    final cx = w / 2;
    final total = historical + mine;

    // Base at 80% of the width; the old structure narrows to 44% at its top
    // and the player's floors keep the same slope.
    final base = w * 0.80;
    final step = (w * 0.36) / historical;
    double widthAt(int i) => max(base - i * step, w * 0.16);

    final baseY = size.height - SpireDrawing._ground;

    Paint stroke(Color c, double width) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt;

    final old = stroke(T.dim.withValues(alpha: 0.55), 1.1);
    final oldEdge = stroke(T.dim.withValues(alpha: 0.8), 1.3);
    final band = stroke(T.dim, 2.0);
    final ours = stroke(T.amber.withValues(alpha: 0.75), 1.1);
    final oursEdge = stroke(T.amber, 1.3);

    // Ground.
    canvas.drawLine(Offset(cx - w * 0.46, baseY + 4),
        Offset(cx + w * 0.46, baseY + 4), oldEdge);

    for (var i = 0; i < total; i++) {
      final isMine = i >= historical;
      final cw = widthAt(i);
      final left = cx - cw / 2;
      final bottom = baseY - i * h;
      final top = bottom - h;
      final joint = isMine ? ours : old;
      final edge = isMine ? oursEdge : oldEdge;

      // Outer faces of the course.
      canvas.drawLine(Offset(left, bottom), Offset(left, top), edge);
      canvas.drawLine(Offset(left + cw, bottom), Offset(left + cw, top), edge);
      // Bed joint.
      canvas.drawLine(Offset(left, top), Offset(left + cw, top), joint);

      // Head joints: roughly one block per 26px, shifted half a block on
      // alternate courses so no joint runs straight up.
      final rng = Random(i * 7919 + 17);
      final blocks = max(2, (cw / 26).round());
      final bw = cw / blocks;
      final shift = i.isOdd ? bw / 2 : 0.0;
      for (var b = 1; b <= blocks; b++) {
        final x = left + shift + b * bw + (rng.nextDouble() - 0.5) * bw * 0.3;
        if (x <= left + 3 || x >= left + cw - 3) continue;
        // Weathered: now and then a joint in the old stone has gone.
        if (!isMine && rng.nextDouble() < 0.08) continue;
        canvas.drawLine(Offset(x, bottom), Offset(x, top), joint);
      }

      // A string course every ten floors of the old structure.
      if (!isMine && (i + 1) % 10 == 0 && i + 1 < historical) {
        canvas.drawLine(
            Offset(left - 3, top), Offset(left + cw + 3, top), band);
      }
    }

    // The top course: unfinished.
    final topY = baseY - total * h;
    final tw = widthAt(total);
    final tl = cx - tw / 2;
    final last = mine > 0 ? oursEdge : oldEdge;
    canvas.drawLine(Offset(tl, topY), Offset(tl + tw, topY), last);

    // Cut stone stacked ready, off to one side.
    final stone = stroke(T.dim, 1.2);
    final sx = tl + tw * 0.58;
    for (final r in [
      Rect.fromLTWH(sx, topY - h, 22, h),
      Rect.fromLTWH(sx + 22, topY - h, 18, h),
      Rect.fromLTWH(sx + 8, topY - h * 2, 20, h),
    ]) {
      canvas.drawRect(r, stone);
    }

    // The lifting frame still standing: two legs leaning together, a rope
    // hanging from where they meet, nothing on the end of it.
    final px = tl + tw * 0.24;
    final apex = Offset(px + 4, topY - 32);
    canvas.drawLine(Offset(px - 8, topY), apex, stone);
    canvas.drawLine(Offset(px + 10, topY), apex, stone);
    canvas.drawLine(apex, Offset(apex.dx, topY - 12), stroke(T.dim, 0.8));
  }

  @override
  bool shouldRepaint(covariant _SpirePainter old) =>
      old.historical != historical || old.mine != mine;
}
