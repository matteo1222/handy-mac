---
id: TASK-1
title: 'Walking skeleton: packages, fence, make verify, menu-bar toggle'
status: To Do
assignee: []
created_date: '2026-10-19 15:38'
labels:
  - ready-for-agent
milestone: m-0
dependencies: []
documentation:
  - docs/prd.md
  - docs/spec.md
priority: high
type: feature
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Handy is greenfield (decision-1), so nothing exists yet. Every later ticket needs the five-package layout (HandyCore, HandyPerception, HandyOutput, HandyApp, HandyReplay), the fence that keeps the best practice the easiest path, and one verify entry point that agents and CI share. The thinnest demoable slice is a menu-bar app that toggles Off/Watching and stops instantly from a global hotkey (R5). See spec: architecture, tech stack, agent workflow.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Tuist-generated app target plus SwiftPM packages build with Swift 6 language mode, strict concurrency and warnings as errors
- [ ] #2 A HandyCore import of AppKit, AVFoundation or Vision fails to compile; SwiftLint custom rules reject Date(), DispatchQueue, Task.sleep and CGEvent in HandyCore
- [ ] #3 make verify runs format, lint, build and tests; the same command runs in CI on a macOS runner and in a lefthook pre-commit (fast subset)
- [ ] #4 Every lint suppression must be listed in DEBT.md with a reason or CI fails
- [ ] #5 Menu-bar item toggles Off/Watching; a global hotkey returns to Off from any state
- [ ] #6 handyctl doctor prints build, permission and version info as JSON and exits non-zero on failure
<!-- AC:END -->
