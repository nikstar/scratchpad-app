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

    func testTitlebarPlusCreatesNoteAndPreservesCompactChrome() throws {
        let (coordinator, directory) = try makeCoordinator()
        defer { coordinator.controllers.values.forEach { $0.hide() } }
        let controller = try XCTUnwrap(coordinator.controllers.values.first)
        let panel = try XCTUnwrap(controller.window as? NotePanel)
        let originalFrame = panel.frame
        let reference = NSPanel(contentRect: .zero, styleMask: panel.styleMask, backing: .buffered, defer: false)
        let standardContentHeight = reference.contentRect(forFrameRect: originalFrame).height
        XCTAssertEqual(controller.scrollView.frame.height, standardContentHeight, accuracy: 0.5)
        XCTAssertTrue(panel.newNoteButton.window === panel)
        panel.newNoteButton.performClick(nil)
        XCTAssertEqual(coordinator.session.notes.count, 2)
        XCTAssertEqual(panel.frame, originalFrame)
        XCTAssertTrue(coordinator.session.notes.allSatisfy(\.isVisible))

        panel.setContentSize(panel.contentMinSize)
        panel.contentView?.superview?.layoutSubtreeIfNeeded()
        let buttonFrame = panel.newNoteButton.convert(panel.newNoteButton.bounds, to: nil)
        XCTAssertGreaterThanOrEqual(buttonFrame.minX, panel.frame.width - 40)
        XCTAssertLessThanOrEqual(buttonFrame.maxX, panel.frame.width)
        XCTAssertGreaterThanOrEqual(buttonFrame.minY, controller.scrollView.frame.maxY)
        try coordinator.flush()
        XCTAssertEqual(try SessionFile(directory: directory).load().session.notes.count, 2)
    }

    func testDockReopenKeepsOtherHiddenNotesHidden() throws {
        let (coordinator, _) = try makeCoordinator()
        defer { coordinator.controllers.values.forEach { $0.hide() } }
        coordinator.createNote()
        let active = try XCTUnwrap(coordinator.session.activeNoteID)
        coordinator.hideAllNotes()
        coordinator.reopen()
        XCTAssertEqual(coordinator.session.notes.filter(\.isVisible).map(\.id), [active])
        XCTAssertTrue(try XCTUnwrap(coordinator.controllers[active]?.window).isVisible)
        coordinator.reopen()
        XCTAssertEqual(coordinator.session.notes.count, 2)
        XCTAssertEqual(coordinator.session.notes.filter(\.isVisible).map(\.id), [active])
        try coordinator.flush()
    }

    func testDockReopenCreatesNoteInEmptyWorkspace() throws {
        let (coordinator, _) = try makeCoordinator()
        defer { coordinator.controllers.values.forEach { $0.hide() } }
        coordinator.deleteNote(try XCTUnwrap(coordinator.session.notes.first?.id))
        coordinator.reopen()
        XCTAssertEqual(coordinator.session.notes.count, 1)
        XCTAssertTrue(try XCTUnwrap(coordinator.controllers.values.first?.window).isVisible)
        try coordinator.flush()
    }

    func testPlusUsesItsOwnWindowAndNewNoteCommandUsesCurrentWindow() throws {
        let (coordinator, _) = try makeCoordinator()
        defer { coordinator.controllers.values.forEach { $0.hide() } }
        let sourceID = try XCTUnwrap(coordinator.session.notes.first?.id)
        let source = try XCTUnwrap(coordinator.controllers[sourceID]?.window as? NotePanel)
        let screen = try XCTUnwrap(source.screen)
        source.setFrame(CGRect(x: screen.visibleFrame.minX + 70, y: screen.visibleFrame.maxY - 400,
                               width: 330, height: 280), display: true)
        coordinator.createNote()
        let current = try XCTUnwrap(coordinator.controllers[try XCTUnwrap(coordinator.session.activeNoteID)]?.window)
        XCTAssertFalse(source.isKeyWindow)

        // Press plus in an older, inactive note while another note is current.
        source.newNoteButton.performClick(nil)
        let fromPlus = try XCTUnwrap(coordinator.controllers[try XCTUnwrap(coordinator.session.activeNoteID)]?.window)
        XCTAssertEqual(fromPlus.frame.minX, source.frame.minX + 22)
        XCTAssertEqual(fromPlus.frame.maxY, source.frame.maxY - 22)
        XCTAssertNotEqual(fromPlus.frame.minX, current.frame.minX + 22)

        coordinator.createNote()
        let fromCommand = try XCTUnwrap(coordinator.controllers[try XCTUnwrap(coordinator.session.activeNoteID)]?.window)
        XCTAssertEqual(fromCommand.frame.minX, fromPlus.frame.minX + 22)
        XCTAssertEqual(fromCommand.frame.maxY, fromPlus.frame.maxY - 22)
        try coordinator.flush()
    }
}
