import 'package:flutter/material.dart';

import '../models/guild_state.dart';
import '../models/models.dart';
import '../theme/telos_theme.dart';
import 'camp_controls.dart';
import 'expedition_widgets.dart';
import 'gear_mark.dart';

/// Reviews scroll as a whole so actions remain reachable with larger text.
Future<void> showCampSheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .9,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );

class CampSheetHeader extends StatelessWidget {
  const CampSheetHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(children: [
          Expanded(child: Text(title, style: T.title)),
          IconButton(
            tooltip: 'Close review',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ]),
      );
}

/// Prevent an accidental second tap while a purchase is being saved.
class CampAction extends StatefulWidget {
  const CampAction({super.key, required this.label, required this.onPressed});
  final String label;
  final Future<void> Function()? onPressed;

  @override
  State<CampAction> createState() => _CampActionState();
}

class _CampActionState extends State<CampAction> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => CampButton(
        label: _busy ? 'Saving…' : widget.label,
        primary: true,
        onPressed: _busy || widget.onPressed == null
            ? null
            : () async {
                if (_busy) return;
                setState(() => _busy = true);
                try {
                  await widget.onPressed!();
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
      );
}

void campNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message, style: T.body)));
}

class StoreBalance extends StatelessWidget {
  const StoreBalance({super.key, required this.guild});
  final GuildState guild;

  @override
  Widget build(BuildContext context) => ExpeditionPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('IN THE STORES', style: T.label),
          const SizedBox(height: 10),
          ResourceAmounts(
              credits: guild.credits, alloy: guild.alloy, intel: guild.intel),
        ]),
      );
}

class SpendCost extends StatelessWidget {
  const SpendCost({
    super.key,
    required this.guild,
    this.credits = 0,
    this.alloy = 0,
    this.intel = 0,
  });
  final GuildState guild;
  final int credits;
  final int alloy;
  final int intel;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COST', style: T.label),
          for (final (label, need, have) in [
            ('credits', credits, guild.credits),
            ('alloy', alloy, guild.alloy),
            ('intel', intel, guild.intel),
          ])
            if (need > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$need $label', style: T.data),
                      Text(
                        have >= need
                            ? 'Have $have · ${have - need} after'
                            : 'Have $have · Need ${need - have} more',
                        style: T.secondary,
                      ),
                    ]),
              ),
        ],
      );
}

class GearEntry extends StatelessWidget {
  const GearEntry({
    super.key,
    required this.def,
    required this.onTap,
    this.detail,
  });
  final GearDef def;
  final VoidCallback onTap;
  final String? detail;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: GearMark(id: def.id, size: 40),
        title: Text(fieldName(def.name), style: T.body),
        subtitle: Text(detail ?? describeBonus(def.bonus), style: T.secondary),
        trailing: const Icon(Icons.chevron_right, size: 20, color: T.dim),
        onTap: onTap,
      );
}

class GearDetail extends StatelessWidget {
  const GearDetail({super.key, required this.def});
  final GearDef def;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: GearMark(id: def.id, size: 96)),
          const SizedBox(height: 16),
          Text(fieldName(def.name), style: T.display),
          const SizedBox(height: 4),
          Text(fieldName(def.rarity.name), style: T.label),
          if (def.flavor.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(def.flavor, style: T.secondary),
          ],
          const SizedBox(height: 16),
          Text(describeBonus(def.bonus), style: T.body),
        ],
      );
}

class SlotComparison extends StatelessWidget {
  const SlotComparison({super.key, required this.before, required this.after});
  final Bonus before;
  final Bonus after;

  String _percent(double n) => '${n > 0 ? '+' : ''}${(n * 100).round()}%';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SLOT BONUSES · BEFORE → AFTER', style: T.label),
          const SizedBox(height: 8),
          for (final (label, old, next) in [
            ('Credits', before.credits, after.credits),
            ('Alloy', before.alloy, after.alloy),
            ('Intel', before.intel, after.intel),
            ('Gear-find modifier', before.rare, after.rare),
            ('XP', before.xp, after.xp),
          ])
            if (old != 0 || next != 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(label, style: T.secondary)),
                    const SizedBox(width: 12),
                    Text('${_percent(old)} → ${_percent(next)}', style: T.data),
                  ],
                ),
              ),
        ],
      );
}
