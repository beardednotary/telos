import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guild_state.dart';
import '../models/models.dart';
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
            _Resources(g: g),
            const SizedBox(height: 26),

            // The only action on this screen, sized like it.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _DispatchBlock(hasHistory: g.log.isNotEmpty),
            ),

            const SizedBox(height: 30),
            const ContractBoardPanel(),
            const SizedBox(height: 30),
            if (g.nextGoal != null) ...[
              _GoalBand(goal: g.nextGoal!),
              const SizedBox(height: 30),
            ],

            _Record(g: g),
            const SizedBox(height: 30),

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
              last: true,
            ),
            const SizedBox(height: 40),
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

/// Three big numbers. No boxes - the size and the colour do the work.
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          cell('CREDITS', g.credits, T.amber),
          rule(),
          cell('ALLOY', g.alloy, T.steel),
          rule(),
          cell('INTEL', g.intel, T.cyan),
        ],
      ),
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

/// The middle horizon, given a thick accent bar instead of another card.
class _GoalBand extends StatelessWidget {
  const _GoalBand({required this.goal});
  final NextGoal goal;

  @override
  Widget build(BuildContext context) {
    final reachable = goal.blocked == null;
    final accent = reachable ? T.cyan : T.dim;

    return Container(
      color: T.band,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('NEXT  //  ${goal.kind}',
                          style: T.micro.copyWith(color: accent)),
                      const Spacer(),
                      Text(
                        goal.blocked ??
                            (goal.progress >= 1.0
                                ? 'READY'
                                : '${(goal.progress * 100).round()}%'),
                        style: T.micro.copyWith(
                            color: goal.progress >= 1.0 && reachable
                                ? T.good
                                : accent),
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(goal.label, style: T.title.copyWith(fontSize: 19)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Meter(
                        value: goal.progress,
                        segments: 26,
                        height: 4,
                        color: accent),
                  ),
                  const SizedBox(height: 8),
                  Text(goal.detail, style: T.micro),
                ],
              ),
            ),
          ],
        ),
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
            Text(v, style: T.mono.copyWith(fontSize: 17)),
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROTECTED TIME', style: T.micro),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$h', style: T.big.copyWith(fontSize: 52, color: T.amber)),
              Text('h ', style: T.mono.copyWith(fontSize: 18, color: T.dim)),
              Text('$m', style: T.big.copyWith(fontSize: 52)),
              Text('m', style: T.mono.copyWith(fontSize: 18, color: T.dim)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: small('EXPEDITIONS', '${g.log.length}')),
              Expanded(child: small('CLEAN RUNS', '${g.cleanRuns}')),
              Expanded(child: small('DAYS WORKED', '${g.daysWorked}')),
            ],
          ),
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
    this.last = false,
  });

  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          border: Border(
            top: const BorderSide(color: T.line),
            bottom: last ? const BorderSide(color: T.line) : BorderSide.none,
          ),
        ),
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
            Text('>', style: T.mono.copyWith(color: T.line, fontSize: 17)),
          ],
        ),
      ),
    );
  }
}
