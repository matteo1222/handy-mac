---
id: TASK-2
title: 'Replay lever: landmark format, handyctl synth and replay'
status: To Do
assignee: []
created_date: '2026-10-19 15:38'
labels:
  - ready-for-agent
milestone: m-0
dependencies:
  - TASK-1
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: feature
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
An agent cannot wave at a camera, so every gesture must be provable from synthetic or recorded landmarks. This ticket builds the lever the rest of the backlog verifies against: a landmark stream format, a parametric clip generator and a headless replay that diffs emitted events. The engine reads time only from frame timestamps, so replays are deterministic.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A versioned landmark-stream file format (landmarks + timestamps, never images) with Codable decode tests on fixtures
- [ ] #2 handyctl synth generates parametric clips from a pose library with jitter, dropout and confidence-loss options
- [ ] #3 handyctl replay runs HandyCore headless and diffs emitted events against an expected file; deterministic and under 1 s per clip
- [ ] #4 A test iterating Gesture.allCases fails when a gesture has no replay fixture
<!-- AC:END -->
