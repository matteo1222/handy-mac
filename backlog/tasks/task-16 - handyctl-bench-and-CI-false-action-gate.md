---
id: TASK-16
title: handyctl bench and CI false-action gate
status: To Do
assignee: []
created_date: '2026-10-19 15:38'
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
- [ ] #1 handyctl bench reports latency, jitter (px RMS) and false actions per hour against a stored baseline as JSON
- [ ] #2 CI runs bench on the regression corpus and fails when false actions rise
- [ ] #3 Baseline updates require an explicit command and show the before/after diff
<!-- AC:END -->
