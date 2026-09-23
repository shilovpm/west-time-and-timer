import SwiftUI
import WidgetKit
#if !LOCAL_WIDGET_STATIC
import AppIntents
#endif

struct WESTEntry: TimelineEntry {
    var date: Date
    var state: AppState
    var selectedIDs: [String] = []
    var error: Bool = false
}

enum WidgetTimeline {
    static func state() -> (AppState, Bool) {
        do { return (try StateStore.shared().read(), false) }
        catch {
            NSLog("WEST widget state read failed: %@", String(describing: error))
            return (AppState(), true)
        }
    }
    static func entries(state: AppState, selected: [String] = [], error: Bool = false) -> [WESTEntry] {
        let now = Date(), horizon = Date().addingTimeInterval(86400)
        var dates = [now]
        let zones = state.clocks.map(\.zone) + [.autoupdatingCurrent]
        for zone in zones {
            if let transition = zone.nextDaylightSavingTimeTransition(after: now), transition <= horizon { dates.append(transition) }
        }
        if state.timer.phase == .running, let end = state.timer.deadline, end > now, end <= horizon { dates.append(end) }
        return Set(dates).sorted().map { WESTEntry(date: $0, state: state, selectedIDs: selected, error: error) }
    }
    static func clockEntries(state: AppState, error: Bool = false) -> [WESTEntry] {
        let now = Date()
        let step: TimeInterval = state.preferences.seconds ? 1 : 60
        let horizon = now.addingTimeInterval(state.preferences.seconds ? 60 : 1800)
        var dates = Set([now])
        var tick = Date(timeIntervalSinceReferenceDate:
            (now.timeIntervalSinceReferenceDate / step).rounded(.down) * step + step)
        while tick <= horizon {
            dates.insert(tick)
            tick = tick.addingTimeInterval(step)
        }
        for zone in state.clocks.map(\.zone) + [.autoupdatingCurrent] {
            if let transition = zone.nextDaylightSavingTimeTransition(after: now), transition <= horizon {
                dates.insert(transition)
            }
        }
        return dates.sorted().map { WESTEntry(date: $0, state: state, error: error) }
    }
    static func clockReloadDate(for state: AppState) -> Date {
        Date().addingTimeInterval(state.preferences.seconds ? 60 : 1800)
    }
}

#if LOCAL_WIDGET_STATIC
struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> WESTEntry { WESTEntry(date: .now, state: AppState()) }
    func getSnapshot(in context: Context, completion: @escaping (WESTEntry) -> Void) {
        let (state, error) = WidgetTimeline.state()
        completion(WESTEntry(date: .now, state: state, error: error))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WESTEntry>) -> Void) {
        let (state, error) = WidgetTimeline.state()
        completion(Timeline(entries: WidgetTimeline.clockEntries(state: state, error: error),
                            policy: .after(WidgetTimeline.clockReloadDate(for: state))))
    }
}
#else
struct ClockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WESTEntry { WESTEntry(date: .now, state: AppState()) }
    func snapshot(for configuration: ClockConfiguration, in context: Context) async -> WESTEntry {
        let (state, error) = WidgetTimeline.state()
        return WESTEntry(date: .now, state: state, error: error)
    }
    func timeline(for configuration: ClockConfiguration, in context: Context) async -> Timeline<WESTEntry> {
        let (state, error) = WidgetTimeline.state()
        return Timeline(entries: WidgetTimeline.clockEntries(state: state, error: error),
                        policy: .after(WidgetTimeline.clockReloadDate(for: state)))
    }
}
#endif

struct TimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> WESTEntry { WESTEntry(date: .now, state: AppState()) }
    func getSnapshot(in context: Context, completion: @escaping (WESTEntry) -> Void) {
        let (state, error) = WidgetTimeline.state(); completion(WESTEntry(date: .now, state: state, error: error))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WESTEntry>) -> Void) {
        let (state, error) = WidgetTimeline.state()
        completion(Timeline(entries: WidgetTimeline.entries(state: state, error: error), policy: .after(Date().addingTimeInterval(1800))))
    }
}

/// WidgetKit archives custom views before the desktop host applies its
/// appearance. Resolve the approved palette from the host environment so the
/// full-color widget follows the actual system light or dark appearance.
struct WidgetPalette {
    let surface: Color
    let ink: Color
    let violet: Color
    let rule: Color

