@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/models/models.dart';
import 'package:telos/screens/debrief_screen.dart';
import 'package:telos/screens/dispatch_screen.dart';
import 'package:telos/screens/session_screen.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';

/// Renders screens to PNG so the look can be checked without a device.
///
///   flutter test --update-goldens test/golden_test.dart
///
/// then open test/goldens/*.png. Run with `--exclude-tags golden` in CI if
/// these ever start failing on a different platform's font rasterisation -
/// they are a preview tool, not a regression gate.
Future<void> _loadFonts() async {
  const families = <String, List<String>>{
    'JetBrainsMono': [
      'assets/fonts/JetBrainsMono-Light.ttf',
      'assets/fonts/JetBrainsMono-Regular.ttf',
      'assets/fonts/JetBrainsMono-SemiBold.ttf',
    ],
    'Syne': ['assets/fonts/Syne-Variable.ttf'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final path in e.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

Widget _phone(GuildController c, Widget child) => ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(
        theme: T.theme(),
        debugShowCheckedModeBanner: false,
        home: child,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> frame(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await _loadFonts();
  }

  testWidgets('dispatch', (t) async {
    await frame(t);
    final c = GuildController(Persistence());
    await c.boot();
    c.g.unlockedSectors.addAll(['blackstone', 'cinder']);
    c.g.level = 3;

    await t.pumpWidget(_phone(c, const DispatchScreen()));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(DispatchScreen),
      matchesGoldenFile('goldens/dispatch.png'),
    );
    c.dispose();
  });

  testWidgets('session', (t) async {
    await frame(t);
    final c = GuildController(Persistence());
    await c.boot();
    c.g.unlockedSectors.add('cinder');
    await c.startRun(
      sectorId: 'cinder',
      intent: 'Finish the expedition engine',
      squad: ['a1'],
      minutes: 60,
    );

    await t.pumpWidget(_phone(c, const SessionScreen()));
    await t.pump();
    await expectLater(
      find.byType(SessionScreen),
      matchesGoldenFile('goldens/session.png'),
    );
    await c.finishRun(recalled: true);
    c.dispose();
  });

  testWidgets('debrief', (t) async {
    await frame(t);
    final c = GuildController(Persistence());
    await c.boot();
    c.g.unlockedSectors.add('blackstone');
    // A finished run with salvage, so the payoff screen shows its best case.
    c.g.vault.add(Gear('g0', 'ore_sense'));
    final rec = RunRecord(
      id: 'golden',
      sectorId: 'blackstone',
      intent: 'Refactor the expedition engine',
      squad: ['a1'],
      startedAt: DateTime(2026, 9, 20, 14),
      endedAt: DateTime(2026, 9, 20, 14, 52),
      plannedMinutes: 60,
      elapsedSeconds: 52 * 60,
      integrity: 1.0,
      recalled: false,
      scraps: false,
      credits: 318,
      alloy: 121,
      intel: 14,
      loot: ['g0'],
      xpGained: {'a1': 214},
      levelUps: ['a1'],
      guildXp: 130,
      guildLevelUps: 1,
      journal: const [
        'Descending the old shaft. Air is stale but breathable.',
        'Ore seam is richer than the survey suggested.',
        'Clean run. No interruptions, no losses.',
      ],
    );

    await t.pumpWidget(_phone(c, DebriefScreen(record: rec)));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(DebriefScreen),
      matchesGoldenFile('goldens/debrief.png'),
    );
    c.dispose();
  });
}
