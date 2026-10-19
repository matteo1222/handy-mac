---
id: TASK-9
title: Scroll with momentum
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 16:44'
labels:
  - ready-for-agent
milestone: m-1
dependencies:
  - TASK-6
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: feature
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Scrolling is the most common hands-busy action. Apps should see trackpad-like scrolling, and the cursor must not wander while scrolling.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Index + middle extended with ring + little curled for 150 ms enters Scrolling; pose lost 150 ms exits
- [x] #2 Cursor parks while scrolling; scroll velocity = palm velocity × gain
- [x] #3 Pixel-unit scroll-wheel events with momentum phases; momentum decays 0.92 per frame after release
- [x] #4 HUD shows Scrolling
- [x] #5 Replay fixtures for vertical scroll, horizontal scroll and momentum
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. ScrollRecognizer (pure): enter after the two-finger pose holds 150 ms, exit 150 ms after it is lost; content follows the hand at a fixed 3000 pt per frame height; momentum decays 0.92 per frame and stops below 0.5 pt/frame.
2. Engine: scroll gets first claim on hand motion (cursor parks), clicks get the rest; Mode.scrolling for HUD; fist and hand loss cancel scrolling.
3. Output: continuous pixel scroll-wheel CGEvents with scroll and momentum phases; fractional remainders carried between events.
4. Fixtures: scroll (vertical), scrollHorizontal, scrollMomentum, briefScrollPoseDoesNotScroll.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixture review: momentum died after one frame because the hand's own deceleration after a flick counted as pointing again. Fixed with a 0.25 s momentum grace and a smoothed release velocity. Inject of scrollMomentum records 41 scroll actions: began, changed..., ended, then momentum (momentumStart on the first) decaying to the end. HandyControlTests now depends on HandyCore directly; without it SwiftPM reused a stale test object after Engine.Event changed layout and the test bundle segfaulted.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Index and middle fingers up (held 150 ms) scrolls: the cursor parks, content follows the hand at a fixed gain, and releasing coasts with momentum decaying 0.92 per frame. Output is trackpad-like continuous pixel scrolling with scroll and momentum phases. HUD shows Scrolling. Fixtures cover vertical, horizontal, momentum and a too-brief pose.
<!-- SECTION:FINAL_SUMMARY:END -->
