---
id: TASK-9
title: Scroll with momentum
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
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Scrolling is the most common hands-busy action. Apps should see trackpad-like scrolling, and the cursor must not wander while scrolling.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Index + middle extended with ring + little curled for 150 ms enters Scrolling; pose lost 150 ms exits
- [ ] #2 Cursor parks while scrolling; scroll velocity = palm velocity × gain
- [ ] #3 Pixel-unit scroll-wheel events with momentum phases; momentum decays 0.92 per frame after release
- [ ] #4 HUD shows Scrolling
- [ ] #5 Replay fixtures for vertical scroll, horizontal scroll and momentum
<!-- AC:END -->
