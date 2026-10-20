---
id: TASK-28
title: 'Beta exit: 20 testers, under 1 accidental action/hour'
status: To Do
assignee: []
created_date: '2026-10-19 15:39'
updated_date: '2026-10-19 18:39'
labels:
  - ready-for-human
milestone: m-2
dependencies:
  - TASK-16
  - TASK-17
  - TASK-20
  - TASK-21
  - TASK-22
  - TASK-23
  - TASK-24
  - TASK-25
  - TASK-26
  - TASK-27
documentation:
  - docs/prd.md
  - docs/spec.md
priority: medium
type: task
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The PRD gates beta on measured trust and pointing quality.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 20 external testers onboarded
- [ ] #2 Accidental actions below 1 per hour
- [ ] #3 ISO 9241-411 pointing throughput ≥ 2 bits/s at 0.6 m
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Tooling ready (agent side): menu Pointing Test… runs the ISO 9241-411 tapping task (13 targets, 4 amplitude x width conditions) with Handy, a trackpad or a mouse and saves throughput (bits/s, effective-width method) to <data>/PointingTests/; handyctl report gives accidental actions per hour. External testers need the signed build (TASK-27).
<!-- SECTION:NOTES:END -->
