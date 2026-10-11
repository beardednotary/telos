import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guild_state.dart';
import '../data/content.dart';
import '../models/models.dart';
import '../services/redeploy.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/sector_scene.dart';
import '../widgets/terminal.dart';
import 'contracts_screen.dart';
import 'spire_screen.dart';
import 'dispatch_screen.dart';
import 'forge_screen.dart';
import 'log_screen.dart';
import 'outpost_screen.dart';
import 'roster_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final g = c.g;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Home is for dispatching, not for reading. It carried eight
            // zones and twenty-five figures, which is a dashboard whatever
            // it is printed in. What is left is who you are, where you last
            // worked, the order you have not signed yet, and the orders you
            // can send again. Everything you study rather than glance at is
            // a line in the index below.
            _Header(g: g),
            const SizedBox(height: 16),
            _Ground(g: g, goal: g.nextGoal),
            _DispatchBlock(
                hasHistory: g.log.isNotEmpty, orderNo: g.runCounter + 1),
            _RedeployList(dispatches: recentDispatches(g)),

            Section(
              label: 'OUTPOST',
              rows: [
                _NavRow(
                  label: 'CONTRACTS',
                  value: c.claimableContracts > 0
                      ? '${c.claimableContracts} READY'
                      : '${c.contracts.length}',
                  hint: 'Standing work, and what it pays',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ContractsScreen())),
                ),
                _NavRow(
                  label: 'STORES',
                  value: '${g.credits} CR',
                  hint: 'Credits, alloy and intel in the chest',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const OutpostScreen())),
                ),
                _NavRow(
                  label: 'ROSTER',
                  value: '${g.roster.length}/${g.rosterSlots}',
                  hint: 'Squad, levels, gear',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RosterScreen())),
                ),
                _NavRow(
                  label: 'FACILITIES',
                  value: 'LV ${g.facilities.values.reduce((a, b) => a + b)}',
                  hint: 'Upgrades, recruiting, sectors',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const OutpostScreen())),
                ),
                _NavRow(
                  label: 'FORGE',
                  value: 'LV ${g.facilities[Facility.forge]}',
                  hint: 'Build gear from what you have charted',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ForgeScreen())),
                ),
                if (g.spireComplete)
                  _NavRow(
                    label: 'THE SPIRE',
                    value: '${g.spireFloors}',
                    hint: 'What your hours have raised since you got there',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SpireScreen())),
                  ),
                _NavRow(
                  label: 'FIELD LOG',
                  value: '${g.log.length}',
                  hint: 'Every session, and what you said you were doing',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LogScreen())),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Full-bleed band. Guild identity and the long arc, and nothing else.
class _Header extends StatelessWidget {
  const _Header({required this.g});
  final GuildState g;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: T.band,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
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
                    Text('GUILD', style: T.micro),
                    const SizedBox(height: 6),
                    Text(g.guildName, style: T.title),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('LEVEL', style: T.micro),
                  const SizedBox(height: 2),
                  Text('${g.level}'.padLeft(2, '0'),
                      style: T.numeric.copyWith(color: T.amber)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Meter(value: g.xp / g.xpToNext, segments: 30, height: 4),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('GUILD XP', style: T.micro),
              const Spacer(),
              Text('${g.xp} / ${g.xpToNext}', style: T.micro),
            ],
          ),
        ],
      ),
    );
  }
}

