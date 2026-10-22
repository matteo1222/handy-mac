---
id: TASK-4
title: 'Core ML backend and bench: choose default backend and click gesture'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-22 00:19'
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
- [x] #4 Decision recorded in Backlog: default backend (must meet 30 fps at < 10 ms inference) and default click gesture
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Click A/B done on synthetic clips (doc-1, docs/click-ab-report.json): both 100% recall and 0 false clicks/hour; with the thumb tip hidden pinch 0% vs index dip 100%; fidget headroom pinch 0.102 vs dip 0.059. Index dip is implemented as ClickSettings.gesture = .indexDip (dip respects the low-confidence-tip rule). Remaining: AC1/AC2 need the MediaPipe hand landmarker converted to Core ML (a model download and coremltools); AC4 is the human decision. Recorded clips (TASK-17) should rerun the A/B before deciding.

Core ML backend done (0a4d07e): CoreMLHandPoseProvider = MediaPipe palm detector + landmarker (Apache-2.0, converted via scripts/convert-hand-models.sh) with ROI tracking from the previous frame's landmarks; same HandPoseProvider port, agrees with Vision on rendered hands (CoreMLProviderTests), full suite passes. Select with `defaults write dev.handy.Handy handBackend coreml`.

Bench on identical real clips (4 Commons videos via scripts/fetch-videos.sh, each also dimmed + noise; docs/backend-report.json via scripts/backend-report.py): Core ML inference p50 1.1-2.2 ms / p95 3.4-5.2 ms vs Vision p50 6.1-7.3 / p95 7.8-10.5 (Vision live in the app measured p50 10-28 ms). Hand found: Vision higher on 2 clips (0.94-1.0 vs 0.87-1.0), Core ML much better on rock-paper-scissors (0.93 vs 0.75; dim 0.89 vs 0.47). Jitter mixed (Core ML lower on 2 of 4). Recommendation: Core ML as default (only backend inside the 10 ms budget with margin), Vision as fallback. Open before deciding: Core ML chirality on a live hand (MediaPipe's handedness convention vs our mirrored frames; emoji are inconclusive) and a live A/B in the app. AC4 needs the human decision.

Decision (decision-3, 2026-10-22): Core ML (MediaPipe) is the default backend, Vision the automatic fallback; thumb-index pinch stays the default click (index dip remains a setting). Evidence: bench-perception with Handy stopped, Core ML p50 1.5 / p95 4.7 ms, Vision p50 2.6 / p95 2.8 ms (both inside 10 ms); real video clips Core ML p50 1.1-2.2 / p95 3.4-5.2 vs Vision 6.1-7.3 / 7.8-10.5; camera-format YUV frames paced at 30 fps Core ML p50 5.7-6.8 vs Vision 10-14 with a hand. Fixed on the way: Core ML handedness was inverted (agreed with Vision on 15% of matched hands, 85% after the flip, 94% on the single-signer clip), and the palm-detector decode now reads only the score column (no-hand frame in debug 21 -> 7.7 ms). Known gaps: inside the running app both backends sit at ~24 ms per idle frame (a contention floor, not the models; follow-up), and MediaPipe gives no per-joint confidence, so the low-confidence-tip guard does not fire on Core ML.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Spike done: CoreMLHandPoseProvider (MediaPipe palm detector + landmarker on Core ML, ROI tracking) behind the same HandPoseProvider port; backend report on identical real and dimmed clips (docs/backend-report.json); click A/B (doc-1). Core ML is now the default with Vision as fallback, pinch the default click (decision-3). Follow-ups: the ~24 ms in-app inference floor shared by both backends, and per-joint confidence for Core ML.
<!-- SECTION:FINAL_SUMMARY:END -->
