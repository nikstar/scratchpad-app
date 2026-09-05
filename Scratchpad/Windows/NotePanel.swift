import AppKit

final class NotePanel: NSPanel {
    let newNoteButton = TitlebarButton()
    var onNewNote: (() -> Void)?

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
        contentMinSize = NSSize(width: 160, height: 90)
        titlebarAppearsTransparent = true
        backgroundColor = .textBackgroundColor
        standardWindowButton(.zoomButton)?.isHidden = true
        installTitlebarControls()
    }

    private func installTitlebarControls() {
        let controls = NSTitlebarAccessoryViewController()
        controls.layoutAttribute = .trailing
        // A trailing accessory stays in the utility panel's existing title bar.
        // A bottom accessory or toolbar would add another row of chrome.
        controls.view = NSView(frame: NSRect(x: 0, y: 0, width: 24, height: 16))

        newNoteButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Note")
        newNoteButton.symbolConfiguration = .init(pointSize: 10, weight: .medium)
        newNoteButton.imagePosition = .imageOnly
        newNoteButton.isBordered = false
        newNoteButton.setButtonType(.momentaryChange)
        newNoteButton.controlSize = .mini
        newNoteButton.contentTintColor = .secondaryLabelColor
        newNoteButton.refusesFirstResponder = true
        newNoteButton.toolTip = "New Note (⌘N)"
        newNoteButton.setAccessibilityLabel("New Note")
        newNoteButton.target = self
        newNoteButton.action = #selector(createNote)
        newNoteButton.translatesAutoresizingMaskIntoConstraints = false
        controls.view.addSubview(newNoteButton)
        NSLayoutConstraint.activate([
            newNoteButton.widthAnchor.constraint(equalToConstant: 18),
            newNoteButton.heightAnchor.constraint(equalToConstant: 16),
            newNoteButton.trailingAnchor.constraint(equalTo: controls.view.trailingAnchor, constant: -3),
            newNoteButton.centerYAnchor.constraint(equalTo: controls.view.centerYAnchor)
        ])
        addTitlebarAccessoryViewController(controls)
    }

    @objc private func createNote() { onNewNote?() }
}

/// Title-bar controls should act on the first click, including in inactive notes.
final class TitlebarButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
