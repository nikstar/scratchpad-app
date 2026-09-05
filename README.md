# Scratchpad

A small native macOS home for temporary text. Each note is a compact floating panel, with a menu bar icon to create, find, hide, and delete notes. Text and workspace state are restored automatically. There are no documents to name, open, or save.

Built with Swift and AppKit only. All windows, menus, and text views are created in code; there are no storyboards, nibs, SwiftUI views, or external dependencies.

## Development

Open `Scratchpad.xcodeproj`, select the shared **Scratchpad** scheme, and run. The project retains its original bundle identifier, signing team, and macOS 26.6 deployment target. The current toolchain is Xcode 27.

```sh
xcodebuild -project Scratchpad.xcodeproj -scheme Scratchpad \
  -configuration Debug -derivedDataPath build/DerivedData build

xcodebuild -project Scratchpad.xcodeproj -scheme Scratchpad \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData test
```

Use `CODE_SIGNING_ALLOWED=NO` for an unsigned local compile. For running the sandboxed app and hosted tests, use normal development signing or ad hoc signing with `CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual`.

## Current behavior

- First launch opens one blank note. Subsequent launches restore the existing workspace, including an intentionally empty workspace.
- Notes use small, resizable `NSPanel` windows that remain visible when another app is active. They appear across Spaces, including alongside full-screen apps.
- The menu bar icon provides New Note, Show All, Hide All, individual note reopening, deletion, and Quit. Checkmarks identify visible notes.
- Closing a window or pressing **⌘W** hides its note. Deletion is a separate action; deleting nonempty text requires confirmation.
- **⌘N**, **⌘Q**, and standard text editing shortcuts work while Scratchpad is active. They are not global shortcuts.
- Text is plain text, with native selection, undo/redo, and copy/paste. Automatic text substitutions are off.
- Light and dark appearances follow macOS. The initial UI is a functional foundation; visual design is still open.

## Persistence

The sandbox stores private data under its Application Support directory, normally:

```text
~/Library/Containers/me.nikstar.Scratchpad/Data/Library/Application Support/Scratchpad/
```

An unsandboxed development build uses `~/Library/Application Support/Scratchpad/` instead. These paths are implementation details, never part of the note workflow.

See [the app vision](docs/VISION.md), [architecture and restoration contract](docs/ARCHITECTURE.md), and [verification checklist](docs/TESTING.md).
