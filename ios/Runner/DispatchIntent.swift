import AppIntents
import Foundation

/// "Dispatch in Telos": the Shortcuts and Siri way to send a recent dispatch
/// again. Attach it to a Focus in the Shortcuts app and turning on Focus
/// sends the squad.
///
/// Swift never starts a run itself. It opens the app and hands the pick to
/// Dart (lib/services/launch_actions.dart), which starts it exactly as SEND
/// AGAIN does, so the run start, the alert and the Live Activity each exist
/// once.

/// Holds a pick until Dart asks for it. On a cold start the intent runs
/// before the Flutter engine does, so a pick is always parked here first and
/// Dart takes it on boot; when the app is already running, [ping] tells Dart
/// to come and take it now.
final class ShortcutRelay {
  static let shared = ShortcutRelay()

  private var pending: String?
  var ping: (() -> Void)?

  func request(_ key: String) {
    pending = key
    ping?()
  }

  func take() -> String? {
    defer { pending = nil }
    return pending
  }
}

/// The list Dart publishes whenever it changes - the same recent dispatches
/// SEND AGAIN shows - read from the App Group it shares with the widget.
@available(iOS 16.0, *)
private func publishedDispatches() -> [DispatchEntity] {
  WidgetStore.dispatches().map {
    DispatchEntity(id: $0.key, title: $0.title, subtitle: $0.subtitle)
  }
}

@available(iOS 16.0, *)
struct DispatchEntity: AppEntity {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Dispatch"
  static let defaultQuery = DispatchQuery()

  let id: String
  let title: String
  let subtitle: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
  }
}

@available(iOS 16.0, *)
struct DispatchQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [DispatchEntity] {
    publishedDispatches().filter { identifiers.contains($0.id) }
  }

  func suggestedEntities() async throws -> [DispatchEntity] {
    publishedDispatches()
  }
}

@available(iOS 16.0, *)
struct DispatchIntent: AppIntent {
  static let title: LocalizedStringResource = "Dispatch"
  static let description = IntentDescription(
    "Sends one of your recent dispatches out again. Leave it empty to repeat the last one.")
  static let openAppWhenRun = true

  @Parameter(title: "Dispatch")
  var dispatch: DispatchEntity?

  @MainActor
  func perform() async throws -> some IntentResult {
    ShortcutRelay.shared.request(dispatch?.id ?? "latest")
    return .result()
  }
}

@available(iOS 16.4, *)
struct TelosShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: DispatchIntent(),
      phrases: [
        "Dispatch in \(.applicationName)",
        "Send the squad out in \(.applicationName)",
      ],
      shortTitle: "Dispatch",
      systemImageName: "arrow.up.right")
  }
}
