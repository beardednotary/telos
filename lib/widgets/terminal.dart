import 'dart:math';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/telos_theme.dart';

/// One colour per rarity, used by the debrief, the vault and the kit slots.
Color rarityColor(Rarity r) => switch (r) {
      Rarity.common => T.dim,
      Rarity.uncommon => T.steel,
      Rarity.rare => T.cyan,
      Rarity.epic => T.amber,
    };

/// One section of a screen, drawn as its own card.
///
/// Every screen is a stack of these, so where one set of data ends and the
/// next begins never rests on a coloured label or a spacing gap. [label]
/// heads the card above a hairline. Pass [child] for a single padded block,
/// or [rows] for a list: rows run edge to edge with a hairline between each,
/// and carry their own padding.

/// Ink, not a border.
///
/// A 1px geometric rule is the most machine-made mark there is, and it was
/// most of what made these screens read as generated. Every rule on a real
/// field sheet is drawn against a straight edge by a person: it wobbles a
/// little, it overshoots the corner or falls short of it, and no two are
/// the same.
///
/// Seeded off the section's own identity so a given rule is the same every
/// build. It is ink that dried once, not an animation.
void drawHandRule(
  Canvas canvas,
  Offset a,
  Offset b, {
  required Color color,
  required int seed,
  double width = 1.2,
  double wobble = 2.2,
}) {
  final rng = Random(seed);
  final paint = Paint()
    ..color = color
    ..strokeWidth = width
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  final vertical = (b.dy - a.dy).abs() > (b.dx - a.dx).abs();

  // Drawn as a handful of overlapping strokes rather than one, each a
  // slightly different weight. Ink varies along a line; a single stroke of
  // constant width is the thing that reads as machine-made, and at phone
  // sizes weight carries far further than wobble does.
  const steps = 16;
  const segs = 4;
  Offset at(double t) {
    final ease = sin(t * pi); // steadiest at the ends, against the edge
    final j = (rng.nextDouble() - 0.5) * wobble * ease;
    return Offset(
      a.dx + (b.dx - a.dx) * t + (vertical ? j : 0),
      a.dy + (b.dy - a.dy) * t + (vertical ? 0 : j),
    );
  }

  final pts = [for (var i = 0; i <= steps; i++) at(i / steps)];
  const per = steps ~/ segs;
  for (var sgi = 0; sgi < segs; sgi++) {
    final path = Path();
    final from = sgi * per;
    final to = (sgi == segs - 1) ? steps : (sgi + 1) * per;
    path.moveTo(pts[from].dx, pts[from].dy);
    for (var i = from + 1; i <= to; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    paint.strokeWidth = width * (0.7 + rng.nextDouble() * 0.75);
    canvas.drawPath(path, paint);
  }
}

/// A zone on the sheet: four hand-drawn rules whose corners do not quite
/// meet, because they never do.
class _SheetZone extends CustomPainter {
  _SheetZone({required this.seed, required this.color, this.accent});

  final int seed;
  final Color color;
  final Color? accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    // How far each rule runs past its corner, or stops short of it.
    double over() => rng.nextDouble() * 7.0 - 2.5;
    final w = size.width, h = size.height;

    drawHandRule(canvas, Offset(-over(), 0.5), Offset(w + over(), 0.5),
        color: color, seed: seed + 1);
    drawHandRule(canvas, Offset(w - 0.5, -over()), Offset(w - 0.5, h + over()),
        color: color, seed: seed + 2);
    drawHandRule(canvas, Offset(-over(), h - 0.5), Offset(w + over(), h - 0.5),
        color: color, seed: seed + 3);

    if (accent == null) {
      drawHandRule(canvas, Offset(0.5, -over()), Offset(0.5, h + over()),
          color: color, seed: seed + 4);
    } else {
      // Three strokes side by side rather than one fat one, the way a bar
      // gets filled in by hand.
      for (var i = 0; i < 3; i++) {
        drawHandRule(
            canvas, Offset(1.0 + i * 1.3, -over()), Offset(1.0 + i * 1.3, h + over()),
            color: accent!, seed: seed + 5 + i, width: 1.5, wobble: 1.4);
      }
    }
  }

  @override
  bool shouldRepaint(_SheetZone old) =>
      old.seed != seed || old.color != color || old.accent != accent;
}

/// A single hand-drawn rule across the width, for separating rows.
class HandRule extends StatelessWidget {
  const HandRule({super.key, required this.seed, this.color = T.line});
  final int seed;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 1.6,
        width: double.infinity,
        child: CustomPaint(painter: _RulePainter(seed: seed, color: color)),
      );
}

class _RulePainter extends CustomPainter {
  _RulePainter({required this.seed, required this.color});
  final int seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final inset = rng.nextDouble() * 3;
    drawHandRule(canvas, Offset(inset, 0.8), Offset(size.width - inset, 0.8),
        color: color, seed: seed, width: 1.1, wobble: 1.8);
  }

  @override
  bool shouldRepaint(_RulePainter old) =>
      old.seed != seed || old.color != color;
}

