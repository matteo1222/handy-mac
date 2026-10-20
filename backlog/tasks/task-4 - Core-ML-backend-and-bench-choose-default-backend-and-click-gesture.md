---
id: TASK-4
title: 'Core ML backend and bench: choose default backend and click gesture'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-20 14:14'
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
- [x] #1 Core ML backend implements the same HandPoseProvider port and passes the same replay tests
- [x] #2 Bench report compares both backends on latency, jitter (px RMS) and landmark accuracy in dim light on identical clips
- [x] #3 Click-gesture A/B (thumb–index pinch vs index dip) measured on recorded clips
- [ ] #4 Decision recorded in Backlog: default backend (must meet 30 fps at < 10 ms inference) and default click gesture
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Click A/B done on synthetic clips (doc-1, docs/click-ab-report.json): both 100% recall and 0 false clicks/hour; with the thumb tip hidden pinch 0% vs index dip 100%; fidget headroom pinch 0.102 vs dip 0.059. Index dip is implemented as ClickSettings.gesture = .indexDip (dip respects the low-confidence-tip rule). Remaining: AC1/AC2 need the MediaPipe hand landmarker converted to Core ML (a model download and coremltools); AC4 is the human decision. Recorded clips (TASK-17) should rerun the A/B before deciding.

Core ML backend done (0a4d07e): CoreMLHandPoseProvider = MediaPipe palm detector + landmarker (Apache-2.0, converted via scripts/convert-hand-models.sh) with ROI tracking from the previous frame's landmarks; same HandPoseProvider port, agrees with Vision on rendered hands (CoreMLProviderTests), full suite passes. Select with `defaults write dev.handy.Handy handBackend coreml`.

Bench on identical real clips (4 Commons videos via scripts/fetch-videos.sh, each also dimmed + noise; docs/backend-report.json via scripts/backend-report.py): Core ML inference p50 1.1-2.2 ms / p95 3.4-5.2 ms vs Vision p50 6.1-7.3 / p95 7.8-10.5 (Vision live in the app measured p50 10-28 ms). Hand found: Vision higher on 2 clips (0.94-1.0 vs 0.87-1.0), Core ML much better on rock-paper-scissors (0.93 vs 0.75; dim 0.89 vs 0.47). Jitter mixed (Core ML lower on 2 of 4). Recommendation: Core ML as default (only backend inside the 10 ms budget with margin), Vision as fallback. Open before deciding: Core ML chirality on a live hand (MediaPipe's handedness convention vs our mirrored frames; emoji are inconclusive) and a live A/B in the app. AC4 needs the human decision.
<!-- SECTION:NOTES:END -->
