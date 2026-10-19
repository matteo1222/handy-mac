---
id: TASK-7
title: Left and right click by pinch with preview ring
status: To Do
assignee: []
created_date: '2026-10-19 15:38'
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
- [ ] #1 Thumb–index pinch below 0.25 × hand scale presses; release above 0.40 × hand scale; release within 250 ms and under 8 px is a left click
- [ ] #2 Thumb–middle pinch is a right click
- [ ] #3 Cursor position is frozen from pinch onset
- [ ] #4 Cursor ring tightens as the pinch closes
- [ ] #5 Low-confidence thumb or index tips never produce a click
- [ ] #6 Replay fixtures for click, right click and a near-miss pinch that must not click
<!-- AC:END -->
