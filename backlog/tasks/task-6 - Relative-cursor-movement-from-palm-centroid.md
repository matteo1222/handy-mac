---
id: TASK-6
title: Relative cursor movement from palm centroid
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
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Moving the pointer is the core trackpad action. The palm centroid is far steadier than a fingertip, and relative (clutched, trackpad-like) mapping keeps arms low. This is also the first slice that reaches the OS, so it introduces HandyOutput and the record sink agents use to check events without posting them.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 While Engaged, cursor delta = filtered palm delta × a trackpad-like acceleration curve
- [ ] #2 Within 24 px of a screen edge the cursor sticks for 150 ms
- [ ] #3 CGEvent posting lives only in HandyOutput; Accessibility permission is checked and a missing permission is reported, not crashed on
- [ ] #4 handyctl inject feeds a clip into the running app over local XPC instead of the camera; --sink record captures CGEvents without posting them
- [ ] #5 handyctl state reports engine state, HUD state, last events and filter parameters
- [ ] #6 Cursor jitter while the hand is still is measured and reported
<!-- AC:END -->
