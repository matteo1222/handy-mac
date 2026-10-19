---
id: TASK-15
title: Onboarding and calibration in ≤ 3 minutes
status: To Do
assignee: []
created_date: '2026-10-19 15:38'
labels:
  - ready-for-agent
milestone: m-1
dependencies:
  - TASK-7
  - TASK-9
  - TASK-14
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: feature
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R4: time to first successful click must be under 3 minutes median. The tutorial doubles as calibration so thresholds fit each hand. Permissions are asked in context, never at launch.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Camera permission asked on 'Start tutorial'; Accessibility asked at the first click step and detected automatically once granted; each permission screen shows a looping preview
- [ ] #2 Framing check gives live guidance (move left, more light)
- [ ] #3 Interactive tutorial: engage, move, click a big target, scroll a list, disengage
- [ ] #4 Calibration stores hand size, pinch thresholds and reach box as numbers only, never images
- [ ] #5 handyctl screenshot onboarding captures each step
<!-- AC:END -->