    init(_ colorScheme: ColorScheme) {
        if colorScheme == .dark {
            surface = Color(.sRGB, red: 0.129, green: 0.102, blue: 0.161, opacity: 1)
            ink = Color(.sRGB, red: 0.973, green: 0.961, blue: 0.984, opacity: 1)
            violet = Color(.sRGB, red: 0.761, green: 0.475, blue: 1.000, opacity: 1)
            rule = Color(.sRGB, red: 0.255, green: 0.196, blue: 0.310, opacity: 1)
        } else {
            surface = Color(.sRGB, red: 1.000, green: 1.000, blue: 1.000, opacity: 1)
            ink = Color(.sRGB, red: 0.090, green: 0.075, blue: 0.120, opacity: 1)
            violet = Color(.sRGB, red: 0.545, green: 0.173, blue: 0.961, opacity: 1)
            rule = Color(.sRGB, red: 0.875, green: 0.788, blue: 1.000, opacity: 1)
        }
    }
}

struct ClockWidgetView: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: WESTEntry
    var limit: Int { family == .systemLarge ? 6 : family == .systemMedium ? 3 : 1 }
    var language: String { entry.state.preferences.language }
    var chosen: [String] {
        Array(entry.state.clocks.map { $0.id.uuidString }.prefix(limit))
    }
    var records: [(String, ClockRecord?)] {
        chosen.map { id in
            let selectedID = UUID(uuidString: id)
            return (id, entry.state.clocks.first { $0.id == selectedID })
        }
    }
    var body: some View {
        let palette = WidgetPalette(colorScheme)
        Group {
            if entry.error {
                Link(Localization.text("Open app to check saved data", language: language), destination: URL(string: "westtime://clocks")!)
                    .font(.caption).foregroundStyle(palette.violet)
            } else if records.isEmpty {
                Link(Localization.text("Add clock", language: language), destination: URL(string: "westtime://clocks")!)
                    .foregroundStyle(palette.violet)
            } else if family == .systemSmall {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Localization.text("World clocks", language: language)).font(.system(size: 13, weight: .bold))
                    if let record = records[0].1 { SmallWidgetClockRow(record: record, preferences: entry.state.preferences, date: entry.date) }
                    else { missingEntry }
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: family == .systemMedium ? 3 : 7) {
                    Text(Localization.text("World clocks", language: language))
                        .font(.system(size: family == .systemMedium ? 12 : 14, weight: .bold))
                        .lineLimit(1)
                    WidgetClockTimeline(records: records, preferences: entry.state.preferences, date: entry.date,
                                        family: family, language: language)
                    Spacer(minLength: 0)
                }
            }
        }
        .foregroundStyle(palette.ink)
        .environment(\.locale, Locale(identifier: Localization.resolved(language)))
        .environment(\.layoutDirection, ["ar", "ur"].contains(Localization.resolved(language)) ? .rightToLeft : .leftToRight)
        .containerBackground(palette.surface, for: .widget)
        .widgetURL(URL(string: "westtime://clocks"))
    }
    var missingEntry: some View {
        Link(Localization.text("Removed clock", language: language), destination: URL(string: "westtime://clocks")!)
            .font(.caption).foregroundStyle(WidgetPalette(colorScheme).violet)
    }
}

struct SmallWidgetClockRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let record: ClockRecord
    let preferences: Preferences
    let date: Date
    var body: some View {
        let palette = WidgetPalette(colorScheme)
        HStack(spacing: 6) {
            WidgetClockText(record: record, preferences: preferences, date: date)
                .font(.system(size: preferences.seconds ? 15 : 20, weight: .semibold, design: .rounded))
                .frame(width: 62, alignment: .trailing)
                .minimumScaleFactor(0.62).lineLimit(1).allowsTightening(true)
            WidgetTimelineRail(isFirst: true, isLast: true, rowHeight: 68)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: record.title(at: date)).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(verbatim: widgetMetadata(record, date)).font(.system(size: 8)).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.58)
                Text(verbatim: Localization.difference(record.difference(at: date), language: preferences.language))
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(palette.violet.opacity(0.72)).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 68)
    }
}

struct WidgetClockTimeline: View {
    @Environment(\.colorScheme) private var colorScheme
    let records: [(String, ClockRecord?)]
    let preferences: Preferences
    let date: Date
    let family: WidgetFamily
    let language: String
    var rowHeight: CGFloat {
        if family == .systemMedium { return 34 }
        return records.count <= 3 ? 52 : 39
    }
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.0) { index, pair in
                if let record = pair.1 {
                    WidgetClockRow(record: record, preferences: preferences, date: date,
                                   family: family, rowHeight: rowHeight,
                                   isFirst: index == 0, isLast: index == records.count - 1)
                } else {
                    Link(Localization.text("Removed clock", language: language), destination: URL(string: "westtime://clocks")!)
                        .font(.caption).foregroundStyle(WidgetPalette(colorScheme).violet).frame(maxWidth: .infinity, minHeight: rowHeight)
                }
            }
        }
    }
}

