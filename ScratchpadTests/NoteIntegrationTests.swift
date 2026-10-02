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
        XCTAssertTrue(coordinator.session.notes.isEmpty)
        XCTAssertTrue(coordinator.controllers.isEmpty)
        XCTAssertTrue(coordinator.session.windowOrder.isEmpty)
        XCTAssertNil(coordinator.session.activeNoteID)
        XCTAssertEqual(coordinator.session.recentlyClosed.first?.note.id, first.id)
        try coordinator.flush()

        let restored = try NoteCoordinator(store: SessionStore(directory: directory))
        restored.start()
        defer { restored.controllers.values.forEach { $0.hide() } }
        XCTAssertTrue(restored.controllers.isEmpty)
        XCTAssertEqual(restored.session.recentlyClosed, coordinator.session.recentlyClosed)
        restored.reopenClosedNote(first.id)
        let reopened = try XCTUnwrap(restored.controllers[first.id])
        XCTAssertEqual(reopened.textView.string, controller.textView.string)
        XCTAssertEqual(reopened.window?.frame, frame)
        XCTAssertEqual(reopened.textView.selectedRange(), NSRange(location: 2, length: 4))
        XCTAssertTrue(try XCTUnwrap(reopened.window).isVisible)
        XCTAssertTrue(restored.session.recentlyClosed.isEmpty)
        XCTAssertEqual(restored.session.activeNoteID, first.id)
        try restored.flush()
        let saved = try SessionFile(directory: directory).load().session
        XCTAssertEqual(saved.notes.map(\.id), [first.id])
        XCTAssertTrue(saved.recentlyClosed.isEmpty)
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

    func testClosingLastBlankNoteRestoresEmptyWorkspace() throws {
        let (coordinator, directory) = try makeCoordinator()
        let id = try XCTUnwrap(coordinator.session.notes.first?.id)
        coordinator.closeNote(id)
        try coordinator.flush()
        let restored = try NoteCoordinator(store: SessionStore(directory: directory))
        restored.start()
        XCTAssertTrue(restored.session.notes.isEmpty)
        XCTAssertTrue(restored.controllers.isEmpty)
        XCTAssertEqual(restored.session.recentlyClosed.map { $0.note.id }, [id])
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
        // The home-position action also carries the selected note's ID.
        XCTAssertEqual(menu.items.first {
            $0.representedObject as? UUID == firstID && $0.action == NSSelectorFromString("openNote:")
        }?.state, .on)
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
        let magnifyFrame = panel.magnifyButton.convert(panel.magnifyButton.bounds, to: nil)
        XCTAssertTrue(panel.magnifyButton.window === panel)
        XCTAssertGreaterThanOrEqual(magnifyFrame.minX, 0)
        XCTAssertLessThanOrEqual(magnifyFrame.maxX, buttonFrame.minX - 4)
        XCTAssertGreaterThanOrEqual(magnifyFrame.minY, controller.scrollView.frame.maxY)
        XCTAssertEqual(panel.magnifyButton.alphaValue, panel.newNoteButton.alphaValue)
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
        let closedID = try XCTUnwrap(coordinator.session.notes.first?.id)
        coordinator.closeNote(closedID)
        coordinator.reopen()
        XCTAssertEqual(coordinator.session.notes.count, 1)
        XCTAssertNotEqual(coordinator.session.notes.first?.id, closedID)
        XCTAssertEqual(coordinator.session.recentlyClosed.map { $0.note.id }, [closedID])
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

    func testActiveDockClickCreatesOnceThenReusesTheBlankNote() throws {
        let (coordinator, _) = try makeCoordinator()
        defer { coordinator.controllers.values.forEach { $0.hide() } }
        let source = try XCTUnwrap(coordinator.controllers.values.first)
        source.textView.insertText("Existing text", replacementRange: NSRange(location: 0, length: 0))
        coordinator.reopen(wasAlreadyActive: false)
        XCTAssertEqual(coordinator.session.notes.count, 1)

        coordinator.reopen(wasAlreadyActive: true)
        XCTAssertEqual(coordinator.session.notes.count, 2)
        let blankID = try XCTUnwrap(coordinator.session.activeNoteID)
        XCTAssertTrue(try XCTUnwrap(coordinator.session.notes.first { $0.id == blankID }).text.isEmpty)
        coordinator.reopen(wasAlreadyActive: true)
        XCTAssertEqual(coordinator.session.notes.count, 2)
        XCTAssertEqual(coordinator.session.activeNoteID, blankID)
        try coordinator.flush()
    }

    func testActiveDockClickReopensHiddenBlankWithoutTreatingWhitespaceAsEmpty() throws {
        let (coordinator, _) = try makeCoordinator()
        defer { coordinator.controllers.values.forEach { $0.hide() } }
        let blankID = try XCTUnwrap(coordinator.session.notes.first?.id)
        coordinator.createNote()
        let textID = try XCTUnwrap(coordinator.session.activeNoteID)
        let editor = try XCTUnwrap(coordinator.controllers[textID]?.textView)
        editor.insertText(" \n\t", replacementRange: NSRange(location: 0, length: 0))
        coordinator.hideNote(blankID)
        coordinator.reopen(wasAlreadyActive: true)
        XCTAssertEqual(coordinator.session.notes.count, 2)
        XCTAssertEqual(coordinator.session.activeNoteID, blankID)
        XCTAssertTrue(try XCTUnwrap(coordinator.controllers[blankID]?.window).isVisible)
        XCTAssertEqual(editor.string, " \n\t")
        try coordinator.flush()
    }

    func testActiveDockClickPrefersVisibleBlankOverHiddenBlank() throws {
        let (coordinator, _) = try makeCoordinator()
        defer { coordinator.controllers.values.forEach { $0.hide() } }
        let visibleBlankID = try XCTUnwrap(coordinator.session.notes.first?.id)
        coordinator.createNote()
        let hiddenBlankID = try XCTUnwrap(coordinator.session.activeNoteID)
        coordinator.hideNote(hiddenBlankID)
        coordinator.createNote()
        let editor = try XCTUnwrap(coordinator.controllers[try XCTUnwrap(coordinator.session.activeNoteID)]?.textView)
        editor.insertText("Current note", replacementRange: NSRange(location: 0, length: 0))
        coordinator.reopen(wasAlreadyActive: true)
        XCTAssertEqual(coordinator.session.notes.count, 3)
        XCTAssertEqual(coordinator.session.activeNoteID, visibleBlankID)
        XCTAssertFalse(try XCTUnwrap(coordinator.controllers[hiddenBlankID]?.window).isVisible)
        try coordinator.flush()
    }

    func testRecentlyClosedMenuReopensAndClosingAgainMovesNoteToTop() throws {
        let (coordinator, directory) = try makeCoordinator()
        defer { coordinator.controllers.values.forEach { $0.hide() } }
        let firstID = try XCTUnwrap(coordinator.session.notes.first?.id)
        coordinator.controllers[firstID]?.textView.insertText("First note 🐈", replacementRange: NSRange(location: 0, length: 0))
        coordinator.createNote()
        let secondID = try XCTUnwrap(coordinator.session.activeNoteID)
        coordinator.controllers[secondID]?.textView.insertText("Second note", replacementRange: NSRange(location: 0, length: 0))
        // Close out of creation order; the menu must follow the close dates.
        coordinator.controllers[secondID]?.window?.performClose(nil)
        coordinator.controllers[firstID]?.window?.performClose(nil)
        let status = StatusItemController(coordinator: coordinator)
        defer { NSStatusBar.system.removeStatusItem(status.statusItem) }
        let menu = try XCTUnwrap(status.statusItem.menu)
        status.menuNeedsUpdate(menu)
        XCTAssertNil(menu.item(withTitle: "Delete Note"))
        XCTAssertNil(menu.items.first { $0.representedObject is UUID })
        let recent = try XCTUnwrap(menu.item(withTitle: "Recently Closed")?.submenu)
        XCTAssertEqual(recent.items.map(\.title), ["First note 🐈", "Second note"])
        recent.performActionForItem(at: 1)
        XCTAssertEqual(coordinator.session.notes.map(\.id), [secondID])
        XCTAssertTrue(try XCTUnwrap(coordinator.controllers[secondID]?.window).isVisible)
        XCTAssertEqual(coordinator.session.recentlyClosed.map { $0.note.id }, [firstID])
        coordinator.controllers[secondID]?.window?.performClose(nil)
        // A repeated/stale close cannot add the same note twice.
        coordinator.closeNote(secondID)
        status.menuNeedsUpdate(menu)
        XCTAssertEqual(menu.item(withTitle: "Recently Closed")?.submenu?.items.map(\.title), ["Second note", "First note 🐈"])
        try coordinator.flush()
        XCTAssertEqual(try SessionFile(directory: directory).load().session.recentlyClosed.map { $0.note.id }, [secondID, firstID])
    }

    func testClosingLongNoteRestoresScrollSelectionAndReleasesController() throws {
        weak var closedController: NoteWindowController?
        // AppKit autoreleases objects while creating and closing windows.
        let coordinator = try autoreleasepool {
            let (coordinator, _) = try makeCoordinator()
            let id = try XCTUnwrap(coordinator.session.notes.first?.id)
            closedController = coordinator.controllers[id]
            coordinator.controllers[id]?.textView.insertText((1...100).map { "Line \($0)" }.joined(separator: "\n"),
                                                            replacementRange: NSRange(location: 0, length: 0))
            coordinator.controllers[id]?.restoreEditor(EditorState(selectionLocation: 60, selectionLength: 3, scrollY: 120))
            coordinator.controllers[id]?.window?.performClose(nil)
            return coordinator
        }
        defer { coordinator.controllers.values.forEach { $0.hide() } }
        XCTAssertNil(closedController)
        let id = try XCTUnwrap(coordinator.session.recentlyClosed.first?.note.id)
        coordinator.reopenClosedNote(id)
        let restored = try XCTUnwrap(coordinator.controllers[id])
        XCTAssertEqual(restored.editorState.selectionLocation, 60)
        XCTAssertEqual(restored.editorState.selectionLength, 3)
        XCTAssertEqual(restored.editorState.scrollY, 120, accuracy: 1)
        try coordinator.flush()
    }

    func testQuitSnapshotKeepsOpenAndHiddenNotesOutOfRecentlyClosed() throws {
        let (coordinator, directory) = try makeCoordinator()
        defer { coordinator.controllers.values.forEach { $0.hide() } }
        let firstID = try XCTUnwrap(coordinator.session.notes.first?.id)
        coordinator.createNote()
        let secondID = try XCTUnwrap(coordinator.session.activeNoteID)
        coordinator.hideNote(firstID)
        // This is the same final-state flush used by applicationShouldTerminate.
        try coordinator.flush()
        let restored = try NoteCoordinator(store: SessionStore(directory: directory))
        restored.start()
        defer { restored.controllers.values.forEach { $0.hide() } }
        XCTAssertEqual(restored.session.notes.map(\.id), [firstID, secondID])
        XCTAssertEqual(restored.session.notes.map(\.isVisible), [false, true])
        XCTAssertTrue(restored.session.recentlyClosed.isEmpty)
    }

    func testRecentlyClosedMenuKeepsOnlyTwelveNotes() throws {
        let (coordinator, directory) = try makeCoordinator()
        defer { coordinator.controllers.values.forEach { $0.hide() } }
        var closedIDs: [UUID] = []
        for index in 0..<15 {
            if index > 0 { coordinator.createNote() }
            let id = try XCTUnwrap(coordinator.session.notes.last?.id)
            closedIDs.append(id)
            coordinator.controllers[id]?.window?.performClose(nil)
        }
        let expected = Array(closedIDs.suffix(12).reversed())
        XCTAssertEqual(coordinator.session.recentlyClosed.map { $0.note.id }, expected)
        XCTAssertTrue(coordinator.controllers.isEmpty)
        let status = StatusItemController(coordinator: coordinator)
        defer { NSStatusBar.system.removeStatusItem(status.statusItem) }
        let menu = try XCTUnwrap(status.statusItem.menu)
        status.menuNeedsUpdate(menu)
        XCTAssertEqual(menu.item(withTitle: "Recently Closed")?.submenu?.items.compactMap { $0.representedObject as? UUID }, expected)
        try coordinator.flush()
        XCTAssertEqual(try SessionFile(directory: directory).load().session.recentlyClosed.map { $0.note.id }, expected)
        coordinator.reopenClosedNote(closedIDs[0])
        XCTAssertTrue(coordinator.session.notes.isEmpty)
    }
}
