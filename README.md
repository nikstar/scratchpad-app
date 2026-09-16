# Scratchpad

A small native macOS home for temporary text. Each note is a compact floating panel, with a menu bar icon to create, find, and reopen recently closed notes. Text and workspace state are restored automatically. There are no documents to name, open, or save.

Built with Swift and AppKit only. All windows, menus, and text views are created in code; there are no storyboards, nibs, SwiftUI views, or external dependencies.

The Dock icon is an original layered vector design in `Scratchpad/Scratchpad.icon`, editable with Icon Composer. See [icon artwork and previews](docs/ICON.md).

## Development

Open `Scratchpad.xcodeproj`, select the shared **Scratchpad** scheme, and run. The project retains its original bundle identifier, signing team, and macOS 26.6 deployment target. The current toolchain is Xcode 27.

```sh
xcodebuild -project Scratchpad.xcodeproj -scheme Scratchpad \
  -configuration Debug -derivedDataPath build/DerivedData build

xcodebuild -project Scratchpad.xcodeproj -scheme Scratchpad \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData test
```

Use `CODE_SIGNING_ALLOWED=NO` for an unsigned local compile. For running the sandboxed app and hosted tests, use normal development signing or ad hoc signing with `CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual`.

## Install a release build

From the repository, run [scripts/install.sh](scripts/install.sh):

```sh
./scripts/install.sh
open /Applications/Scratchpad.app
```

The script locates the project relative to itself, builds Release, verifies its ad hoc signature, and installs it at `/Applications/Scratchpad.app`. It requires Xcode and write access to `/Applications`, but no signing certificate. An existing running copy is asked to quit normally so all notes are flushed; a failed or cancelled quit stops installation. The previous app bundle is retained until its replacement succeeds. Note storage is untouched, and the script can be run again for updates. The installer does not launch the app automatically.

If the selected developer tools are only Command Line Tools, the installer automatically uses Xcode or Xcode-beta from `/Applications` for that run. It also respects an explicit `DEVELOPER_DIR` and does not change the system's toolchain selection.

## Current behavior

- First launch opens one blank note. Subsequent launches restore the existing workspace, including an intentionally empty workspace.
- Notes use small, resizable `NSPanel` windows that remain visible when another app is active. They appear across Spaces, including alongside full-screen apps.
- A small **+** in each note's title bar creates another note cascaded from that window. Keyboard/menu creation cascades from the current note. The control dims with an inactive window while remaining clickable.
- A **magnifying glass** beside the plus doubles the note's font size and outer window width/height, keeping its top-right corner fixed. Click again to halve them. Each note remembers its magnification through relaunch and Recently Closed.
- Scratchpad appears in the Dock and app switcher while running. The first Dock click brings the workspace forward. Clicking again while Scratchpad is already active focuses an existing empty note (including a hidden one), or creates a new cascaded note when none is empty.
- The menu bar icon provides New Note, Show All, Hide All, current notes, Recently Closed, and Quit. Checkmarks identify visible current notes. Hide All only changes visibility.
- Closing a window or pressing **⌘W** removes its note immediately, without a confirmation. **Recently Closed** retains the last 12 notes, newest close date first, across relaunches. Reopening restores its text, window placement, selection, and scroll position, and removes it from that submenu.
- Quitting preserves all current notes. Closing and deleting are the same action; there is no separate Delete menu.
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
