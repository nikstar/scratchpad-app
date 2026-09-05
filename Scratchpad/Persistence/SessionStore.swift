import Foundation

@MainActor
final class SessionStore {
    private let file: SessionFile
    private let writer = DispatchQueue(label: "me.nikstar.Scratchpad.persistence", qos: .userInitiated)
    private var revision = 0
    var onWriteResult: ((Error?) -> Void)?

    init(directory: URL) {
        file = SessionFile(directory: directory)
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Scratchpad", isDirectory: true)
    }

    func load() throws -> SessionFile.LoadResult {
        try writer.sync { try file.load() }
    }

    /// Enqueue every text change immediately. A single writer preserves ordering;
    /// atomic replacement means interruption cannot leave half-written JSON.
    func save(_ session: Session) {
        revision += 1
        let revision = revision
        let file = file
        writer.async { [weak self] in
            let error: Error?
            do {
                try file.write(session)
                error = nil
            } catch let writeError {
                error = writeError
            }
            Task { @MainActor [weak self] in
                guard let self, self.revision == revision else { return }
                self.onWriteResult?(error)
            }
        }
    }

    /// Drain pending writes and synchronously persist the final snapshot at quit.
    func flush(_ session: Session) throws {
        revision += 1
        try writer.sync { try file.write(session) }
        onWriteResult?(nil)
    }
}
