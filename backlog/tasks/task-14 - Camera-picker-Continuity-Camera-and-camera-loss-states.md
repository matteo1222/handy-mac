---
id: TASK-14
title: 'Camera picker, Continuity Camera and camera-loss states'
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
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R7: users at a TV need an external webcam or iPhone, and a video call can take the camera at any time. Failures must be said plainly with a fix.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Settings picks built-in, external or Continuity Camera; choice persists
- [ ] #2 Camera taken exclusively or unplugged → pause with a HUD message naming the cause and a one-click fix
- [ ] #3 Too-dark condition is detected and reported
- [ ] #4 Menu-bar icon shows a distinct state whenever the camera is live
<!-- AC:END -->
