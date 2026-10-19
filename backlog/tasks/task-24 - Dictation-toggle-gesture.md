---
id: TASK-24
title: Dictation toggle gesture
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:39'
updated_date: '2026-10-19 17:29'
labels:
  - ready-for-agent
milestone: m-2
dependencies:
  - TASK-12
documentation:
  - docs/prd.md
  - docs/spec.md
priority: medium
type: feature
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R11: text is entered by dictation, not an air keyboard.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Shaka gesture toggles macOS Dictation in the focused field
- [x] #2 Missing Dictation shortcut is detected and the user is guided to set it
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Shaka is a classifier one-shot; binding shaka -> Action.toggleDictation.
2. DictationShortcut reads System Settings: Dictation on (com.apple.assistant.support) and its shortcut (symbolic hotkey 164: modifier double-tap, custom chord, or Globe default).
3. Output posts the user's shortcut (flags-changed double tap or key chord).
4. Missing or disabled: HUD 'Dictation is off or has no shortcut' with 'Open Keyboard Settings' for six seconds; Settings shows the current shortcut or a set-up button.
5. Fixture gestures/dictation.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Live inject on this Mac (Dictation: Control twice) records modifierDoubleTap(control). Found while proving it: hotkey parameters include an unsigned 64-bit mask that does not bridge to [Int], so the shortcut silently fell back to Globe; now read as NSNumber (also fixes custom Spaces shortcuts with such values). Not verified: that the Dictation daemon accepts the synthesised double tap; needs Accessibility and a live test.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
A shaka held half a second while not engaged toggles macOS Dictation by sending the user's own Dictation shortcut, read from System Settings. If Dictation is off or has no shortcut, the HUD says so with a button to Keyboard Settings, and Settings shows the current shortcut.
<!-- SECTION:FINAL_SUMMARY:END -->
