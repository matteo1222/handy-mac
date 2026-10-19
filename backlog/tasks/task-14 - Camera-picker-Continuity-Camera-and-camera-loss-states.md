---
id: TASK-14
title: 'Camera picker, Continuity Camera and camera-loss states'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 17:03'
labels:
  - ready-for-agent
milestone: m-1
dependencies:
  - TASK-3
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: feature
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R7: users at a TV need an external webcam or iPhone, and a video call can take the camera at any time. Failures must be said plainly with a fix.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Settings picks built-in, external or Continuity Camera; choice persists
- [x] #2 Camera taken exclusively or unplugged → pause with a HUD message naming the cause and a one-click fix
- [x] #3 Too-dark condition is detected and reported
- [x] #4 Menu-bar icon shows a distinct state whenever the camera is live
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. CameraDevices lists built-in, external and Continuity Camera devices (by AVCaptureDevice type).
2. Settings window (SwiftUI Settings scene) with a camera picker; choice persisted in UserDefaults and applied on next start or immediately when running.
3. Problem model: camera in use, disconnected, unavailable, permission denied, failed, accessibility, too dark; each with a plain message and a one-click fix (Retry, Use built-in camera, Open Settings). HUD pill becomes clickable only while it offers a fix; the menu repeats it.
4. Interruption ended resumes; DarknessMonitor (pure, hysteresis) from mean luma.
5. Menu-bar symbol: hand.raised.circle(.fill) whenever the camera is live.
6. handyctl camera <inUse|disconnected|resumed|dark|bright|fix> stages conditions to verify the HUD.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified in the running app with handyctl camera: in use -> 'Camera in use by another app' + Retry; disconnected -> 'Camera disconnected' + 'Use FaceTime HD camera' (clicking it persisted the built-in camera ID and restarted capture); dark -> 'Too dark to see your hands. Add light', cleared by bright. Real unplug / Zoom takeover not exercised; AVFoundation's interruption and disconnect notifications map onto the same states. Unit tests cover darkness hysteresis, the menu-bar symbol and problem fixes.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Settings now picks the built-in, an external or a Continuity Camera and remembers it. Camera loss, camera taken by another app, missing permissions and a too-dark scene pause tracking and are said plainly in the HUD, with a one-click fix where one exists. The menu-bar icon shows a distinct state whenever the camera is live.
<!-- SECTION:FINAL_SUMMARY:END -->
