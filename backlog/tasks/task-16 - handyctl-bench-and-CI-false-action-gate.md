---
id: TASK-16
title: handyctl bench and CI false-action gate
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 17:18'
labels:
  - ready-for-agent
milestone: m-1
dependencies:
  - TASK-5
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: feature
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Quality must be proven on recorded data, not by feel. Bench turns the corpus into numbers and CI blocks any change that raises false actions.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 handyctl bench reports latency, jitter (px RMS) and false actions per hour against a stored baseline as JSON
- [x] #2 CI runs bench on the regression corpus and fails when false actions rise
- [x] #3 Baseline updates require an explicit command and show the before/after diff
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. NoGestureGenerator (HandyReplay): deterministic everyday-hands footage (typing, resting, talking hands with brief open palms, pointing, near-pinches, wrist turns, glances away, a second hand); streaming synth render so hours of footage never sit in memory.
2. Bench: false actions (engage, click, drag, scroll, one-shot, flick) on no-gesture footage per hour; still-hand jitter; palm-to-cursor lag by cross-correlation; gesture recall on labelled segments; per-frame processing time.
3. handyctl bench <corpus dirs> compares with bench/baseline.json; exits 1 on any false-action rise or jitter/lag/recall regression past tolerance; --update-baseline writes it and prints the before/after diff.
4. make bench (release build) is part of make verify, so CI runs it.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
First run: 352 false actions/hour on the synthetic corpus. Root causes found with a trace of preceding poses: (a) the bench counted returns to Engaged after drags/scrolls as engages (fixed); (b) an OK sign / half-pinch counted as an open palm, so it engaged (open palm now needs the thumb clear of the index); (c) flicks measured whole-hand travel, so pointing while gesturing fired arrows (now wrist-relative tip travel, from rest, confirmed after a 100 ms hold). Now 2.98/hour (3 engages, 1 drag, 2 flicks in 2 h); remaining engages are brief open palms that with natural blends last past 300 ms while facing the screen, the clutch's inherent trade-off. Proof of the gate: halving armHold raised it to 21.9/hour and make bench failed. Bench takes ~2 s for 2 h of footage. These numbers are for synthetic footage; TASK-17's human corpus is what the PRD target is measured on.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
handyctl bench turns a corpus into false actions per hour, jitter, lag and gesture recall, and gates CI against a committed baseline that changes only with --update-baseline. Its first run exposed three real false-action sources (OK-sign engaging, whole-hand flicks, bench miscounting), now fixed: synthetic no-gesture false actions went from 352 to 2.98 per hour.
<!-- SECTION:FINAL_SUMMARY:END -->
