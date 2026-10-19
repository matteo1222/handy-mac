---
id: TASK-21
title: Command palette with 8 per-app slots
status: To Do
assignee: []
created_date: '2026-10-19 15:39'
labels:
  - ready-for-agent
milestone: m-2
dependencies:
  - TASK-7
  - TASK-12
documentation:
  - docs/prd.md
  - docs/spec.md
priority: medium
type: feature
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R9: the long tail of shortcuts without memorising 30 poses. Other-hand pinch-hold opens a radial menu; a flick toward a slot fires it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Other-hand pinch-hold opens a radial menu of 8 slots around the cursor
- [ ] #2 Flick toward a slot fires its action; releasing without a flick cancels
- [ ] #3 Slots are configurable per frontmost app
- [ ] #4 Each Action is one typed value projected to gesture binding, menu bar, App Intent and handyctl; a CaseIterable test fails on a missing projection
<!-- AC:END -->
