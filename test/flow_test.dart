import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/main.dart';
import 'package:telos/screens/log_screen.dart';
import 'package:telos/screens/outpost_screen.dart';
import 'package:telos/screens/roster_screen.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';

Future<GuildController> bootController() async {
  SharedPreferences.setMockInitialValues({});
  final c = GuildController(Persistence());
  await c.boot();
  return c;
}

/// Widget tests default to an 800x600 surface; these screens are tall lists,
/// and a ListView does not build children that are off-screen. Give them room.
void tallSurface(WidgetTester t) {
  t.view.physicalSize = const Size(900, 4200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Widget wrap(GuildController c, Widget child) => ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(theme: T.theme(), home: child),
    );

void main() {
  testWidgets('full loop: home -> dispatch -> session -> debrief', (t) async {
    tallSurface(t);
    final c = await bootController();
    // Open a second sector so the length gate is visible next to the lock gate.
    c.g.unlockedSectors.add('blackstone');
    await t.pumpWidget(wrap(c, const Root()));
    await t.pumpAndSettle();

    // Home
    expect(find.text('THE SILVER LANTERN'), findsOneWidget);
    expect(find.text('DISPATCH'), findsOneWidget);

    await t.tap(find.text('DISPATCH'));
    await t.pumpAndSettle();

    // Dispatch: nothing selected yet, so the action is blocked.
    expect(find.text('01 / INTENT'), findsOneWidget);
    expect(find.text('[ SELECT A SQUAD ]'), findsOneWidget);

    await t.enterText(find.byType(TextField).first, 'Refactor the auth flow');
    await t.tap(find.text('15 MIN'));
    await t.pumpAndSettle();

    // 15 minutes only reaches Mosswood. Blackstone is open but too deep for
    // this block of time; the Cinder Archive is not open at all.
    expect(find.text('MOSSWOOD VERGE'), findsOneWidget);
    expect(find.text('NEEDS 25+ MIN'), findsOneWidget);
    expect(find.text('LOCKED - 320 INTEL, GUILD LV 3'), findsOneWidget);

    await t.tap(find.text('KAEL'));
    await t.pumpAndSettle();
    expect(find.text('[ BEGIN EXPEDITION ]'), findsOneWidget);

    await t.tap(find.text('[ BEGIN EXPEDITION ]'));
    await t.pump(); // startRun
    await t.pump(const Duration(milliseconds: 500)); // pop transition

    // Session
    expect(find.text('MOSSWOOD VERGE'), findsOneWidget);
    expect(find.text('KAEL'), findsOneWidget);
    expect(find.text('INTEGRITY'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('RECALL SQUAD'), findsOneWidget);
    expect(find.text('Refactor the auth flow'), findsOneWidget);

    // Recalling resolves the run and hands back a debrief.
    final record = await c.finishRun(recalled: true);
    expect(record, isNotNull);
    expect(c.hasActiveRun, isFalse);
    await t.pump();
    await t.pumpAndSettle();

    expect(find.text('DEBRIEF'), findsOneWidget);
    expect(find.text('FIELD JOURNAL'), findsOneWidget);
    expect(find.text('RECOVERED'), findsOneWidget);
    expect(find.text('DID YOU MAKE PROGRESS?'), findsOneWidget);

    // Honour-system answer is recorded against the log entry.
    await t.tap(find.text('SOME'));
    await t.pumpAndSettle();
    expect(c.g.log.first.progress, 'SOME');

    await t.tap(find.text('[ RETURN TO OUTPOST ]'));
    await t.pumpAndSettle();
    expect(find.text('DISPATCH'), findsOneWidget);
    expect(c.g.log.length, 1);

    c.dispose();
  });

  testWidgets('a live run is restored on cold start', (t) async {
    final c = await bootController();
    await c.startRun(
      sectorId: 'mosswood',
      intent: 'still going',
      squad: ['a1'],
      minutes: 45,
    );

    // Simulate relaunching the app against the same save.
    final c2 = GuildController(Persistence());
    await c2.boot();
    expect(c2.hasActiveRun, isTrue);
    expect(c2.active!.intent, 'still going');

    await t.pumpWidget(wrap(c2, const Root()));
    await t.pump();
    expect(find.text('still going'), findsOneWidget);

    c.dispose();
    c2.dispose();
  });

  testWidgets('roster, outpost and log screens render', (t) async {
    tallSurface(t);
    final c = await bootController();

    await t.pumpWidget(wrap(c, const RosterScreen()));
    await t.pumpAndSettle();
    expect(find.text('ROSTER'), findsOneWidget);
    expect(find.text('KAEL'), findsOneWidget);
    expect(find.text('MIRA'), findsOneWidget);
    expect(find.text('EMPTY SLOT'), findsNWidgets(4)); // 2 members x 2 slots

    await t.pumpWidget(wrap(c, const OutpostScreen()));
    await t.pumpAndSettle();
    expect(find.text('BARRACKS'), findsOneWidget);
    expect(find.text('SECTOR ACCESS'), findsOneWidget);

    await t.pumpWidget(wrap(c, const LogScreen()));
    await t.pumpAndSettle();
    expect(find.text('FIELD LOG'), findsOneWidget);
    expect(find.text('No expeditions logged yet.'), findsOneWidget);

    c.dispose();
  });

  testWidgets('spending gates hold: cannot upgrade or recruit while broke',
      (t) async {
    tallSurface(t);
    final c = await bootController();
    await t.pumpWidget(wrap(c, const OutpostScreen()));
    await t.pumpAndSettle();

    final before = c.g.facilities.values.toList();
    await t.tap(find.text('UPGRADE').first);
    await t.pumpAndSettle();
    expect(c.g.facilities.values.toList(), before);
    expect(c.g.credits, 0);

    c.dispose();
  });
}
