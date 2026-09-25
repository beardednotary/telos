import SwiftUI
import WidgetKit

/// A door into a run, not a window onto the guild.
///
/// Before a run it offers the recent dispatches, exactly as SEND AGAIN does,
/// and a tap sends one. While a squad is out it shows where, and when they
/// come back, as a clock time - nothing ticking, nothing to watch. It never
/// shows resources, levels or loot, and it looks the same on the first day
/// as after a month away: there is no "nothing sent lately" state.
struct DispatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DispatchWidget", provider: DispatchProvider()) { entry in
            DispatchWidgetView(entry: entry)
        }
        .configurationDisplayName("Dispatch")
        .description("Send a recent dispatch again in one tap.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct DispatchEntry: TimelineEntry {
    let date: Date
    let dispatches: [WidgetStore.Dispatch]
    /// Set only while the squad is actually out at [date].
    let run: WidgetStore.Run?
}

/// The app rewrites the store and reloads this whenever a dispatch or a run
/// changes, so the timeline never polls. The one change the app is not
/// around for - the squad coming back - is a second entry at that moment.
struct DispatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> DispatchEntry {
        DispatchEntry(date: .now, dispatches: [Self.sample], run: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DispatchEntry) -> Void) {
        let dispatches = WidgetStore.dispatches()
        completion(DispatchEntry(
            date: .now,
            dispatches: dispatches.isEmpty && context.isPreview ? [Self.sample] : dispatches,
            run: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DispatchEntry>) -> Void) {
        let now = Date.now
        let dispatches = WidgetStore.dispatches()
        var entries: [DispatchEntry] = []
        if let run = WidgetStore.run(), run.endsAt > now {
            entries.append(DispatchEntry(date: now, dispatches: dispatches, run: run))
            entries.append(DispatchEntry(date: run.endsAt, dispatches: dispatches, run: nil))
        } else {
            entries.append(DispatchEntry(date: now, dispatches: dispatches, run: nil))
        }
        completion(Timeline(entries: entries, policy: .never))
    }

    private static let sample = WidgetStore.Dispatch(
        key: "latest", title: "MOSSWOOD VERGE", subtitle: "25 MIN · KAEL", accent: 0xFF8FD694)
}

struct DispatchWidgetView: View {
    let entry: DispatchEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetBackground(family == .accessoryRectangular ? nil : Palette.black)
    }

    @ViewBuilder private var content: some View {
        if let run = entry.run {
            RunView(run: run, family: family)
        } else if entry.dispatches.isEmpty {
            NothingSentView(family: family)
        } else if family == .systemMedium {
            MediumView(dispatches: Array(entry.dispatches.prefix(3)))
        } else {
            SingleView(dispatch: entry.dispatches[0], family: family)
                .widgetURL(WidgetStore.url(for: entry.dispatches[0].key))
        }
    }
}

// MARK: - States

/// The squad is out. Where, and when they are back: a clock time, so there
/// is nothing counting down to watch.
private struct RunView: View {
    let run: WidgetStore.Run
    let family: WidgetFamily

    var body: some View {
        let accent = Palette.accent(run.accent)
        if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 1) {
                Text(run.sectorName).font(Typeface.name(13)).lineLimit(1)
                Text("BACK AT \(run.endsAt, style: .time)").font(Typeface.micro)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("OUT")
                    .font(Typeface.micro).tracking(1.6)
                    .foregroundStyle(accent)
                Text(run.sectorName)
                    .font(Typeface.name(family == .systemSmall ? 15 : 18))
                    .foregroundStyle(Palette.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text("BACK AT")
                    .font(Typeface.micro).tracking(1.6)
                    .foregroundStyle(Palette.dim)
                Text(run.endsAt, style: .time)
                    .font(Typeface.clock(family == .systemSmall ? 26 : 30))
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// The last dispatch, for the sizes too small for three.
private struct SingleView: View {
    let dispatch: WidgetStore.Dispatch
    let family: WidgetFamily

    var body: some View {
        let accent = Palette.accent(dispatch.accent)
        if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 1) {
                Text("SEND AGAIN").font(Typeface.micro)
                Text(dispatch.title).font(Typeface.name(13)).lineLimit(1)
                Text(dispatch.subtitle).font(Typeface.micro).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("SEND AGAIN")
                    .font(Typeface.micro).tracking(1.6)
                    .foregroundStyle(Palette.dim)
                Spacer(minLength: 0)
                Rectangle().fill(accent).frame(width: 24, height: 3)
                Text(dispatch.title)
                    .font(Typeface.name(15))
                    .foregroundStyle(Palette.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(dispatch.subtitle)
                    .font(Typeface.micro)
                    .foregroundStyle(accent)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// Up to three, each its own tap target - the home screen's SEND AGAIN list.
private struct MediumView: View {
    let dispatches: [WidgetStore.Dispatch]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SEND AGAIN")
                .font(Typeface.micro).tracking(1.6)
                .foregroundStyle(Palette.dim)
            ForEach(dispatches, id: \.key) { d in
                Link(destination: WidgetStore.url(for: d.key)) {
                    Row(dispatch: d)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private struct Row: View {
        let dispatch: WidgetStore.Dispatch

        var body: some View {
            let accent = Palette.accent(dispatch.accent)
            HStack(spacing: 10) {
                Rectangle().fill(accent).frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(dispatch.title)
                        .font(Typeface.name(13))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                    Text(dispatch.subtitle)
                        .font(Typeface.micro)
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(">").font(Typeface.micro).foregroundStyle(accent)
            }
            .frame(maxHeight: 30)
            .background(accent.opacity(0.08))
        }
    }
}

/// Nothing sent yet, so nothing to repeat: a plain way into the app.
private struct NothingSentView: View {
    let family: WidgetFamily

    var body: some View {
        if family == .accessoryRectangular {
            Text("TELOS").font(Typeface.name(13))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("TELOS")
                    .font(Typeface.name(15))
                    .foregroundStyle(Palette.amber)
                Text("Send a squad out once and it will be here to send again.")
                    .font(Typeface.micro)
                    .foregroundStyle(Palette.dim)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Background

private extension View {
    /// iOS 17 requires widgets to declare their background this way, and
    /// draws a placeholder instead of the widget when they do not.
    @ViewBuilder func widgetBackground(_ color: Color?) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { color ?? Color.clear }
        } else if let color {
            padding().background(color)
        } else {
            self
        }
    }
}
