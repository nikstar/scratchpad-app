import AppKit
import XCTest
@testable import Scratchpad

final class HomePositionTests: XCTestCase {
    func testHomeKeepsRightAndTopInsetsOnPreferredDisplayAfterResizeAndMove() {
        let original = Display(id: 7, visibleFrame: CGRect(x: -1440, y: 40, width: 1440, height: 840))
        let home = NoteHomePosition(frame: CGRect(x: -312, y: 602, width: 280, height: 220), on: original)
        let changed = Display(id: 7, visibleFrame: CGRect(x: 1920, y: -200, width: 1920, height: 1040))
        let other = Display(id: 1, visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 800))
        let placement = home.placement(on: [other, changed], fallback: other)
        XCTAssertEqual(placement.displayID, 7)
        XCTAssertEqual(placement.frame, CGRect(x: 3528, y: 562, width: 280, height: 220))
        XCTAssertEqual(changed.visibleFrame.maxX - placement.frame.maxX, 32)
        XCTAssertEqual(changed.visibleFrame.maxY - placement.frame.maxY, 58)
    }

    func testMissingDisplayUsesFallbackWithoutReplacingHome() {
        let original = Display(id: 7, visibleFrame: CGRect(x: -1440, y: 40, width: 1440, height: 840))
        let frame = CGRect(x: -1400, y: 120, width: 280, height: 220)
        let home = NoteHomePosition(frame: frame, on: original)
        let other = Display(id: 1, visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 800))
        let fallback = Display(id: 2, visibleFrame: CGRect(x: 1200, y: -400, width: 900, height: 650))
        let placement = home.placement(on: [other, fallback], fallback: fallback)
        XCTAssertEqual(placement.displayID, 2)
        XCTAssertEqual(placement.frame, CGRect(x: 1240, y: -320, width: 280, height: 220))
        XCTAssertEqual(home.placement(on: [original, fallback], fallback: fallback).frame, frame)
        XCTAssertEqual(home.displayID, 7)
    }

    func testHomeClampsToSmallerDisplayAndDoesNotCopyOversizedSourceSize() {
        let original = Display(id: 7, visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        let oversized = CGRect(x: -100, y: -100, width: 1510, height: 960)
        let home = NoteHomePosition(frame: oversized, on: original)
        let normal = home.placement(on: [original], fallback: original)
        XCTAssertEqual(normal.frame, CGRect(x: 1130, y: 640, width: 280, height: 220))

        let smaller = Display(id: 7, visibleFrame: CGRect(x: 0, y: 30, width: 300, height: 240))
        XCTAssertEqual(home.placement(on: [smaller], fallback: smaller).frame,
                       CGRect(x: 0, y: 30, width: 280, height: 220))
        let tiny = Display(id: 7, visibleFrame: CGRect(x: 0, y: 30, width: 200, height: 180))
        XCTAssertEqual(home.placement(on: [tiny], fallback: tiny).frame, tiny.visibleFrame)

        let offscreen = NoteHomePosition(frame: CGRect(x: 1200, y: 750, width: 280, height: 220), on: original)
        XCTAssertTrue(offscreen.isValid)
        XCTAssertEqual(offscreen.placement(on: [original], fallback: original).frame,
                       CGRect(x: 1160, y: 680, width: 280, height: 220))
    }

    func testUnconfiguredFirstNoteStillUsesDisplayCenter() {
        let display = Display(id: 1, visibleFrame: CGRect(x: -1440, y: 40, width: 1440, height: 840))
        let placement = WindowPlacement.newNote(relativeTo: nil, on: display)
        XCTAssertEqual(placement.frame.midX, display.visibleFrame.midX)
        XCTAssertEqual(placement.frame.midY, display.visibleFrame.midY)
    }

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

    func testChosenHomeSurvivesMovementClosingRelaunchAndDockCreation() throws {
        let (coordinator, directory) = try makeCoordinator()
        let id = try XCTUnwrap(coordinator.session.activeNoteID)
        let controller = try XCTUnwrap(coordinator.controllers[id])
        let panel = try XCTUnwrap(controller.window)
        let visible = try XCTUnwrap(panel.screen?.visibleFrame)
        let homeFrame = CGRect(x: visible.maxX - 312, y: visible.maxY - 260, width: 280, height: 220)
        panel.setFrame(homeFrame, display: true)
        controller.textView.insertText("Keep this text 🐈", replacementRange: NSRange(location: 0, length: 0))
        coordinator.usePositionForNewNotes(of: id)
        let home = try XCTUnwrap(coordinator.session.newNoteHome)

        let moved = homeFrame.offsetBy(dx: -220, dy: -130)
        panel.setFrame(moved, display: true)
        panel.performClose(nil)
        XCTAssertEqual(coordinator.session.newNoteHome, home)
        try coordinator.flush()

        let restored = try NoteCoordinator(store: SessionStore(directory: directory))
        restored.start()
        defer { restored.controllers.values.forEach { $0.close() } }
        XCTAssertTrue(restored.session.notes.isEmpty)
        XCTAssertTrue(restored.controllers.isEmpty)
        XCTAssertEqual(restored.session.newNoteHome, home)
        restored.reopen()
        let blankID = try XCTUnwrap(restored.session.activeNoteID)
        XCTAssertEqual(restored.controllers[blankID]?.window?.frame, homeFrame)
        XCTAssertEqual(restored.session.notes.first?.isMagnified, false)
        restored.reopenClosedNote(id)
        XCTAssertEqual(restored.controllers[id]?.window?.frame, moved)
        XCTAssertEqual(restored.controllers[id]?.textView.string, "Keep this text 🐈")
        XCTAssertEqual(restored.session.newNoteHome, home)
        try restored.flush()
    }

    func testMenuCapturesSelectedNoteAndHomeOnlyAppliesWithoutVisibleSource() throws {
        let (coordinator, _) = try makeCoordinator()
        let id = try XCTUnwrap(coordinator.session.activeNoteID)
        let source = try XCTUnwrap(coordinator.controllers[id]?.window as? NotePanel)
        let visible = try XCTUnwrap(source.screen?.visibleFrame)
        let sourceFrame = CGRect(x: visible.minX + 40, y: visible.maxY - 270, width: 280, height: 220)
        source.setFrame(sourceFrame, display: true)
        let status = StatusItemController(coordinator: coordinator)
        defer { NSStatusBar.system.removeStatusItem(status.statusItem) }
        let menu = try XCTUnwrap(status.statusItem.menu)
        // Opening the status menu can leave the note without key-window status.
        source.resignKey()
        status.menuNeedsUpdate(menu)
        let homeIndex = try XCTUnwrap(menu.items.firstIndex { $0.title == "Use This Position for New Notes" })
        XCTAssertEqual(menu.items[homeIndex].representedObject as? UUID, id)
        XCTAssertTrue(status.validateMenuItem(menu.items[homeIndex]))
        coordinator.createNote()
        let other = try XCTUnwrap(coordinator.controllers[try XCTUnwrap(coordinator.session.activeNoteID)]?.window)
        other.setFrame(sourceFrame.offsetBy(dx: 180, dy: -100), display: true)
        menu.performActionForItem(at: homeIndex)
        let home = try XCTUnwrap(coordinator.session.newNoteHome)
        XCTAssertEqual(home.placement(on: NSScreen.noteDisplays, fallback: NSScreen.noteDisplays[0]).frame, sourceFrame)

        source.newNoteButton.performClick(nil)
        let fromPlus = try XCTUnwrap(coordinator.controllers[try XCTUnwrap(coordinator.session.activeNoteID)]?.window)
        XCTAssertEqual(fromPlus.frame.minX, sourceFrame.minX + 22)
        XCTAssertEqual(fromPlus.frame.maxY, sourceFrame.maxY - 22)
        coordinator.createNote()
        let fromCommand = try XCTUnwrap(coordinator.controllers[try XCTUnwrap(coordinator.session.activeNoteID)]?.window)
        XCTAssertEqual(fromCommand.frame.minX, fromPlus.frame.minX + 22)
        XCTAssertEqual(fromCommand.frame.maxY, fromPlus.frame.maxY - 22)

        coordinator.hideAllNotes()
        coordinator.createNote()
        let fromHome = try XCTUnwrap(coordinator.controllers[try XCTUnwrap(coordinator.session.activeNoteID)]?.window)
        XCTAssertEqual(fromHome.frame, sourceFrame)
        XCTAssertEqual(coordinator.session.newNoteHome, home)
    }

    func testHomeMenuDisablesWithoutVisibleNoteAndIgnoresStaleActions() throws {
        let (coordinator, _) = try makeCoordinator()
        let status = StatusItemController(coordinator: coordinator)
        defer { NSStatusBar.system.removeStatusItem(status.statusItem) }
        let menu = try XCTUnwrap(status.statusItem.menu)
        status.menuNeedsUpdate(menu)
        let entry = try XCTUnwrap(menu.item(withTitle: "Use This Position for New Notes"))
        let id = try XCTUnwrap(entry.representedObject as? UUID)
        coordinator.usePositionForNewNotes(of: id)
        let home = coordinator.session.newNoteHome
        coordinator.hideAllNotes()
        XCTAssertFalse(status.validateMenuItem(entry))
        coordinator.usePositionForNewNotes(of: id)
        XCTAssertEqual(coordinator.session.newNoteHome, home)
        menu.update()
        XCTAssertFalse(try XCTUnwrap(menu.item(withTitle: entry.title)).isEnabled)
        coordinator.closeNote(id)
        coordinator.usePositionForNewNotes(of: id)
        XCTAssertEqual(coordinator.session.newNoteHome, home)
        menu.update()
        XCTAssertFalse(try XCTUnwrap(menu.item(withTitle: entry.title)).isEnabled)
    }
}
