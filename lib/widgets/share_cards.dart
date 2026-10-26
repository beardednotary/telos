import 'package:flutter/material.dart';

import '../models/guild_identity.dart';
import '../models/models.dart';
import '../theme/telos_theme.dart';
import 'gear_art.dart';
import 'guild_sigil.dart';
import 'sector_header.dart';

/// The line under every shareable image. The card is seen by people who have
/// never heard of the app, so it says what it is.
const kShareTagline = 'Focus Timer RPG';

/// Instagram, TikTok and Shorts draw their own controls over the top and
/// bottom of a 9:16 frame. Text stays between these, in logical pixels of a
/// 360-wide card (about 250px and 340px of a 1080×1920 export).
const kStorySafeTop = 84.0;
const kStorySafeBottom = 113.0;

/// One expedition, sized for Stories and Reels: 360×640, exported at 3×.
/// Task and reflection text never enter it, as with [RunCard].
class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.record,
    required this.sector,
    required this.guildName,
    this.find,
  });

  final RunRecord record;
  final Sector sector;
  final String guildName;

  /// The best piece recovered, if any. The find is the run's big moment in
  /// the app, so it is the card's too.
  final GearDef? find;

  static const size = Size(360, 640);

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
                child: _Art(child: SectorHeader(sector: sector, height: 300))),
            Positioned.fill(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(24, 206, 24, kStorySafeBottom),
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
                              fontSize: 84, height: 1, color: T.text)),
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
                        const SizedBox(height: 16),
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

  static const feedSize = Size(360, 450);

  Size get size => story ? StoryCard.size : feedSize;

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
        Text(kShareTagline, style: T.micro),
        const Spacer(),
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
