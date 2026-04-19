# Design: Connection Log Copy Button

## Summary

Add a "Copy" button to the `ConnectionDebugPanel` in `SetupView` so users can copy connection logs to the clipboard and send them for support.

## Context

Users report connection issues but can't get past the setup screen. The `ConnectionDebugPanel` already shows real-time connection logs — it just lacks a way to extract them.

## Design

### Where
Bottom of the expanded `ConnectionDebugPanel` log list, only visible when the panel is expanded and at least one log entry exists.

### Behavior
- Tapping copies the following plain text to `UIPasteboard.general.string`:
  ```
  RomM iOS v{CFBundleShortVersionString}

  HH:mm:ss [info] Checking server URL...
  HH:mm:ss [error] Connection refused
  ...
  ```
- After copy: a `"Kopiert ✓"` label appears inline (replaces button text), disappears after 2 seconds via `DispatchQueue.main.asyncAfter`.
- No alert, no share sheet.

### When visible
`ConnectionDebugPanel` is already shown when `!connectionLogger.logs.isEmpty || connectionLogger.isConnecting`. The copy button appears inside the expanded panel only.

## Changes Required

- `SetupView.swift` — `ConnectionDebugPanel` struct:
  - Add `@State private var copied = false` 
  - Add copy button at bottom of log scroll view (inside expanded branch)
  - Format log text: app version header + each `ConnectionLogEntry` as `"HH:mm:ss [type] message\n  details"`
  - Read app version from `Bundle.main.infoDictionary["CFBundleShortVersionString"]`

## Out of Scope
- Share sheet
- Device info / server URL in copied text
- Persistent log storage across sessions
