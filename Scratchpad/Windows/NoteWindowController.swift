import AppKit

final class NoteWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate {
    let noteID: UUID
    let textView = NSTextView()
    let scrollView = NSScrollView()
    var onTextChange: ((String, EditorState) -> Void)?
    var onEditorChange: ((EditorState) -> Void)?
    var onPlacementChange: ((WindowPlacement) -> Void)?
    var onFocus: (() -> Void)?
    var onHide: (() -> Void)?
    var onNewNote: (() -> Void)?
    private var isApplyingState = true

    init(note: Note, displays: [Display]) {
        noteID = note.id
        let panel = NotePanel()
        super.init(window: panel)
        panel.onNewNote = { [weak self] in self?.onNewNote?() }
        panel.delegate = self
        panel.title = note.title
        panel.identifier = NSUserInterfaceItemIdentifier(note.id.uuidString)

        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 280, height: CGFloat.greatestFiniteMagnitude)
        textView.setAccessibilityLabel("Note text")
        textView.string = note.text
        scrollView.documentView = textView
        panel.contentView = scrollView
        panel.setFrame(note.placement.restoredFrame(on: displays), display: false)
        textView.frame.size.width = scrollView.contentSize.width
        textView.delegate = self
        panel.initialFirstResponder = textView
        panel.makeFirstResponder(textView)

        restoreEditor(note.editor)
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(scrollPositionChanged),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView
        )
        isApplyingState = false
    }

    required init?(coder: NSCoder) { fatalError("Scratchpad creates its UI in code.") }

    var editorState: EditorState {
        let selection = textView.selectedRange()
        return EditorState(
            selectionLocation: selection.location,
            selectionLength: selection.length,
            scrollY: max(0, scrollView.contentView.bounds.origin.y)
        )
    }

    func show(focus: Bool) {
        if focus {
            NSApp.activate()
            window?.makeKeyAndOrderFront(nil)
            window?.makeFirstResponder(textView)
        } else {
            window?.orderFrontRegardless()
        }
    }

    func hide() { window?.orderOut(nil) }

    func applyPlacement(_ placement: WindowPlacement, displays: [Display]) {
        isApplyingState = true
        window?.setFrame(placement.restoredFrame(on: displays), display: true)
        isApplyingState = false
    }

    func restoreEditor(_ state: EditorState) {
        let wasApplying = isApplyingState
        isApplyingState = true
        textView.setSelectedRange(state.selection(in: textView.string))
        if let container = textView.textContainer {
            textView.layoutManager?.ensureLayout(for: container)
        }
        textView.sizeToFit()
        let maxY = max(0, textView.bounds.height - scrollView.contentSize.height)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: min(state.scrollY, maxY)))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        isApplyingState = wasApplying
    }

    func textDidChange(_ notification: Notification) {
        guard !isApplyingState else { return }
        onTextChange?(textView.string, editorState)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !isApplyingState else { return }
        onEditorChange?(editorState)
    }

    @objc private func scrollPositionChanged(_ notification: Notification) {
        guard !isApplyingState else { return }
        onEditorChange?(editorState)
    }

    func windowDidMove(_ notification: Notification) { recordPlacement() }
    func windowDidResize(_ notification: Notification) { recordPlacement() }

    private func recordPlacement() {
        guard !isApplyingState, let window, window.isVisible else { return }
        onPlacementChange?(WindowPlacement(
            frame: window.frame,
            displayID: window.screen?.displayID,
            displayVisibleFrame: window.screen?.visibleFrame
        ))
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard !isApplyingState else { return }
        onFocus?()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onHide?()
        return false
    }
}

extension NSScreen {
    var displayID: UInt32 {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    static var noteDisplays: [Display] {
        screens.map { Display(id: $0.displayID, visibleFrame: $0.visibleFrame) }
    }
}
