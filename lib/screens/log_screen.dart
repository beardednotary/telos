import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/terminal.dart';

/// Every session, with what you said you were doing. A focus app produces a
/// work log as a side effect - this is that log.
class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final log = c.g.log;
    final mins = c.g.totalFocusMinutes;

    return TerminalScaffold(
      title: 'FIELD LOG',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Panel(
            child: Column(
              children: [
                KV('PROTECTED TIME', '${mins ~/ 60}h ${mins % 60}m',
                    color: T.amber, bold: true),
                KV('EXPEDITIONS', '${log.length}'),
                KV('CLEAN RUNS', '${c.g.cleanRuns}'),
                KV(
                  'AVG INTEGRITY',
                  log.isEmpty
                      ? '-'
                      : '${(log.map((r) => r.integrity).reduce((a, b) => a + b) / log.length * 100).round()}%',
                ),
                KV(
                  'AVG SESSION',
                  log.isEmpty ? '-' : '${mins ~/ log.length}m',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (log.isEmpty)
            Panel(
              child: Text('No expeditions logged yet.',
                  style: T.label.copyWith(fontSize: 10, letterSpacing: 0.3)),
            )
          else
            for (final r in log) ...[
              _LogRow(record: r),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.record});
  final RunRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final sector = sectorById(r.sectorId);
    final d = r.endedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';

    final iColor = r.integrity >= 0.999
        ? T.good
        : r.integrity >= 0.7
            ? T.amber
            : T.bad;

    return Panel(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(stamp, style: T.label.copyWith(fontSize: 9)),
              const Spacer(),
              Text('${r.elapsedMinutes}m',
                  style: T.mono.copyWith(fontSize: 12, color: T.amber)),
              const SizedBox(width: 10),
              Text('${(r.integrity * 100).round()}%',
                  style: T.mono.copyWith(fontSize: 12, color: iColor)),
            ],
          ),
          const SizedBox(height: 6),
          Text(sector.name, style: T.mono.copyWith(fontSize: 12)),
          if (r.intent.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('> ', style: T.mono.copyWith(color: T.dim, fontSize: 11)),
                Expanded(
                  child: Text(r.intent,
                      style: T.mono.copyWith(fontSize: 11, height: 1.5)),
                ),
                if (r.progress != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    r.progress!,
                    style: T.label.copyWith(
                      fontSize: 9,
                      color: r.progress == 'YES'
                          ? T.good
                          : r.progress == 'SOME'
                              ? T.amber
                              : T.dim,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (r.note != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(r.note!,
                  style: T.label.copyWith(
                      fontSize: 10, letterSpacing: 0.3, height: 1.5)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (r.credits > 0)
                Text('+${r.credits} CR',
                    style: T.label.copyWith(fontSize: 9, color: T.amber)),
              if (r.alloy > 0) ...[
                const SizedBox(width: 10),
                Text('+${r.alloy} AL', style: T.label.copyWith(fontSize: 9)),
              ],
              if (r.intel > 0) ...[
                const SizedBox(width: 10),
                Text('+${r.intel} IN',
                    style: T.label.copyWith(fontSize: 9, color: T.cyan)),
              ],
              if (r.loot.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text('${r.loot.length} SALVAGE',
                    style: T.label.copyWith(fontSize: 9, color: T.amber)),
              ],
              const Spacer(),
              if (r.recalled)
                Text('RECALLED', style: T.label.copyWith(fontSize: 9, color: T.bad)),
            ],
          ),
        ],
      ),
    );
  }
}
