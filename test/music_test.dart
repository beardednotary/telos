import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telos/models/guild_state.dart';
import 'package:telos/screens/backup_screen.dart';
import 'package:telos/screens/launch_screen.dart';
import 'package:telos/main.dart';
import 'package:telos/services/music.dart';
import 'package:telos/services/persistence.dart';
import 'package:telos/state/guild_controller.dart';
import 'package:telos/theme/telos_theme.dart';

import 'support/archive_fixtures.dart' show MemoryBackupFiles;

/// Records whether the music should be playing right now.
class FakeMusic implements Music {
  bool playing = false;
  bool? faded;
  int chimes = 0;

  @override
  Future<void> chime() async => chimes++;

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> pause({bool fade = true}) async {
    if (playing) faded = fade;
    playing = false;
  }
}

/// Records every volume the track is set to, and whether it is running.
class FakePlayer implements AudioPlayer {
  final volumes = <double>[];
  bool running = false;

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> resume() async => running = true;

  @override
  Future<void> pause() async => running = false;

  /// Audio context, release mode and source: nothing to record.
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
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

  test('eases out for a run; cut when the player leaves the app', () async {
    final c = await boot();
    await c.setMusic(true);
    await c.startRun(
        sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
    expect(music.faded, isTrue);
    await c.finishRun(recalled: true);
    expect(music.playing, isTrue);
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(music.faded, isFalse);
  });

  testWidgets('the track fades in, and fades out before it stops', (t) async {
    final player = FakePlayer();
    final m = CampMusic(player);
    await m.play();
    expect(player.running, isTrue);
    expect(player.volumes.last, 0);
    // Squared, so the first half of the fade is the quiet half.
    await t.pump(CampMusic.fadeIn ~/ 2);
    expect(player.volumes.last,
        inExclusiveRange(0, CampMusic.volume / 2));
    await t.pump(CampMusic.fadeIn);
    expect(player.volumes.last, closeTo(CampMusic.volume, 1e-9));

    await m.pause();
    await t.pump(CampMusic.fadeOut ~/ 2);
    expect(player.running, isTrue, reason: 'still fading out');
    expect(player.volumes.last, lessThan(CampMusic.volume));
    await t.pump(CampMusic.fadeOut);
    expect(player.running, isFalse);
    expect(player.volumes.last, 0);
  });

  testWidgets('wanted back mid-fade, it turns around; leaving cuts it',
      (t) async {
    final player = FakePlayer();
    final m = CampMusic(player);
    await m.play();
    await t.pump(CampMusic.fadeIn);
    await m.pause();
    await t.pump(CampMusic.fadeOut ~/ 2);
    await m.play();
    await t.pump(CampMusic.fadeIn);
    expect(player.running, isTrue);
    expect(player.volumes.last, closeTo(CampMusic.volume, 1e-9));

    await m.pause(fade: false);
    expect(player.running, isFalse);
    await t.pump(CampMusic.fadeOut);
    expect(player.running, isFalse);
  });

  testWidgets('held under the launch screen, then up as camp shows',
      (t) async {
    final c = GuildController(Persistence(), music: music, launchScreen: true);
    addTearDown(c.dispose);
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(
          theme: T.theme(), home: const LaunchScreen(child: Root())),
    ));
    expect(find.byKey(const Key('launch-screen')), findsOneWidget);
    await c.boot();
    c.g
      ..onboarded = true
      ..musicOn = true;
    c.notifyListeners();
    await t.pump();
    expect(music.playing, isFalse);

    // Test images never decode, so the intro starts on the grace timer.
    await t.pump(LaunchScreen.decodeGrace);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('launch-screen')), findsNothing);
    expect(find.byKey(const Key('camp-dispatch')), findsOneWidget);
    expect(music.playing, isTrue);
  });

  test('a chime when a squad comes home, with the music on', () async {
    final c = await boot();
    await c.startRun(
        sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
    await c.finishRun(recalled: true);
    expect(music.chimes, 0, reason: 'music is off');
    await c.dismissDebrief();

    await c.setMusic(true);
    await c.startRun(
        sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
    await c.finishRun(recalled: true);
    expect(music.chimes, 1);
  });

  testWidgets('the chime player plays the bundled chime', (t) async {
    final chime = FakePlayer();
    await CampMusic(FakePlayer(), chime).chime();
    expect(chime.running, isTrue);
    expect(chime.volumes.single, CampMusic.chimeVolume);
    final data = await rootBundle.load('assets/${CampMusic.chimeAsset}');
    expect(data.lengthInBytes, greaterThan(10000));
  });

  testWidgets('camp offers the music once, after the first expedition',
      (t) async {
    final c = await boot();
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(theme: T.theme(), home: const Root()),
    ));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('music-offer')), findsNothing,
        reason: 'the first visit is for getting a squad out');

    await c.startRun(
        sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
    await c.finishRun(recalled: true);
    await c.dismissDebrief();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('music-offer-yes')));
    await t.pumpAndSettle();
    expect(c.g.musicOn, isTrue);
    expect(music.playing, isTrue);
    expect(find.byKey(const Key('music-offer')), findsNothing);

    // Turned off again in Settings, it does not ask a second time.
    await c.setMusic(false);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('music-offer')), findsNothing);
  });

  test('"No thanks" settles it', () async {
    final c = await boot();
    expect(c.offerMusic, isFalse);
    await c.startRun(
        sectorId: 'mosswood', intent: '', squad: ['a1'], minutes: 25);
    await c.finishRun(recalled: true);
    expect(c.offerMusic, isTrue);
    await c.declineMusic();
    expect(c.offerMusic, isFalse);
    expect(c.g.musicOn, isFalse);
    expect(GuildState.fromJson(c.g.toJson()).musicOffered, isTrue);
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
