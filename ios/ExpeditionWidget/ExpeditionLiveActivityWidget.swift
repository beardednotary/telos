import ActivityKit
import SwiftUI
import WidgetKit

/// The session screen, cut down to what survives on a lock screen: the
/// sector in its own colour, the countdown, and the progress bar.
///
/// Every moving part here is driven by the system clock (Text(timerInterval:)
/// and ProgressView(timerInterval:)), and the switch to RETURNED is driven by
/// the stale date, so none of it needs the app to run.
struct ExpeditionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ExpeditionAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Palette.black)
                .activitySystemActionForegroundColor(Palette.text)
        } dynamicIsland: { context in
            let accent = Palette.accent(context.attributes.accent)
            let returned = context.isStale
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.attributes.designation)
                            .font(Typeface.micro)
                            .tracking(1.6)
                            .foregroundStyle(accent)
                        Text(context.attributes.sectorName)
                            .font(Typeface.name(15))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: context.state, returned: returned, size: 26)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RunProgress(state: context.state, returned: returned, accent: accent)
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                }
            } compactLeading: {
                // The session screen's status square, in the sector's colour.
                Rectangle()
                    .fill(returned ? Palette.good : accent)
                    .frame(width: 7, height: 7)
            } compactTrailing: {
                Countdown(state: context.state, returned: returned, size: 14)
                    .frame(maxWidth: 52)
            } minimal: {
                ProgressView(
                    timerInterval: context.state.startedAt...context.state.endsAt,
                    countsDown: false
                ) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(returned ? Palette.good : accent)
            }
            .keylineTint(accent)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<ExpeditionAttributes>

    var body: some View {
        let accent = Palette.accent(context.attributes.accent)
        let returned = context.isStale

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(context.attributes.designation)
                    .font(Typeface.micro)
                    .tracking(1.6)
                    .foregroundStyle(accent)
                Spacer()
                Rectangle()
                    .fill(returned ? Palette.good : Palette.amber)
                    .frame(width: 6, height: 6)
                Text(returned ? "RETURNED" : "IN TRANSIT")
                    .font(Typeface.micro)
                    .tracking(1.6)
                    .foregroundStyle(returned ? Palette.good : Palette.amber)
            }

            HStack(alignment: .lastTextBaseline) {
                Text(context.attributes.sectorName)
                    .font(Typeface.name(18))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 12)
                Countdown(state: context.state, returned: returned, size: 38)
            }

            RunProgress(state: context.state, returned: returned, accent: accent)
        }
        .padding(16)
    }
}

/// Counts down on its own. Once the run is over it is replaced with a fixed
/// 00:00 in green, matching the session screen's EXPEDITION COMPLETE state.
private struct Countdown: View {
    let state: ExpeditionAttributes.ContentState
    let returned: Bool
    let size: CGFloat

    var body: some View {
        Group {
            if returned {
                Text("00:00")
                    .foregroundStyle(Palette.good)
            } else {
                Text(timerInterval: state.startedAt...state.endsAt, countsDown: true)
                    .foregroundStyle(Palette.text)
            }
        }
        .font(Typeface.clock(size))
        .monospacedDigit()
        // A timer Text claims the widest string it could ever show; pin it
        // to the trailing edge so short times do not float in the middle.
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
    }
}

private struct RunProgress: View {
    let state: ExpeditionAttributes.ContentState
    let returned: Bool
    let accent: Color

    var body: some View {
        ProgressView(
            timerInterval: state.startedAt...state.endsAt,
            countsDown: false
        ) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(returned ? Palette.good : accent)
    }
}

/// The subset of lib/theme/telos_theme.dart the lock screen uses.
private enum Palette {
    static let black = Color(argb: 0xFF0B0C0E)
    static let text = Color(argb: 0xFFE6E8EB)
    static let amber = Color(argb: 0xFFF5A623)
    static let good = Color(argb: 0xFF3DD68C)

    static func accent(_ argb: UInt32) -> Color { Color(argb: argb) }
}

/// The same fonts as the app, bundled into the extension (see its Info.plist).
/// If one ever fails to register, SwiftUI falls back to the system face.
private enum Typeface {
    static let micro = Font.custom("JetBrainsMono-Regular", size: 10)

    /// The countdown: Light, like T.big.
    static func clock(_ size: CGFloat) -> Font {
        .custom("JetBrainsMono-Light", size: size)
    }

    /// Sector names: Syne at its heavy end, like T.display.
    static func name(_ size: CGFloat) -> Font {
        .custom("Syne-Bold", size: size)
    }
}

private extension Color {
    init(argb: UInt32) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}
