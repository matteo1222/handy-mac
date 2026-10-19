---
id: TASK-22
title: Spaces swipe and Mission Control
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:39'
updated_date: '2026-10-19 17:25'
labels:
  - ready-for-agent
milestone: m-2
dependencies:
  - TASK-5
documentation:
  - docs/prd.md
  - docs/spec.md
priority: medium
type: feature
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R10: swipe between Spaces and open Mission Control like a 3-finger trackpad swipe.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Open-palm swipe over 25% of frame width in under 400 ms → previous/next Space; swipe up → Mission Control
- [x] #2 600 ms refractory after firing
- [x] #3 Uses the user's own symbolic hotkeys, falling back to ⌃← ⌃→ ⌃↑
- [x] #4 Replay fixtures, including hand movements that must not count as swipes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. SwipeRecognizer (pure): open palm, palm travel >= 25% of frame width (left/right) or height (up) within 400 ms, 2:1 dominance, 600 ms refractory; runs in Watching and Arming; arming held off during the refractory.
2. Arming now requires the palm roughly still (< 0.6 frame heights/s), so a swipe cannot engage on the way.
3. Actions previousSpace / nextSpace / missionControl; output resolves them from com.apple.symbolichotkeys (79, 81, 32), falling back to ⌃← ⌃→ ⌃↑.
4. Fixtures: swipeLeft/Right/Up; short swipe, slow palm move, swipe while engaged must not fire.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Review found two more real problems: (a) HandTracker handed a fast-moving hand back to a stale track held through a dropout because it was nearer; live tracks now win over stale ones; (b) the synthetic relaxed hand matched the scroll pose, so scroll needs clear margins (index/middle reach > 0.6, ring/little < 0.2). Bench 2.98 -> 1.49 false actions/hour (drags 1 -> 0, engages 3 -> 1); baseline updated with diff. Inject: swipeLeft -> ⌃← (Previous Space), swipeUp -> ⌃↑. Mapping follows the PRD (swipe left = previous Space); trackpad users may expect the opposite, so it is a binding. This Mac uses the default Spaces shortcuts; custom-shortcut parsing is unit tested.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Open-palm swipes while not engaged switch Spaces and open Mission Control, sent with the user's own system shortcuts (or the defaults). Swipes have distance, time, dominance and refractory checks; arming now needs a held palm. Along the way, fixed a tracker identity bug and a relaxed hand reading as the scroll pose; synthetic false actions dropped to 1.49/hour.
<!-- SECTION:FINAL_SUMMARY:END -->
