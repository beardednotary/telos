import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/camp_controls.dart';
import '../widgets/expedition_widgets.dart';
import '../widgets/management_widgets.dart';
import '../widgets/sector_scene.dart';

String _duration(int seconds) => seconds < 60
    ? '$seconds sec'
    : seconds % 60 == 0
        ? '${seconds ~/ 60} min'
        : '${seconds ~/ 60} min ${seconds % 60} sec';

String _stamp(BuildContext context, DateTime when) {
  final local = when.toLocal();
  final labels = MaterialLocalizations.of(context);
  return '${labels.formatShortDate(local)} · '
      '${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

/// History is a read-only record. Opening it never resolves or banks a run.
class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GuildController>().g;
    final log = g.log;
    final minutes = g.totalFocusMinutes;
    final average = log.isEmpty
        ? 0
        : (log.fold<double>(0, (sum, r) => sum + r.integrity) /
                log.length *
                100)
            .round();
    return Scaffold(
      appBar: AppBar(title: const Text('Field log')),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          key: const Key('field-log-list'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: log.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FOCUS TIME IN THIS LOG', style: T.label),
                      const SizedBox(height: 10),
                      Text('${minutes ~/ 60}h ${minutes % 60}m',
                          style: T.numeric),
                      const SizedBox(height: 12),
                      Text(
                          '${expeditionCount(log.length)} · ${g.cleanRuns} at 100% Integrity',
                          style: T.secondary),
                      if (log.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                            'Average · ${minutes ~/ log.length} min · $average% Integrity',
                            style: T.secondary),
                        const SizedBox(height: 16),
                        Text(
                            log.length >= 500
                                ? 'Your latest 500 expeditions.'
                                : 'Most recent first. Tap an entry for its report.',
                            style: T.secondary),
                      ] else ...[
                        const SizedBox(height: 28),
                        ExpeditionPanel(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('The log is blank.', style: T.title),
                            const SizedBox(height: 8),
                            Text(
                                'The first company kept theirs for eleven years. '
                                'Yours starts with your first expedition: every '
                                'session, report and reflection is kept here.',
                                style: T.secondary),
                          ],
                        )),
                      ],
                    ]),
              );
            }
            return _LogEntry(record: log[index - 1]);
          },
        ),
      ),
    );
  }
}

class _LogEntry extends StatelessWidget {
  const _LogEntry({required this.record});
  final RunRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final sector = sectorById(r.sectorId);
    return Material(
      color: T.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: const BorderSide(color: T.boundary),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('log-${r.id}'),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ExpeditionRecordScreen(record: r))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(_stamp(context, r.endedAt), style: T.secondary)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: T.dim, size: 20),
            ]),
            const SizedBox(height: 12),
            Text(r.intent.isEmpty ? fieldName(sector.name) : r.intent,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: T.body.copyWith(fontWeight: FontWeight.w600)),
            if (r.intent.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(fieldName(sector.name), style: T.secondary),
            ],
            const SizedBox(height: 12),
            Text(
                '${_duration(r.elapsedSeconds)} · ${(r.integrity * 100).round()}% Integrity'
                '${r.recalled ? ' · Recalled' : ''}',
                style: T.secondary),
          ]),
        ),
      ),
    );
  }
}

/// A past report uses only recorded results. Current member levels and guild
/// unlocks are deliberately omitted: the save does not snapshot those values.
class ExpeditionRecordScreen extends StatefulWidget {
  const ExpeditionRecordScreen({super.key, required this.record});
  final RunRecord record;

  @override
  State<ExpeditionRecordScreen> createState() => _ExpeditionRecordScreenState();
}

