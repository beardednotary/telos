import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Camp music. One looped track, played only while the player is at camp or
/// reading a debrief - never during a run, which is the whole point of the
/// app - and only when they have turned it on.
///
/// It is meant to sit under whatever the player already listens to, not
/// replace it: on iOS it uses the ambient session, so the silent switch
/// mutes it and Spotify or a podcast keeps playing; on Android it plays as
/// media without taking audio focus.
abstract class Music {
  /// Starts or resumes the loop. Safe to call repeatedly.
  Future<void> play();

  /// Pauses where it is, so coming back to camp picks the track up again.
  Future<void> pause();
}

/// Used in tests and on platforms without audio.
class NoopMusic implements Music {
  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}
}

class CampMusic implements Music {
  CampMusic([AudioPlayer? player]) : _player = player;

  /// Pixabay content licence: free to use in an app, no attribution
  /// required. The credit is shown under Settings anyway.
  static const asset = 'music/kulakovka-epic-motivation-618588.mp3';
  static const credit = 'Music by Tony Vodnik (kulakovka) from Pixabay';

  /// Under the player's own audio, not over it.
  static const double volume = 0.35;

  AudioPlayer? _player;
  bool _ready = false;
  bool _playing = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<AudioPlayer> _setUp() async {
    final player = _player ??= AudioPlayer();
    if (_ready) return player;
    await player.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        usageType: AndroidUsageType.media,
        contentType: AndroidContentType.music,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextConfig(
        respectSilence: true,
        focus: AudioContextConfigFocus.mixWithOthers,
      ).buildIOS(),
    ));
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setVolume(volume);
    await player.setSource(AssetSource(asset));
    _ready = true;
    return player;
  }

  @override
  Future<void> play() async {
    if (!_supported || _playing) return;
    _playing = true;
    try {
      await (await _setUp()).resume();
    } catch (e) {
      // Music is decoration. A codec or session failure must never reach
      // the player as an error.
      _playing = false;
      debugPrint('Camp music unavailable: $e');
    }
  }

  @override
  Future<void> pause() async {
    if (!_supported || !_playing) return;
    _playing = false;
    try {
      await _player?.pause();
    } catch (e) {
      debugPrint('Camp music pause failed: $e');
    }
  }
}
