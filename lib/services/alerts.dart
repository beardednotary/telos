import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One local notification: "your squad is back". Nothing else — no streak
/// nagging, no daily reminders. The app has exactly one thing worth
/// interrupting you for, and it only fires when the run you started is over.
abstract class Alerts {
  Future<void> init();

  /// Asks for permission. Called at the first dispatch, not at launch, so the
  /// prompt arrives with an obvious reason attached.
  Future<bool> requestPermission();

  Future<void> scheduleReturn({
    required DateTime at,
    required String sector,
    required String squad,
  });

  Future<void> cancel();
}

/// Used in tests and on platforms without notification support.
class NoopAlerts implements Alerts {
  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleReturn({
    required DateTime at,
    required String sector,
    required String squad,
  }) async {}

  @override
  Future<void> cancel() async {}
}

class LocalAlerts implements Alerts {
  LocalAlerts([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const int _returnId = 1;
  static const String _channelId = 'telos.expedition';

  /// Android and iOS both support this; the desktop/web targets exist only for
  /// previewing, so skip them rather than failing at launch.
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> init() async {
    if (!_supported || _ready) return;

    tzdata.initializeTimeZones();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permissions are requested later, at the first dispatch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await init();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true, badge: true) ??
        false;
  }

  @override
  Future<void> scheduleReturn({
    required DateTime at,
    required String sector,
    required String squad,
  }) async {
    if (!_supported) return;
    await init();
    await cancel();
    if (!at.isAfter(DateTime.now())) return;

    // The absolute instant is what matters for a one-shot timer, and
    // TZDateTime.from converts correctly, so UTC is safe here and saves
    // pulling in a device-timezone plugin.
    final when = tz.TZDateTime.from(at, tz.UTC);

    await _plugin.zonedSchedule(
      id: _returnId,
      scheduledDate: when,
      title: '$squad returned from $sector',
      body: 'Expedition complete. Open the debrief when you are ready.',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Expedition complete',
          channelDescription:
              'Fires once when a focus session you started has finished.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
    );
  }

  @override
  Future<void> cancel() async {
    if (!_supported) return;
    await _plugin.cancel(id: _returnId);
  }
}
