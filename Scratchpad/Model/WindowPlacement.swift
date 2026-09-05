import Foundation
import CoreGraphics

nonisolated struct Display: Sendable {
    let id: UInt32
    let visibleFrame: CGRect
}

nonisolated struct WindowPlacement: Codable, Equatable, Sendable {
    var frame: CGRect
    var displayID: UInt32?
    var displayVisibleFrame: CGRect?

    var isValid: Bool {
        Self.isValid(frame) && (displayVisibleFrame.map(Self.isValid) ?? true)
    }

    private static func isValid(_ rect: CGRect) -> Bool {
        [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height].allSatisfy(\.isFinite)
            && rect.size.width > 0 && rect.size.height > 0
    }

    /// Preserve exact coordinates on an unchanged display. If a display moves or
    /// disappears, keep the note reachable without overwriting its saved placement.
    func restoredFrame(on displays: [Display]) -> CGRect {
        guard let first = displays.first else { return frame }
        let matching = displays.first { $0.id == displayID }
        let target = matching ?? displays.max {
            Self.overlap(frame, $0.visibleFrame) < Self.overlap(frame, $1.visibleFrame)
        } ?? first
        let visible = target.visibleFrame
        var result = frame
        if matching != nil, let previous = displayVisibleFrame {
            result.origin.x += visible.minX - previous.minX
            result.origin.y += visible.minY - previous.minY
        }
        result.size.width = min(result.width, visible.width)
        result.size.height = min(result.height, visible.height)
        result.origin.x = min(max(result.minX, visible.minX), visible.maxX - result.width)
        result.origin.y = min(max(result.minY, visible.minY), visible.maxY - result.height)
        return result
    }

    private static func overlap(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
