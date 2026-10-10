import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guild_state.dart';
import '../data/content.dart';
import '../models/models.dart';
import '../services/redeploy.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/contract_board.dart';
import '../widgets/sector_scene.dart';
import '../widgets/terminal.dart';
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
            _Header(g: g),
            const SizedBox(height: 16),
            _Resources(g: g),
            _Ground(g: g),

            // The main action on this screen, sized like it. The repeats
            // below it are the fast path: the same dispatch again, one tap.
            // Section carries its own margin, so no wrapper here.
            _DispatchBlock(
                hasHistory: g.log.isNotEmpty, orderNo: g.runCounter + 1),
            _RedeployList(dispatches: recentDispatches(g)),

            const ContractBoardPanel(),
            if (g.nextGoal != null) _GoalBand(goal: g.nextGoal!),

            // The player's own record, so it carries their colour. It and
            // the guild header bookend the screen: who the guild is at the
            // top, what they have actually done at the bottom.
            Section(
                label: 'PROTECTED TIME', accent: T.amber, child: _Record(g: g)),

            Section(
              label: 'OUTPOST',
              rows: [
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
class _Resources extends StatelessWidget {
  const _Resources({required this.g});
  final GuildState g;

  @override
  Widget build(BuildContext context) {
    return Section(
      label: 'STORES',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldRow('CREDITS', '${g.credits}', valueColor: T.amber, seed: 61),
          FieldRow('ALLOY', '${g.alloy}', valueColor: T.steel, seed: 67),
          FieldRow('INTEL', '${g.intel}', valueColor: T.cyan, seed: 71),
        ],
      ),
    );
  }
}

/// A blank order, waiting to be signed.
///
/// A document has no call-to-action button. What it has is a form that is
/// not filled in yet - ruled fields with nothing written against them, and
/// a line at the bottom for a signature. Tapping it goes and fills it in.
///
/// That is the whole difference between this and a button labelled
/// DISPATCH in a box. The empty fields say what is being committed to
/// before any of it is chosen.
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
              style: T.mono.copyWith(fontSize: 13, height: 1.6, color: T.dim),
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
class _GoalBand extends StatelessWidget {
  const _GoalBand({required this.goal});
  final NextGoal goal;

  @override
  Widget build(BuildContext context) {
    final reachable = goal.blocked == null;
    final accent = reachable ? T.cyan : T.dim;

    return Section(
      label: 'NEXT  //  ${goal.kind}',
      labelColor: accent,
      trailing: goal.blocked ??
          (goal.progress >= 1.0
              ? 'READY'
              : '${(goal.progress * 100).round()}%'),
      trailingColor: goal.progress >= 1.0 && reachable ? T.good : accent,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(goal.label, style: T.title.copyWith(fontSize: 19)),
          const SizedBox(height: 12),
          Meter(value: goal.progress, segments: 26, height: 4, color: accent),
          const SizedBox(height: 8),
          Text(goal.detail, style: T.micro),
        ],
      ),
    );
  }
}

class _Record extends StatelessWidget {
  const _Record({required this.g});
  final GuildState g;

  @override
  Widget build(BuildContext context) {
    final mins = g.totalFocusMinutes;
    final h = mins ~/ 60;
    final m = mins % 60;

    // A label shrinks rather than running into its neighbour when the
    // system text size is turned up.
    Widget small(String label, String v) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label, style: T.micro),
              ),
            ),
            const SizedBox(height: 4),
            Text(v, style: T.mono.copyWith(fontSize: 20)),
          ],
        );

    // No meter and no target under the number. A bar implies somewhere to
    // get to, and there is nowhere to get to: this is a record of hours
    // already protected, and it only ever goes up.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$h', style: T.big.copyWith(fontSize: 68, color: T.amber)),
              Text('h ', style: T.mono.copyWith(fontSize: 22, color: T.dim)),
              Text('$m', style: T.big.copyWith(fontSize: 68)),
              Text('m', style: T.mono.copyWith(fontSize: 22, color: T.dim)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          g.log.isEmpty
              ? 'Nothing yet.'
              : 'Time the squad was out and you were working.',
          style: T.micro.copyWith(letterSpacing: 0.4, height: 1.6),
        ),
        const SizedBox(height: 22),
        Container(height: 1, color: T.line),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: small('EXPEDITIONS', '${g.log.length}')),
            Expanded(child: small('CLEAN RUNS', '${g.cleanRuns}')),
            Expanded(child: small('DAYS WORKED', '${g.daysWorked}')),
          ],
        ),
      ],
    );
  }
}

/// The deepest ground the guild has opened, drawn, directly above DISPATCH.
///
/// Home was a stack of numbers and read as a dashboard - the first thing
/// anyone sees, including in a screenshot, with nothing in it that could
/// only be this app. Every sector is already drawn for the debrief; this
/// puts one of them where it gets seen first.
///
/// It shows the deepest sector unlocked rather than the last one visited,
/// so the picture changes as the guild gets further in, and every run made
/// there is carved into it.
class _Ground extends StatelessWidget {
  const _Ground({required this.g});
  final GuildState g;

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
      child: SectorScene(
        sectorId: sector.id,
        color: sc,
        depths: [
          for (final p in g.log)
            if (p.sectorId == sector.id)
              p.elapsedSeconds / 60 / sector.nominalMinutes,
        ],
        floors: g.spireComplete ? g.spireFloors : 0,
        height: 104,
        // Still, never animated: nothing on this screen may advance while
        // it is being watched.
        animate: false,
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