class Section extends StatelessWidget {
  const Section({
    super.key,
    this.label,
    this.labelColor = T.steel,
    this.leading,
    this.trailing,
    this.trailingColor = T.dim,
    this.accent,
    this.border = T.line,
    this.child,
    this.rows,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  }) : assert((child == null) != (rows == null));

  final String? label;
  final Color labelColor;

  /// Sits before the label, for the dispatch screen's step numbers.
  final Widget? leading;
  final String? trailing;
  final Color trailingColor;

  /// A thick bar down the left edge, for a card that is one thing's colour.
  final Color? accent;
  final Color border;
  final Widget? child;
  final List<Widget>? rows;
  final EdgeInsets padding;

  /// Space between stacked sections, and their inset from the screen edge.
  static const margin = EdgeInsets.fromLTRB(16, 0, 16, 16);

  /// A row inside [rows] that is just a line of text, such as an empty state.
  static Widget note(String text, {Color color = T.dim}) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Text(text,
            style: T.micro
                .copyWith(color: color, letterSpacing: 0.4, height: 1.7)),
      );

  @override
  Widget build(BuildContext context) {
    // Stable per section, so a zone's rules are the same every rebuild but
    // no two zones are drawn alike.
    final seed = (label ?? trailing ?? '').hashCode ^ (rows?.length ?? 7) * 31;
    final hairline = HandRule(seed: seed * 7 + 3);

    // No fill. The sheet shows through, and the zone is made of ink.
    // The margin sits outside the paint so the rules land on the content,
    // not out at the screen edge.
    return Container(
      width: double.infinity,
      margin: margin,
      child: CustomPaint(
        painter: _SheetZone(seed: seed, color: border, accent: accent),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 11),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 10)],
                  Expanded(
                    child: Text(label!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.micro.copyWith(color: labelColor)),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    Text(trailing!,
                        style: T.micro.copyWith(color: trailingColor)),
                  ],
                ],
              ),
            ),
            hairline,
          ],
          if (child != null)
            Padding(padding: padding, child: child)
          else
            for (var i = 0; i < rows!.length; i++) ...[
              if (i > 0) HandRule(seed: seed * 7 + 11 + i * 5),
              rows![i],
            ],
          ],
        ),
      ),
    );
  }
}



/// Integrity as the squad would report it, not as a percentage.
///
/// A number with a decimal point is telemetry. These are the words a
/// person writes on a form, and they carry the same information: whether
/// the phone stayed down.
String integrityWord(double integrity) {
  if (integrity >= 0.999) return 'untouched';
  if (integrity >= 0.95) return 'barely broken';
  if (integrity >= 0.85) return 'interrupted';
  if (integrity >= 0.6) return 'broken up';
  return 'scattered';
}

/// A field on a form: a label, a run of leader dots, a value.
///
/// The thing that stops a screen reading as an app. A card with a label
/// above a big number is a dashboard tile and always will be, whatever
/// colour it is. `FOCUSED · · · · · · 52 min` is a line on a form.
class FieldRow extends StatelessWidget {
  const FieldRow(
    this.label,
    this.value, {
    super.key,
    this.valueColor = T.text,
    this.note,
    this.seed = 0,
  });

  final String label;
  final String value;
  final Color valueColor;

  /// Sits under the value in small type, for a unit or a qualifier.
  final String? note;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label, style: T.micro),
          const SizedBox(width: 10),
          // The dots have no baseline of their own, so they get a box the
          // height of the line and sit on the bottom of it.
          Expanded(
            child: SizedBox(
              height: 15,
              child: CustomPaint(
                size: const Size(double.infinity, 15),
                painter: _LeaderDots(seed: seed),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(value,
              style: T.mono.copyWith(
                  fontSize: 15, color: valueColor, letterSpacing: 0.5)),
          if (note != null) ...[
            const SizedBox(width: 4),
            Text(note!, style: T.micro.copyWith(color: T.dim)),
          ],
        ],
      ),
    );
  }
}

/// The dots that run from a label to its value. Spaced by hand, so they
/// drift a little and do not end flush.
class _LeaderDots extends CustomPainter {
  _LeaderDots({required this.seed});
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final paint = Paint()..color = T.line;
    var x = rng.nextDouble() * 4;
    while (x < size.width - 2) {
      canvas.drawCircle(
          Offset(x, size.height - 4 + (rng.nextDouble() - 0.5) * 0.8),
          0.9, paint);
      x += 5 + rng.nextDouble() * 2.5;
    }
  }

  @override
  bool shouldRepaint(_LeaderDots old) => old.seed != seed;
}

/// The block in the corner of a drafted sheet that says what the sheet is.
///
/// Every real drawing carries one: who drew it, when, which sheet of how
/// many, at what scale. Nothing in app design looks remotely like this,
/// which is most of the point.
class TitleBlock extends StatelessWidget {
  const TitleBlock({super.key, required this.fields, this.seed = 11});

