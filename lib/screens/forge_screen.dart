import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/guild_state.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/flash.dart';
import '../widgets/terminal.dart';

/// Where INTEL goes once every sector is open.
///
/// You forge a named piece, not a random one - saving toward a specific thing
/// is the opposite of a loot box, and the design notes are explicit about not
/// selling randomness. The forge level gates rarity, so the deep tiers stay
/// something to build toward.
class ForgeScreen extends StatelessWidget {
  const ForgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final g = c.g;
    final catalogue = craftableGear(g);
    final spare = g.unequippedGear;

    return TerminalScaffold(
      title: 'FORGE',
      actions: [Text('LV ${c.forgeLevel}', style: T.micro)],
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Container(
            color: T.band,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Bal('CREDITS', g.credits, T.amber),
                    _Bal('ALLOY', g.alloy, T.steel),
                    _Bal('INTEL', g.intel, T.cyan),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'The forge works at ${_tierText(c)}. Raise it in FACILITIES '
                  'to work deeper.',
                  style: T.micro.copyWith(letterSpacing: 0.4, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          if (catalogue.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Nothing to work from yet. Charting a sector is what teaches '
                'you to build its equipment.',
                style: T.micro.copyWith(letterSpacing: 0.4, height: 1.6),
              ),
            )
          else
            for (final r in Rarity.values) ...[
              if (catalogue.any((d) => d.rarity == r)) ...[
                _Rule(
                  label: r.label,
                  color: rarityColor(r),
                  trailing: c.forgeCanWork(r)
                      ? null
                      : 'NEEDS FORGE LV ${kForgeLevelFor[r]}',
                ),
                for (final def in catalogue.where((d) => d.rarity == r))
                  _CraftBand(def: def),
                const SizedBox(height: 20),
              ],
            ],

          const _Rule(
              label: 'VAULT', color: T.steel, trailing: 'MELT FOR ALLOY'),
          if (spare.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Nothing unassigned.',
                  style: T.micro.copyWith(letterSpacing: 0.4)),
            )
          else
            for (final gear in spare) _MeltBand(gear: gear),
        ],
      ),
    );
  }

  String _tierText(GuildController c) {
    final can = Rarity.values.where(c.forgeCanWork).toList();
    if (can.isEmpty) return 'nothing yet';
    return '${can.first.label.toLowerCase()} to ${can.last.label.toLowerCase()}';
  }
}

class _Bal extends StatelessWidget {
  const _Bal(this.label, this.value, this.color);
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
              child: Text('$value',
                  style: T.numeric.copyWith(fontSize: 26, color: color)),
            ),
          ],
        ),
      );
}

class _Rule extends StatelessWidget {
  const _Rule({required this.label, required this.color, this.trailing});
  final String label;
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Row(
          children: [
            Text(label, style: T.micro.copyWith(color: color)),
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

class _CraftBand extends StatelessWidget {
  const _CraftBand({required this.def});
  final GearDef def;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final color = rarityColor(def.rarity);
    final cost = kCraftCost[def.rarity]!;
    final can = c.canCraft(def);
    final gated = !c.forgeCanWork(def.rarity);

    Widget part(String label, int need, int have, Color hue) {
      final ok = have >= need;
      return Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Text('$need $label',
            style: T.mono.copyWith(
                fontSize: 11, color: ok ? hue : T.bad, letterSpacing: 0.6)),
      );
    }

    return Opacity(
      opacity: gated ? 0.4 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        color: T.band,
        padding: const EdgeInsets.fromLTRB(0, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, height: 48, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.name,
                      style: T.title.copyWith(fontSize: 17, color: color)),
                  const SizedBox(height: 5),
                  Text(def.bonus.lines.join('   '),
                      style: T.micro.copyWith(color: T.good)),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          children: [
                            part('CR', cost.credits, c.g.credits, T.amber),
                            part('AL', cost.alloy, c.g.alloy, T.steel),
                            part('IN', cost.intel, c.g.intel, T.cyan),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: can
                            ? () async {
                                await c.craft(def);
                                if (!context.mounted) return;
                                showFlash(
                                  context,
                                  kicker: 'FORGED',
                                  title: def.name,
                                  lines: def.bonus.lines,
                                  color: color,
                                  heavy: def.rarity == Rarity.epic,
                                );
                              }
                            : null,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: can
                                ? color.withValues(alpha: 0.12)
                                : Colors.transparent,
                            border:
                                Border.all(color: can ? color : T.line),
                          ),
                          child: Text('FORGE',
                              style: T.mono.copyWith(
                                  fontSize: 11,
                                  letterSpacing: 2,
                                  color: can ? color : T.dim)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeltBand extends StatelessWidget {
  const _MeltBand({required this.gear});
  final Gear gear;

  @override
  Widget build(BuildContext context) {
    final c = context.read<GuildController>();
    final def = gearById(gear.defId);
    final color = rarityColor(def.rarity);
    final value = kMeltValue[def.rarity]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      color: T.band,
      padding: const EdgeInsets.fromLTRB(0, 12, 20, 12),
      child: Row(
        children: [
          Container(width: 3, height: 32, color: color),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.name,
                    style: T.mono.copyWith(fontSize: 13, color: color)),
                const SizedBox(height: 3),
                Text('RETURNS $value ALLOY', style: T.micro),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final ok = await _confirm(context, def, value);
              if (ok != true) return;
              final got = await c.melt(gear);
              if (got == null || !context.mounted) return;
              showFlash(
                context,
                kicker: 'MELTED DOWN',
                title: def.name,
                lines: ['+$got ALLOY'],
                color: T.steel,
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text('MELT',
                  style: T.mono.copyWith(
                      fontSize: 11, letterSpacing: 2, color: T.bad)),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(BuildContext context, GearDef def, int value) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: T.card,
        shape: const Border.fromBorderSide(BorderSide(color: T.line)),
        title: Text('MELT ${def.name}?',
            style: T.mono.copyWith(fontSize: 15, letterSpacing: 1.5)),
        content: Text(
          'Destroyed for $value alloy. Forging it again costs '
          '${kCraftCost[def.rarity]!.alloy} alloy and '
          '${kCraftCost[def.rarity]!.intel} intel.',
          style: T.mono.copyWith(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('KEEP',
                style: T.mono.copyWith(color: T.amber, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('MELT',
                style: T.mono.copyWith(color: T.bad, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
