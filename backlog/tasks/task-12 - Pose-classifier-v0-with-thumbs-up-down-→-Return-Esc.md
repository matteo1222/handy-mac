---
id: TASK-12
title: Pose classifier v0 with thumbs-up/down → Return/Esc
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
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Keyboard intent needs static poses that never fire by accident. A small MLP over normalised joints plus curl angles with an explicit no-gesture class gives one-shots a confidence margin. Thumbs-up/down is the first one-shot to exercise it end to end (part of R6).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 MLP trained on HaGRID landmarks, shipped as a Core ML model under 1 MB
- [ ] #2 One-shot fires only when confidence > 0.9 for the hold time and exceeds the no-gesture class by 0.3, and only while not Engaged
- [ ] #3 Thumbs-up / thumbs-down held 500 ms post Return / Esc with a progress arc in the HUD
- [ ] #4 Keyboard events use key codes resolved through the current layout
- [ ] #5 Per-gesture precision/recall and no-gesture false-positive rate reported on a held-out split
<!-- AC:END -->
