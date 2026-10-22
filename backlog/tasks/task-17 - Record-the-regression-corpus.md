---
id: TASK-17
title: Record the regression corpus
status: In Progress
assignee: []
created_date: '2026-10-19 15:38'
updated_date: '2026-10-22 02:40'
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
- [x] #3 Corpus stored in the repo or a documented location that bench and CI can read
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Tooling ready (agent side): menu Record Corpus Session… runs a guided ~9 min protocol per participant x lighting x distance (all 23 gestures plus 3 m 40 s of typing, talking with hands, drinking and video-call posture), writes labelled landmark streams (numbers only) to <data>/Corpus/ with participant, lighting, distance, skin tone and background in the header; output is recorded, not posted, during the session. Three participants over the 4 x 3 grid give over 2 h of no-gesture footage. Copy the files into corpus/ (or a documented store) and run: handyctl bench corpus -- recall per gesture is scored from the labels. Recording people is the remaining human work.

Public real-hand corpus (2026-10-22): scripts/fetch-corpus.sh turns 6 openly licensed Wikimedia Commons videos (video call, podcasts, interviews; CC0, public domain, CC BY) into corpus/public/*.lmkz: 3.4 h of no-gesture footage, many people, skin tones, distances and backgrounds, landmarks only (16 MB, LZFSE-compressed .lmkz, read by bench and CI). First run measured 261 false actions/hour on real hands against 0.99 on the synthetic corpus. Two fixes: a plausibility gate drops hands whose fingers reach past 1.5 hand scales (MediaPipe inventing hands at a frame edge), and palmFacing is now negative when the back of the hand faces the camera (hands resting flat on a leg engaged). Real footage now 3.5/h (8 engages at a frame edge in one interview, 2 thumbs-ups in a video call); synthetic + real gate baseline 2.41/h. Still open: AC1 needs recorded laptop-camera sessions (Record Corpus Session) across 4 lighting conditions and 3 distances with labelled gestures; AC2's footage is mostly talking and video calls, with little typing or drinking.
<!-- SECTION:NOTES:END -->