struct WidgetClockRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let record: ClockRecord
    let preferences: Preferences
    let date: Date
    let family: WidgetFamily
    let rowHeight: CGFloat
    let isFirst: Bool
    let isLast: Bool
    var medium: Bool { family == .systemMedium }
    var timeWidth: CGFloat { medium ? 70 : 78 }
    var differenceWidth: CGFloat { medium ? 48 : 64 }
    var spacing: CGFloat { medium ? 6 : 7 }
    var body: some View {
        let palette = WidgetPalette(colorScheme)
        HStack(spacing: spacing) {
            WidgetClockText(record: record, preferences: preferences, date: date)
                .font(.system(size: preferences.seconds ? (medium ? 13 : 15) : (medium ? 19 : 21), weight: .semibold, design: .rounded))
                .frame(width: timeWidth, alignment: .trailing)
                .minimumScaleFactor(0.62).lineLimit(1).allowsTightening(true)
            WidgetTimelineRail(isFirst: isFirst, isLast: isLast, rowHeight: rowHeight)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: record.title(at: date)).font(.system(size: medium ? 11 : 12, weight: .semibold)).lineLimit(1)
                Text(verbatim: widgetMetadata(record, date)).font(.system(size: medium ? 7.5 : 8)).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.58)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: Localization.difference(record.difference(at: date), language: preferences.language))
                .font(.system(size: medium ? 8.5 : 9, weight: .medium)).foregroundStyle(palette.violet.opacity(0.72))
                .frame(width: differenceWidth, alignment: .trailing).lineLimit(1).minimumScaleFactor(0.58)
        }
        .frame(height: rowHeight)
        .overlay(alignment: .bottomTrailing) {
            if !isLast {
                Rectangle().fill(palette.rule).frame(height: 1)
                    .padding(.leading, timeWidth + spacing + 14 + spacing)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The line and node share one fixed column, so their horizontal centers can
/// never drift apart when the neighbouring text columns resize.
struct WidgetTimelineRail: View {
    @Environment(\.colorScheme) private var colorScheme
    let isFirst: Bool
    let isLast: Bool
    let rowHeight: CGFloat
    var body: some View {
        let violet = WidgetPalette(colorScheme).violet
        ZStack {
            if isFirst && isLast {
                Rectangle().fill(violet).frame(width: 2)
            } else {
                Rectangle().fill(violet).frame(width: 2)
                    .padding(.top, isFirst ? rowHeight / 2 : 0)
                    .padding(.bottom, isLast ? rowHeight / 2 : 0)
            }
            Circle().fill(violet).frame(width: 13, height: 13)
        }
        .frame(width: 14, height: rowHeight)
    }
}

private func widgetMetadata(_ record: ClockRecord, _ date: Date) -> String {
    let abbreviation = record.kind == .city ? record.abbreviation(at: date) + " · " : ""
    return abbreviation + Localization.utc(record.zone.secondsFromGMT(for: date))
}

/// Widget view archives are decoded in Notification Center, which cannot load
/// app-defined FormatStyle types. Archive a plain string and advance it with
/// timeline entries instead.
struct WidgetClockText: View {
    let record: ClockRecord
    let preferences: Preferences
    let date: Date
    var body: some View {
        Text(verbatim: ZonedTimeStyle(zoneID: record.zoneID,
                                     language: preferences.language,
                                     hourFormat: preferences.format,
                                     seconds: preferences.seconds).format(date))
            .monospacedDigit()
    }
}

struct TimerWidgetView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme
    let entry: WESTEntry
    var body: some View {
        let timer = entry.state.timer
        let phase = timer.effectivePhase(at: entry.date)
        let language = entry.state.preferences.language
        let palette = WidgetPalette(colorScheme)
        VStack(alignment: .leading, spacing: 10) {
            Text(Localization.text("Timer", language: language)).font(.system(size: 13, weight: .bold)).foregroundStyle(palette.ink)
            if entry.error {
                Link(Localization.text("Open app to check saved data", language: language), destination: URL(string: "westtime://timer")!)
                    .font(.caption).foregroundStyle(palette.violet)
            } else {
                Countdown(timer: timer, now: entry.date)
                    .font(.system(size: 32, weight: .semibold, design: .rounded)).foregroundStyle(palette.ink)
                    .minimumScaleFactor(0.65).lineLimit(1)
                timerProgress(timer, phase)
                HStack(spacing: 10) {
#if LOCAL_WIDGET_STATIC
                    Link(destination: timerURL(phase == .running ? .pause : phase == .paused ? .resume : phase == .finished ? .repeatTimer : .start)) {
                        Image(systemName: phase == .running ? "pause.fill" : phase == .finished ? "arrow.clockwise" : "play.fill")
                            .widgetAccentedRenderingMode(.fullColor)
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(WidgetActionButtonStyle(primary: true, renderingMode: renderingMode, palette: palette))
                    .accessibilityLabel(Localization.text(phase == .running ? "Pause" : phase == .paused ? "Continue" : phase == .finished ? "Repeat" : "Start", language: language))
                    Link(destination: timerURL(.reset)) {
                        Image(systemName: "arrow.counterclockwise")
                            .widgetAccentedRenderingMode(.fullColor)
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(WidgetActionButtonStyle(primary: false, renderingMode: renderingMode, palette: palette))
                    .accessibilityLabel(Localization.text("Reset", language: language))
#else
                    Button(intent: TimerActionIntent(command: phase == .running ? .pause : phase == .paused ? .resume : phase == .finished ? .repeatTimer : .start, timer: timer)) {
                        Image(systemName: phase == .running ? "pause.fill" : phase == .finished ? "arrow.clockwise" : "play.fill")
                            .widgetAccentedRenderingMode(.fullColor)
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(WidgetActionButtonStyle(primary: true, renderingMode: renderingMode, palette: palette))
                    .accessibilityLabel(Localization.text(phase == .running ? "Pause" : phase == .paused ? "Continue" : phase == .finished ? "Repeat" : "Start", language: language))
                    Button(intent: TimerActionIntent(command: .reset, timer: timer)) {
                        Image(systemName: "arrow.counterclockwise")
                            .widgetAccentedRenderingMode(.fullColor)
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(WidgetActionButtonStyle(primary: false, renderingMode: renderingMode, palette: palette))
                    .accessibilityLabel(Localization.text("Reset", language: language))
#endif
                }
            }
            Spacer(minLength: 0)
        }
        .containerBackground(palette.surface, for: .widget)
        .widgetURL(URL(string: "westtime://timer"))
    }
    @ViewBuilder func timerProgress(_ timer: TimerState, _ phase: TimerPhase) -> some View {
        if phase == .running, let deadline = timer.deadline {
            ProgressView(timerInterval: entry.date...max(entry.date, deadline), countsDown: true).labelsHidden().tint(WidgetPalette(colorScheme).violet)
        } else {
            ProgressView(value: timer.duration > 0 ? timer.remaining(at: entry.date) / timer.duration : 0).labelsHidden().tint(WidgetPalette(colorScheme).violet)
        }
    }
#if LOCAL_WIDGET_STATIC
    func timerURL(_ command: TimerCommand) -> URL {
        URL(string: "westtime://timer?action=\(command.rawValue)")!
    }
#endif
}

struct WidgetActionButtonStyle: ButtonStyle {
    let primary: Bool
    let renderingMode: WidgetRenderingMode
    let palette: WidgetPalette

    func makeBody(configuration: Configuration) -> some View {
        let fullColor = renderingMode == .fullColor
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(primary && fullColor ? Color.white : Color.primary)
            .background(
                primary && fullColor
                    ? palette.violet.opacity(configuration.isPressed ? 0.78 : 1)
                    : Color.primary.opacity(configuration.isPressed ? 0.12 : primary ? 0.20 : 0.10),
                in: Capsule()
            )
            .contentShape(Capsule())
    }
}

struct WorldClockWidget: Widget {
    var body: some WidgetConfiguration {
#if LOCAL_WIDGET_STATIC
        StaticConfiguration(kind: "WESTClocks", provider: ClockProvider()) { ClockWidgetView(entry: $0) }
            .configurationDisplayName("World clocks").description("Your saved cities and seasonal time zones.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
#else
        AppIntentConfiguration(kind: "WESTClocks", intent: ClockConfiguration.self, provider: ClockProvider()) { ClockWidgetView(entry: $0) }
            .configurationDisplayName("World clocks").description("Your saved cities and seasonal time zones.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
#endif
    }
}
struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WESTTimer", provider: TimerProvider()) { TimerWidgetView(entry: $0) }
            .configurationDisplayName("Timer").description("One shared countdown.").supportedFamilies([.systemSmall])
    }
}
@main struct WESTWidgetBundle: WidgetBundle {
    var body: some Widget { WorldClockWidget(); CountdownWidget() }
}
