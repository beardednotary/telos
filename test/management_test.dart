import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/data/content.dart';
import 'package:telos/models/models.dart';
import 'package:telos/screens/forge_screen.dart';
import 'package:telos/screens/outpost_screen.dart';
import 'package:telos/screens/roster_screen.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';
import 'package:telos/widgets/camp_controls.dart';
import 'package:telos/widgets/sector_header.dart';

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

  void kit(GuildController c) {
    c.g.vault.addAll([
      Gear('cord', 'scav_cord'),
      Gear('glass', 'mossglass'),
      Gear('optic', 'field_optic'),
    ]);
    c.g.roster.first.equipped.addAll(['cord', 'glass']);
  }

  Future<void> mount(WidgetTester t, GuildController c, Widget screen,
      {bool small = false}) async {
    t.view.physicalSize = small ? const Size(320, 640) : const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(
        theme: T.theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(small ? 1.6 : 1)),
          child: child!,
        ),
        home: screen,
      ),
    ));
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await t.scrollUntilVisible(finder, 200,
          scrollable: find.byType(Scrollable).last);
    }
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  Future<void> closeSheet(WidgetTester t) async {
    await tap(t, find.byTooltip('Close review'));
  }

  test('slot replacement preserves the other slot and ownership after restart',
      () async {
    final c = await boot();
    kit(c);
    await c.equip('a1', 'optic', replacingUid: 'glass');
    expect(c.g.roster.first.equipped, ['cord', 'optic']);
    expect(c.g.unequippedGear.map((g) => g.uid), ['glass']);
    expect(c.g.vault.length, 3);
    await c.equip('a1', 'missing', replacingUid: 'cord');
    await c.equip('a1', 'glass', replacingUid: 'stale');
    expect(c.g.roster.first.equipped, ['cord', 'optic']);
    await c.equip('a2', 'optic');
    expect(c.g.roster.first.equipped, ['cord']);
    expect(c.g.roster.last.equipped, ['optic']);
    final restored = GuildController(Persistence());
    await restored.boot();
    addTearDown(restored.dispose);
    expect(restored.g.roster.first.equipped, ['cord']);
    expect(restored.g.roster.last.equipped, ['optic']);
    expect(restored.g.vault.length, 3);
  });

  testWidgets(
      'equipment review compares both gains and losses before replacing slot two',
      (t) async {
    final c = await boot();
    kit(c);
    await mount(t, c, const RosterScreen());
    await tap(t, find.text('KAEL'));
    await tap(t, find.byKey(const Key('slot-a1-1')));
    await tap(t, find.byKey(const Key('choose-gear-optic')));
    expect(find.text('+6% → 0%'), findsOneWidget);
    expect(find.text('0% → +10%'), findsOneWidget);
    expect(c.g.roster.first.equipped, ['cord', 'glass']);
    await tap(t, find.byKey(const Key('confirm-equip')));
    expect(c.g.roster.first.equipped, ['cord', 'optic']);
    expect(c.g.unequippedGear.single.uid, 'glass');
    await tap(t, find.byKey(const Key('slot-a1-1')));
    await tap(t, find.byKey(const Key('remove-equipment')));
    expect(c.g.roster.first.equipped, ['cord']);
    expect(c.g.vault.length, 3);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'one member opens at a time and cancelled equipment reviews change nothing',
      (t) async {
    final c = await boot();
    kit(c);
    await mount(t, c, const RosterScreen());
    await tap(t, find.text('KAEL'));
    await tap(t, find.byKey(const Key('slot-a1-1')));
    await tap(t, find.byKey(const Key('choose-gear-optic')));
    await closeSheet(t);
    expect(c.g.roster.first.equipped, ['cord', 'glass']);
    await tap(t, find.text('MIRA'));
    final sections = t.widgetList<CampDisclosure>(find.byType(CampDisclosure));
    expect(sections.where((section) => section.expanded).length, 1);
    expect(find.byKey(const Key('slot-a1-0')), findsNothing);
    expect(find.byKey(const Key('slot-a2-0')), findsOneWidget);
  });

  testWidgets(
      'craft review spends once, saves a real piece and protects equipped gear from melting',
      (t) async {
    final c = await boot();
    c.g.credits = 1000;
    c.g.alloy = 500;
    c.g.intel = 200;
    kit(c);
    await mount(t, c, const ForgeScreen());
    await tap(t, find.byKey(const Key('recipe-scav_cord')));
    expect(find.text('Have 1000 · 840 after'), findsOneWidget);
    expect(find.text('Have 500 · 440 after'), findsOneWidget);
    expect(c.g.vault.length, 3);
    await closeSheet(t);
    expect(c.g.credits, 1000);
    await tap(t, find.byKey(const Key('recipe-scav_cord')));
    final craft = find.byKey(const Key('confirm-craft'));
    await t.ensureVisible(craft);
    await t.pumpAndSettle();
    // Two callbacks can arrive before the disabled state paints.
    final button = t.widget<TextButton>(find.descendant(
      of: craft,
      matching: find.byType(TextButton),
    ));
    button.onPressed!();
    button.onPressed!();
    await t.pumpAndSettle();
    expect((c.g.credits, c.g.alloy, c.g.intel), (840, 440, 175));
    expect(c.g.vault.length, 4);
    final crafted = c.g.vault.last;
    expect(crafted.defId, 'scav_cord');
    expect(c.g.roster.first.equipped, ['cord', 'glass']);
    await tap(t, find.text('Melt spare gear'));
    expect(find.byKey(const Key('melt-cord')), findsNothing);
    await tap(t, find.byKey(Key('melt-${crafted.uid}')));
    await tap(t, find.text('Keep this piece'));
    expect(c.g.vault.length, 4);
    await tap(t, find.byKey(Key('melt-${crafted.uid}')));
    await tap(t, find.byKey(const Key('confirm-melt')));
    expect(c.g.vault.length, 3);
    expect(c.g.alloy, 464);
    expect(await c.melt(crafted), isNull);
    expect(await c.melt(c.g.vault.first), isNull);
    final restored = GuildController(Persistence());
    await restored.boot();
    addTearDown(restored.dispose);
    expect((restored.g.credits, restored.g.alloy, restored.g.intel),
        (840, 464, 175));
  });

  testWidgets('forge recipes retain sector, resource and forge-level gates',
      (t) async {
    final c = await boot();
    await mount(t, c, const ForgeScreen());
    expect(find.byKey(const Key('recipe-hollow_pick')), findsNothing);
    await tap(t, find.byKey(const Key('recipe-scav_cord')));
    expect(find.text('Have 0 · Need 160 more'), findsOneWidget);
    await tap(t, find.byKey(const Key('confirm-craft')));
    expect(c.g.vault, isEmpty);
    await closeSheet(t);
    await tap(t, find.text('Rare equipment'));
    await tap(t, find.byKey(const Key('recipe-verge_charm')));
    expect(find.text('Requires forge level 3. Your forge is level 1.'),
        findsOneWidget);
    await tap(t, find.byKey(const Key('confirm-craft')));
    expect(c.g.vault, isEmpty);
  });

  testWidgets(
      'upgrade review exposes actual costs, preserves cancel, and separates roster from squad size',
      (t) async {
    final c = await boot();
    c.g.credits = 1000;
    c.g.alloy = 500;
    final squadSlots = c.g.squadSlots;
    await mount(t, c, const OutpostScreen());
    await tap(t, find.text('Barracks'));
    await tap(t, find.byKey(const Key('track-barracks')));
    expect(c.g.campProject, Facility.barracks);
    expect(c.g.credits, 1000);
    await tap(t, find.byKey(const Key('review-barracks')));
    expect(find.text('Have 1000 · 880 after'), findsOneWidget);
    expect(find.textContaining('Expedition squad size grows with guild level.'),
        findsOneWidget);
    await closeSheet(t);
    expect(c.g.facilities[Facility.barracks], 1);
    await tap(t, find.byKey(const Key('review-barracks')));
    await tap(t, find.byKey(const Key('confirm-upgrade')));
    expect((c.g.credits, c.g.alloy), (880, 475));
    expect(c.g.facilities[Facility.barracks], 2);
    expect(c.g.rosterSlots, 4);
    expect(c.g.squadSlots, squadSlots);
  });

  testWidgets(
      'recruiting and sector reviews enforce guild, capacity and intel gates',
      (t) async {
    final c = await boot();
    c.g.credits = 5000;
    c.g.intel = 500;
    await mount(t, c, const OutpostScreen());
    await tap(t, find.text('Recruiting'));
    await tap(t, find.byKey(const Key('recruit-archivist')));
    expect(find.text('Guild level too low'), findsOneWidget);
    await tap(t, find.byKey(const Key('confirm-recruit')));
    expect(c.g.roster.length, 2);
    await closeSheet(t);
    c.g.level = 2;
    await tap(t, find.byKey(const Key('recruit-archivist')));
    await tap(t, find.byKey(const Key('confirm-recruit')));
    expect(c.g.roster.length, 3);
    expect(c.g.roster.last.classId, 'archivist');
    expect(c.g.credits, 4350);
    await tap(t, find.byKey(const Key('recruit-archivist')));
    expect(find.text('Roster full'), findsOneWidget);
    await tap(t, find.byKey(const Key('confirm-recruit')));
    expect(c.g.roster.length, 3);
    await closeSheet(t);
    await tap(t, find.text('Sector access'));
    await tap(t, find.byKey(const Key('access-cinder')));
    expect(find.text('Guild level too low'), findsOneWidget);
    await closeSheet(t);
    await tap(t, find.byKey(const Key('access-blackstone')));
    await tap(t, find.byKey(const Key('confirm-unlock')));
    expect(c.g.sectorUnlocked('blackstone'), isTrue);
    expect(c.g.intel, 500 - sectorById('blackstone').intelToUnlock);
  });

  testWidgets('Spire illustration is revealed only after sector access',
      (t) async {
    final c = await boot();
    await mount(t, c, const OutpostScreen());
    await tap(t, find.text('Sector access'));
    expect(find.byType(SectorHeader), findsNothing,
        reason: 'the sector list has no illustration thumbnails');
    await tap(t, find.byKey(const Key('access-spire')));
    expect(find.byType(SectorHeader), findsNothing,
        reason: 'the locked Spire review must not reveal its illustration');
    await closeSheet(t);

    c.g.unlockedSectors.add('spire');
    await tap(t, find.byKey(const Key('access-spire')));
    expect(t.widget<SectorHeader>(find.byType(SectorHeader)).sector.id, 'spire');
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'management and review actions remain usable on a small phone with larger text',
      (t) async {
    final c = await boot();
    kit(c);
    c.g.roster.first.name = 'A very long adventurer name';
    await mount(t, c, const RosterScreen(), small: true);
    await tap(t, find.text(c.g.roster.first.name));
    await tap(t, find.byKey(const Key('slot-a1-1')));
    await tap(t, find.byKey(const Key('choose-gear-optic')));
    await tap(t, find.byKey(const Key('confirm-equip')));
    expect(c.g.roster.first.equipped, ['cord', 'optic']);
    expect(t.takeException(), isNull);
    await mount(t, c, const ForgeScreen(), small: true);
    await tap(t, find.byKey(const Key('recipe-scav_cord')));
    await tap(t, find.byKey(const Key('confirm-craft')));
    expect(t.takeException(), isNull);
    await closeSheet(t);
    await mount(t, c, const OutpostScreen(), small: true);
    await tap(t, find.byKey(const Key('review-forge')));
    await tap(t, find.byKey(const Key('confirm-upgrade')));
    expect(t.takeException(), isNull);
    expect(c.g.facilities[Facility.forge], 1);
  });
}
