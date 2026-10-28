import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/content.dart';
import '../models/guild_identity.dart';
import '../models/guild_state.dart';
import '../models/models.dart';
import '../theme/telos_theme.dart';
import 'camp_controls.dart';
import 'gear_art.dart';
import 'guild_sigil.dart';
import 'management_widgets.dart';
import 'sector_header.dart';

/// The line under every shareable image. The card is seen by people who have
/// never heard of the app, so it says what it is.
const kShareTagline = 'Focus Timer RPG';

/// Instagram, TikTok and Shorts draw their own controls over the top and
/// bottom of a 9:16 frame. Text stays between these, in logical pixels of a
/// 360-wide card (about 250px and 340px of a 1080×1920 export).
const kStorySafeTop = 84.0;
const kStorySafeBottom = 113.0;

/// Every card is laid out 360 wide and exported at 3x: 1080x1920 for
/// Stories, Reels and TikTok, 1080x1350 (4:5) for a feed post.
const kStorySize = Size(360, 640);
const kPostSize = Size(360, 450);

/// One expedition, as a Story or a feed post. Task and reflection text never
/// enter it.
class ExpeditionCard extends StatelessWidget {
  const ExpeditionCard({
    super.key,
    required this.record,
    required this.sector,
    required this.guildName,
    this.find,
    this.story = true,
  });

  final RunRecord record;
  final Sector sector;
  final String guildName;

  /// The best piece recovered, if any. The find is the run's big moment in
  /// the app, so it is the card's too.
  final GearDef? find;
  final bool story;

  Size get size => story ? kStorySize : kPostSize;

  @override
  Widget build(BuildContext context) {
    final date = record.endedAt.toLocal();
    final minutes = record.elapsedMinutes;
    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: size,
        child: Material(
          color: T.band,
          child: Stack(children: [
            // The art runs under the platform's top controls; text does
            // not. The text starts on the art's faded lower edge.
            Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _Art(
                    height: story ? 300 : 210,
                    child: SectorHeader(
                        sector: sector, height: story ? 300 : 210))),
            Positioned.fill(
              child: Padding(
                padding: story
                    ? const EdgeInsets.fromLTRB(24, 206, 24, kStorySafeBottom)
                    : const EdgeInsets.fromLTRB(20, 124, 20, 18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sector.designation,
                          style: T.micro.copyWith(color: T.amber)),
                      const SizedBox(height: 6),
                      _Fit(
                          height: 34,
                          child: Text(fieldName(sector.name),
                              style: T.display.copyWith(fontSize: 30))),
                      _Fit(
                          height: 22,
                          child: Text(guildName,
                              style: T.body.copyWith(color: T.dim))),
                      const Spacer(),
                      Text(
                          record.elapsedSeconds < 60
                              ? '${record.elapsedSeconds}'
                              : '$minutes',
                          style: T.big.copyWith(
                              fontSize: story ? 84 : 60,
                              height: 1,
                              color: T.text)),
                      const SizedBox(height: 4),
                      Text(
                          record.elapsedSeconds < 60
                              ? 'seconds of focus.'
                              : minutes == 1
                                  ? 'minute of focus.'
                                  : 'minutes of focus.',
                          style: T.title),
                      // What Integrity measures, said plainly: Telos was
                      // never reopened. A percentage means nothing to
                      // someone scrolling past, so a lower one says
                      // nothing at all.
                      if (record.integrity >= .999) ...[
                        const SizedBox(height: 6),
                        Text('Not checked once.',
                            style: T.body.copyWith(color: T.dim)),
                      ],
                      if (find case final def?) ...[
                        SizedBox(height: story ? 16 : 12),
                        Row(children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: GearArt(id: def.id, size: 56)),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${def.rarity.label} FIND',
                                  style: T.micro.copyWith(color: T.amber)),
                              const SizedBox(height: 4),
                              Text(fieldName(def.name), style: T.heading),
                            ],
                          )),
                        ]),
                      ],
                      const Spacer(),
                      _Footer(
                          right:
                              '${date.year}-${date.month.toString().padLeft(2, '0')}-'
                              '${date.day.toString().padLeft(2, '0')}'),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The whole record, for the Field log: 360×450 (4:5) for a feed post, or
/// 360×640 for Stories, exported at 3×. A record only goes up, so it is
/// something to show, not a streak to keep.
class TotalsCard extends StatelessWidget {
  const TotalsCard({
    super.key,
    required this.guildName,
    required this.sigil,
    required this.focusMinutes,
    required this.daysWorked,
    required this.expeditions,
    required this.cleanRuns,
    required this.since,
    this.story = false,
  });

  final String guildName;
  final GuildSigil sigil;
  final int focusMinutes;
  final int daysWorked;
  final int expeditions;
  final int cleanRuns;
  final DateTime since;
  final bool story;

  Size get size => story ? kStorySize : kPostSize;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final art = Image.asset('assets/art/camp.webp',
        height: story ? 300 : 150,
        fit: BoxFit.cover,
        alignment: const Alignment(0, .15),
        excludeFromSemantics: true);
    final record =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        GuildEmblem(sigil: sigil, size: 26),
        const SizedBox(width: 10),
        Expanded(
            child: _Fit(height: 26, child: Text(guildName, style: T.heading))),
      ]),
      const Spacer(),
      Text('${focusMinutes ~/ 60}h ${focusMinutes % 60}m',
          style: T.big
              .copyWith(fontSize: story ? 64 : 56, height: 1, color: T.text)),
      const SizedBox(height: 4),
      Text('of focus, kept.', style: T.title),
      const SizedBox(height: 18),
      Row(children: [
        _Figure('Days worked', '$daysWorked'),
        _Figure('Expeditions', '$expeditions'),
        _Figure('Clean runs', '$cleanRuns'),
      ]),
      const Spacer(),
      _Footer(right: 'Since ${_months[since.month - 1]} ${since.year}'),
    ]);
    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: size,
        child: Material(
          color: T.band,
          // Laid out as the run cards are: a Story starts its text on the
          // art's faded edge and keeps clear of the platform's controls.
          child: story
              ? Stack(children: [
                  Positioned(
                      top: 0, left: 0, right: 0, child: _Art(child: art)),
                  Positioned.fill(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              24, 230, 24, kStorySafeBottom),
                          child: record)),
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      _Art(height: 150, child: art),
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                              child: record)),
                    ]),
        ),
      ),
    );
  }
}

