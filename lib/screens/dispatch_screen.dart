import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../services/expedition_engine.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/sigil.dart';
import '../widgets/terminal.dart';

/// The pre-session decision, in one screen:
///   what am I doing -> how long -> where do they go -> who goes.
class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  final _intent = TextEditingController();
  int _minutes = 45;
  String? _sectorId;
  final _squad = <String>[];

  @override
  void dispose() {
    _intent.dispose();
    super.dispose();
  }

  void _autoPickSector(GuildController c) {
    final avail = c.availableSectors(_minutes);
    if (avail.isEmpty) {
      _sectorId = null;
      return;
    }
    if (_sectorId == null || !avail.any((s) => s.id == _sectorId)) {
      // Default to the deepest sector this block of time can actually reach.
      _sectorId = avail.last.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final g = c.g;
    _autoPickSector(c);

    while (_squad.length > g.squadSlots) {
      _squad.removeLast();
    }

    final ready = _sectorId != null && _squad.isNotEmpty;
    final outOfReach = kSectors
        .where((s) => g.sectorUnlocked(s.id) && s.minMinutes > _minutes);

    return TerminalScaffold(
      title: 'DISPATCH',
      bottom: _Action(
        label: ready ? 'BEGIN EXPEDITION' : 'SELECT A SQUAD',
        color: ready ? T.amber : T.dim,
        onTap: ready
            ? () async {
                HapticFeedback.heavyImpact();
                await c.startRun(
                  sectorId: _sectorId!,
                  intent: _intent.text,
                  squad: List.of(_squad),
                  minutes: _minutes,
                );
                if (context.mounted) Navigator.pop(context);
              }
            : null,
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 4),
        children: [
          // -- 01 INTENT -------------------------------------------------
          Section(
            label: 'INTENT',
            leading: const _StepNumber('01'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _intent,
                  style: T.mono
                      .copyWith(fontSize: 17, fontWeight: FontWeight.w300),
                  cursorColor: T.amber,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 80,
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: 'What are you working on?',
                    hintStyle: T.mono.copyWith(
                        color: T.dim,
                        fontSize: 17,
                        fontWeight: FontWeight.w300),
                    border: const UnderlineInputBorder(
                        borderSide: BorderSide(color: T.line)),
                    enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: T.line)),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: T.amber)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Optional. Nothing checks up on you - it just ends up in your log.',
                  style: T.micro.copyWith(letterSpacing: 0.4),
                ),
              ],
            ),
          ),

          // -- 02 DURATION -----------------------------------------------
          Section(
            label: 'DURATION',
            leading: const _StepNumber('02'),
            trailing: durationTier(_minutes),
            trailingColor: T.amber,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$_minutes',
                        style: T.big.copyWith(fontSize: 54, color: T.amber)),
                    const SizedBox(width: 6),
                    Text('MIN', style: T.micro.copyWith(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in kDurations)
                      TChip('$d MIN', selected: _minutes == d, onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _minutes = d);
                      }),
                    TChip('CUSTOM',
                        selected: !kDurations.contains(_minutes),
                        onTap: _pickCustom),
                  ],
                ),
              ],
            ),
          ),

          // -- 03 SECTOR -------------------------------------------------
          Section(
            label: 'SECTOR',
            leading: const _StepNumber('03'),
            rows: [
              for (final s in kSectors)
                _SectorBand(
                  sector: s,
                  minutes: _minutes,
                  unlocked: g.sectorUnlocked(s.id),
                  surveyed: (g.surveyRead[s.id] ?? 0) >= s.priorSurvey.length,
                  selected: _sectorId == s.id,
                  onTap: g.sectorUnlocked(s.id) && s.minMinutes <= _minutes
                      ? () {
                          HapticFeedback.selectionClick();
                          setState(() => _sectorId = s.id);
                        }
                      : null,
                ),
              if (outOfReach.isNotEmpty)
                Section.note(
                  '${outOfReach.first.minMinutes} min would reach '
                  '${outOfReach.first.name}.',
                  color: T.cyan,
                ),
            ],
          ),

          // -- 04 SQUAD --------------------------------------------------
          Section(
            label: 'SQUAD',
            leading: const _StepNumber('04'),
            trailing: '${_squad.length}/${g.squadSlots}',
            trailingColor: T.amber,
            rows: [
              for (final m in g.roster)
                _MemberBand(
                  member: m,
                  minutes: _minutes,
                  selected: _squad.contains(m.id),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (_squad.contains(m.id)) {
                        _squad.remove(m.id);
                      } else if (_squad.length < g.squadSlots) {
                        _squad.add(m.id);
                      } else {
                        _squad.removeAt(0);
                        _squad.add(m.id);
                      }
                    });
                  },
                ),
              if (g.squadSlots < g.roster.length)
                Section.note(
                  'Guild level ${g.level}: ${g.squadSlots} can go out at once. '
                  'More slots at guild level 3, 6 and 10.',
                ),
            ],
          ),

          if (_squad.isNotEmpty && _sectorId != null)
            _Projection(
              squad: _squad,
              sectorId: _sectorId!,
              minutes: _minutes,
            ),
        ],
      ),
    );
  }

  Future<void> _pickCustom() async {
    var v = _minutes.toDouble();
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: T.card,
      shape: const Border(top: BorderSide(color: T.line)),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CUSTOM DURATION', style: T.micro),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${v.round()}',
                      style: T.big.copyWith(fontSize: 54, color: T.amber)),
                  const SizedBox(width: 6),
                  Text('MIN', style: T.micro.copyWith(fontSize: 12)),
                  const Spacer(),
                  Text(durationTier(v.round()),
                      style: T.micro.copyWith(color: T.amber)),
                ],
              ),
              Slider(
                value: v,
                min: 5,
                max: 180,
                divisions: 35,
                activeColor: T.amber,
                inactiveColor: T.line,
                onChanged: (x) => setSheet(() => v = x),
              ),
              const SizedBox(height: 6),
              _Action(
                label: 'CONFIRM',
                color: T.amber,
                onTap: () => Navigator.pop(context, v.round()),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _minutes = picked);
  }
}

