import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/camp_controls.dart';
import '../widgets/expedition_widgets.dart';
import '../widgets/management_widgets.dart';
import '../widgets/sector_scene.dart';
import '../widgets/sigil.dart';
import 'backup_screen.dart';
import 'onboarding_screen.dart';

class OutpostScreen extends StatefulWidget {
  const OutpostScreen({super.key});

  @override
  State<OutpostScreen> createState() => _OutpostScreenState();
}

class _OutpostScreenState extends State<OutpostScreen> {
  late String? _open;

  @override
  void initState() {
    super.initState();
    _open = context.read<GuildController>().g.campProject.name;
  }

  void _toggle(String id) => setState(() => _open = _open == id ? null : id);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final g = c.g;
    final recruits = kClasses.values.where((cls) => cls.recruitCost > 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Facilities & recruiting')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Text('Build the company.', style: T.display),
            const SizedBox(height: 8),
            Text('Permanent upgrades. More hands. New ground.',
                style: T.secondary),
            const SizedBox(height: 20),
            StoreBalance(guild: g),
            const SizedBox(height: 24),
            for (final facility in Facility.values) ...[
              CampDisclosure(
                key: Key('facility-${facility.name}'),
                title: fieldName(facility.label),
                summary: 'Level ${g.facilities[facility]}'
                    '${g.campProject == facility ? ' · Camp project' : ''}',
                icon: switch (facility) {
                  Facility.barracks => Icons.cabin_outlined,
                  Facility.forge => Icons.handyman_outlined,
                  Facility.archive => Icons.menu_book_outlined,
                },
                expanded: _open == facility.name,
                onToggle: () => _toggle(facility.name),
                child: _FacilityDetails(facility: facility),
              ),
              const SizedBox(height: 12),
            ],
            CampDisclosure(
              key: const Key('recruiting-disclosure'),
              title: 'Recruiting',
              summary:
                  '${g.roster.length}/${g.rosterSlots} places filled · Guild level ${g.level}',
              icon: Icons.person_add_alt_outlined,
              expanded: _open == 'recruiting',
              onToggle: () => _toggle('recruiting'),
              child: Column(children: [
                if (g.roster.length >= g.rosterSlots)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        'The roster is full. Upgrade the barracks to make room.',
                        style: T.secondary),
                  ),
                for (final cls in recruits)
                  CampLink(
                    key: Key('recruit-${cls.id}'),
                    title: fieldName(cls.name),
                    detail: g.level < cls.unlockGuildLevel
                        ? 'Requires guild level ${cls.unlockGuildLevel}'
                        : '${cls.recruitCost} credits · ${cls.windowText}',
                    onTap: () =>
                        showCampSheet(context, _RecruitReview(cls: cls)),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            CampDisclosure(
              key: const Key('sectors-disclosure'),
              title: 'Sector access',
              summary: '${g.unlockedSectors.length} of ${kSectors.length} open',
              icon: Icons.explore_outlined,
              expanded: _open == 'sectors',
              onToggle: () => _toggle('sectors'),
              child: Column(children: [
                for (final sector in kSectors)
                  CampLink(
                    key: Key('access-${sector.id}'),
                    title: fieldName(sector.name),
                    detail: g.sectorUnlocked(sector.id)
                        ? 'Open · ${sector.minMinutes}+ minute expeditions'
                        : '${sector.intelToUnlock} intel · Guild ${sector.guildLevelToUnlock} · ${sector.minMinutes}+ min',
                    onTap: () =>
                        showCampSheet(context, _SectorReview(sector: sector)),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            CampDisclosure(
              key: const Key('camp-reference'),
              title: 'Camp reference',
              summary: 'Field manual, backups & build information',
              icon: Icons.info_outline,
              expanded: _open == 'reference',
              onToggle: () => _toggle('reference'),
              child: Column(children: [
                CampLink(
                  title: 'Settings & backup',
                  detail: 'Export a save or restore one',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BackupScreen())),
                ),
                CampLink(
                  title: 'Field manual',
                  detail: 'How expeditions and Integrity work',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const OnboardingScreen(asReview: true))),
                ),
                const _BuildInfo(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mounted only when the reference disclosure is open. The builder attaches
/// an error listener immediately, including where platform metadata is absent.
class _BuildInfo extends StatelessWidget {
  const _BuildInfo();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            snap.hasData
                ? 'Telos ${snap.data!.version} (${snap.data!.buildNumber})'
                : 'Telos',
            style: T.secondary,
          ),
        ),
      );
}

String _facilityBenefit(Facility facility, int level) {
  final bonus = describeBonus(facility.bonusAt(level));
  final effects = <String>[
    if (facility == Facility.barracks) '${2 + level} roster places',
    if (facility == Facility.forge)
      'Craft ${Rarity.values.where((r) => kForgeLevelFor[r]! <= level).map((r) => r.name).join(', ')} equipment',
    if (bonus.isNotEmpty) bonus,
  ];
  return effects.isEmpty ? 'No added resource bonus yet.' : effects.join('\n');
}

class _FacilityDetails extends StatelessWidget {
  const _FacilityDetails({required this.facility});
  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final level = c.g.facilities[facility]!;
    final (credits, alloy) = facility.costAt(level);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NEXT · LEVEL ${level + 1}', style: T.label),
        const SizedBox(height: 8),
        Text(_facilityBenefit(facility, level + 1), style: T.body),
        const SizedBox(height: 12),
        Text('$credits credits · $alloy alloy', style: T.data),
        const SizedBox(height: 16),
        CampButton(
          key: Key('review-${facility.name}'),
          label: 'Review upgrade',
          onPressed: () =>
              showCampSheet(context, _UpgradeReview(facility: facility)),
        ),
        if (c.g.campProject != facility) ...[
          const SizedBox(height: 8),
          CampButton(
            key: Key('track-${facility.name}'),
            label: 'Make this the camp project',
            onPressed: () async {
              await c.selectCampProject(facility);
              if (context.mounted) {
                campNotice(context,
                    '${fieldName(facility.label)} is now the camp project.');
              }
            },
          ),
        ],
      ]),
    );
  }
}

class _UpgradeReview extends StatelessWidget {
  const _UpgradeReview({required this.facility});
  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final level = c.g.facilities[facility]!;
    final (credits, alloy) = facility.costAt(level);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CampSheetHeader(title: fieldName(facility.label)),
      Text('Level $level → ${level + 1}', style: T.display),
      const SizedBox(height: 24),
      Text('NOW', style: T.label),
      const SizedBox(height: 8),
      Text(_facilityBenefit(facility, level), style: T.secondary),
      const SizedBox(height: 20),
      Text('AFTER THE UPGRADE', style: T.label),
      const SizedBox(height: 8),
      Text(_facilityBenefit(facility, level + 1), style: T.body),
      if (facility == Facility.barracks) ...[
        const SizedBox(height: 12),
        Text(
            'Roster places hold recruits. Expedition squad size grows with guild level.',
            style: T.secondary),
      ],
      const SizedBox(height: 24),
      SpendCost(guild: c.g, credits: credits, alloy: alloy),
      const SizedBox(height: 24),
      CampAction(
        key: const Key('confirm-upgrade'),
        label: c.canUpgrade(facility)
            ? 'Upgrade to level ${level + 1}'
            : 'More resources needed',
        onPressed: c.canUpgrade(facility)
            ? () async {
                await c.upgrade(facility);
                if (!context.mounted) return;
                Navigator.pop(context);
                campNotice(context,
                    '${fieldName(facility.label)} upgraded to level ${c.g.facilities[facility]}.');
              }
            : null,
      ),
    ]);
  }
}

