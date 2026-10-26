@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/data/content.dart';
import 'package:telos/models/models.dart';
import 'package:telos/screens/debrief_screen.dart';
import 'package:telos/screens/dispatch_screen.dart';
import 'package:telos/screens/home_screen.dart';
import 'package:telos/screens/backup_screen.dart';
import 'package:telos/screens/log_screen.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/services/backup.dart';
import 'package:telos/screens/forge_screen.dart';
import 'package:telos/screens/outpost_screen.dart';
import 'package:telos/screens/roster_screen.dart';
import 'package:telos/screens/onboarding_screen.dart';
import 'package:telos/screens/session_screen.dart';
import 'package:telos/screens/spire_screen.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';
import 'package:telos/widgets/camp_controls.dart';
import 'package:telos/widgets/gear_art.dart';
import 'package:telos/widgets/contract_board.dart';
import 'package:telos/widgets/run_card.dart';
import 'package:telos/widgets/sector_header.dart';
import 'package:telos/widgets/sigil.dart';

import 'support/archive_fixtures.dart';

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
    'IBMPlexSans': ['assets/fonts/IBMPlexSans-Variable.ttf'],
    'IBMPlexSansCondensed': ['assets/fonts/IBMPlexSansCondensed-SemiBold.ttf'],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
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

  Future<GuildController> establishedCamp() async {
    final c = GuildController(Persistence());
    await c.boot();
    addTearDown(c.dispose);
    c.g.onboarded = true;
    c.g.credits = 1840;
    c.g.alloy = 420;
    c.g.intel = 196;
    c.g.level = 4;
    c.g.unlockedSectors.addAll(['blackstone', 'cinder']);
    c.g.vault.addAll([
      Gear('cord', 'scav_cord'),
      Gear('glass', 'mossglass'),
      Gear('optic', 'field_optic'),
      Gear('lamp', 'deep_lamp'),
    ]);
    c.g.roster.first.equipped.addAll(['cord', 'glass']);
    c.g.roster.first.level = 3;
    c.g.roster.first.xp = 112;
    return c;
  }

  Future<void> tapVisible(WidgetTester t, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await t.scrollUntilVisible(finder, 160,
          scrollable: find.byType(Scrollable).last);
    }
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  testWidgets('roster and equipment reviews', (t) async {
    await frame(t);
    final c = await establishedCamp();
    await t.pumpWidget(_phone(c, const RosterScreen()));
    await t.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/roster.png'));
    await tapVisible(t, find.text('KAEL'));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/member-kit.png'));
    await tapVisible(t, find.byKey(const Key('slot-a1-1')));
    await tapVisible(t, find.byKey(const Key('choose-gear-optic')));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/equipment-compare.png'));
  });

  testWidgets('forge and recipe review', (t) async {
    await frame(t);
    final c = await establishedCamp();
    await t.pumpWidget(_phone(c, const ForgeScreen()));
    await t.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/forge.png'));
    await tapVisible(t, find.byKey(const Key('recipe-scav_cord')));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/recipe.png'));
  });

  testWidgets('facilities and upgrade review', (t) async {
    await frame(t);
    final c = await establishedCamp();
    await t.pumpWidget(_phone(c, const OutpostScreen()));
    await t.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/facilities.png'));
    await tapVisible(t, find.byKey(const Key('review-forge')));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/upgrade.png'));
  });

  testWidgets('dispatch', (t) async {
    await frame(t);
    final c = GuildController(Persistence());
    await c.boot();
    c.g.unlockedSectors.addAll(['blackstone', 'cinder']);
    c.g.level = 3;

    await t.pumpWidget(_phone(c, const DispatchScreen()));
    // Image.asset resolves asynchronously, so without this the golden
    // records the placeholder rather than the illustration.
    await t.runAsync(() => precacheImage(
          AssetImage(SectorHeader.assetFor('blackstone')),
          t.element(find.byType(DispatchScreen)),
        ));
    await t.pumpAndSettle();
    // The destination illustration sits above the disclosures now, so the
    // squad step starts below the fold. A ListView does not build what is
    // off-screen, so it has to be scrolled to rather than found.
    await t.drag(
        find.byKey(const Key('dispatch-scroll')), const Offset(0, -220));
    await t.pumpAndSettle();
    await t.tap(find.text('The squad'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('member-a1')));
    await t.tap(find.text('KAEL'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Review the plan'));
    await t.tap(find.text('Review the plan'));
    await t.pumpAndSettle();
    await t.drag(
        find.byKey(const Key('dispatch-scroll')), const Offset(0, 1000));
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

    // Fix the clock and return time so preview comparisons are repeatable.
    c.now = DateTime(2026, 10, 11, 9, 41);
    c.g.active = ActiveRun(
      id: 'golden-session',
      sectorId: 'cinder',
      intent: 'Finish the expedition engine',
      squad: ['a1'],
      startedAt: c.now,
      plannedMinutes: 60,
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

  testWidgets('spire', (t) async {
    await frame(t);
    final c = GuildController(Persistence());
    await c.boot();
    // A player a year past arriving: enough floors to read as a real share
    // of the structure, nowhere near the centuries below.
    c.g.spireCompletedAt = DateTime(2026, 3, 1);
    c.g.spireCompletionMinutes = 0;
    c.g.spireCharterName = c.g.guildName;
    c.g.log.add(RunRecord(
      id: 'sp',
      sectorId: 'spire',
      intent: '',
      squad: const [],
      startedAt: DateTime(2026, 3, 1),
      endedAt: DateTime(2026, 3, 1),
      plannedMinutes: 0,
      elapsedSeconds: 240 * 60 * 60,
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
    ));

    await t.pumpWidget(_phone(c, const SpireScreen()));
    await t.pump();
    await expectLater(
      find.byType(SpireScreen),
      matchesGoldenFile('goldens/spire.png'),
    );
    c.dispose();
  });

  testWidgets('debrief', (t) async {
    await frame(t);
    final c = GuildController(Persistence());
    await c.boot();
    c.g.unlockedSectors.add('blackstone');
    // A finished run with salvage, so the payoff screen shows its best case.
    c.g.vault.add(Gear('g0', 'ore_sense'));
    c.g.credits = 318;
    c.g.alloy = 121;
    c.g.intel = 14;
    c.g.level = 3;
    c.g.roster.first.level = 2;
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
      priorSurvey:
          'Their survey of the seam is here. It reads a third of what we '
          'are pulling out.',
    );

    await t.pumpWidget(_phone(c, DebriefScreen(record: rec)));
    // Asset decoding runs outside the fake clock. Wait for the actual plate
    // so this preview cannot silently capture the loading engraving.
    await t.runAsync(() => precacheImage(
        AssetImage(GearArt.assetFor('ore_sense')),
        t.element(find.byType(DebriefScreen))));
    await t.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(GearArt), matching: find.byType(RawImage)),
        findsOneWidget);
    await expectLater(
      find.byType(DebriefScreen),
      matchesGoldenFile('goldens/debrief.png'),
    );
    final plain = RunRecord.fromJson(rec.toJson()
      ..['loot'] = []
      ..['priorSurvey'] = null
      ..['guildLevelUps'] = 0
      ..['levelUps'] = []);
    await t.pumpWidget(
        _phone(c, DebriefScreen(key: const Key('no-gear'), record: plain)));
    await t.pumpAndSettle();
    await expectLater(find.byType(DebriefScreen),
        matchesGoldenFile('goldens/debrief-no-gear.png'));

    final short = RunRecord.fromJson(plain.toJson()
      ..['recalled'] = true
      ..['scraps'] = true
      ..['elapsedSeconds'] = 45
      ..['credits'] = 1
      ..['alloy'] = 0
      ..['intel'] = 0);
    t.view.physicalSize = const Size(320, 640);
    await t.pumpWidget(
        _phone(c, DebriefScreen(key: const Key('short'), record: short)));
    await t.pumpAndSettle();
    await expectLater(find.byType(DebriefScreen),
        matchesGoldenFile('goldens/debrief-recalled-small.png'));
    c.dispose();
  });

  // The share card for the same run, among a few earlier ones, at the size
  // it is shared (1080 x 1350 once captured at 3x).
  testWidgets('run card', (t) async {
    await frame(t);
    t.view.physicalSize = RunCard.size * 3;
    t.view.devicePixelRatio = 3;
    final sector = sectorById('blackstone');
    final rec = RunRecord(
      id: 'card',
      sectorId: 'blackstone',
      intent: 'Never on the card',
      squad: const ['a1'],
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
      loot: const [],
      xpGained: const {},
      levelUps: const [],
      guildXp: 130,
      guildLevelUps: 0,
      journal: const [],
    );
    await t.pumpWidget(MaterialApp(
      theme: T.theme(),
      debugShowCheckedModeBanner: false,
      home: Center(
        child: RunCard(
          record: rec,
          sector: sector,
          guildName: 'THE SILVER LANTERN',
          depths: const [1.0, 0.98, 1.0, 0.6, 1.1, 0.56, 1.0, 0.8],
          floors: 0,
          status: 'CLEAN RUN',
        ),
      ),
    ));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(RunCard),
      matchesGoldenFile('goldens/run_card.png'),
    );
  });

  // Every mark at the sizes it actually has to survive.
  testWidgets('marks', (t) async {
    await frame(t);
    Widget row(String label, List<Widget> marks) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(label, style: T.micro),
              ),
              for (final m in marks)
                Padding(padding: const EdgeInsets.only(right: 16), child: m),
            ],
          ),
        );

    await t.pumpWidget(MaterialApp(
      theme: T.theme(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text('SECTOR SIGILS', style: T.micro.copyWith(color: T.steel)),
                for (final sec in kSectors)
                  row(sec.name.replaceAll('THE ', ''), [
                    Sigil(sectorId: sec.id, color: Color(sec.accent), size: 40),
                    Sigil(sectorId: sec.id, color: Color(sec.accent), size: 24),
                    Sigil(sectorId: sec.id, color: Color(sec.accent), size: 16),
                  ]),
                const SizedBox(height: 18),
                Text('CLASS EMBLEMS', style: T.micro.copyWith(color: T.steel)),
                for (final cls in kClasses.values)
                  row(cls.name, [
                    ClassEmblem(classId: cls.id, color: T.steel, size: 34),
                    ClassEmblem(classId: cls.id, color: T.good, size: 24),
                    ClassEmblem(classId: cls.id, color: T.dim, size: 16),
                  ]),
              ],
            ),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/marks.png'),
    );
  });

  testWidgets('field log and historical report', (t) async {
    await frame(t);
    final c = await establishedCamp();
    c.g.log.addAll([
      archiveRecord(),
      archiveRecord(
          id: 'record-2',
          startedAt: DateTime(2026, 10, 11, 8),
          sector: 'mosswood',
          intent: 'Inbox and invoices',
          loot: const []),
      archiveRecord(
          id: 'record-3',
          startedAt: DateTime(2026, 10, 11, 7),
          recalled: true,
          intent: 'Interrupted by a call',
          loot: const []),
    ]);
    c.g.vault.add(Gear('retained', 'deep_lamp'));
    await t.pumpWidget(_phone(c, const LogScreen()));
    await t.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/field-log.png'));
    await tapVisible(t, find.byKey(const Key('log-record-1')));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/expedition-record.png'));
    await t.pageBack();
    await t.pumpAndSettle();
    c.g.log.clear();
    await t.pumpWidget(_phone(c, const LogScreen(key: Key('empty'))));
    await t.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/field-log-empty.png'));
  });

  testWidgets('standing orders and claim review', (t) async {
    await frame(t);
    final c = await establishedCamp();
    c.g.contracts
      ..clear()
      ..addAll(standingOrders());
    await t.pumpWidget(_phone(
        c,
        Scaffold(
          appBar: AppBar(title: const Text('Contracts')),
          body: ListView(
              padding: const EdgeInsets.all(16),
              children: const [ContractBoardPanel()]),
        )));
    await t.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/contracts.png'));
    await tapVisible(t, find.text('Finish 3 runs at full Integrity'));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/contract-reward.png'));
  });

  testWidgets('share preview', (t) async {
    await frame(t);
    final c = await establishedCamp();
    final rec = archiveRecord(loot: const []);
    await t.pumpWidget(_phone(
        c,
        Scaffold(
            body: Builder(
                builder: (context) => Center(
                    child: CampButton(
                        label: 'Preview',
                        onPressed: () => showRunCard(
                            context,
                            RunCard(
                                record: rec,
                                sector: sectorById(rec.sectorId),
                                guildName: c.g.guildName,
                                depths: const [.5, .8, 1],
                                floors: 0,
                                status: 'CLEAN RUN'))))))));
    await tapVisible(t, find.text('Preview'));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/share-preview.png'));
  });

  testWidgets('settings and backup review', (t) async {
    await frame(t);
    final c = await establishedCamp();
    final saved = GuildState.fresh()
      ..guildName = 'The Ash Company'
      ..level = 5
      ..onboarded = true;
    saved.log.add(archiveRecord(loot: const []));
    final files = MemoryBackupFiles();
    files.contents['/memory/telos-backup-2026-10-11-0900.json'] =
        Backup.encode(saved);
    await t.pumpWidget(_phone(c, BackupScreen(files: files)));
    await t.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/settings.png'));
    await tapVisible(t, find.text('Save & restore'));
    await t.ensureVisible(find.byKey(const Key('export-backup')));
    await t.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/backup-list.png'));
    await tapVisible(
        t, find.byKey(const Key('backup-telos-backup-2026-10-11-0900.json')));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/backup-restore.png'));
  });

  testWidgets('manual', (t) async {
    await frame(t);
    final c = GuildController(Persistence());
    await c.boot();
    await t.pumpWidget(_phone(c, const OnboardingScreen()));
    await t.runAsync(() => precacheImage(
          const AssetImage('assets/art/camp.webp'),
          t.element(find.byType(OnboardingScreen)),
        ));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/manual.png'),
    );
    for (final name in ['manual-integrity', 'manual-return']) {
      await tapVisible(t, find.byKey(const Key('manual-next')));
      if (name == 'manual-integrity') {
        await t.runAsync(() => precacheImage(
              const AssetImage('assets/art/onboarding-hourglass.webp'),
              t.element(find.byType(OnboardingScreen)),
            ));
        await t.pumpAndSettle();
      }
      await expectLater(
          find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    }
    c.dispose();
  });

  testWidgets('home', (t) async {
    await frame(t);
    final c = GuildController(Persistence());
    await c.boot();
    c.g.onboarded = true;
    c.g.credits = 1840;
    c.g.alloy = 420;
    c.g.intel = 96;
    c.g.level = 4;
    c.g.xp = 130;
    // One contract already finished, so the claim state is visible too.
    c.g.contracts.first.progress = c.g.contracts.first.target;
    // A guild this far along has sent runs, so SEND AGAIN has rows.
    c.g.unlockedSectors.add('blackstone');
    for (final (sector, minutes, squad, intent) in [
      ('blackstone', 45, ['a1', 'a2'], 'Write the methods chapter'),
      ('mosswood', 25, ['a2'], 'Inbox and invoices'),
      ('blackstone', 90, ['a1'], ''),
    ]) {
      c.g.log.add(RunRecord(
        id: 'h$minutes',
        sectorId: sector,
        intent: intent,
        squad: squad,
        startedAt: DateTime(2026, 9, 1),
        endedAt: DateTime(2026, 9, 1).add(Duration(minutes: minutes)),
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
      ));
    }

    await t.pumpWidget(_phone(c, const HomeScreen()));
    await t.runAsync(() => precacheImage(
          const AssetImage('assets/art/camp.webp'),
          t.element(find.byType(HomeScreen)),
        ));
    await t.pumpAndSettle();
    // Asked once, after the first expedition.
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home-music-offer.png'),
    );
    // A guild this far along has long since answered.
    c.g.musicOffered = true;
    c.notifyListeners();
    await t.pumpAndSettle();
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home.png'),
    );
    await t.tap(find.byKey(const Key('edit-guild')));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(Navigator),
      matchesGoldenFile('goldens/guild-identity.png'),
    );
    Navigator.of(t.element(find.byKey(const Key('save-guild')))).pop();
    await t.pumpAndSettle();
    // An attainable project on a narrow phone. Larger text and the keyboard
    // are exercised separately by the camp interaction tests.
    c.g.credits = 96;
    c.g.alloy = 18;
    c.g.contracts.first.progress = 0;
    t.view.physicalSize = const Size(320, 640);
    await t.pumpWidget(_phone(c, const HomeScreen()));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home-small.png'),
    );
    c.dispose();
  });
}
