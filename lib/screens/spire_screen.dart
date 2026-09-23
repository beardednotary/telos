import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guild_state.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/terminal.dart';

/// What is left after the ending.
///
/// The Spire was never finished: every group that worked on it stopped, which
/// is why nobody knows what it is for. The player's hours now go into it, one
/// floor per 20.
///
/// This screen is a record, not a target. There is deliberately no countdown
/// to the next floor, no projection, nothing the player could fall behind on -
/// the whole point is that a month away costs nothing. See the story bible.
class SpireScreen extends StatelessWidget {
  const SpireScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GuildController>().g;
    final mine = g.spireFloors;
    final hours = g.minutesSinceSpire ~/ 60;

    return TerminalScaffold(
      title: 'THE SPIRE',
      actions: [Text('SECTOR 05', style: T.micro)],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'The top course was never finished. Cut stone stacked ready, '
            'mortar never mixed. Everyone who worked on it stopped, which is '
            'why nobody knows what it is for.',
            style: T.mono.copyWith(fontSize: 13, height: 1.7, color: T.dim),
          ),
          const SizedBox(height: 24),
          _Tower(mine: mine),
          const SizedBox(height: 28),
          _Line(
            label: 'RAISED BY YOU',
            value: '$mine',
            unit: mine == 1 ? 'floor' : 'floors',
            accent: T.amber,
          ),
          const SizedBox(height: 14),
          const _Line(
            label: 'STANDING BEFORE YOU',
            value: '${GuildState.kHistoricalFloors}',
            unit: 'floors',
            accent: T.dim,
          ),
          const SizedBox(height: 26),
          Container(height: 1, color: T.line),
          const SizedBox(height: 26),
          _Line(
            label: 'YOUR HOURS ON THIS CHARTER',
            value: '$hours',
            unit: 'h',
            accent: T.text,
          ),
          const SizedBox(height: 14),
          const _Line(
            label: 'THEIRS',
            value: '${GuildState.kCharterHours}',
            unit: 'h',
            accent: T.dim,
          ),
          const SizedBox(height: 28),
          Text(
            'One floor for every ${GuildState.kFloorHours} hours. It does not '
            'decay and it cannot be bought.',
            style: T.mono.copyWith(fontSize: 12, height: 1.7, color: T.dim),
          ),
        ],
      ),
    );
  }
}

/// The structure itself, newest course at the top. The player's own floors
/// are the ones in amber - at first a rounding error against the centuries,
/// and after a few years genuinely a share of it.
class _Tower extends StatelessWidget {
  const _Tower({required this.mine});
  final int mine;

  @override
  Widget build(BuildContext context) {
    // Enough of the old structure to read as mass without scrolling forever.
    const shown = 24;
    return Container(
      color: T.band,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Column(
        children: [
          Text('UNFINISHED', style: T.micro.copyWith(color: T.dim)),
          const SizedBox(height: 10),
          for (var i = 0; i < mine.clamp(0, 40); i++)
            const _Course(color: T.amber, width: 0.74),
          if (mine > 40) ...[
            const SizedBox(height: 6),
            Text('+ ${mine - 40} more', style: T.micro.copyWith(color: T.amber)),
            const SizedBox(height: 6),
          ],
          if (mine == 0) ...[
            Text('nothing yet', style: T.micro.copyWith(color: T.dim)),
            const SizedBox(height: 8),
          ],
          for (var i = 0; i < shown; i++)
            _Course(color: T.line, width: 0.8 + i * 0.008),
          Text('+ ${GuildState.kHistoricalFloors - shown} below',
              style: T.micro.copyWith(color: T.dim)),
        ],
      ),
    );
  }
}

class _Course extends StatelessWidget {
  const _Course({required this.color, required this.width});
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: FractionallySizedBox(
        widthFactor: width,
        child: Container(height: 4, color: color),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });
  final String label;
  final String value;
  final String unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(label, style: T.micro)),
        Text(value, style: T.big.copyWith(fontSize: 30, color: accent)),
        const SizedBox(width: 5),
        Text(unit, style: T.mono.copyWith(fontSize: 13, color: T.dim)),
      ],
    );
  }
}
