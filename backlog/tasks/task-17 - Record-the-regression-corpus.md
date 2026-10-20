---
id: TASK-17
title: Record the regression corpus
status: To Do
assignee: []
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 18:39'
labels:
  - ready-for-human
milestone: m-1
dependencies:
  - TASK-3
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: task
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Bench numbers only mean something on varied, labelled data, and recording people is human work. Includes the no-gesture footage that measures accidental actions.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Landmark streams (no video) with labels from multiple people × 4 lighting conditions × 3 distances (0.5, 1.5, 3 m) across skin tones and backgrounds
- [ ] #2 At least 2 h of no-gesture footage: typing, talking with hands, drinking, video calls
- [ ] #3 Corpus stored in the repo or a documented location that bench and CI can read
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Tooling ready (agent side): menu Record Corpus Session… runs a guided ~9 min protocol per participant x lighting x distance (all 23 gestures plus 3 m 40 s of typing, talking with hands, drinking and video-call posture), writes labelled landmark streams (numbers only) to <data>/Corpus/ with participant, lighting, distance, skin tone and background in the header; output is recorded, not posted, during the session. Three participants over the 4 x 3 grid give over 2 h of no-gesture footage. Copy the files into corpus/ (or a documented store) and run: handyctl bench corpus -- recall per gesture is scored from the labels. Recording people is the remaining human work.
<!-- SECTION:NOTES:END -->
