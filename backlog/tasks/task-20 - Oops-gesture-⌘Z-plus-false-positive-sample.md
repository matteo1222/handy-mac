---
id: TASK-20
title: 'Oops gesture: ⌘Z plus false-positive sample'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:39'
updated_date: '2026-10-19 17:33'
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
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R8: undo is one gesture away, and every oops becomes training and regression data.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Oops gesture posts ⌘Z
- [x] #2 The preceding landmark window is saved as a false-positive sample (numbers only)
- [x] #3 Accidental-action counter visible in a local log the user can open
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. OopsRecognizer (pure): pointing finger wagged sideways relative to the wrist, >= 3 reversals of >= 0.3 hand scales within 1.2 s, while not engaged; 1 s refractory.
2. Flick confirmation now waits for the tip to settle and cancels on a reversal, so a wag never fires arrows.
3. Bindings.oops -> ⌘Z.
4. App keeps the last ~7 s of frames; on oops writes the window before the wag as an .lmk labelled none (numbers only) to <data>/FalsePositives and appends a JSON line to <data>/accidental-actions.log; menu shows 'Accidental-Action Log (N)…'.
5. HANDY_DATA_DIR override for all app data, used by verify-handy.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Proven in an isolated verify instance: a synthetic 3 s lead-in + wag -> one ⌘Z keystroke, one log line, one 2.6 s none-labelled sample; the user's Application Support was untouched. Bench now counts oops, swipes and zooms as false actions: 0.99/hour on synthetic footage (baseline updated). Samples can be dropped into corpus/ to become regression data.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
A 'no-no' wag of the pointing finger undoes the last action with ⌘Z, saves the landmarks that led to the mistake as a labelled false-positive sample, and logs it in an accidental-action log the menu opens. Arrow-key flicks now wait for the finger to settle so a wag never fires them.
<!-- SECTION:FINAL_SUMMARY:END -->
