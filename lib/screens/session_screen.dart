import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../models/models.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/sigil.dart';
import '../widgets/terminal.dart';

/// The live run. Deliberately almost empty: there is nothing to tap, nothing
/// to collect, and watching it costs you integrity. The countdown is the only
/// thing on it allowed to be large.
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
        .join(' / ');

    final sc = Color(sector.accent);
    final iColor = integrity >= 0.999
        ? T.good
        : integrity >= 0.7
            ? T.amber
            : T.bad;

    String two(int n) => n.toString().padLeft(2, '0');
    final clock = left.inHours > 0
        ? '${left.inHours}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}'
        : '${two(left.inMinutes)}:${two(left.inSeconds % 60)}';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // -- destination band ------------------------------------------
            Container(
              width: double.infinity,
              // The live run belongs to its sector, not to a neutral grey.
              color: sc.withValues(alpha: 0.10),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(sector.designation,
                          style: T.micro.copyWith(color: sc)),
                      const Spacer(),
                      Container(
                        width: 6,
                        height: 6,
                        color: done ? T.good : T.amber,
                      ),
                      const SizedBox(width: 8),
                      Text(done ? 'RETURNED' : 'IN TRANSIT',
                          style:
                              T.micro.copyWith(color: done ? T.good : T.amber)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sector.name,
                                style:
                                    T.title.copyWith(fontSize: 20, color: sc)),
                            const SizedBox(height: 7),
                            Text(squad,
                                style: T.micro.copyWith(letterSpacing: 1.0)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      SigilPlate(sectorId: sector.id, color: sc, size: 66),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // -- the clock -------------------------------------------------
            Text(done ? '00:00' : clock,
                style: T.big.copyWith(color: done ? T.good : T.text)),
            const SizedBox(height: 10),
            Text(done ? 'EXPEDITION COMPLETE' : 'REMAINING',
                style: T.micro.copyWith(
                    color: done ? T.good : T.dim, letterSpacing: 3)),

            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child:
                  Meter(value: progress, segments: 34, height: 4, color: sc),
            ),

            const Spacer(flex: 2),

            // -- integrity -------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('INTEGRITY', style: T.micro),
                          const SizedBox(height: 4),
                          Text('${(integrity * 100).round()}%',
                              style: T.numeric.copyWith(color: iColor)),
                        ],
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          run.checkIns == 0
                              ? 'UNTOUCHED'
                              : '${run.checkIns} CHECK-IN'
                                  '${run.checkIns == 1 ? '' : 'S'}',
                          style: T.micro.copyWith(
                              color: run.checkIns == 0 ? T.good : T.amber),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Meter(
                      value: integrity, segments: 24, height: 5, color: iColor),
                ],
              ),
            ),

            if (run.intent.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                color: T.band,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INTENT', style: T.micro),
                    const SizedBox(height: 5),
                    Text(run.intent,
                        style: T.mono.copyWith(fontSize: 14, height: 1.4)),
                  ],
                ),
              ),
            ],

            const Spacer(flex: 1),

            // -- the only control ------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: done
                  ? _BigAction(
                      label: 'RECEIVE DEBRIEF',
                      color: T.good,
                      onTap: () => c.finishRun(recalled: false),
                    )
                  : Column(
                      children: [
                        Text('Nothing happens in here while you watch it.',
                            textAlign: TextAlign.center,
                            style: T.micro.copyWith(letterSpacing: 0.4)),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () => _confirmRecall(context, c),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('RECALL SQUAD',
                                style: T.mono.copyWith(
                                    color: T.bad,
                                    fontSize: 12,
                                    letterSpacing: 2.4)),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
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
        title: Text('RECALL SQUAD?',
            style: T.mono.copyWith(fontSize: 16, letterSpacing: 2)),
        content: Text(
          short
              ? 'They are $elapsedMin minutes in. ${sector.name} needs '
                  '${sector.minMinutes}. Pull them out now and they come back '
                  'with scraps - but the time still counts in your log.'
              : 'They are $elapsedMin minutes in. You keep what they have '
                  'gathered so far, scaled to how far they got.',
          style: T.mono.copyWith(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('KEEP GOING',
                style: T.mono.copyWith(color: T.amber, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('RECALL',
                style: T.mono.copyWith(color: T.bad, fontSize: 12)),
          ),
        ],
      ),
    );
    if (ok == true) await c.finishRun(recalled: true);
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          label,
          style: T.mono.copyWith(
            color: color,
            fontSize: 19,
            letterSpacing: 3.5,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }
}
