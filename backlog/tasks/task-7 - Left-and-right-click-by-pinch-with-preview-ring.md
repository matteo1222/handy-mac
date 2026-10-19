---
id: TASK-7
title: Left and right click by pinch with preview ring
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 16:41'
labels:
  - ready-for-agent
milestone: m-1
dependencies:
  - TASK-6
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: feature
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Clicks are the action most likely to misfire, so each one is previewed (the cursor ring tightens as fingers approach) and lands where the user aimed (cursor frozen at pinch onset). Uses the click gesture chosen in the spike; the hysteresis band prevents flicker.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Thumb–index pinch below 0.25 × hand scale presses; release above 0.40 × hand scale; release within 250 ms and under 8 px is a left click
- [x] #2 Thumb–middle pinch is a right click
- [x] #3 Cursor position is frozen from pinch onset
- [x] #4 Cursor ring tightens as the pinch closes
- [x] #5 Low-confidence thumb or index tips never produce a click
- [x] #6 Replay fixtures for click, right click and a near-miss pinch that must not click
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. ClickRecognizer (pure): idle/pressing/dragging phases, press < 0.25, release > 0.40, click if released within 250 ms and under 8 pt of raw palm travel; middle pinch = right click; missing tip readings never press or release.
2. Cursor frozen from press: filtered motion held back, released only into a drag.
3. Status.pinch closeness drives a click-through, capture-excluded cursor ring that tightens and fills on press.
4. OutputAction mouseDown/mouseUp with click count; driver posts them.
5. Fixtures: click, rightClick, nearMissPinch, lowConfidenceTips (synth --dim-joints), clickLandsWhereAimed.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixture review: a hand that decelerates hard before pinching turned a click into a drag because the cursor filter's catch-up was counted as motion. Click-vs-drag now uses raw palm travel since press (at precision gain); filtered deltas still move the cursor during a real drag. Click gesture default is thumb-index pinch pending the TASK-4 A/B. A stale incremental build once segfaulted HandyControlTests after ControlResponse changed layout; a clean build passes (CI builds clean).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Thumb-index and thumb-middle pinch taps now post left and right clicks with a hysteresis band, a frozen cursor from press, and a tightening cursor ring as preview. Low-confidence fingertips cannot press. Replay fixtures and unit tests cover click, right click, near miss, dim tips and aim drift.
<!-- SECTION:FINAL_SUMMARY:END -->
