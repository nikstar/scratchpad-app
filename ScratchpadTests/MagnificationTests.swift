import AppKit
import XCTest
@testable import Scratchpad

final class MagnificationTests: XCTestCase {
    private func makeCoordinator() throws -> (NoteCoordinator, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let coordinator = try NoteCoordinator(store: SessionStore(directory: directory))
        coordinator.start()
        addTeardownBlock {
            try coordinator.flush()
            coordinator.controllers.values.forEach { $0.close() }
            try? FileManager.default.removeItem(at: directory)
        }
        return (coordinator, directory)
    }

    func testMagnifierDoublesAndHalvesItsOwnNoteKeepingTopRight() throws {
        let (coordinator, _) = try makeCoordinator()
        let id = try XCTUnwrap(coordinator.session.notes.first?.id)
        let controller = try XCTUnwrap(coordinator.controllers[id])
        let panel = try XCTUnwrap(controller.window as? NotePanel)
        controller.textView.insertText("A tiny note 🐈", replacementRange: NSRange(location: 0, length: 0))
        controller.textView.setSelectedRange(NSRange(location: 2, length: 4))
        let original = panel.frame
        coordinator.createNote()
        let other = try XCTUnwrap(coordinator.controllers[try XCTUnwrap(coordinator.session.activeNoteID)])
        let otherFrame = other.window?.frame
        XCTAssertFalse(panel.isKeyWindow)
        panel.magnifyButton.performClick(nil)
        XCTAssertEqual(panel.frame.width, original.width * 2)
        XCTAssertEqual(panel.frame.height, original.height * 2)
        XCTAssertEqual(panel.frame.maxX, original.maxX)
        XCTAssertEqual(panel.frame.maxY, original.maxY)
        XCTAssertEqual(controller.textView.font?.pointSize, 26)
        XCTAssertEqual(controller.textView.selectedRange(), NSRange(location: 2, length: 4))
        XCTAssertEqual(controller.textView.string, "A tiny note 🐈")
        XCTAssertTrue(try XCTUnwrap(coordinator.session.notes.first { $0.id == id }).isMagnified)
        XCTAssertEqual(other.window?.frame, otherFrame)
        XCTAssertEqual(other.textView.font?.pointSize, 13)
        XCTAssertEqual(panel.magnifyButton.toolTip, "Restore Note Size")
        panel.magnifyButton.performClick(nil)
        XCTAssertEqual(panel.frame, original)
        XCTAssertEqual(controller.textView.font?.pointSize, 13)
        XCTAssertFalse(controller.isMagnified)
        // Changing display size must not add text-edit undo operations.
        controller.textView.undoManager?.undo()
        XCTAssertEqual(controller.textView.string, "")
    }

    func testResizedMagnifiedNoteHalvesFromItsCurrentFrame() throws {
        let (coordinator, _) = try makeCoordinator()
        let controller = try XCTUnwrap(coordinator.controllers.values.first)
        let panel = try XCTUnwrap(controller.window as? NotePanel)
        let normalMinimum = panel.minSize
        panel.magnifyButton.performClick(nil)
        XCTAssertEqual(panel.minSize.width, normalMinimum.width * 2)
        XCTAssertEqual(panel.minSize.height, normalMinimum.height * 2)
        panel.setFrame(NSRect(x: panel.frame.maxX - panel.minSize.width,
                             y: panel.frame.maxY - panel.minSize.height,
                             width: panel.minSize.width, height: panel.minSize.height), display: true)
        let resized = panel.frame
        panel.magnifyButton.performClick(nil)
        XCTAssertEqual(panel.frame.width, resized.width / 2)
        XCTAssertEqual(panel.frame.height, resized.height / 2)
        XCTAssertEqual(panel.frame.maxX, resized.maxX)
        XCTAssertEqual(panel.frame.maxY, resized.maxY)
        XCTAssertEqual(panel.minSize, normalMinimum)
    }

