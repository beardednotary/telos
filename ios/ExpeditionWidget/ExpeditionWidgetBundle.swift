import SwiftUI
import WidgetKit

/// The extension exists for one thing: the live run on the lock screen and
/// in the Dynamic Island. There are deliberately no home screen widgets -
/// Telos has nothing worth glancing at while no squad is out.
@main
struct ExpeditionWidgetBundle: WidgetBundle {
    var body: some Widget {
        ExpeditionLiveActivityWidget()
    }
}
