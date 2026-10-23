import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/screens/backup_screen.dart';
import 'package:telos/services/music.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';

import 'support/archive_fixtures.dart' show MemoryBackupFiles;

/// Records whether the music should be playing right now.
class FakeMusic implements Music {
  bool playing = false;

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> pause() async => playing = false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeMusic music;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    music = FakeMusic();
  });

  Future<GuildController> boot({bool onboarded = true}) async {
    final c = GuildController(Persistence(), music: music);
    await c.boot();
    c.g.onboarded = onboarded;
    addTearDown(c.dispose);
    return c;
  }

  test('silent until the player turns it on', () async {
    final c = await boot();
    c.notifyListeners();
    expect(music.playing, isFalse);
    await c.setMusic(true);
    expect(music.playing, isTrue);
    await c.setMusic(false);
    expect(music.playing, isFalse);
  });

  test('never during a run; back on for the debrief', () async {
    final c = await boot();
    await c.setMusic(true);
    await c.startRun(
        sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
    expect(music.playing, isFalse);
    await c.finishRun(recalled: true);
    expect(c.pendingDebrief, isNotNull);
    expect(music.playing, isTrue);
  });

  test('not over the first-launch briefing', () async {
    final c = await boot(onboarded: false);
    await c.setMusic(true);
    expect(music.playing, isFalse);
    await c.completeOnboarding();
    expect(music.playing, isTrue);
  });

  test('stops when the app goes to the background', () async {
    final c = await boot();
    await c.setMusic(true);
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(music.playing, isFalse);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(music.playing, isTrue);
  });

  test('the choice survives a restart, and old saves default to off', () {
    final g = GuildState.fresh()..musicOn = true;
    expect(GuildState.fromJson(g.toJson()).musicOn, isTrue);
    expect(GuildState.fromJson(g.toJson()..remove('musicOn')).musicOn,
        isFalse);
  });

  testWidgets('the Settings switch turns it on and credits the track',
      (t) async {
    final c = await boot();
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(
          theme: T.theme(),
          home: BackupScreen(files: MemoryBackupFiles())),
    ));
    await t.pumpAndSettle();
    expect(find.textContaining('Tony Vodnik'), findsOneWidget);
    await t.tap(find.byKey(const Key('settings-music')));
    await t.pumpAndSettle();
    expect(c.g.musicOn, isTrue);
    expect(music.playing, isTrue);
  });

  test('the bundled track is the one the player loads', () async {
    final data = await rootBundle.load('assets/${CampMusic.asset}');
    expect(data.lengthInBytes, greaterThan(1000000));
  });
}
