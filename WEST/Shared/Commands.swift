import Foundation
import UserNotifications
import WidgetKit

enum TimerCommands {
    static let notificationID = "west.timer"
    static func execute(_ command: TimerCommand, run: UUID, version: UInt64,
                        store: StateStore? = nil) async throws -> AppState {
        let store = try store ?? StateStore.shared()
        let token = try await store.lockAsync(); defer { withExtendedLifetime(token) {} }
        var state = try store.readLocked()
        guard state.timer.apply(command, expectedRun: run, expectedVersion: version, at: Date()) else { return state }
        try store.writeLocked(state)
        WidgetCenter.shared.reloadAllTimelines()
        try await reconcileLocked(state)
        return state
    }
    static func restore() async throws -> AppState {
        let store = try StateStore.shared()
        let token = try await store.lockAsync(); defer { withExtendedLifetime(token) {} }
        var state = try store.readLocked()
        let old = state.timer
        state.timer.normalize(at: Date())
        if old != state.timer { try store.writeLocked(state); WidgetCenter.shared.reloadAllTimelines() }
        try await reconcileLocked(state)
        return state
    }
    static func reconcileLocked(_ state: AppState) async throws {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let now = Date()
        guard state.timer.effectivePhase(at: now) == .running, let deadline = state.timer.deadline else {
            center.removePendingNotificationRequests(withIdentifiers: [notificationID]); return
        }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let revision = "\(state.timer.runID.uuidString):\(state.timer.version)"
        if pending.contains(where: { $0.identifier == notificationID && $0.content.userInfo["revision"] as? String == revision }) { return }
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        let content = UNMutableNotificationContent()
        content.title = Localization.text("Timer finished", language: state.preferences.language)
        content.body = Localization.text("Your countdown has finished.", language: state.preferences.language)
        content.sound = .default; content.userInfo = ["revision": revision]
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: deadline)
        components.calendar = calendar; components.timeZone = calendar.timeZone
        try await center.add(UNNotificationRequest(identifier: notificationID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
    }
}
