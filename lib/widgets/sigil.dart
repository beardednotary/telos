import 'package:flutter/material.dart';

/// Carved marks: one per sector (a place), one per class (a person), and one
/// per thing the camp keeps (a [CampMark]: the barracks, the vault, a report).
///
/// Every mark is a handful of strokes in a unit square, built as a [Path] so
/// it can be drawn progressively - the reveal animation and the static icon
/// are the same geometry. No assets, no artist, and a new sector or class is
/// still a data edit plus five lines here.
///
/// Colour carries two different channels deliberately: a sector's own colour
/// says *where*, and a class emblem stays monochrome and says *who*. Tinting
/// both would collapse the distinction. Camp marks are monochrome too: they
/// label a section, and say nothing about where or who.

// ---------------------------------------------------------------------------
// GEOMETRY
// ---------------------------------------------------------------------------

/// Each segment is a polyline. One that ends where it began is closed, so
/// its first corner gets a proper join: drawn open, the start and the end
/// are two loose stroke ends, and a notch is cut out of that corner.
Path _p(double s, List<List<double>> segments) {
  final path = Path();
  for (final seg in segments) {
    final n = seg.length;
    final closed = n >= 6 && seg[0] == seg[n - 2] && seg[1] == seg[n - 1];
    path.moveTo(seg[0] * s, seg[1] * s);
    for (var i = 2; i < (closed ? n - 2 : n); i += 2) {
      path.lineTo(seg[i] * s, seg[i + 1] * s);
    }
    if (closed) path.close();
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
        [0.26, 0.64, 0.5, 0.44, 0.74, 0.64],
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
        [0.24, 0.94, 0.5, 0.10, 0.76, 0.94],
        // Bands end on the walls' centre lines rather than overshooting them.
        [0.364, 0.54, 0.636, 0.54],
        [0.302, 0.74, 0.698, 0.74],
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
        [0.5, 0.24, 0.86, 0.34, 0.86, 0.80, 0.5, 0.84, 0.14, 0.80, 0.14, 0.34,
            0.5, 0.24],
        [0.5, 0.24, 0.5, 0.84],
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
        [0.14, 0.5, 0.86, 0.5],
      ]);

    default:
      return _p(s, [
        [0.5, 0.14, 0.5, 0.86],
        [0.14, 0.5, 0.86, 0.5],
      ]);
  }
}

/// The things a section of the camp is about. These replace the stock
/// Material outlines on section headers, which were the one place the app
/// still looked like any other app. Not interchangeable with the guild
/// emblems: no hammer is an anvil and no route is a compass, so a guild's
/// chosen emblem never reads as a menu item.
enum CampMark {
  /// Where the roster sleeps: a ridge tent.
  barracks,

  /// A hammer, head up.
  forge,

  /// Volumes on a shelf, one leaning.
  archive,

  /// One member.
  person,

  /// A member, and a place for another.
  recruit,

  /// Two members, one behind the other.
  squad,

  /// A braced crate: stores, the vault.
  crate,

  /// A survey stake at the end of a road: a destination, sector access.
  route,

  /// The focus session itself.
  hourglass,

  /// A ruled sheet with its corner turned: the expedition report.
  ledger,

  /// A strapped field journal.
  journal,

  /// A crucible: melting gear back to alloy.
  crucible,

  /// A sheet and its copy: save and restore.
  copy,

  /// A set plate with a mark: reference, help.
  reference,

  /// A plumb line: Integrity, keeping true.
  plumb,

  /// A rolled charter.
  charter,

  /// A sealed order: a contract still open.
  contract,

  /// Cut once, cleanly: a contract met.
  done,
}