  /// Left to right, in the order a draughtsman would read them.
  final List<(String, String)> fields;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Section.margin,
      child: CustomPaint(
        painter: _SheetZone(seed: seed, color: T.line),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    child: SizedBox(
                      height: 28,
                      width: 1.4,
                      child: CustomPaint(
                        painter: _DividerPainter(seed: seed + i),
                      ),
                    ),
                  ),
                // The first field is conventionally an organisation's name
                // and is always the longest, so it gets the room.
                Flexible(
                  flex: i == 0 ? 3 : 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fields[i].$1,
                          style: T.micro.copyWith(fontSize: 8.5)),
                      const SizedBox(height: 3),
                      Text(fields[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.mono.copyWith(
                              fontSize: 12, letterSpacing: 0.6)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DividerPainter extends CustomPainter {
  _DividerPainter({required this.seed});
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    drawHandRule(canvas, const Offset(0.7, 0), Offset(0.7, size.height),
        color: T.line, seed: seed, width: 1.0, wobble: 1.2);
  }

  @override
  bool shouldRepaint(_DividerPainter old) => old.seed != seed;
}

/// [████████░░░░░░] style bar.
class Meter extends StatelessWidget {
  const Meter({
    super.key,
    required this.value,
    this.color = T.amber,
    this.height = 8,
    this.segments = 0,
  });

  final double value; // 0..1
  final Color color;
  final double height;

  /// 0 = smooth bar. >0 = that many discrete blocks, for the terminal look.
  final int segments;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    if (segments > 0) {
      final filled = (v * segments).round();
      return Row(
        children: List.generate(segments, (i) {
          return Expanded(
            child: Container(
              height: height,
              margin: const EdgeInsets.only(right: 2),
              color: i < filled ? color : T.line,
            ),
          );
        }),
      );
    }
    return LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          Container(height: height, color: T.line),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: height,
            width: c.maxWidth * v,
            color: color,
          ),
        ],
      ),
    );
  }
}

/// A bracketed action:  [ DISPATCH SQUAD ]
class TButton extends StatelessWidget {
  const TButton(
    this.label, {
    super.key,
    this.onTap,
    this.color = T.amber,
    this.filled = false,
    this.expand = true,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool filled;
  final bool expand;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final c = enabled ? color : T.dim;
    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 12 : 16,
        vertical: dense ? 8 : 14,
      ),
      decoration: BoxDecoration(
        color:
            filled && enabled ? c.withValues(alpha: 0.12) : Colors.transparent,
        border: Border.all(color: enabled ? c : T.line),
      ),
      alignment: Alignment.center,
      child: Text(
        '[ $label ]',
        style: T.mono.copyWith(
          color: c,
          fontSize: dense ? 11 : 13,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final tappable = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
    return expand
        ? SizedBox(width: double.infinity, child: tappable)
        : tappable;
  }
}

/// A small selectable pill, used for durations and squad members.
class TChip extends StatelessWidget {
  const TChip(
    this.label, {
    super.key,
    this.selected = false,
    this.onTap,
    this.color = T.amber,
    this.sub,
  });

  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : T.card,
          border: Border.all(color: selected ? color : T.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: T.mono.copyWith(
                color: enabled ? (selected ? color : T.text) : T.dim,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
            if (sub != null)
              Text(sub!,
                  style: T.label.copyWith(fontSize: 11, letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }
}

/// LABEL .......... VALUE
class KV extends StatelessWidget {
  const KV(this.k, this.v, {super.key, this.color, this.bold = false});
  final String k;
  final String v;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(k, style: T.label),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '.' * 60,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: T.mono.copyWith(color: T.line, fontSize: 12),
              ),
            ),
          ),
          Text(
            v,
            style: T.data.copyWith(
              color: color ?? T.text,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// A screen scaffold with the standard header rule.
class TerminalScaffold extends StatelessWidget {
  const TerminalScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.showBack = true,
    this.bottom,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  if (showBack && Navigator.canPop(context))
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child:
                            Text('<', style: T.heading.copyWith(color: T.dim)),
                      ),
                    ),
                  Text(title, style: T.heading),
                  const SizedBox(width: 12),
                  Expanded(child: Container(height: 1, color: T.line)),
                  if (actions != null) ...[
                    const SizedBox(width: 12),
                    ...actions!,
                  ],
                ],
              ),
            ),
            Expanded(child: child),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: bottom!,
              ),
          ],
        ),
      ),
    );
  }
}

/// One beat of a staged reveal.
///
/// The debrief is the payoff for the work you just did, so it arrives in
/// sequence rather than all at once. [step] is which beat this belongs to,
/// [steps] the total. Every beat is driven by one finite controller, so the
/// whole thing still settles (and stays testable).
class Staged extends StatelessWidget {
  const Staged({
    super.key,
    required this.animation,
    required this.step,
    required this.steps,
    required this.child,
  });

  final Animation<double> animation;
  final int step;
  final int steps;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Beats overlap slightly so it reads as a cascade, not a slideshow.
        final spread = 1 / (steps + 1);
        final start = step * spread;
        final t = ((animation.value - start) / (spread * 2)).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 10),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
