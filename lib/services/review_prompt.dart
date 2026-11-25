import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Asks the App Store to show its rating prompt.
///
/// iOS decides whether the prompt actually appears (at most three times a
/// year per person, and never in TestFlight), so a request is a suggestion,
/// not a promise. Nothing in Telos waits on it or reads its outcome.
abstract class ReviewPrompt {
  Future<void> request();
}

/// Used in tests and on platforms without the App Store prompt.
class NoopReviewPrompt implements ReviewPrompt {
  @override
  Future<void> request() async {}
}

class SystemReviewPrompt implements ReviewPrompt {
  /// Swift side: ios/Runner/AppDelegate.swift.
  static const _channel = MethodChannel('telos/review');

  /// Long enough for the report to finish crossfading back to camp, so the
  /// prompt lands on camp rather than over the screen being dismissed.
  static const _settle = Duration(milliseconds: 600);

  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> request() async {
    if (!_ios) return;
    await Future<void>.delayed(_settle);
    await _channel.invokeMethod<void>('request');
  }
}
