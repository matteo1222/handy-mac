---
id: TASK-11
title: Crossed-hands hard stop
status: To Do
assignee: []
created_date: '2026-10-19 15:38'
labels:
  - ready-for-agent
milestone: m-1
dependencies:
  - TASK-5
documentation:
  - docs/prd.md
  - docs/spec.md
priority: medium
type: feature
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A protective gesture that is hard to do by accident: two crossed hands held 1 s turn tracking Off from any state.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Both hands crossed for 1 s transitions to Off from every state
- [ ] #2 HUD and menu-bar icon reflect Off
- [ ] #3 Replay fixtures, including two-hand clips that must not trigger it
<!-- AC:END -->
