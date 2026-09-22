import Foundation
#if !CLI_TESTS
import XCTest
@testable import WEST
#endif

struct TestFailure: Error, CustomStringConvertible { var description: String }
enum CoreChecks {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestFailure(description: message) }
    }
    static func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    static func run() throws -> Int {
        var count = 0
        func check(_ name: String, _ body: () throws -> Void) throws {
            try body(); count += 1; print("PASS \(name)")
        }
        let now = date("2026-07-01T12:00:00Z")
        let local = TimeZone(identifier: "Europe/Lisbon")!
        let berlin = ClockCatalog.records.first { $0.city == "Berlin" }!
        let cest = ClockCatalog.records.first { $0.kind == .designation && $0.winter == "CET" }!
        try check("live clock style applies each IANA zone") {
            let lisbon = ZonedTimeStyle(zoneID: "Europe/Lisbon", language: "en",
                                        hourFormat: .twentyFour, seconds: false)
            let central = ZonedTimeStyle(zoneID: "Europe/Berlin", language: "en",
                                         hourFormat: .twentyFour, seconds: false)
            let eastern = ZonedTimeStyle(zoneID: "Europe/Helsinki", language: "en",
                                         hourFormat: .twentyFour, seconds: false)
            try require(lisbon.format(now) == "13:00", "Lisbon used the Mac zone")
            try require(central.format(now) == "14:00", "Berlin used the Mac zone")
            try require(eastern.format(now) == "15:00", "Helsinki used the Mac zone")
        }
        try check("independent city and designation IDs / removal") {
            var state = AppState(); state.clocks = [berlin, cest]; try state.validate()
            state.clocks.removeAll { $0.id == berlin.id }
            try require(state.clocks == [cest], "Removing Berlin removed designation")
        }
        try check("seasonal designation and winter search") {
            let winter = date("2026-01-01T12:00:00Z")
            try require(cest.title(at: winter) == "CET", "False summer label")
            try require(ClockCatalog.search("CEST", kind: .designation, at: winter).contains(cest), "No winter alias")
            try require(ClockCatalog.search("CET", kind: .designation, at: now).contains(cest), "No summer alias")
        }
        try check("full IANA catalog and GMT search") {
            let cities = ClockCatalog.records.filter { $0.kind == .city }
            try require(cities.count >= 400, "IANA catalog is still truncated")
            try require(ClockCatalog.search("Москва", kind: .city, at: now).contains { $0.zoneID == "Europe/Moscow" }, "Moscow alias")
            try require(ClockCatalog.search("GMT+3", kind: .city, at: now).contains { $0.zoneID == "Europe/Moscow" }, "GMT+3")
            try require(ClockCatalog.search("GMT+4", kind: .city, at: now).contains { $0.zoneID == "Asia/Dubai" }, "GMT+4")
            try require(ClockCatalog.search("CEST", kind: .designation, at: now).contains(cest), "Designation layer lost")
        }
        try check("both DST transitions") {
            try require(cest.title(at: date("2026-03-29T00:59:59Z")) == "CET", "Before spring")
            try require(cest.title(at: date("2026-03-29T01:00:00Z")) == "CEST", "After spring")
            try require(cest.title(at: date("2026-10-25T00:59:59Z")) == "CEST", "Before autumn")
            try require(cest.title(at: date("2026-10-25T01:00:00Z")) == "CET", "After autumn")
        }
        try check("Berlin +1, WEST 0 relative to Lisbon") {
            try require(berlin.difference(at: now, local: local) == 3600, "Berlin diff")
            let west = ClockCatalog.records.first { $0.kind == .designation && $0.winter == "WET" }!
            try require(west.difference(at: now, local: local) == 0, "WEST diff")
        }
        try check("different DST dates and system-zone changes") {
            let ny = ClockCatalog.records.first { $0.city == "New York" }!
            try require(ny.difference(at: date("2026-03-15T12:00:00Z"), local: local) == -14400, "US/EU DST mismatch")
            try require(berlin.difference(at: now, local: TimeZone(identifier: "Asia/Tokyo")!) == -25200, "Changed local zone")
        }
        try check("fractional +05:30 and +05:45") {
            let utc = TimeZone(secondsFromGMT: 0)!
            try require(ClockCatalog.records.first { $0.city == "Kolkata" }!.difference(at: now, local: utc) == 19800, "Half hour")
            try require(ClockCatalog.records.first { $0.city == "Kathmandu" }!.difference(at: now, local: utc) == 20700, "Quarter hour")
            try require(Localization.difference(20700, language: "en").contains("45"), "Fraction lost")
        }
        try check("midnight does not change offset difference") {
            try require(berlin.difference(at: date("2026-07-01T23:30:00Z"), local: local) == 3600, "Clock hours used as offsets")
        }
        try check("UTC filter is seasonal, invalid requests have no invented zones") {
            try require(ClockCatalog.search("UTC+02:00", kind: .city, at: now).contains(berlin), "UTC summer")
            try require(!ClockCatalog.search("UTC+02:00", kind: .city, at: date("2026-01-01T12:00:00Z")).contains(berlin), "Fixed offset")
            try require(ClockCatalog.search("UTC+99:99", kind: .city, at: now).isEmpty, "Invalid offset")
            try require(ClockCatalog.search("unknown-zone", kind: .designation, at: now).isEmpty, "Invented zone")
        }
        try check("duration boundaries") {
            var timer = TimerState(); try timer.setDuration(1); try timer.setDuration(86399)
            for bad in [0.0, 86400.0, Double.infinity, 1.5] {
                do { try timer.setDuration(bad); throw TestFailure(description: "Accepted invalid duration") }
                catch StateError.invalidDuration {}
            }
        }
        try check("deadline / pause / resume / repeat / zero") {
            var t = TimerState(); try t.setDuration(10)
            try require(t.apply(.start, expectedRun: t.runID, expectedVersion: t.version, at: now), "Start")
            try require(t.remaining(at: now.addingTimeInterval(3)) == 7, "Deadline")
            try require(t.apply(.pause, expectedRun: t.runID, expectedVersion: t.version, at: now.addingTimeInterval(3)), "Pause")
            try require(t.remaining(at: now.addingTimeInterval(100)) == 7, "Paused remainder")
            try require(t.apply(.resume, expectedRun: t.runID, expectedVersion: t.version, at: now.addingTimeInterval(100)), "Resume")
            try require(t.remaining(at: now.addingTimeInterval(107)) == 0, "Zero")
            try require(t.remaining(at: now.addingTimeInterval(1000)) == 0, "Count up")
            let oldID = t.runID
            try require(t.apply(.repeatTimer, expectedRun: t.runID, expectedVersion: t.version, at: now.addingTimeInterval(200)), "Repeat")
            try require(t.runID != oldID && t.remaining(at: now.addingTimeInterval(200)) == 10, "Repeat duration")
        }
        try check("repeated and stale commands") {
            var t = TimerState(); let id = t.runID, version = t.version
            try require(t.apply(.start, expectedRun: id, expectedVersion: version, at: now), "Start")
            let copy = t
            try require(!t.apply(.reset, expectedRun: id, expectedVersion: version, at: now), "Stale reset")
            try require(t == copy, "Stale command changed state")
            try require(!t.apply(.start, expectedRun: id, expectedVersion: version, at: now), "Duplicate")
        }
        try check("running duration requires reset") {
            var t = TimerState(); t.apply(.start, expectedRun: t.runID, expectedVersion: t.version, at: now)
            do { try t.setDuration(30); throw TestFailure(description: "Duration changed while running") } catch StateError.invalidDuration {}
        }
        try check("quit / sleep / relaunch from persisted deadline") {
            var t = TimerState(); t.apply(.start, expectedRun: t.runID, expectedVersion: t.version, at: now)
            var decoded = try JSONDecoder().decode(TimerState.self, from: JSONEncoder().encode(t))
            decoded.normalize(at: now.addingTimeInterval(5000))
            try require(decoded.phase == .finished && decoded.remaining(at: now.addingTimeInterval(5000)) == 0, "Relaunch finish")
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("west-tests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = StateStore(directory: folder)
        try check("atomic persistence and six-clock capacity") {
            _ = try store.update { $0.clocks = Array(ClockCatalog.records.prefix(6)) }
            let firstCount = try tryReadCount(store); try require(firstCount == 6, "Lost clocks")
            do { _ = try store.update { $0.clocks.append(ClockCatalog.records[6]) }; throw TestFailure(description: "Accepted seventh") } catch StateError.corrupt {}
            let secondCount = try tryReadCount(store); try require(secondCount == 6, "Failed transaction mutated data")
        }
        try check("corrupt data preserved") {
            try Data("invalid-json".utf8).write(to: store.file)
            do { _ = try store.read(); throw TestFailure(description: "Silently reset corrupt data") } catch StateError.corrupt {}
            let corruptText = try String(contentsOf: store.file, encoding: .utf8); try require(corruptText == "invalid-json", "Overwrote corrupt data")
        }
        try check("unknown IANA and duplicate IDs rejected") {
            var s = AppState(); var r = berlin; r.zoneID = "Imaginary/City"; s.clocks = [r]
            do { try s.validate(); throw TestFailure(description: "Unknown zone") } catch StateError.corrupt {}
            s.clocks = [berlin, berlin]
            do { try s.validate(); throw TestFailure(description: "Duplicate IDs") } catch StateError.corrupt {}
        }
        return count
    }
    static func tryReadCount(_ store: StateStore) throws -> Int { try store.read().clocks.count }
}
#if CLI_TESTS
@main struct CoreTestRunner {
    static func main() throws {
        if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--increment" {
            let store = StateStore(directory: URL(fileURLWithPath: CommandLine.arguments[2]))
            for _ in 0..<40 { _ = try store.update { $0.timer.version += 1 } }; return
        }
        let count = try CoreChecks.run()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("west-process-tests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = StateStore(directory: folder)
        _ = try store.update { _ in }
        let processes = try (0..<6).map { _ -> Process in
            let p = Process(); p.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]); p.arguments = ["--increment", folder.path]; try p.run(); return p
        }
        for p in processes { p.waitUntilExit(); try CoreChecks.require(p.terminationStatus == 0, "Child failed") }
        let state = try store.read()
        try CoreChecks.require(state.timer.version == 240, "Lost interprocess writes: \(state.timer.version)")
        print("PASS six processes, 240 coordinated writes")
        print("\(count + 1) checks passed")
    }
}
#else
final class WESTCoreTests: XCTestCase {
    func testCoreBehavior() throws { XCTAssertGreaterThanOrEqual(try CoreChecks.run(), 16) }
}
#endif
