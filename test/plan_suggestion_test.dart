import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/data/content.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/screens/dispatch_screen.dart';
import 'package:telos/screens/roster_screen.dart';
import 'package:telos/services/expedition_engine.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/services/plan_suggestion.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';

GuildState veteran() => GuildState.fresh()
  ..level = 6 // three squad slots
  ..unlockedSectors = {'mosswood', 'blackstone', 'cinder'}
  ..roster.addAll([
    Adventurer(id: 'a3', name: 'VESS', classId: 'archivist'),
    Adventurer(id: 'a4', name: 'ODRIN', classId: 'artificer'),
  ]);

/// The project progress camp would show after [s]'s forecast.
double progressAfter(GuildState g, PlanSuggestion s) {
  final (c, a) = g.campProject.costAt(g.facilities[g.campProject]!);
  return min((g.credits + s.forecast.credits) / c,
          (g.alloy + s.forecast.alloy) / a)
      .clamp(0.0, 1.0);
}

void main() {
  test('only suggests what the time can reach', () {
    final g = veteran();
    for (final minutes in [10, 15, 25, 40, 60]) {
      final s = suggestPlan(g, minutes)!;
      expect(s.sector.minMinutes, lessThanOrEqualTo(minutes));
      expect(g.sectorUnlocked(s.sector.id), isTrue);
      expect(s.squad.length, inInclusiveRange(1, g.squadSlots));
      expect(s.squad.toSet().length, s.squad.length, reason: 'no doubles');
    }
    expect(suggestPlan(g, 5), isNull, reason: 'nothing needs under 10');
  });

  test('the promise matches the forecast the screen will show', () {
    final g = veteran();
    final s = suggestPlan(g, 45)!;
    final shown = ExpeditionEngine.forecast(
        guild: g, sector: s.sector, members: s.squad, minutes: 45);
    expect(shown.credits, s.forecast.credits);
    expect(shown.alloy, s.forecast.alloy);
  });

  test('no other plan gets the camp project further', () {
    final g = veteran()
      ..credits = 40
      ..alloy = 2;
    final best = suggestPlan(g, 45)!;
    final mine = progressAfter(g, best);
    final members = g.roster;
    for (final sector in kSectors
        .where((s) => g.sectorUnlocked(s.id) && s.minMinutes <= 45)) {
      for (final m in members) {
        final f = ExpeditionEngine.forecast(
            guild: g, sector: sector, members: [m], minutes: 45);
        final (c, a) = g.campProject.costAt(g.facilities[g.campProject]!);
        final p = min((g.credits + f.credits) / c, (g.alloy + f.alloy) / a)
            .clamp(0.0, 1.0);
        expect(p, lessThanOrEqualTo(mine + 1e-9),
            reason: '${sector.id} with ${m.name}');
      }
    }
    expect(best.reason, contains('Forge'));
  });

  test('an affordable project says so, and goes for the richest haul', () {
    final g = veteran()
      ..credits = 100000
      ..alloy = 100000;
    expect(suggestPlan(g, 25)!.reason, contains('already afford'));
  });

  testWidgets('one tap fills in the plan and says why', (t) async {
    SharedPreferences.setMockInitialValues({});
    final c = GuildController(Persistence());
    await c.boot();
    c.g.onboarded = true;
    c.g.level = 3; // two slots, so the suggestion has a squad to choose
    addTearDown(c.dispose);
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(theme: T.theme(), home: const DispatchScreen()),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('suggest-plan')));
    await t.pumpAndSettle();
    expect(find.textContaining('Mosswood Verge with'), findsOneWidget);
    expect(find.textContaining('Forge upgrade'), findsOneWidget);
    expect(find.text('Deploy · 25 minutes'), findsOneWidget);
    expect(find.text('KAEL & MIRA · 2/2'), findsOneWidget,
        reason: 'a bigger squad carries more home');
  });

  group('the plan sentence goes once the plan it describes is changed', () {
    /// The list builds lazily, so a line scrolled out of view is simply not
    /// there to find. Bring the spot where the notice sits back first.
    Future<bool> planShown(WidgetTester t) async {
      await Scrollable.ensureVisible(
          t.element(find.byKey(const Key('squad-step'))),
          alignment: 0.5);
      await t.pumpAndSettle();
      return find.textContaining('Mosswood Verge with').evaluate().isNotEmpty;
    }

    Future<GuildController> suggested(WidgetTester t) async {
      SharedPreferences.setMockInitialValues({});
      final c = GuildController(Persistence());
      await c.boot();
      c.g.onboarded = true;
      c.g.level = 3;
      addTearDown(c.dispose);
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(theme: T.theme(), home: const DispatchScreen()),
      ));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('suggest-plan')));
      await t.pumpAndSettle();
      expect(find.textContaining('Mosswood Verge with'), findsOneWidget);
      await t.ensureVisible(find.text('The squad'));
      await t.tap(find.text('The squad'));
      await t.pumpAndSettle();
      expect(await planShown(t), isTrue);
      return c;
    }

    // The audit's case: the sentence named KAEL and MIRA while only MIRA
    // was selected.
    testWidgets('by taking someone out of the squad', (t) async {
      await suggested(t);
      await t.ensureVisible(find.byKey(const Key('member-a1')));
      await t.tap(find.byKey(const Key('member-a1')));
      await t.pumpAndSettle();
      expect(await planShown(t), isFalse);
      expect(find.byKey(const Key('dispatch-notice')), findsNothing);
    });

    testWidgets('by going to change equipment', (t) async {
      await suggested(t);
      // Centred, so the deploy bar along the bottom cannot take the tap.
      await Scrollable.ensureVisible(t.element(find.text('Review equipment')),
          alignment: 0.5);
      await t.pumpAndSettle();
      await t.tap(find.text('Review equipment'));
      await t.pumpAndSettle();
      expect(find.byType(RosterScreen), findsOneWidget);
      t.state<NavigatorState>(find.byType(Navigator)).pop();
      await t.pumpAndSettle();
      expect(find.byType(DispatchScreen), findsOneWidget);
      expect(await planShown(t), isFalse);
    });
  });
}
