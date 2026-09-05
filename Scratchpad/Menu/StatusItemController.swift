import AppKit

final class StatusItemController: NSObject, NSMenuDelegate {
    let statusItem: NSStatusItem
    private let coordinator: NoteCoordinator
    private var writeError: Error?
    private var recoveredFromBackup: Bool

    init(coordinator: NoteCoordinator) {
        self.coordinator = coordinator
        recoveredFromBackup = coordinator.recoveredFromBackup
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()
    }

    func setWriteError(_ error: Error?) {
        writeError = error
        updateIcon()
    }

    private func updateIcon() {
        let name = writeError == nil ? "note.text" : "exclamationmark.triangle"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Scratchpad")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = writeError == nil ? "Scratchpad" : "Scratchpad — changes couldn’t be backed up"
        statusItem.button?.setAccessibilityLabel("Scratchpad")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if writeError != nil {
            menu.addItem(item("Changes Couldn’t Be Backed Up…", action: #selector(showWriteError)))
            menu.addItem(.separator())
        }
        if recoveredFromBackup {
            menu.addItem(item("Recovered Notes from Backup…", action: #selector(showRecovery)))
            menu.addItem(.separator())
        }
        let new = item("New Note", action: #selector(newNote), key: "n")
        new.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        menu.addItem(new)
        menu.addItem(item("Show All Notes", action: #selector(showAll)))
        menu.addItem(item("Hide All Notes", action: #selector(hideAll)))
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Notes"))

        if coordinator.session.notes.isEmpty {
            let empty = NSMenuItem(title: "No notes yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for note in coordinator.session.notes {
            let entry = item(note.title, action: #selector(openNote))
            entry.representedObject = note.id
            entry.state = note.isVisible ? .on : .off
            entry.toolTip = note.isVisible ? "Bring this note forward" : "Reopen this hidden note"
            menu.addItem(entry)
        }
        if !coordinator.session.notes.isEmpty {
            menu.addItem(.separator())
            let deleteMenu = NSMenu()
            for note in coordinator.session.notes {
                let entry = item(note.title, action: #selector(deleteNote))
                entry.representedObject = note.id
                deleteMenu.addItem(entry)
            }
            let delete = NSMenuItem(title: "Delete Note", action: nil, keyEquivalent: "")
            delete.submenu = deleteMenu
            menu.addItem(delete)
        }
        menu.addItem(.separator())
        menu.addItem(item("Quit Scratchpad", action: #selector(quit), key: "q"))
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func newNote(_ sender: Any?) { coordinator.createNote() }
    @objc private func showAll(_ sender: Any?) { coordinator.showAllNotes() }
    @objc private func hideAll(_ sender: Any?) { coordinator.hideAllNotes() }
    @objc private func quit(_ sender: Any?) { NSApp.terminate(nil) }

    @objc private func openNote(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        coordinator.showNote(id)
    }

    @objc private func deleteNote(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        coordinator.deleteNote(id)
    }

    @objc private func showWriteError(_ sender: Any?) {
        guard let writeError else { return }
        NSApp.activate()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Your latest changes couldn’t be backed up."
        alert.informativeText = "Keep Scratchpad open until this is resolved. \(writeError.localizedDescription)"
        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "Keep Working")
        if alert.runModal() == .alertFirstButtonReturn { coordinator.persist() }
    }

    @objc private func showRecovery(_ sender: Any?) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Notes were recovered from a backup."
        alert.informativeText = "The latest session couldn’t be read, so Scratchpad restored the previous complete snapshot. Existing data has been kept for recovery. The most recent change may be missing."
        alert.runModal()
        recoveredFromBackup = false
    }
}