/// A step's number, set big and Light ahead of its card's label.
class _StepNumber extends StatelessWidget {
  const _StepNumber(this.number);
  final String number;

  @override
  Widget build(BuildContext context) {
    return Text(number,
        style: T.mono.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            color: T.dim,
            height: 1.0));
  }
}

class _SectorBand extends StatelessWidget {
  const _SectorBand({
    required this.sector,
    required this.minutes,
    required this.unlocked,
    required this.surveyed,
    required this.selected,
    required this.onTap,
  });

  final Sector sector;
  final int minutes;
  final bool unlocked;

  /// Every trace the first company left in this sector has been recovered.
  /// Worth saying out loud: a sector that has quietly stopped yielding
  /// records reads as the story being broken rather than finished. This is a
  /// state, not a tally - it never says how many there were.
  final bool surveyed;

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tooShort = unlocked && sector.minMinutes > minutes;
    final blocked = !unlocked || tooShort;

    String? reason;
    if (!unlocked) {
      reason = 'LOCKED - ${sector.intelToUnlock} INTEL'
          '${sector.guildLevelToUnlock > 1 ? ', GUILD LV ${sector.guildLevelToUnlock}' : ''}';
    } else if (tooShort) {
      reason = 'NEEDS ${sector.minMinutes}+ MIN';
    }

    final depth = (minutes / sector.nominalMinutes).clamp(0.0, 1.0);
    final sc = Color(sector.accent);
    final accent =
        blocked ? T.line : (selected ? sc : sc.withValues(alpha: 0.4));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          // Every unlocked sector carries a wash of its own colour and the
          // chosen one is properly lit, so the list reads as five different
          // places rather than five identical rows.
          color: blocked ? null : sc.withValues(alpha: selected ? 0.17 : 0.055),
          border: selected ? Border.all(color: sc, width: 1.4) : null,
        ),
        padding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
        child: Opacity(
          opacity: blocked ? 0.45 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 4, height: 44, color: accent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                              '${sector.designation}   //   ${sector.kind}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.micro
                                  .copyWith(color: selected ? sc : T.dim)),
                        ),
                        if (reason == null) ...[
                          const SizedBox(width: 10),
                          Text(
                            '${(depth * 100).round()}% DEPTH',
                            style: T.micro
                                .copyWith(color: depth >= 1.0 ? T.good : sc),
                          ),
                        ],
                      ],
                    ),
                    // The lock reason can run long ("LOCKED - 320 INTEL,
                    // GUILD LV 3"), so it takes its own line rather than
                    // squeezing the designation off a narrow phone.
                    if (reason != null) ...[
                      const SizedBox(height: 4),
                      Text(reason, style: T.micro.copyWith(color: T.dim)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(sector.name,
                              style: T.title.copyWith(fontSize: 18)),
                        ),
                        const SizedBox(width: 12),
                        Sigil(sectorId: sector.id, color: accent, size: 30),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(sector.blurb,
                        style:
                            T.micro.copyWith(letterSpacing: 0.4, height: 1.6)),
                    if (unlocked && surveyed) ...[
                      const SizedBox(height: 7),
                      Text('NOTHING FURTHER TO RECOVER HERE',
                          style: T.micro
                              .copyWith(color: T.dim, letterSpacing: 0.4)),
                    ],
                    if (!blocked) ...[
                      const SizedBox(height: 11),
                      Meter(
                          value: depth,
                          segments: 22,
                          height: 4,
                          color: selected ? sc : T.dim),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          _Yield('CR', sector.creditsPerMin, T.amber),
                          _Yield('AL', sector.alloyPerMin, T.steel),
                          _Yield('IN', sector.intelPerMin, T.cyan),
                          const Spacer(),
                          Text('RARE ${(sector.baseRare * 100).round()}%',
                              style: T.micro),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Yield extends StatelessWidget {
  const _Yield(this.label, this.perMin, this.color);
  final String label;
  final double perMin;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final blocks = perMin >= 1.5
        ? 3
        : perMin >= 0.5
            ? 2
            : perMin > 0.05
                ? 1
                : 0;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: [
          Text(label, style: T.micro.copyWith(fontSize: 10)),
          const SizedBox(width: 5),
          for (var i = 0; i < 3; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 2),
              color: i < blocks ? color : T.line,
            ),
        ],
      ),
    );
  }
}

