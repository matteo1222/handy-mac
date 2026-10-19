---
id: TASK-23
title: Two-hand pinch zoom
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:39'
updated_date: '2026-10-19 17:27'
labels:
  - ready-for-agent
milestone: m-2
dependencies:
  - TASK-7
documentation:
  - docs/prd.md
  - docs/spec.md
priority: medium
type: feature
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R10: mirrors trackpad pinch-to-zoom.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Two-hand pinch spread/close posts zoom in/out (magnify event or ⌘+/⌘−)
- [x] #2 Replay fixtures
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. ZoomRecognizer (pure): both hands pinching (thumb-index below press, index reaching out) starting within 300 ms of each other; one zoom step per 15% change in distance between the pinch points; ends when either releases.
2. Engaged: zoom takes over both hands, abandons the pointer's pending press without clicking, parks the cursor; Mode.zooming for HUD.
3. Bindings.zooms: ⌘= / ⌘− (key codes through the current layout); macOS has no public API to post magnify events.
4. Fixtures: zoomIn, zoomOut, click with the other hand visible.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Inject of gestures/zoomIn records six ⌘= keystrokes and no mouseDown. Magnify (trackpad pinch) events cannot be synthesised with public CGEvent API, so zoom uses the ⌘=/⌘− shortcuts the PRD lists as the alternative.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Pinching with both hands and spreading or closing them zooms in or out in 15% steps via ⌘= / ⌘−, without the pinch also clicking. HUD shows Zooming.
<!-- SECTION:FINAL_SUMMARY:END -->
