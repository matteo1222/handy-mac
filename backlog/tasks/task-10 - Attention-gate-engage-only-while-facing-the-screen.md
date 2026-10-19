---
id: TASK-10
title: 'Attention gate: engage only while facing the screen'
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
priority: high
type: feature
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Talking with your hands while looking away should never move the cursor. Completes R1.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Face detection at 5 fps; engagement allowed only while face yaw is within ±30° (configurable)
- [ ] #2 Looking away while Engaged returns to Watching
- [ ] #3 Replay fixtures with face-away segments
<!-- AC:END -->