    func testMagnificationRestoresFromDiskAndRecentlyClosed() throws {
        let (coordinator, directory) = try makeCoordinator()
        let id = try XCTUnwrap(coordinator.session.notes.first?.id)
        let controller = try XCTUnwrap(coordinator.controllers[id])
        let panel = try XCTUnwrap(controller.window as? NotePanel)
        let text = (1...100).map { "Line \($0) 🐈" }.joined(separator: "\n")
        controller.textView.insertText(text, replacementRange: NSRange(location: 0, length: 0))
        controller.restoreEditor(EditorState(selectionLocation: 60, selectionLength: 3, scrollY: 120))
        panel.magnifyButton.performClick(nil)
        XCTAssertEqual(controller.editorState.scrollY, 240, accuracy: 1)
        let magnifiedFrame = panel.frame
        let editor = controller.editorState
        try coordinator.flush()
        let restored = try NoteCoordinator(store: SessionStore(directory: directory))
        restored.start()
        defer { restored.controllers.values.forEach { $0.close() } }
        var reopened = try XCTUnwrap(restored.controllers[id])
        XCTAssertTrue(reopened.isMagnified)
        XCTAssertEqual(reopened.textView.font?.pointSize, 26)
        XCTAssertEqual(reopened.window?.frame, magnifiedFrame)
        XCTAssertEqual(reopened.editorState, editor)
        reopened.window?.performClose(nil)
        try restored.flush()
        XCTAssertTrue(try XCTUnwrap(SessionFile(directory: directory).load().session.recentlyClosed.first).note.isMagnified)
        restored.reopenClosedNote(id)
        reopened = try XCTUnwrap(restored.controllers[id])
        XCTAssertTrue(reopened.isMagnified)
        XCTAssertEqual(reopened.window?.frame, magnifiedFrame)
        XCTAssertEqual(reopened.editorState, editor)
        reopened.textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        reopened.textView.insertText("!", replacementRange: NSRange(location: NSNotFound, length: 0))
        let font = reopened.textView.textStorage?.attribute(.font, at: (text as NSString).length, effectiveRange: nil) as? NSFont
        XCTAssertEqual(font?.pointSize, 26)
        try restored.flush()
    }

    func testEnlargingNearScreenEdgeKeepsAnchorAndRestoresExactFrame() throws {
        let (coordinator, directory) = try makeCoordinator()
        let id = try XCTUnwrap(coordinator.session.notes.first?.id)
        let panel = try XCTUnwrap(coordinator.controllers[id]?.window as? NotePanel)
        let visible = try XCTUnwrap(panel.screen?.visibleFrame)
        panel.setFrame(NSRect(x: visible.minX + 16, y: visible.maxY - 290, width: 280, height: 220), display: true)
        let original = panel.frame
        panel.magnifyButton.performClick(nil)
        XCTAssertEqual(panel.frame.width, original.width * 2)
        XCTAssertEqual(panel.frame.height, original.height * 2)
        XCTAssertEqual(panel.frame.maxX, original.maxX)
        XCTAssertEqual(panel.frame.maxY, original.maxY)
        let expanded = panel.frame
        try coordinator.flush()
        let restored = try NoteCoordinator(store: SessionStore(directory: directory))
        restored.start()
        defer { restored.controllers.values.forEach { $0.close() } }
        let reopened = try XCTUnwrap(restored.controllers[id]?.window as? NotePanel)
        XCTAssertEqual(reopened.frame, expanded)
        reopened.magnifyButton.performClick(nil)
        XCTAssertEqual(reopened.frame, original)
        try restored.flush()
    }

    func testEnlargementCanExceedScreenSizeWithoutMovingTopRight() throws {
        let (coordinator, _) = try makeCoordinator()
        let panel = try XCTUnwrap(coordinator.controllers.values.first?.window as? NotePanel)
        let visible = try XCTUnwrap(panel.screen?.visibleFrame)
        let size = NSSize(width: floor(visible.width * 0.6), height: floor(visible.height * 0.6))
        panel.setFrame(NSRect(x: visible.maxX - size.width - 20, y: visible.maxY - size.height - 20,
                             width: size.width, height: size.height), display: true)
        let original = panel.frame
        panel.magnifyButton.performClick(nil)
        XCTAssertEqual(panel.frame.width, original.width * 2)
        XCTAssertEqual(panel.frame.height, original.height * 2)
        XCTAssertEqual(panel.frame.maxX, original.maxX)
        XCTAssertEqual(panel.frame.maxY, original.maxY)
        panel.magnifyButton.performClick(nil)
        XCTAssertEqual(panel.frame, original)
    }
}
