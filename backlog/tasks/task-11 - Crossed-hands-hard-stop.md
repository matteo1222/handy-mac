---
id: TASK-11
title: Crossed-hands hard stop
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
priority: medium
type: feature
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A protective gesture that is hard to do by accident: two crossed hands held 1 s turn tracking Off from any state.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Both hands crossed for 1 s transitions to Off from every state
- [x] #2 HUD and menu-bar icon reflect Off
- [x] #3 Replay fixtures, including two-hand clips that must not trigger it
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. HardStop (pure): left hand's wrist right of the right hand's wrist by 0.3 hand scales (mirrored image), held 1 s.
2. Engine checks it in every non-Off state before anything else; releases held drag/scroll, then Off. Guards reset on Off.
3. HUD and menu-bar symbol already follow mode (Off -> hand.raised.slash).
4. Fixtures: hardStop, hardStopWhileDragging, briefCrossDoesNotStop, handsSideBySideDoNotStop.
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Crossing both hands for one second turns tracking Off from Watching, Arming, Engaged, Dragging or Scrolling, releasing anything held first. HUD and menu bar show Off. Side-by-side hands and brief crosses do not trigger it.
<!-- SECTION:FINAL_SUMMARY:END -->
