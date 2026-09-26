import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../theme/telos_theme.dart';
import 'sector_scene.dart';
import 'terminal.dart';

/// One run, as a picture someone can post.
///
/// The sector scene with this run's stake, the sector, the guild, and three
/// numbers: time, depth, integrity. Never the intent note - that was typed
/// for the player, not for a feed. No link or store mention while Telos is
/// unreleased (see the story bible, sharing).
///
/// Laid out at 360 x 450 and captured at 3x, so the file is 1080 x 1350,
/// the portrait size most feeds take without cropping.
class RunCard extends StatelessWidget {
  const RunCard({
    super.key,
    required this.record,
    required this.sector,
    required this.guildName,
    required this.depths,
    required this.floors,
    required this.status,
  });

  final RunRecord record;
  final Sector sector;
  final String guildName;
  final List<double> depths;
  final int floors;

  /// The debrief's own verdict: CLEAN RUN, RECALLED EARLY and so on.
  final String status;

  static const size = Size(360, 450);

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final sc = Color(sector.accent);
    final depth =
        (record.elapsedSeconds / 60 / sector.nominalMinutes).clamp(0.0, 1.6);
    final iColor = record.integrity >= 0.999
        ? T.good
        : record.integrity >= 0.7
            ? T.amber
            : T.bad;
    final d = record.endedAt;

    // Its own Material, so the text is styled wherever the card is built:
    // in the dialog, or offscreen.
    return SizedBox.fromSize(
      size: size,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          decoration: BoxDecoration(
            color: T.black,
            border: Border.all(color: T.line),
          ),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('TELOS',
                      style:
                          T.micro.copyWith(color: T.amber, letterSpacing: 3)),
                  const Spacer(),
                  Text(sector.designation, style: T.micro),
                ],
              ),
              const SizedBox(height: 18),
              Text(sector.name,
                  style: T.title.copyWith(fontSize: 22, color: sc)),
              const SizedBox(height: 4),
              Text(guildName, style: T.micro),
              const SizedBox(height: 16),
              Container(
                color: sc.withValues(alpha: 0.12),
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
                child: SectorScene(
                  sectorId: sector.id,
                  color: sc,
                  depths: depths,
                  latest: depth,
                  floors: floors,
                  height: 150,
                  animate: false,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Figure(
                      'TIME', '${record.elapsedSeconds ~/ 60}', 'm', T.amber),
                  _Figure('DEPTH', '${(depth * 100).round()}', '%', T.text),
                  _Figure('INTEGRITY', '${(record.integrity * 100).round()}',
                      '%', iColor),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Text(status,
                      style: T.micro.copyWith(
                          color: record.scraps || record.recalled
                              ? T.bad
                              : iColor)),
                  const Spacer(),
                  Text('${d.day} ${_months[d.month - 1]} ${d.year}',
                      style: T.micro),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, this.unit, this.color);
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: T.micro),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: T.numeric.copyWith(color: color)),
              const SizedBox(width: 3),
              Text(unit, style: T.mono.copyWith(fontSize: 13, color: T.dim)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the card as it will be shared, with the choice to share it or not.
/// Nothing happens unless the player taps SHARE here.
Future<void> showRunCard(BuildContext context, RunCard card) {
  final key = GlobalKey();
  return showDialog<void>(
    context: context,
    barrierColor: T.black.withValues(alpha: 0.85),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              child: RepaintBoundary(key: key, child: card),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TButton('CLOSE',
                    color: T.dim, onTap: () => Navigator.pop(ctx)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Builder(
                  builder: (b) => TButton('SHARE', filled: true, onTap: () {
                    final box = b.findRenderObject() as RenderBox?;
                    _share(
                        key,
                        card,
                        box == null
                            ? null
                            : box.localToGlobal(Offset.zero) & box.size);
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<void> _share(GlobalKey key, RunCard card, Rect? origin) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;

  final dir = await getTemporaryDirectory();
  final file =
      File('${dir.path}/telos-${card.sector.id}-${card.record.id}.png');
  await file.writeAsBytes(bytes.buffer.asUint8List());
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      // iPad anchors the share sheet to this; without it the sheet throws.
      sharePositionOrigin: origin,
    ),
  );
}
