import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/guild_state.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/flash.dart';
import 'backup_screen.dart';
import 'onboarding_screen.dart';
import '../widgets/terminal.dart';

/// Everything you spend resources on. This is the between-sessions layer -
/// the reason a finished run makes you want to start the next one.
class OutpostScreen extends StatelessWidget {
  const OutpostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final g = c.g;
    final locked = kSectors.where((s) => !g.sectorUnlocked(s.id)).toList();

    return TerminalScaffold(
      title: 'FACILITIES',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _Balances(g: g),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Text(
              'Upgrades apply to every run from now on. BARRACKS raises how '
              'many members you can keep, FORGE how deep it can work, ARCHIVE '
              'how much INTEL comes home.',
              style: T.micro.copyWith(letterSpacing: 0.4, height: 1.7),
            ),
          ),

          const _SectionRule('UPGRADES'),
          for (final f in Facility.values) _FacilityBand(facility: f),

          const SizedBox(height: 26),
          _SectionRule('RECRUITING', trailing: '${g.roster.length}/${g.rosterSlots} SLOTS'),
          if (recruitableClasses(g).isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'No new archetypes available yet. The ARCHIVIST opens up at '
                'guild level 2.',
                style: T.micro.copyWith(letterSpacing: 0.4),
              ),
            )
          else
            for (final cls in recruitableClasses(g)) _RecruitBand(cls: cls),

          const SizedBox(height: 26),
          const _SectionRule('SECTOR ACCESS', color: T.cyan),
          if (locked.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Every charted sector is open.',
                  style: T.micro.copyWith(letterSpacing: 0.4)),
            )
          else
            for (final s in locked) _SectorBand(sector: s),

          const SizedBox(height: 26),
          const _SectionRule('ABOUT'),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BackupScreen()),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              color: T.band,
              padding: const EdgeInsets.fromLTRB(0, 16, 20, 16),
              child: Row(
                children: [
                  Container(width: 4, height: 40, color: T.steel),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SAVE DATA', style: T.title.copyWith(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text('Export a backup, or restore one',
                            style: T.micro.copyWith(letterSpacing: 0.4)),
                      ],
                    ),
                  ),
                  Text('>', style: T.mono.copyWith(color: T.dim)),
                ],
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OnboardingScreen(asReview: true),
              ),
            ),
            child: Container(
              color: T.band,
              padding: const EdgeInsets.fromLTRB(0, 16, 20, 16),
              child: Row(
                children: [
                  Container(width: 4, height: 40, color: T.amber),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FIELD MANUAL', style: T.title.copyWith(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text('How this works, and why not opening it is the point',
                            style: T.micro.copyWith(letterSpacing: 0.4)),
                      ],
                    ),
                  ),
                  Text('>', style: T.mono.copyWith(color: T.dim)),
                ],
              ),
            ),
          ),
          // Which build this is, so a tester can say without guessing.
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final info = snap.data;
              if (info == null) return const SizedBox(height: 24);
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Text('TELOS ${info.version} (${info.buildNumber})',
                    style: T.micro),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionRule extends StatelessWidget {
  const _SectionRule(this.label, {this.trailing, this.color});
  final String label;
  final String? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Text(label, style: T.micro.copyWith(color: color ?? T.steel)),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: T.line)),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            Text(trailing!, style: T.micro),
          ],
        ],
      ),
    );
  }
}

class _Balances extends StatelessWidget {
  const _Balances({required this.g});
  final GuildState g;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, int v, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: T.micro),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('$v',
                    style: T.numeric.copyWith(fontSize: 28, color: color)),
              ),
            ],
          ),
        );

    return Container(
      color: T.band,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          cell('CREDITS', g.credits, T.amber),
          cell('ALLOY', g.alloy, T.steel),
          cell('INTEL', g.intel, T.cyan),
        ],
      ),
    );
  }
}

/// One shared shape for facilities, recruits and sectors: accent bar, a big
/// Light name, the cost, and the action. Repetition here is structure, not
/// sameness - each row is doing the same job.
class _SpendBand extends StatelessWidget {
  const _SpendBand({
    required this.accent,
    required this.kicker,
    required this.name,
    required this.blurb,
    required this.trailing,
    required this.cost,
    required this.action,
    required this.enabled,
    required this.onTap,
    this.note,
  });

