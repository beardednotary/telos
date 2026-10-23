import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/data/content.dart';
import 'package:telos/main.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/screens/debrief_screen.dart';
import 'package:telos/screens/dispatch_screen.dart';
import 'package:telos/screens/session_screen.dart';
import 'package:telos/screens/roster_screen.dart';
import 'package:telos/services/alerts.dart';
import 'package:telos/services/expedition_engine.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';

class _HeldAlerts extends NoopAlerts {
  Completer<bool>? permission;
  Completer<void>? cancellation;
  int permissionRequests = 0;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission == null ? false : await permission!.future;
  }

  @override
  Future<void> cancel() async {
    if (cancellation != null) await cancellation!.future;
  }
}

RunRecord _record(
        {List<String> loot = const [],
        String? survey,
        bool scraps = false,
        bool charter = false}) =>
    RunRecord(
      id: 'outcome',
      sectorId: charter ? 'spire' : 'blackstone',
      intent: 'Write the next chapter',
      squad: ['a1'],
      startedAt: DateTime(2026, 10, 11, 9),
      endedAt: DateTime(2026, 10, 11, 9, 25),
      plannedMinutes: 25,
      elapsedSeconds: scraps ? 45 : 1500,
      integrity: 1,
      recalled: scraps,
      scraps: scraps,
      credits: scraps ? 1 : 110,
      alloy: scraps ? 0 : 46,
      intel: scraps ? 0 : 5,
      loot: loot,
      xpGained: const {'a1': 80},
      levelUps: const [],
      guildXp: 63,
      guildLevelUps: 0,
      journal: const ['The west road is passable.'],
      priorSurvey: survey,
      completedSpire: charter,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GuildController> boot({Alerts? alerts}) async {
    final c = GuildController(Persistence(), alerts: alerts);
    await c.boot();
    c.g.onboarded = true;
    addTearDown(c.dispose);
    return c;
  }

  Future<void> mount(
    WidgetTester t,
    GuildController c,
    Widget screen, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(
        theme: T.theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    ));
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder target) async {
    // ListView builds only near the viewport. Discover distant sections by
    // scrolling rather than assuming every disclosure is mounted already.
    if (target.evaluate().isEmpty) {
      final scrollable = find.byType(Scrollable).first;
      t.state<ScrollableState>(scrollable).position.jumpTo(0);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(target, 180,
          scrollable: scrollable, maxScrolls: 50);
    }
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
  }

  test(
      'forecasts match full and recalled outcomes without touching saves or loot',
      () {
    final g = GuildState.fresh();
    g.level = 4;
    g.facilities[Facility.forge] = 2;
    g.vault.add(Gear('kit', 'mossglass'));
    g.roster.first.equipped.add('kit');
    final before = g.toJson();
    for (final sector in kSectors) {
      for (final minutes in [5, 25, 45, 90, 180]) {
        for (final watches in [0, 600]) {
          final start = DateTime(2026, 10, 11, 9);
          final run = ActiveRun(
            id: 'forecast-$minutes-$watches',
            sectorId: sector.id,
            intent: '',
            squad: g.roster.map((m) => m.id).toList(),
            startedAt: start,
            plannedMinutes: 180,
            watchSeconds: watches,
          );
          final end = start.add(Duration(minutes: minutes));
          final prediction = ExpeditionEngine.forecast(
            guild: g,
            sector: sector,
            members: g.roster,
            minutes: minutes.toDouble(),
            integrity: run.integrity(end),
          );
          final result = ExpeditionEngine.resolve(
              run: run, guild: g, now: end, recalled: minutes < 180);
          expect([
            prediction.credits,
            prediction.alloy,
            prediction.intel
          ], [
            result.record.credits,
            result.record.alloy,
            result.record.intel
          ]);
          if (minutes < sector.minMinutes) {
            expect(prediction.gearAttempts, 0);
            expect(result.record.loot, isEmpty);
          }
        }
      }
    }
    expect(g.toJson(), before);
  });

  test(
      '45-minute destination tradeoff preserves alloy, intel and attempt differences',
      () {
    final g = GuildState.fresh();
    final hollow = ExpeditionEngine.forecast(
        guild: g,
        sector: sectorById('blackstone'),
        members: g.roster,
        minutes: 45);
    final archive = ExpeditionEngine.forecast(
        guild: g, sector: sectorById('cinder'), members: g.roster, minutes: 45);
    expect(hollow.alloy, greaterThan(archive.alloy));
    expect(archive.intel, greaterThan(hollow.intel));
    expect(hollow.gearAttempts, 2);
    expect(archive.gearAttempts, 1);
  });

  test('overlapping starts wait for one permission request and one dispatch',
      () async {
    final alerts = _HeldAlerts()..permission = Completer<bool>();
    final c = await boot(alerts: alerts);
    final first = c.startRun(
        sectorId: 'mosswood', intent: 'first', squad: ['a1'], minutes: 25);
    final duplicate = c.startRun(
        sectorId: 'mosswood', intent: 'second', squad: ['a2'], minutes: 45);
    expect(alerts.permissionRequests, 1);
    alerts.permission!.complete(false);
    await Future.wait([first, duplicate]);
    expect(c.g.runCounter, 1);
    expect(c.active!.intent, 'first');
    expect(c.active!.plannedMinutes, 25);
  });

  test('overlapping finishes bank once and cannot be cancelled midway',
      () async {
    final alerts = _HeldAlerts();
    final c = await boot(alerts: alerts);
    await c.startRun(
        sectorId: 'mosswood', intent: 'One run', squad: ['a1'], minutes: 25);
    final run = c.active!;
    c.g.active = ActiveRun(
        id: run.id,
        sectorId: run.sectorId,
        intent: run.intent,
        squad: run.squad,
        startedAt: DateTime.now().subtract(const Duration(minutes: 25)),
        plannedMinutes: 25);
    alerts.cancellation = Completer<void>();
    final first = c.finishRun(recalled: false);
    final duplicate = c.finishRun(recalled: true);
    expect(await c.cancelRun(), isFalse);
    alerts.cancellation!.complete();
    final results = await Future.wait([first, duplicate]);
    expect(identical(results[0], results[1]), isTrue);
    final r = results[0]!;
    expect(c.g.log, hasLength(1));
    expect(c.g.credits, r.credits);
    expect(c.g.alloy, r.alloy);
    expect(c.g.surveyRead['mosswood'], 1);
    expect(c.g.vault.length, r.loot.length);
    expect(await c.finishRun(recalled: false), isNull);
  });

  testWidgets(
      'changing duration explains a replaced destination; custom duration and slots hold',
      (t) async {
    final c = await boot();
    c.g.unlockedSectors.addAll(['blackstone', 'cinder']);
    await mount(t, c, const DispatchScreen());
    await tap(t, find.byKey(const Key('duration-45')));
    await tap(t, find.text('Their destination'));
    await tap(t, find.byKey(const Key('sector-cinder')));
    await tap(t, find.text('Your focus'));
    await tap(t, find.byKey(const Key('duration-25')));
    expect(find.textContaining('Destination changed to Blackstone Hollow'),
        findsOneWidget);
    await tap(t, find.text('The squad'));
    await tap(t, find.byKey(const Key('member-a1')));
    await tap(t, find.byKey(const Key('member-a2')));
    expect(find.text('MIRA · 1/1'), findsOneWidget);
    expect(find.byKey(const Key('focus-intent')), findsNothing);
    await tap(t, find.text('Your focus'));
    await tap(t, find.byKey(const Key('custom-duration')));
    await t.drag(find.byType(Slider), const Offset(800, 0));
    await t.pumpAndSettle();
    await tap(t, find.byKey(const Key('confirm-duration')));
    expect(find.text('Deploy · 180 minutes'), findsOneWidget);
    expect(c.g.log, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'small-screen planning and an hours-long timer tolerate larger text',
      (t) async {
    final c = await boot();
    c.g.roster.first.name = 'A very long adventurer name';
    await mount(t, c, const DispatchScreen(),
        size: const Size(320, 640), scale: 1.6);
    await tap(t, find.text('The squad'));
    await tap(t, find.byKey(const Key('member-a1')));
    expect(find.byKey(const Key('deploy')).hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
    await c.startRun(
        sectorId: 'mosswood',
        intent: 'A longer intention to check text wrapping on a small phone',
        squad: ['a1'],
        minutes: 180);
    await mount(t, c, const Root(), size: const Size(320, 640), scale: 1.6);
    expect(find.byType(SessionScreen), findsOneWidget);
    expect(find.byType(DispatchScreen), findsNothing);
    expect(find.byKey(const Key('focus-clock')), findsOneWidget);
    await tap(t, find.byKey(const Key('cancel-dispatch')));
    expect(c.g.log, isEmpty);
    expect(find.byKey(const Key('camp-dispatch')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('recall explains scraps and resolves the live session',
      (t) async {
    final c = await boot();
    c.g.active = ActiveRun(
        id: 'early',
        sectorId: 'blackstone',
        intent: '',
        squad: ['a1'],
        startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        plannedMinutes: 25);
    c.now = DateTime.now();
    await mount(t, c, const Root());
    expect(find.byKey(const Key('cancel-dispatch')), findsNothing);
    await tap(t, find.byKey(const Key('recall-squad')));
    expect(find.textContaining('credits only, with no alloy, intel, or gear'),
        findsOneWidget);
    await tap(t, find.text('Keep going'));
    expect(c.hasActiveRun, isTrue);
    await tap(t, find.byKey(const Key('recall-squad')));
    await tap(t, find.byKey(const Key('confirm-recall')));
    expect(c.pendingDebrief!.scraps, isTrue);
    expect(find.byType(DebriefScreen), findsOneWidget);
  });

  testWidgets('an external dispatch closes equipment and preparation routes',
      (t) async {
    final c = await boot();
    await mount(t, c, const Root());
    await tap(t, find.byKey(const Key('camp-dispatch')));
    await tap(t, find.text('The squad'));
    await tap(t, find.text('Review equipment'));
    expect(find.byType(RosterScreen), findsOneWidget);
    // This is the same state transition used by the platform launch actions.
    await c.startRun(
        sectorId: 'mosswood',
        intent: 'Start from a Shortcut',
        squad: ['a1'],
        minutes: 25);
    await t.pumpAndSettle();
    expect(find.byType(SessionScreen), findsOneWidget);
    expect(find.byType(RosterScreen), findsNothing);
    expect(find.byType(DispatchScreen), findsNothing);
    expect(
        Navigator.of(t.element(find.byType(SessionScreen))).canPop(), isFalse);
    await c.cancelRun();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('camp-dispatch')), findsOneWidget);
    expect(find.byType(RosterScreen), findsNothing);
  });

  testWidgets(
      'a completed 25-minute run and its repeat bank through the native loop',
      (t) async {
    final c = await boot();
    await c.startRun(
        sectorId: 'mosswood',
        intent: 'Finish the outline',
        squad: ['a2'],
        minutes: 25);
    void elapse() {
      final run = c.active!;
      c.now = DateTime.now();
      c.g.active = ActiveRun(
          id: run.id,
          sectorId: run.sectorId,
          intent: run.intent,
          squad: run.squad,
          startedAt: c.now.subtract(const Duration(minutes: 25)),
          plannedMinutes: 25);
    }

    elapse();
    await mount(t, c, const Root());
    await tap(t, find.byKey(const Key('receive-debrief')));
    final first = c.g.log.single;
    expect(first.recalled, isFalse);
    expect(first.elapsedMinutes, 25);
    await tap(t, find.byKey(const Key('return-to-camp')));
    await tap(t, find.byKey(const Key('camp-repeat')));
    expect(c.active!.intent, 'Finish the outline');
    expect(c.active!.plannedMinutes, 25);
    elapse();
    final second = (await c.finishRun(recalled: false))!;
    await t.pumpAndSettle();
    await tap(t, find.byKey(const Key('return-to-camp')));
    expect(c.g.log, hasLength(2));
    expect(c.g.credits, first.credits + second.credits);
    expect(c.g.alloy, first.alloy + second.alloy);
    expect(c.g.intel, first.intel + second.intel);
    expect(c.g.totalFocusMinutes, 50);
    expect(c.pendingDebrief, isNull);
    expect(find.byKey(const Key('camp-dispatch')), findsOneWidget);
  });

  for (final (label, loot, survey, scraps, charter, headline) in [
    ('common', ['common'], null, false, false, 'COMMON FIND'),
    ('rare', ['rare'], null, false, false, 'RARE FIND'),
    ('empty', <String>[], null, false, false, 'Nothing worth carrying back this time.'),
    ('scraps', <String>[], null, true, false, 'Back with scraps.'),
    (
      'survey',
      <String>[],
      'A record of an earlier company.',
      false,
      false,
      'LEFT BY THE FIRST COMPANY'
    ),
    (
      'charter',
      <String>[],
      'The last record.',
      false,
      true,
      'THE LAST CHARTER'
    ),
  ]) {
    testWidgets('return presents $label honestly and preserves the report',
        (t) async {
      final c = await boot();
      c.g.vault
          .addAll([Gear('common', 'scav_cord'), Gear('rare', 'deep_lamp')]);
      final r =
          _record(loot: loot, survey: survey, scraps: scraps, charter: charter);
      c.g.pendingDebrief = r;
      c.g.log.add(r);
      c.g.spireCharterName = 'The Original Watch';
      await mount(t, c, const Root(), size: const Size(320, 640), scale: 1.3);
      expect(find.text(headline), findsOneWidget);
      expect(find.text('Field journal'), findsNothing);
      await tap(t, find.text('Expedition report'));
      expect(find.text('The west road is passable.'), findsOneWidget);
      expect(find.text('Share expedition'), findsOneWidget);
      final wallet = [c.g.credits, c.g.alloy, c.g.intel];
      await tap(t, find.byKey(const Key('return-to-camp')));
      expect(c.pendingDebrief, isNull);
      expect([c.g.credits, c.g.alloy, c.g.intel], wallet);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
      'a reopened report keeps reflection and saves edits without changing rewards',
      (t) async {
    final c = await boot();
    final r = _record()
      ..progress = 'SOME'
      ..note = 'Saved before restart';
    c.g.pendingDebrief = r;
    c.g.log.add(r);
    await mount(t, c, const Root());
    await tap(t, find.text('Your focus'));
    final chip = t.widget<ChoiceChip>(find.byKey(const Key('progress-SOME')));
    expect(chip.selected, isTrue);
    expect(find.text('Saved before restart'), findsOneWidget);
    await t.enterText(
        find.byKey(const Key('reflection-note')), 'Finished the outline');
    await t.pumpAndSettle();
    await tap(t, find.byKey(const Key('return-to-camp')));
    final saved = await Persistence().load();
    expect(saved.log.single.progress, 'SOME');
    expect(saved.log.single.note, 'Finished the outline');
    expect(saved.pendingDebrief, isNull);
    expect(saved.credits, 0);
  });
}
