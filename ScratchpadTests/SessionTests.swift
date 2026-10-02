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
        var closed = note
        closed.id = UUID()
        closed.text = "Recently closed 🦊"
        return Session(notes: [note, hidden], windowOrder: [hidden.id, note.id], activeNoteID: note.id,
                       recentlyClosed: [ClosedNote(note: closed, closedAt: Date(timeIntervalSince1970: 1_780_000_000))])
    }

    func testFullWorkspaceRoundTrip() throws {
        let file = SessionFile(directory: try temporaryDirectory())
        var original = exampleSession()
        original.newNoteHome = NoteHomePosition(frame: original.notes[0].placement.frame,
                                               on: Display(id: 7, visibleFrame: original.notes[0].placement.displayVisibleFrame!))
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
        var original = exampleSession()
        original.newNoteHome = NoteHomePosition(frame: original.notes[0].placement.frame,
                                               on: Display(id: 7, visibleFrame: original.notes[0].placement.displayVisibleFrame!))
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

    private func versionOneData(_ session: Session) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        json["version"] = 1
        json.removeValue(forKey: "recentlyClosed")
        json["notes"] = (json["notes"] as? [[String: Any]])?.map { note in
            var note = note
            note.removeValue(forKey: "isMagnified")
            return note
        }
        return try JSONSerialization.data(withJSONObject: json)
    }

    func testVersionOneMigrationPreservesEveryNoteAndItsVisibility() throws {
        let file = SessionFile(directory: try temporaryDirectory())
        var expected = exampleSession()
        expected.recentlyClosed = []
        let original = try versionOneData(expected)
        try original.write(to: file.primaryURL)
        let migrated = try file.load()
        XCTAssertFalse(migrated.isFirstLaunch)
        XCTAssertEqual(migrated.session, expected)
        XCTAssertEqual(migrated.session.version, Session.currentVersion)
        XCTAssertEqual(try Data(contentsOf: file.primaryURL), original)
        try file.write(migrated.session)
        XCTAssertEqual(try file.load().session, expected)
        XCTAssertEqual(try Data(contentsOf: file.backupURL), original)
    }

    func testVersionOneBackupStillRecoversAfterMigration() throws {
        let file = SessionFile(directory: try temporaryDirectory())
        var expected = exampleSession()
        expected.recentlyClosed = []
        try versionOneData(expected).write(to: file.backupURL)
        try Data("{incomplete".utf8).write(to: file.primaryURL)
        let loaded = try file.load()
        XCTAssertTrue(loaded.recoveredFromBackup)
        XCTAssertEqual(loaded.session, expected)
        try file.write(loaded.session)
        XCTAssertEqual(try file.load().session, expected)
    }

    func testCloseHistoryUsesDatesAndDiscardsOldestBeyondTwelve() throws {
        var session = Session()
        let base = exampleSession().notes[0]
        // Insert out of date order to verify ordering by closure date itself.
        for number in [4, 0, 14, 8, 2, 1, 6, 5, 13, 3, 9, 12, 11, 10, 7] {
            var note = base
            note.id = UUID()
            note.text = "Closed \(number)"
            session.rememberClosed(note, at: Date(timeIntervalSince1970: Double(number)))
        }
        XCTAssertEqual(session.recentlyClosed.map { $0.note.text }, (3...14).reversed().map { "Closed \($0)" })
        try session.validate()
        let file = SessionFile(directory: try temporaryDirectory())
        try file.write(session)
        XCTAssertEqual(try file.load().session, session)
    }

    func testInvalidClosedNoteStateIsRejected() throws {
        var session = exampleSession()
        session.recentlyClosed[0].note.id = session.notes[0].id
        XCTAssertThrowsError(try session.validate())
        session = exampleSession()
        session.recentlyClosed[0].note.editor.scrollY = -1
        XCTAssertThrowsError(try session.validate())
        session = exampleSession()
        session.recentlyClosed.append(session.recentlyClosed[0])
        XCTAssertThrowsError(try session.validate())
    }

    func testVersionTwoMigrationPreservesCurrentAndRecentlyClosedNotes() throws {
        let file = SessionFile(directory: try temporaryDirectory())
        let expected = exampleSession()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(expected)) as? [String: Any])
        json["version"] = 2
        func legacyNote(_ note: [String: Any]) -> [String: Any] {
            var note = note
            note.removeValue(forKey: "isMagnified")
            return note
        }
        json["notes"] = try XCTUnwrap(json["notes"] as? [[String: Any]]).map(legacyNote)
        json["recentlyClosed"] = try XCTUnwrap(json["recentlyClosed"] as? [[String: Any]]).map { entry in
            var entry = entry
            entry["note"] = legacyNote(try XCTUnwrap(entry["note"] as? [String: Any]))
            return entry
        }
        let original = try JSONSerialization.data(withJSONObject: json)
        try original.write(to: file.primaryURL)
        let migrated = try file.load().session
        XCTAssertEqual(migrated, expected)
        XCTAssertFalse(migrated.notes.contains(where: \.isMagnified))
        XCTAssertFalse(migrated.recentlyClosed.contains { $0.note.isMagnified })
        try file.write(migrated)
        XCTAssertEqual(try Data(contentsOf: file.backupURL), original)
        try Data("{incomplete".utf8).write(to: file.primaryURL)
        XCTAssertEqual(try file.load().session, expected)
    }

    func testVersionThreeMigrationPreservesWorkspaceAndLeavesHomeUnconfigured() throws {
        let file = SessionFile(directory: try temporaryDirectory())
        var expected = exampleSession()
        expected.notes[0].isMagnified = true
        expected.recentlyClosed[0].note.isMagnified = true
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(expected)) as? [String: Any])
        json["version"] = 3
        json.removeValue(forKey: "newNoteHome")
        let original = try JSONSerialization.data(withJSONObject: json)
        try original.write(to: file.primaryURL)
        let migrated = try file.load().session
        XCTAssertEqual(migrated, expected)
        XCTAssertNil(migrated.newNoteHome)
        XCTAssertEqual(try Data(contentsOf: file.primaryURL), original)
        try file.write(migrated)
        XCTAssertEqual(try Data(contentsOf: file.backupURL), original)
        try Data("{incomplete".utf8).write(to: file.primaryURL)
        let recovered = try file.load()
        XCTAssertTrue(recovered.recoveredFromBackup)
        XCTAssertEqual(recovered.session, expected)
    }

    func testInvalidHomeInsetsAreRejectedWithoutReplacingSavedState() throws {
        let file = SessionFile(directory: try temporaryDirectory())
        let original = exampleSession()
        try file.write(original)
        for invalid in [CGFloat(-1), .infinity, .nan] {
            for horizontal in [true, false] {
                var session = original
                var home = NoteHomePosition(frame: original.notes[0].placement.frame,
                                            on: Display(id: 7, visibleFrame: original.notes[0].placement.displayVisibleFrame!))
                if horizontal { home.horizontalInset = invalid } else { home.verticalInset = invalid }
                session.newNoteHome = home
                XCTAssertThrowsError(try file.write(session))
                XCTAssertEqual(try file.load().session, original)
            }
        }
    }
}
