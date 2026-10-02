import Foundation
import CoreGraphics

nonisolated struct Display: Sendable {
    let id: UInt32
    let visibleFrame: CGRect
}

nonisolated struct WindowPlacement: Codable, Equatable, Sendable {
    static let defaultNoteSize = CGSize(width: 280, height: 220)

    var frame: CGRect
    var displayID: UInt32?
    var displayVisibleFrame: CGRect?

    static func newNote(relativeTo source: CGRect?, on display: Display) -> Self {
        let visible = display.visibleFrame
        let size = defaultNoteSize
        let step: CGFloat = 22
        var frame = CGRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2,
            width: size.width, height: size.height
        )
        if let source {
            // Cascade the title bars, even when the source has been resized.
            frame.origin = CGPoint(x: source.minX + step, y: source.maxY - step - size.height)
            if frame.maxX > visible.maxX { frame.origin.x = visible.minX + step }
            if frame.minY < visible.minY { frame.origin.y = visible.maxY - size.height - step }
        }
        var placement = Self(frame: frame, displayID: display.id, displayVisibleFrame: visible)
        placement.frame = placement.restoredFrame(on: [display])
        return placement
    }

    var isValid: Bool {
        Self.isValid(frame) && (displayVisibleFrame.map(Self.isValid) ?? true)
    }

    private static func isValid(_ rect: CGRect) -> Bool {
        [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height].allSatisfy(\.isFinite)
            && rect.size.width > 0 && rect.size.height > 0
    }

    /// Preserve exact coordinates on an unchanged display. If a display moves or
    /// disappears, keep the note reachable without overwriting its saved placement.
    func restoredFrame(on displays: [Display], allowMagnifiedOverflow: Bool = false) -> CGRect {
        guard let first = displays.first else { return frame }
        let matching = displays.first { $0.id == displayID }
        let target = matching ?? displays.max {
            Self.overlap(frame, $0.visibleFrame) < Self.overlap(frame, $1.visibleFrame)
        } ?? first
        let visible = target.visibleFrame
        // An anchored enlargement can deliberately extend left/below the screen.
        // Restore it exactly on an unchanged display while its controls remain
        // reachable. Changed/missing displays still use the normal recovery below.
        if allowMagnifiedOverflow, matching != nil, displayVisibleFrame == visible,
           visible.contains(CGPoint(x: frame.maxX - 1, y: frame.maxY - 1)) {
            return frame
        }
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

/// An explicitly chosen starting position, independent of any note's lifetime.
/// Insets use the display's usable area so the Dock and menu bar stay clear.
nonisolated struct NoteHomePosition: Codable, Equatable, Sendable {
    enum HorizontalEdge: String, Codable { case left, right }
    enum VerticalEdge: String, Codable { case bottom, top }

    var displayID: UInt32
    var horizontalEdge: HorizontalEdge
    var verticalEdge: VerticalEdge
    var horizontalInset: CGFloat
    var verticalInset: CGFloat

    init(frame: CGRect, on display: Display) {
        displayID = display.id
        let visible = display.visibleFrame
        let left = frame.minX - visible.minX
        let right = visible.maxX - frame.maxX
        let bottom = frame.minY - visible.minY
        let top = visible.maxY - frame.maxY
        // Absolute distances also handle a magnified note extending offscreen.
        horizontalEdge = abs(left) < abs(right) ? .left : .right
        verticalEdge = abs(bottom) < abs(top) ? .bottom : .top
        horizontalInset = max(0, horizontalEdge == .left ? left : right)
        verticalInset = max(0, verticalEdge == .bottom ? bottom : top)
    }

    var isValid: Bool {
        horizontalInset.isFinite && horizontalInset >= 0
            && verticalInset.isFinite && verticalInset >= 0
    }

    func placement(on displays: [Display], fallback: Display) -> WindowPlacement {
        let display = displays.first { $0.id == displayID } ?? fallback
        let visible = display.visibleFrame
        let size = CGSize(width: min(WindowPlacement.defaultNoteSize.width, visible.width),
                          height: min(WindowPlacement.defaultNoteSize.height, visible.height))
        let xInset = min(horizontalInset, visible.width - size.width)
        let yInset = min(verticalInset, visible.height - size.height)
        let frame = CGRect(
            x: horizontalEdge == .left ? visible.minX + xInset : visible.maxX - xInset - size.width,
            y: verticalEdge == .bottom ? visible.minY + yInset : visible.maxY - yInset - size.height,
            width: size.width, height: size.height
        )
        return WindowPlacement(frame: frame, displayID: display.id, displayVisibleFrame: visible)
    }
}
