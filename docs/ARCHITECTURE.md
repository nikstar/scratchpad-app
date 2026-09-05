# Architecture

## Application lifecycle

`ScratchpadApplication` explicitly constructs `NSApplication` and its delegate. The regular activation policy and `LSUIElement = NO` give the running app a Dock icon and an entry in the app switcher. The menu bar status item remains available. `AppDelegate` owns the note coordinator and status item, installs the responder-chain menus, and flushes storage before termination.

A Dock or Finder reopen brings existing visible notes forward. If every note is hidden, it reopens the most recently active one; if the workspace is empty, it creates a blank note. Normal startup still restores each note's saved visibility.

The title-bar plus is a borderless `NSButton` in a trailing `NSTitlebarAccessoryViewController`, fitting inside the utility panel's original title-bar height. It accepts clicks on inactive notes and routes creation through the coordinator. Private APIs are permitted for this personal app, but this control uses public AppKit APIs.

Plus-button creation carries the source note's identity explicitly, so pressing it on an inactive panel still cascades from that panel. Keyboard/menu creation uses the key note or most recently focused visible note. Placement uses the source window's current top-left corner and display with a 22-point cascade offset, wrapping at display edges. The default note size is unchanged. With no visible source, the first note is centered on the pointer's display. Title-bar controls use the system secondary text color and dim to 45% opacity while their window or the app is inactive, without disabling interaction. View opacity is applied explicitly because symbol tinting in the title bar does not reliably preserve a semantic color's alpha.

`NoteCoordinator` owns the session model and one `NoteWindowController` per note, including hidden notes. It handles creation, visibility, deletion, stacking, and display changes. `NotePanel` controls native window behavior; `NoteWindowController` configures the plain `NSTextView` and translates editing/window notifications into model changes. UI details can be replaced without changing the storage model.

## Restoration contract

The versioned `Session` records:

- Stable note IDs and unmodified Unicode text.
- Outer window frames in AppKit screen coordinates, display IDs, and previous display visible frames.
- Individual visibility, relative back-to-front order, and the most recently focused note.
- UTF-16 selection ranges and vertical scroll offsets.

On an unchanged display arrangement, frames are restored exactly. When a display moves, coordinates are translated relative to its saved visible frame. If a display is missing or smaller, the window is moved/resized onto an available display. Automatic repositioning does not intentionally overwrite the preferred placement; a subsequent user move or resize establishes a new placement.

Panels join all Spaces. This deliberately avoids promising restoration of individual Space assignments, for which macOS does not offer a suitable public API. Native undo history is in memory and is not restored between launches.

Hidden windows are kept alive for cheap reopening and undo continuity during the same run. Closing never removes text. AppKit document restoration is disabled for note panels so it cannot race the app's own restoration.

## Persistence and recovery

`SessionStore` serializes immutable snapshots on a private dispatch queue. Each text change is enqueued immediately. Window movement, resizing, selection, and scrolling use a 150 ms debounce in common run-loop modes. Deactivation enqueues a snapshot; a normal quit drains the queue and synchronously writes the final editor state.

`SessionFile` writes `session.json` by atomic replacement and keeps the previous validated snapshot in `session.backup.json`. Both files live in the app's private Application Support directory. No user-selected file access or network capability is required.

`Scratchpad.entitlements` explicitly preserves the app sandbox for both development and locally installed releases. The installer verifies the signed sandbox entitlement before replacing the app, so signing changes cannot silently switch notes to a different Application Support directory. Release installation disables Xcode's additional development entitlements.

An interrupted write leaves a complete old or new snapshot. Abrupt termination can still lose an in-flight text change or the last 150 ms of geometry/editor changes; zero loss under forced termination or power failure is not guaranteed. Normal termination flushes all pending changes.

If the primary file is unreadable, a valid backup is loaded, the bad primary is preserved under a unique name before replacement, and the menu reports recovery. If both copies are unreadable, startup stops with Retry/Quit and does not manufacture an empty session over existing data. A future schema version is never overwritten or replaced with an older backup.

Write failures are surfaced through the menu bar icon and a retry action. A failed final flush keeps the app open unless the user explicitly chooses Quit Anyway. The storage schema is versioned; future model changes must include a migration or explicitly reject incompatible data.

## Concurrency

AppKit and mutable session state stay on the main actor. Codable value models and the synchronous file layer are explicitly nonisolated and Sendable. Disk operations are confined to one queue, so an older snapshot cannot overwrite a newer completed write.

## Native API references

- [NSPanel floating behavior](https://developer.apple.com/documentation/appkit/nspanel/isfloatingpanel)
- [Windows available across Spaces](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces)
