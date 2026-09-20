import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/guild_state.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/terminal.dart';

/// Everything you spend resources on. This is the between-sessions layer -
/// the reason a finished run makes you want to start the next one.
class OutpostScreen extends StatelessWidget {
  const OutpostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final g = c.g;

    return TerminalScaffold(
      title: 'FACILITIES',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _Bal('CR', g.credits, T.amber),
                _Bal('AL', g.alloy, T.text),
                _Bal('IN', g.intel, T.cyan),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const PanelTitle('UPGRADES'),
          for (final f in Facility.values) ...[
            _FacilityCard(facility: f),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 18),
          PanelTitle('RECRUITING',
              trailing: Text('${g.roster.length}/${g.rosterSlots} SLOTS',
                  style: T.label)),
          if (recruitableClasses(g).isEmpty)
            Panel(
              child: Text(
                'No new archetypes available yet. The ARCHIVIST opens up at '
                'guild level 2.',
                style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3, height: 1.5),
              ),
            )
          else
            for (final cls in recruitableClasses(g)) ...[
              _RecruitCard(cls: cls),
              const SizedBox(height: 8),
            ],

          const SizedBox(height: 18),
          const PanelTitle('SECTOR ACCESS'),
          for (final s in kSectors.where((s) => !g.sectorUnlocked(s.id))) ...[
            _SectorUnlock(sector: s),
            const SizedBox(height: 8),
          ],
          if (kSectors.every((s) => g.sectorUnlocked(s.id)))
            Panel(
              child: Text('Every charted sector is open.',
                  style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3)),
            ),

          const SizedBox(height: 22),
          const PanelTitle('ABOUT'),
          Panel(
            onTap: () => _showLicence(context),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TYPEFACE',
                          style: T.mono.copyWith(letterSpacing: 1.6)),
                      const SizedBox(height: 3),
                      Text('JetBrains Mono - SIL Open Font License 1.1',
                          style: T.label
                              .copyWith(fontSize: 10, letterSpacing: 0.3)),
                    ],
                  ),
                ),
                Text('>', style: T.mono.copyWith(color: T.dim)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLicence(BuildContext context) async {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: T.card,
      isScrollControlled: true,
      shape: const Border(top: BorderSide(color: T.line)),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Row(
                children: [
                  Text('SIL OPEN FONT LICENSE 1.1', style: T.label),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Text('[ CLOSE ]',
                        style: T.label.copyWith(color: T.amber)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: T.line),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                child: SelectableText(
                  text,
                  style: T.mono.copyWith(fontSize: 11, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bal extends StatelessWidget {
  const _Bal(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Row(
          children: [
            Text(label, style: T.label.copyWith(fontSize: 9)),
            const SizedBox(width: 6),
            Text('$value', style: T.mono.copyWith(color: color, fontSize: 14)),
          ],
        ),
      );
}

class _FacilityCard extends StatelessWidget {
  const _FacilityCard({required this.facility});
  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final level = c.g.facilities[facility]!;
    final (costC, costA) = facility.costAt(level);
    final can = c.canUpgrade(facility);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(facility.label,
                  style: T.mono.copyWith(fontSize: 14, letterSpacing: 1.6)),
              const Spacer(),
              Text('LV $level', style: T.mono.copyWith(color: T.amber)),
            ],
          ),
          const SizedBox(height: 4),
          Text(facility.effect,
              style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3, height: 1.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'NEXT: $costC CR  +  $costA AL',
                  style: T.mono.copyWith(
                      fontSize: 11, color: can ? T.text : T.dim),
                ),
              ),
              TButton(
                'UPGRADE',
                expand: false,
                dense: true,
                onTap: can ? () => c.upgrade(facility) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecruitCard extends StatelessWidget {
  const _RecruitCard({required this.cls});
  final ClassDef cls;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final can = c.canRecruit(cls);
    final full = c.g.roster.length >= c.g.rosterSlots;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(cls.name,
                  style: T.mono.copyWith(fontSize: 14, letterSpacing: 1.6)),
              const Spacer(),
              Text('${cls.recruitCost} CR',
                  style: T.mono.copyWith(
                      color: c.g.credits >= cls.recruitCost ? T.amber : T.dim)),
            ],
          ),
          const SizedBox(height: 4),
          Text(cls.blurb,
              style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3, height: 1.5)),
          const SizedBox(height: 6),
          Text(cls.windowText.toUpperCase(),
              style: T.label.copyWith(color: T.good, fontSize: 9)),
          const SizedBox(height: 10),
          TButton(
            full ? 'ROSTER FULL - UPGRADE BARRACKS' : 'RECRUIT',
            dense: true,
            onTap: can ? () => c.recruit(cls) : null,
          ),
        ],
      ),
    );
  }
}

class _SectorUnlock extends StatelessWidget {
  const _SectorUnlock({required this.sector});
  final Sector sector;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final can = c.canUnlock(sector);
    final levelShort = c.g.level < sector.guildLevelToUnlock;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(sector.designation, style: T.label),
              const Spacer(),
              Text('${sector.minMinutes}+ MIN',
                  style: T.label.copyWith(color: T.amber)),
            ],
          ),
          const SizedBox(height: 6),
          Text(sector.name,
              style: T.mono.copyWith(fontSize: 14, letterSpacing: 1.4)),
          const SizedBox(height: 4),
          Text(sector.blurb,
              style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3, height: 1.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  levelShort
                      ? 'REQUIRES GUILD LV ${sector.guildLevelToUnlock}'
                      : '${sector.intelToUnlock} INTEL  '
                          '(HAVE ${c.g.intel})',
                  style: T.mono.copyWith(
                      fontSize: 11, color: can ? T.cyan : T.dim),
                ),
              ),
              TButton(
                'UNLOCK',
                expand: false,
                dense: true,
                color: T.cyan,
                onTap: can ? () => c.unlockSector(sector) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
