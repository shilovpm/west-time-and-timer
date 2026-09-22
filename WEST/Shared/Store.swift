import Foundation
import Darwin

// All clients lock the same stable sidecar inode, never the atomically replaced data file.
final class StateLock: @unchecked Sendable {
    private let fd: Int32
    init(url: URL) throws {
        fd = open(url.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw StateError.io }
        guard flock(fd, LOCK_EX) == 0 else { close(fd); throw StateError.io }
    }
    deinit { flock(fd, LOCK_UN); close(fd) }
}
struct StateStore: Sendable {
    let directory: URL
    static func shared() throws -> StateStore {
        let localMode = (Bundle.main.object(forInfoDictionaryKey: "WESTUseLocalSharedStorage") as? String) == "YES"
        if localMode, let url = localSharedDirectory() { return StateStore(directory: url) }
        if let group = Bundle.main.object(forInfoDictionaryKey: "WESTAppGroup") as? String,
           let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
            return StateStore(directory: url)
        }
        throw StateError.unavailableGroup
    }
    // Local ad-hoc builds cannot provision an App Group. Both sandboxed processes receive
    // a narrowly scoped home-relative file exception for this directory instead.
    private static func localSharedDirectory() -> URL? {
        guard let account = getpwuid(getuid()), let home = account.pointee.pw_dir else { return nil }
        return URL(fileURLWithPath: String(cString: home), isDirectory: true)
            .appendingPathComponent("Library/Application Support/WEST time and timer Shared", isDirectory: true)
    }
    var file: URL { directory.appendingPathComponent("state.json") }
    func lock() throws -> StateLock {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try StateLock(url: directory.appendingPathComponent("state.lock"))
    }
    func lockAsync() async throws -> StateLock {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try lock() })
            }
        }
    }
    // Caller must retain a StateLock for the entire read/change/write/side-effect transaction.
    func readLocked() throws -> AppState {
        guard FileManager.default.fileExists(atPath: file.path) else { return AppState() }
        let state: AppState
        do { state = try JSONDecoder().decode(AppState.self, from: Data(contentsOf: file)); try state.validate() }
        catch { throw StateError.corrupt }
        return state
    }
    func writeLocked(_ state: AppState) throws {
        try state.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(state).write(to: file, options: .atomic)
    }
    func read() throws -> AppState {
        let token = try lock(); defer { withExtendedLifetime(token) {} }
        return try readLocked()
    }
    func update(_ change: (inout AppState) throws -> Void) throws -> AppState {
        let token = try lock(); defer { withExtendedLifetime(token) {} }
        var state = try readLocked(); try change(&state); try writeLocked(state); return state
    }
}
