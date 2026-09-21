import 'package:flutter/material.dart';

/// Carved marks: one per sector (a place) and one per class (a person).
///
/// Every mark is a handful of strokes in a unit square, built as a [Path] so
/// it can be drawn progressively - the reveal animation and the static icon
/// are the same geometry. No assets, no artist, and a new sector or class is
/// still a data edit plus five lines here.
///
/// Colour carries two different channels deliberately: a sector's own colour
/// says *where*, and a class emblem stays monochrome and says *who*. Tinting
/// both would collapse the distinction.

// ---------------------------------------------------------------------------
// GEOMETRY
// ---------------------------------------------------------------------------

Path _p(double s, List<List<double>> segments) {
  final path = Path();
  for (final seg in segments) {
    path.moveTo(seg[0] * s, seg[1] * s);
    for (var i = 2; i < seg.length; i += 2) {
      path.lineTo(seg[i] * s, seg[i + 1] * s);
    }
  }
  return path;
}

/// A mark for a place.
Path sigilPath(String sectorId, double s) {
  switch (sectorId) {
    // MOSSWOOD VERGE - a treeline: canopy over a trunk, branches either side.
    case 'mosswood':
      return _p(s, [
        [0.14, 0.52, 0.5, 0.10, 0.86, 0.52],
        [0.5, 0.10, 0.5, 0.92],
        [0.26, 0.64, 0.5, 0.44],
        [0.74, 0.64, 0.5, 0.44],
      ]);

    // BLACKSTONE HOLLOW - a descent: wedges dropping to a floor.
    case 'blackstone':
      return _p(s, [
        [0.14, 0.12, 0.5, 0.50, 0.86, 0.12],
        [0.26, 0.42, 0.5, 0.68, 0.74, 0.42],
        [0.2, 0.9, 0.8, 0.9],
      ]);

    // THE CINDER ARCHIVE - a burned ledger: a volume struck through.
    // Redrawn: the old page-stack read as a domino at header size.
    case 'cinder':
      return _p(s, [
        [0.22, 0.12, 0.78, 0.12, 0.78, 0.88, 0.22, 0.88, 0.22, 0.12],
        [0.30, 0.78, 0.70, 0.22],
      ]);

    // RIFTLINE DESCENT - a split: two halves pulled off the centre line.
    case 'riftline':
      return _p(s, [
        [0.5, 0.04, 0.5, 0.96],
        [0.28, 0.18, 0.12, 0.5, 0.28, 0.82],
        [0.72, 0.18, 0.88, 0.5, 0.72, 0.82],
      ]);

    // THE SPIRE OF TELOS - a banded tower with something at the top.
    case 'spire':
      return _p(s, [
        [0.5, 0.10, 0.24, 0.94],
        [0.5, 0.10, 0.76, 0.94],
        [0.33, 0.54, 0.67, 0.54],
        [0.28, 0.74, 0.72, 0.74],
        [0.42, 0.20, 0.5, 0.06, 0.58, 0.20, 0.42, 0.20],
      ]);

    default:
      return _p(s, [
        [0.5, 0.12, 0.88, 0.5, 0.5, 0.88, 0.12, 0.5, 0.5, 0.12],
      ]);
  }
}

