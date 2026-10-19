---
id: TASK-20
title: 'Oops gesture: ⌘Z plus false-positive sample'
status: To Do
assignee: []
created_date: '2026-10-19 15:39'
labels:
  - ready-for-agent
milestone: m-2
dependencies:
  - TASK-12
documentation:
  - docs/prd.md
  - docs/spec.md
priority: medium
type: feature
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R8: undo is one gesture away, and every oops becomes training and regression data.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Oops gesture posts ⌘Z
- [ ] #2 The preceding landmark window is saved as a false-positive sample (numbers only)
- [ ] #3 Accidental-action counter visible in a local log the user can open
<!-- AC:END -->
