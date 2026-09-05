import Foundation

nonisolated struct Session: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version = currentVersion
    var notes: [Note] = []
    /// Back to front, independent of the notes' creation order.
    var windowOrder: [UUID] = []
    var activeNoteID: UUID?

    func validate() throws {
        guard version == Self.currentVersion else {
            throw SessionError.unsupportedVersion(version)
        }
        let ids = Set(notes.map(\.id))
        guard ids.count == notes.count,
              Set(windowOrder).count == windowOrder.count,
              Set(windowOrder).isSubset(of: ids),
              activeNoteID.map({ ids.contains($0) }) ?? true,
              notes.allSatisfy({ $0.placement.isValid && $0.editor.isValid }) else {
            throw SessionError.invalidContents
        }
    }
}

nonisolated struct Note: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var text = ""
    var isVisible = true
    var placement: WindowPlacement
    var editor = EditorState()

    var title: String {
        let line = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? "New Note"
        return line.count > 44 ? String(line.prefix(44)) + "…" : line
    }
}

nonisolated struct EditorState: Codable, Equatable, Sendable {
    var selectionLocation = 0
    var selectionLength = 0
    var scrollY = 0.0

    var isValid: Bool {
        selectionLocation >= 0 && selectionLength >= 0 && scrollY.isFinite && scrollY >= 0
    }

    func selection(in text: String) -> NSRange {
        let count = (text as NSString).length
        let location = min(max(0, selectionLocation), count)
        return NSRange(location: location, length: min(max(0, selectionLength), count - location))
    }
}

nonisolated enum SessionError: LocalizedError {
    case unsupportedVersion(Int)
    case invalidContents
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "These notes use storage version \(version). Open them with a compatible version of Scratchpad."
        case .invalidContents:
            return "The saved notes contain invalid window or editor state."
        case .unreadable:
            return "Scratchpad couldn’t read its saved notes or their backup. The existing files have been left untouched."
        }
    }
}
