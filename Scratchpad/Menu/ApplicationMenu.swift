import AppKit

enum ApplicationMenu {
    static func install(coordinator: NoteCoordinator) {
        let main = NSMenu()
        let app = NSMenu(title: "Scratchpad")
        app.addItem(withTitle: "About Scratchpad", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Scratchpad", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(.separator())
        app.addItem(withTitle: "Quit Scratchpad", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        add(app, to: main)

        let notes = NSMenu(title: "Notes")
        let new = notes.addItem(withTitle: "New Note", action: #selector(NoteCoordinator.createNote(_:)), keyEquivalent: "n")
        new.target = coordinator
        notes.addItem(withTitle: "Close Note", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        notes.addItem(.separator())
        let show = notes.addItem(withTitle: "Show All Notes", action: #selector(NoteCoordinator.showAllNotes(_:)), keyEquivalent: "")
        show.target = coordinator
        let hide = notes.addItem(withTitle: "Hide All Notes", action: #selector(NoteCoordinator.hideAllNotes(_:)), keyEquivalent: "")
        hide.target = coordinator
        add(notes, to: main)

        // A programmatic menu restores the standard responder-chain shortcuts
        // that were previously supplied by Main.storyboard.
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        add(edit, to: main)
        NSApp.mainMenu = main
    }

    private static func add(_ menu: NSMenu, to parent: NSMenu) {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        parent.addItem(item)
    }
}
