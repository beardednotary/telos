import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guild_state.dart';
import '../data/content.dart';
import '../models/models.dart';
import '../services/redeploy.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/contract_board.dart';
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
            Section(child: _Resources(g: g)),

            // The main action on this screen, sized like it. The repeats
            // below it are the fast path: the same dispatch again, one tap.
            Padding(
              padding: Section.margin,
              child: _DispatchBlock(hasHistory: g.log.isNotEmpty),
            ),
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
class _Resources extends StatelessWidget {
  const _Resources({required this.g});
  final GuildState g;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, int v, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: T.micro),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('$v', style: T.numeric.copyWith(color: color)),
              ),
            ],
          ),
        );

    Widget rule() => Container(
          width: 1,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 14),
          color: T.line,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        cell('CREDITS', g.credits, T.amber),
        rule(),
        cell('ALLOY', g.alloy, T.steel),
        rule(),
        cell('INTEL', g.intel, T.cyan),
      ],
    );
  }
}

class _DispatchBlock extends StatelessWidget {
  const _DispatchBlock({required this.hasHistory});
  final bool hasHistory;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DispatchScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: T.amber.withValues(alpha: 0.10),
          border: Border.all(color: T.amber, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'DISPATCH',
                    style: T.mono.copyWith(
                      color: T.amber,
                      fontSize: 34,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 5,
                      height: 1.0,
                    ),
                  ),
                ),
                Text('>',
                    style: T.mono
                        .copyWith(color: T.amber, fontSize: 26, height: 1.0)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasHistory
                  ? 'Squad at camp. Nothing in here advances while you watch it.'
                  : 'The outpost has reopened. Nobody has been sent out yet.',
              style: T.mono.copyWith(fontSize: 13, height: 1.6, color: T.dim),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recent dispatches, sent again in one tap with no dispatch screen.
///
/// Tapping starts the run; the root router then shows the session because a
/// run is live, so there is nothing to navigate. Nothing here is a reminder:
/// it shows what was sent before, never that nothing has been sent lately.
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
          color: sc.withValues(alpha: 0.055),
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
