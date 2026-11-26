import 'package:flutter/material.dart';

import '../models/guild_identity.dart';
import 'guild_sigil.dart';
import 'sigil.dart';

enum _MarkKind { sector, classEmblem, guild }

/// Ink plates for the moments when a mark is looked at, rather than scanned.
///
/// Colour comes from the caller: these assets contain only black and alpha.
/// Missing or still-loading plates keep the same-size stroke. Small marks
/// and stroke-by-stroke reveals continue to use the stroke widgets directly.
/// The Spire plate is shown only when its sector unlock is acknowledged.
class MarkPlate extends StatelessWidget {
  const MarkPlate.sector({
    super.key,
    required String sectorId,
    required this.color,
    this.size = 72,
  })  : _kind = _MarkKind.sector,
        _id = sectorId,
        _sigil = null;

  const MarkPlate.classEmblem({
    super.key,
    required String classId,
    required this.color,
    this.size = 72,
  })  : _kind = _MarkKind.classEmblem,
        _id = classId,
        _sigil = null;

  const MarkPlate.guild({
    super.key,
    required GuildSigil sigil,
    required this.color,
    this.size = 88,
  })  : _kind = _MarkKind.guild,
        _id = null,
        _sigil = sigil;

  final _MarkKind _kind;
  final String? _id;
  final GuildSigil? _sigil;
  final Color color;
  final double size;

  static String sectorAssetFor(String id) =>
      'assets/art/marks/sectors/$id.webp';
  static String classAssetFor(String id) => 'assets/art/marks/classes/$id.webp';
  static String guildAssetFor(GuildSigil sigil) =>
      'assets/art/marks/guild/${sigil.name}.webp';

  String get assetPath => switch (_kind) {
        _MarkKind.sector => sectorAssetFor(_id!),
        _MarkKind.classEmblem => classAssetFor(_id!),
        _MarkKind.guild => guildAssetFor(_sigil!),
      };

  Widget _stroke() => switch (_kind) {
        _MarkKind.sector => Sigil(sectorId: _id!, color: color, size: size),
        _MarkKind.classEmblem =>
          ClassEmblem(classId: _id!, color: color, size: size),
        // GuildEmblem's ordinary callers remain amber. This fallback must
        // match the caller's tint, including any alpha, just like the plate.
        _MarkKind.guild => ColorFiltered(
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            child: GuildEmblem(sigil: _sigil!, size: size),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => _stroke(),
      frameBuilder: (_, child, frame, wasSync) =>
          wasSync || frame != null ? child : _stroke(),
    );
    // One stable label whether loading, showing ink, or using the fallback.
    return _sigil == null
        ? image
        : Semantics(
            label: '${_sigil!.label} sigil',
            image: true,
            child: ExcludeSemantics(child: image),
          );
  }
}
