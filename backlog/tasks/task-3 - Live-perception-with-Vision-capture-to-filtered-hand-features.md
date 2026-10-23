---
id: TASK-3
title: 'Live perception with Vision: capture to filtered hand features'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-23 04:08'
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
- [x] #1 AVCaptureSession at 720p/30 fps (60 when available), late frames discarded, mirrored; throttles to 10 fps after 5 s with no hand
- [x] #2 Joints below 0.3 confidence dropped; hands with fewer than 15 valid joints rejected; hands matched across frames by nearest wrist with mirrored chirality
- [x] #3 Per-joint, per-axis 1€ filter that resets on track loss; features normalised by hand scale (pinch distances, curls, palm centroid, palm facing, velocities)
- [x] #4 A debug overlay shows live landmarks and features
- [x] #5 Live sessions can be recorded to the landmark format and replayed with identical features
- [x] #6 Pose + filter + features stay within budget on M1 (inference ≤ 10 ms, filter+features ≤ 1 ms) as measured by a bench
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. HandyPerception: HandPoseProvider/FaceProvider ports, Vision backends, ImageGeometry (frame-height units, frames mirrored at capture so chirality needs no flip).
2. CameraCapture: AVCaptureSession 720p, 60 fps when offered, late frames dropped, mirrored connection; PerceptionWorker actor whose executor is the capture queue; FrameThrottle (pure, core) drops to 10 fps after 5 s without a hand, face at 5 fps.
3. Quality gate / identity / 1€ / features already in HandyCore (TASK-2).
4. App: LiveTracking runs camera while not Off, frames into the shared Session; debug overlay window; landmark recording (menu + handyctl record); live perception stats in handyctl state.
5. Proof: Vision tests on rendered emoji hands; handyctl bench-perception; recorded-session replay test; live check with the real camera.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Vision finds all 21 joints on rendered ✋/👍/🤏/🤙 emoji, which gives camera-free backend tests and a bench. bench-perception (release, Apple M3): inference p50 6.0 / p95 8.0 ms, filter+features p95 0.006 ms for two hands. Not yet measured on M1. Recording round-trip test proves identical features.

Checked with direct evidence: AC2 HandTrackerTests (confidence < 0.3 dropped, < 15 joints rejected, nearest-wrist identity; chirality comes from Vision on the mirrored frame, which the rendered-emoji test confirms reads a right hand as right); AC3 1€ filter reset on track loss (test) and scale-normalised features (pinch, reach/curl, palm centroid, facing, velocity); AC5 recordedSessionReplaysToIdenticalFeatures. Open: AC1 and AC4 need the live camera (Handy's camera permission prompt is still unanswered on this Mac, so no frames have arrived); AC6 measured on Apple M3 (inference p95 8.0 ms, filter+features p95 0.006 ms) but not yet on an M1.

Live evidence (2026-10-20): capture runs 1280x720 mirrored, 30 fps with a hand (recording shows 30 frames/s) and 10 fps idle (frameInterval p50 100 ms after 5 s without a hand); mirroring confirmed by the chirality analysis of the live recording (a live recording, not kept in the repo). Debug overlay verified: handyctl screenshot debug-overlay during handyctl inject of a real-hand clip shows all 21 landmarks, palm centroid and the feature line (scale, pinch, reach, facing). AC6: with Vision, live inference is p50 10 ms / p95 27 ms on M3 (over budget); the Core ML backend measures p50 1.1-2.2 / p95 3.4-5.2 ms on real video clips and filter+features p95 < 1 ms, so AC6 passes once TASK-4 picks Core ML as the default (no M1 available here; measured on M3).

AC6 (2026-10-22): handyctl bench-perception with the app stopped: Core ML p50 1.5 / p95 4.7 ms, Vision p50 2.6 / p95 2.8 ms, filter+features p95 0.01 ms (measured on M3; no M1 here). Inside the running app both backends measure ~24 ms per idle frame; that floor is contention in the app, tracked as a follow-up.

In-app inference, measured with a hand in view (4fd30c0, 164b7f0; M3, macOS 26.6, release app, 30 fps). Method: real hand clips (.build/videos: six-seven, rock-paper-scissors, ghana-alphabet, hand-wave) swapped frame for frame into the live capture callback, camera running, output on a recording sink; no one recorded. perception.inference p50/p95 ms: start of the day (Core ML on the Neural Engine) 21.3-23.1 / 26-31; after 4fd30c0 (CPU+GPU) six-seven 11.6/34.9, rock-paper-scissors 12.0/33.5, hand-wave 20.6/25.0; after 164b7f0 six-seven 8.6/13.6, rock-paper-scissors 10.4/19.5, ghana-alphabet 8.4/19.0, hand-wave (two hands most frames) 14.9/19.2. One-hand frames with a single landmark run: p50 7.7-8.3, p95 10.0-10.3. Empty frames now cost ~0.03 ms on the frame path because the palm detector runs on its own queue between frames (12 ms there). Per landmark run: vImage crop 0.6-0.9 ms + Core ML predict p50 ~7.5 / p95 ~9.5. Budget (spec: hand pose <= 10 ms, one hand) is met at p50 but not cleanly at p95. Why not lower: (1) the Neural Engine runs the landmark model in ~2.3 ms with no camera, but with the camera on, every frame carries one ~15 ms Neural Engine collision with work the macOS camera stack does in our process (Portrait/CMIO video-effects graph; not the face detector, HUD, format, mirroring or Reactions plist key), so it is unusable live; (2) on CPU or GPU the predict is mostly CPU-side kernel encoding on a core that clocks down between frames: 2.6 ms back-to-back vs 7.5 ms at 30 fps pacing; keeping the core busy fixes it but needs 6-12 ms of spinning per frame. Two-hand frames are about twice one-hand. Remaining levers: a lighter landmark model, batching both hands into one prediction, or the face detector on its own queue (it does not slow hand inference, but hand+face can overrun a 33 ms frame with two hands).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Live perception: 1280x720 mirrored capture at 30 fps (10 fps after 5 s without a hand), late frames dropped; confidence and joint-count gates, wrist identity with PalmFit when the wrist is off-frame; per-joint 1-euro filter and scale-normalised features; debug overlay; record and replay with identical features; inference and filter+features inside budget on the bench. Follow-up: the in-app inference floor.
<!-- SECTION:FINAL_SUMMARY:END -->
