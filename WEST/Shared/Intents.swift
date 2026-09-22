#if !LOCAL_WIDGET_STATIC
import AppIntents
import Foundation

/// Keeps the configuration identity used by already-installed clock widgets.
/// The saved order now comes exclusively from shared app state, so the intent
/// intentionally has no user-editable entity parameters.
struct ClockConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "World clocks"
    static var description = IntentDescription("Your saved cities and seasonal time zones.")
}

struct TimerActionIntent: AppIntent {
    static var title: LocalizedStringResource = "Control timer"
    static var description = IntentDescription("Control the single shared timer.")
    static var openAppWhenRun = false
    @Parameter(title: "Command") var command: String
    @Parameter(title: "Run") var run: String
    @Parameter(title: "Version") var version: String
    init() {}
    init(command: TimerCommand, timer: TimerState) {
        self.command = command.rawValue; run = timer.runID.uuidString; version = String(timer.version)
    }
    func perform() async throws -> some IntentResult {
        guard let action = TimerCommand(rawValue: command), let id = UUID(uuidString: run), let revision = UInt64(version) else { return .result() }
        _ = try await TimerCommands.execute(action, run: id, version: revision)
        return .result()
    }
}
#endif
