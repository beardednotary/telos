import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One recent dispatch as the system shows it outside the app.
class LaunchItem {
  const LaunchItem({
    required this.key,
    required this.title,
    required this.subtitle,
  });

  /// [Redeploy.key] - how a tap on this item finds its dispatch again.
  final String key;
  final String title;
  final String subtitle;

  Map<String, String> toJson() =>
      {'key': key, 'title': title, 'subtitle': subtitle};
}

/// The ways into a redeploy from outside the app: the long-press menu on the
/// app icon (both platforms), and the Shortcuts / Siri action (iOS).
///
/// All of them offer the same recent dispatches as SEND AGAIN on the home
/// screen, and all of them open the app to start the run. Starting in the
/// background would mean a second copy of the run start, the alert and the
/// Live Activity in Swift; opening costs nothing, since integrity's grace
/// period exists to cover dispatch.
abstract class LaunchActions {
  /// Replaces what the system offers. Called whenever the list may change.
  Future<void> publish(List<LaunchItem> items);

  /// Delivers the key of a dispatch the player picked outside the app, or
  /// [latest] for "whatever was sent last". Includes a pick that launched
  /// the app, so call this once the save is loaded.
  Future<void> listen(void Function(String key) onPick);

  static const latest = 'latest';
}

/// Used in tests and on platforms without either.
class NoopLaunchActions implements LaunchActions {
  @override
  Future<void> publish(List<LaunchItem> items) async {}

  @override
  Future<void> listen(void Function(String key) onPick) async {}
}

class SystemLaunchActions implements LaunchActions {
  static const _prefix = 'redeploy:';

  /// Read by the App Intents code (ios/Runner/DispatchIntent.swift) as the
  /// UserDefaults key `flutter.telos.launch_menu`, which is where the
  /// shared_preferences plugin stores it.
  static const menuKey = 'telos.launch_menu';

  static const _channel = MethodChannel('telos/shortcuts');

  final _quickActions = const QuickActions();

  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> publish(List<LaunchItem> items) async {
    try {
      await _quickActions.setShortcutItems([
        for (final i in items)
          ShortcutItem(
            type: '$_prefix${i.key}',
            // Android shows one line, so the detail goes in the title there.
            localizedTitle: _ios ? i.title : '${i.subtitle} · ${i.title}',
            localizedSubtitle: _ios ? i.subtitle : null,
          ),
      ]);
      if (_ios) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            menuKey, jsonEncode([for (final i in items) i.toJson()]));
      }
    } catch (e) {
      // A shortcut menu is a convenience; failing to set one must never
      // break a save.
      debugPrint('launch actions: publish failed: $e');
    }
  }

  @override
  Future<void> listen(void Function(String key) onPick) async {
    try {
      await _quickActions.initialize((type) {
        if (type.startsWith(_prefix)) onPick(type.substring(_prefix.length));
      });
    } catch (e) {
      debugPrint('launch actions: quick actions unavailable: $e');
    }
    if (!_ios) return;

    // A Shortcuts run is parked on the Swift side until Dart asks for it,
    // because on a cold start the intent can fire before this code exists.
    // Swift pings when one arrives while the app is already running.
    Future<void> take() async {
      final key = await _channel.invokeMethod<String>('takePending');
      if (key != null) onPick(key);
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pending') await take();
    });
    try {
      await take();
    } catch (e) {
      debugPrint('launch actions: shortcuts channel unavailable: $e');
    }
  }
}
