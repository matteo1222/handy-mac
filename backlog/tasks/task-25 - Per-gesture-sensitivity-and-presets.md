---
id: TASK-25
title: Per-gesture sensitivity and presets
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:39'
updated_date: '2026-10-19 17:36'
labels:
  - ready-for-agent
milestone: m-2
dependencies:
  - TASK-15
documentation:
  - docs/prd.md
  - docs/spec.md
priority: medium
type: feature
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R12: Desk, Couch and Presenter need different filters and thresholds; users tune with a live meter.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Per-gesture sensitivity slider with a live meter
- [x] #2 Desk, Couch and Presenter presets store filter and threshold values
- [x] #3 Settings are versioned Codable values with decode tests on old fixtures
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. HandyCore UserSettings (version 1): preset, per-gesture sensitivity 0...1, camera ID; tolerant decoder (missing fields default, unknown values fall back, out-of-range clamped).
2. Presets Desk / Couch / Presenter store joint-filter, pointer-filter, gain and threshold values (Tuning); tuning = preset, then calibration, then sensitivity sliders.
3. SensitivityMeter: live 0...1 level per gesture family where 1 is the trigger point.
4. App: settings.json in the data folder (migrates the old UserDefaults camera choice), applied to the session on every change; Settings window gets a preset picker and a slider + live gauge per gesture.
5. Decode tests on frozen v1, sparse v1 and future-version fixtures.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Live meters update at ~10 Hz only while the settings window is open; their values are unit tested (click meter 0 open, partial near-pinch, 1 at press). Couch and Presenter values are first guesses until tuned on recorded footage.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Settings now offers Desk, Couch and Presenter presets with their own filtering and thresholds, plus a sensitivity slider per gesture with a live meter that fills where the gesture triggers. Settings are a versioned JSON file with decode tests on old and future fixtures, and the old camera preference migrates into it.
<!-- SECTION:FINAL_SUMMARY:END -->
