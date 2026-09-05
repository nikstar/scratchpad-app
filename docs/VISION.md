# Vision

Scratchpad is a lightweight place to put short-lived text while doing something else. It replaces the incidental scratch-buffer workflow of a full editor with a handful of tiny, pleasant windows.

## Principles

1. **Effortless continuity.** Relaunching should feel like returning to the same desk: the same text in the same windows, in the same places.
2. **No document management.** No Save, Save As, Open, filenames, folders, or unsaved-change prompts in the normal workflow. Storage is automatic and private to the app.
3. **Small and native.** AppKit exclusively. Programmatic UI. Compact panels and familiar macOS text editing, without the weight of a full editor.
4. **A quiet presence.** A menu bar icon and small notes. No main document window or Dock presence is needed.
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
- Default to a 280 × 220 point outer window, resizable down to a 160 × 90 point content area.
- Panels float above ordinary windows and are available across Spaces. There is no per-Space assignment in this version.
- First launch creates one blank note. An intentionally empty or entirely hidden workspace stays that way after relaunch.
- Follow the system appearance and use native controls until the visual direction is provided.

## Design questions for later

Panel chrome and close behavior; note colors/materials; typography; menu versus popover management; default size and placement; whether floating should become optional; whether a global new-note shortcut is useful.

## Decision log

- **2026-09-05:** Establish the AppKit foundation, remove the starter storyboard, and make reliable automatic restoration the first engineering priority.
