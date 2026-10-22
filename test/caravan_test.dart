import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/data/content.dart';
import 'package:telos/models/caravan.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/screens/caravan_screen.dart';
import 'package:telos/screens/debrief_screen.dart';
import 'package:telos/screens/home_screen.dart';
import 'package:telos/services/alerts.dart';
import 'package:telos/services/expedition_engine.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';

const everyDay = {1, 2, 3, 4, 5, 6, 7};

CaravanSchedule at(int hour, int minute, [Set<int> days = everyDay]) =>
    CaravanSchedule(minuteOfDay: hour * 60 + minute, weekdays: days);

/// A schedule whose departure is [ahead] from now, today.
CaravanSchedule leavingIn(Duration ahead) {
  final t = DateTime.now().add(ahead);
  return at(t.hour, t.minute);
}

class CaravanAlerts extends NoopAlerts {
  final List<List<CaravanNotice>> armed = [];

  @override
  Future<void> scheduleCaravan(List<CaravanNotice> notices) async =>
      armed.add(notices);
}

ActiveRun run(String id, {double? caravan, int minutes = 25}) => ActiveRun(
      id: id,
      sectorId: 'mosswood',
      intent: '',
      squad: const ['a1'],
      startedAt: DateTime(2026, 3, 2, 9),
      plannedMinutes: minutes,
      caravan: caravan,
      caravanDay: caravan == null ? null : '2026-03-02',
    );

