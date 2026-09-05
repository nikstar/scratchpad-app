import AppKit
import CoreServices

enum ReopenRequest {
    // Dock reopen events carry a 'frnt' boolean indicating whether the app was
    // frontmost when clicked. NSApp.isActive can already be true by the time the
    // delegate callback runs, even for the first click from another application.
    static let wasFrontmostKeyword: AEKeyword = 0x66726E74 // 'frnt'

    static func wasAlreadyActive(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event,
              event.eventClass == kCoreEventClass,
              event.eventID == kAEReopenApplication,
              let frontmost = event.paramDescriptor(forKeyword: wasFrontmostKeyword),
              frontmost.descriptorType == typeBoolean else {
            // Reopen requests without the flag retain ordinary reveal behavior.
            return false
        }
        return frontmost.booleanValue
    }
}
