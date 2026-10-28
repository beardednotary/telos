import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';

import 'support/archive_fixtures.dart';

/// [count] runs, newest first as the log keeps them, two to a day, every
/// third one recalled so the totals have something to tell apart.
List<RunRecord> _history(int count) => [
      for (var i = count - 1; i >= 0; i--)
        archiveRecord(
          id: 'r$i',
          recalled: i % 3 == 0,
          startedAt: DateTime(2025, 1, 1, 9).add(Duration(hours: 12 * i)),
        ),
    ];

typedef _Totals = (int, int, int, int, int, String, DateTime?);

_Totals _totals(GuildState g) => (
      g.totalFocusMinutes,
      g.expeditions,
      g.cleanRuns,
      g.caravansMet,
      g.daysWorked,
      g.averageIntegrity.toStringAsFixed(9),
      g.firstRunAt,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('trimming the log changes none of the totals', () {
    final g = GuildState.fresh()..log = _history(GuildState.kLogLimit + 37);
    final before = _totals(g);

    g.trimLog();
    expect(g.log.length, GuildState.kLogLimit);
    expect(g.trimmed.runs, 37);
    expect(_totals(g), before);
  });

  test('a day the trimmed runs end on is not counted twice', () {
    final day = DateTime(2026, 3, 4, 9);
    final g = GuildState.fresh()
      ..log = [
        archiveRecord(id: 'next', startedAt: day.add(const Duration(days: 1))),
        archiveRecord(id: 'later', startedAt: day.add(const Duration(hours: 6))),
      ];
    g.trimmed.add(archiveRecord(id: 'first', startedAt: day));
    expect(g.daysWorked, 2);
  });

  test('the tally survives a save and a backup round trip', () {
    final g = GuildState.fresh()..log = _history(GuildState.kLogLimit + 5);
    g.trimLog();
    final again = GuildState.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect(_totals(again), _totals(g));
  });

  test('a save from before the tally reads as nothing trimmed', () {
    final json = GuildState.fresh().toJson()..remove('trimmed');
    final g = GuildState.fromJson(json);
    expect(g.trimmed.runs, 0);
    expect(g.expeditions, 0);
  });

  test('a run past the history limit adds to earned Spire progress',
      () async {
    SharedPreferences.setMockInitialValues({});
    final c = GuildController(Persistence());
    addTearDown(c.dispose);
    await c.boot();
    c.g.log = List.generate(
        GuildState.kLogLimit, (i) => archiveRecord(id: 'r$i'));
    c.g.spireCompletedAt = DateTime(2026, 1, 1);
    c.g.spireCompletionMinutes = 11300;
    expect(c.g.totalFocusMinutes, 12500);
    expect(c.g.spireFloors, 1);

    c.g.active = ActiveRun(
        id: 'next',
        sectorId: 'mosswood',
        intent: '',
        squad: ['a1'],
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        plannedMinutes: 10);
    await c.finishRun(recalled: false);

    expect(c.g.log.length, GuildState.kLogLimit);
    expect(c.g.expeditions, GuildState.kLogLimit + 1);
    expect(c.g.totalFocusMinutes, 12510);
    expect(c.g.spireFloors, 1);
  });
}
