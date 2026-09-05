import AppKit
import XCTest
@testable import Scratchpad

final class SessionTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func exampleSession() -> Session {
        var note = Note(text: "A little scratchpad 🐈\nПривет\n日本語\t  \n", placement: WindowPlacement(
            frame: CGRect(x: -800.5, y: 321.5, width: 280, height: 220),
            displayID: 7,
            displayVisibleFrame: CGRect(x: -1440, y: 0, width: 1440, height: 880)
        ))
        note.editor = EditorState(selectionLocation: 3, selectionLength: 6, scrollY: 48.5)
        var hidden = note
        hidden.id = UUID()
        hidden.text = "Hidden note"
        hidden.isVisible = false
        return Session(notes: [note, hidden], windowOrder: [hidden.id, note.id], activeNoteID: note.id)
    }

    func testFullWorkspaceRoundTrip() throws {
        let file = SessionFile(directory: try temporaryDirectory())
        let original = exampleSession()
        try file.write(original)
        let loaded = try file.load()
        XCTAssertEqual(loaded.session, original)
        XCTAssertFalse(loaded.isFirstLaunch)
        XCTAssertFalse(loaded.recoveredFromBackup)
    }

    func testEmptyWorkspaceIsNotFirstLaunch() throws {
        let file = SessionFile(directory: try temporaryDirectory())
        XCTAssertTrue(try file.load().isFirstLaunch)
        try file.write(Session())
        XCTAssertFalse(try file.load().isFirstLaunch)
        XCTAssertTrue(try file.load().session.notes.isEmpty)
    }

    func testCorruptPrimaryRecoversBackupAndPreservesOriginal() throws {
        let directory = try temporaryDirectory()
        let file = SessionFile(directory: directory)
        let original = exampleSession()
        try file.write(original)
        var next = original
        next.notes[0].text = "Newer snapshot"
        try file.write(next)
        let corrupt = Data("{incomplete".utf8)
        try corrupt.write(to: file.primaryURL)
        let loaded = try file.load()
        XCTAssertTrue(loaded.recoveredFromBackup)
        XCTAssertEqual(loaded.session, original)
        try file.write(loaded.session)
        let preserved = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasPrefix("session-unreadable-") })
        XCTAssertEqual(try Data(contentsOf: preserved), corrupt)
        XCTAssertEqual(try file.load().session, original)
    }

    func testUnreadableSessionIsNotSilentlyReset() throws {
        let file = SessionFile(directory: try temporaryDirectory())
        let data = Data("bad data".utf8)
        try data.write(to: file.primaryURL)
        try data.write(to: file.backupURL)
        XCTAssertThrowsError(try file.load())
        XCTAssertEqual(try Data(contentsOf: file.primaryURL), data)
        XCTAssertEqual(try Data(contentsOf: file.backupURL), data)
    }

    func testFutureSchemaIsNeverReplacedWithOldBackup() throws {
        let file = SessionFile(directory: try temporaryDirectory())
        try file.write(exampleSession())
        let future = Data(#"{"version":999,"differentSchema":true}"#.utf8)
        try future.write(to: file.primaryURL)
        XCTAssertThrowsError(try file.load()) { error in
            guard case SessionError.unsupportedVersion(999) = error else {
                return XCTFail("Expected unsupported version, received \(error)")
            }
        }
        XCTAssertThrowsError(try file.write(Session()))
        XCTAssertEqual(try Data(contentsOf: file.primaryURL), future)
    }

    func testInvalidIDsAndGeometryAreRejected() throws {
        var session = exampleSession()
        session.notes.append(session.notes[0])
        XCTAssertThrowsError(try session.validate())
        session = exampleSession()
        session.notes[0].placement.frame.size.width = -1
        XCTAssertThrowsError(try session.validate())
    }

    func testFlushWaitsForQueuedWritesAndKeepsLatestText() throws {
        let directory = try temporaryDirectory()
        let store = SessionStore(directory: directory)
        var session = exampleSession()
        for number in 0..<30 {
            session.notes[0].text = "Typing \(number)"
            store.save(session)
        }
        session.notes[0].text = "Final text 🦊"
        try store.flush(session)
        XCTAssertEqual(try SessionFile(directory: directory).load().session, session)
    }

    func testWriteFailureReachesCaller() throws {
        let directory = try temporaryDirectory()
        let occupied = directory.appendingPathComponent("not-a-directory")
        try Data("file".utf8).write(to: occupied)
        XCTAssertThrowsError(try SessionStore(directory: occupied).flush(exampleSession()))
    }

    func testSelectionUsesUTF16AndClampsOutOfBounds() {
        let text = "a🐈b"
        XCTAssertEqual(EditorState(selectionLocation: 1, selectionLength: 2).selection(in: text), NSRange(location: 1, length: 2))
        XCTAssertEqual(EditorState(selectionLocation: 99, selectionLength: Int.max).selection(in: text), NSRange(location: 4, length: 0))
    }
}
