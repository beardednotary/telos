import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telos/data/content.dart';
import 'package:telos/models/guild_identity.dart';
import 'package:telos/models/models.dart';
import 'package:telos/theme/telos_theme.dart';
import 'package:telos/widgets/share_cards.dart';

RunRecord _run({int minutes = 52, double integrity = 1}) => RunRecord(
      id: 'card',
      sectorId: 'blackstone',
      intent: 'Never on the card',
      squad: const ['a1'],
      startedAt: DateTime(2026, 10, 26, 9),
      endedAt: DateTime(2026, 10, 26, 9).add(Duration(minutes: minutes)),
      plannedMinutes: minutes,
      elapsedSeconds: minutes * 60,
      integrity: integrity,
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

const _longName = 'The Long Watch of the North Road and the Far Gate';

/// The test font draws every glyph as a full square, far wider than the real
/// faces, so whether a fixed-size image fits has to be measured in those.
Future<void> _fonts() async {
  const families = <String, List<String>>{
    'JetBrainsMono': [
      'assets/fonts/JetBrainsMono-Light.ttf',
      'assets/fonts/JetBrainsMono-Regular.ttf',
      'assets/fonts/JetBrainsMono-SemiBold.ttf',
    ],
    'IBMPlexSans': ['assets/fonts/IBMPlexSans-Variable.ttf'],
    'IBMPlexSansCondensed': ['assets/fonts/IBMPlexSansCondensed-SemiBold.ttf'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final path in e.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

Future<void> _show(WidgetTester t, Size size, Widget card) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  // Large system text must not reach a fixed-size image.
  t.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(t.platformDispatcher.clearAllTestValues);
  await _fonts();
  await t.pumpWidget(MaterialApp(theme: T.theme(), home: card));
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

void main() {
  for (final story in [true, false]) {
    testWidgets(
        'a ${story ? 'story' : 'post'} fits with a find and a long guild name',
        (t) async {
      final card = ExpeditionCard(
          record: _run(),
          sector: sectorById('blackstone'),
          guildName: _longName,
          find: gearById('ore_sense'),
          story: story);
      await _show(t, card.size, card);
      expect(find.text('52'), findsOneWidget);
      expect(find.text('minutes of focus.'), findsOneWidget);
      expect(find.text('Not checked once.'), findsOneWidget);
      expect(find.text('Ore-sense Rig'), findsOneWidget);
      expect(find.text(kShareTagline), findsOneWidget);
      expect(find.textContaining('Never on the card'), findsNothing,
          reason: 'task text stays private');
    });
  }

  testWidgets('a run that was checked says nothing about Integrity', (t) async {
    await _show(
        t,
        kStorySize,
        ExpeditionCard(
            record: _run(minutes: 25, integrity: .96),
            sector: sectorById('blackstone'),
            guildName: 'The Silver Lantern'));
    expect(find.text('Not checked once.'), findsNothing);
    expect(find.textContaining('Integrity'), findsNothing);
  });

  for (final story in [false, true]) {
    testWidgets('the totals card fits as a ${story ? 'story' : 'feed post'}',
        (t) async {
      final card = TotalsCard(
          guildName: _longName,
          sigil: GuildSigil.lantern,
          focusMinutes: 100000,
          daysWorked: 1200,
          expeditions: 4800,
          cleanRuns: 4100,
          since: DateTime(2026, 9, 19),
          story: story);
      await _show(t, card.size, card);
      expect(find.text('1666h 40m'), findsOneWidget);
      expect(find.text('Clean runs'), findsOneWidget);
      expect(find.text('Since Sep 2026'), findsOneWidget);
    });
  }
}
