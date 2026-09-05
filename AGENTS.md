# Working on Scratchpad

Read `docs/VISION.md` before changing product behavior and `docs/ARCHITECTURE.md` before changing persistence or window lifecycle.

- Use AppKit exclusively. Create UI in Swift code; do not introduce SwiftUI, storyboards, or nibs.
- Keep the app small, native, and focused on temporary plain text. Detailed visual design is still to come.
- Notes are app-owned state, not documents. Do not add Save/Open workflows or file pickers.
- Preserve all note text and restoration state. Closing hides; deletion is a separate explicit operation.
- Keep AppKit and mutable state on the main actor; serialize disk writes through `SessionStore`.
- Never silently reset unreadable or newer-version storage. Change the schema only with an explicit migration/versioning plan.
- Use the existing Xcode project and shared Scratchpad scheme. Keep tests isolated from the user's Application Support directory.
- Update the vision and architecture docs when an accepted decision changes. Run the relevant restoration tests for persistence or window lifecycle changes.
