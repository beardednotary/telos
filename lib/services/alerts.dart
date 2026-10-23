import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/caravan.dart';

/// One local notification: "your squad is back". No streak nagging, no daily
/// reminders. The app has exactly one thing worth interrupting you for, and
/// it only fires when the run you started is over.
///
/// The one addition is the caravan, and only for a player who has scheduled
/// it: a notice when it reaches the gate and one when it leaves, at the time
/// they chose themselves. See models/caravan.dart.
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

  /// Replaces every pending caravan notice with [notices]. An empty list
  /// clears them.
  Future<void> scheduleCaravan(List<CaravanNotice> notices);
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

  @override
  Future<void> scheduleCaravan(List<CaravanNotice> notices) async {}
}

class LocalAlerts implements Alerts {
  LocalAlerts([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const int _returnId = 1;
  static const String _channelId = 'telos.expedition';

  /// Caravan notices take a block of ids of their own, so replacing them
  /// never touches the return alert.
  static const int _caravanBase = 100;
  static const int _caravanSlots = 32;
  static const String _caravanChannelId = 'telos.caravan';

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

  @override
  Future<void> scheduleCaravan(List<CaravanNotice> notices) async {
    if (!_supported) return;
    await init();
    for (var i = 0; i < _caravanSlots; i++) {
      await _plugin.cancel(id: _caravanBase + i);
    }
    final now = DateTime.now();
    var slot = 0;
    for (final n in notices) {
      if (slot >= _caravanSlots) break;
      if (!n.at.isAfter(now)) continue;
      // Each notice is a one-off at an absolute instant, computed from local
      // wall-clock time by the caller, so UTC is as safe here as it is for
      // the return alert. Re-armed on every open rather than repeating.
      await _plugin.zonedSchedule(
        id: _caravanBase + slot++,
        scheduledDate: tz.TZDateTime.from(n.at, tz.UTC),
        title: n.title,
        body: n.body,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _caravanChannelId,
            'Caravan',
            channelDescription:
                'Only if you schedule the caravan: when it reaches the gate, '
                'and when it leaves.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
      );
    }
  }
}
