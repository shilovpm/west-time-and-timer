import SwiftUI
import UserNotifications
import WidgetKit
import AppKit

@MainActor private func activateMainWindow() {
    NSApp.unhide(nil)
    NSApp.activate(ignoringOtherApps: true)
    let appWindows = NSApp.windows.filter { $0.canBecomeMain || $0.canBecomeKey }
    for window in appWindows where window.isMiniaturized { window.deminiaturize(nil) }
    if let window = appWindows.first {
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

@MainActor private func activateMainWindowAfterSceneUpdate() {
    activateMainWindow()
    DispatchQueue.main.async { activateMainWindow() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { activateMainWindow() }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        activateMainWindowAfterSceneUpdate()
        return true
    }
}

@MainActor final class AppModel: ObservableObject {
    @Published var state = AppState()
    @Published var error: String?
    @Published var permission: UNAuthorizationStatus = .notDetermined
    init() {
        do { state = try StateStore.shared().read() }
        catch { self.error = errorMessage(error) }
    }
    func load() async {
        do { state = try await TimerCommands.restore(); error = nil } catch { self.error = errorMessage(error) }
        permission = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        WidgetCenter.shared.reloadAllTimelines()
    }
    func refresh() { do { state = try StateStore.shared().read(); error = nil } catch { self.error = errorMessage(error) } }
    func update(_ change: (inout AppState) throws -> Void) {
        do { state = try StateStore.shared().update(change); error = nil; WidgetCenter.shared.reloadAllTimelines() }
        catch { self.error = errorMessage(error) }
    }
    func command(_ command: TimerCommand) async {
        if command == .start || command == .repeatTimer {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                do { _ = try await center.requestAuthorization(options: [.alert, .sound]) }
                catch { self.error = errorMessage(error) }
            }
        }
        let timer = state.timer
        do { state = try await TimerCommands.execute(command, run: timer.runID, version: timer.version); error = nil }
        catch { self.error = errorMessage(error); refresh() }
        permission = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
    func text(_ key: String) -> String { Localization.text(key, language: state.preferences.language) }
    private func errorMessage(_ error: Error) -> String {
        guard let stateError = error as? StateError else { return error.localizedDescription }
        return text(stateError.messageKey)
    }
    var locale: Locale { Locale(identifier: Localization.resolved(state.preferences.language)) }
    var direction: LayoutDirection { ["ar", "ur"].contains(Localization.resolved(state.preferences.language)) ? .rightToLeft : .leftToRight }
}
@main struct WESTApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("WEST time and timer", id: "main") {
            MainView().environmentObject(model).environment(\.locale, model.locale)
                .environment(\.layoutDirection, model.direction).tint(AppPalette.violet)
        }
        .defaultSize(width: 900, height: 650)
        .handlesExternalEvents(matching: ["*"])
        Settings {
            SettingsView().environmentObject(model).environment(\.locale, model.locale)
                .environment(\.layoutDirection, model.direction).tint(AppPalette.violet)
        }
    }
}
struct MainView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) var scenePhase
    @State private var add = false
    @State private var hours = 0
    @State private var minutes = 25
    @State private var seconds = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let error = model.error {
                    HStack {
                        Text(verbatim: error).foregroundStyle(.red).textSelection(.enabled)
                        Spacer()
                        Button(model.text("Retry")) { Task { await model.load() } }
                    }.padding(.bottom, 14)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    timerSection(now: context.date)
                }
                Divider().overlay(AppPalette.rule).padding(.vertical, 22)
                clocksSection
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .background(AppPalette.canvas)
        .frame(minWidth: 840, minHeight: 560)
        .toolbar {
            SettingsLink { Image(systemName: "gearshape") }
                .accessibilityLabel(model.text("Settings"))
        }
        .sheet(isPresented: $add) { AddClockView().environmentObject(model) }
        .task { await model.load(); syncDuration() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.load() } } }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            NSTimeZone.resetSystemTimeZone(); model.refresh(); WidgetCenter.shared.reloadAllTimelines()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refresh() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in model.refresh() }
        .onOpenURL { url in
            guard url.scheme == "westtime" else { return }
            activateMainWindowAfterSceneUpdate()
            guard url.host == "timer",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let value = components.queryItems?.first(where: { $0.name == "action" })?.value,
                  let command = TimerCommand(rawValue: value) else { return }
            Task { await model.command(command); syncDuration() }
        }
    }

    func timerSection(now: Date) -> some View {
        let timer = model.state.timer
        let phase = timer.effectivePhase(at: now)
        let progress = timer.duration > 0 ? min(1, max(0, timer.remaining(at: now) / timer.duration)) : 0
        return VStack(alignment: .leading, spacing: 14) {
            Text(model.text("Timer"))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppPalette.ink)
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 18) {
                    Countdown(timer: timer, now: now)
                        .font(.system(size: 54, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                        .minimumScaleFactor(0.68)
                        .lineLimit(1)
                    LinearTimerProgress(progress: progress)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(model.text(actionTitle(phase))) {
                            Task { await model.command(actionCommand(phase)) }
                        }
                        .buttonStyle(FilledVioletButtonStyle())
                        .keyboardShortcut(.space, modifiers: [])
                        Button(model.text("Reset")) {
                            Task { await model.command(.reset); syncDuration() }
                        }
                        .buttonStyle(SoftVioletButtonStyle())
                    }
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 12) {
                        ForEach([5, 15, 25, 60], id: \.self) { value in
                            Button("\(value) " + model.text("min")) {
                                model.update { try $0.timer.setDuration(Double(value * 60)) }
                                syncDuration()
                            }
                            .buttonStyle(SoftVioletButtonStyle())
                            .disabled(phase != .idle)
                        }
                    }

                    HStack(spacing: 12) {
                        DurationMenu(value: $hours, range: 0...23, unit: model.text("h"), accessibilityName: model.text("h"))
                        DurationMenu(value: $minutes, range: 0...59, unit: model.text("min"), accessibilityName: model.text("min"))
                        DurationMenu(value: $seconds, range: 0...59, unit: model.text("s"), accessibilityName: model.text("s"))
                        Button(model.text("Set")) {
                            model.update { try $0.timer.setDuration(Double(hours * 3600 + minutes * 60 + seconds)) }
                        }
                        .buttonStyle(OutlineVioletButtonStyle())
                        .disabled(phase != .idle || hours + minutes + seconds == 0)
                    }
                    .disabled(phase != .idle)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    var clocksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(model.text("World clocks"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppPalette.ink)
                Spacer()
                Button { add = true } label: { Image(systemName: "plus").font(.system(size: 18, weight: .medium)) }
                    .buttonStyle(SquareAddButtonStyle())
                    .accessibilityLabel(model.text("Add clock"))
                    .disabled(model.state.clocks.count >= 6)
            }
            if model.state.clocks.isEmpty {
                Button(model.text("Add clock")) { add = true }
                    .buttonStyle(OutlineVioletButtonStyle())
                    .frame(maxWidth: .infinity, minHeight: 110)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ClockTimelineList(records: model.state.clocks,
                                      preferences: model.state.preferences,
                                      date: context.date,
                                      move: move,
                                      remove: remove,
                                      text: model.text)
                }
            }
        }
    }

    func actionTitle(_ phase: TimerPhase) -> String {
        phase == .running ? "Pause" : phase == .paused ? "Continue" : phase == .finished ? "Repeat" : "Start"
    }
    func actionCommand(_ phase: TimerPhase) -> TimerCommand {
        phase == .running ? .pause : phase == .paused ? .resume : phase == .finished ? .repeatTimer : .start
    }
    func syncDuration() {
        let s = Int(model.state.timer.duration); hours = s / 3600; minutes = s % 3600 / 60; seconds = s % 60
    }
    func remove(_ id: UUID) { model.update { $0.clocks.removeAll { $0.id == id } } }
    func move(_ id: UUID, _ delta: Int) {
        model.update { state in
            guard let index = state.clocks.firstIndex(where: { $0.id == id }),
                  state.clocks.indices.contains(index + delta) else { return }
            state.clocks.swapAt(index, index + delta)
        }
    }
}

