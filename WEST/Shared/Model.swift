import Foundation

enum ClockKind: String, Codable, CaseIterable { case city, designation }
struct ClockRecord: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var kind: ClockKind
    var zoneID: String
    var city: String
    var country: String
    var winter: String
    var summer: String
    var zone: TimeZone { TimeZone(identifier: zoneID)! }
    var identity: String { "\(kind.rawValue):\(zoneID):\(city)" }
    func abbreviation(at date: Date) -> String {
        if !winter.isEmpty { return zone.isDaylightSavingTime(for: date) ? summer : winter }
        return zone.abbreviation(for: date) ?? zoneID
    }
    func title(at date: Date) -> String { kind == .city ? city : abbreviation(at: date) }
    func difference(at date: Date, local: TimeZone = .autoupdatingCurrent) -> Int {
        zone.secondsFromGMT(for: date) - local.secondsFromGMT(for: date)
    }
}
enum HourFormat: String, Codable, CaseIterable { case system, twelve, twentyFour }
struct Preferences: Codable, Equatable {
    var seconds = false
    var format: HourFormat = .system
    var language = "system"
}
enum TimerPhase: String, Codable { case idle, running, paused, finished }
enum TimerCommand: String, Codable { case start, pause, resume, reset, repeatTimer }
struct TimerState: Codable, Equatable {
    var duration: TimeInterval = 1500
    var deadline: Date?
    var pausedRemaining: TimeInterval = 1500
    var phase: TimerPhase = .idle
    var runID: UUID = UUID()
    var version: UInt64 = 0
    func remaining(at now: Date) -> TimeInterval {
        switch effectivePhase(at: now) {
        case .running: return max(0, (deadline ?? now).timeIntervalSince(now))
        case .finished: return 0
        case .idle: return duration
        case .paused: return max(0, pausedRemaining)
        }
    }
    func effectivePhase(at now: Date) -> TimerPhase {
        phase == .running && (deadline ?? .distantPast) <= now ? .finished : phase
    }
    mutating func normalize(at now: Date) {
        if effectivePhase(at: now) == .finished { phase = .finished; pausedRemaining = 0 }
    }
    @discardableResult mutating func apply(_ command: TimerCommand, expectedRun: UUID,
                                           expectedVersion: UInt64, at now: Date) -> Bool {
        guard runID == expectedRun, version == expectedVersion else { return false }
        let effective = effectivePhase(at: now)
        switch command {
        case .start: guard effective == .idle else { return false }; runID = UUID(); deadline = now.addingTimeInterval(duration); phase = .running
        case .pause: guard effective == .running else { return false }; pausedRemaining = remaining(at: now); deadline = nil; phase = .paused
        case .resume: guard effective == .paused else { return false }; deadline = now.addingTimeInterval(pausedRemaining); phase = .running
        case .reset: deadline = nil; pausedRemaining = duration; phase = .idle; runID = UUID()
        case .repeatTimer: guard effective == .finished else { return false }; runID = UUID(); deadline = now.addingTimeInterval(duration); phase = .running
        }
        version += 1
        return true
    }
    mutating func setDuration(_ seconds: TimeInterval) throws {
        guard phase == .idle, seconds.isFinite, seconds >= 1, seconds <= 86399,
              seconds.rounded() == seconds else { throw StateError.invalidDuration }
        duration = seconds; pausedRemaining = seconds; version += 1
    }
}
struct AppState: Codable, Equatable {
    var schema = 1
    var clocks: [ClockRecord] = []
    var preferences = Preferences()
    var timer = TimerState()
    func validate() throws {
        guard schema == 1, clocks.count <= 6, Set(clocks.map(\.id)).count == clocks.count,
              Set(clocks.map(\.identity)).count == clocks.count,
              clocks.allSatisfy({ TimeZone(identifier: $0.zoneID) != nil }),
              timer.duration.isFinite, (1...86399).contains(timer.duration),
              timer.pausedRemaining.isFinite, (0...timer.duration).contains(timer.pausedRemaining),
              timer.phase != .running || timer.deadline != nil,
              preferences.language == "system" || Localization.languages.contains(preferences.language)
        else { throw StateError.corrupt }
    }
}
enum StateError: Error, LocalizedError {
    case unavailableGroup, corrupt, invalidDuration, capacity, io
    var messageKey: String {
        switch self {
        case .unavailableGroup: return "Shared storage unavailable. Check signing and App Group configuration."
        case .corrupt: return "Saved data is invalid. The file has been preserved."
        case .invalidDuration: return "Reset the timer before changing duration (1–86399 seconds)."
        case .capacity: return "A maximum of six clocks is supported."
        case .io: return "Unable to access saved data."
        }
    }
    var errorDescription: String? { messageKey }
}