class _ExpeditionRecordScreenState extends State<ExpeditionRecordScreen> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GuildController>().g;
    final r = widget.record;
    final sector = sectorById(r.sectorId);
    final recovered = r.loot.map(g.gearByUid).whereType<Gear>().toList();
    final missing = r.loot.length - recovered.length;
    final depth =
        (r.elapsedSeconds / 60 / sector.nominalMinutes).clamp(0.0, 1.6);
    return Scaffold(
      appBar: AppBar(title: const Text('Expedition record')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(_stamp(context, r.endedAt), style: T.secondary),
            const SizedBox(height: 12),
            Text(fieldName(sector.name), style: T.display),
            const SizedBox(height: 12),
            Text(
                '${_duration(r.elapsedSeconds)} of ${r.plannedMinutes} min planned',
                style: T.body),
            const SizedBox(height: 4),
            Text(
                '${(r.integrity * 100).round()}% Integrity · '
                '${r.recalled ? 'Recalled' : 'Completed'}${r.scraps ? ' · Scraps only' : ''}',
                style: T.secondary),
            const SizedBox(height: 16),
            SectorScene(
                sectorId: sector.id,
                color: T.amber,
                latest: depth,
                animate: false,
                height: 120),
            const SizedBox(height: 20),
            ExpeditionPanel(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RECORDED HAUL', style: T.label),
                const SizedBox(height: 12),
                ResourceAmounts(
                    credits: r.credits,
                    alloy: r.alloy,
                    intel: r.intel,
                    gains: true),
                const SizedBox(height: 12),
                Text('Banked when this expedition ended.', style: T.secondary),
              ],
            )),
            if (r.intent.isNotEmpty ||
                r.progress != null ||
                (r.note?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              ExpeditionPanel(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR FOCUS', style: T.label),
                  if (r.intent.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(r.intent, style: T.body),
                  ],
                  if (r.progress != null) ...[
                    const SizedBox(height: 8),
                    Text('Progress: ${fieldName(r.progress!)}',
                        style: T.secondary),
                  ],
                  if (r.note?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text(r.note!, style: T.body),
                  ],
                ],
              )),
            ],
            const SizedBox(height: 12),
            CampDisclosure(
              key: const Key('record-journal'),
              title: 'Field journal',
              summary:
                  '${r.journal.length} entries${r.priorSurvey != null ? ' · Prior record recovered' : ''}',
              icon: Icons.menu_book_outlined,
              expanded: _open == 'journal',
              onToggle: () =>
                  setState(() => _open = _open == 'journal' ? null : 'journal'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r.journal.isEmpty)
                        Text('No journal entries recorded.',
                            style: T.secondary),
                      for (final line in r.journal)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(line, style: T.body)),
                      if (r.priorSurvey != null) ...[
                        const Divider(height: 24),
                        Text('LEFT BY THE FIRST COMPANY', style: T.label),
                        const SizedBox(height: 12),
                        Text(r.priorSurvey!, style: T.body),
                      ],
                      if (r.completedSpire) ...[
                        const SizedBox(height: 16),
                        const Text(
                            'This expedition recovered the last Spire record.',
                            style: T.body),
                      ],
                    ]),
              ),
            ),
            const SizedBox(height: 12),
            CampDisclosure(
              key: const Key('record-squad'),
              title: 'Squad & equipment',
              summary:
                  '${r.squad.length} deployed · ${r.loot.length} pieces recovered',
              icon: Icons.groups_outlined,
              expanded: _open == 'squad',
              onToggle: () =>
                  setState(() => _open = _open == 'squad' ? null : 'squad'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final id in r.squad) ...[
                        Text(
                            '${g.memberById(id)?.name ?? 'Former member'} · +${r.xpGained[id] ?? 0} XP'
                            '${r.levelUps.contains(id) ? ' · Levelled up' : ''}',
                            style: T.body),
                        const SizedBox(height: 8),
                      ],
                      Text(
                          'Guild · +${r.guildXp} XP'
                          '${r.guildLevelUps > 0 ? ' · +${r.guildLevelUps} levels' : ''}',
                          style: T.secondary),
                      const Divider(height: 28),
                      if (r.loot.isEmpty)
                        Text('No equipment found on this expedition.',
                            style: T.secondary),
                      for (final gear in recovered)
                        GearEntry(
                          def: gearById(gear.defId),
                          onTap: () => showCampSheet(
                              context,
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const CampSheetHeader(
                                      title: 'Recovered equipment'),
                                  GearDetail(def: gearById(gear.defId)),
                                ],
                              )),
                        ),
                      if (missing > 0)
                        Text(
                            '$missing recovered ${missing == 1 ? 'piece is' : 'pieces are'} no longer in the vault. '
                            'Older records keep the count, but not the names of removed equipment.',
                            style: T.secondary),
                    ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
