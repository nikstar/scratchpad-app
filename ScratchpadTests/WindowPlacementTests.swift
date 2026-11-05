import AppKit
import XCTest
@testable import Scratchpad

final class WindowPlacementTests: XCTestCase {
    func testNewNoteCascadesFromResizedSourceOnItsDisplay() {
        let screen = Display(id: 7, visibleFrame: CGRect(x: -1440, y: 40, width: 1440, height: 840))
        let source = CGRect(x: -1200, y: 300, width: 400, height: 360)
        let placement = WindowPlacement.newNote(relativeTo: source, on: screen)
        XCTAssertEqual(placement.frame.minX - source.minX, 22)
        XCTAssertEqual(source.maxY - placement.frame.maxY, 22)
        XCTAssertEqual(placement.displayID, screen.id)
        XCTAssertTrue(screen.visibleFrame.contains(placement.frame))
    }

    func testCascadeOverflowUsesCenterWhenHomeIsUnset() {
        let screen = Display(id: 1, visibleFrame: CGRect(x: 0, y: 40, width: 1440, height: 840))
        for source in [CGRect(x: 1160, y: 300, width: 280, height: 220),
                       CGRect(x: 400, y: 40, width: 280, height: 220),
                       CGRect(x: 1160, y: 40, width: 280, height: 220)] {
            let placement = WindowPlacement.newNote(relativeTo: source, on: screen)
            XCTAssertEqual(placement.frame, CGRect(x: 580, y: 350, width: 280, height: 220))
            XCTAssertEqual(placement.displayID, screen.id)
        }
    }

    func testCascadeOverflowUsesHomeIncludingItsPreferredDisplay() {
        let screen = Display(id: 1, visibleFrame: CGRect(x: -1440, y: 40, width: 1440, height: 840))
        let homeDisplay = Display(id: 2, visibleFrame: CGRect(x: 0, y: 40, width: 1920, height: 1040))
        let homeFrame = CGRect(x: 1600, y: 800, width: 280, height: 220)
        let home = NoteHomePosition(frame: homeFrame, on: homeDisplay)
            .placement(on: [screen, homeDisplay], fallback: screen)
        for source in [CGRect(x: -280, y: 300, width: 280, height: 220),
                       CGRect(x: -900, y: 40, width: 280, height: 220)] {
            XCTAssertEqual(WindowPlacement.newNote(relativeTo: source, on: screen, fallback: home), home)
        }
        XCTAssertEqual(home.frame, homeFrame)
        XCTAssertEqual(home.displayID, homeDisplay.id)
    }

    func testCascadeThatExactlyFitsStillTakesPrecedenceOverHome() {
        let screen = Display(id: 7, visibleFrame: CGRect(x: -1440, y: 40, width: 1440, height: 840))
        let source = CGRect(x: -302, y: 62, width: 200, height: 220)
        let home = WindowPlacement.newNote(relativeTo: nil, on: screen)
        let placement = WindowPlacement.newNote(relativeTo: source, on: screen, fallback: home)
        XCTAssertEqual(placement.frame, CGRect(x: -280, y: 40, width: 280, height: 220))
        XCTAssertNotEqual(placement, home)
        // One point farther right exceeds the display even though the narrow source fits.
        XCTAssertEqual(WindowPlacement.newNote(relativeTo: source.offsetBy(dx: 1, dy: 0),
                                               on: screen, fallback: home), home)
    }

    func testUnchangedDisplayPreservesExactFrame() {
        let screen = Display(id: 1, visibleFrame: CGRect(x: 0, y: 40, width: 1440, height: 840))
        let frame = CGRect(x: 128.5, y: 242.5, width: 301, height: 222)
        let placement = WindowPlacement(frame: frame, displayID: 1, displayVisibleFrame: screen.visibleFrame)
        XCTAssertEqual(placement.restoredFrame(on: [screen]), frame)
    }

    func testMovedDisplayPreservesRelativePosition() {
        let old = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        let new = Display(id: 7, visibleFrame: CGRect(x: 1440, y: 0, width: 1440, height: 900))
        let placement = WindowPlacement(frame: CGRect(x: -1200, y: 200, width: 280, height: 220), displayID: 7, displayVisibleFrame: old)
        XCTAssertEqual(placement.restoredFrame(on: [new]), CGRect(x: 1680, y: 200, width: 280, height: 220))
    }

    func testMissingDisplayMakesNoteReachableWithoutChangingPreferredFrame() {
        let remaining = Display(id: 1, visibleFrame: CGRect(x: 0, y: 40, width: 1440, height: 840))
        let frame = CGRect(x: -1200, y: 1500, width: 280, height: 220)
        let placement = WindowPlacement(frame: frame, displayID: 7)
        XCTAssertTrue(remaining.visibleFrame.contains(placement.restoredFrame(on: [remaining])))
        XCTAssertEqual(placement.frame, frame)
    }

    func testSmallerDisplayFitsOversizedNote() {
        let screen = Display(id: 1, visibleFrame: CGRect(x: 0, y: 40, width: 800, height: 560))
        let placement = WindowPlacement(frame: CGRect(x: 100, y: 100, width: 1600, height: 1000))
        XCTAssertEqual(placement.restoredFrame(on: [screen]), screen.visibleFrame)
    }
}
