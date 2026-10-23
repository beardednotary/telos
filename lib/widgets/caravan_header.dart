import 'package:flutter/material.dart';

import '../theme/telos_theme.dart';

/// The Caravan's arrival scene, for its camp card and debrief beat.
///
/// The artwork keeps wagons, animals and gate inside the central band so
/// the full 16:9 asset can be cropped to a 2.3:1 header. Like SectorHeader,
/// an unavailable illustration collapses instead of leaving an empty panel.
/// The parent supplies the card border and decides when the Caravan appears.
class CaravanHeader extends StatelessWidget {
  const CaravanHeader({super.key, this.height});

  static const assetPath = 'assets/art/caravan.webp';
  static const aspectRatio = 2.3;

  /// Optional override for a view that needs a particular header height.
  final double? height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      final h = height ?? width / aspectRatio;
      return Image.asset(
        assetPath,
        width: width,
        height: h,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        frameBuilder: (_, child, frame, wasSync) => wasSync || frame != null
            ? child
            : SizedBox(
                width: width,
                height: h,
                child: const ColoredBox(color: T.card),
              ),
      );
    });
  }
}
