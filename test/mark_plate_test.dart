import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/data/content.dart';
import 'package:telos/models/guild_identity.dart';
import 'package:telos/models/models.dart';
import 'package:telos/screens/backup_screen.dart';
import 'package:telos/screens/dispatch_screen.dart';
import 'package:telos/screens/debrief_screen.dart';
import 'package:telos/screens/guild_identity_sheet.dart';
import 'package:telos/screens/home_screen.dart';
import 'package:telos/screens/roster_screen.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';
import 'package:telos/widgets/contract_board.dart';
import 'package:telos/widgets/flash.dart';
import 'package:telos/widgets/guild_sigil.dart';
import 'package:telos/widgets/mark_plate.dart';
import 'package:telos/widgets/sigil.dart';

class _DelayedMissingBundle extends CachingAssetBundle {
  final pending = Completer<ByteData>();

  @override
  Future<ByteData> load(String key) => key.startsWith('assets/art/marks/')
      ? pending.future
      : rootBundle.load(key);
}

const _tint = Color(0xFF82B6AE);

List<MarkPlate> get _plates => [
      for (final sector in kSectors)
        MarkPlate.sector(sectorId: sector.id, color: _tint),
      for (final id in kClasses.keys)
        MarkPlate.classEmblem(classId: id, color: _tint),
      for (final sigil in GuildSigil.values)
        MarkPlate.guild(sigil: sigil, color: _tint),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every sector, class and guild emblem has its own asset path', () {
    for (final sector in kSectors) {
      expect(MarkPlate.sectorAssetFor(sector.id),
          'assets/art/marks/sectors/${sector.id}.webp');
    }
    for (final id in kClasses.keys) {
      expect(MarkPlate.classAssetFor(id), 'assets/art/marks/classes/$id.webp');
    }
    for (final sigil in GuildSigil.values) {
      expect(MarkPlate.guildAssetFor(sigil),
          'assets/art/marks/guild/${sigil.name}.webp');
    }
    expect(_plates.map((p) => p.assetPath).toSet(), hasLength(14));
  });

  for (final (plate, strokeType) in <(MarkPlate, Type)>[
    (
      const MarkPlate.sector(sectorId: 'mosswood', color: _tint, size: 72),
      Sigil
    ),
    (
      const MarkPlate.classEmblem(classId: 'recon', color: _tint, size: 64),
      ClassEmblem
    ),
    (
      const MarkPlate.guild(sigil: GuildSigil.lantern, color: _tint, size: 88),
      GuildEmblem
    ),
  ]) {
    testWidgets('${plate.assetPath}: loading and missing keep the stroke',
        (t) async {
      final bundle = _DelayedMissingBundle();
      await t.pumpWidget(MaterialApp(
        theme: T.theme(),
        home: DefaultAssetBundle(
          bundle: bundle,
          child: Scaffold(body: Center(child: plate)),
        ),
      ));
      await t.pump();
      expect(find.byType(strokeType), findsOneWidget);
      expect(t.getSize(find.byType(MarkPlate)), Size.square(plate.size));
      if (strokeType == GuildEmblem) {
        expect(find.bySemanticsLabel('Lantern sigil'), findsOneWidget);
        expect(t.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter,
            const ColorFilter.mode(_tint, BlendMode.srcIn));
      }
      bundle.pending.completeError(FlutterError('Missing plate for this test'));
      await t.pumpAndSettle();
      expect(find.byType(strokeType), findsOneWidget);
      expect(t.getSize(find.byType(MarkPlate)), Size.square(plate.size));
      if (strokeType == GuildEmblem) {
        expect(find.bySemanticsLabel('Lantern sigil'), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('all bundled plates decode, tint, and replace their fallbacks',
      (t) async {
    final plates = _plates;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: Wrap(children: plates)),
    ));
    final context = t.element(find.byType(Wrap));
    await t.runAsync(() async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final plate in plates) {
        expect(manifest.listAssets(), contains(plate.assetPath));
        await precacheImage(AssetImage(plate.assetPath), context);
      }
    });
    await t.pumpAndSettle();
    expect(find.byType(Sigil), findsNothing);
    expect(find.byType(ClassEmblem), findsNothing);
    expect(find.byType(GuildEmblem), findsNothing);
    for (final raw in t.widgetList<RawImage>(find.byType(RawImage))) {
      expect(raw.image, isNotNull);
      expect((raw.image!.width, raw.image!.height), (512, 512));
      expect(raw.color, _tint);
      expect(raw.colorBlendMode, BlendMode.srcIn);
    }
    expect(find.byType(RawImage), findsNWidgets(14));
    for (final sigil in GuildSigil.values) {
      expect(find.bySemanticsLabel('${sigil.label} sigil'), findsOneWidget);
    }
    expect(t.takeException(), isNull);
  });

  Future<GuildController> boot() async {
    final c = GuildController(Persistence());
    await c.boot();
    c.g.onboarded = true;
    addTearDown(c.dispose);
    return c;
  }

  for (final (width, scale) in [(320.0, 1.6), (390.0, 1.0)]) {
    testWidgets(
        'guild picker uses 64px plates at $width with text scale $scale',
        (t) async {
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final c = await boot();
      await t.pumpWidget(MaterialApp(
        theme: T.theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: GuildIdentitySheet(controller: c)),
      ));
      await t.pumpAndSettle();
      expect(find.byType(MarkPlate), findsNWidgets(4));
      for (final plate in t.widgetList<MarkPlate>(find.byType(MarkPlate))) {
        expect(plate.size, 64);
        expect(plate.color, T.amber);
      }
      await t.ensureVisible(find.byKey(const Key('sigil-branch')));
      await t.tap(find.byKey(const Key('sigil-branch')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
      'small marks in dispatch, roster, home, backup and board stay strokes',
      (t) async {
    t.view.physicalSize = const Size(900, 4200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await boot();
    for (final (screen, stroke) in <(Widget, Type)>[
      (const DispatchScreen(), Sigil),
      (const RosterScreen(), ClassEmblem),
      (const HomeScreen(), GuildEmblem),
      (const BackupScreen(), GuildEmblem),
      (const Scaffold(body: ContractBoardPanel()), Sigil),
    ]) {
      await t.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(theme: T.theme(), home: screen),
      ));
      await t.pumpAndSettle();
      if (screen is DispatchScreen) {
        await t.tap(find.text('Their destination'));
        await t.pumpAndSettle();
      }
      expect(find.byType(MarkPlate), findsNothing,
          reason: '$screen stays scanned');
      expect(find.byType(stroke), findsWidgets,
          reason: '$screen retains its strokes');
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('the guild debrief beat uses the chosen 88px emblem', (t) async {
    t.view.physicalSize = const Size(900, 4200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = await boot();
    c.g.level = 2;
    c.g.guildSigil = GuildSigil.anvil;
    final record = RunRecord(
      id: 'guild-rise',
      sectorId: 'mosswood',
      intent: '',
      squad: const ['a1'],
      startedAt: DateTime(2026, 11, 25, 9),
      endedAt: DateTime(2026, 11, 25, 9, 25),
      plannedMinutes: 25,
      elapsedSeconds: 1500,
      integrity: 1,
      recalled: false,
      scraps: false,
      credits: 50,
      alloy: 10,
      intel: 2,
      loot: const [],
      xpGained: const {},
      levelUps: const [],
      guildXp: 100,
      guildLevelUps: 1,
      journal: const [],
    );
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(theme: T.theme(), home: DebriefScreen(record: record)),
    ));
    await t.pumpAndSettle();
    expect(find.text('THE GUILD HAS RISEN'), findsOneWidget);
    final plate = t.widget<MarkPlate>(find.byType(MarkPlate));
    expect(plate.assetPath, MarkPlate.guildAssetFor(GuildSigil.anvil));
    expect(plate.size, 88);
    expect(plate.color, T.amber);
    expect(t.takeException(), isNull);
  });

  testWidgets('the flash still animates its sector stroke', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () => showFlash(context,
                        kicker: 'OPEN',
                        title: 'Mosswood',
                        sigilSectorId: 'mosswood'),
                    child: const Text('Show'),
                  ))),
    ));
    await t.tap(find.text('Show'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(MarkPlate), findsNothing);
    final stroke = t.widget<Sigil>(find.byType(Sigil));
    expect(stroke.animate, isTrue);
    expect(stroke.size, 34);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
