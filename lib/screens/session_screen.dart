import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/camp_controls.dart';
import '../widgets/expedition_widgets.dart';

/// No live loot, animated landscape, or management controls during focus.
class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final run = c.active;
    if (run == null) return const SizedBox.shrink();
    final sector = sectorById(run.sectorId);
    final done = run.isComplete(c.now);
    final left = run.remaining(c.now);
    String two(int n) => n.toString().padLeft(2, '0');
    final clock = left.inHours > 0
        ? '${left.inHours}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}'
        : '${two(left.inMinutes)}:${two(left.inSeconds % 60)}';
    final back = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(run.endsAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final names = run.squad
        .map(c.g.memberById)
        .where((m) => m != null)
        .map((m) => m!.name)
        .join(' & ');
    return Scaffold(
      backgroundColor: T.band,
      body: SafeArea(
          child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fieldName(sector.name), style: T.secondary),
                  const SizedBox(height: 6),
                  Text(names, style: T.secondary),
                ]),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          label: done
                              ? 'Expedition complete'
                              : '${left.inMinutes} minutes and ${left.inSeconds % 60} seconds remaining',
                          child: ExcludeSemantics(
                              child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(done ? '00:00' : clock,
                                key: const Key('focus-clock'),
                                style: T.big.copyWith(fontSize: 82)),
                          )),
                        ),
                        const SizedBox(height: 24),
                        Text(
                            run.intent.isEmpty
                                ? 'Your focus session.'
                                : run.intent,
                            textAlign: TextAlign.center,
                            style: T.title),
                        const SizedBox(height: 12),
                        Text(
                            done ? 'The squad has returned.' : 'Back at $back.',
                            textAlign: TextAlign.center,
                            style: T.secondary),
                      ]),
                ),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Integrity ${(run.integrity(c.now) * 100).round()}%',
                          key: const Key('session-integrity'),
                          textAlign: TextAlign.center,
                          style: T.secondary),
                      const SizedBox(height: 16),
                      if (done)
                        CampButton(
                          key: const Key('receive-debrief'),
                          label: 'Receive the report',
                          primary: true,
                          onPressed: () => c.finishRun(recalled: false),
                        )
                      else ...[
                        Text(
                            'Lock your phone. They will be here when you return.',
                            textAlign: TextAlign.center,
                            style: T.secondary),
                        const SizedBox(height: 12),
                        if (c.canCancel(c.now))
                          TextButton(
                            key: const Key('cancel-dispatch'),
                            onPressed: c.cancelRun,
                            child: Text(
                                'Cancel dispatch · ${(GuildController.cancelWindow - c.now.difference(run.startedAt)).inSeconds + 1}s',
                                style: T.secondary),
                          )
                        else
                          TextButton(
                            key: const Key('recall-squad'),
                            onPressed: () => _confirmRecall(context, c),
                            child: Text('Recall squad',
                                style: T.secondary.copyWith(color: T.bad)),
                          ),
                      ],
                    ]),
              ],
            ),
          ),
        )),
      )),
    );
  }

  Future<void> _confirmRecall(BuildContext context, GuildController c) async {
    final run = c.active;
    if (run == null) return;
    final sector = sectorById(run.sectorId);
    final minutes = run.elapsedSeconds(c.now) ~/ 60;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: T.card,
        title: Text('Recall the squad?', style: T.title),
        content: Text(
            minutes < sector.minMinutes
                ? 'They are $minutes minutes in. ${fieldName(sector.name)} needs ${sector.minMinutes}. '
                    'Returning now brings scraps: credits only, with no alloy, intel, or gear. Your time still counts.'
                : 'They are $minutes minutes in. You keep the earnings for the time completed.',
            style: T.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep going')),
          TextButton(
              key: const Key('confirm-recall'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Recall')),
        ],
      ),
    );
    if (ok == true && c.active?.id == run.id) await c.finishRun(recalled: true);
  }
}
