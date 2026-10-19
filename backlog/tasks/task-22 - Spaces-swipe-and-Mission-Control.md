---
id: TASK-22
title: Spaces swipe and Mission Control
status: To Do
assignee: []
created_date: '2026-10-19 15:39'
labels:
  - ready-for-agent
milestone: m-2
dependencies:
  - TASK-5
documentation:
  - docs/prd.md
  - docs/spec.md
priority: medium
type: feature
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R10: swipe between Spaces and open Mission Control like a 3-finger trackpad swipe.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Open-palm swipe over 25% of frame width in under 400 ms → previous/next Space; swipe up → Mission Control
- [ ] #2 600 ms refractory after firing
- [ ] #3 Uses the user's own symbolic hotkeys, falling back to ⌃← ⌃→ ⌃↑
- [ ] #4 Replay fixtures, including hand movements that must not count as swipes
<!-- AC:END -->
