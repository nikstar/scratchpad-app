import AppKit
import XCTest
@testable import Scratchpad

final class NoteIntegrationTests: XCTestCase {
    private func makeCoordinator() throws -> (NoteCoordinator, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let coordinator = try NoteCoordinator(store: SessionStore(directory: directory))
        coordinator.start()
        return (coordinator, directory)
    }

    func testEditingClosingAndRecreatingNotesFromDisk() throws {
        let (coordinator, directory) = try makeCoordinator()
        let first = try XCTUnwrap(coordinator.session.notes.first)
        let controller = try XCTUnwrap(coordinator.controllers[first.id])
        let panel = try XCTUnwrap(controller.window as? NSPanel)
        defer {
            coordinator.controllers.values.forEach { $0.hide() }
        }
        XCTAssertTrue(panel.isFloatingPanel)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertFalse(controller.textView.isRichText)

        controller.textView.insertText("A tiny note 🐈\nSecond line", replacementRange: NSRange(location: 0, length: 0))
        XCTAssertEqual(coordinator.session.notes[0].text, "A tiny note 🐈\nSecond line")
        let frame = panel.frame.offsetBy(dx: 31, dy: -17)
        panel.setFrame(frame, display: true)
        controller.textView.setSelectedRange(NSRange(location: 2, length: 4))
        panel.performClose(nil)
        XCTAssertFalse(panel.isVisible)
        XCTAssertFalse(coordinator.session.notes[0].isVisible)
        XCTAssertEqual(coordinator.session.notes.count, 1)
        try coordinator.flush()

        let restored = try NoteCoordinator(store: SessionStore(directory: directory))
        restored.start()
        defer { restored.controllers.values.forEach { $0.hide() } }
        let reopened = try XCTUnwrap(restored.controllers[first.id])
        XCTAssertEqual(reopened.textView.string, controller.textView.string)
        XCTAssertEqual(reopened.window?.frame, frame)
        XCTAssertEqual(reopened.textView.selectedRange(), NSRange(location: 2, length: 4))
        XCTAssertFalse(try XCTUnwrap(reopened.window).isVisible)
        restored.showNote(first.id)
        XCTAssertTrue(try XCTUnwrap(reopened.window).isVisible)
    }

    func testLongNoteRestoresScrollAndSelection() throws {
        let (coordinator, directory) = try makeCoordinator()
        defer { coordinator.controllers.values.forEach { $0.hide() } }
        let note = try XCTUnwrap(coordinator.session.notes.first)
        let controller = try XCTUnwrap(coordinator.controllers[note.id])
        let text = (1...100).map { "Line \($0)" }.joined(separator: "\n")
        controller.textView.insertText(text, replacementRange: NSRange(location: 0, length: 0))
        controller.restoreEditor(EditorState(selectionLocation: 60, selectionLength: 3, scrollY: 120))
        try coordinator.flush()
        let restored = try NoteCoordinator(store: SessionStore(directory: directory))
        restored.start()
        defer { restored.controllers.values.forEach { $0.hide() } }
        let reopened = try XCTUnwrap(restored.controllers[note.id])
        XCTAssertEqual(reopened.editorState.selectionLocation, 60)
        XCTAssertEqual(reopened.editorState.selectionLength, 3)
        XCTAssertEqual(reopened.editorState.scrollY, 120, accuracy: 1)
    }

    func testDeletingLastBlankNoteRestoresEmptyWorkspace() throws {
        let (coordinator, directory) = try makeCoordinator()
        let id = try XCTUnwrap(coordinator.session.notes.first?.id)
        coordinator.deleteNote(id)
        try coordinator.flush()
        let restored = try NoteCoordinator(store: SessionStore(directory: directory))
        restored.start()
        XCTAssertTrue(restored.session.notes.isEmpty)
        XCTAssertTrue(restored.controllers.isEmpty)
    }

    func testMenuBarCanReopenNotesWhenAllWindowsAreHidden() throws {
        let (coordinator, _) = try makeCoordinator()
        defer { coordinator.controllers.values.forEach { $0.hide() } }
        coordinator.createNote()
        coordinator.hideAllNotes()
        let status = StatusItemController(coordinator: coordinator)
        defer { NSStatusBar.system.removeStatusItem(status.statusItem) }
        XCTAssertTrue(status.statusItem.isVisible)
        XCTAssertNotNil(status.statusItem.button?.image)
        let menu = try XCTUnwrap(status.statusItem.menu)
        status.menuNeedsUpdate(menu)
        let firstID = try XCTUnwrap(coordinator.session.notes.first?.id)
        let entryIndex = try XCTUnwrap(menu.items.firstIndex { $0.representedObject as? UUID == firstID })
        XCTAssertEqual(menu.items[entryIndex].state, .off)
        menu.performActionForItem(at: entryIndex)
        XCTAssertTrue(try XCTUnwrap(coordinator.controllers[firstID]?.window).isVisible)
        XCTAssertTrue(coordinator.session.notes[0].isVisible)
        XCTAssertFalse(coordinator.session.notes[1].isVisible)
        status.menuNeedsUpdate(menu)
        XCTAssertEqual(menu.items.first { $0.representedObject as? UUID == firstID }?.state, .on)
        try coordinator.flush()
    }
}
