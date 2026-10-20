---
id: TASK-19
title: 'Alpha exit: 5 internal users under 3 accidental actions/hour'
status: To Do
assignee: []
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 18:39'
labels:
  - ready-for-human
milestone: m-1
dependencies:
  - TASK-8
  - TASK-9
  - TASK-10
  - TASK-11
  - TASK-13
  - TASK-14
  - TASK-15
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: task
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The PRD gates the alpha on measured trust, not feature count.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 5 internal users complete daily use for the alpha period
- [ ] #2 Accidental actions measured below 3 per hour of active use
- [ ] #3 Misfires collected as landmark clips and added to the corpus
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Tooling ready (agent side): each user's Handy keeps counts-only usage (engaged time, actions by kind, oops) per day in usage.json; the menu shows today's minutes and accidental actions per hour and handyctl report prints the totals (accidental per hour = oops per engaged hour). scripts/collect-misfires.sh <participant> copies each user's oops landmark samples into corpus/misfires/. Running the alpha with 5 people is the remaining human work.
<!-- SECTION:NOTES:END -->
