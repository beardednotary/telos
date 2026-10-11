import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/camp_controls.dart';
import '../widgets/expedition_widgets.dart';
import '../widgets/management_widgets.dart';
import '../widgets/sigil.dart';
import 'forge_screen.dart';

class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key});

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  String? _open;

  void _toggle(String id) => setState(() => _open = _open == id ? null : id);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final g = c.g;
    final spare = g.unequippedGear;
    return Scaffold(
      appBar: AppBar(title: const Text('Roster & equipment')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Text('Ready for the field.', style: T.display),
            const SizedBox(height: 8),
            Text(
              '${g.roster.length} of ${g.rosterSlots} places filled · '
              'Up to ${g.squadSlots} per expedition',
              style: T.secondary,
            ),
            const SizedBox(height: 24),
            for (final member in g.roster) ...[
              CampDisclosure(
                key: Key('roster-${member.id}'),
                title: member.name,
                summary: '${fieldName(kClasses[member.classId]!.name)} · '
                    'Level ${member.level} · ${member.equipped.length}/$kGearSlots equipped',
                icon: Icons.person_outline,
                leading: ClassEmblem(
                    classId: member.classId, color: T.amber, size: 32),
                expanded: _open == member.id,
                onToggle: () => _toggle(member.id),
                child: _MemberKit(member: member),
              ),
              const SizedBox(height: 12),
            ],
            CampDisclosure(
              key: const Key('vault-disclosure'),
              title: 'The vault',
              summary: '${spare.length} unassigned · ${g.vault.length} owned',
              icon: Icons.inventory_2_outlined,
              expanded: _open == 'vault',
              onToggle: () => _toggle('vault'),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    spare.isEmpty
                        ? 'No spare equipment. Expedition finds and forged pieces arrive here.'
                        : 'Choose a member and an equipment slot to assign these pieces.',
                    style: T.secondary,
                  ),
                ),
                for (final gear in spare)
                  GearEntry(
                    def: gearById(gear.defId),
                    onTap: () => showCampSheet(
                      context,
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CampSheetHeader(title: 'In the vault'),
                            GearDetail(def: gearById(gear.defId)),
                            const SizedBox(height: 24),
                            Text(
                                'Unassigned. Choose a member’s equipment slot to put it to use.',
                                style: T.secondary),
                          ]),
                    ),
                  ),
                CampLink(
                  title: 'Visit the forge',
                  detail: 'Craft a piece or melt spare gear',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ForgeScreen())),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Text(
                'Two pieces per member. Equipment helps only when its wearer is deployed.',
                style: T.secondary),
          ],
        ),
      ),
    );
  }
}

class _MemberKit extends StatelessWidget {
  const _MemberKit({required this.member});
  final Adventurer member;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final cls = kClasses[member.classId]!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FIELD KIT', style: T.label),
        const SizedBox(height: 8),
        for (var slot = 0; slot < kGearSlots; slot++) ...[
          CampLink(
            key: Key('slot-${member.id}-$slot'),
            title: slot < member.equipped.length
                ? fieldName(
                    gearById(c.g.gearByUid(member.equipped[slot])!.defId).name)
                : 'Empty slot ${slot + 1}',
            detail: slot < member.equipped.length
                ? describeBonus(
                    gearById(c.g.gearByUid(member.equipped[slot])!.defId).bonus)
                : 'Choose from the vault',
            onTap: () => showCampSheet(
              context,
              _EquipReview(
                memberId: member.id,
                currentUid: slot < member.equipped.length
                    ? member.equipped[slot]
                    : null,
              ),
            ),
          ),
          if (slot < kGearSlots - 1) const Divider(height: 1),
        ],
        const SizedBox(height: 16),
        Text(cls.blurb, style: T.body),
        const SizedBox(height: 8),
        Text('Always · ${describeBonus(cls.base + member.levelBonus)}',
            style: T.secondary),
        const SizedBox(height: 8),
        Text(cls.windowText, style: T.body),
        Text('Additional · ${describeBonus(cls.windowBonus)}',
            style: T.secondary),
        const SizedBox(height: 20),
        Text(
            '${member.xp} / ${member.xpToNext} XP to level ${member.level + 1}',
            style: T.secondary),
      ]),
    );
  }
}

class _EquipReview extends StatefulWidget {
  const _EquipReview({required this.memberId, required this.currentUid});
  final String memberId;
  final String? currentUid;

  @override
  State<_EquipReview> createState() => _EquipReviewState();
}

class _EquipReviewState extends State<_EquipReview> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final member = c.g.memberById(widget.memberId)!;
    final current = c.g.gearByUid(widget.currentUid ?? '');
    final currentDef = current == null ? null : gearById(current.defId);
    final selected = c.g.gearByUid(_selected ?? '');
    final def = selected == null ? null : gearById(selected.defId);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CampSheetHeader(title: '${member.name} · Field kit'),
      if (def == null) ...[
        Text(currentDef == null ? 'Choose a piece.' : 'Currently equipped',
            style: T.title),
        if (currentDef != null) ...[
          const SizedBox(height: 12),
          GearEntry(
            def: currentDef,
            detail: 'Inspect · ${describeBonus(currentDef.bonus)}',
            onTap: () => setState(() => _selected = current!.uid),
          ),
          CampButton(
            key: const Key('remove-equipment'),
            label: 'Return to the vault',
            onPressed: () async {
              await c.unequip(member.id, current!.uid);
              if (!context.mounted) return;
              Navigator.pop(context);
              campNotice(context,
                  '${fieldName(currentDef.name)} returned to the vault.');
            },
          ),
          const SizedBox(height: 24),
          Text('REPLACE WITH', style: T.label),
        ],
        if (c.g.unequippedGear.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
                'No spare equipment. Find pieces on expeditions or craft them at the forge.',
                style: T.secondary),
          ),
        for (final gear in c.g.unequippedGear)
          GearEntry(
            key: Key('choose-gear-${gear.uid}'),
            def: gearById(gear.defId),
            onTap: () => setState(() => _selected = gear.uid),
          ),
      ] else ...[
        GearDetail(def: def),
        const SizedBox(height: 24),
        if (selected!.uid == current?.uid)
          Text('Equipped by ${member.name}.', style: T.secondary)
        else ...[
          Text(
              currentDef == null
                  ? 'Fills an empty slot.'
                  : 'Replaces ${fieldName(currentDef.name)}. The old piece returns to the vault.',
              style: T.secondary),
          const SizedBox(height: 20),
          SlotComparison(
              before: currentDef?.bonus ?? Bonus.none, after: def.bonus),
          const SizedBox(height: 12),
          Text('Gear-find affects the chance of any equipment, not its rarity.',
              style: T.secondary),
          const SizedBox(height: 24),
          CampAction(
            key: const Key('confirm-equip'),
            label: 'Equip on ${member.name}',
            onPressed:
                c.g.unequippedGear.any((gear) => gear.uid == selected.uid)
                    ? () async {
                        await c.equip(member.id, selected.uid,
                            replacingUid: widget.currentUid);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        campNotice(context,
                            '${fieldName(def.name)} equipped on ${member.name}.');
                      }
                    : null,
          ),
        ],
        const SizedBox(height: 12),
        CampButton(
            label: 'Back to equipment',
            onPressed: () => setState(() => _selected = null)),
      ],
    ]);
  }
}