/// Art across the top, fading into the card so the text below it does not
/// sit on a hard edge.
class _Art extends StatelessWidget {
  const _Art({required this.child, this.height = 300});
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Stack(fit: StackFit.expand, children: [
          child,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [.4, .92],
                colors: [Color(0x0012181D), T.band],
              ),
            ),
          ),
        ]),
      );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.right});
  final String right;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text('TELOS',
            style: T.label.copyWith(color: T.amber, letterSpacing: 3)),
        const SizedBox(width: 10),
        // Gives way before the date does, should a font ever run wide.
        Expanded(
            child: Text(kShareTagline,
                style: T.micro, maxLines: 1, overflow: TextOverflow.clip)),
        const SizedBox(width: 8),
        Text(right, style: T.micro),
      ]);
}

class _Fit extends StatelessWidget {
  const _Fit({required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: child),
      );
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: T.mono.copyWith(fontSize: 24)),
          const SizedBox(height: 2),
          Text(label, style: T.secondary.copyWith(fontSize: 12)),
        ],
      ));
}

/// Preview first; native sharing happens only after an explicit Share tap.
/// [card] builds the image in either format, so the player can pick where
/// it is going. [name] becomes the file name.
Future<void> showSharePreview(
  BuildContext context, {
  required Widget Function(bool story) card,
  required String name,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _SharePreview(card: card, name: name),
    );

class _SharePreview extends StatefulWidget {
  const _SharePreview({required this.card, required this.name});
  final Widget Function(bool story) card;
  final String name;

  @override
  State<_SharePreview> createState() => _SharePreviewState();
}

class _SharePreviewState extends State<_SharePreview> {
  final _capture = GlobalKey();
  bool _story = true;
  String? _error;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: T.black,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: T.boundary),
          borderRadius: BorderRadius.circular(4),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 8, children: [
              for (final (story, label) in [(true, 'Story'), (false, 'Post')])
                ChoiceChip(
                  key: Key('share-${label.toLowerCase()}'),
                  label: Text(label),
                  selected: _story == story,
                  onSelected: (_) => setState(() => _story = story),
                ),
            ]),
            const SizedBox(height: 12),
            Flexible(
                child: FittedBox(
              child:
                  RepaintBoundary(key: _capture, child: widget.card(_story)),
            )),
            const SizedBox(height: 12),
            Text(
                _story
                    ? 'Sized for Stories, Reels and TikTok. Task notes stay private.'
                    : 'Sized for a feed post. Task notes stay private.',
                style: T.secondary),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: T.secondary),
            ],
            const SizedBox(height: 16),
            Builder(
                builder: (buttonContext) => CampAction(
                      key: const Key('share-card'),
                      label: 'Share',
                      onPressed: () async {
                        setState(() => _error = null);
                        final box =
                            buttonContext.findRenderObject() as RenderBox?;
                        try {
                          await _share(
                              _capture,
                              '${widget.name}-${_story ? 'story' : 'post'}',
                              box == null
                                  ? null
                                  : box.localToGlobal(Offset.zero) & box.size);
                        } catch (_) {
                          if (mounted) {
                            setState(() => _error =
                                'Could not share the image. Please try again.');
                          }
                        }
                      },
                    )),
            const SizedBox(height: 8),
            CampButton(
                label: 'Close preview',
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
      );
}

Future<void> _share(GlobalKey key, String name, Rect? origin) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  // 3x whatever the preview's scale: the boundary sits inside the FittedBox,
  // so it keeps the card's own logical size.
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) return;
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/telos-$name.png');
  await file.writeAsBytes(bytes.buffer.asUint8List());
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'image/png')],
    sharePositionOrigin: origin,
  ));
}

/// The share preview for one expedition, from its report or the Field log.
/// The find shown is the best piece it recovered that the guild still has.
Future<void> shareExpedition(BuildContext context, RunRecord r, GuildState g) {
  final sector = sectorById(r.sectorId);
  final finds = [
    for (final uid in r.loot)
      if (g.gearByUid(uid) case final gear?) gearById(gear.defId),
  ]..sort((a, b) => b.rarity.index.compareTo(a.rarity.index));
  return showSharePreview(
    context,
    name: '${sector.id}-${r.id}',
    card: (story) => ExpeditionCard(
      record: r,
      sector: sector,
      guildName: g.guildName,
      find: finds.firstOrNull,
      story: story,
    ),
  );
}

/// The share preview for the whole record, from the Field log.
Future<void> shareRecord(BuildContext context, GuildState g) =>
    showSharePreview(
      context,
      name: 'record',
      card: (story) => TotalsCard(
        guildName: g.guildName,
        sigil: g.guildSigil,
        focusMinutes: g.totalFocusMinutes,
        daysWorked: g.daysWorked,
        expeditions: g.expeditions,
        cleanRuns: g.cleanRuns,
        since: (g.firstRunAt ?? DateTime.now()).toLocal(),
        story: story,
      ),
    );
