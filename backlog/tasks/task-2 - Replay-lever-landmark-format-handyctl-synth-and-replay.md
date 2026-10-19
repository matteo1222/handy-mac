---
id: TASK-2
title: 'Replay lever: landmark format, handyctl synth and replay'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 16:14'
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
- [x] #1 A versioned landmark-stream file format (landmarks + timestamps, never images) with Codable decode tests on fixtures
- [x] #2 handyctl synth generates parametric clips from a pose library with jitter, dropout and confidence-loss options
- [x] #3 handyctl replay runs HandyCore headless and diffs emitted events against an expected file; deterministic and under 1 s per clip
- [x] #4 A test iterating Gesture.allCases fails when a gesture has no replay fixture
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. HandyCore data shapes: Joint, Finger, Chirality, JointSample, HandPose, FaceSample, LandmarkFrame (frame-height units, mirrored; numbers only).
2. Pure pipeline: quality gate, nearest-wrist identity, per-joint 1€ filter, HandFeatures; Session = pipeline + engine.
3. HandyReplay: JSON Lines .lmk (header + one frame per line), reader/writer/streaming writer, decode tests on a frozen fixture.
4. Synth: 3D hand model projected to 2D, pose library, clip scripts, seeded jitter/dropout/confidence loss.
5. handyctl synth / replay / features.
6. Gesture enum + generic fixture coverage check.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Coordinates are in frame heights (x in 0...aspect) so distances are isotropic; the header meta carries aspect. Coverage check is generic over CaseIterable (an empty enum would make a parameterised test unreachable under warnings-as-errors); a probe enum proves it reports a missing fixture. handyctl replay of a 39-frame clip takes ~2 ms; a 10 s noisy clip replays deterministically well under 1 s (test). Pipeline pieces from TASK-3 (quality gate, identity, 1€ filter, features) live here because replay needs them.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Built the replay lever: a versioned JSON Lines landmark format with decode tests on a frozen fixture, a seeded parametric synth (pose library, scripts, jitter/dropout/confidence loss), and handyctl synth/replay/features. Replay runs the real HandyCore Session headless and exits 1 on any event diff. Gesture coverage is enforced by a generic fixture check.
<!-- SECTION:FINAL_SUMMARY:END -->
