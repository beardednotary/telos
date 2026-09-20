import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
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

    // Trim the squad if the slot count shrank.
    while (_squad.length > g.squadSlots) {
      _squad.removeLast();
    }

    final ready = _sectorId != null && _squad.isNotEmpty;

    return TerminalScaffold(
      title: 'DISPATCH',
      bottom: TButton(
        ready ? 'BEGIN EXPEDITION' : 'SELECT A SQUAD',
        filled: true,
        onTap: ready
            ? () async {
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          // -- 1. INTENT -------------------------------------------------
          const PanelTitle('01 / INTENT'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WHAT ARE YOU WORKING ON?', style: T.label),
                const SizedBox(height: 8),
                TextField(
                  controller: _intent,
                  style: T.mono.copyWith(fontSize: 14),
                  cursorColor: T.amber,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 80,
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: 'Refactor the auth flow',
                    hintStyle: T.mono.copyWith(color: T.dim, fontSize: 14),
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: T.line),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: T.line),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: T.amber),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Optional. Nothing checks up on you - it just ends up in your log.',
                  style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // -- 2. DURATION ----------------------------------------------
          PanelTitle(
            '02 / DURATION',
            trailing: Text(durationTier(_minutes),
                style: T.label.copyWith(color: T.amber)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in kDurations)
                TChip(
                  '$d MIN',
                  selected: _minutes == d,
                  onTap: () => setState(() => _minutes = d),
                ),
              TChip(
                'CUSTOM',
                selected: !kDurations.contains(_minutes),
                sub: kDurations.contains(_minutes) ? null : '$_minutes MIN',
                onTap: _pickCustom,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // -- 3. SECTOR -------------------------------------------------
          const PanelTitle('03 / SECTOR'),
          for (final s in kSectors) ...[
            _SectorTile(
              sector: s,
              minutes: _minutes,
              unlocked: g.sectorUnlocked(s.id),
              selected: _sectorId == s.id,
              onTap: g.sectorUnlocked(s.id) && s.minMinutes <= _minutes
                  ? () => setState(() => _sectorId = s.id)
                  : null,
            ),
            const SizedBox(height: 8),
          ],

          // The nudge towards a longer block: never a scolding, just the fact
          // that a bit more time opens somewhere better.
          Builder(builder: (context) {
            final outOfReach = kSectors
                .where((s) =>
                    g.sectorUnlocked(s.id) && s.minMinutes > _minutes)
                .toList();
            if (outOfReach.isEmpty) return const SizedBox.shrink();
            final next = outOfReach.first;
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${next.minMinutes} min would reach ${next.name}.',
                style: T.label.copyWith(
                    fontSize: 10, letterSpacing: 0.3, color: T.cyan),
              ),
            );
          }),

          const SizedBox(height: 12),

          // -- 4. SQUAD --------------------------------------------------
          PanelTitle(
            '04 / SQUAD',
            trailing: Text('${_squad.length}/${g.squadSlots}',
                style: T.label.copyWith(color: T.amber)),
          ),
          for (final m in g.roster) ...[
            _MemberTile(
              member: m,
              minutes: _minutes,
              selected: _squad.contains(m.id),
              onTap: () => setState(() {
                if (_squad.contains(m.id)) {
                  _squad.remove(m.id);
                } else if (_squad.length < g.squadSlots) {
                  _squad.add(m.id);
                } else {
                  // Slots are full - swap the oldest pick out.
                  _squad.removeAt(0);
                  _squad.add(m.id);
                }
              }),
            ),
            const SizedBox(height: 8),
          ],
          if (g.squadSlots < g.roster.length)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Guild level ${g.level}: ${g.squadSlots} can go out at once. '
                'More slots at guild level 3, 6 and 10.',
                style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3, height: 1.5),
              ),
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
              Text('CUSTOM DURATION', style: T.label),
              const SizedBox(height: 14),
              Text('${v.round()} MIN',
                  style: T.mono.copyWith(fontSize: 30, color: T.amber)),
              Text(durationTier(v.round()), style: T.label),
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
              TButton('CONFIRM',
                  filled: true, onTap: () => Navigator.pop(context, v.round())),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _minutes = picked);
  }
}

class _SectorTile extends StatelessWidget {
  const _SectorTile({
    required this.sector,
    required this.minutes,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  final Sector sector;
  final int minutes;
  final bool unlocked;
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

    // How deep this length of session gets into the sector.
    final depth = (minutes / sector.nominalMinutes).clamp(0.0, 1.0);

    return Panel(
      onTap: onTap,
      selected: selected,
      dimmed: blocked,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(sector.designation, style: T.label),
              const SizedBox(width: 8),
              Text(sector.kind,
                  style: T.label.copyWith(color: T.dim, fontSize: 9)),
              const Spacer(),
              if (reason != null)
                Text(reason,
                    style: T.label.copyWith(color: T.dim, fontSize: 9))
              else
                Text('${(depth * 100).round()}% DEPTH',
                    style: T.label.copyWith(
                        color: depth >= 1.0 ? T.good : T.amber, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 6),
          Text(sector.name,
              style: T.mono.copyWith(fontSize: 14, letterSpacing: 1.4)),
          const SizedBox(height: 4),
          Text(sector.blurb,
              style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3, height: 1.5)),
          if (!blocked) ...[
            const SizedBox(height: 10),
            Meter(value: depth, segments: 20, height: 5),
            const SizedBox(height: 8),
            Row(
              children: [
                _Yield('CR', sector.creditsPerMin),
                _Yield('AL', sector.alloyPerMin),
                _Yield('IN', sector.intelPerMin),
                const Spacer(),
                Text('RARE ${(sector.baseRare * 100).round()}%',
                    style: T.label.copyWith(fontSize: 9)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Yield extends StatelessWidget {
  const _Yield(this.label, this.perMin);
  final String label;
  final double perMin;

  @override
  Widget build(BuildContext context) {
    // Three blocks = strong, one = trace.
    final blocks = perMin >= 1.5
        ? 3
        : perMin >= 0.5
            ? 2
            : perMin > 0.05
                ? 1
                : 0;
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        children: [
          Text(label, style: T.label.copyWith(fontSize: 9)),
          const SizedBox(width: 4),
          Text('#' * blocks + '-' * (3 - blocks),
              style: T.mono.copyWith(
                  fontSize: 10, color: blocks > 0 ? T.amber : T.line)),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
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

    return Panel(
      onTap: onTap,
      selected: selected,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            color: selected ? T.amber : T.line,
            margin: const EdgeInsets.only(right: 12),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(member.name,
                        style: T.mono.copyWith(fontSize: 14, letterSpacing: 1.2)),
                    const SizedBox(width: 8),
                    Text('${cls.name}  LV ${member.level}', style: T.label),
                  ],
                ),
                const SizedBox(height: 4),
                Text(cls.windowText,
                    style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3)),
              ],
            ),
          ),
          Text(
            inWindow ? 'IN WINDOW' : 'OFF WINDOW',
            style: T.label.copyWith(
              fontSize: 9,
              color: inWindow ? T.good : T.dim,
            ),
          ),
        ],
      ),
    );
  }
}
