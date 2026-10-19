---
id: TASK-15
title: Onboarding and calibration in ≤ 3 minutes
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 17:07'
labels:
  - ready-for-agent
milestone: m-1
dependencies:
  - TASK-7
  - TASK-9
  - TASK-14
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: feature
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R4: time to first successful click must be under 3 minutes median. The tutorial doubles as calibration so thresholds fit each hand. Permissions are asked in context, never at launch.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Camera permission asked on 'Start tutorial'; Accessibility asked at the first click step and detected automatically once granted; each permission screen shows a looping preview
- [x] #2 Framing check gives live guidance (move left, more light)
- [x] #3 Interactive tutorial: engage, move, click a big target, scroll a list, disengage
- [x] #4 Calibration stores hand size, pinch thresholds and reach box as numbers only, never images
- [x] #5 handyctl screenshot onboarding captures each step
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Core (pure, replayable): Tutorial step machine advanced by engine events; FramingAdvice from hand position, size and brightness; CalibrationRecorder -> Calibration (hand size, pinch press/release, reach box) applied to EngineSettings.
2. App: OnboardingModel; camera asked on 'Start tutorial', Accessibility asked when the click step starts and polled until granted; LoopingPreview on each permission screen (static under Reduce Motion).
3. OnboardingView, one instruction per step; opens on first launch and from the menu (Tutorial…); calibration saved as JSON numbers in Application Support and applied at launch.
4. handyctl screenshot onboarding (contact sheet) and onboarding:<step>.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
A synthetic walkthrough clip drives the tutorial engage -> move -> click -> scroll -> disengage -> done and yields a calibration (hand size 0.15, press < release, reach box) in a test. Calibration JSON has only version, handSize, pinchPress, pinchRelease, reachBox. Every step rendered via handyctl screenshot. Not measured: the 3-minute median time to first click (needs people), and the live camera run (camera permission still pending on this Mac).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
First launch opens a short tutorial: Start asks for the camera, a framing check gives live advice, then engage, move, click a big target, scroll a list and let go. Accessibility is asked only at the click step and detected automatically. The tutorial calibrates hand size, pinch thresholds and reach as plain numbers and applies them. Each step can be screenshotted with handyctl.
<!-- SECTION:FINAL_SUMMARY:END -->
