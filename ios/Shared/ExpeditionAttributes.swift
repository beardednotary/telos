import ActivityKit
import Foundation

/// The live run as the lock screen sees it. This one file is compiled into
/// both Runner (which starts the activity) and ExpeditionWidget (which draws
/// it), so the two sides can never disagree about the shape of the payload.
///
/// Nothing in here changes during a run: the countdown and the progress bar
/// are driven by the system clock from [startedAt]/[endsAt], so the app never
/// has to wake up to push an update. That matters for an app whose whole
/// premise is that it stays closed.
@available(iOS 16.1, *)
struct ExpeditionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var endsAt: Date
    }

    /// "MOSSWOOD VERGE"
    var sectorName: String
    /// "SECTOR 01"
    var designation: String
    /// The sector's accent as 0xAARRGGBB, exactly as content.dart stores it.
    var accent: UInt32
}
