import Flutter
import UIKit
import UserNotifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Dart side: lib/services/lock_screen.dart.
  private var liveActivityChannel: FlutterMethodChannel?
  /// Dart side: lib/services/launch_actions.dart.
  private var shortcutsChannel: FlutterMethodChannel?

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

    // A dispatch picked in Shortcuts or Siri (DispatchIntent.swift). Dart
    // takes it on boot, and again whenever it is told one has arrived.
    let shortcuts = FlutterMethodChannel(
      name: "telos/shortcuts", binaryMessenger: registrar.messenger())
    shortcuts.setMethodCallHandler { call, result in
      switch call.method {
      case "takePending":
        result(ShortcutRelay.shared.take())
      case "publish":
        // The recent dispatches and the live run, for the widget and the
        // Shortcuts action. Written to the App Group the widget can read.
        let args = call.arguments as? [String: Any] ?? [:]
        let dispatches = (args["dispatches"] as? [[String: Any]] ?? []).compactMap {
          row -> WidgetStore.Dispatch? in
          guard let key = row["key"] as? String, let title = row["title"] as? String
          else { return nil }
          return WidgetStore.Dispatch(
            key: key, title: title,
            subtitle: row["subtitle"] as? String ?? "",
            accent: (row["accent"] as? NSNumber)?.uint32Value ?? 0xFFF5A623)
        }
        var run: WidgetStore.Run?
        if let r = args["run"] as? [String: Any],
          let name = r["sectorName"] as? String,
          let endsAtMs = (r["endsAtMs"] as? NSNumber)?.doubleValue
        {
          run = WidgetStore.Run(
            sectorName: name,
            accent: (r["accent"] as? NSNumber)?.uint32Value ?? 0xFFF5A623,
            endsAt: Date(timeIntervalSince1970: endsAtMs / 1000))
        }
        WidgetStore.write(dispatches: dispatches, run: run)
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    ShortcutRelay.shared.ping = { [weak shortcuts] in
      DispatchQueue.main.async { shortcuts?.invokeMethod("pending", arguments: nil) }
    }
    shortcutsChannel = shortcuts

    // A tap on the Dispatch widget arrives as a telos://dispatch/ link. It
    // goes through the same relay as Shortcuts, so Dart starts every run the
    // same way. Registered as a plugin scene delegate rather than overriding
    // FlutterSceneDelegate, which handles URLs of its own.
    if #available(iOS 13.0, *) {
      registrar.addSceneDelegate(widgetLinks)
    }
  }

  private let widgetLinks = WidgetLinkRelay()
}

/// Hands telos://dispatch/ links from the widget to ShortcutRelay: on a cold
/// launch through the scene's connection options, otherwise as they open.
final class WidgetLinkRelay: NSObject, FlutterSceneLifeCycleDelegate {
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    relay(connectionOptions?.urlContexts ?? [])
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    relay(URLContexts)
  }

  private func relay(_ contexts: Set<UIOpenURLContext>) -> Bool {
    guard let key = contexts.lazy.compactMap({ WidgetStore.key(from: $0.url) }).first
    else { return false }
    ShortcutRelay.shared.request(key)
    return true
  }
}