void main() {
  // 2026-03-02 is a Monday.
  final monday = DateTime(2026, 3, 2);

  group('the departure window', () {
    final s = at(9, 0);

    test('closed until the caravan reaches the gate', () {
      expect(caravanStatus(s, DateTime(2026, 3, 2, 8, 44)), isNull);
    });

    test('at the gate from fifteen minutes before, through departure', () {
      for (final t in [
        DateTime(2026, 3, 2, 8, 45),
        DateTime(2026, 3, 2, 8, 59),
        DateTime(2026, 3, 2, 9, 0),
      ]) {
        final status = caravanStatus(s, t)!;
        expect(status.phase, CaravanPhase.atGate, reason: '$t');
        expect(status.strength, 1.0);
        expect(status.day, '2026-03-02');
      }
    });

    test('late, what is in reach fades to nothing over the hour', () {
      final half = caravanStatus(s, DateTime(2026, 3, 2, 9, 30))!;
      expect(half.phase, CaravanPhase.fading);
      expect(half.strength, closeTo(0.5, 1e-9));
      expect(caravanStatus(s, DateTime(2026, 3, 2, 9, 54))!.strength,
          closeTo(0.1, 1e-9));
      expect(caravanStatus(s, DateTime(2026, 3, 2, 10, 0)), isNull);
    });

    test('a departure already met is gone for the day, not the next', () {
      expect(
          caravanStatus(s, DateTime(2026, 3, 2, 8, 50),
              claimedDay: '2026-03-02'),
          isNull);
      expect(
          caravanStatus(s, DateTime(2026, 3, 3, 8, 50),
              claimedDay: '2026-03-02'),
          isNotNull,
          reason: 'missing or meeting one day must not touch the next');
    });

    test('only on the chosen days', () {
      final weekdays = at(9, 0, {1, 2, 3, 4, 5});
      expect(caravanStatus(weekdays, DateTime(2026, 3, 6, 8, 55)), isNotNull);
      expect(caravanStatus(weekdays, DateTime(2026, 3, 7, 8, 55)), isNull,
          reason: 'Saturday');
    });

    test('a departure just after midnight opens the evening before', () {
      final status = caravanStatus(at(0, 5), DateTime(2026, 3, 2, 23, 55))!;
      expect(status.phase, CaravanPhase.atGate);
      expect(status.day, '2026-03-03');
    });

    test('nothing without a schedule', () {
      expect(caravanStatus(null, monday), isNull);
      expect(caravanNotices(schedule: null, now: monday), isEmpty);
    });
  });

  group('notices', () {
    final s = at(9, 0, {1});

    test('one at the gate and one at departure, for a week ahead', () {
      final notices = caravanNotices(schedule: s, now: monday);
      // This Monday and next.
      expect(notices.map((n) => n.at), [
        DateTime(2026, 3, 2, 8, 45),
        DateTime(2026, 3, 2, 9),
        DateTime(2026, 3, 9, 8, 45),
        DateTime(2026, 3, 9, 9),
      ]);
      expect(notices[1].title, 'You missed the caravan');
      expect(notices[1].body, contains('still work to be done'));
    });

    test('never for a departure already met or with a squad already out', () {
      expect(
          caravanNotices(schedule: s, now: monday, claimedDay: '2026-03-02')
              .first
              .at,
          DateTime(2026, 3, 9, 8, 45));
      expect(
          caravanNotices(schedule: s, now: monday, runDay: '2026-03-02')
              .first
              .at,
          DateTime(2026, 3, 9, 8, 45));
    });

    test('never while a squad is out, so a run is not interrupted', () {
      final notices = caravanNotices(
        schedule: s,
        now: monday,
        runStart: DateTime(2026, 3, 2, 8, 30),
        runEnd: DateTime(2026, 3, 2, 8, 55),
      );
      expect(notices.first.at, DateTime(2026, 3, 2, 9),
          reason: 'the gate notice lands mid-run; the departure does not');
    });

    test('nothing in the past', () {
      final notices =
          caravanNotices(schedule: s, now: DateTime(2026, 3, 2, 8, 50));
      expect(notices.first.at, DateTime(2026, 3, 2, 9));
    });
  });

  group('schedule save', () {
    test('round trips', () {
      final s = CaravanSchedule.fromJson(at(7, 30, {1, 3, 5}).toJson())!;
      expect(s.minuteOfDay, 450);
      expect(s.weekdays, {1, 3, 5});
    });

    test('a damaged schedule reads as none, not as a crash', () {
      expect(CaravanSchedule.fromJson(null), isNull);
      expect(CaravanSchedule.fromJson({'minuteOfDay': 9999, 'weekdays': [1]}),
          isNull);
      expect(CaravanSchedule.fromJson({'minuteOfDay': 60, 'weekdays': []}),
          isNull);
    });

    test('an old save has no caravan and loses nothing', () {
      final g = GuildState.fromJson(GuildState.fresh().toJson()
        ..remove('caravan')
        ..remove('caravanClaimed')
        ..remove('caravanRead'));
      expect(g.caravan, isNull);
      expect(g.caravanRead, 0);
    });
  });

  group('rewards', () {
    Resolution resolve(ActiveRun r, {bool recalled = false, GuildState? g}) =>
        ExpeditionEngine.resolve(
          run: r,
          guild: g ?? GuildState.fresh(),
          now: r.endsAt,
          recalled: recalled,
        );

    test('caravan salvage exists nowhere else', () {
      for (final id in kCaravanGear) {
        expect(kGear.containsKey(id), isTrue);
        for (final s in kSectors) {
          expect(s.lootPool, isNot(contains(id)), reason: s.id);
        }
      }
      final g = GuildState.fresh()
        ..unlockedSectors = kSectors.map((s) => s.id).toSet();
      expect(craftableGear(g).map((d) => d.id),
          isNot(contains(anyOf(kCaravanGear))));
    });

    test('the caravan never changes the ordinary haul', () {
      for (var i = 0; i < 40; i++) {
        final alone = resolve(run('r$i')).record;
        final escorted = resolve(run('r$i', caravan: 1)).record;
        expect(escorted.credits, alone.credits);
        expect(
            escorted.loot.where((u) => !escorted.caravanLoot.contains(u)),
            alone.loot);
      }
    });

    test('met at the gate: a manifest line, and often a find', () {
      var finds = 0;
      for (var i = 0; i < 200; i++) {
        final res = resolve(run('r$i', caravan: 1));
        final r = res.record;
        expect(r.caravan, 1);
        expect(r.caravanLine, kCaravanManifest.first);
        expect(r.caravanLoot.length, lessThanOrEqualTo(1));
        for (final uid in r.caravanLoot) {
          expect(r.loot, contains(uid));
          final gear = res.gear.singleWhere((g) => g.uid == uid);
          expect(kCaravanGear, contains(gear.defId));
          finds++;
        }
        // Unique uids, so banking can never collide with ordinary loot.
        expect(r.loot.toSet().length, r.loot.length);
      }
      expect(finds, inInclusiveRange(90, 150), reason: 'about 60% of 200');
    });

    test('late, the tracks give less, and no line', () {
      var finds = 0;
      for (var i = 0; i < 200; i++) {
        final r = resolve(run('r$i', caravan: 0.25)).record;
        expect(r.caravanLine, isNull);
        finds += r.caravanLoot.length;
      }
      expect(finds, inInclusiveRange(10, 50), reason: 'about 15% of 200');
    });

    test('the manifest is read in order and runs out quietly', () {
      final g = GuildState.fresh()..caravanRead = 3;
      expect(resolve(run('x', caravan: 1), g: g).record.caravanLine,
          kCaravanManifest[3]);
      g.caravanRead = kCaravanManifest.length;
      expect(resolve(run('x', caravan: 1), g: g).record.caravanLine, isNull);
    });

    test('a recall turns back from the caravan too', () {
      for (var i = 0; i < 50; i++) {
        final r = resolve(run('r$i', caravan: 1), recalled: true).record;
        expect(r.caravanLoot, isEmpty);
        expect(r.caravanLine, isNull);
        expect(r.caravan, 1, reason: 'the debrief still says what happened');
      }
    });

    test('a record keeps its caravan through the log', () {
      final r = resolve(run('r1', caravan: 0.5)).record;
      final back = RunRecord.fromJson(r.toJson());
      expect(back.caravan, 0.5);
      expect(back.caravanLoot, r.caravanLoot);
    });
  });

  group('controller', () {
    late CaravanAlerts alerts;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      alerts = CaravanAlerts();
    });

    Future<GuildController> boot() async {
      final c = GuildController(Persistence(), alerts: alerts);
      await c.boot();
      c.g.onboarded = true;
      addTearDown(c.dispose);
      return c;
    }

    test('silent until the player schedules it', () async {
      await boot();
      expect(alerts.armed.every((n) => n.isEmpty), isTrue);
    });

    test('a run at the gate leaves with the caravan, once', () async {
      final c = await boot();
      await c.setCaravan(leavingIn(const Duration(minutes: 5)));
      expect(alerts.armed.last, isNotEmpty);
      expect(c.caravanAt(DateTime.now())!.caught, isTrue);

      await c.startRun(
          sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
      expect(c.active!.caravan, 1.0);
      expect(c.caravanAt(DateTime.now()), isNull,
          reason: 'the squad already out has it');
      final today = caravanDayKey(DateTime.now());
      expect(alerts.armed.last.map((n) => caravanDayKey(n.at)),
          isNot(contains(today)));

      final r = (await c.finishRun(recalled: false))!;
      expect(r.caravanLine, kCaravanManifest.first);
      expect(c.g.caravanRead, 1);
      expect(c.g.caravanClaimed, today);
      expect(c.g.caravansMet, 1);

      // A second run inside the same window goes alone.
      await c.dismissDebrief();
      await c.startRun(
          sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
      expect(c.active!.caravan, isNull);
    });

    test('a cancelled dispatch leaves the departure to be met', () async {
      final c = await boot();
      await c.setCaravan(leavingIn(const Duration(minutes: 5)));
      await c.startRun(
          sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
      expect(await c.cancelRun(), isTrue);
      expect(c.g.caravanClaimed, isNull);
      expect(c.caravanAt(DateTime.now()), isNotNull);
    });

    test('stopping the caravan clears its notices', () async {
      final c = await boot();
      await c.setCaravan(leavingIn(const Duration(hours: 2)));
      expect(alerts.armed.last, isNotEmpty);
      await c.setCaravan(null);
      expect(alerts.armed.last, isEmpty);
      expect(c.g.caravan, isNull);
    });
  });

  group('camp', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<GuildController> mount(WidgetTester t, Widget screen) async {
      final c = GuildController(Persistence());
      await c.boot();
      c.g.onboarded = true;
      addTearDown(c.dispose);
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(theme: T.theme(), home: screen),
      ));
      await t.pumpAndSettle();
      return c;
    }

    testWidgets('camp shows nothing of the caravan until it is scheduled',
        (t) async {
      await mount(t, const HomeScreen());
      expect(find.byKey(const Key('caravan-card')), findsNothing);
    });

    testWidgets('at the gate, camp says so and how long is left', (t) async {
      final c = await mount(t, const HomeScreen());
      await c.setCaravan(leavingIn(const Duration(minutes: 10)));
      await t.pumpAndSettle();
      expect(find.text('THE CARAVAN IS AT THE GATE'), findsOneWidget);
      expect(find.textContaining('Leaves in'), findsOneWidget);
    });

    testWidgets('late, camp says there is still work to be done', (t) async {
      final c = await mount(t, const HomeScreen());
      await c.setCaravan(leavingIn(const Duration(minutes: -20)));
      await t.pumpAndSettle();
      expect(find.text('THE CARAVAN HAS LEFT'), findsOneWidget);
      expect(find.textContaining('still work to be done'), findsOneWidget);
      expect(find.textContaining('of its salvage still in reach'),
          findsOneWidget);
    });

    testWidgets('scheduling from the caravan screen', (t) async {
      final c = await mount(t, const CaravanScreen());
      expect(find.text('Schedule the caravan'), findsOneWidget);
      await t.tap(find.byKey(const Key('caravan-day-6')));
      await t.pump();
      await t.tap(find.byKey(const Key('caravan-save')));
      await t.pumpAndSettle();
      expect(c.g.caravan!.minuteOfDay, 9 * 60);
      expect(c.g.caravan!.weekdays, {1, 2, 3, 4, 5, 6});
    });

    testWidgets('the debrief tells the caravan part of the run', (t) async {
      SharedPreferences.setMockInitialValues({});
      final c = GuildController(Persistence());
      await c.boot();
      addTearDown(c.dispose);
      // Find a run id where the caravan hands something over.
      late Resolution res;
      for (var i = 0;; i++) {
        res = ExpeditionEngine.resolve(
            run: run('d$i', caravan: 1),
            guild: c.g,
            now: run('d$i').endsAt,
            recalled: false);
        if (res.record.caravanLoot.isNotEmpty) break;
      }
      c.g.vault.addAll(res.gear);
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(
            theme: T.theme(), home: DebriefScreen(record: res.record)),
      ));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
          find.byKey(const Key('debrief-caravan')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('WITH THE CARAVAN'), findsOneWidget);
      expect(find.text(kCaravanManifest.first), findsOneWidget);
      expect(find.textContaining('The caravan handed over'), findsOneWidget);
    });

    test('day labels read naturally', () {
      expect(caravanDaysLabel({1, 2, 3, 4, 5}), 'Weekdays');
      expect(caravanDaysLabel(everyDay), 'Every day');
      expect(caravanDaysLabel({6, 7}), 'Weekends');
      expect(caravanDaysLabel({5, 1, 3}), 'Mon, Wed, Fri');
    });
  });
}