struct LinearTimerProgress: View {
    let progress: Double
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppPalette.pale)
                Capsule().fill(AppPalette.violet).frame(width: proxy.size.width * progress)
            }
        }.frame(height: 7).accessibilityHidden(true)
    }
}

struct DurationMenu: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    let accessibilityName: String
    var body: some View {
        Menu {
            ForEach(Array(range), id: \.self) { option in
                Button {
                    value = option
                } label: {
                    if option == value {
                        Label("\(option) \(unit)", systemImage: "checkmark")
                    } else {
                        Text(verbatim: "\(option) \(unit)")
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(verbatim: "\(value)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                Text(verbatim: unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.violet.opacity(0.7))
                Spacer(minLength: 2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppPalette.violet)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38)
            .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppPalette.violet, lineWidth: 1))
        .accessibilityLabel(accessibilityName)
        .accessibilityValue("\(value)")
    }
}

struct ClockTimelineList: View {
    let records: [ClockRecord]
    let preferences: Preferences
    let date: Date
    let move: (UUID, Int) -> Void
    let remove: (UUID) -> Void
    let text: (String) -> String
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                ClockTimelineRow(record: record, preferences: preferences, date: date,
                                 isFirst: index == 0, isLast: index == records.count - 1,
                                 move: move, remove: remove, text: text)
                if index < records.count - 1 {
                    Divider().overlay(AppPalette.rule).padding(.leading, 40)
                }
            }
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(AppPalette.violet).frame(width: 2)
                .padding(.leading, 8).padding(.vertical, 34)
        }
    }
}

