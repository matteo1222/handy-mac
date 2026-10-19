---
id: TASK-18
title: verify-handy project skill
status: Done
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-19 17:20'
labels:
  - ready-for-agent
milestone: m-1
dependencies:
  - TASK-6
documentation:
  - docs/prd.md
  - docs/spec.md
priority: medium
type: chore
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Agents need a repeatable way to prove app behaviour. Generate it with pstack's create-verification-skill once inject and the record sink exist, and keep it fresh as features land.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 verify-handy skill drives the running app via handyctl (synth, inject, state, screenshot) and is proven once before hand-over
- [x] #2 Linked from the agent instructions file
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Interview the repo: menu-bar app; drive via handyctl over the control socket; evidence as JSON and offscreen PNGs.
2. Isolation: HANDY_CONTROL_SOCKET override; scripts/verify/launch.sh starts the bundle's executable on its own socket and records its PID; cleanup.sh stops only that PID and keeps .build/verify/evidence.
3. .agents/skills/verify-handy/SKILL.md (launch, doctor, drive, evidence, cleanup) + features/ map (clutch and HUD, pointer, scroll, keys, safety, camera problems, onboarding).
4. AGENTS.md links it; CLAUDE.md points to AGENTS.md.
5. Prove once end to end.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Proven: launch.sh started an instance on /tmp/handy-verify-<pid>.sock while another Handy kept running; doctor ok (0.1.0, ⌃⌥⌘H, camera off); inject of gestures/click recorded mouseDown/mouseUp clickCount 1 with posted 0; cleanup stopped only the verify PID (the other instance still running) and .build/verify/evidence/click.json survived. Maintain with $pstack maintain-verification-skill as features land.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Agents now have a verify-handy skill that launches an isolated Handy, drives it with landmark clips through handyctl, captures JSON and PNG evidence, and cleans up only what it started. A feature map covers seven user-facing areas. AGENTS.md links it.
<!-- SECTION:FINAL_SUMMARY:END -->