/// A mark for a person. Reads at 16px, which is where most of them live.
Path emblemPath(String classId, double s) {
  switch (classId) {
    // VANGUARD - a bulwark. Heavy, planted, takes the long haul.
    case 'vanguard':
      return _p(s, [
        [0.12, 0.26, 0.88, 0.26],
        [0.2, 0.26, 0.5, 0.86, 0.8, 0.26],
        [0.32, 0.5, 0.68, 0.5],
      ]);

    // RECON - a dart already moving. In and out.
    case 'recon':
      return _p(s, [
        [0.18, 0.78, 0.82, 0.22],
        [0.52, 0.22, 0.82, 0.22, 0.82, 0.52],
        [0.14, 0.44, 0.36, 0.44],
        [0.14, 0.60, 0.28, 0.60],
      ]);

    // ARCHIVIST - an open volume on its spine.
    case 'archivist':
      return _p(s, [
        [0.5, 0.24, 0.5, 0.84],
        [0.5, 0.24, 0.14, 0.34, 0.14, 0.80, 0.5, 0.84],
        [0.5, 0.24, 0.86, 0.34, 0.86, 0.80, 0.5, 0.84],
      ]);

    // ARTIFICER - a clamp on a rivet. Strips things for parts.
    case 'artificer':
      return _p(s, [
        [0.16, 0.16, 0.40, 0.40],
        [0.84, 0.16, 0.60, 0.40],
        [0.16, 0.84, 0.40, 0.60],
        [0.84, 0.84, 0.60, 0.60],
        [0.40, 0.40, 0.60, 0.40, 0.60, 0.60, 0.40, 0.60, 0.40, 0.40],
      ]);

    // QUARTERMASTER - a balance. No specialism, no bad days.
    case 'quartermaster':
      return _p(s, [
        [0.5, 0.10, 0.86, 0.5, 0.5, 0.90, 0.14, 0.5, 0.5, 0.10],
        [0.2, 0.5, 0.8, 0.5],
      ]);

    default:
      return _p(s, [
        [0.5, 0.14, 0.5, 0.86],
        [0.14, 0.5, 0.86, 0.5],
      ]);
  }
}

// ---------------------------------------------------------------------------
// PAINTING
// ---------------------------------------------------------------------------

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.path, this.color, this.strokeWidth, this.progress);

  final Path path;
  final Color color;
  final double strokeWidth;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;

    if (progress >= 1.0) {
      canvas.drawPath(path, paint);
      return;
    }

    // Draw the subpaths in order, cutting off mid-stroke - the mark is being
    // carved, not faded in.
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (a, m) => a + m.length);
    var budget = total * progress.clamp(0.0, 1.0);
    for (final m in metrics) {
      if (budget <= 0) break;
      final take = budget < m.length ? budget : m.length;
      canvas.drawPath(m.extractPath(0, take), paint);
      budget -= take;
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.path != path;
}

class _Mark extends StatelessWidget {
  const _Mark({
    required this.path,
    required this.color,
    required this.size,
    required this.strokeScale,
    required this.animate,
  });

  final Path path;
  final Color color;
  final double size;
  final double strokeScale;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final stroke = size * 0.075 * strokeScale;
    _MarkPainter painterFor(double t) => _MarkPainter(path, color, stroke, t);

    return SizedBox(
      width: size,
      height: size,
      child: animate
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOutCubic,
              builder: (_, t, __) =>
                  CustomPaint(painter: painterFor(t), size: Size.square(size)),
            )
          : CustomPaint(painter: painterFor(1), size: Size.square(size)),
    );
  }
}

/// The mark for a sector.
class Sigil extends StatelessWidget {
  const Sigil({
    super.key,
    required this.sectorId,
    required this.color,
    this.size = 40,
    this.strokeScale = 1.0,
    this.animate = false,
  });

  final String sectorId;
  final Color color;
  final double size;
  final double strokeScale;

  /// One-shot stroke reveal. Reserved for things that happen rarely - a
  /// sector opening, a run beginning. If everything animates, nothing reads.
  final bool animate;

  @override
  Widget build(BuildContext context) => _Mark(
        path: sigilPath(sectorId, size),
        color: color,
        size: size,
        strokeScale: strokeScale,
        animate: animate,
      );
}

/// The mark for a class. Monochrome on purpose - see the note at the top.
class ClassEmblem extends StatelessWidget {
  const ClassEmblem({
    super.key,
    required this.classId,
    required this.color,
    this.size = 28,
    this.animate = false,
  });

  final String classId;
  final Color color;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) => _Mark(
        path: emblemPath(classId, size),
        color: color,
        size: size,
        // Emblems live small, so they need a touch more weight to hold up.
        strokeScale: size < 24 ? 1.25 : 1.0,
        animate: animate,
      );
}

/// A sigil set into a bordered plate, where the mark needs presence: the
/// session header, the debrief header.
class SigilPlate extends StatelessWidget {
  const SigilPlate({
    super.key,
    required this.sectorId,
    required this.color,
    this.size = 84,
    this.animate = false,
  });

  final String sectorId;
  final Color color;
  final double size;
  final bool animate;

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
      child: Sigil(
        sectorId: sectorId,
        color: color,
        size: size * 0.52,
        animate: animate,
      ),
    );
  }
}
