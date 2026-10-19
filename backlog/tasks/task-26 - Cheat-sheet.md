---
id: TASK-26
title: Cheat sheet
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:39'
updated_date: '2026-10-19 17:44'
labels:
  - ready-for-agent
milestone: m-2
dependencies:
  - TASK-12
documentation:
  - docs/prd.md
  - docs/spec.md
priority: low
type: feature
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Users need to see every gesture and its binding for the frontmost app without leaving it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A hotkey or palm held 2 s shows all gestures and current bindings for the frontmost app
- [x] #2 Respects Reduce Motion and works with VoiceOver
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. CheatSheetRecognizer (pure): the other (non-pointer) hand's open palm held 2 s shows; lowering it for 0.3 s hides; hard stop hides.
2. Global hotkey ⌃⌥⌘/ and a menu item toggle it; GlobalHotKey now checks its own ID so several hotkeys can coexist.
3. GestureGuide: a table entry per Gesture case with the current binding for the frontmost app (tested over Gesture.allCases).
4. CheatSheetPanel: non-activating, capture-excluded, glass on macOS 26; announced to VoiceOver; rows combine for VoiceOver; no animation.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Replay test proves the other hand's 2 s open palm shows and lowering hides, and never engages. handyctl screenshot cheat-sheet renders all 23 gestures with bindings. Found while adding the second hotkey: each Carbon handler fired on every hotkey press; handlers now compare the pressed hotkey ID. Physical hotkey presses not exercised here (no Accessibility for the shell to synthesise keys).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
⌃⌥⌘/ or holding up the other hand's open palm for two seconds shows every gesture and what it does in the frontmost app, read from the current bindings. It never takes focus, stays out of screen captures, is announced to VoiceOver and does not animate.
<!-- SECTION:FINAL_SUMMARY:END -->
