---
id: TASK-18
title: verify-handy project skill
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
priority: medium
type: chore
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Agents need a repeatable way to prove app behaviour. Generate it with pstack's create-verification-skill once inject and the record sink exist, and keep it fresh as features land.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 verify-handy skill drives the running app via handyctl (synth, inject, state, screenshot) and is proven once before hand-over
- [ ] #2 Linked from the agent instructions file
<!-- AC:END -->
