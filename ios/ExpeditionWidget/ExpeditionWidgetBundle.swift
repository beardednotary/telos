import SwiftUI
import WidgetKit

/// The live run on the lock screen and in the Dynamic Island, and the
/// Dispatch widget. There is still nothing to glance at while no squad is
/// out: the widget is a door into a run, not a view of the guild.
@main
struct ExpeditionWidgetBundle: WidgetBundle {
    var body: some Widget {
        ExpeditionLiveActivityWidget()
        DispatchWidget()
    }
}