/// A mark for a part of camp. Drawn for 20-24px, where every one lives.
Path campMarkPath(CampMark mark, double s) => _p(s, switch (mark) {
      CampMark.barracks => [
          [0.06, 0.84, 0.94, 0.84],
          [0.12, 0.84, 0.50, 0.18, 0.88, 0.84],
          [0.40, 0.84, 0.50, 0.58, 0.60, 0.84],
        ],
      // Tilted mid-swing: upright, it reads as a letter T.
      CampMark.forge => [
          [0.52, 0.14, 0.90, 0.44, 0.80, 0.57, 0.42, 0.27, 0.52, 0.14],
          [0.61, 0.42, 0.22, 0.90],
        ],
      CampMark.archive => [
          [0.08, 0.86, 0.92, 0.86],
          [0.14, 0.86, 0.14, 0.24, 0.30, 0.24, 0.30, 0.86],
          [0.30, 0.34, 0.46, 0.34, 0.46, 0.86],
          // Resting a little high: its lowest corner's mitre would
          // otherwise poke through the underside of the shelf.
          [0.52, 0.79, 0.66, 0.84, 0.85, 0.31, 0.71, 0.26, 0.52, 0.79],
        ],
      CampMark.person => [
          [0.50, 0.10, 0.64, 0.24, 0.50, 0.38, 0.36, 0.24, 0.50, 0.10],
          [0.18, 0.88, 0.24, 0.58, 0.50, 0.48, 0.76, 0.58, 0.82, 0.88],
        ],
      CampMark.recruit => [
          [0.40, 0.14, 0.52, 0.26, 0.40, 0.38, 0.28, 0.26, 0.40, 0.14],
          [0.12, 0.88, 0.18, 0.60, 0.40, 0.50, 0.62, 0.60, 0.68, 0.88],
          [0.80, 0.14, 0.80, 0.42],
          [0.66, 0.28, 0.94, 0.28],
        ],
      CampMark.squad => [
          [0.34, 0.28, 0.45, 0.39, 0.34, 0.50, 0.23, 0.39, 0.34, 0.28],
          [0.10, 0.90, 0.15, 0.68, 0.34, 0.60, 0.53, 0.68, 0.58, 0.90],
          [0.66, 0.12, 0.77, 0.23, 0.66, 0.34, 0.55, 0.23, 0.66, 0.12],
          [0.58, 0.48, 0.66, 0.44, 0.85, 0.52, 0.90, 0.80],
        ],
      CampMark.crate => [
          [0.12, 0.28, 0.88, 0.28, 0.88, 0.86, 0.12, 0.86, 0.12, 0.28],
          [0.12, 0.42, 0.88, 0.42],
          [0.12, 0.86, 0.88, 0.42],
        ],
      // A near stake and a far one on rising ground: a line of them is a
      // route without drawing the road, which at this size reads as a crack.
      CampMark.route => [
          [0.06, 0.86, 0.94, 0.66],
          [0.22, 0.81, 0.22, 0.26, 0.30, 0.14, 0.38, 0.26, 0.38, 0.78],
          [0.66, 0.72, 0.66, 0.46, 0.71, 0.38, 0.76, 0.46, 0.76, 0.70],
        ],
      CampMark.hourglass => [
          [0.20, 0.10, 0.80, 0.10],
          [0.20, 0.90, 0.80, 0.90],
          [0.28, 0.10, 0.50, 0.50, 0.72, 0.10],
          [0.28, 0.90, 0.50, 0.50, 0.72, 0.90],
        ],
      CampMark.ledger => [
          [0.20, 0.10, 0.58, 0.10, 0.80, 0.32, 0.80, 0.90, 0.20, 0.90, 0.20, 0.10],
          [0.58, 0.10, 0.58, 0.32, 0.80, 0.32],
          [0.32, 0.42, 0.68, 0.42],
          [0.32, 0.56, 0.68, 0.56],
          [0.32, 0.70, 0.54, 0.70],
        ],
      CampMark.journal => [
          [0.22, 0.10, 0.78, 0.10, 0.78, 0.90, 0.22, 0.90, 0.22, 0.10],
          [0.34, 0.10, 0.34, 0.90],
          [0.34, 0.55, 0.90, 0.55],
        ],
      CampMark.crucible => [
          [0.12, 0.38, 0.88, 0.38],
          [0.20, 0.38, 0.30, 0.86, 0.70, 0.86, 0.80, 0.38],
          [0.25, 0.60, 0.75, 0.60],
          [0.40, 0.10, 0.40, 0.24],
          [0.60, 0.10, 0.60, 0.24],
        ],
      CampMark.copy => [
          [0.34, 0.10, 0.84, 0.10, 0.84, 0.72],
          [0.16, 0.28, 0.66, 0.28, 0.66, 0.90, 0.16, 0.90, 0.16, 0.28],
          [0.28, 0.50, 0.54, 0.50],
          [0.28, 0.66, 0.54, 0.66],
        ],
      CampMark.reference => [
          [0.16, 0.16, 0.84, 0.16, 0.84, 0.84, 0.16, 0.84, 0.16, 0.16],
          [0.50, 0.28, 0.50, 0.38],
          [0.50, 0.46, 0.50, 0.72],
          [0.40, 0.72, 0.60, 0.72],
        ],
      CampMark.plumb => [
          [0.22, 0.10, 0.78, 0.10],
          [0.50, 0.10, 0.50, 0.52],
          [0.50, 0.52, 0.64, 0.70, 0.50, 0.90, 0.36, 0.70, 0.50, 0.52],
        ],
      CampMark.charter => [
          [0.14, 0.12, 0.86, 0.12, 0.86, 0.24, 0.14, 0.24, 0.14, 0.12],
          [0.22, 0.24, 0.22, 0.76],
          [0.78, 0.24, 0.78, 0.76],
          [0.14, 0.76, 0.86, 0.76, 0.86, 0.88, 0.14, 0.88, 0.14, 0.76],
          [0.34, 0.42, 0.66, 0.42],
          [0.34, 0.58, 0.66, 0.58],
        ],
      CampMark.contract => [
          [0.20, 0.10, 0.80, 0.10, 0.80, 0.90, 0.20, 0.90, 0.20, 0.10],
          [0.32, 0.28, 0.68, 0.28],
          [0.32, 0.42, 0.68, 0.42],
          [0.56, 0.54, 0.66, 0.64, 0.56, 0.74, 0.46, 0.64, 0.56, 0.54],
        ],
      CampMark.done => [
          [0.16, 0.52, 0.40, 0.76, 0.84, 0.24],
        ],
    });

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
      // Butt ends: a square cap would poke a nub out wherever a stroke ends
      // against an angled one. Joints are closed by the geometry instead -
      // outlines are closed paths, and strokes that meet at a point are one
      // polyline, so the point is a join rather than two ends.
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

/// The mark for a part of camp, at section-header size. Never animated: a
/// header is read, not revealed.
class CampMarkIcon extends StatelessWidget {
  const CampMarkIcon(this.mark, {super.key, required this.color, this.size = 23});

  final CampMark mark;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => _Mark(
        path: campMarkPath(mark, size),
        color: color,
        size: size,
        // About the weight of the outlined icons these replace, so a header
        // row keeps its balance against the text beside it.
        strokeScale: 1.15,
        animate: false,
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
