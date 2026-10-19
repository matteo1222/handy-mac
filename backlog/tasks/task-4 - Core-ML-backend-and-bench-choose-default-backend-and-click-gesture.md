---
id: TASK-4
title: 'Core ML backend and bench: choose default backend and click gesture'
status: To Do
assignee: []
created_date: '2026-10-19 15:38'
labels:
  - ready-for-human
milestone: m-0
dependencies:
  - TASK-3
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: spike
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Vision hand-pose quality may plateau, and a front camera can hide the thumb–index pinch. The spike compares Vision against a MediaPipe-on-Core-ML backend with frame-to-frame ROI tracking on the same recorded clips, and A/Bs thumb–index pinch against index-finger dip, so a human picks the defaults with numbers in hand. Resolves two open questions in the spec.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Core ML backend implements the same HandPoseProvider port and passes the same replay tests
- [ ] #2 Bench report compares both backends on latency, jitter (px RMS) and landmark accuracy in dim light on identical clips
- [ ] #3 Click-gesture A/B (thumb–index pinch vs index dip) measured on recorded clips
- [ ] #4 Decision recorded in Backlog: default backend (must meet 30 fps at < 10 ms inference) and default click gesture
<!-- AC:END -->
