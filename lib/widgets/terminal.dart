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
    const hairline = SizedBox(
      height: 1,
      width: double.infinity,
      child: ColoredBox(color: T.line),
    );

    return Container(
      width: double.infinity,
      margin: margin,
      decoration: BoxDecoration(
        color: T.card,
        border: Border(
          top: BorderSide(color: border),
          right: BorderSide(color: border),
          bottom: BorderSide(color: border),
          left: accent == null
              ? BorderSide(color: border)
              : BorderSide(color: accent!, width: 4),
        ),
      ),
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
              if (i > 0) hairline,
              rows![i],
            ],
        ],
      ),
    );
  }
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
