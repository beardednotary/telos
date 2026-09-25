import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/main.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/services/redeploy.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';

RunRecord rec({
  String sector = 'mosswood',
  int minutes = 25,
  List<String> squad = const ['a1'],
  String intent = '',
}) =>
    RunRecord(
      id: 'r',
      sectorId: sector,
      intent: intent,
      squad: squad,
      startedAt: DateTime(2026, 1, 1, 9),
      endedAt: DateTime(2026, 1, 1, 9).add(Duration(minutes: minutes)),
      plannedMinutes: minutes,
      elapsedSeconds: minutes * 60,
      integrity: 1,
      recalled: false,
      scraps: false,
      credits: 0,
      alloy: 0,
      intel: 0,
      loot: const [],
      xpGained: const {},
      levelUps: const [],
      guildXp: 0,
      guildLevelUps: 0,
      journal: const [],
    );

/// A guild with two squad slots and the first two sectors open.
GuildState guild(List<RunRecord> newestFirst) {
  final g = GuildState.fresh();
  g.level = 10;
  g.unlockedSectors.add('blackstone');
  g.log.addAll(newestFirst);
  return g;
}

void main() {
  group('recentDispatches', () {
    test('nothing sent yet, nothing to repeat', () {
      expect(recentDispatches(GuildState.fresh()), isEmpty);
    });

    test('newest first, distinct, at most three', () {
      final g = guild([
        rec(minutes: 25, intent: 'thesis'),
        rec(minutes: 25, intent: 'older thesis'), // same dispatch again
        rec(minutes: 45),
        rec(sector: 'blackstone', minutes: 60),
        rec(minutes: 15),
      ]);
      final d = recentDispatches(g);
      expect(d.map((x) => x.minutes), [25, 45, 60]);
      // The newest copy of a repeated dispatch is the one offered.
      expect(d.first.intent, 'thesis');
    });

    test('squad order does not make a different dispatch', () {
      final g = guild([
        rec(squad: ['a1', 'a2']),
        rec(squad: ['a2', 'a1']),
      ]);
      expect(recentDispatches(g), hasLength(1));
    });

    test('a sector deeper than the duration falls back to one it reaches', () {
      // Blackstone needs 25; a 15 minute block only reaches Mosswood.
      final g = guild([rec(sector: 'blackstone', minutes: 15)]);
      expect(recentDispatches(g).single.sectorId, 'mosswood');
    });

    test('a locked or removed sector falls back rather than failing', () {
      final g = guild([rec(sector: 'no-such-sector', minutes: 45)]);
      expect(recentDispatches(g).single.sectorId, 'blackstone');
    });

    test('a duration too short for anything is not offered', () {
      final g = guild([rec(minutes: 5)]);
      expect(recentDispatches(g), isEmpty);
    });

    test('missing members are dropped and the squad fits the slots', () {
      final g = guild([
        rec(squad: ['gone', 'a2', 'a1']),
      ]);
      expect(recentDispatches(g).single.squad, ['a2', 'a1']);

      final small = GuildState.fresh()..log.add(rec(squad: ['a2', 'a1']));
      expect(small.squadSlots, 1);
      expect(recentDispatches(small).single.squad, ['a2']);
    });

    test('a squad with nobody left falls back to the roster', () {
      final g = guild([
        rec(squad: ['gone'])
      ]);
      expect(recentDispatches(g).single.squad, ['a1']);
    });

    test('fitting can merge two dispatches into one', () {
      // Both become Mosswood at 15 once Blackstone is out of reach.
      final g = guild([
        rec(sector: 'blackstone', minutes: 15),
        rec(sector: 'mosswood', minutes: 15),
      ]);
      expect(recentDispatches(g), hasLength(1));
    });
  });

  group('redeploy', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('starts the run as it was sent', () async {
      final c = GuildController(Persistence());
      await c.boot();
      await c.redeploy(const Redeploy(
        sectorId: 'mosswood',
        squad: ['a1'],
        minutes: 25,
        intent: 'Refactor the auth flow',
      ));
      final run = c.g.active!;
      expect(run.sectorId, 'mosswood');
      expect(run.squad, ['a1']);
      expect(run.plannedMinutes, 25);
      expect(run.intent, 'Refactor the auth flow');
      await c.finishRun(recalled: true);
      c.dispose();
    });

    test('never starts a second run over a live one', () async {
      final c = GuildController(Persistence());
      await c.boot();
      const d = Redeploy(
          sectorId: 'mosswood', squad: ['a1'], minutes: 25, intent: '');
      await c.redeploy(d);
      final first = c.g.active!.id;
      await c.redeploy(const Redeploy(
          sectorId: 'mosswood', squad: ['a2'], minutes: 60, intent: ''));
      expect(c.g.active!.id, first);
      expect(c.g.active!.plannedMinutes, 25);
      await c.finishRun(recalled: true);
      c.dispose();
    });
  });

  testWidgets('one tap on home goes straight into the session', (t) async {
    SharedPreferences.setMockInitialValues({});
    final c = GuildController(Persistence());
    await c.boot();
    c.g.onboarded = true;
    c.g.log.add(rec(minutes: 25, intent: 'Write the methods chapter'));

    await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(theme: T.theme(), home: const Root()),
    ));
    await t.pump();

    expect(find.text('SEND AGAIN'), findsOneWidget);
    await t.tap(find.text('MOSSWOOD VERGE'));
    await t.pump();
    await t.pump();

    expect(c.hasActiveRun, isTrue);
    expect(find.text('RECALL SQUAD'), findsOneWidget);
    expect(find.text('Write the methods chapter'), findsOneWidget);

    await c.finishRun(recalled: true);
    c.dispose();
  });
}
