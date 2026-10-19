---
id: TASK-5
title: Engage/disengage clutch with live HUD pill
status: To Do
assignee: []
created_date: '2026-10-19 15:38'
labels:
  - ready-for-agent
milestone: m-1
dependencies:
  - TASK-3
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: feature
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Trust starts with nothing firing uninvited: control is off until an explicit open palm held 300 ms, and drops on fist or hand loss. The user must always see whether Handy is listening, so the HUD pill ships with the clutch. The engine is a pure reducer (State, Input) -> (State, [Effect]) over exhaustive enums. Covers R1 (without the face gate) and R3.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Open palm (4 fingers extended, facing camera) held 300 ms moves Watching → Arming → Engaged; any finger curling for 150 ms aborts arming
- [ ] #2 Fist or hand lost returns to Watching
- [ ] #3 HUD pill (top centre, click-through, non-activating, sharingType none) shows Off / Watching / Engaged and the last action, and is absent from screen recordings
- [ ] #4 Arming shows a progress ring
- [ ] #5 Replay fixtures cover engage, aborted arm, disengage and a resting/typing hand that never engages
<!-- AC:END -->
