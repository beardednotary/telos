import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/main.dart';
import 'package:telos/models/guild_identity.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/screens/backup_screen.dart';
import 'package:telos/screens/caravan_screen.dart';
import 'package:telos/screens/forge_screen.dart';
import 'package:telos/screens/home_screen.dart';
import 'package:telos/screens/log_screen.dart';
import 'package:telos/screens/outpost_screen.dart';
import 'package:telos/screens/roster_screen.dart';
import 'package:telos/screens/spire_screen.dart';
import 'package:telos/services/backup.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';

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

  Future<void> mount(
    WidgetTester t,
    GuildController c, {
    Size size = const Size(390, 844),
    double textScale = 1,
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
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Root(),
      ),
    ));
    await t.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  test('old saves preserve names and gain safe identity/project defaults', () {
    final old = GuildState.fresh().toJson()
      ..remove('guildSigil')
      ..remove('campProject')
      ..['guildName'] = 'AN EXISTING GUILD';
    final migrated = GuildState.fromJson(old);
    expect(migrated.guildName, 'AN EXISTING GUILD');
    expect(migrated.guildSigil, GuildSigil.lantern);
    expect(migrated.campProject, Facility.forge);
    old['guildSigil'] = {'unknown': true};
    old['campProject'] = 'future-project';
    expect(GuildState.fromJson(old).guildSigil, GuildSigil.lantern);
    expect(GuildState.fromJson(old).campProject, Facility.forge);
  });

  test(
      'identity and project survive restart and backup without changing rewards or charter',
      () async {
    final c = await boot();
    c.g.credits = 207;
    c.g.alloy = 42;
    c.g.intel = 31;
    c.g.spireCharterName = 'The first name';
    final before = c.g.toJson();
    await c.updateGuildIdentity('  The   Long Watch  ', GuildSigil.compass);
    await c.selectCampProject(Facility.archive);
    final unchanged = c.g.toJson()
      ..['guildName'] = before['guildName']
      ..['guildSigil'] = before['guildSigil']
      ..['campProject'] = before['campProject'];
    expect(unchanged, before);
    final restarted = await boot();
    expect(restarted.g.guildName, 'The Long Watch');
    expect(restarted.g.guildSigil, GuildSigil.compass);
    expect(restarted.g.campProject, Facility.archive);
    final restored = Backup.decode(Backup.encode(restarted.g))!;
    expect(restored.toJson(), restarted.g.toJson());
    expect(restored.spireCharterName, 'The first name');
  });

  test('invalid names leave saved identity intact', () async {
    final c = await boot();
    final name = c.g.guildName;
    await expectLater(
        c.updateGuildIdentity('   ', GuildSigil.branch), throwsArgumentError);
    await expectLater(
        c.updateGuildIdentity('x' * 33, GuildSigil.anvil), throwsArgumentError);
    expect(c.g.guildName, name);
    expect(c.g.guildSigil, GuildSigil.lantern);
  });

  testWidgets('editing is a draft until Save, and blank names are explained',
      (t) async {
    final c = await boot();
    await mount(t, c);
    await tapVisible(t, find.byKey(const Key('edit-guild')));
    await t.enterText(find.byKey(const Key('guild-name')), 'The Oak Watch');
    await tapVisible(t, find.byKey(const Key('sigil-branch')));
    await tapVisible(t, find.text('Cancel'));
    expect(c.g.guildName, 'The Silver Lantern');
    expect(c.g.guildSigil, GuildSigil.lantern);

    await tapVisible(t, find.byKey(const Key('edit-guild')));
    await t.enterText(find.byKey(const Key('guild-name')), '   ');
    await tapVisible(t, find.byKey(const Key('save-guild')));
    expect(find.text('Give your guild a name.'), findsOneWidget);
    await t.enterText(find.byKey(const Key('guild-name')), 'The Oak Watch');
    await tapVisible(t, find.byKey(const Key('sigil-branch')));
    await tapVisible(t, find.byKey(const Key('save-guild')));
    expect(find.text('The Oak Watch'), findsOneWidget);
    expect(c.g.guildSigil, GuildSigil.branch);
    final saved = await Persistence().load();
    expect(saved.guildName, 'The Oak Watch');
    expect(saved.guildSigil, GuildSigil.branch);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'one disclosure opens at a time; project selection spends nothing',
      (t) async {
    final c = await boot();
    await mount(t, c);
    expect(find.text('Roster & equipment'), findsNothing);
    await tapVisible(t, find.text('Squad & equipment'));
    expect(find.text('Roster & equipment'), findsOneWidget);
    await tapVisible(t, find.text('Camp & orders'));
    expect(find.text('Roster & equipment'), findsNothing);
    expect(find.text('Facilities & recruiting'), findsOneWidget);
    await tapVisible(t, find.byKey(const Key('change-project')));
    await tapVisible(t, find.byKey(const Key('project-archive')));
    expect(c.g.campProject, Facility.archive);
    expect(c.g.credits, 0);
    expect(c.g.facilities[Facility.archive], 1);
    expect(find.text('Archive · Level 2'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('camp keeps every management destination reachable', (t) async {
    final c = await boot();
    c.g.spireCompletedAt = DateTime(2026, 1, 1);
    await mount(t, c, size: const Size(900, 2600));
    Future<void> back() async {
      Navigator.of(t.element(find.byType(Scaffold).last)).pop();
      await t.pumpAndSettle();
    }

    Future<void> visit(String label, Type type) async {
      await tapVisible(t, find.text(label));
      expect(find.byType(type), findsOneWidget);
      await back();
    }

    await tapVisible(t, find.text('Squad & equipment'));
    await visit('Roster & equipment', RosterScreen);
    await visit('Forge', ForgeScreen);
    // Outside the sections, so always one tap away.
    await visit('Field log', LogScreen);
    await visit('The Spire', SpireScreen);
    await tapVisible(t, find.byKey(const Key('camp-settings')));
    expect(find.byType(BackupScreen), findsOneWidget);
    await back();
    await tapVisible(t, find.text('Camp & orders'));
    await visit('Facilities & recruiting', OutpostScreen);
    await visit('Caravan', CaravanScreen);
    await tapVisible(t, find.text('Contracts'));
    expect(find.text('Standing orders.'), findsOneWidget);
    await back();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'small phone and larger text keep actions and keyboard editor usable',
      (t) async {
    final c = await boot();
    c.g.guildName = 'The Long Watch of the North Road';
    await mount(t, c, size: const Size(320, 640), textScale: 1.6);
    expect(t.takeException(), isNull);
    final action = find.byKey(const Key('camp-dispatch'));
    expect(t.getRect(action).bottom, lessThanOrEqualTo(640));
    expect(action.hitTestable(), findsOneWidget);
    await tapVisible(t, find.byKey(const Key('edit-guild')));
    t.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('guild-name')), 'North Road');
    // Let the focused text field finish revealing the caret before scrolling
    // the sheet to its save action.
    await t.pumpAndSettle();
    await tapVisible(t, find.byKey(const Key('save-guild')));
    expect(c.g.guildName, 'North Road');
    expect(t.takeException(), isNull);
  });
}