struct ClockTimelineRow: View {
    let record: ClockRecord
    let preferences: Preferences
    let date: Date
    let isFirst: Bool
    let isLast: Bool
    let move: (UUID, Int) -> Void
    let remove: (UUID) -> Void
    let text: (String) -> String
    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(AppPalette.violet).frame(width: 16, height: 16).zIndex(1)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: record.title(at: date)).font(.system(size: 17, weight: .semibold)).foregroundStyle(AppPalette.ink).lineLimit(1)
                HStack(spacing: 4) {
                    if record.kind == .city { Text(verbatim: record.abbreviation(at: date)) }
                    Text(verbatim: "·")
                    Text(verbatim: Localization.utc(record.zone.secondsFromGMT(for: date)))
                }.font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
            LiveClock(record: record, preferences: preferences)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(AppPalette.ink).frame(width: preferences.seconds ? 125 : 88, alignment: .trailing)
            Text(verbatim: Localization.difference(record.difference(at: date), language: preferences.language))
                .font(.system(size: 13, weight: .medium)).foregroundStyle(AppPalette.violet.opacity(0.78))
                .frame(width: 105, alignment: .leading).lineLimit(1).minimumScaleFactor(0.75)
            HStack(spacing: 2) {
                Button { move(record.id, -1) } label: { Image(systemName: "arrow.up") }.disabled(isFirst)
                Button { move(record.id, 1) } label: { Image(systemName: "arrow.down") }.disabled(isLast)
                Button { remove(record.id) } label: { Image(systemName: "trash") }
            }
            .buttonStyle(ManagementIconButtonStyle())
            .padding(.horizontal, 4)
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(AppPalette.rule, lineWidth: 1))
            .frame(width: 116)
            .accessibilityElement(children: .contain)
        }
        .frame(minHeight: 68)
        .accessibilityElement(children: .contain)
    }
}

