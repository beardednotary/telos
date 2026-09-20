import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/terminal.dart';

class RosterScreen extends StatelessWidget {
  const RosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final g = c.g;
    final spare = g.unequippedGear;

    return TerminalScaffold(
      title: 'ROSTER',
      actions: [
        Text('${g.roster.length}/${g.rosterSlots}', style: T.label),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            'Members gain XP on every run. Levels add a flat bonus; gear adds '
            'more. Who you send still matters more than either.',
            style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3, height: 1.6),
          ),
          const SizedBox(height: 16),
          for (final m in g.roster) ...[
            _MemberCard(member: m),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          PanelTitle('VAULT',
              trailing: Text('${spare.length} UNASSIGNED', style: T.label)),
          if (spare.isEmpty)
            Panel(
              child: Text(
                'Nothing spare. Salvage turns up on runs past a sector minimum.',
                style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3),
              ),
            )
          else
            for (final gear in spare) ...[
              _GearRow(gear: gear),
              const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});
  final Adventurer member;

  @override
  Widget build(BuildContext context) {
    final c = context.read<GuildController>();
    final cls = kClasses[member.classId]!;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(member.name,
                  style: T.mono.copyWith(fontSize: 16, letterSpacing: 1.6)),
              const SizedBox(width: 10),
              Text(cls.name, style: T.label.copyWith(color: T.amber)),
              const Spacer(),
              Text('LV ${member.level}',
                  style: T.mono.copyWith(color: T.amber, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(cls.blurb,
              style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3, height: 1.5)),
          const SizedBox(height: 10),
          Meter(value: member.xp / member.xpToNext, segments: 22, height: 5),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('XP', style: T.label.copyWith(fontSize: 9)),
              const Spacer(),
              Text('${member.xp} / ${member.xpToNext}',
                  style: T.label.copyWith(fontSize: 9)),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: T.line),
          const SizedBox(height: 10),
          Text(cls.windowText.toUpperCase(),
              style: T.label.copyWith(color: T.good, fontSize: 9)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [
              for (final l in (cls.base + cls.windowBonus).lines)
                Text(l, style: T.mono.copyWith(fontSize: 10, color: T.dim)),
            ],
          ),
          const SizedBox(height: 14),
          Text('KIT', style: T.label),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < kGearSlots; i++) ...[
                Expanded(
                  child: _Slot(
                    member: member,
                    uid: i < member.equipped.length ? member.equipped[i] : null,
                    onTap: () => _openSlot(
                      context,
                      c,
                      member,
                      i < member.equipped.length ? member.equipped[i] : null,
                    ),
                  ),
                ),
                if (i == 0) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openSlot(
    BuildContext context,
    GuildController c,
    Adventurer m,
    String? current,
  ) async {
    final spare = c.g.unequippedGear;
    await showModalBottomSheet(
      context: context,
      backgroundColor: T.card,
      shape: const Border(top: BorderSide(color: T.line)),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            Text('ASSIGN TO ${m.name}', style: T.label),
            const SizedBox(height: 14),
            if (current != null) ...[
              TButton('REMOVE CURRENT', color: T.bad, onTap: () {
                c.unequip(m.id, current);
                Navigator.pop(context);
              }),
              const SizedBox(height: 12),
            ],
            if (spare.isEmpty)
              Text('Vault is empty.',
                  style: T.mono.copyWith(color: T.dim, fontSize: 12))
            else
              for (final gear in spare) ...[
                GestureDetector(
                  onTap: () {
                    c.equip(m.id, gear.uid);
                    Navigator.pop(context);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: _GearRow(gear: gear),
                ),
                const SizedBox(height: 6),
              ],
          ],
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.member, required this.uid, required this.onTap});
  final Adventurer member;
  final String? uid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.read<GuildController>();
    final gear = uid == null ? null : c.g.gearByUid(uid!);
    final def = gear == null ? null : gearById(gear.defId);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: def == null ? T.line : T.amber),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(def?.name ?? 'EMPTY SLOT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.mono.copyWith(
                    fontSize: 11, color: def == null ? T.dim : T.text)),
            const SizedBox(height: 2),
            Text(def == null ? 'TAP TO ASSIGN' : def.bonus.lines.join('  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.label.copyWith(fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _GearRow extends StatelessWidget {
  const _GearRow({required this.gear});
  final Gear gear;

  @override
  Widget build(BuildContext context) {
    final def = gearById(gear.defId);
    final color = switch (def.rarity) {
      Rarity.common => T.dim,
      Rarity.uncommon => T.text,
      Rarity.rare => T.cyan,
      Rarity.epic => T.amber,
    };
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.name, style: T.mono.copyWith(fontSize: 12, color: color)),
                const SizedBox(height: 2),
                Text(def.bonus.lines.join('   '),
                    style: T.label.copyWith(fontSize: 9)),
              ],
            ),
          ),
          Text('[${def.rarity.label}]',
              style: T.label.copyWith(fontSize: 9, color: color)),
        ],
      ),
    );
  }
}
