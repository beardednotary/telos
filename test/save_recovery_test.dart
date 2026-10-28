import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/main.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/screens/onboarding_screen.dart';
import 'package:telos/screens/unreadable_save_screen.dart';
import 'package:telos/services/backup.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';

const _broken = '{"guildName":"Established Guild",broken';

class _FakeFiles extends BackupFiles {
  final exported = <String>[];
  bool fail = false;

  @override
  Future<String> exportUnreadable(String raw,
      {Rect? sharePositionOrigin}) async {
    if (fail) throw StateError('share sheet failed');
    exported.add(raw);
    return 'unreadable.json';
  }
}

Future<List<String>> _kept() async {
  final prefs = await SharedPreferences.getInstance();
  return [
    for (final k in prefs.getKeys())
      if (k.startsWith('telos.save.v1.unreadable.')) prefs.getString(k)!,
  ];
}

Future<GuildController> _bootBroken() async {
  SharedPreferences.setMockInitialValues({'telos.save.v1': _broken});
  final c = GuildController(Persistence());
  await c.boot();
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an unreadable save is kept before the fresh guild is saved over it',
      () async {
    final c = await _bootBroken();
    addTearDown(c.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(c.g.guildName, GuildState.fresh().guildName);
    expect(await _kept(), [_broken]);
    expect(c.unreadableSave, _broken);
  });

  test('dismissing the notice keeps the save and does not ask again',
      () async {
    final c = await _bootBroken();
    addTearDown(c.dispose);
    await c.dismissUnreadableSave();
    expect(c.unreadableSave, isNull);

    // The fresh guild is readable, so the next launch has nothing to report.
    final next = GuildController(Persistence());
    addTearDown(next.dispose);
    await next.boot();
    expect(next.unreadableSave, isNull);
    expect(await _kept(), [_broken]);
  });

  test('a readable save raises no notice', () async {
    SharedPreferences.setMockInitialValues({});
    final c = GuildController(Persistence());
    addTearDown(c.dispose);
    await c.boot();
    expect(c.unreadableSave, isNull);
    expect(await _kept(), isEmpty);
  });

  testWidgets('the notice comes before the briefing', (t) async {
    final c = await _bootBroken();
    addTearDown(c.dispose);
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(theme: T.theme(), home: const Root()),
    ));
    await t.pumpAndSettle();
    expect(find.byType(UnreadableSaveScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);

    await t.tap(find.byKey(const Key('unreadable-continue')));
    await t.pumpAndSettle();
    expect(find.byType(UnreadableSaveScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('saving a copy hands over the save exactly as found',
      (t) async {
    final c = await _bootBroken();
    addTearDown(c.dispose);
    final files = _FakeFiles()..fail = true;
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(
          theme: T.theme(), home: UnreadableSaveScreen(files: files)),
    ));

    await t.tap(find.byKey(const Key('unreadable-export')));
    await t.pump();
    expect(find.byKey(const Key('unreadable-error')), findsOneWidget);

    files.fail = false;
    await t.tap(find.byKey(const Key('unreadable-export')));
    await t.pump();
    expect(files.exported, [_broken]);
    expect(find.byKey(const Key('unreadable-error')), findsNothing);
    expect(find.text('Save another copy'), findsOneWidget);
  });
}
