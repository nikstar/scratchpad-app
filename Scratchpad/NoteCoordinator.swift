import AppKit

final class NoteCoordinator: NSObject {
    private(set) var session: Session
    private(set) var controllers: [UUID: NoteWindowController] = [:]
    private let store: SessionStore
    private let isFirstLaunch: Bool
    let recoveredFromBackup: Bool
    private var isRestoring = false
    private var stateSaveTimer: Timer?
    var onChange: (() -> Void)?

    init(store: SessionStore) throws {
        self.store = store
        let result = try store.load()
        session = result.session
        isFirstLaunch = result.isFirstLaunch
        recoveredFromBackup = result.recoveredFromBackup
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    func start() {
        if isFirstLaunch {
            createNote()
            return
        }
        isRestoring = true
        for note in session.notes { makeController(for: note) }
        let order = session.windowOrder + session.notes.map(\.id).filter { !session.windowOrder.contains($0) }
        for id in order where note(id)?.isVisible == true { controllers[id]?.show(focus: false) }
        if let active = session.activeNoteID, note(active)?.isVisible == true {
            controllers[active]?.show(focus: true)
        }
        for note in session.notes { controllers[note.id]?.restoreEditor(note.editor) }
        isRestoring = false
        if recoveredFromBackup { persist() }
    }

    @objc func createNote(_ sender: Any? = nil) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1200, height: 800)
        let offset = CGFloat(session.notes.filter(\.isVisible).count % 8) * 22
        let placement = WindowPlacement(
            frame: CGRect(x: visible.midX - 140 + offset, y: visible.midY - 110 - offset, width: 280, height: 220),
            displayID: screen?.displayID,
            displayVisibleFrame: visible
        )
        let note = Note(placement: placement)
        session.notes.append(note)
        session.windowOrder.append(note.id)
        session.activeNoteID = note.id
        makeController(for: note)
        controllers[note.id]?.show(focus: true)
        persist()
    }

    func showNote(_ id: UUID) {
        guard let index = index(id) else { return }
        session.notes[index].isVisible = true
        controllers[id]?.show(focus: true)
        persist()
    }

    /// Dock/Finder reopening reveals the current workspace without reopening
    /// every deliberately hidden note or making a new note on every click.
    func reopen() {
        if session.notes.isEmpty {
            createNote()
            return
        }
        let visible = session.windowOrder.filter { note($0)?.isVisible == true }
        for id in visible { controllers[id]?.show(focus: false) }
        let active = session.activeNoteID
        if let id = active.flatMap({ visible.contains($0) ? $0 : nil }) ?? visible.last
            ?? active ?? session.notes.last?.id {
            showNote(id)
        }
    }

    func hideNote(_ id: UUID) {
        guard let index = index(id) else { return }
        if let controller = controllers[id] { session.notes[index].editor = controller.editorState }
        session.notes[index].isVisible = false
        controllers[id]?.hide()
        persist()
    }

    @objc func showAllNotes(_ sender: Any? = nil) {
        for index in session.notes.indices { session.notes[index].isVisible = true }
        for id in session.windowOrder { controllers[id]?.show(focus: false) }
        if let id = session.activeNoteID ?? session.notes.last?.id { controllers[id]?.show(focus: true) }
        persist()
    }

    @objc func hideAllNotes(_ sender: Any? = nil) {
        for index in session.notes.indices {
            let id = session.notes[index].id
            if let controller = controllers[id] { session.notes[index].editor = controller.editorState }
            session.notes[index].isVisible = false
            controllers[id]?.hide()
        }
        persist()
    }

    func deleteNote(_ id: UUID) {
        guard let note = note(id) else { return }
        if !note.text.isEmpty {
            NSApp.activate()
            let alert = NSAlert()
            alert.messageText = "Delete this note?"
            alert.informativeText = "“\(note.title)” will be permanently deleted. Close the window to keep it for later instead."
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Delete Note")
            alert.buttons.last?.hasDestructiveAction = true
            guard alert.runModal() == .alertSecondButtonReturn else { return }
        }
        controllers.removeValue(forKey: id)?.hide()
        session.notes.removeAll { $0.id == id }
        session.windowOrder.removeAll { $0 == id }
        if session.activeNoteID == id { session.activeNoteID = session.windowOrder.last }
        persist()
    }

    func flush() throws {
        stateSaveTimer?.invalidate()
        for index in session.notes.indices {
            guard let controller = controllers[session.notes[index].id] else { continue }
            session.notes[index].text = controller.textView.string
            session.notes[index].editor = controller.editorState
        }
        try store.flush(session)
    }

    func persist() {
        guard !isRestoring else { return }
        stateSaveTimer?.invalidate()
        store.save(session)
        onChange?()
    }

    private func scheduleStateSave() {
        guard !isRestoring else { return }
        stateSaveTimer?.invalidate()
        // Only geometry/selection/scroll notifications are coalesced. Text is
        // always enqueued immediately, including during live window resizing.
        let timer = Timer(timeInterval: 0.15, target: self, selector: #selector(saveState), userInfo: nil, repeats: false)
        stateSaveTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func saveState() { persist() }

    @objc private func displaysChanged() {
        isRestoring = true
        for note in session.notes {
            controllers[note.id]?.applyPlacement(note.placement, displays: NSScreen.noteDisplays)
        }
        isRestoring = false
    }

    @discardableResult
    private func makeController(for note: Note) -> NoteWindowController {
        let controller = NoteWindowController(note: note, displays: NSScreen.noteDisplays)
        let id = note.id
        controller.onTextChange = { [weak self] text, editor in
            guard let self, !self.isRestoring, let index = self.index(id) else { return }
            self.session.notes[index].text = text
            self.session.notes[index].editor = editor
            self.controllers[id]?.window?.title = self.session.notes[index].title
            self.persist()
        }
        controller.onEditorChange = { [weak self] editor in
            guard let self, !self.isRestoring, let index = self.index(id) else { return }
            self.session.notes[index].editor = editor
            self.scheduleStateSave()
        }
        controller.onPlacementChange = { [weak self] placement in
            guard let self, !self.isRestoring, let index = self.index(id) else { return }
            self.session.notes[index].placement = placement
            self.scheduleStateSave()
        }
        controller.onFocus = { [weak self] in
            guard let self, !self.isRestoring else { return }
            self.session.activeNoteID = id
            self.session.windowOrder.removeAll { $0 == id }
            self.session.windowOrder.append(id)
            self.scheduleStateSave()
        }
        controller.onHide = { [weak self] in self?.hideNote(id) }
        controller.onNewNote = { [weak self] in self?.createNote() }
        controllers[id] = controller
        return controller
    }

    private func index(_ id: UUID) -> Int? { session.notes.firstIndex { $0.id == id } }
    private func note(_ id: UUID) -> Note? { session.notes.first { $0.id == id } }
}
