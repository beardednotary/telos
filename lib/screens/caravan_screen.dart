import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/caravan.dart';
import '../state/guild_controller.dart';
import '../theme/telos_theme.dart';
import '../widgets/camp_controls.dart';
import '../widgets/expedition_widgets.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Weekdays", "Every day", or "Mon, Wed, Fri".
String caravanDaysLabel(Set<int> days) {
  const weekdays = {1, 2, 3, 4, 5};
  if (days.length == 7) return 'Every day';
  if (days.length == 5 && days.containsAll(weekdays)) return 'Weekdays';
  if (days.length == 2 && days.containsAll(const {6, 7})) return 'Weekends';
  return [for (final d in days.toList()..sort()) _dayNames[d - 1]].join(', ');
}

/// "Leaves 9:00 AM · Weekdays", for summaries.
String caravanSummary(BuildContext context, CaravanSchedule s) =>
    'Leaves ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: s.hour, minute: s.minute))}'
    ' · ${caravanDaysLabel(s.weekdays)}';

/// Where the player sets their punch clock.
class CaravanScreen extends StatefulWidget {
  const CaravanScreen({super.key});

  @override
  State<CaravanScreen> createState() => _CaravanScreenState();
}

class _CaravanScreenState extends State<CaravanScreen> {
  late TimeOfDay _time;
  late Set<int> _days;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<GuildController>().g.caravan;
    _time = s == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: s.hour, minute: s.minute);
    _days = s == null ? {1, 2, 3, 4, 5} : Set.of(s.weekdays);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _save(CaravanSchedule? schedule) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<GuildController>().setCaravan(schedule);
      if (mounted) await Navigator.maybePop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    final current = c.g.caravan;
    final next = nextCaravanDeparture(current, DateTime.now());
    final met = c.g.caravansMet;
    final loc = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Caravan')),
      body: Column(children: [
        Expanded(
          child: ListView(
            key: const Key('caravan-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              const Text('Start on time.', style: T.display),
              const SizedBox(height: 12),
              const Text(
                  'Name the time you mean to start work. On those days a '
                  'supply caravan reaches the gate $kCaravanGateMinutes '
                  'minutes before, and leaves on the minute. A squad sent '
                  'out with it brings back things nothing else carries.',
                  style: T.body),
              const SizedBox(height: 12),
              Text(
                  'Late, its tracks stay fresh for an hour, and what the '
                  'squad can still bring back from it fades by the minute. '
                  'Missing it costs nothing you already have.',
                  style: T.secondary),
              const SizedBox(height: 20),
              ExpeditionPanel(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('DEPARTURE', style: T.label),
                  const SizedBox(height: 4),
                  InkWell(
                    key: const Key('caravan-time'),
                    onTap: _pickTime,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        Expanded(
                            child: Text(loc.formatTimeOfDay(_time),
                                style: T.title)),
                        Text('Change', style: T.secondary),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('DAYS', style: T.label),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        key: Key('caravan-day-$d'),
                        label: Text(_dayNames[d - 1]),
                        selected: _days.contains(d),
                        onSelected: (on) =>
                            setState(() => on ? _days.add(d) : _days.remove(d)),
                      ),
                  ]),
                ],
              )),
              if (current != null) ...[
                const SizedBox(height: 20),
                Text(caravanSummary(context, current), style: T.body),
                if (next != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        'Next at the gate: ${loc.formatShortDate(next)}, '
                        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(next.subtract(const Duration(minutes: kCaravanGateMinutes))))}',
                        style: T.secondary),
                  ),
              ],
              if (met > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      'Met at the gate $met ${met == 1 ? 'time' : 'times'}.',
                      style: T.secondary),
                ),
            ],
          ),
        ),
        ExpeditionFooter(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          CampButton(
            key: const Key('caravan-save'),
            label: _days.isEmpty
                ? 'Choose at least one day'
                : current == null
                    ? 'Schedule the caravan'
                    : 'Save changes',
            primary: true,
            onPressed: _saving || _days.isEmpty
                ? null
                : () => _save(CaravanSchedule(
                    minuteOfDay: _time.hour * 60 + _time.minute,
                    weekdays: Set.of(_days))),
          ),
          if (current != null) ...[
            const SizedBox(height: 8),
            CampButton(
              key: const Key('caravan-stop'),
              label: 'Stop the caravan',
              onPressed: _saving ? null : () => _save(null),
            ),
          ],
        ])),
      ]),
    );
  }
}

/// The caravan as it stands right now, on camp. Only there while it is at
/// the gate or its tracks are fresh; otherwise camp looks as it always has.
///
/// Ticks on its own, because the controller's clock only runs during a run.
class CaravanCard extends StatefulWidget {
  const CaravanCard({super.key, required this.onDispatch});
  final VoidCallback onDispatch;

  @override
  State<CaravanCard> createState() => _CaravanCardState();
}

class _CaravanCardState extends State<CaravanCard> {
  late final _clock = Stream<void>.periodic(const Duration(seconds: 15));

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GuildController>();
    if (c.g.caravan == null) return const SizedBox.shrink();
    return StreamBuilder<void>(
      stream: _clock,
      builder: (context, _) {
        final now = DateTime.now();
        final status = c.caravanAt(now);
        if (status == null) return const SizedBox.shrink();
        final mins = (status.remaining(now).inSeconds / 60).ceil();
        final caught = status.caught;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: T.card,
            shape: RoundedRectangleBorder(
                side: BorderSide(color: caught ? T.amber : T.boundary)),
            child: InkWell(
              key: const Key('caravan-card'),
              onTap: widget.onDispatch,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        caught
                            ? 'THE CARAVAN IS AT THE GATE'
                            : 'THE CARAVAN HAS LEFT',
                        style:
                            T.label.copyWith(color: caught ? T.amber : null)),
                    const SizedBox(height: 6),
                    Text(
                        caught
                            ? 'Leaves in $mins ${mins == 1 ? 'minute' : 'minutes'}.'
                            : 'You missed the caravan, but there is still work to be done.',
                        style: T.title),
                    const SizedBox(height: 6),
                    Text(
                        caught
                            ? 'Send a squad out with it.'
                            : 'Start a run now. Its tracks are fresh: '
                                '${(status.strength * 100).round()}% of its '
                                'salvage still in reach, fading by the minute.',
                        style: T.secondary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One line for the dispatch screen, so the player knows before they commit.
String? caravanDispatchLine(CaravanStatus? status) {
  if (status == null) return null;
  return status.caught
      ? 'The caravan is at the gate. This squad leaves with it.'
      : "On the caravan's tracks: ${(status.strength * 100).round()}% of its "
          'salvage still in reach.';
}

/// What the debrief says about the caravan's part in a run.
String caravanDebriefLine({
  required double share,
  required bool recalled,
}) {
  if (recalled) return 'Recalled early. The caravan went on without them.';
  if (share >= 1) return 'They left with the caravan.';
  return "You missed the caravan, but the squad followed its tracks with "
      '${(share * 100).round()}% of its salvage still in reach.';
}

/// For the debrief's caravan beat: the field name of each piece it gave.
String caravanHaulLine(List<String> names) => names.isEmpty
    ? 'Nothing from the caravan this time.'
    : 'The caravan handed over ${names.map(fieldName).join(' and ')}.';
