---
id: TASK-10
title: 'Attention gate: engage only while facing the screen'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 16:46'
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
- [x] #1 Face detection at 5 fps; engagement allowed only while face yaw is within ±30° (configurable)
- [x] #2 Looking away while Engaged returns to Watching
- [x] #3 Replay fixtures with face-away segments
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. AttentionGate (pure): fed by 5 fps face readings; engaging allowed only within ±maxYaw (30°, configurable), no face found counts as away; stale readings (>1 s) leave the gate open.
2. Engine: watching/arming blocked when not attentive; engaged drops to watching after 0.3 s looking away, releasing any held drag or scroll.
3. Fixtures: lookingAwayNeverEngages, noFaceNeverEngages, lookingAwayDisengages, glanceAwayKeepsEngagement.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Face detection runs at 5 fps via FrameThrottle (TASK-3) on the live camera; synth --face drives it in fixtures. A 0.3 s away dwell keeps a brief glance from dropping engagement.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Engagement now requires facing the screen: face yaw within ±30° (setting) gates arming, and looking away for 0.3 s while engaged returns to Watching after releasing anything held. Fixtures cover looking away, no face, disengaging and a harmless glance.
<!-- SECTION:FINAL_SUMMARY:END -->
