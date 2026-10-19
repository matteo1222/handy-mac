---
id: TASK-12
title: Pose classifier v0 with thumbs-up/down → Return/Esc
status: In Progress
assignee: []
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 16:56'
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
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Keyboard intent needs static poses that never fire by accident. A small MLP over normalised joints plus curl angles with an explicit no-gesture class gives one-shots a confidence margin. Thumbs-up/down is the first one-shot to exercise it end to end (part of R6).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 MLP trained on HaGRID landmarks, shipped as a Core ML model under 1 MB
- [x] #2 One-shot fires only when confidence > 0.9 for the hold time and exceeds the no-gesture class by 0.3, and only while not Engaged
- [x] #3 Thumbs-up / thumbs-down held 500 ms post Return / Esc with a progress arc in the HUD
- [x] #4 Keyboard events use key codes resolved through the current layout
- [x] #5 Per-gesture precision/recall and no-gesture false-positive rate reported on a held-out split
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. PoseFeatures: 47-d vector (wrist-relative, scale- and rotation-normalised joints, mirrored to a right hand, plus the removed in-plane angle and per-finger reach).
2. MLP (one tanh hidden layer, softmax) in pure Swift in HandyCore; weights generated as Swift by handyctl train-classifier (decision-2).
3. OneShotRecognizer: confidence > 0.9, margin over no-gesture >= 0.3, held 500 ms, only in Watching, latched until released, blocked after disengaging until the hand relaxes.
4. Action/KeyChord/Bindings + ActionRouter (thumbs up -> Return, thumbs down -> Esc); output keyStroke with key codes resolved through the current layout (UCKeyTranslate).
5. HUD progress arc names the pose and its binding.
6. Train on synthetic hands (HaGRID optional later), evaluate on a held-out split, check on real Vision landmarks from rendered emoji.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Held-out (synthetic, different seed, more noise) in docs/pose-classifier-report.json: accuracy 0.993, no-gesture one-shot false-positive rate 0.41%, one-shot recall thumbsUp 0.988 / thumbsDown 0.982 / shaka 0.969. These numbers measure fit to the synthetic generator, not real hands. Cross-domain check: real Vision landmarks from rendered 👍 🤙 ✋ 🤏 classify correctly (test). Getting there needed realistic geometry in the generator: thumbs are fists rolled ~90°, shakas range upright to sideways, curled fingers vary in knuckle bend. Review also found a synth bug (steps compared by value, so a script whose first and last steps match never advanced); fixed with a regression test. AC1 open: no HaGRID landmarks yet (needs a dataset download) and the model is pure-Swift weights rather than a Core ML file (decision-2: Core ML on the ANE is not bit-reproducible, which would break replay tests). Weights are 1,668 parameters (19 KB of source).
<!-- SECTION:NOTES:END -->
