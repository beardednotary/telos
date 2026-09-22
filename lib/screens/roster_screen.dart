import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/flash.dart';
import '../widgets/sigil.dart';
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
        Text('${g.roster.length}/${g.rosterSlots}', style: T.micro),
      ],
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Members gain XP on every run they go on. Levels add a flat '
              'bonus; the two KIT slots add more. Gear does nothing until it '
              'is assigned to someone.',
              style: T.micro.copyWith(letterSpacing: 0.4, height: 1.7),
            ),
          ),
          for (final m in g.roster) _MemberBand(member: m),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('VAULT', style: T.micro.copyWith(color: T.steel)),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 1, color: T.line)),
                const SizedBox(width: 12),
                Text('${spare.length} UNASSIGNED', style: T.micro),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (spare.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Nothing spare. Salvage turns up on runs past a sector minimum.',
                style: T.micro.copyWith(letterSpacing: 0.4),
              ),
            )
          else
            for (final gear in spare) _GearBand(gear: gear),
        ],
      ),
    );
  }
}

class _MemberBand extends StatelessWidget {
  const _MemberBand({required this.member});
  final Adventurer member;

  @override
  Widget build(BuildContext context) {
    final c = context.read<GuildController>();
    final cls = kClasses[member.classId]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      color: T.band,
      padding: const EdgeInsets.fromLTRB(0, 18, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 62, color: T.amber),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 14),
            child: ClassEmblem(classId: member.classId, color: T.steel, size: 34),
          ),
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
                          Text(cls.name,
                              style: T.micro.copyWith(color: T.amber)),
                          const SizedBox(height: 5),
                          Text(member.name, style: T.title),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('LEVEL', style: T.micro),
                        const SizedBox(height: 2),
                        Text('${member.level}'.padLeft(2, '0'),
                            style: T.numeric.copyWith(fontSize: 30)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Meter(value: member.xp / member.xpToNext, segments: 26, height: 4),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('XP', style: T.micro),
                    const Spacer(),
                    Text('${member.xp} / ${member.xpToNext}', style: T.micro),
                  ],
                ),
                const SizedBox(height: 14),
                Text(cls.windowText.toUpperCase(),
                    style: T.micro.copyWith(color: T.good)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 2,
                  children: [
                    for (final l in (cls.base + cls.windowBonus).lines)
                      Text(l, style: T.mono.copyWith(fontSize: 11, color: T.dim)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('KIT', style: T.micro),
                const SizedBox(height: 7),
                Row(
                  children: [
                    for (var i = 0; i < kGearSlots; i++) ...[
                      Expanded(
                        child: _Slot(
                          uid: i < member.equipped.length
                              ? member.equipped[i]
                              : null,
                          onTap: () => _openSlot(
                            context,
                            c,
                            member,
                            i < member.equipped.length
                                ? member.equipped[i]
                                : null,
                          ),
                        ),
                      ),
                      if (i == 0) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
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
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('ASSIGN TO ${m.name}', style: T.micro),
            ),
            const SizedBox(height: 14),
            if (current != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () async {
                    final name =
                        gearById(c.g.gearByUid(current)!.defId).name;
                    Navigator.pop(sheetCtx);
                    await c.unequip(m.id, current);
                    if (!context.mounted) return;
                    showFlash(
                      context,
                      kicker: 'RETURNED TO VAULT',
                      title: name,
                      color: T.dim,
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text('REMOVE CURRENT',
                        style: T.mono.copyWith(
                            color: T.bad, fontSize: 12, letterSpacing: 2)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (spare.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child:
                    Text('Vault is empty.', style: T.mono.copyWith(color: T.dim)),
              )
            else
              for (final gear in spare)
                GestureDetector(
                  onTap: () async {
                    final def = gearById(gear.defId);
                    Navigator.pop(sheetCtx);
                    await c.equip(m.id, gear.uid);
                    if (!context.mounted) return;
                    showFlash(
                      context,
                      kicker: 'ASSIGNED TO ${m.name}',
                      title: def.name,
                      lines: def.bonus.lines,
                      color: rarityColor(def.rarity),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: _GearBand(gear: gear),
                ),
          ],
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.uid, required this.onTap});
  final String? uid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.read<GuildController>();
    final gear = uid == null ? null : c.g.gearByUid(uid!);
    final def = gear == null ? null : gearById(gear.defId);
    final filled = def != null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        decoration: BoxDecoration(
          color: filled ? T.amber.withValues(alpha: 0.07) : Colors.transparent,
          border: Border.all(color: filled ? T.amber : T.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(def?.name ?? 'EMPTY SLOT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.mono.copyWith(
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: filled ? T.text : T.dim)),
            const SizedBox(height: 3),
            Text(def == null ? 'TAP TO ASSIGN' : def.bonus.lines.join('  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.micro.copyWith(
                    color: filled ? T.good : T.dim, letterSpacing: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _GearBand extends StatelessWidget {
  const _GearBand({required this.gear});
  final Gear gear;

  @override
  Widget build(BuildContext context) {
    final def = gearById(gear.defId);
    final color = rarityColor(def.rarity);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      color: T.band,
      padding: const EdgeInsets.fromLTRB(0, 13, 20, 13),
      child: Row(
        children: [
          Container(width: 3, height: 34, color: color),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.name,
                    style: T.mono.copyWith(
                        fontSize: 14, letterSpacing: 1.2, color: color)),
                const SizedBox(height: 3),
                Text(def.bonus.lines.join('   '),
                    style: T.micro.copyWith(color: T.good, letterSpacing: 0.6)),
              ],
            ),
          ),
          Text(def.rarity.label, style: T.micro.copyWith(color: color)),
        ],
      ),
    );
  }
}
