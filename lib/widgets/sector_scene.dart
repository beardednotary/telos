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
  static bool has(String sectorId) =>
      const {'mosswood', 'blackstone', 'cinder', 'riftline'}
          .contains(sectorId);

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
      case 'blackstone':
        _blackstone(canvas, size);
      case 'cinder':
        _cinder(canvas, size);
      case 'riftline':
        _riftline(canvas, size);
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

    _stakes(canvas, size, (_) => ground);
  }

  // BLACKSTONE HOLLOW - the works in section: the winch house's headframe
  // over the shaft, the gallery running off it under the seam, its shoring
  // re-cut and holding, and the equipment stacked and sheeted past full
  // depth. The stakes stand on the gallery floor.
  void _blackstone(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final surface = h * 0.24;
    final roof = h * 0.50;
    final floor = h * 0.86;
    // Fainter than the other sectors: this orange sits close to the
    // player's amber, and the stakes have to win.
    final land = _stroke(color.withValues(alpha: 0.38), 1.2);
    final far = _stroke(color.withValues(alpha: 0.18), 1.0);
    final rng = Random(202);

    // The surface: rough ground, broken where the shaft goes down.
    final shaftL = w * 0.035;
    final shaftR = w * 0.085;
    canvas.drawLine(Offset(0, surface), Offset(shaftL, surface), land);
    final ground = Path()..moveTo(shaftR, surface);
    for (var x = shaftR + 10; x < w; x += 12 + rng.nextDouble() * 14) {
      ground.lineTo(x, surface - rng.nextDouble() * 9);
    }
    ground.lineTo(w, surface - 4);
    canvas.drawPath(ground, land);

    // Headframe over the shaft: two legs and the wheel.
    final hx = (shaftL + shaftR) / 2;
    final apex = Offset(hx, surface - 24);
    canvas.drawLine(Offset(shaftL - 4, surface), apex, land);
    canvas.drawLine(Offset(shaftR + 4, surface), apex, land);
    canvas.drawCircle(apex, 5, land);
    canvas.drawLine(apex, Offset(hx, roof), far); // the cable

    // The shaft, open on its right into the gallery.
    canvas.drawLine(Offset(shaftL, surface), Offset(shaftL, floor), land);
    canvas.drawLine(Offset(shaftR, surface), Offset(shaftR, roof), land);

    // Gallery roof and floor.
    canvas.drawLine(Offset(shaftR, roof), Offset(w, roof), land);
    canvas.drawLine(Offset(0, floor), Offset(w, floor), land);

    // The seam in the rock above: richer than the old survey said, so it
    // runs thick. Two jagged bands.
    for (final (y, p) in [(h * 0.36, land), (h * 0.42, far)]) {
      final seam = Path()..moveTo(w * 0.22, y);
      for (var x = w * 0.22; x < w; x += 9 + rng.nextDouble() * 8) {
        seam.lineTo(x, y + (rng.nextDouble() - 0.5) * 7);
      }
      canvas.drawPath(seam, p);
    }

    // Shoring: timber sets down the gallery, a post each side of a cap.
    // One on level two gave way and hangs at an angle.
    var n = 0;
    for (var x = w * 0.14; x < w - 6; x += w * 0.085) {
      n++;
      if (x > w * 0.58 && x < w * 0.72) continue; // the stack is here
      canvas.drawLine(Offset(x - 6, floor), Offset(x - 6, roof), far);
      canvas.drawLine(Offset(x + 6, floor), Offset(x + 6, roof), far);
      if (n == 3) {
        canvas.drawLine(Offset(x - 9, roof + 1), Offset(x + 9, roof + 9), land);
      } else {
        canvas.drawLine(Offset(x - 9, roof + 1), Offset(x + 9, roof + 1), land);
      }
    }

    // Equipment stacked and sheeted: a covered load, tied down.
    final ex = w * 0.635;
    canvas.drawPath(
        Path()
          ..moveTo(ex, floor)
          ..lineTo(ex + 4, floor - 14)
          ..lineTo(ex + 22, floor - 16)
          ..lineTo(ex + 27, floor),
        land);
    canvas.drawLine(
        Offset(ex + 2, floor - 7), Offset(ex + 25, floor - 8), far);

    _stakes(canvas, size, (_) => floor);
  }

  // THE CINDER ARCHIVE - the stacks in elevation: bays of shelving, some
  // standing and some burned down to a ragged line, the door of the sealed
  // reading room past full depth, and the fire still going under the floor.
  void _cinder(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final floor = h * 0.80;
    final land = _stroke(color.withValues(alpha: 0.45), 1.2);
    final far = _stroke(color.withValues(alpha: 0.2), 1.0);
    final rng = Random(303);

    canvas.drawLine(Offset(0, floor), Offset(w, floor), land);

    // The fire below: a low flicker running under the whole floor.
    final ember = _stroke(T.amber.withValues(alpha: 0.28), 1.0);
    final flicker = Path()..moveTo(0, floor + 12);
    for (var x = 0.0; x < w; x += 5 + rng.nextDouble() * 5) {
      flicker.lineTo(x, floor + 8 + rng.nextDouble() * 9);
    }
    canvas.drawPath(flicker, ember);

    // The door to the sealed reading room: a frame, a lintel, shut.
    final dx = w * 0.64;
    canvas.drawRect(Rect.fromLTWH(dx, floor - 38, 22, 38), land);
    canvas.drawLine(
        Offset(dx - 4, floor - 42), Offset(dx + 26, floor - 42), land);
    canvas.drawLine(Offset(dx + 16, floor - 20), Offset(dx + 18, floor - 20),
        land); // the handle

    // The bays: bookcases of one height with an overhanging top, pushed
    // back to the faint tone so the stakes stand in front of them. About a
    // half burned down to a ragged line, with what is left of the shelves.
    final bay = w * 0.075;
    final top = h * 0.16;
    var i = 0;
    for (var x = w * 0.015; x + bay < w; x += bay + 3) {
      if (x + bay > dx - 6 && x < dx + 30) continue;
      // Two in every five, spread out rather than left to the dice.
      final burned = (i++ * 3 + 1) % 5 < 2;
      final cut = burned
          ? floor - (floor - top) * (0.3 + rng.nextDouble() * 0.35)
          : top;

      canvas.drawLine(Offset(x, floor), Offset(x, cut), far);
      canvas.drawLine(Offset(x + bay, floor), Offset(x + bay, cut), far);
      if (burned) {
        final rag = Path()..moveTo(x, cut);
        for (var i = 1; i <= 4; i++) {
          rag.lineTo(x + bay * i / 4,
              cut + (i.isOdd ? -5 : 3) * rng.nextDouble());
        }
        canvas.drawPath(rag, land);
      } else {
        canvas.drawLine(Offset(x - 2, top), Offset(x + bay + 2, top), land);
      }

      // Shelves, each packed with spines.
      for (var y = floor - 12.0; y > cut + 6; y -= 12) {
        canvas.drawLine(Offset(x, y), Offset(x + bay, y), far);
        for (var bx = x + 2; bx < x + bay - 1; bx += 1.8 + rng.nextDouble() * 1.4) {
          if (rng.nextDouble() < 0.1) continue;
          canvas.drawLine(
              Offset(bx, y), Offset(bx, y - 6 - rng.nextDouble() * 3), far);
        }
      }
    }

    _stakes(canvas, size, (_) => floor);
  }

  // RIFTLINE DESCENT - the way down in section: ledges stepping into the
  // split, the far wall above, their anchors set at every ledge, and stores
  // cached at the last depth mark. Each stake stands on the ledge its depth
  // reached, so runs past full depth go on down where theirs never did.
  void _riftline(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final land = _stroke(color.withValues(alpha: 0.5), 1.2);
    final far = _stroke(color.withValues(alpha: 0.2), 1.0);
    final rng = Random(404);

    // Ledges of uneven width and drop, fixed by the seed.
    const steps = 8;
    final top = h * 0.30;
    final span = h * 0.92 - top;
    final widths = [for (var i = 0; i < steps; i++) 0.7 + rng.nextDouble() * 0.6];
    final drops = [for (var i = 0; i < steps - 1; i++) 0.6 + rng.nextDouble() * 0.8];
    final wSum = widths.reduce((a, b) => a + b);
    final dSum = drops.reduce((a, b) => a + b);
    final xs = <double>[0];
    for (final v in widths) {
      xs.add(xs.last + w * v / wSum);
    }
    final ys = <double>[top];
    for (final v in drops) {
      ys.add(ys.last + span * v / dSum);
    }
    double ledge(double x) {
      for (var i = 0; i < steps; i++) {
        if (x < xs[i + 1]) return ys[i];
      }
      return ys.last;
    }

    for (var i = 0; i < steps; i++) {
      final x0 = xs[i], x1 = xs[i + 1], y = ys[i];
      canvas.drawLine(Offset(x0, y), Offset(x1, y), land);
      if (i < steps - 1) {
        canvas.drawLine(Offset(x1, y), Offset(x1, ys[i + 1]), land);
      }
      // Rock under the ledge: a band of hatching.
      for (var x = x0 + 3; x < x1 - 2; x += 6) {
        canvas.drawLine(Offset(x, y + 3), Offset(x - 5, y + 9), far);
      }
      // Their anchor at the lip of every ledge.
      canvas.drawCircle(Offset(x0 + 5, y - 2.5), 2, land);
    }

    // The far wall, jagged, keeping its distance above the ledges.
    final wall = Path()..moveTo(0, top - 44);
    for (var x = 0.0; x <= w; x += 8 + rng.nextDouble() * 8) {
      wall.lineTo(x, ledge(x) - 40 + (rng.nextDouble() - 0.5) * 10);
    }
    canvas.drawPath(wall, far);

    // Stores at the last depth mark: a sealed case, strapped.
    final sx = _x(1.04, w);
    final sy = ledge(sx);
    canvas.drawRect(Rect.fromLTWH(sx, sy - 10, 16, 10), land);
    canvas.drawLine(Offset(sx, sy - 10), Offset(sx + 16, sy), far);
    canvas.drawLine(Offset(sx + 16, sy - 10), Offset(sx, sy), far);

    _stakes(canvas, size, ledge);
  }

  /// Survey stakes, each with its pennant. Never a crossbar: a row of those
  /// reads as graves.
  ///
  /// [groundAt] gives the height of the route at x, so a stake stands on
  /// the ledge its depth reached in a sector that goes down.
  void _stakes(Canvas canvas, Size size, double Function(double x) groundAt) {
    final w = size.width;
    Path stake(double x, double tall) {
      final ground = groundAt(x);
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
