import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/sigil.dart';
import '../widgets/terminal.dart';

/// The after-action report. This is the reward: everything the run produced is
/// hidden until the work is over, then delivered in sequence.
class DebriefScreen extends StatefulWidget {
  const DebriefScreen({super.key, required this.record});
  final RunRecord record;

  @override
  State<DebriefScreen> createState() => _DebriefScreenState();
}

class _DebriefScreenState extends State<DebriefScreen>
    with SingleTickerProviderStateMixin {
  final _note = TextEditingController();
  String? _progress;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  static const int _beats = 7;

  @override
  void dispose() {
    _reveal.dispose();
    _note.dispose();
    super.dispose();
  }

  Widget _beat(int step, Widget child) =>
      Staged(animation: _reveal, step: step, steps: _beats, child: child);

  @override
  Widget build(BuildContext context) {
    final c = context.read<GuildController>();
    final r = widget.record;
    final sector = sectorById(r.sectorId);
    final depth =
        (r.elapsedSeconds / 60 / sector.nominalMinutes).clamp(0.0, 1.6);
    final sc = Color(sector.accent);
    final clean = r.integrity >= 0.999;
    final iColor = clean
        ? T.good
        : r.integrity >= 0.7
            ? T.amber
            : T.bad;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => _reveal.value = 1,
          behavior: HitTestBehavior.deferToChild,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    // -- 0. header -----------------------------------------
                    _beat(
                      0,
                      Container(
                        width: double.infinity,
                        color: sc.withValues(alpha: 0.12),
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('DEBRIEF',
                                    style: T.micro.copyWith(color: sc)),
                                const Spacer(),
                                Text(sector.designation, style: T.micro),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(sector.name,
                                      style: T.title
                                          .copyWith(fontSize: 24, color: sc)),
                                ),
                                const SizedBox(width: 14),
                                SigilPlate(
                                    sectorId: sector.id, color: sc, size: 72),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // -- 1. the two numbers that matter ---------------------
                    _beat(
                      1,
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('FOCUSED', style: T.micro),
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text('${r.elapsedMinutes}',
                                              style: T.big.copyWith(
                                                  fontSize: 48,
                                                  color: T.amber)),
                                          Text('m',
                                              style: T.mono.copyWith(
                                                  fontSize: 16, color: T.dim)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('INTEGRITY', style: T.micro),
                                    const SizedBox(height: 6),
                                    Text('${(r.integrity * 100).round()}%',
                                        style: T.big.copyWith(
                                            fontSize: 48, color: iColor)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Meter(
                                value: depth.clamp(0.0, 1.0),
                                segments: 30,
                                height: 4,
                                color: iColor),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('DEPTH ${(depth * 100).round()}%',
                                    style: T.micro),
                                const Spacer(),
                                Text(
                                  r.scraps
                                      ? 'BELOW SECTOR MINIMUM'
                                      : r.recalled
                                          ? 'RECALLED EARLY'
                                          : clean
                                              ? 'CLEAN RUN'
                                              : 'PLANNED ${r.plannedMinutes}m',
                                  style: T.micro.copyWith(
                                      color: (r.scraps || r.recalled)
                                          ? T.bad
                                          : iColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // -- 2. journal ----------------------------------------
                    const SizedBox(height: 26),
                    _beat(
                      2,
                      Container(
                        color: T.band,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FIELD JOURNAL', style: T.micro),
                            const SizedBox(height: 12),
                            for (final line in r.journal)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('> ',
                                        style: T.mono.copyWith(color: T.dim)),
                                    Expanded(
                                      child: Text(line,
                                          style: T.mono.copyWith(
                                              fontSize: 13, height: 1.65)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // -- 3. yield ------------------------------------------
                    const SizedBox(height: 26),
                    _beat(
                      3,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('RECOVERED',
                                    style: T.micro.copyWith(color: T.steel)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child:
                                        Container(height: 1, color: T.line)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _Gain('CREDITS', r.credits, T.amber),
                                _Gain('ALLOY', r.alloy, T.steel),
                                _Gain('INTEL', r.intel, T.cyan),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // -- 4. salvage: the beat everything builds to ----------
                    if (r.loot.isNotEmpty)
                      _beat(
                        4,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 28),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                  '> and something else came back with them',
                                  style: T.micro.copyWith(
                                      color: T.amber, letterSpacing: 0.4)),
                            ),
                            const SizedBox(height: 12),
                            for (final uid in r.loot) _LootBand(uid: uid),
                          ],
                        ),
                      ),

                    // -- 5. progression -------------------------------------
                    const SizedBox(height: 28),
                    _beat(
                      5,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('PROGRESSION',
                                    style: T.micro.copyWith(color: T.steel)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child:
                                        Container(height: 1, color: T.line)),
                                const SizedBox(width: 12),
                                Text('+${r.guildXp} GUILD XP',
                                    style: T.micro.copyWith(color: T.amber)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            for (final id in r.squad)
                              _MemberProgress(id: id, rec: r),
                            if (r.guildLevelUps > 0) ...[
                              const SizedBox(height: 10),
                              Text(
                                  'GUILD LEVEL UP  x${r.guildLevelUps}  ->  '
                                  'LV ${c.g.level}',
                                  style: T.mono.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: 1.6,
                                      color: T.good)),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // -- 6. honour-system self report -----------------------
                    if (r.intent.isNotEmpty)
                      _beat(
                        6,
                        Column(
                          children: [
                            const SizedBox(height: 28),
                            Container(
                              width: double.infinity,
                              color: T.band,
                              padding:
                                  const EdgeInsets.fromLTRB(20, 18, 20, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('YOU SET OUT TO', style: T.micro),
                                  const SizedBox(height: 8),
                                  Text(r.intent,
                                      style: T.mono.copyWith(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w300,
                                          height: 1.45)),
                                  const SizedBox(height: 18),
                                  Text('DID YOU MAKE PROGRESS?', style: T.micro),
                                  const SizedBox(height: 10),
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
                                            c.recordProgress(a,
                                                note: _note.text);
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 16),
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
                                      hintStyle: T.mono
                                          .copyWith(color: T.dim, fontSize: 13),
                                      border: const UnderlineInputBorder(
                                          borderSide:
                                              BorderSide(color: T.line)),
                                      enabledBorder: const UnderlineInputBorder(
                                          borderSide:
                                              BorderSide(color: T.line)),
                                      focusedBorder: const UnderlineInputBorder(
                                          borderSide:
                                              BorderSide(color: T.amber)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: GestureDetector(
                  onTap: () {
                    if (_progress != null) {
                      c.recordProgress(_progress!, note: _note.text);
                    }
                    c.dismissDebrief();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: T.amber.withValues(alpha: 0.12),
                      border: Border.all(color: T.amber, width: 1.5),
                    ),
                    child: Text('RETURN TO OUTPOST',
                        style: T.mono.copyWith(
                            color: T.amber,
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 3.5)),
                  ),
                ),
              ),
            ],
          ),
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
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: T.micro),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value > 0 ? '+$value' : '-',
                  style: T.numeric
                      .copyWith(fontSize: 30, color: value > 0 ? color : T.dim)),
            ),
          ],
        ),
      );
}

class _LootBand extends StatelessWidget {
  const _LootBand({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final c = context.read<GuildController>();
    final gear = c.g.gearByUid(uid);
    if (gear == null) return const SizedBox.shrink();
    final def = gearById(gear.defId);
    final color = rarityColor(def.rarity);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      color: color.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(0, 16, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 54, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.rarity.label, style: T.micro.copyWith(color: color)),
                const SizedBox(height: 6),
                Text(def.name,
                    style: T.title.copyWith(fontSize: 20, color: color)),
                if (def.flavor.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(def.flavor,
                      style: T.micro.copyWith(
                          letterSpacing: 0.4, fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 10),
                for (final l in def.bonus.lines)
                  Text(l,
                      style: T.mono.copyWith(fontSize: 12, color: T.good)),
              ],
            ),
          ),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(m.name,
                  style: T.mono.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2)),
              const SizedBox(width: 10),
              Text('+${rec.xpGained[id] ?? 0} XP', style: T.micro),
              const Spacer(),
              Text(levelled ? 'LV ${m.level}  UP' : 'LV ${m.level}',
                  style: T.mono.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: levelled ? T.good : T.dim)),
            ],
          ),
          const SizedBox(height: 8),
          Meter(
            value: m.xp / m.xpToNext,
            segments: 24,
            height: 4,
            color: levelled ? T.good : T.amber,
          ),
        ],
      ),
    );
  }
}