class _MemberBand extends StatelessWidget {
  const _MemberBand({
    required this.member,
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final Adventurer member;
  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cls = kClasses[member.classId]!;
    final inWindow = minutes >= cls.windowMin && minutes <= cls.windowMax;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: selected ? T.amber.withValues(alpha: 0.07) : null,
        padding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, height: 40, color: selected ? T.amber : T.line),
            const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: ClassEmblem(
                classId: member.classId,
                // Selected wins, then whether they suit this block of time.
                color: selected ? T.amber : (inWindow ? T.good : T.dim),
                size: 30,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // QUARTERMASTER is long, so the class yields to the
                      // window label rather than pushing it off the card.
                      Expanded(
                        child: Text('${cls.name}   //   LV ${member.level}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.micro
                                .copyWith(color: selected ? T.amber : T.dim)),
                      ),
                      const SizedBox(width: 10),
                      Text(inWindow ? 'IN WINDOW' : 'OFF WINDOW',
                          style: T.micro
                              .copyWith(color: inWindow ? T.good : T.dim)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(member.name, style: T.title.copyWith(fontSize: 18)),
                  const SizedBox(height: 5),
                  Text(cls.windowText,
                      style: T.micro.copyWith(letterSpacing: 0.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What this squad, at this length, in this place, is actually worth.
///
/// Modifiers only - never the loot. The reveal at the debrief is the payoff
/// the whole loop is built around, so the preview stops at how the odds are
/// shaped and says nothing about what comes back.
class _Projection extends StatelessWidget {
  const _Projection({
    required this.squad,
    required this.sectorId,
    required this.minutes,
  });

  final List<String> squad;
  final String sectorId;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final sector = sectorById(sectorId);
    final sc = Color(sector.accent);

    final members =
        squad.map((id) => c.g.memberById(id)).whereType<Adventurer>().toList();

    final bonus = ExpeditionEngine.squadBonusFor(
      guild: c.g,
      members: members,
      minutes: minutes.toDouble(),
    );
    final rare = ExpeditionEngine.rareChanceFor(
      sector: sector,
      minutes: minutes.toDouble(),
      squadBonus: bonus,
    );
    final team = ExpeditionEngine.teamFactorFor(members.length);

    Widget mod(String label, double v, Color hue) {
      final pct = (v * 100).round();
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: T.micro.copyWith(fontSize: 10)),
            const SizedBox(height: 4),
            Text(
              '${pct >= 0 ? '+' : ''}$pct%',
              style: T.mono.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w300,
                color: pct == 0 ? T.dim : (pct > 0 ? hue : T.bad),
              ),
            ),
          ],
        ),
      );
    }

    return Section(
      label: 'PROJECTED',
      labelColor: sc,
      trailing: 'AT 100% INTEGRITY',
      accent: sc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              mod('CREDITS', bonus.credits, T.amber),
              mod('ALLOY', bonus.alloy, T.steel),
              mod('INTEL', bonus.intel, T.cyan),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: T.line),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('RARE FIND', style: T.micro),
              const SizedBox(width: 10),
              Text('${(rare * 100).round()}%',
                  style: T.mono.copyWith(
                      fontSize: 16, fontWeight: FontWeight.w300, color: sc)),
              const Spacer(),
              if (members.length > 1)
                Text('SQUAD x${team.toStringAsFixed(2)}', style: T.micro),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Class, levels, kit and the outpost, combined. Integrity is the '
            'one part still up to you - it barely moves the resources but '
            'drives the rare find hard.',
            style: T.micro.copyWith(letterSpacing: 0.4, height: 1.7),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.color, this.onTap});
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: on ? color : T.line, width: on ? 1.5 : 1),
        ),
        child: Text(label,
            style: T.mono.copyWith(
                color: on ? color : T.dim,
                fontSize: 18,
                fontWeight: FontWeight.w300,
                letterSpacing: 3.5)),
      ),
    );
  }
}