  final Color accent;
  final String kicker;
  final String name;
  final String blurb;
  final Widget trailing;
  final String cost;
  final String action;
  final bool enabled;
  final VoidCallback? onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      color: T.band,
      padding: const EdgeInsets.fromLTRB(0, 16, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 54, color: enabled ? accent : T.line),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kicker, style: T.micro.copyWith(color: accent)),
                          const SizedBox(height: 5),
                          Text(name, style: T.title.copyWith(fontSize: 19)),
                        ],
                      ),
                    ),
                    trailing,
                  ],
                ),
                const SizedBox(height: 7),
                Text(blurb,
                    style: T.micro.copyWith(letterSpacing: 0.4, height: 1.6)),
                if (note != null) ...[
                  const SizedBox(height: 5),
                  Text(note!, style: T.micro.copyWith(color: T.good)),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(cost,
                          style: T.mono.copyWith(
                              fontSize: 13,
                              letterSpacing: 0.8,
                              color: enabled ? T.text : T.dim)),
                    ),
                    GestureDetector(
                      onTap: enabled ? onTap : null,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: enabled
                              ? accent.withValues(alpha: 0.12)
                              : Colors.transparent,
                          border:
                              Border.all(color: enabled ? accent : T.line),
                        ),
                        child: Text(action,
                            style: T.mono.copyWith(
                                fontSize: 12,
                                letterSpacing: 2,
                                color: enabled ? accent : T.dim)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FacilityBand extends StatelessWidget {
  const _FacilityBand({required this.facility});
  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final level = c.g.facilities[facility]!;
    final (costC, costA) = facility.costAt(level);
    final can = c.canUpgrade(facility);

    return _SpendBand(
      accent: T.steel,
      kicker: 'FACILITY',
      name: facility.label,
      blurb: facility.effect,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('LEVEL', style: T.micro),
          const SizedBox(height: 2),
          Text('$level'.padLeft(2, '0'),
              style: T.numeric.copyWith(fontSize: 28, color: T.steel)),
        ],
      ),
      cost: '$costC CR   +   $costA AL',
      action: 'UPGRADE',
      enabled: can,
      onTap: () async {
        await c.upgrade(facility);
        if (!context.mounted) return;
        final now = c.g.facilities[facility]!;
        showFlash(
          context,
          kicker: 'FACILITY UPGRADED',
          title: '${facility.label}  LV ${now.toString().padLeft(2, '0')}',
          lines: [
            facility.effect,
            if (facility == Facility.barracks)
              'Roster capacity now ${c.g.rosterSlots}',
          ],
          color: T.steel,
        );
      },
    );
  }
}

class _RecruitBand extends StatelessWidget {
  const _RecruitBand({required this.cls});
  final ClassDef cls;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final can = c.canRecruit(cls);
    final full = c.g.roster.length >= c.g.rosterSlots;

    return _SpendBand(
      accent: T.amber,
      kicker: 'ARCHETYPE',
      name: cls.name,
      blurb: cls.blurb,
      note: cls.windowText.toUpperCase(),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('COST', style: T.micro),
          const SizedBox(height: 2),
          Text('${cls.recruitCost}',
              style: T.numeric.copyWith(fontSize: 26, color: T.amber)),
        ],
      ),
      cost: full ? 'ROSTER FULL - UPGRADE BARRACKS' : '${cls.recruitCost} CREDITS',
      action: 'RECRUIT',
      enabled: can,
      onTap: () async {
        final hire = await c.recruit(cls);
        if (!context.mounted || hire == null) return;
        showFlash(
          context,
          kicker: 'RECRUITED',
          title: '${hire.name}  //  ${cls.name}',
          lines: [cls.windowText],
          color: T.amber,
        );
      },
    );
  }
}

class _SectorBand extends StatelessWidget {
  const _SectorBand({required this.sector});
  final Sector sector;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final can = c.canUnlock(sector);
    final levelShort = c.g.level < sector.guildLevelToUnlock;

    return _SpendBand(
      accent: T.cyan,
      kicker: '${sector.designation}   //   ${sector.minMinutes}+ MIN',
      name: sector.name,
      blurb: sector.blurb,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('INTEL', style: T.micro),
          const SizedBox(height: 2),
          Text('${sector.intelToUnlock}',
              style: T.numeric.copyWith(fontSize: 26, color: T.cyan)),
        ],
      ),
      cost: levelShort
          ? 'REQUIRES GUILD LV ${sector.guildLevelToUnlock}'
          : 'HAVE ${c.g.intel} OF ${sector.intelToUnlock}',
      action: 'UNLOCK',
      enabled: can,
      onTap: () async {
        await c.unlockSector(sector);
        if (!context.mounted) return;
        showFlash(
          context,
          kicker: 'SECTOR OPEN',
          title: sector.name,
          lines: [
            sector.blurb,
            'Needs ${sector.minMinutes}+ minutes to reach',
          ],
          color: Color(sector.accent),
          heavy: true,
          sigilSectorId: sector.id,
        );
      },
    );
  }
}
