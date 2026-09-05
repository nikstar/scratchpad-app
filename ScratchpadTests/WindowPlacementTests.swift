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

    func testCascadeWrapsAtDisplayEdgesAndStaysReachable() {
        let screen = Display(id: 1, visibleFrame: CGRect(x: 0, y: 40, width: 1440, height: 840))
        let source = CGRect(x: 1160, y: 40, width: 280, height: 220)
        let placement = WindowPlacement.newNote(relativeTo: source, on: screen)
        XCTAssertTrue(screen.visibleFrame.contains(placement.frame))
        XCTAssertNotEqual(placement.frame, source)
        XCTAssertEqual(placement.frame.minX, screen.visibleFrame.minX + 22)
        XCTAssertEqual(placement.frame.maxY, screen.visibleFrame.maxY - 22)
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
