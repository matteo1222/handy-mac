---
id: TASK-21
title: Command palette with 8 per-app slots
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:39'
updated_date: '2026-10-19 18:30'
labels:
  - ready-for-agent
milestone: m-2
dependencies:
  - TASK-7
  - TASK-12
documentation:
  - docs/prd.md
  - docs/spec.md
priority: medium
type: feature
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R9: the long tail of shortcuts without memorising 30 poses. Other-hand pinch-hold opens a radial menu; a flick toward a slot fires it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Other-hand pinch-hold opens a radial menu of 8 slots around the cursor
- [x] #2 Flick toward a slot fires its action; releasing without a flick cancels
- [x] #3 Slots are configurable per frontmost app
- [x] #4 Each Action is one typed value projected to gesture binding, menu bar, App Intent and handyctl; a CaseIterable test fails on a missing projection
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. NamedAction catalog (CaseIterable typed values -> Action), PaletteLayout (8 slots clockwise from the top), PaletteBindings (all apps + per bundle ID) stored in UserSettings.
2. PaletteRecognizer (pure): while engaged, the other hand's pinch held 400 ms (pointer not pinching) opens; highlight past 0.25 hand scales; fire past 0.8 toward a slot; release or hand loss cancels. Cursor frozen while open; Mode.palette in HUD.
3. Router resolves fired slots through the frontmost app's layout.
4. Projections from the catalog: palette slots (Settings editor), menu bar Actions submenu, App Intent (PerformHandyActionIntent + HandyActionEnum), handyctl perform [--record]. CaseIterable projection test.
5. PalettePanel radial overlay at the cursor (glass slots, capture-excluded); fixtures palette, release cancels, brief pinch.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Inject of gestures/palette records one ⌘T (slot 0, New Tab); handyctl perform missionControl --record records ⌃↑. Caveat on the App Intent projection: the intent and its enum compile and are tested for completeness, but Shortcuts discovers intents from metadata that Xcode's appintentsmetadataprocessor extracts at build time; the SwiftPM build does not run it yet (needs the compiler's const-values output). Tracked under TASK-27 packaging.

Update: packaging now extracts App Intents metadata (scripts/appintents-metadata.sh: standalone HandyApp compile for const values, then appintentsmetadataprocessor); Handy.app/Contents/Resources/Metadata.appintents lists PerformHandyActionIntent and HandyActionEnum. Shortcuts listing it on a user's Mac (app installed in /Applications) is still to be seen.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
While engaged, pinch-holding with the other hand opens a radial palette of eight actions around the cursor; moving toward a slot fires it, releasing cancels. Slots are configurable for all apps or per app in Settings. Every catalog action is also in the menu bar's Actions menu, a Shortcuts intent and handyctl perform, with a test that fails if any surface misses one.
<!-- SECTION:FINAL_SUMMARY:END -->
