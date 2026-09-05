import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: NoteCoordinator?
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosted unit tests use isolated stores and must not open the user's notes.
        guard NSClassFromString("XCTestCase") == nil else { return }
        NSWindow.allowsAutomaticWindowTabbing = false
        let store = SessionStore(directory: SessionStore.defaultDirectory)
        while coordinator == nil {
            do {
                let coordinator = try NoteCoordinator(store: store)
                self.coordinator = coordinator
                ApplicationMenu.install(coordinator: coordinator)
                statusController = StatusItemController(coordinator: coordinator)
                store.onWriteResult = { [weak self] error in self?.statusController?.setWriteError(error) }
                coordinator.start()
            } catch {
                NSApp.activate()
                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = "Scratchpad couldn’t restore your notes."
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: "Retry")
                alert.addButton(withTitle: "Quit")
                if alert.runModal() != .alertFirstButtonReturn {
                    NSApp.terminate(nil)
                    return
                }
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        do {
            try coordinator?.flush()
            return .terminateNow
        } catch {
            NSApp.activate()
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Your latest changes couldn’t be backed up."
            alert.informativeText = "Keep Scratchpad open and try again after resolving the problem. \(error.localizedDescription)"
            alert.addButton(withTitle: "Keep Scratchpad Open")
            alert.addButton(withTitle: "Quit Anyway")
            return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        coordinator?.persist()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        coordinator?.reopen(wasAlreadyActive: ReopenRequest.wasAlreadyActive(event))
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
