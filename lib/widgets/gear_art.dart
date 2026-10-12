import 'package:flutter/material.dart';

import '../theme/telos_theme.dart';
import 'gear_mark.dart';

/// A drawn plate of one piece of salvage, if it has one yet.
///
/// Same arrangement as [SectorHeader]: assets live at
/// `assets/art/gear/<id>.webp`, the whole directory is bundled, and an item
/// with no plate falls back to its [GearMark] engraving. Dropping in a file
/// is the entire installation step.
///
/// Deliberately not used in lists. The design direction's test is that each
/// illustration answers a question: a drawn rig at the reveal answers "what
/// did we find", while the same drawing in a comparison row answers nothing
/// the numbers were not already saying and makes the row slower to read.
/// [GearMark] stays wherever equipment is being scanned or compared.
class GearArt extends StatelessWidget {
  const GearArt({super.key, required this.id, this.size = 88});

  final String id;
  final double size;

  static String assetFor(String gearId) => 'assets/art/gear/$gearId.webp';

  @override
  Widget build(BuildContext context) {
    // Framed, the way the camp illustration is on the outpost screen. The
    // plates are drawn on bone paper, so without a border they are a bright
    // hard-edged rectangle pasted onto charcoal rather than something
    // mounted on the page. The fallback engraving gets no frame: it is
    // drawn in the theme's own colours and has no rectangle to contain.
    return Image.asset(
      assetFor(id),
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      // No plate drawn yet: the engraving is a complete answer on its own,
      // so this degrades to it rather than to a gap.
      errorBuilder: (_, __, ___) => GearMark(id: id, size: size),
      frameBuilder: (_, child, frame, wasSync) => wasSync || frame != null
          ? DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: T.boundary)),
              child: child,
            )
          : SizedBox(
              width: size, height: size, child: GearMark(id: id, size: size)),
    );
  }
}
