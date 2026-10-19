---
id: TASK-3
title: 'Live perception with Vision: capture to filtered hand features'
status: To Do
assignee: []
created_date: '2026-10-19 15:38'
labels:
  - ready-for-agent
milestone: m-0
dependencies:
  - TASK-2
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: feature
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The engine needs real, steady hand features from the built-in camera. This slice runs camera → Vision hand pose → quality gate → hand identity → 1€ filter → normalised features end to end, behind the HandPoseProvider port so a second backend can slot in, and can record real sessions into the replay format.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 AVCaptureSession at 720p/30 fps (60 when available), late frames discarded, mirrored; throttles to 10 fps after 5 s with no hand
- [ ] #2 Joints below 0.3 confidence dropped; hands with fewer than 15 valid joints rejected; hands matched across frames by nearest wrist with mirrored chirality
- [ ] #3 Per-joint, per-axis 1€ filter that resets on track loss; features normalised by hand scale (pinch distances, curls, palm centroid, palm facing, velocities)
- [ ] #4 A debug overlay shows live landmarks and features
- [ ] #5 Live sessions can be recorded to the landmark format and replayed with identical features
- [ ] #6 Pose + filter + features stay within budget on M1 (inference ≤ 10 ms, filter+features ≤ 1 ms) as measured by a bench
<!-- AC:END -->
