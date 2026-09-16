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
        let current = controllers.values.first { $0.window?.isKeyWindow == true }?.window
            ?? session.activeNoteID.flatMap { controllers[$0]?.window }.flatMap { $0.isVisible ? $0 : nil }
            ?? session.windowOrder.reversed().compactMap { controllers[$0]?.window }.first { $0.isVisible }
        createNote(relativeTo: current)
    }

    private func createNote(relativeTo source: NSWindow?) {
        let screen = source?.screen
            ?? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let display = Display(
            id: screen?.displayID ?? 0,
            visibleFrame: screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1200, height: 800)
        )
        let placement = WindowPlacement.newNote(relativeTo: source?.frame, on: display)
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
        // Record explicit focus requests even if AppKit defers key-window delivery.
        session.activeNoteID = id
        session.windowOrder.removeAll { $0 == id }
        session.windowOrder.append(id)
        controllers[id]?.show(focus: true)
        persist()
    }

    /// Repeated Dock clicks provide a blank note without multiplying empty notes.
    /// A first click from another app retains the normal workspace reveal behavior.
    func reopen(wasAlreadyActive: Bool = false) {
        if wasAlreadyActive {
            let empty = session.notes.first { $0.id == session.activeNoteID && $0.isVisible && $0.text.isEmpty }
                ?? session.notes.last { $0.isVisible && $0.text.isEmpty }
                ?? session.notes.last { $0.text.isEmpty }
            if let empty {
                showNote(empty.id)
            } else {
                createNote()
            }
            return
        }
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

    func closeNote(_ id: UUID) {
        guard var note = note(id) else { return }
        let controller = controllers.removeValue(forKey: id)
        if let controller {
            note.text = controller.textView.string
            note.editor = controller.editorState
        }
        session.rememberClosed(note)
        session.notes.removeAll { $0.id == id }
        session.windowOrder.removeAll { $0 == id }
        if session.activeNoteID == id { session.activeNoteID = session.windowOrder.last }
        controller?.close()
        persist()
    }

    func reopenClosedNote(_ id: UUID) {
        guard let index = session.recentlyClosed.firstIndex(where: { $0.note.id == id }) else { return }
        var note = session.recentlyClosed.remove(at: index).note
        note.isVisible = true
        session.notes.append(note)
        isRestoring = true
        makeController(for: note)
        showNote(id)
        controllers[id]?.restoreEditor(note.editor)
        isRestoring = false
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
        controller.onMagnificationChange = { [weak self] magnified, placement, editor in
            guard let self, !self.isRestoring, let index = self.index(id) else { return }
            self.session.notes[index].isMagnified = magnified
            self.session.notes[index].placement = placement
            self.session.notes[index].editor = editor
            self.persist()
        }
        controller.onFocus = { [weak self] in
            guard let self, !self.isRestoring, self.index(id) != nil else { return }
            self.session.activeNoteID = id
            self.session.windowOrder.removeAll { $0 == id }
            self.session.windowOrder.append(id)
            self.scheduleStateSave()
        }
        controller.onClose = { [weak self] in self?.closeNote(id) }
        controller.onNewNote = { [weak self] in
            guard let self else { return }
            self.createNote(relativeTo: self.controllers[id]?.window)
        }
        controllers[id] = controller
        return controller
    }

    private func index(_ id: UUID) -> Int? { session.notes.firstIndex { $0.id == id } }
    private func note(_ id: UUID) -> Note? { session.notes.first { $0.id == id } }
}
