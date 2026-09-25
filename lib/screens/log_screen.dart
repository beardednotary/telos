import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/sigil.dart';
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
    final avgI = log.isEmpty
        ? 0
        : (log.map((r) => r.integrity).reduce((a, b) => a + b) /
                log.length *
                100)
            .round();

    return TerminalScaffold(
      title: 'FIELD LOG',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // -- headline ---------------------------------------------------
          Container(
            width: double.infinity,
            color: T.band,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PROTECTED TIME', style: T.micro),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${mins ~/ 60}',
                        style: T.big.copyWith(fontSize: 50, color: T.amber)),
                    Text('h ',
                        style: T.mono.copyWith(fontSize: 17, color: T.dim)),
                    Text('${mins % 60}', style: T.big.copyWith(fontSize: 50)),
                    Text('m',
                        style: T.mono.copyWith(fontSize: 17, color: T.dim)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _Stat('EXPEDITIONS', '${log.length}'),
                    _Stat('CLEAN', '${c.g.cleanRuns}'),
                    _Stat('AVG INTEGRITY', log.isEmpty ? '-' : '$avgI%'),
                    _Stat('AVG LENGTH',
                        log.isEmpty ? '-' : '${mins ~/ log.length}m'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (log.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('No expeditions logged yet.',
                  style: T.micro.copyWith(letterSpacing: 0.4)),
            )
          else
            for (final r in log) _LogBand(record: r),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: T.micro.copyWith(fontSize: 10)),
            const SizedBox(height: 4),
            Text(value, style: T.mono.copyWith(fontSize: 16)),
          ],
        ),
      );
}

class _LogBand extends StatelessWidget {
  const _LogBand({required this.record});
  final RunRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final sector = sectorById(r.sectorId);
    final d = r.endedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';

    final iColor = r.integrity >= 0.999
        ? T.good
        : r.integrity >= 0.7
            ? T.amber
            : T.bad;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      color: T.band,
      padding: const EdgeInsets.fromLTRB(0, 15, 20, 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 46, color: iColor),
          const SizedBox(width: 17),
          Expanded(
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
                          Text(stamp, style: T.micro.copyWith(fontSize: 10)),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Sigil(
                                  sectorId: sector.id,
                                  color: Color(sector.accent),
                                  size: 16),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(sector.name,
                                    style: T.title.copyWith(
                                        fontSize: 16,
                                        color: Color(sector.accent))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${r.elapsedMinutes}m',
                            style: T.mono.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w300,
                                color: T.amber,
                                height: 1.0)),
                        const SizedBox(height: 3),
                        Text('${(r.integrity * 100).round()}%',
                            style: T.micro.copyWith(color: iColor)),
                      ],
                    ),
                  ],
                ),
                if (r.intent.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(r.intent,
                            style:
                                T.mono.copyWith(fontSize: 13, height: 1.5)),
                      ),
                      if (r.progress != null) ...[
                        const SizedBox(width: 10),
                        Text(r.progress!,
                            style: T.micro.copyWith(
                              color: r.progress == 'YES'
                                  ? T.good
                                  : r.progress == 'SOME'
                                      ? T.amber
                                      : T.dim,
                            )),
                      ],
                    ],
                  ),
                ],
                if (r.note != null) ...[
                  const SizedBox(height: 4),
                  Text(r.note!,
                      style: T.micro.copyWith(letterSpacing: 0.4, height: 1.5)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (r.credits > 0)
                      Text('+${r.credits} CR',
                          style: T.micro.copyWith(color: T.amber)),
                    if (r.alloy > 0) ...[
                      const SizedBox(width: 12),
                      Text('+${r.alloy} AL',
                          style: T.micro.copyWith(color: T.steel)),
                    ],
                    if (r.intel > 0) ...[
                      const SizedBox(width: 12),
                      Text('+${r.intel} IN',
                          style: T.micro.copyWith(color: T.cyan)),
                    ],
                    if (r.loot.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Text('${r.loot.length} SALVAGE',
                          style: T.micro.copyWith(color: T.amber)),
                    ],
                    const Spacer(),
                    if (r.recalled)
                      Text('RECALLED', style: T.micro.copyWith(color: T.bad)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
