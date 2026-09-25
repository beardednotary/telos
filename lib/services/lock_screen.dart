import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The live run on the lock screen: a Live Activity on iOS, an ongoing
/// countdown notification on Android.
///
/// Both count down on their own from the start and end times, so the app is
/// never woken to update them. Looking at the lock screen costs nothing; only
/// opening Telos is a check-in, same as before.
abstract class LockScreen {
  Future<void> show({
    required DateTime startedAt,
    required DateTime endsAt,
    required String sector,
    required String designation,
    required int accent,
  });

  Future<void> clear();
}

/// Used in tests and on platforms without a lock screen.
class NoopLockScreen implements LockScreen {
  @override
  Future<void> show({
    required DateTime startedAt,
    required DateTime endsAt,
    required String sector,
    required String designation,
    required int accent,
  }) async {}

  @override
  Future<void> clear() async {}
}

class SystemLockScreen implements LockScreen {
  SystemLockScreen([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Swift side: ios/Runner/AppDelegate.swift.
  static const _channel = MethodChannel('telos/live_activity');

  /// Separate from the expedition-complete alert (id 1) so each can be
  /// cancelled without touching the other.
  static const int _ongoingId = 2;
  static const String _androidChannelId = 'telos.transit';

  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> show({
    required DateTime startedAt,
    required DateTime endsAt,
    required String sector,
    required String designation,
    required int accent,
  }) async {
    final left = endsAt.difference(DateTime.now());
    if (left <= Duration.zero) return;

    try {
      if (_ios) {
        await _channel.invokeMethod<void>('start', {
          'sectorName': sector,
          'designation': designation,
          'accent': accent,
          'startedAtMs': startedAt.millisecondsSinceEpoch,
          'endsAtMs': endsAt.millisecondsSinceEpoch,
        });
      } else if (_android) {
        // Relies on the plugin having been initialised by LocalAlerts, which
        // the controller always does first (boot, and permission at dispatch).
        await _plugin.show(
          id: _ongoingId,
          title: sector,
          body: '$designation  ·  IN TRANSIT',
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannelId,
              'Expedition in transit',
              channelDescription:
                  'The countdown for a run in progress, on the lock screen.',
              // Low: it sits there silently. The one interruption Telos
              // makes is still the expedition-complete alert.
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
              autoCancel: false,
              onlyAlertOnce: true,
              showWhen: true,
              when: endsAt.millisecondsSinceEpoch,
              usesChronometer: true,
              chronometerCountDown: true,
              // A chronometer runs on past zero into negative time. Drop the
              // notification the moment the run ends; the complete alert
              // takes over from there.
              timeoutAfter: left.inMilliseconds,
              color: Color(accent),
              visibility: NotificationVisibility.public,
              category: AndroidNotificationCategory.progress,
            ),
          ),
        );
      }
    } catch (e) {
      // The lock screen is a nicety. A refused Live Activity or a missing
      // channel must never stop a run from starting.
      debugPrint('lock screen show failed: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      if (_ios) {
        await _channel.invokeMethod<void>('end');
      } else if (_android) {
        await _plugin.cancel(id: _ongoingId);
      }
    } catch (e) {
      debugPrint('lock screen clear failed: $e');
    }
  }
}