class _RecruitReview extends StatelessWidget {
  const _RecruitReview({required this.cls});
  final ClassDef cls;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final full = c.g.roster.length >= c.g.rosterSlots;
    final locked = c.g.level < cls.unlockGuildLevel;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CampSheetHeader(title: 'Meet a recruit'),
      ClassEmblem(classId: cls.id, color: T.amber, size: 64),
      const SizedBox(height: 16),
      Text(fieldName(cls.name), style: T.display),
      const SizedBox(height: 8),
      Text(cls.blurb, style: T.body),
      const SizedBox(height: 16),
      Text('Always · ${describeBonus(cls.base)}', style: T.secondary),
      const SizedBox(height: 12),
      Text(cls.windowText, style: T.body),
      Text('Additional · ${describeBonus(cls.windowBonus)}',
          style: T.secondary),
      const SizedBox(height: 24),
      SpendCost(guild: c.g, credits: cls.recruitCost),
      const SizedBox(height: 16),
      if (locked || full) ...[
        Text(
            locked
                ? 'Requires guild level ${cls.unlockGuildLevel}. Your guild is level ${c.g.level}.'
                : 'The roster is full. Upgrade the barracks first.',
            style: T.body),
        const SizedBox(height: 16),
      ],
      CampAction(
        key: const Key('confirm-recruit'),
        label: locked
            ? 'Guild level too low'
            : full
                ? 'Roster full'
                : c.canRecruit(cls)
                    ? 'Recruit ${fieldName(cls.name)}'
                    : 'More credits needed',
        onPressed: c.canRecruit(cls)
            ? () async {
                final member = await c.recruit(cls);
                if (!context.mounted || member == null) return;
                Navigator.pop(context);
                campNotice(context,
                    '${member.name} joined as ${fieldName(cls.name)}.');
              }
            : null,
      ),
    ]);
  }
}

class _SectorReview extends StatelessWidget {
  const _SectorReview({required this.sector});
  final Sector sector;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final open = c.g.sectorUnlocked(sector.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CampSheetHeader(title: 'Sector access'),
      Text(fieldName(sector.name), style: T.display),
      const SizedBox(height: 16),
      SectorScene(
          sectorId: sector.id, color: T.amber, animate: false, height: 140),
      const SizedBox(height: 16),
      Text(sector.blurb, style: T.body),
      const SizedBox(height: 12),
      Text('Requires a focus session of ${sector.minMinutes} minutes or more.',
          style: T.secondary),
      const SizedBox(height: 24),
      if (open)
        const Text('This sector is open for expeditions.', style: T.body)
      else ...[
        SpendCost(guild: c.g, intel: sector.intelToUnlock),
        if (c.g.level < sector.guildLevelToUnlock) ...[
          const SizedBox(height: 16),
          Text(
              'Requires guild level ${sector.guildLevelToUnlock}. Your guild is level ${c.g.level}.',
              style: T.body),
        ],
        const SizedBox(height: 24),
        CampAction(
          key: const Key('confirm-unlock'),
          label: c.canUnlock(sector)
              ? 'Open this sector'
              : c.g.level < sector.guildLevelToUnlock
                  ? 'Guild level too low'
                  : 'More intel needed',
          onPressed: c.canUnlock(sector)
              ? () async {
                  await c.unlockSector(sector);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  campNotice(context, '${fieldName(sector.name)} is now open.');
                }
              : null,
        ),
      ],
    ]);
  }
}
