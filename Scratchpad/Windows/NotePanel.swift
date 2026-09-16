import AppKit

final class NotePanel: NSPanel {
    let newNoteButton = TitlebarButton()
    let magnifyButton = TitlebarButton()
    var onNewNote: (() -> Void)?
    var onToggleMagnification: (() -> Void)?
    static let normalContentMinSize = NSSize(width: 160, height: 90)
    private var isMagnified = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 200),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isRestorable = false
        becomesKeyOnlyIfNeeded = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        tabbingMode = .disallowed
        contentMinSize = Self.normalContentMinSize
        titlebarAppearsTransparent = true
        backgroundColor = .textBackgroundColor
        standardWindowButton(.zoomButton)?.isHidden = true
        installTitlebarControls()
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(updateControlAppearance(_:)), name: name, object: nil)
        }
        updateControlAppearance()
    }

    override func becomeKey() {
        super.becomeKey()
        updateControlAppearance()
    }

    override func resignKey() {
        super.resignKey()
        updateControlAppearance()
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // AppKit also constrains a window when first showing it. Preserve an
        // intentional anchored enlargement while the trailing controls are on screen.
        let anchor = NSPoint(x: frameRect.maxX - 1, y: frameRect.maxY - 1)
        let anchorIsReachable = screen?.visibleFrame.contains(anchor) == true
            || NSScreen.screens.contains { $0.visibleFrame.contains(anchor) }
        if isMagnified && anchorIsReachable {
            return frameRect
        }
        return super.constrainFrameRect(frameRect, to: screen)
    }

    @objc private func updateControlAppearance(_ notification: Notification? = nil) {
        // NSButton's symbol tint does not reliably preserve a semantic color's
        // alpha in title-bar vibrancy. Dim the view itself to match inactive titles.
        newNoteButton.alphaValue = isKeyWindow && NSApp.isActive ? 1 : 0.45
        magnifyButton.alphaValue = newNoteButton.alphaValue
    }

    func setMagnified(_ magnified: Bool) {
        isMagnified = magnified
        let label = magnified ? "Restore Note Size" : "Enlarge Note"
        magnifyButton.image = NSImage(systemSymbolName: magnified ? "minus.magnifyingglass" : "plus.magnifyingglass",
                                     accessibilityDescription: label)
        magnifyButton.toolTip = label
        magnifyButton.setAccessibilityLabel(label)
        // Scale the outer minimum too, so halving a manually resized note can
        // always return to the normal minimum without shifting its top-right.
        let normalMinimum = frameRect(forContentRect: NSRect(origin: .zero, size: Self.normalContentMinSize)).size
        let scale: CGFloat = magnified ? 2 : 1
        minSize = NSSize(width: normalMinimum.width * scale, height: normalMinimum.height * scale)
    }

    private func installTitlebarControls() {
        let controls = NSTitlebarAccessoryViewController()
        controls.layoutAttribute = .trailing
        // A trailing accessory stays in the utility panel's existing title bar.
        // A bottom accessory or toolbar would add another row of chrome.
        controls.view = NSView(frame: NSRect(x: 0, y: 0, width: 49, height: 16))

        newNoteButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Note")
        newNoteButton.toolTip = "New Note (⌘N)"
        newNoteButton.setAccessibilityLabel("New Note")
        newNoteButton.action = #selector(createNote)
        magnifyButton.action = #selector(toggleMagnification)
        for button in [newNoteButton, magnifyButton] {
            button.symbolConfiguration = .init(pointSize: 10, weight: .medium)
            button.imagePosition = .imageOnly
            button.isBordered = false
            button.setButtonType(.momentaryChange)
            button.controlSize = .mini
            button.contentTintColor = .secondaryLabelColor
            button.refusesFirstResponder = true
            button.target = self
            button.translatesAutoresizingMaskIntoConstraints = false
            controls.view.addSubview(button)
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 18),
                button.heightAnchor.constraint(equalToConstant: 16),
                button.centerYAnchor.constraint(equalTo: controls.view.centerYAnchor)
            ])
        }
        NSLayoutConstraint.activate([
            newNoteButton.trailingAnchor.constraint(equalTo: controls.view.trailingAnchor, constant: -6),
            magnifyButton.trailingAnchor.constraint(equalTo: newNoteButton.leadingAnchor, constant: -4)
        ])
        addTitlebarAccessoryViewController(controls)
        setMagnified(false)
    }

    @objc private func createNote() { onNewNote?() }
    @objc private func toggleMagnification() { onToggleMagnification?() }
}

/// Title-bar controls should act on the first click, including in inactive notes.
final class TitlebarButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
