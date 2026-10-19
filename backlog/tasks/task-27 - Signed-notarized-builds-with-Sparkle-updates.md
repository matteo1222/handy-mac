---
id: TASK-27
title: 'Signed, notarized builds with Sparkle updates'
status: To Do
assignee: []
created_date: '2026-10-19 15:39'
updated_date: '2026-10-19 17:41'
labels:
  - ready-for-human
milestone: m-2
dependencies:
  - TASK-1
documentation:
  - docs/prd.md
  - docs/spec.md
priority: medium
type: chore
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
External beta testers need a trusted build. Synthesising input rules out the App Store, so Developer ID, notarization and Sparkle it is. Needs a human with the Developer ID account.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 GitHub Actions on macOS runners builds, signs with Developer ID, notarizes and staples
- [ ] #2 Sparkle appcast publishes updates; the update check is the only network call in the default build
- [ ] #3 Launch at login available and off by default
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
From TASK-21: run appintentsmetadataprocessor during packaging (needs -emit-const-values from the Swift compiler for HandyApp) so Shortcuts discovers PerformHandyActionIntent.
<!-- SECTION:NOTES:END -->
