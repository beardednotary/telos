import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/models/models.dart';
import 'package:telos/screens/session_screen.dart';
import 'package:telos/services/expedition_engine.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';

/// The first five minutes: finds go on by themselves, and the timer
/// explains Integrity where the number is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GuildController> boot() async {
    final c = GuildController(Persistence());
    await c.boot();
    c.g.onboarded = true;
    addTearDown(c.dispose);
    return c;
  }

  /// A finished run for [squad] that is known to bring gear home.
  ActiveRun findingRun(GuildController c, List<String> squad) {
    for (var i = 0;; i++) {
      final run = ActiveRun(
        id: 'find-$i',
        sectorId: 'mosswood',
        intent: '',
        squad: squad,
        startedAt: DateTime.now().subtract(const Duration(minutes: 45)),
        plannedMinutes: 45,
      );
      final res = ExpeditionEngine.resolve(
          run: run, guild: c.g, now: run.endsAt, recalled: false);
      if (res.gear.isNotEmpty) return run;
    }
  }

  test('a find goes straight onto whoever brought it home', () async {
    final c = await boot();
    c.g.active = findingRun(c, ['a1']);
    final r = (await c.finishRun(recalled: false))!;
    final kael = c.g.memberById('a1')!;
    expect(kael.equipped, isNotEmpty);
    expect(r.loot, containsAll(kael.equipped));
    expect(c.wearerOf(kael.equipped.first), kael);
    expect(c.g.memberById('a2')!.equipped, isEmpty,
        reason: 'MIRA stayed at camp');
  });

  test('a full kit is never rearranged', () async {
    final c = await boot();
    c.g.vault.addAll([Gear('mine-1', 'scav_cord'), Gear('mine-2', 'mossglass')]);
    c.g.memberById('a1')!.equipped.addAll(['mine-1', 'mine-2']);
    c.g.active = findingRun(c, ['a1']);
    final r = (await c.finishRun(recalled: false))!;
    expect(c.g.memberById('a1')!.equipped, ['mine-1', 'mine-2']);
    for (final uid in r.loot) {
      expect(c.g.gearByUid(uid), isNotNull, reason: 'still banked in the vault');
      expect(c.wearerOf(uid), isNull);
    }
  });

  Future<void> mountSession(WidgetTester t, GuildController c) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(theme: T.theme(), home: const SessionScreen()),
    ));
    await t.pump();
  }

  testWidgets('the first runs explain Integrity on the timer', (t) async {
    final c = await boot();
    await c.startRun(
        sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
    await mountSession(t, c);
    expect(find.textContaining('Integrity drops'), findsOneWidget);
    await c.cancelRun();
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('after a few runs the timer trusts the player', (t) async {
    final c = await boot();
    for (var i = 0; i < kIntegrityHintRuns; i++) {
      c.g.active = findingRun(c, ['a1']);
      await c.finishRun(recalled: false);
      await c.dismissDebrief();
    }
    await c.startRun(
        sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
    await mountSession(t, c);
    expect(find.textContaining('Integrity drops'), findsNothing);
    expect(find.text('Lock your phone. They will be here when you return.'),
        findsOneWidget);
    await c.cancelRun();
    await t.pumpWidget(const SizedBox());
  });
}
