import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/terminal.dart';

/// The after-action report. This is the reward: everything the run produced is
/// hidden until the work is over, then delivered at once.
class DebriefScreen extends StatefulWidget {
  const DebriefScreen({super.key, required this.record});
  final RunRecord record;

  @override
  State<DebriefScreen> createState() => _DebriefScreenState();
}

class _DebriefScreenState extends State<DebriefScreen> {
  final _note = TextEditingController();
  String? _progress;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<GuildController>();
    final r = widget.record;
    final sector = sectorById(r.sectorId);
    final mins = r.elapsedMinutes;
    final depth = (r.elapsedSeconds / 60 / sector.nominalMinutes).clamp(0.0, 1.6);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                children: [
                  // -- header -------------------------------------------
                  Row(
                    children: [
                      Text('DEBRIEF', style: T.heading),
                      const SizedBox(width: 12),
                      Expanded(child: Container(height: 1, color: T.line)),
                      const SizedBox(width: 12),
                      Text(sector.designation, style: T.label),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(sector.name,
                      style: T.heading.copyWith(fontSize: 18, letterSpacing: 2.4)),
                  const SizedBox(height: 14),

                  Panel(
                    child: Column(
                      children: [
                        KV('ELAPSED', '${mins}m of ${r.plannedMinutes}m',
                            bold: true),
                        KV(
                          'INTEGRITY',
                          '${(r.integrity * 100).round()}%'
                          '${r.integrity >= 0.999 ? '  CLEAN RUN' : ''}',
                          color: r.integrity >= 0.999
                              ? T.good
                              : r.integrity >= 0.7
                                  ? T.amber
                                  : T.bad,
                          bold: true,
                        ),
                        KV('DEPTH REACHED', '${(depth * 100).round()}%'),
                        if (r.recalled)
                          const KV('STATUS', 'RECALLED EARLY', color: T.bad),
                        if (r.scraps)
                          const KV('STATUS', 'BELOW SECTOR MINIMUM',
                              color: T.bad),
                      ],
                    ),
                  ),

                  // -- journal ------------------------------------------
                  const SizedBox(height: 22),
                  const PanelTitle('FIELD JOURNAL'),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in r.journal)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('> ',
                                    style: T.mono.copyWith(color: T.dim)),
                                Expanded(
                                  child: Text(line,
                                      style: T.mono.copyWith(
                                          fontSize: 12, height: 1.6)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // -- yield --------------------------------------------
                  const SizedBox(height: 22),
                  const PanelTitle('RECOVERED'),
                  Panel(
                    child: Column(
                      children: [
                        _Gain('CREDITS', r.credits, T.amber),
                        _Gain('ALLOY', r.alloy, T.text),
                        _Gain('INTEL', r.intel, T.cyan),
                      ],
                    ),
                  ),

                  // -- loot ---------------------------------------------
                  if (r.loot.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    PanelTitle('SALVAGE',
                        color: T.amber,
                        trailing: Text('${r.loot.length} FOUND',
                            style: T.label.copyWith(color: T.amber))),
                    for (final uid in r.loot) ...[
                      _LootCard(uid: uid),
                      const SizedBox(height: 8),
                    ],
                  ],

                  // -- progression ---------------------------------------
                  const SizedBox(height: 22),
                  const PanelTitle('ROSTER PROGRESSION'),
                  Panel(
                    child: Column(
                      children: [
                        for (final id in r.squad) _MemberProgress(id: id, rec: r),
                        const SizedBox(height: 6),
                        const Divider(height: 18, color: T.line),
                        KV('GUILD XP', '+${r.guildXp}'),
                        if (r.guildLevelUps > 0)
                          KV('GUILD LEVEL',
                              'UP x${r.guildLevelUps}  ->  LV ${c.g.level}',
                              color: T.good, bold: true),
                      ],
                    ),
                  ),

                  // -- honour-system self report -------------------------
                  const SizedBox(height: 22),
                  if (r.intent.isNotEmpty) ...[
                    const PanelTitle('YOU SET OUT TO'),
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.intent,
                              style: T.mono.copyWith(fontSize: 14, height: 1.5)),
                          const SizedBox(height: 14),
                          Text('DID YOU MAKE PROGRESS?', style: T.label),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (final a in ['YES', 'SOME', 'NO']) ...[
                                TChip(
                                  a,
                                  selected: _progress == a,
                                  color: a == 'YES'
                                      ? T.good
                                      : a == 'SOME'
                                          ? T.amber
                                          : T.dim,
                                  onTap: () {
                                    setState(() => _progress = a);
                                    c.recordProgress(a, note: _note.text);
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _note,
                            style: T.mono.copyWith(fontSize: 13),
                            cursorColor: T.amber,
                            maxLines: 2,
                            maxLength: 160,
                            onChanged: (v) {
                              if (_progress != null) {
                                c.recordProgress(_progress!, note: v);
                              }
                            },
                            decoration: InputDecoration(
                              isDense: true,
                              counterText: '',
                              hintText: 'Add a note (optional)',
                              hintStyle:
                                  T.mono.copyWith(color: T.dim, fontSize: 13),
                              border: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: T.line)),
                              enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: T.line)),
                              focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: T.amber)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: TButton(
                'RETURN TO OUTPOST',
                filled: true,
                onTap: () {
                  if (_progress != null) {
                    c.recordProgress(_progress!, note: _note.text);
                  }
                  c.dismissDebrief();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Gain extends StatelessWidget {
  const _Gain(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      KV(label, value > 0 ? '+$value' : '-', color: value > 0 ? color : T.dim);
}

class _LootCard extends StatelessWidget {
  const _LootCard({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final c = context.read<GuildController>();
    final gear = c.g.gearByUid(uid);
    if (gear == null) return const SizedBox.shrink();
    final def = gearById(gear.defId);
    final color = switch (def.rarity) {
      Rarity.common => T.dim,
      Rarity.uncommon => T.text,
      Rarity.rare => T.cyan,
      Rarity.epic => T.amber,
    };

    return Panel(
      accent: color,
      selected: def.rarity.index >= Rarity.rare.index,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('[${def.rarity.label}]',
                  style: T.label.copyWith(color: color, fontSize: 9)),
              const Spacer(),
              Text('SALVAGE', style: T.label.copyWith(fontSize: 9)),
            ],
          ),
          const SizedBox(height: 6),
          Text(def.name,
              style: T.mono.copyWith(
                  fontSize: 15, color: color, letterSpacing: 1.4)),
          if (def.flavor.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(def.flavor,
                style: T.label.copyWith(
                    fontSize: 10, letterSpacing: 0.3, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 8),
          for (final l in def.bonus.lines)
            Text('> $l', style: T.mono.copyWith(fontSize: 11, color: T.good)),
        ],
      ),
    );
  }
}

class _MemberProgress extends StatelessWidget {
  const _MemberProgress({required this.id, required this.rec});
  final String id;
  final RunRecord rec;

  @override
  Widget build(BuildContext context) {
    final c = context.read<GuildController>();
    final m = c.g.memberById(id);
    if (m == null) return const SizedBox.shrink();
    final levelled = rec.levelUps.contains(id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(m.name, style: T.mono.copyWith(letterSpacing: 1.2)),
              const SizedBox(width: 8),
              Text('+${rec.xpGained[id] ?? 0} XP', style: T.label),
              const Spacer(),
              Text(
                levelled ? 'LV ${m.level}  UP' : 'LV ${m.level}',
                style: T.mono.copyWith(
                    fontSize: 12, color: levelled ? T.good : T.dim),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Meter(
            value: m.xp / m.xpToNext,
            segments: 18,
            height: 5,
            color: levelled ? T.good : T.amber,
          ),
        ],
      ),
    );
  }
}
