---
id: TASK-6
title: Relative cursor movement from palm centroid
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 16:35'
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
- [x] #1 While Engaged, cursor delta = filtered palm delta × a trackpad-like acceleration curve
- [x] #2 Within 24 px of a screen edge the cursor sticks for 150 ms
- [x] #3 CGEvent posting lives only in HandyOutput; Accessibility permission is checked and a missing permission is reported, not crashed on
- [x] #4 handyctl inject feeds a clip into the running app over the local control socket instead of the camera; --sink record captures CGEvents without posting them
- [x] #5 handyctl state reports engine state, HUD state, last events and filter parameters
- [x] #6 Cursor jitter while the hand is still is measured and reported
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Core: PointerSettings (cursor 1€ filter, slow/fast gain curve, deadband), PointerTracker (re-anchors on engage), EdgeStick (24 pt band, 150 ms hold), Rect.
2. Engine emits moveCursor(dx:dy:) while engaged; a forming fist re-anchors instead of dragging.
3. HandyOutput: OutputAction, EventSink (CGEventSink live, RecordingSink), PointerEnvironment (live via NSScreen, virtual), OutputDriver with posted/refused counts.
4. App: driver wired to events; HUD says 'Accessibility permission needed' when posts are refused.
5. handyctl inject (--sink record|live, --realtime), richer handyctl state (HUD, last events, settings, output stats), handyctl bench-cursor.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Live inject found CGGetActiveDisplayList returning zero displays inside the app, so every move was silently dropped (a recording looked right only because the virtual environment fell back to a default screen). Fixed by using NSScreen. Inject of gestures/moveCursor with --sink record: 29 events, 23 moves clamped to the 1470 pt display. With --sink live and no Accessibility: 27 posts refused, HUD shows the problem, app keeps running. bench-cursor: still hand jitter 0 pt RMS at <= 2 px joint noise, 0.9 pt at 4 px (deadband 0.25 pt). Real-camera jitter not yet measured (camera permission pending).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Engaged palm motion now drives the cursor: a dedicated 1€ filter on the palm centroid, a trackpad-like gain curve (1400 to 5200 pt per frame height) and a small deadband, with 150 ms edge stick and on-screen clamping in HandyOutput. handyctl inject runs clips through the live app and can capture output instead of posting it; handyctl state shows engine, HUD, recent events, settings and output counts. Missing Accessibility is reported in the HUD, never fatal.
<!-- SECTION:FINAL_SUMMARY:END -->
