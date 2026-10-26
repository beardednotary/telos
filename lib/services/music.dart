import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Camp music. One looped track, played only while the player is at camp or
/// reading a debrief - never during a run, which is the whole point of the
/// app - and only when they have turned it on. The same switch covers the
/// chime when a squad comes home.
///
/// It is meant to sit under whatever the player already listens to, not
/// replace it: on iOS it uses the ambient session, so the silent switch
/// mutes it and Spotify or a podcast keeps playing; on Android it plays as
/// media without taking audio focus.
abstract class Music {
  /// Starts or resumes the loop. Safe to call repeatedly.
  Future<void> play();

  /// Pauses where it is, so coming back to camp picks the track up again.
  /// [fade] eases it out; leaving the app passes false and stops at once.
  Future<void> pause({bool fade = true});

  /// Once, as a squad comes home and the debrief opens.
  Future<void> chime();
}

/// Used in tests and on platforms without audio.
class NoopMusic implements Music {
  @override
  Future<void> play() async {}

  @override
  Future<void> pause({bool fade = true}) async {}

  @override
  Future<void> chime() async {}
}

class CampMusic implements Music {
  CampMusic([AudioPlayer? player, AudioPlayer? chimePlayer])
      : _player = player,
        _chimePlayer = chimePlayer;

  /// Pixabay content licence: free to use in an app, no attribution
  /// required. The credit is shown under Settings anyway.
  static const asset = 'music/kulakovka-epic-motivation-618588.mp3';
  static const credit = 'Music by Tony Vodnik (kulakovka) from Pixabay';

  /// Made for Telos: docs/design/return-chime/chime.py.
  static const chimeAsset = 'music/return-chime.wav';
  static const double chimeVolume = 0.5;

  /// Under the player's own audio, not over it.
  static const double volume = 0.35;

  /// Starting a run is the one moment the app asks for quiet, so the track
  /// gets out of the way gently rather than cutting off on the tap.
  static const fadeIn = Duration(milliseconds: 2500);
  static const fadeOut = Duration(seconds: 2);
  static const _tick = Duration(milliseconds: 50);

  AudioPlayer? _player;
  AudioPlayer? _chimePlayer;
  bool _ready = false;
  bool _chimeReady = false;

  /// Whether the track is wanted. It can still be sounding, fading out.
  bool _playing = false;

  /// Whether the player is running at all, fade-outs included.
  bool _sounding = false;

  /// How far up the fade is, 0 to 1. Squared on the way to the volume, since
  /// a linear ramp sounds like it does nothing and then drops off a cliff.
  double _level = 0;
  Timer? _fade;
  bool _fadingIn = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<AudioPlayer> _setUp() async {
    final player = _player ??= AudioPlayer();
    if (_ready) return player;
    await player.setAudioContext(_context);
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setVolume(0);
    await player.setSource(AssetSource(asset));
    _ready = true;
    return player;
  }

  static AudioContext get _context => AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.media,
          contentType: AndroidContentType.music,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextConfig(
          respectSilence: true,
          focus: AudioContextConfigFocus.mixWithOthers,
        ).buildIOS(),
      );

  @override
  Future<void> chime() async {
    if (!_supported) return;
    try {
      final player = _chimePlayer ??= AudioPlayer();
      if (!_chimeReady) {
        await player.setAudioContext(_context);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(chimeVolume);
        await player.setSource(AssetSource(chimeAsset));
        _chimeReady = true;
      }
      await player.seek(Duration.zero);
      await player.resume();
    } catch (e) {
      debugPrint('Return chime unavailable: $e');
    }
  }

  @override
  Future<void> play() async {
    if (!_supported || _playing) return;
    _playing = true;
    try {
      final player = await _setUp();
      // Paused again while the track was loading.
      if (!_playing) return;
      if (!_sounding) {
        _sounding = true;
        _level = 0;
        await player.setVolume(0);
        await player.resume();
      }
      // Caught mid fade-out, this turns it around from where it is.
      _rampTo(1, fadeIn);
    } catch (e) {
      // Music is decoration. A codec or session failure must never reach
      // the player as an error.
      _playing = false;
      _sounding = false;
      debugPrint('Camp music unavailable: $e');
    }
  }

  @override
  Future<void> pause({bool fade = true}) async {
    if (!_supported) return;
    _playing = false;
    if (!_sounding) return;
    if (fade) {
      if (_fade == null || _fadingIn) _rampTo(0, fadeOut, then: _stop);
    } else {
      await _stop();
    }
  }

  Future<void> _stop() async {
    _fade?.cancel();
    _fade = null;
    _sounding = false;
    _level = 0;
    try {
      await _player?.pause();
    } catch (e) {
      debugPrint('Camp music pause failed: $e');
    }
  }

  /// Moves [_level] to [target] at the rate a full fade over [over] would,
  /// so turning a half-finished fade around takes half the time.
  void _rampTo(double target, Duration over, {Future<void> Function()? then}) {
    _fade?.cancel();
    _fadingIn = target > _level;
    final step = _tick.inMicroseconds / over.inMicroseconds;
    _fade = Timer.periodic(_tick, (timer) async {
      _level = _fadingIn
          ? (_level + step).clamp(0.0, target)
          : (_level - step).clamp(target, 1.0);
      final done = _level == target;
      if (done) {
        timer.cancel();
        _fade = null;
      }
      try {
        await _player?.setVolume(volume * _level * _level);
      } catch (e) {
        debugPrint('Camp music fade failed: $e');
      }
      // Unless the track was wanted back while that last step went out.
      if (done && then != null && !_playing) await then();
    });
  }
}
