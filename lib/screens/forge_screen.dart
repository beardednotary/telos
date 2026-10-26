import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/guild_state.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/camp_controls.dart';
import '../widgets/management_widgets.dart';
import 'roster_screen.dart';

class ForgeScreen extends StatefulWidget {
  const ForgeScreen({super.key});

  @override
  State<ForgeScreen> createState() => _ForgeScreenState();
}

class _ForgeScreenState extends State<ForgeScreen> {
  String? _open = Rarity.common.name;

  void _toggle(String id) => setState(() => _open = _open == id ? null : id);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final catalogue = craftableGear(c.g);
    final spare = c.g.unequippedGear;
    return Scaffold(
      appBar: AppBar(title: const Text('Forge')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Text('Made for the next run.', style: T.display),
            const SizedBox(height: 8),
            Text('Forge level ${c.forgeLevel} · Choose a named piece to craft.',
                style: T.secondary),
            const SizedBox(height: 20),
            StoreBalance(guild: c.g),
            const SizedBox(height: 24),
            for (final rarity in Rarity.values)
              if (catalogue.any((def) => def.rarity == rarity)) ...[
                CampDisclosure(
                  key: Key('recipes-${rarity.name}'),
                  title: '${fieldName(rarity.name)} equipment',
                  summary: c.forgeCanWork(rarity)
                      ? switch (catalogue
                          .where((def) => def.rarity == rarity)
                          .length) {
                          1 => '1 recipe',
                          final n => '$n recipes',
                        }
                      : 'Requires forge level ${kForgeLevelFor[rarity]}',
                  icon: Icons.handyman_outlined,
                  expanded: _open == rarity.name,
                  onToggle: () => _toggle(rarity.name),
                  child: Column(children: [
                    for (final def
                        in catalogue.where((def) => def.rarity == rarity))
                      GearEntry(
                        key: Key('recipe-${def.id}'),
                        def: def,
                        onTap: () =>
                            showCampSheet(context, _RecipeReview(def: def)),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
            if (catalogue.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text('Open a sector to learn its equipment recipes.',
                    style: T.secondary),
              ),
            CampDisclosure(
              key: const Key('melt-disclosure'),
              title: 'Melt spare gear',
              summary: '${spare.length} unassigned pieces · Recover alloy',
              icon: Icons.recycling_outlined,
              expanded: _open == 'melt',
              onToggle: () => _toggle('melt'),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      spare.isEmpty
                          ? 'No unassigned equipment. Equipped pieces stay with their wearers.'
                          : 'Melting destroys a piece and returns some alloy. Equipped pieces are protected.',
                      style: T.secondary),
                ),
                for (final gear in spare)
                  GearEntry(
                    key: Key('melt-${gear.uid}'),
                    def: gearById(gear.defId),
                    detail:
                        'Recover ${kMeltValue[gearById(gear.defId).rarity]} alloy',
                    onTap: () =>
                        showCampSheet(context, _MeltReview(gear: gear)),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            CampLink(
              title: 'Assign equipment',
              detail: 'Forged pieces wait in the vault',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RosterScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeReview extends StatelessWidget {
  const _RecipeReview({required this.def});
  final GearDef def;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final cost = kCraftCost[def.rarity]!;
    final owned = c.g.vault.where((gear) => gear.defId == def.id).length;
    final can = c.canCraft(def);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CampSheetHeader(title: 'Review recipe'),
      GearDetail(def: def),
      const SizedBox(height: 16),
      Text('$owned owned · Arrives unassigned in the vault.',
          style: T.secondary),
      const SizedBox(height: 24),
      SpendCost(
          guild: c.g,
          credits: cost.credits,
          alloy: cost.alloy,
          intel: cost.intel),
      const SizedBox(height: 16),
      if (!c.forgeCanWork(def.rarity)) ...[
        Text(
            'Requires forge level ${kForgeLevelFor[def.rarity]}. '
            'Your forge is level ${c.forgeLevel}.',
            style: T.body),
        const SizedBox(height: 16),
      ],
      CampAction(
        key: const Key('confirm-craft'),
        label: !c.forgeCanWork(def.rarity)
            ? 'Forge level too low'
            : can
                ? 'Craft ${fieldName(def.name)}'
                : 'More resources needed',
        onPressed: can
            ? () async {
                final gear = await c.craft(def);
                if (!context.mounted || gear == null) return;
                Navigator.pop(context);
                campNotice(context,
                    '${fieldName(def.name)} forged. Assign it in Roster & equipment.');
              }
            : null,
      ),
    ]);
  }
}

class _MeltReview extends StatelessWidget {
  const _MeltReview({required this.gear});
  final Gear gear;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final def = gearById(gear.defId);
    final value = kMeltValue[def.rarity]!;
    final cost = kCraftCost[def.rarity]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CampSheetHeader(title: 'Melt this piece?'),
      GearDetail(def: def),
      const SizedBox(height: 24),
      Text('Recover $value alloy', style: T.title),
      const SizedBox(height: 8),
      Text(
          'This piece will be destroyed. Your alloy increases from '
          '${c.g.alloy} to ${c.g.alloy + value}.',
          style: T.body),
      const SizedBox(height: 12),
      Text(
          'Crafting a replacement costs ${cost.credits} credits, '
          '${cost.alloy} alloy and ${cost.intel} intel.',
          style: T.secondary),
      const SizedBox(height: 24),
      CampButton(
        label: 'Keep this piece',
        onPressed: () => Navigator.pop(context),
      ),
      const SizedBox(height: 12),
      CampAction(
        key: const Key('confirm-melt'),
        label: 'Melt for $value alloy',
        onPressed: c.g.unequippedGear.any((item) => item.uid == gear.uid)
            ? () async {
                final got = await c.melt(gear);
                if (!context.mounted || got == null) return;
                Navigator.pop(context);
                campNotice(
                    context, '${fieldName(def.name)} melted. +$got alloy.');
              }
            : null,
      ),
    ]);
  }
}
