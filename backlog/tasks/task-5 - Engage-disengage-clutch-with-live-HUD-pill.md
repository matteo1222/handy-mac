---
id: TASK-5
title: Engage/disengage clutch with live HUD pill
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 16:29'
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
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Trust starts with nothing firing uninvited: control is off until an explicit open palm held 300 ms, and drops on fist or hand loss. The user must always see whether Handy is listening, so the HUD pill ships with the clutch. The engine is a pure reducer (State, Input) -> (State, [Effect]) over exhaustive enums. Covers R1 (without the face gate) and R3.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Open palm (4 fingers extended, facing camera) held 300 ms moves Watching → Arming → Engaged; any finger curling for 150 ms aborts arming
- [x] #2 Fist or hand lost returns to Watching
- [x] #3 HUD pill (top centre, click-through, non-activating, sharingType none) shows Off / Watching / Engaged and the last action, and is absent from screen recordings
- [x] #4 Arming shows a progress ring
- [x] #5 Replay fixtures cover engage, aborted arm, disengage and a resting/typing hand that never engages
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Engine as explicit state enum (off/watching/arming/engaged) with per-state handlers and EngineSettings (dwell and hysteresis values from spec).
2. Clutch: open palm (4 fingers extended + palm facing) held 300 ms engages; curl for 150 ms aborts; fist 150 ms or hand lost 200 ms disengages. Tracker keeps identity through 250 ms dropouts.
3. HUD: HUDState (pure) -> HUDView pill (Liquid Glass on macOS 26, material fallback) in a borderless non-activating click-through NSPanel with sharingType none.
4. Proof: scripts/fixtures.sh recipes + replay fixtures, handyctl screenshot hud-gallery, handyctl windows (sharing state).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixture review found that one dropped frame broke hand identity and aborted arming; fixed at the root (tracker grace period, arming tolerates dropouts). handyctl windows reports the HUD panel with kCGWindowSharingState 0 (excluded from capture). Offscreen snapshots cannot composite glass/vibrancy, so screenshots draw a solid pill via an environment flag; on-screen it is glass.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Engine is now an explicit clutch state machine: open palm 300 ms engages, curl 150 ms aborts arming, fist or hand loss disengages, with dwell bands so single noisy frames cannot flip state. A glass HUD pill shows state, the arming ring and last action, sits top-centre, ignores the mouse, never activates and is excluded from screen capture. Fixtures cover engage, disengage, hand lost, aborted arm, brief curl, resting/typing and sideways hands, and dropout.
<!-- SECTION:FINAL_SUMMARY:END -->
