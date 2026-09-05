# Vision

Scratchpad is a lightweight place to put short-lived text while doing something else. It replaces the incidental scratch-buffer workflow of a full editor with a handful of tiny, pleasant windows.

## Principles

1. **Effortless continuity.** Relaunching should feel like returning to the same desk: the same text in the same windows, in the same places.
2. **No document management.** No Save, Save As, Open, filenames, folders, or unsaved-change prompts in the normal workflow. Storage is automatic and private to the app.
3. **Small and native.** AppKit exclusively. Programmatic UI. Compact panels and familiar macOS text editing, without the weight of a full editor.
4. **A quiet presence.** Small notes, a menu bar control, and a Dock icon while the app is running. No main document window is needed.
5. **Cute and minimalist.** A restrained, friendly visual identity with little chrome. Detailed colors, materials, typography, and interactions will be specified later.

## Initial scope

- Multiple independent plain-text notes.
- Compact, movable, resizable floating panels.
- Menu bar management: create, reveal, hide, and delete.
- Automatic restoration of text, window frames, visibility, relative stacking order, active note, caret/selection, and scroll position.
- Resilience to ordinary crashes, interrupted writes, and changed display arrangements.

## Outside the initial scope

Rich text, Markdown rendering, syntax highlighting, document saving/export, sync/accounts, tags/folders, sharing, attachments, and a preferences screen. Add features only when they support the scratchpad use case without making it feel like a notes manager.

## Current provisional decisions

- Closing hides a note; deletion is explicit.
- Start with a native menu as the management UI.
- Show the app in the Dock while running. Clicking it brings the workspace forward or reopens the most recent note when all notes are hidden.
- Keep a small plus button at the trailing edge of each title bar to create another note without adding a toolbar or increasing the panel height.
- Default to a 280 × 220 point outer window, resizable down to a 160 × 90 point content area.
- Panels float above ordinary windows and are available across Spaces. There is no per-Space assignment in this version.
- First launch creates one blank note. An intentionally empty or entirely hidden workspace stays that way after relaunch.
- Follow the system appearance and use native controls until the visual direction is provided.
- Distribution is personal, outside the App Store. Private APIs are permitted where they help achieve the intended behavior; keep those uses isolated and documented.

## Design questions for later

Panel chrome and close behavior; note colors/materials; typography; menu versus popover management; default size and placement; whether floating should become optional; whether a global new-note shortcut is useful.

## Decision log

- **2026-09-05:** Establish the AppKit foundation, remove the starter storyboard, and make reliable automatic restoration the first engineering priority.
- **2026-09-05:** Keep the compact panel direction; add Dock presence, a trailing title-bar plus button, and a repeatable release installer for `~/Applications`. Private APIs are explicitly permitted if needed.
