import Foundation

/// Synchronous disk operations. Production access is serialized by SessionStore.
nonisolated final class SessionFile: Sendable {
    let directory: URL
    var primaryURL: URL { directory.appendingPathComponent("session.json") }
    var backupURL: URL { directory.appendingPathComponent("session.backup.json") }

    struct LoadResult: Sendable {
        var session: Session
        var isFirstLaunch = false
        var recoveredFromBackup = false
    }

    init(directory: URL) {
        self.directory = directory
    }

    func load() throws -> LoadResult {
        let manager = FileManager.default
        let hasPrimary = manager.fileExists(atPath: primaryURL.path)
        let hasBackup = manager.fileExists(atPath: backupURL.path)
        guard hasPrimary || hasBackup else {
            return LoadResult(session: Session(), isFirstLaunch: true)
        }
        if hasPrimary {
            do {
                return LoadResult(session: try decode(Data(contentsOf: primaryURL)))
            } catch SessionError.unsupportedVersion(let version) {
                // Never replace a newer format with an older backup.
                throw SessionError.unsupportedVersion(version)
            } catch { /* Try the last complete snapshot below. */ }
        }
        do {
            return LoadResult(session: try decode(Data(contentsOf: backupURL)), recoveredFromBackup: true)
        } catch SessionError.unsupportedVersion(let version) {
            throw SessionError.unsupportedVersion(version)
        } catch {
            throw SessionError.unreadable
        }
    }

    func write(_ session: Session) throws {
        try session.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(session)
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)

        if manager.fileExists(atPath: primaryURL.path) {
            let previous = try Data(contentsOf: primaryURL)
            do {
                _ = try decode(previous)
                try previous.write(to: backupURL, options: .atomic)
            } catch SessionError.unsupportedVersion(let version) {
                throw SessionError.unsupportedVersion(version)
            } catch is DecodingError {
                try preserveUnreadableFile(previous)
            } catch SessionError.invalidContents {
                try preserveUnreadableFile(previous)
            }
        } else if !manager.fileExists(atPath: backupURL.path) {
            try data.write(to: backupURL, options: .atomic)
        }
        try data.write(to: primaryURL, options: .atomic)
    }

    private func preserveUnreadableFile(_ data: Data) throws {
        let url = directory.appendingPathComponent("session-unreadable-\(UUID().uuidString).json")
        try data.write(to: url, options: .atomic)
    }

    private func decode(_ data: Data) throws -> Session {
        // Read the version first, even if the rest of a future schema differs.
        struct Header: Decodable { let version: Int }
        let version = try JSONDecoder().decode(Header.self, from: data).version
        let session: Session
        switch version {
        case 1:
            // Version 1 had no close history. Preserve every existing note,
            // including hidden notes, rather than guessing when it was closed.
            struct LegacySession: Decodable {
                let notes: [Note]
                let windowOrder: [UUID]
                let activeNoteID: UUID?
            }
            let legacy = try JSONDecoder().decode(LegacySession.self, from: data)
            session = Session(notes: legacy.notes, windowOrder: legacy.windowOrder, activeNoteID: legacy.activeNoteID)
        case Session.currentVersion:
            session = try JSONDecoder().decode(Session.self, from: data)
        default:
            throw SessionError.unsupportedVersion(version)
        }
        try session.validate()
        return session
    }
}
