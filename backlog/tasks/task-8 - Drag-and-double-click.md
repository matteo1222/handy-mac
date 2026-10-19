---
id: TASK-8
title: Drag and double click
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 16:41'
labels:
  - ready-for-agent
milestone: m-1
dependencies:
  - TASK-7
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: feature
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Completes the pointer basics in R2: holding a pinch drags; two quick pinches double-click with the same interval macOS uses.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Pinch held over 250 ms or moved over 8 px enters Dragging; release drops
- [x] #2 A second press within 350 ms and under 12 px posts a double click (click-count field set)
- [x] #3 HUD shows Dragging
- [x] #4 Replay fixtures for drag, double click and two slow clicks that must stay single clicks
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Pinch held over 250 ms or raw palm travel over 8 pt enters dragging: dragBegan, dragMoved (carrying held motion), dragEnded; Mode.dragging for HUD.
2. A second press within 350 ms and 12 pt of the last click counts up (click count set on both down and up); cursor held still between taps unless the hand clearly moves.
3. Disengaging mid-drag ends the drag.
4. Fixtures: drag, doubleClick, twoSlowClicksStaySingle, holdWithoutMovingStartsDrag.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Inject of gestures/doubleClick records mouseDown/Up clickCount 1 then 2; gestures/drag records mouseDown, 19 mouseDragged, mouseUp. HUD gallery shows Dragging.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Pinch-and-hold or pinch-and-move drags (mouse down, dragged events, up on release) and two quick pinches double-click with the click-count field set, matching macOS's 350 ms interval. HUD shows Dragging. Fixtures prove drag, double click, hold-to-drag and that two slow clicks stay single.
<!-- SECTION:FINAL_SUMMARY:END -->
