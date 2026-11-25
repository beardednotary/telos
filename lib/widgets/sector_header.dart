import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/telos_theme.dart';

/// A sector's header illustration, if one has been drawn yet.
///
/// The slot ships before the art does. Assets live at
/// `assets/art/sectors/<id>.webp` and the whole directory is bundled, so
/// dropping a file in is the entire installation step - there is no list to
/// update and no code to change. Until a sector has one, this renders
/// nothing and the layout closes up around it.
///
/// This is mood, not information. [SectorScene] stays wherever the drawn
/// stakes matter, because those are the player's own runs and a picture of
/// a place cannot say where they got to.
class SectorHeader extends StatelessWidget {
  const SectorHeader({super.key, required this.sector, this.height});

  final Sector sector;

  /// Defaults to the camp illustration's height, and shortens on the
  /// narrowest phones the same way it does.
  final double? height;

  static String assetFor(String sectorId) => 'assets/art/sectors/$sectorId.webp';

  /// The height of a full-width illustration: 184 on a phone, 150 on the
  /// narrowest, and in proportion on a wider column (an iPad), so the crop
  /// frames the same picture it does on a phone instead of a thin strip.
  static double heightFor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= 340) return 150;
    return math.max(184, width * 184 / 440);
  }

  @override
  Widget build(BuildContext context) {
    final h = height ?? heightFor(context);

    return Image.asset(
      assetFor(sector.id),
      height: h,
      width: double.infinity,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      // No asset yet, or a bad one: take up no room rather than leaving a
      // grey box on the screen someone is deciding from.
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      frameBuilder: (_, child, frame, wasSync) => wasSync || frame != null
          ? child
          : SizedBox(height: h, child: const ColoredBox(color: T.card)),
    );
  }
}