/// Three big numbers, the size and the colour doing the work.
/// What is in the chest, as a stores return rather than three tiles.
class _DispatchBlock extends StatelessWidget {
  const _DispatchBlock({required this.hasHistory, required this.orderNo});
  final bool hasHistory;
  final int orderNo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DispatchScreen()),
      ),
      child: Section(
        label: 'ORDER No. ${orderNo.toString().padLeft(3, '0')}',
        trailing: 'UNSIGNED',
        trailingColor: T.amber,
        accent: T.amber,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldRow('SQUAD', '—', valueColor: T.dim, seed: 41),
            const FieldRow('PLACE', '—', valueColor: T.dim, seed: 43),
            const FieldRow('FOR', '—', valueColor: T.dim, seed: 47),
            const FieldRow('WHILE I', '—', valueColor: T.dim, seed: 53),
            const SizedBox(height: 14),
            Text(
              hasHistory
                  ? 'Squad at camp. Nothing in here advances while you watch it.'
                  : 'The outpost has reopened. Nobody has been sent out yet.',
              style: T.prose.copyWith(
                  fontSize: 15, height: 1.6, color: T.dim),
            ),
            const SizedBox(height: 16),
            // The signature line. Signing it is the act; there is no button.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: HandRule(seed: orderNo * 13 + 2)),
                const SizedBox(width: 12),
                Text('SIGN IT  >',
                    style: T.micro.copyWith(color: T.amber, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RedeployList extends StatelessWidget {
  const _RedeployList({required this.dispatches});
  final List<Redeploy> dispatches;

  @override
  Widget build(BuildContext context) {
    if (dispatches.isEmpty) return const SizedBox.shrink();
    final c = context.read<GuildController>();

    return Section(
      label: 'SEND AGAIN',
      rows: [
        for (final d in dispatches)
          _RedeployRow(
            dispatch: d,
            squad: d.squad
                .map((id) => c.g.memberById(id)?.name)
                .whereType<String>()
                .join(', '),
            onTap: () => c.redeploy(d),
          ),
      ],
    );
  }
}

class _RedeployRow extends StatelessWidget {
  const _RedeployRow({
    required this.dispatch,
    required this.squad,
    required this.onTap,
  });

  final Redeploy dispatch;
  final String squad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sector = sectorById(dispatch.sectorId);
    final sc = Color(sector.accent);
    final detail = [
      squad,
      if (dispatch.intent.isNotEmpty) dispatch.intent,
    ].join('   //   ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: sc, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(13, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sector.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.title.copyWith(fontSize: 17)),
                  const SizedBox(height: 3),
                  // The duration leads the detail line rather than sitting
                  // beside the name, which needs the full width.
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '${dispatch.minutes} MIN   ',
                          style: TextStyle(color: sc)),
                      TextSpan(text: detail),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.micro.copyWith(letterSpacing: 0.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('>', style: T.mono.copyWith(color: sc, fontSize: 17)),
          ],
        ),
      ),
    );
  }
}

/// The middle horizon: its own card, edged in the colour of whether it can
/// be reached yet.
class _Ground extends StatelessWidget {
  const _Ground({required this.g, this.goal});
  final GuildState g;

  /// What opens next, as a line under the plate rather than a band of its
  /// own. It is a note about this ground, not a separate subject.
  final NextGoal? goal;

  @override
  Widget build(BuildContext context) {
    final open = kSectors
        .where((s) => g.sectorUnlocked(s.id) && SectorScene.has(s.id))
        .toList();
    if (open.isEmpty) return const SizedBox.shrink();
    final sector = open.last;
    final sc = Color(sector.accent);

    return Section(
      label: sector.designation,
      accent: sc,
      trailing: sector.name,
      trailingColor: sc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectorScene(
            sectorId: sector.id,
            color: sc,
            depths: [
              for (final p in g.log)
                if (p.sectorId == sector.id)
                  p.elapsedSeconds / 60 / sector.nominalMinutes,
            ],
            floors: g.spireComplete ? g.spireFloors : 0,
            height: 104,
            // Still, never animated: nothing on this screen may advance
            // while it is being watched.
            animate: false,
          ),
          if (goal != null) ...[
            const SizedBox(height: 14),
            const HandRule(seed: 404),
            const SizedBox(height: 8),
            FieldRow('NEXT', goal!.label, seed: 81),
            Text(goal!.detail, style: T.micro.copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: T.row),
                  const SizedBox(height: 3),
                  Text(hint, style: T.micro.copyWith(letterSpacing: 0.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(value, style: T.mono.copyWith(color: T.dim, fontSize: 16)),
            const SizedBox(width: 12),
            Text('>', style: T.mono.copyWith(color: T.dim, fontSize: 17)),
          ],
        ),
      ),
    );
  }
}
