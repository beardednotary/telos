import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/terminal.dart';

/// The live run. Deliberately almost empty: there is nothing to tap, nothing
/// to collect, and watching it costs you integrity.
class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final run = c.active;
    if (run == null) return const SizedBox.shrink();

    final now = c.now;
    final sector = sectorById(run.sectorId);
    final done = run.isComplete(now);
    final left = run.remaining(now);
    final integrity = run.integrity(now);
    final elapsed = run.elapsedSeconds(now);
    final progress = elapsed / (run.plannedMinutes * 60);

    final squad = run.squad
        .map((id) => c.g.memberById(id))
        .whereType<Adventurer>()
        .map((m) => m.name)
        .join(', ');

    String two(int n) => n.toString().padLeft(2, '0');
    final clock = left.inHours > 0
        ? '${left.inHours}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}'
        : '${two(left.inMinutes)}:${two(left.inSeconds % 60)}';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(sector.designation, style: T.label),
                  const SizedBox(width: 10),
                  Expanded(child: Container(height: 1, color: T.line)),
                  const SizedBox(width: 10),
                  Text(done ? 'RETURNED' : 'IN TRANSIT',
                      style: T.label.copyWith(color: done ? T.good : T.amber)),
                ],
              ),
              const SizedBox(height: 10),
              Text(sector.name,
                  style: T.heading.copyWith(fontSize: 16, letterSpacing: 2.2)),
              const SizedBox(height: 4),
              Text('SQUAD: $squad', style: T.label),

              const Spacer(),

              // -- the clock -------------------------------------------
              Center(
                child: Column(
                  children: [
                    Text(done ? '00:00' : clock, style: T.big),
                    const SizedBox(height: 6),
                    Text(done ? 'EXPEDITION COMPLETE' : 'REMAINING',
                        style: T.label.copyWith(
                            color: done ? T.good : T.dim, letterSpacing: 2)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Meter(value: progress, segments: 30, height: 6),

              const SizedBox(height: 28),

              // -- integrity -------------------------------------------
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('INTEGRITY', style: T.label),
                        const Spacer(),
                        Text('${(integrity * 100).round()}%',
                            style: T.mono.copyWith(
                              color: integrity >= 0.999
                                  ? T.good
                                  : integrity >= 0.7
                                      ? T.amber
                                      : T.bad,
                              fontSize: 15,
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Meter(
                      value: integrity,
                      segments: 20,
                      height: 6,
                      color: integrity >= 0.999
                          ? T.good
                          : integrity >= 0.7
                              ? T.amber
                              : T.bad,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      done
                          ? 'Final. Rare finds were scaled to this.'
                          : run.checkIns == 0
                              ? 'Untouched since dispatch. Put the phone down and it stays there.'
                              : 'Reopened ${run.checkIns} time${run.checkIns == 1 ? '' : 's'}. '
                                  'Each check-in costs the squad.',
                      style: T.label.copyWith(
                          fontSize: 10, letterSpacing: 0.3, height: 1.5),
                    ),
                  ],
                ),
              ),

              if (run.intent.isNotEmpty) ...[
                const SizedBox(height: 12),
                Panel(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      Text('INTENT  ', style: T.label),
                      Expanded(
                        child: Text(run.intent,
                            style: T.mono.copyWith(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              if (done)
                TButton(
                  'RECEIVE DEBRIEF',
                  filled: true,
                  color: T.good,
                  onTap: () => c.finishRun(recalled: false),
                )
              else ...[
                Text(
                  'Nothing happens in here while you watch. Lock the phone.',
                  textAlign: TextAlign.center,
                  style: T.label.copyWith(fontSize: 10, letterSpacing: 0.4),
                ),
                const SizedBox(height: 10),
                TButton(
                  'RECALL SQUAD',
                  color: T.bad,
                  onTap: () => _confirmRecall(context, c),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRecall(BuildContext context, GuildController c) async {
    final run = c.active;
    if (run == null) return;
    final sector = sectorById(run.sectorId);
    final elapsedMin = run.elapsedSeconds(DateTime.now()) ~/ 60;
    final short = elapsedMin < sector.minMinutes;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: T.card,
        shape: const Border.fromBorderSide(BorderSide(color: T.line)),
        title: Text('RECALL SQUAD?', style: T.heading.copyWith(fontSize: 14)),
        content: Text(
          short
              ? 'They are $elapsedMin minutes in. ${sector.name} needs '
                  '${sector.minMinutes}. Pull them out now and they come back '
                  'with scraps - but the time still counts in your log.'
              : 'They are $elapsedMin minutes in. You keep what they have '
                  'gathered so far, scaled to how far they got.',
          style: T.mono.copyWith(fontSize: 12, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('KEEP GOING', style: T.label.copyWith(color: T.amber)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('RECALL', style: T.label.copyWith(color: T.bad)),
          ),
        ],
      ),
    );
    if (ok == true) await c.finishRun(recalled: true);
  }
}
