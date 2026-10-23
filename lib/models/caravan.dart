// ---------------------------------------------------------------------------
// THE CARAVAN
// An optional punch clock. The player names a time they mean to start work;
// on those days a supply caravan leaves the gate at that time, and a squad
// sent out with it brings back things nothing else in the game carries.
//
// This is the one opportunity in Telos that can be missed, and that is a
// deliberate exception to "never expire": the player sets it up themselves,
// and the point is to give starting on time some weight. It is shaped so
// that missing it never costs anything already earned:
//   - Nothing is taken away. Late, the bonus fades; it never goes negative.
//   - It is never a streak. A missed day leaves no mark on the next one.
//   - Off by default, and silent unless the player schedules it.
// ---------------------------------------------------------------------------

/// How long before departure the caravan is at the gate. Starting a little
/// early is starting on time.
const int kCaravanGateMinutes = 15;

/// How long after departure its tracks stay fresh. The salvage on offer
/// fades from full to nothing across this stretch.
const int kCaravanFadeMinutes = 60;

/// When the player means to start, and on which days.
class CaravanSchedule {
  /// Minutes after local midnight.
  final int minuteOfDay;

  /// [DateTime.monday] .. [DateTime.sunday].
  final Set<int> weekdays;

  const CaravanSchedule({required this.minuteOfDay, required this.weekdays});

  int get hour => minuteOfDay ~/ 60;
  int get minute => minuteOfDay % 60;

  /// The departure on the calendar day of [date], in local wall-clock time.
  /// Built from the date's fields so it stays at 9:00 across a daylight
  /// saving change rather than drifting with a fixed offset.
  DateTime departureOn(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  bool runsOn(DateTime date) => weekdays.contains(date.weekday);

  Map<String, dynamic> toJson() => {
        'minuteOfDay': minuteOfDay,
        'weekdays': (weekdays.toList()..sort()),
      };

  static CaravanSchedule? fromJson(Object? j) {
    if (j is! Map) return null;
    final minute = j['minuteOfDay'];
    final days = (j['weekdays'] as List?)?.whereType<int>().toSet() ?? {};
    if (minute is! int || minute < 0 || minute >= 24 * 60) return null;
    days.removeWhere((d) => d < DateTime.monday || d > DateTime.sunday);
    if (days.isEmpty) return null;
    return CaravanSchedule(minuteOfDay: minute, weekdays: days);
  }
}

/// yyyy-mm-dd, in local time. Which departure a run went out with.
String caravanDayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';

enum CaravanPhase {
  /// At the gate. A squad sent now travels with it.
  atGate,

  /// Gone, but its tracks are fresh. A squad sent now can still follow it,
  /// for a share of the salvage that shrinks by the minute.
  fading,
}

/// One departure as it stands at a given moment.
class CaravanStatus {
  final CaravanPhase phase;
  final DateTime departure;

  /// 1.0 at the gate, falling to 0 as the tracks go cold.
  final double strength;

  const CaravanStatus({
    required this.phase,
    required this.departure,
    required this.strength,
  });

  String get day => caravanDayKey(departure);
  bool get caught => phase == CaravanPhase.atGate;

  /// Until departure while at the gate; until the tracks are gone after.
  Duration remaining(DateTime now) {
    final end = caught
        ? departure
        : departure.add(const Duration(minutes: kCaravanFadeMinutes));
    final r = end.difference(now);
    return r.isNegative ? Duration.zero : r;
  }
}

/// The departure a run started at [now] would go out with, if any.
///
/// [claimedDay] is the departure already met; each one can be met once. A
/// departure near midnight can open on the previous calendar day, so the
/// neighbouring days are checked too.
CaravanStatus? caravanStatus(
  CaravanSchedule? schedule,
  DateTime now, {
  String? claimedDay,
}) {
  if (schedule == null) return null;
  final today = DateTime(now.year, now.month, now.day);
  for (final offset in const [-1, 0, 1]) {
    final date = DateTime(today.year, today.month, today.day + offset);
    if (!schedule.runsOn(date)) continue;
    final departure = schedule.departureOn(date);
    if (caravanDayKey(departure) == claimedDay) continue;
    final gate =
        departure.subtract(const Duration(minutes: kCaravanGateMinutes));
    final cold = departure.add(const Duration(minutes: kCaravanFadeMinutes));
    if (now.isBefore(gate) || !now.isBefore(cold)) continue;
    if (!now.isAfter(departure)) {
      return CaravanStatus(
          phase: CaravanPhase.atGate, departure: departure, strength: 1);
    }
    final late = now.difference(departure).inSeconds / 60;
    return CaravanStatus(
      phase: CaravanPhase.fading,
      departure: departure,
      strength: (1 - late / kCaravanFadeMinutes).clamp(0.0, 1.0),
    );
  }
  return null;
}

/// The next departure strictly after [now], ignoring whether it has been
/// met. For "next caravan: Tue 9:00" on the schedule screen.
DateTime? nextCaravanDeparture(CaravanSchedule? schedule, DateTime now) {
  if (schedule == null) return null;
  for (var offset = 0; offset <= 7; offset++) {
    final date = DateTime(now.year, now.month, now.day + offset);
    if (!schedule.runsOn(date)) continue;
    final departure = schedule.departureOn(date);
    if (departure.isAfter(now)) return departure;
  }
  return null;
}

/// One local notification the caravan wants scheduled.
class CaravanNotice {
  final DateTime at;
  final String title;
  final String body;
  const CaravanNotice(
      {required this.at, required this.title, required this.body});
}

/// How many days ahead notices are armed. They are re-armed every time the
/// app is opened, so a player who stops opening it stops hearing from it
/// within the week - the caravan does not chase anyone.
const int kCaravanNoticeDays = 7;

/// Two per departure: one when the caravan reaches the gate, and one when it
/// leaves. Skipped for a departure already met, or one that would land
/// while a squad is out, so it never interrupts a run in progress.
List<CaravanNotice> caravanNotices({
  required CaravanSchedule? schedule,
  required DateTime now,
  String? claimedDay,
  DateTime? runStart,
  DateTime? runEnd,
  String? runDay,
}) {
  if (schedule == null) return const [];
  bool duringRun(DateTime t) =>
      runStart != null &&
      runEnd != null &&
      !t.isBefore(runStart) &&
      t.isBefore(runEnd);

  final out = <CaravanNotice>[];
  for (var offset = 0; offset <= kCaravanNoticeDays; offset++) {
    final date = DateTime(now.year, now.month, now.day + offset);
    if (!schedule.runsOn(date)) continue;
    final departure = schedule.departureOn(date);
    final day = caravanDayKey(departure);
    if (day == claimedDay || day == runDay) continue;
    final gate =
        departure.subtract(const Duration(minutes: kCaravanGateMinutes));
    if (gate.isAfter(now) && !duringRun(gate)) {
      out.add(CaravanNotice(
        at: gate,
        title: 'The caravan is at the gate',
        body: 'It leaves in $kCaravanGateMinutes minutes. '
            'Send a squad out with it.',
      ));
    }
    if (departure.isAfter(now) && !duringRun(departure)) {
      out.add(CaravanNotice(
        at: departure,
        title: 'You missed the caravan',
        body: 'There is still work to be done. Start a run now - '
            'its tracks are fresh.',
      ));
    }
  }
  return out;
}
