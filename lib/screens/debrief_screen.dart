import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/guild_state.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/gear_art.dart';
import '../widgets/guild_sigil.dart';
import '../widgets/camp_controls.dart';
import '../widgets/expedition_widgets.dart';
import '../widgets/run_card.dart';
import '../widgets/sector_scene.dart';
import '../widgets/terminal.dart';
import 'caravan_screen.dart';

class DebriefScreen extends StatefulWidget {
  const DebriefScreen({super.key, required this.record});
  final RunRecord record;
  @override
  State<DebriefScreen> createState() => _DebriefScreenState();
}

class _DebriefScreenState extends State<DebriefScreen>
    with SingleTickerProviderStateMixin {
  late final _note = TextEditingController(text: widget.record.note ?? '');
  late String? _progress = widget.record.progress;
  String? _open;
  bool _leaving = false;
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _reveal.value = 1;
  }

  @override
  void dispose() {
    _note.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _toggle(String section) =>
      setState(() => _open = _open == section ? null : section);
  Widget _beat(int step, Widget child) => Staged(
        animation: _reveal,
        step: step,
        steps: 3,
        child: child,
      );

  Future<void> _return() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    final c = context.read<GuildController>();
    if (_progress != null) await c.recordProgress(_progress!, note: _note.text);
    await c.dismissDebrief();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final g = c.g;
    final r = widget.record;
    final sector = sectorById(r.sectorId);
    final depth =
        (r.elapsedSeconds / 60 / sector.nominalMinutes).clamp(0.0, 1.6);
    final gear = r.loot.map(g.gearByUid).whereType<Gear>().toList()
      ..sort((a, b) => gearById(b.defId)
          .rarity
          .index
          .compareTo(gearById(a.defId).rarity.index));
    final pastDepths = [
      for (final p in g.log)
        if (p.sectorId == r.sectorId && p.id != r.id)
          p.elapsedSeconds / 60 / sector.nominalMinutes,
    ];
    final status = r.scraps
        ? 'BELOW SECTOR MINIMUM'
        : r.recalled
            ? 'RECALLED EARLY'
            : r.integrity >= .999
                ? 'CLEAN RUN'
                : 'PLANNED ${r.plannedMinutes}m';
    final duration = r.elapsedSeconds < 60
        ? '${r.elapsedSeconds} seconds'
        : '${r.elapsedMinutes} minutes';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Listener(
          onPointerDown: (_) {
            if (!_reveal.isCompleted) _reveal.value = 1;
          },
          child: Column(children: [
            Expanded(
                child: ListView(
              key: const Key('debrief-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              children: [
                _beat(
                    0,
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                              '$duration · ${(r.integrity * 100).round()}% Integrity',
                              textAlign: TextAlign.center,
                              style: T.label),
                          const SizedBox(height: 12),
                          Text('Back from ${fieldName(sector.name)}.',
                              textAlign: TextAlign.center, style: T.display),
                          if (r.recalled || r.scraps) ...[
                            const SizedBox(height: 10),
                            Text(
                                r.scraps
                                    ? 'Below the sector minimum. Credits only; your time still counts.'
                                    : 'Recalled early. Earnings reflect the time completed.',
                                style: T.secondary,
                                textAlign: TextAlign.center),
                          ],
                        ])),
                const SizedBox(height: 24),
                _beat(1, _find(c, gear, sector)),
                if (_caravan(g) case final caravan?) ...[
                  const SizedBox(height: 16),
                  _beat(1, caravan),
                ],
                if (_milestone(c) case final milestone?) ...[
                  const SizedBox(height: 16),
                  _beat(2, milestone),
                ],
                const SizedBox(height: 16),
                _beat(
                    3,
                    ExpeditionPanel(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            c.canUpgrade(g.campProject)
                                ? 'WITHIN REACH'
                                : 'YOUR NEXT PROJECT',
                            style: T.label),
                        const SizedBox(height: 8),
                        Text(projectTitle(g), style: T.title),
                        const SizedBox(height: 8),
                        Text(
                            c.canUpgrade(g.campProject)
                                ? 'You have enough to upgrade it at camp.'
                                : '${g.credits} / ${g.campProject.costAt(g.facilities[g.campProject]!).$1} credits · '
                                    '${g.alloy} / ${g.campProject.costAt(g.facilities[g.campProject]!).$2} alloy',
                            style: T.secondary),
                      ],
                    ))),
                const SizedBox(height: 16),
                _beat(
                    2,
                    CampDisclosure(
                      key: const Key('report-disclosure'),
                      title: 'Expedition report',
                      summary:
                          '+${r.credits} credits · +${r.alloy} alloy · +${r.intel} intel'
                          '${r.guildLevelUps > 0 ? '\nGuild level ${g.level} reached' : r.levelUps.isNotEmpty ? '\n${r.levelUps.length} members levelled up' : ''}',
                      icon: Icons.receipt_long_outlined,
                      expanded: _open == 'report',
                      onToggle: () => _toggle('report'),
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ResourceAmounts(
                                  credits: r.credits,
                                  alloy: r.alloy,
                                  intel: r.intel,
                                  gains: true),
                              const SizedBox(height: 12),
                              Text('Already in the stores.',
                                  style: T.secondary),
                              const SizedBox(height: 20),
                              Text('Field journal', style: T.title),
                              SectorScene(
                                  sectorId: sector.id,
                                  color: T.dim,
                                  depths: pastDepths,
                                  latest: depth,
                                  floors: g.spireComplete ? g.spireFloors : 0,
                                  height: 100,
                                  animate: false),
                              Text(
                                  '${(depth * 100).round()}% depth · ${r.plannedMinutes} minutes planned',
                                  style: T.secondary),
                              for (final line in r.journal)
                                Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(line, style: T.body)),
                              if (r.priorSurvey != null &&
                                  (gear.isNotEmpty || r.completedSpire)) ...[
                                const SizedBox(height: 20),
                                Text('Prior survey', style: T.title),
                                const SizedBox(height: 8),
                                Text(r.priorSurvey!, style: T.body),
                              ],
                              if (r.loot.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text('Recovered equipment', style: T.title),
                                for (final item in gear)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: _gearDetails(gearById(item.defId),
                                        caravan:
                                            r.caravanLoot.contains(item.uid)),
                                  ),
                                if (gear.length < r.loot.length)
                                  Text(
                                      'Some recovered equipment is no longer in the vault.',
                                      style: T.secondary),
                              ],
                              const SizedBox(height: 20),
                              Text('Progression', style: T.title),
                              const SizedBox(height: 8),
                              Text('+${r.guildXp} guild XP', style: T.body),
                              if (r.guildLevelUps > 0) ...[
                                Text('Guild level ${g.level}', style: T.title),
                                for (var level = g.level - r.guildLevelUps + 1;
                                    level <= g.level;
                                    level++)
                                  for (final unlock in guildLevelUnlocks(level))
                                    Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(unlock, style: T.body)),
                              ],
                              for (final id in r.squad)
                                if (g.memberById(id) != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                        '${g.memberById(id)!.name} · +${r.xpGained[id] ?? 0} XP · '
                                        '${r.levelUps.contains(id) ? 'reached level' : 'level'} ${g.memberById(id)!.level}',
                                        style: T.body),
                                  ),
                              const SizedBox(height: 20),
                              CampButton(
                                  label: 'Share expedition',
                                  onPressed: () => showRunCard(
                                      context,
                                      RunCard(
                                        record: r,
                                        sector: sector,
                                        guildName: g.guildName,
                                        depths: pastDepths,
                                        floors:
                                            g.spireComplete ? g.spireFloors : 0,
                                        status: status,
                                      ))),
                            ],
                          )),
                    )),
                if (r.intent.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _beat(
                      2,
                      CampDisclosure(
                        key: const Key('reflection-disclosure'),
                        title: 'Your focus',
                        summary: _progress == null
                            ? r.intent
                            : '${r.intent}\nProgress: ${fieldName(_progress!)}',
                        icon: Icons.edit_note_outlined,
                        expanded: _open == 'reflection',
                        onToggle: () => _toggle('reflection'),
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Did you make progress?', style: T.title),
                                const SizedBox(height: 6),
                                Text(
                                    'For your log only. Your answer does not change the rewards.',
                                    style: T.secondary),
                                const SizedBox(height: 12),
                                Wrap(spacing: 8, children: [
                                  for (final answer in ['YES', 'SOME', 'NO'])
                                    ChoiceChip(
                                      key: Key('progress-$answer'),
                                      label: Text(fieldName(answer)),
                                      selected: _progress == answer,
                                      onSelected: (_) {
                                        setState(() => _progress = answer);
                                        c.recordProgress(answer,
                                            note: _note.text);
                                      },
                                    ),
                                ]),
                                const SizedBox(height: 12),
                                TextField(
                                  key: const Key('reflection-note'),
                                  controller: _note,
                                  style: T.body,
                                  maxLines: 2,
                                  maxLength: 160,
                                  onChanged: (value) {
                                    if (_progress != null) {
                                      c.recordProgress(_progress!, note: value);
                                    }
                                  },
                                  decoration: const InputDecoration(
                                      labelText: 'Add a note (optional)'),
                                ),
                              ],
                            )),
                      )),
                ],
              ],
            )),
            ExpeditionFooter(
                child: CampButton(
              key: const Key('return-to-camp'),
              label: 'Return to camp',
              primary: true,
              onPressed: _leaving ? null : _return,
            )),
          ]),
        ),
      ),
    );
  }

  Widget _gearDetails(GearDef def, {bool caravan = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${fieldName(def.rarity.name)} · ${fieldName(def.name)}',
              style: T.title),
          if (caravan)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('From the caravan',
                    style: T.secondary.copyWith(color: T.amber))),
          if (def.flavor.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(def.flavor, style: T.secondary)),
          const SizedBox(height: 6),
          Text(describeBonus(def.bonus), style: T.body),
        ],
      );

  /// Crossing a threshold, given the same weight as finding something.
  ///
  /// A guild level opens sectors and classes, and it was a line of text
  /// inside a collapsed report: "Guild level 3 reached". A find got a card
  /// with a plate. Both are the loop paying out, so both get a beat.
  ///
  /// Member levels are quieter on purpose - they happen most runs, and a
  /// thing that happens most runs stops being a milestone if it shouts.
  Widget? _milestone(GuildController c) {
    final r = widget.record;
    final g = c.g;
    if (r.guildLevelUps == 0 && r.levelUps.isEmpty) return null;

    final unlocks = [
      for (var level = g.level - r.guildLevelUps + 1; level <= g.level; level++)
        ...guildLevelUnlocks(level),
    ];
    final risen = [
      for (final id in r.levelUps)
        if (g.memberById(id) != null) g.memberById(id)!,
    ];

    return ExpeditionPanel(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(r.guildLevelUps > 0 ? 'THE GUILD HAS RISEN' : 'THE SQUAD HAS RISEN',
            textAlign: TextAlign.center,
            style: T.label.copyWith(color: T.amber)),
        const SizedBox(height: 16),
        if (r.guildLevelUps > 0) ...[
          Center(child: GuildEmblem(sigil: g.guildSigil, size: 88)),
          const SizedBox(height: 18),
          Text('Guild level ${g.level}',
              textAlign: TextAlign.center, style: T.display),
          if (unlocks.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            for (final unlock in unlocks)
              Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(unlock,
                      textAlign: TextAlign.center, style: T.body)),
          ],
        ],
        if (risen.isNotEmpty) ...[
          if (r.guildLevelUps > 0) const SizedBox(height: 14),
          for (final m in risen)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${fieldName(m.name)} reached level ${m.level}',
                    textAlign: TextAlign.center, style: T.body)),
        ],
      ],
    ));
  }

  /// The caravan's beat: whether the squad left with it, what it said, and
  /// what it handed over. Only for a run that went out with it or after it.
  Widget? _caravan(GuildState g) {
    final r = widget.record;
    final share = r.caravan;
    if (share == null) return null;
    final names = [
      for (final uid in r.caravanLoot)
        if (g.gearByUid(uid) case final gear?) gearById(gear.defId).name,
    ];
    return ExpeditionPanel(
        key: const Key('debrief-caravan'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                share >= 1 && !r.recalled
                    ? 'WITH THE CARAVAN'
                    : "ON THE CARAVAN'S TRACKS",
                style: T.label.copyWith(color: T.amber)),
            const SizedBox(height: 12),
            if (r.caravanLine != null) ...[
              Text(r.caravanLine!, style: T.title.copyWith(height: 1.4)),
              const SizedBox(height: 12),
            ],
            Text(caravanDebriefLine(share: share, recalled: r.recalled),
                style: T.body),
            if (!r.recalled) ...[
              const SizedBox(height: 6),
              Text(caravanHaulLine(names), style: T.secondary),
            ],
          ],
        ));
  }

  Widget _find(GuildController c, List<Gear> gear, Sector sector) {
    final r = widget.record;
    if (r.completedSpire) {
      return ExpeditionPanel(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('THE LAST CHARTER', style: T.label),
          const SizedBox(height: 16),
          const Text('Find out what the structure in Sector 05 is for.',
              style: T.display),
          const SizedBox(height: 12),
          const Text(
              'The line for the holder is blank. They never put their name to it.',
              style: T.body),
          const SizedBox(height: 16),
          Text(c.g.spireCharterName ?? c.g.guildName,
              style: T.title.copyWith(color: T.amber)),
          const SizedBox(height: 16),
          Text(
              'Logged against this charter before you: ${GuildState.kCharterHours} hours. '
              'Yours: ${c.g.totalFocusMinutes ~/ 60}.',
              style: T.body),
          const SizedBox(height: 12),
          const Text(
              'The top course is unfinished. It is yours to carry on, or not.',
              style: T.body),
        ],
      ));
    }
    if (gear.isNotEmpty) {
      final def = gearById(gear.first.defId);
      return ExpeditionPanel(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              r.caravanLoot.contains(gear.first.uid)
                  ? '${def.rarity.label} FIND · FROM THE CARAVAN'
                  : '${def.rarity.label} FIND',
              textAlign: TextAlign.center,
              style: T.label.copyWith(color: T.amber)),
          const SizedBox(height: 16),
          // The one beat the whole return screen builds to, so it gets
          // the room. Larger here than on an item's own page.
          Center(child: GearArt(id: def.id, size: 124)),
          const SizedBox(height: 18),
          Text(fieldName(def.name),
              textAlign: TextAlign.center, style: T.display),
          if (def.flavor.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(def.flavor,
                textAlign: TextAlign.center,
                style: T.secondary.copyWith(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(describeBonus(def.bonus),
              textAlign: TextAlign.center, style: T.body),
          if (gear.length > 1) ...[
            const SizedBox(height: 10),
            Text('And ${gear.length - 1} more in the expedition report.',
                style: T.secondary, textAlign: TextAlign.center),
          ],
        ],
      ));
    }
    if (r.priorSurvey != null) {
      return ExpeditionPanel(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LEFT BY THE FIRST COMPANY', style: T.label),
          const SizedBox(height: 16),
          Text(r.priorSurvey!, style: T.title.copyWith(height: 1.4)),
        ],
      ));
    }
    return ExpeditionPanel(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(r.loot.isEmpty ? 'THE HAUL' : 'RECOVERED EQUIPMENT',
            style: T.label),
        const SizedBox(height: 12),
        Text(
            r.loot.isEmpty
                ? r.scraps
                    ? 'Back with scraps.'
                    : 'Supplies for the next expedition.'
                : '${r.loot.length} pieces recovered.',
            style: T.display),
        const SizedBox(height: 16),
        ResourceAmounts(
            credits: r.credits, alloy: r.alloy, intel: r.intel, gains: true),
        if (!r.scraps && r.loot.isEmpty) ...[
          const SizedBox(height: 12),
          Text('No equipment found this time.', style: T.secondary),
        ],
      ],
    ));
  }
}
