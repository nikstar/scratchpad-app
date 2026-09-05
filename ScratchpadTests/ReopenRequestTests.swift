import AppKit
import CoreServices
import XCTest
@testable import Scratchpad

final class ReopenRequestTests: XCTestCase {
    private func event(frontmost: Bool?) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass),
                                          eventID: AEEventID(kAEReopenApplication),
                                          targetDescriptor: nil,
                                          returnID: AEReturnID(kAutoGenerateReturnID),
                                          transactionID: AETransactionID(kAnyTransactionID))
        if let frontmost {
            event.setParam(NSAppleEventDescriptor(boolean: frontmost), forKeyword: ReopenRequest.wasFrontmostKeyword)
        }
        return event
    }

    func testReopenReadsFocusAtClickTime() {
        XCTAssertTrue(ReopenRequest.wasAlreadyActive(event(frontmost: true)))
        XCTAssertFalse(ReopenRequest.wasAlreadyActive(event(frontmost: false)))
    }

    func testMissingAndMalformedFlagsRetainRevealBehavior() {
        XCTAssertFalse(ReopenRequest.wasAlreadyActive(nil))
        XCTAssertFalse(ReopenRequest.wasAlreadyActive(event(frontmost: nil)))
        let malformed = event(frontmost: nil)
        malformed.setParam(NSAppleEventDescriptor(string: "true"), forKeyword: ReopenRequest.wasFrontmostKeyword)
        XCTAssertFalse(ReopenRequest.wasAlreadyActive(malformed))
    }
}
