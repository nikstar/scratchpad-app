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
- AppKit integration checks text editing, panel behavior, hiding/revealing, closing/reopening, and recreation from disk.
- Recently Closed survives disk round trips, sorts by close date, retains only 12 entries, and restores through the menu even when no current windows exist.
- Version 1 sessions and backups migrate without losing hidden notes or restoration state. Quitting preserves current notes without adding history entries.
- Home positions survive closure, an empty workspace, and relaunch. Visible notes still cascade; existing and recently closed notes retain their own placements. Menu actions capture the intended source and reject hidden/closed sources.
- Home placement preserves edge insets on moved/resized displays, uses the pointer's display when the preferred one is missing, and clamps to smaller usable areas without changing the saved preference. Version 3 migration preserves magnification and leaves the home unconfigured; invalid home insets cannot overwrite saved state.

## Manual regression checklist

1. Launch: one blank compact note, menu bar icon, a Dock icon, and no save/open commands. Check the title-bar plus creates a note and keeps the compact height.
2. Enter multiline Unicode text. Exercise select all, copy/paste, undo/redo, and ⌘N.
3. Create several notes. Move, resize, overlap, select text, and scroll a longer note.
4. Close one note with text. Verify it leaves the current list immediately without a confirmation and appears first in Recently Closed. Reopen it and compare text, placement, selection, and scrolling. Verify it leaves Recently Closed. Close it again and check its position in history. Hide All / Show All must not add history entries.
5. Quit normally and relaunch. Compare exact text, frames, visibility, order, selections, and scrolling.
6. Quit with every note hidden, then relaunch. Verify no unwanted blank window appears.
7. Close all test notes. Relaunch an empty workspace; it should remain empty and Recently Closed should remain available. Close more than 12 notes and check that only the latest 12 close dates are retained. Quit with open notes and verify they stay current after relaunch.
8. Force-quit after allowing writes to finish, then relaunch. Confirm persisted state survives.
9. Switch to another app; notes should remain visible. Check another Space and a full-screen app.
10. Check light/dark appearance and resizing down to the minimum size.
11. With a spare display, move a note there, quit, disconnect the display, and relaunch. Verify it is reachable. Reconnect and verify preferred placement where possible.
12. Click the Dock icon from another app, then click again while Scratchpad is active. The first click reveals the workspace. Further clicks focus an existing empty note or create one if none exists; repeated clicks should not accumulate blank notes. Check visible and hidden blanks, and confirm whitespace-only text is preserved.
13. Run `scripts/install.sh` from outside the repository, then repeat with the installed app running. Confirm graceful quit, successful replacement, valid sandbox entitlements, and unchanged saved notes.
14. Move and resize a note away from the screen center. Press its plus while another note is current, then use ⌘N: each new title bar should be offset 22 points down and right from its source. Near screen edges, verify the new note remains reachable on that display.
15. Switch between notes and then to another app. The title-bar plus should dim with the inactive title, remain clickable, and retain its trailing inset at minimum window size.
16. Click the magnifier: font and outer window dimensions should double around the fixed top-right corner. Click again to halve them, including after a manual resize. Check both buttons at minimum size and in inactive notes. Relaunch and reopen from Recently Closed while magnified; verify the same scale, frame, text, selection, and scroll position.
17. Place a note near a screen edge and choose **Use This Position for New Notes** from the menu bar. Move it elsewhere and close it; a new note in the empty workspace should use the chosen position. Repeat after relaunch and after Hide All. With visible notes, verify plus/⌘N still cascade. The command should be disabled when no notes are visible. Change resolution or disconnect/reconnect the chosen display and verify edge placement and the original home are retained.

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

## Close and Recently Closed — 2026-09-05

- All 36 XCTest cases passed. Coverage includes nonempty close without confirmation, released window controllers, exact text/frame/selection/scroll recovery, reopening from the menu with no current windows, re-closing at the top of history, stale close/reopen actions, and persistence of the 12-entry limit.
- History is checked against close timestamps rather than note creation order. Version 1 sessions and backups migrate with every existing note and visibility flag intact; malformed archived state is rejected.
- Installed and signature-verified the Release build at `/Applications/Scratchpad.app`. Launched, quit normally with ⌘Q, and relaunched. The live session migrated to version 2 with all seven current note records, window order, and active note unchanged, and no entries added to Recently Closed.

## Note magnification — 2026-09-16

- All 42 XCTest cases passed. New coverage checks doubled/halved font and outer dimensions, the fixed top-right anchor, inactive-source routing, minimum-size controls, manual resizing, unchanged text/selection and undo, scroll scaling, magnified typing, relaunch, and Recently Closed.
- Screen-edge and oversized-window cases verify exact anchored enlargement and restoration. Version 1/2 migration keeps current and recently closed notes intact at normal scale; version 2 backup recovery is also covered.
- Installed and signature-verified the Release app in `/Applications`. Visually clicked the magnifier in both directions: a 252 × 361 window became 504 × 722 at the same top-right corner, then returned to its exact original frame. All current note texts were unchanged. The app is left running at the original scale.
- No Swift compiler warnings in the final builds; Xcode still emits its standard skipped App Intents metadata notice.

## Layered Dock icon — 2026-09-16

- Authored four original SVG layers in `Scratchpad/Scratchpad.icon` and opened the document successfully in Icon Composer. Checked default, dark, mono/clear, 64-pixel Dock size, and the previous design generation with Apple's `ictool` renderer. Added an explicit dark-appearance ink override so the face remains visible.
- Release build and installation succeeded. The installed app's icon name/file are both `Scratchpad`; its compiled asset catalog contains vector layers, icon groups, and image stacks, and the generated `Scratchpad.icns` was visually checked. Code signature validation passed.
- This change only affects artwork and icon build configuration; no application logic or persistence changes were made. Validation used the release resource compiler and rendered appearances rather than repeating the application unit suite.

## Supplied cat icon and README header — 2026-10-02

- Replaced the icon with Nikita's supplied `.icon` bundle and verified an exact file-for-file match. Rendered its native appearances with `ictool` and visually checked the default, dark, and 64-pixel Dock previews.
- Built and installed Release at `/Applications/Scratchpad.app`. Code signature validation passed; the installed asset catalog matches the release build and includes the new icon image and native icon groups. The installer verified the sandbox entitlement and completed its normal quit step.
- Generated transparent light and dark README headers from the native icon preview, with system fonts. Checked the rendered images, dimensions, and matching icon pixels in both versions.
- No application behavior or persistence changes. Validation used the release build, compiled icon resources, and artwork checks; the application unit suite was not repeated.

## Home position for new notes — 2026-10-03

- All 51 XCTest cases passed. Coverage includes explicit menu selection, ignoring stale or hidden sources, unchanged cascading, closure/relaunch with an empty workspace, Recently Closed placement, preferred-display selection, edge insets after display changes, and fallback without overwriting the home.
- Storage version 4 round trips preserve the home; version 1–3 migrations preserve existing notes and leave it unconfigured. Invalid insets cannot overwrite saved state, and backup recovery retains the preference.
- Built and installed Release in `/Applications/Scratchpad.app`; its code signature verified successfully. The additional computer-use inspection stalled and was interrupted. Nikita confirmed the installed behavior.
- Physical display disconnect/reconnect remains a manual check; automated tests exercise the corresponding display geometries.
