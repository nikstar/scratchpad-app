# Verification

Run the shared Scratchpad scheme's tests with Product → Test or the `xcodebuild test` command in the README. Tests use temporary directories and never the user's saved notes. The hosted app skips normal startup while XCTest is loaded.

## Automated coverage

- Unicode text, multiple notes, hidden state, frame coordinates, selection/scroll, and stacking survive disk round trips.
- An empty saved workspace is distinct from first launch.
- Backup recovery preserves the unreadable primary.
- Corrupt files and future schemas are never silently reset.
- Rapid queued writes followed by a flush restore the latest state.
- Missing/moved displays and smaller screens yield reachable panels.
- Editor selections are safely clamped using UTF-16 coordinates.
- AppKit integration checks text editing, panel behavior, hiding/reopening, and recreation from disk.

## Manual regression checklist

1. Launch: one blank compact note, menu bar icon, a Dock icon, and no save/open commands. Check the title-bar plus creates a note and keeps the compact height.
2. Enter multiline Unicode text. Exercise select all, copy/paste, undo/redo, and ⌘N.
3. Create several notes. Move, resize, overlap, select text, and scroll a longer note.
4. Close one note. Verify it remains listed and can be reopened. Hide all and show all.
5. Quit normally and relaunch. Compare exact text, frames, visibility, order, selections, and scrolling.
6. Quit with every note hidden, then relaunch. Verify no unwanted blank window appears.
7. Delete test notes using the management menu. Relaunch an empty workspace; it should remain empty.
8. Force-quit after allowing writes to finish, then relaunch. Confirm persisted state survives.
9. Switch to another app; notes should remain visible. Check another Space and a full-screen app.
10. Check light/dark appearance and resizing down to the minimum size.
11. With a spare display, move a note there, quit, disconnect the display, and relaunch. Verify it is reachable. Reconnect and verify preferred placement where possible.
12. Click the Dock icon from another app, then click again while Scratchpad is active. The first click reveals the workspace. Further clicks focus an existing empty note or create one if none exists; repeated clicks should not accumulate blank notes. Check visible and hidden blanks, and confirm whitespace-only text is preserved.
13. Run `scripts/install.sh` from outside the repository, then repeat with the installed app running. Confirm graceful quit, successful replacement, valid sandbox entitlements, and unchanged saved notes.
14. Move and resize a note away from the screen center. Press its plus while another note is current, then use ⌘N: each new title bar should be offset 22 points down and right from its source. Near screen edges, verify the new note remains reachable on that display.
15. Switch between notes and then to another app. The title-bar plus should dim with the inactive title, remain clickable, and retain its trailing inset at minimum window size.

Tests establish data and local AppKit behavior. Multi-display hardware changes, full-screen Spaces, system shutdown, and power loss still require dedicated manual checks.

## Foundation verification — 2026-09-05

- Debug and Release builds succeeded with Xcode 27 on macOS 27.
- All 17 XCTest cases passed, including native panel recreation and reopening a hidden note through the status menu's action.
- A separate sandboxed smoke build verified multiline Unicode input, ⌘N, undo/redo, and ⌘W. A full process quit and relaunch restored one visible note and one hidden note; the saved session matched exactly.
- Visually inspected the native panel and restored text. The computer-use inspector could not inspect the system menu bar with no open windows, so menu routing with all notes hidden was checked by the AppKit integration test.
- No Swift compiler warnings. Xcode emits its standard skipped App Intents metadata notice because the app has no App Intents dependency.

## Dock, title-bar controls, and installation — 2026-09-05

- All 20 XCTest cases passed after these changes. New cases cover title-bar creation without increasing chrome height, the plus button remaining reachable at minimum size, and Dock reopening with hidden or empty notes.
- Inspected the installed Release build's title bar and clicked the plus to create a note. Confirmed the running app uses the regular, Dock-visible activation policy.
- Ran the release installer from outside the repository and repeated installation with the installed app running. Its normal quit and replacement completed successfully; the sandbox session's SHA-256 hash was unchanged across the final reinstall.
- Verified the installed code signature and the explicit app-sandbox entitlement. Development-only signing entitlements are absent from the installed release.

## Cascading and inactive controls — 2026-09-05

- All 23 XCTest cases passed. Added regression coverage for creating from an inactive source note versus the current note, cascading from resized windows on displays with negative coordinates, and wrapping at screen edges.
- Moved the plus control 3 points farther inward. It follows window focus and app activation with explicit view opacity over the system text color, while retaining first-click behavior.
- Rebuilt and installed the Release app. Visually verified the plus is dim with an inactive title and returns to normal contrast when the note is focused.

## Repeated Dock clicks and system installation — 2026-09-05

- Installer destination is `/Applications/Scratchpad.app`; the previous `~/Applications` destination was a mistaken preference, now corrected.
- Reopen-event tests distinguish the original `frnt` flag from missing or malformed metadata. Integration tests cover first-click reveal, creating exactly one blank note, reusing visible or hidden blanks, and preserving whitespace content.
- All 28 XCTest cases passed. Reusing an older blank note now records its focus immediately, including when AppKit defers key-window delivery.
- Ran the release installer from outside the repository with Command Line Tools selected. It found the installed Xcode without changing the system selection, gracefully quit the running app, and installed to `/Applications`. The installed signature and sandbox entitlement verified successfully.