struct FilledVioletButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(maxWidth: .infinity, minHeight: 38)
            .foregroundStyle(.white).fontWeight(.semibold)
            .background(AppPalette.violet.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 10))
    }
}
struct SoftVioletButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(maxWidth: .infinity, minHeight: 38)
            .foregroundStyle(AppPalette.violet).fontWeight(.semibold)
            .background(AppPalette.pale.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 10))
    }
}
struct OutlineVioletButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(maxWidth: .infinity, minHeight: 38)
            .padding(.horizontal, 8).foregroundStyle(AppPalette.violet).fontWeight(.semibold)
            .background(AppPalette.surface.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppPalette.violet, lineWidth: 1))
    }
}
struct SquareAddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(width: 40, height: 36).foregroundStyle(AppPalette.violet)
            .background(AppPalette.pale.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 10))
    }
}
struct ManagementIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(width: 34, height: 34).contentShape(Rectangle())
            .foregroundStyle(AppPalette.violet.opacity(configuration.isPressed ? 0.65 : 1))
    }
}

struct AddClockView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var query = ""
    @State private var kind = ClockKind.city
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.text("Add clock")).font(.title2.bold())
            TextField(model.text("City, country, IANA or abbreviation"), text: $query)
            Picker(model.text("Category"), selection: $kind) {
                Text(model.text("Cities")).tag(ClockKind.city)
                Text(model.text("Time zone designations")).tag(ClockKind.designation)
            }.pickerStyle(.segmented)
            List(ClockCatalog.search(query, kind: kind, at: .now)) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: record.title(at: .now)).fontWeight(.semibold)
                        Text(verbatim: record.kind == .designation ? "\(record.winter)/\(record.summer) · \(record.zoneID)" : record.zoneID).font(.caption)
                        if record.kind == .designation { Text(model.text("Automatic seasonal rules for this region")).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Button(model.text("Add")) {
                        model.update { state in
                            guard state.clocks.count < 6 else { throw StateError.capacity }
                            guard !state.clocks.contains(where: { $0.identity == record.identity }) else { return }
                            var saved = record; saved.id = UUID(); state.clocks.append(saved)
                        }
                        if model.error == nil { dismiss() }
                    }.disabled(model.state.clocks.contains(where: { $0.identity == record.identity }))
                }
            }
            Text(model.text("All IANA time zones are available. GMT and UTC offsets use current seasonal time."))
                .font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button(model.text("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction) }
        }.padding(20).frame(width: 540, height: 450)
    }
}
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        Form {
            Picker(model.text("Language"), selection: Binding(get: { model.state.preferences.language }, set: { value in model.update { $0.preferences.language = value } })) {
                Text(model.text("System")).tag("system")
                ForEach(Array(Localization.languages.enumerated()), id: \.element) { index, code in Text(Localization.names[index]).tag(code) }
            }
            Toggle(model.text("Show seconds in clocks"), isOn: Binding(get: { model.state.preferences.seconds }, set: { value in model.update { $0.preferences.seconds = value } }))
            Picker(model.text("Time format"), selection: Binding(get: { model.state.preferences.format }, set: { value in model.update { $0.preferences.format = value } })) {
                Text(model.text("System")).tag(HourFormat.system)
                Text(model.text("12 hour")).tag(HourFormat.twelve)
                Text(model.text("24 hour")).tag(HourFormat.twentyFour)
            }
            LabeledContent(model.text("Notifications"), value: model.text(permissionLabel))
            Link(model.text("Open notification settings"), destination: URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
            Text(model.text("Sleep counts toward the timer. Changing the system clock can change the remaining time.")).font(.caption)
            if let error = model.error { Text(verbatim: error).foregroundStyle(.red) }
        }.formStyle(.grouped).padding(12).frame(width: 470, height: 330).task { await model.load() }
    }
    var permissionLabel: String {
        switch model.permission { case .authorized, .provisional, .ephemeral: return "Allowed"; case .denied: return "Denied"; default: return "Not requested" }
    }
}
