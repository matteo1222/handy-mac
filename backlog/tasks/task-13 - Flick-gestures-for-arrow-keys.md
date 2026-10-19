---
id: TASK-13
title: Flick gestures for arrow keys
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 16:58'
labels:
  - ready-for-agent
milestone: m-1
dependencies:
  - TASK-12
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: feature
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Completes R6: an index-finger flick in four directions while not engaged posts the arrow keys.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Index-only flick up/down/left/right posts ↑ ↓ ← → while not Engaged
- [x] #2 A pointing hand while Engaged never fires a flick
- [x] #3 Replay fixtures for each direction and near-miss flicks
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. FlickRecognizer (pure): pointing pose (index only) held 100 ms; index-tip travel >= 0.6 hand scales within 250 ms on a dominant axis (2:1) fires up/down/left/right; 400 ms refractory.
2. Runs only in Watching, alongside one-shots; reset on arming/engaging.
3. Bindings.flicks -> arrow keys through the ActionRouter.
4. Fixtures: four directions; slow pointing, small flick, diagonal flick and flick while engaged must not fire.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixture review found pointing while engaged started a right-button drag: the thumb resting on the curled middle finger read as a thumb-middle pinch. Pinches now only start when the target finger reaches out from the palm (ClickSettings.minFingerReach); release still uses the real distance, so a press cannot get stuck. No click fixture changed. Inject of gestures/flickLeft records one ← keystroke.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
An index-finger flick in any of four directions while not engaged posts the matching arrow key, with dominance, distance, time and refractory checks so slow pointing, small and diagonal moves do not fire. Pointing while engaged never fires a flick, and no longer triggers a false right-click either.
<!-- SECTION:FINAL_SUMMARY:END -->
