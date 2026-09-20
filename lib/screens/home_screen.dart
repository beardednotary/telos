import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guild_state.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/terminal.dart';
import 'dispatch_screen.dart';
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            _GuildHeader(g: g),
            const SizedBox(height: 18),
            _ResourceBar(g: g),
            const SizedBox(height: 22),

            // The one thing this screen is for.
            Panel(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STATUS', style: T.label),
                  const SizedBox(height: 6),
                  Text(
                    g.log.isEmpty
                        ? 'The outpost has reopened. Nobody has been sent out yet.'
                        : 'Squad at camp. Awaiting dispatch.',
                    style: T.mono.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  TButton(
                    'DISPATCH SQUAD',
                    filled: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DispatchScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Starts a focus session. Nothing in here advances while you watch it.',
                    style: T.label.copyWith(letterSpacing: 0.4, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),
            const PanelTitle('FIELD RECORD'),
            _StatStrip(g: g),

            const SizedBox(height: 22),
            const PanelTitle('OUTPOST'),
            _NavRow(
              label: 'ROSTER',
              value: '${g.roster.length}/${g.rosterSlots}',
              hint: 'Squad members, levels and gear',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RosterScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _NavRow(
              label: 'FACILITIES',
              value: 'LV ${g.facilities.values.reduce((a, b) => a + b)}',
              hint: 'Upgrades, recruiting, new sectors',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OutpostScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _NavRow(
              label: 'FIELD LOG',
              value: '${g.log.length}',
              hint: 'Every session, and what you said you were doing',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuildHeader extends StatelessWidget {
  const _GuildHeader({required this.g});
  final GuildState g;

  @override
  Widget build(BuildContext context) {
    final pct = g.xp / g.xpToNext;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                g.guildName,
                style: T.heading.copyWith(fontSize: 17, letterSpacing: 2.4),
              ),
            ),
            Text('LV ${g.level}',
                style: T.mono.copyWith(color: T.amber, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 10),
        Meter(value: pct, segments: 24),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('GUILD XP', style: T.label),
            const Spacer(),
            Text('${g.xp} / ${g.xpToNext}',
                style: T.label.copyWith(color: T.dim)),
          ],
        ),
      ],
    );
  }
}

class _ResourceBar extends StatelessWidget {
  const _ResourceBar({required this.g});
  final GuildState g;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, int value, Color color) => Expanded(
          child: Panel(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: T.label.copyWith(fontSize: 9)),
                const SizedBox(height: 4),
                Text('$value',
                    style: T.mono.copyWith(color: color, fontSize: 18)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        cell(Res.credits.label, g.credits, T.amber),
        const SizedBox(width: 8),
        cell(Res.alloy.label, g.alloy, T.text),
        const SizedBox(width: 8),
        cell(Res.intel.label, g.intel, T.cyan),
      ],
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.g});
  final GuildState g;

  @override
  Widget build(BuildContext context) {
    final mins = g.totalFocusMinutes;
    final h = mins ~/ 60;
    final m = mins % 60;
    return Panel(
      child: Column(
        children: [
          KV('PROTECTED TIME', h > 0 ? '${h}h ${m}m' : '${m}m',
              color: T.amber, bold: true),
          KV('EXPEDITIONS', '${g.log.length}'),
          KV('CLEAN RUNS', '${g.cleanRuns}'),
          KV('DAY STREAK', '${g.streak}'),
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
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: T.mono.copyWith(letterSpacing: 1.6)),
                const SizedBox(height: 3),
                Text(hint, style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3)),
              ],
            ),
          ),
          Text(value, style: T.mono.copyWith(color: T.dim)),
          const SizedBox(width: 10),
          Text('>', style: T.mono.copyWith(color: T.dim)),
        ],
      ),
    );
  }
}
