import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Dart side: lib/services/lock_screen.dart.
  private var liveActivityChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by flutter_local_notifications so the expedition-complete alert
    // is delivered while the app is in the foreground too. The conditional cast
    // is the form the plugin documents.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TelosLiveActivity")
    else { return }
    let channel = FlutterMethodChannel(
      name: "telos/live_activity", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "start":
        guard let args = call.arguments as? [String: Any],
          let sectorName = args["sectorName"] as? String,
          let designation = args["designation"] as? String,
          let accent = (args["accent"] as? NSNumber)?.uint32Value,
          let startedAtMs = (args["startedAtMs"] as? NSNumber)?.doubleValue,
          let endsAtMs = (args["endsAtMs"] as? NSNumber)?.doubleValue
        else {
          result(FlutterError(code: "bad_args", message: "start needs a full run", details: nil))
          return
        }
        Task {
          await ExpeditionLiveActivity.start(
            sectorName: sectorName,
            designation: designation,
            accent: accent,
            startedAt: Date(timeIntervalSince1970: startedAtMs / 1000),
            endsAt: Date(timeIntervalSince1970: endsAtMs / 1000))
          result(nil)
        }
      case "end":
        Task {
          await ExpeditionLiveActivity.end()
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    liveActivityChannel = channel
  }
}
