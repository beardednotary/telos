import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/main.dart';
import 'package:telos/models/guild_identity.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/models/models.dart';
import 'package:telos/screens/backup_screen.dart';
import 'package:telos/screens/log_screen.dart';
import 'package:telos/screens/onboarding_screen.dart';
import 'package:telos/services/backup.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';
import 'package:telos/widgets/camp_controls.dart';

import 'support/archive_fixtures.dart';

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
      await t.scrollUntilVisible(finder, 180,
          scrollable: find.byType(Scrollable).last);
    }
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  test('backup review uses actual save data and rejects unsupported versions',
      () {
    final g = GuildState.fresh()..guildName = 'Actual guild';
    final data = jsonDecode(Backup.encode(g)) as Map<String, dynamic>;
    data['summary'] = {'guild': 'Wrong guild', 'level': 99};
    final info = Backup.inspect(jsonEncode(data))!;
    expect(info.guild, 'Actual guild');
    expect(info.level, 1);
    data['telos'] = 2;
    expect(Backup.decode(jsonEncode(data)), isNull);
    expect(Backup.inspect(jsonEncode(data)), isNull);
    data['telos'] = 1;
    (data['save'] as Map<String, dynamic>)['v'] = 2;
    expect(Backup.decode(jsonEncode(data)), isNull);
    expect(
        Backup.inspect(jsonEncode({
          'summary': {'guild': 'Summary only'}
        })),
        isNull);
  });

  testWidgets(
      'history opens complete read-only results without rebanking or inventing old levels',
      (t) async {
    final c = await boot();
    c.g.level = 9;
    c.g.roster.first.level = 8;
    c.g.credits = 340;
    c.g.vault.add(Gear('retained', 'deep_lamp'));
    c.g.log.add(archiveRecord());
    final before = jsonEncode(c.g.toJson());
    await mount(t, c, const LogScreen());
    expect(find.text('0h 25m'), findsOneWidget);
    await tap(t, find.byKey(const Key('log-record-1')));
    expect(find.text('Finished the outline. The ending needs another pass.'),
        findsOneWidget);
    await tap(t, find.text('Field journal'));
    expect(find.text('The west road is passable.'), findsOneWidget);
    expect(find.text('Someone had marked a second route through the stone.'),
        findsOneWidget);
    await tap(t, find.text('Squad & equipment'));
    expect(find.text('KAEL · +80 XP · Leveled up'), findsOneWidget);
    expect(find.textContaining('no longer in the vault.'), findsOneWidget);
    expect(find.text('Deep Lamp'), findsOneWidget);
    expect(find.textContaining('level 8'), findsNothing);
    final sections = t.widgetList<CampDisclosure>(find.byType(CampDisclosure));
    expect(sections.where((s) => s.expanded).length, 1);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(jsonEncode(c.g.toJson()), before);
  });

  testWidgets(
      'short recalls and long reflections remain readable at large text',
      (t) async {
    final c = await boot();
    final record = archiveRecord(
        recalled: true,
        loot: const [],
        intent:
            'A long task name that needs more than one line on a small phone');
    c.g.log.add(record);
    await mount(t, c, const LogScreen(), small: true);
    await tap(t, find.byKey(const Key('log-record-1')));
    expect(find.text('45 sec of 25 min planned'), findsOneWidget);
    expect(find.textContaining('Scraps only'), findsOneWidget);
    await tap(t, find.text('Squad & equipment'));
    await t.ensureVisible(find.text('No equipment found on this expedition.'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'first-run manual supports back and completion on a small phone',
      (t) async {
    final c = await boot();
    c.g.onboarded = false;
    await mount(t, c, const Root(), small: true);
    expect(c.g.manualSeenAt, isNotNull);
    expect(c.g.manualDoneAt, isNull);
    await tap(t, find.byKey(const Key('manual-next')));
    expect(find.text('INTEGRITY'), findsOneWidget);
    // The detail lives in the full manual under Settings, not on day one.
    expect(find.text('How Integrity works'), findsNothing);
    expect(c.g.onboarded, isFalse);
    await tap(t, find.text('Previous page'));
    expect(find.text('THE ONE RULE'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tap(t, find.byKey(const Key('manual-next')));
    }
    expect(find.text('Open camp'), findsOneWidget);
    await tap(t, find.byKey(const Key('manual-next')));
    expect(c.g.onboarded, isTrue);
    expect(c.g.manualDoneAt, isNotNull);
    expect(find.byKey(const Key('camp-dispatch')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'settings retains identity, manual review and licenses without resetting onboarding',
      (t) async {
    final c = await boot();
    await c.completeOnboarding();
    final done = c.g.manualDoneAt;
    await mount(t, c, BackupScreen(files: MemoryBackupFiles()));
    await tap(t, find.byKey(const Key('settings-identity')));
    expect(find.text('Your guild'), findsOneWidget);
    await tap(t, find.text('Cancel'));
    await tap(t, find.text('Help & about'));
    await tap(t, find.byKey(const Key('settings-manual')));
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tap(t, find.byKey(const Key('manual-next')));
    await tap(t, find.text('How Integrity works'));
    expect(find.textContaining('Equipment rarity is rolled separately.'),
        findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tap(t, find.byKey(const Key('manual-next')));
    }
    expect(find.text('REPEAT A DISPATCH'), findsOneWidget);
    await tap(t, find.byKey(const Key('manual-next')));
    expect(find.byType(BackupScreen), findsOneWidget);
    expect(c.g.manualDoneAt, done);
    await tap(t, find.byKey(const Key('settings-licenses')));
    expect(find.byType(LicensePage), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('export guards repeated taps and saves a restorable copy',
      (t) async {
    final c = await boot();
    final files = MemoryBackupFiles()..pendingExport = Completer<void>();
    final before = jsonEncode(c.g.toJson());
    await mount(t, c, BackupScreen(files: files));
    await tap(t, find.text('Save & restore'));
    final action = find.byKey(const Key('export-backup'));
    await t.ensureVisible(action);
    await t.pumpAndSettle();
    final button = t.widget<TextButton>(
        find.descendant(of: action, matching: find.byType(TextButton)));
    button.onPressed!();
    button.onPressed!();
    await t.pump();
    expect(files.exports, 1);
    final origin = files.lastSharePositionOrigin!;
    expect(origin.width, greaterThan(0));
    expect(origin.height, greaterThan(0));
    expect(origin.left, greaterThanOrEqualTo(0));
    expect(origin.top, greaterThanOrEqualTo(0));
    expect(origin.right, lessThanOrEqualTo(390));
    expect(origin.bottom, lessThanOrEqualTo(844));
    files.pendingExport!.complete();
    await t.pumpAndSettle();
    expect(
        Backup.decode(files.contents.values.single)!.guildName, c.g.guildName);
    expect(jsonEncode(c.g.toJson()), before);
    expect(
        find.textContaining('Backup written on this phone.'), findsOneWidget);
  });

  testWidgets(
      'a backup saved anywhere can be picked and restored through the same review',
      (t) async {
    final c = await boot();
    final replacement = GuildState.fresh()
      ..guildName = 'The Ash Company'
      ..credits = 812
      ..onboarded = true;
    final files = MemoryBackupFiles()
      ..picked = PickedBackup(
          'my renamed backup.json', Backup.encode(replacement));
    await mount(t, c, BackupScreen(files: files), small: true);
    await tap(t, find.text('Save & restore'));
    expect(find.text('No backup files found.'), findsOneWidget,
        reason: 'the case the tester hit: nothing in the app folder');
    await tap(t, find.byKey(const Key('pick-backup')));
    expect(files.picks, 1);
    expect(find.text('Replace this guild?'), findsOneWidget);
    expect(find.text('my renamed backup.json'), findsOneWidget);
    await tap(t, find.byKey(const Key('confirm-restore')));
    expect(c.g.guildName, 'The Ash Company');
    expect(c.g.credits, 812);
    expect(t.takeException(), isNull);
  });

  testWidgets('picking something that is not a backup says so and changes nothing',
      (t) async {
    final c = await boot();
    final before = jsonEncode(c.g.toJson());
    final files = MemoryBackupFiles()
      ..picked = const PickedBackup('notes.json', '{"hello": 1}');
    await mount(t, c, BackupScreen(files: files), small: true);
    await tap(t, find.text('Save & restore'));
    await tap(t, find.byKey(const Key('pick-backup')));
    expect(find.text('Replace this guild?'), findsNothing);
    expect(find.textContaining('notes.json is not a Telos backup'),
        findsOneWidget);
    // Cancelling the picker clears nothing and opens nothing.
    files.picked = null;
    await tap(t, find.byKey(const Key('pick-backup')));
    expect(find.text('Replace this guild?'), findsNothing);
    expect(jsonEncode(c.g.toJson()), before);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'restore cancellation preserves the save; confirmation replaces it and clears live state',
      (t) async {
    final c = await boot();
    final replacement = GuildState.fresh()
      ..guildName = 'The Ash Company'
      ..guildSigil = GuildSigil.compass
      ..credits = 812
      ..onboarded = true;
    replacement.log.add(archiveRecord(loot: const []));
    replacement.pendingDebrief = replacement.log.first;
    replacement.active = ActiveRun(
        id: 'old',
        sectorId: 'mosswood',
        intent: 'Old task',
        squad: ['a1'],
        startedAt: DateTime(2026, 1),
        plannedMinutes: 25);
    final files = MemoryBackupFiles();
    const name = 'telos-backup-2026-10-11-0900.json';
    files.contents['/memory/$name'] = Backup.encode(replacement);
    final before = jsonEncode(c.g.toJson());
    await mount(t, c, BackupScreen(files: files), small: true);
    await tap(t, find.text('Save & restore'));
    await tap(t, find.byKey(const Key('backup-$name')));
    expect(find.text('Replace this guild?'), findsOneWidget);
    await tap(t, find.text('Keep current guild'));
    expect(jsonEncode(c.g.toJson()), before);
    await tap(t, find.byKey(const Key('backup-$name')));
    await tap(t, find.byKey(const Key('confirm-restore')));
    expect(c.g.guildName, 'The Ash Company');
    expect(c.g.guildSigil, GuildSigil.compass);
    expect(c.g.credits, 812);
    expect(c.g.active, isNull);
    expect(c.g.pendingDebrief, isNull);
    final restored = GuildController(Persistence());
    await restored.boot();
    addTearDown(restored.dispose);
    expect(restored.g.guildName, 'The Ash Company');
    expect(restored.g.credits, 812);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'file and export failures are visible and recoverable without changing the guild',
      (t) async {
    final c = await boot();
    final files = MemoryBackupFiles()..failList = true;
    const bad = '/memory/telos-backup-invalid.json';
    const unreadable = '/memory/telos-backup-unreadable.json';
    files.contents[bad] = '{bad';
    files.contents[unreadable] = Backup.encode(GuildState.fresh());
    files.unreadable.add(unreadable);
    final before = jsonEncode(c.g.toJson());
    await mount(t, c, BackupScreen(files: files));
    await tap(t, find.text('Save & restore'));
    expect(
        find.textContaining('Could not read local backups.'), findsOneWidget);
    files.failList = false;
    await tap(t, find.byKey(const Key('refresh-backups')));
    expect(
        find.text('Unreadable or unsupported Telos backup.'), findsNWidgets(2));
    await tap(t, find.byKey(const Key('backup-telos-backup-invalid.json')));
    expect(find.byKey(const Key('confirm-restore')), findsNothing);
    files.failExport = true;
    await tap(t, find.byKey(const Key('export-backup')));
    expect(find.textContaining('Could not finish exporting.'), findsOneWidget);
    expect(jsonEncode(c.g.toJson()), before);
    files.failExport = false;
    await tap(t, find.byKey(const Key('export-backup')));
    expect(files.exports, 2);
    expect(t.takeException(), isNull);
  });
}
