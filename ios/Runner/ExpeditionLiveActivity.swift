import ActivityKit
import Foundation

/// Starts and ends the lock screen countdown. Kept free of Flutter so the
/// channel in AppDelegate is only plumbing.
///
/// Live Activities need iOS 16.2 for the ActivityContent API; below that
/// every call is a no-op and the expedition-complete notification is still
/// the only signal, as before.
enum ExpeditionLiveActivity {
    static func start(
        sectorName: String,
        designation: String,
        accent: UInt32,
        startedAt: Date,
        endsAt: Date
    ) async {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard endsAt > Date() else { return }

        let attributes = ExpeditionAttributes(
            sectorName: sectorName,
            designation: designation,
            accent: accent
        )
        let state = ExpeditionAttributes.ContentState(
            startedAt: startedAt,
            endsAt: endsAt
        )

        // boot() calls this again on every cold start. If the activity for
        // this exact run is still up, leave it be rather than flashing it off
        // and on; anything else is left over from an earlier run and goes.
        let existing = Activity<ExpeditionAttributes>.activities
        if existing.count == 1, let only = existing.first,
           only.attributes.sectorName == sectorName,
           only.content.state == state,
           only.activityState == .active || only.activityState == .stale {
            return
        }
        await endAll()

        // The stale date is the moment the squad gets back: the widget reads
        // context.isStale to flip to RETURNED without the app running.
        let content = ActivityContent(state: state, staleDate: endsAt)
        _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    static func end() async {
        guard #available(iOS 16.2, *) else { return }
        await endAll()
    }

    @available(iOS 16.2, *)
    private static func endAll() async {
        for activity in Activity<ExpeditionAttributes>.activities {
            // Immediate: once the debrief is open the countdown has nothing
            // left to say, and a lingering 00:00 would read as a stuck timer.
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
