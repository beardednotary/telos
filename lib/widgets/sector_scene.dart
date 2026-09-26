import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/telos_theme.dart';

/// A sector drawn as a place, in the sigils' carved strokes.
///
/// The place itself is always drawn whole: there is nothing to uncover, so
/// it can never become a completion bar. What changes is the player's own
/// stakes on it, in amber, the way their floors go on the Spire. Every run
/// in the sector leaves one at the depth it reached, so the scene is a map
/// of how far the player's runs have gone. Stakes are never counted and
/// never taken away: a month away costs nothing here either.
///
/// The old company's stakes are the depth scale: 25, 50, 75 and 100%. The
/// road runs on past the last of them, to the 160% the engine allows.
///
/// Geometry is seeded, so a sector always looks the same. No assets.
class SectorScene extends StatelessWidget {
  const SectorScene({
    super.key,
    required this.sectorId,
    required this.color,
    this.depths = const [],
    this.latest,
    this.height = 132,
  });

  /// Sectors with a scene drawn. The rest keep their sigil plate for now.
  static bool has(String sectorId) => sectorId == 'mosswood';

  final String sectorId;

  /// The sector's own accent. The land is drawn in it, faintly.
  final Color color;

  /// Depths reached by earlier runs here, 0 to 1.6.
  final List<double> depths;

  /// The run being debriefed. Its stake is drawn bright and carved in.
  final double? latest;

  final double height;

  @override
  Widget build(BuildContext context) {
    CustomPaint paint(double t) => CustomPaint(
          size: Size.fromHeight(height),
          painter: _ScenePainter(sectorId, color, depths, latest, t),
        );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: latest == null
          ? paint(1)
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOutCubic,
              builder: (_, t, __) => paint(t),
            ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(
      this.sectorId, this.color, this.depths, this.latest, this.progress);

  final String sectorId;
  final Color color;
  final List<double> depths;
  final double? latest;
  final double progress;

  /// Where a depth stands along the road.
  static double _x(double depth, double w) =>
      w * (0.03 + 0.94 * depth.clamp(0.0, 1.6) / 1.6);

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.miter;

  @override
  void paint(Canvas canvas, Size size) {
    switch (sectorId) {
      case 'mosswood':
        _mosswood(canvas, size);
    }
  }

  // MOSSWOOD VERGE - the treeline along the old service road, the cache in
  // a clearing, and the survey stakes: theirs in stone, ours in amber, cut
  // the same way.
  void _mosswood(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ground = h * 0.86;
    final land = _stroke(color.withValues(alpha: 0.5), 1.2);
    final far = _stroke(color.withValues(alpha: 0.22), 1.0);
    final rng = Random(101);

    // Ground and the road's two edges running along it.
    canvas.drawLine(Offset(0, ground), Offset(w, ground), land);
    canvas.drawLine(
        Offset(0, ground + 7), Offset(w, ground + 7), far);

    // The treeline, two ranks deep, with a clearing round the cache.
    void tree(double x, double top, Paint p) {
      final spread = (ground - top) * 0.34;
      final mid = top + (ground - top) * 0.5;
      canvas.drawPath(
          Path()
            ..moveTo(x - spread, mid)
            ..lineTo(x, top)
            ..lineTo(x + spread, mid),
          p);
      canvas.drawLine(Offset(x, top), Offset(x, ground), p);
      final bt = top + (ground - top) * 0.34;
      final bb = top + (ground - top) * 0.62;
      canvas.drawLine(Offset(x - spread * 0.6, bb), Offset(x, bt), p);
      canvas.drawLine(Offset(x + spread * 0.6, bb), Offset(x, bt), p);
    }

    bool clearing(double x) => x > w * 0.56 && x < w * 0.74;

    for (var x = w * 0.03; x < w; x += w * (0.07 + rng.nextDouble() * 0.04)) {
      if (clearing(x)) continue;
      tree(x, h * (0.16 + rng.nextDouble() * 0.14), far);
    }
    for (var x = w * 0.06; x < w; x += w * (0.10 + rng.nextDouble() * 0.06)) {
      if (clearing(x)) continue;
      tree(x, h * (0.08 + rng.nextDouble() * 0.12), land);
    }

    // The cache in the clearing: a stocked box, lid square.
    canvas.drawRect(
        Rect.fromLTWH(w * 0.64, ground - 11, 18, 11), land);
    canvas.drawLine(Offset(w * 0.64, ground - 7),
        Offset(w * 0.64 + 18, ground - 7), far);

    _stakes(canvas, size, ground);
  }

  /// Survey stakes, each with its pennant. Never a crossbar: a row of those
  /// reads as graves.
  void _stakes(Canvas canvas, Size size, double ground) {
    final w = size.width;
    Path stake(double x, double tall) {
      final top = ground - tall;
      return Path()
        ..moveTo(x, ground)
        ..lineTo(x, top)
        ..lineTo(x + 7, top + 3)
        ..lineTo(x, top + 6);
    }

    // Theirs: the depth scale, the full-depth stake a head taller.
    final theirs = _stroke(T.dim, 1.3);
    for (final d in [0.25, 0.5, 0.75, 1.0]) {
      canvas.drawPath(stake(_x(d, w), d == 1.0 ? 24 : 17), theirs);
    }

    // Ours: one per earlier run, nudged apart so a common depth reads as a
    // thicket rather than one stake.
    final ours = _stroke(T.amber.withValues(alpha: 0.5), 1.2);
    for (var i = 0; i < depths.length; i++) {
      final rng = Random(i * 31 + 7);
      final x = _x(depths[i], w) + (rng.nextDouble() - 0.5) * 8;
      canvas.drawPath(stake(x, 12 + rng.nextDouble() * 6), ours);
    }

    // This run's stake, carved in the way a sigil is.
    if (latest != null) {
      final path = stake(_x(latest!, w), 30);
      final paint = _stroke(T.amber, 1.6);
      if (progress >= 1) {
        canvas.drawPath(path, paint);
      } else {
        final metrics = path.computeMetrics().toList();
        final total = metrics.fold<double>(0, (a, m) => a + m.length);
        var budget = total * progress;
        for (final m in metrics) {
          if (budget <= 0) break;
          final take = budget < m.length ? budget : m.length;
          canvas.drawPath(m.extractPath(0, take), paint);
          budget -= take;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.sectorId != sectorId ||
      old.color != color ||
      old.depths != depths ||
      old.latest != latest ||
      old.progress != progress;
}
