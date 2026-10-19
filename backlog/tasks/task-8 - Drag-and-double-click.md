---
id: TASK-8
title: Drag and double click
status: To Do
assignee: []
created_date: '2026-10-19 15:38'
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
- [ ] #1 Pinch held over 250 ms or moved over 8 px enters Dragging; release drops
- [ ] #2 A second press within 350 ms and under 12 px posts a double click (click-count field set)
- [ ] #3 HUD shows Dragging
- [ ] #4 Replay fixtures for drag, double click and two slow clicks that must stay single clicks
<!-- AC:END -->
