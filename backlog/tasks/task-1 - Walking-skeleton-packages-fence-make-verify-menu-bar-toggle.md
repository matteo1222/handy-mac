---
id: TASK-1
title: 'Walking skeleton: packages, fence, make verify, menu-bar toggle'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-19 15:38'
updated_date: '2026-10-20 15:39'
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
- [x] #1 SwiftPM-only build (no Xcode project, no Tuist): library packages plus a Handy executable target packaged into an .app by scripts/package-app.sh; all build with Swift 6 language mode, strict concurrency and warnings as errors
- [x] #2 A HandyCore import of AppKit, AVFoundation or Vision fails to compile; SwiftLint custom rules reject Date(), DispatchQueue, Task.sleep and CGEvent in HandyCore
- [x] #3 make verify runs format, lint, build and tests; the same command runs in CI on a macOS runner and in a lefthook pre-commit (fast subset)
- [x] #4 Every lint suppression must be listed in DEBT.md with a reason or CI fails
- [ ] #5 Menu-bar item toggles Off/Watching; a global hotkey returns to Off from any state
- [x] #6 handyctl doctor prints build, permission and version info as JSON and exits non-zero on failure
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Root SwiftPM package: HandyCore, HandyPerception, HandyOutput, HandyReplay, HandyControl, HandyApp libraries; Handy and handyctl executables; tools 6.2, Swift 6 mode, warnings as errors.
2. Fence: FenceCheck build-tool plugin on HandyCore fails the build on banned imports; SwiftLint custom rules; scripts/prove-fence.sh proves both.
3. DEBT.md + scripts/check-debt.py.
4. Makefile verify, lefthook pre-commit fast subset, GitHub Actions macOS workflow.
5. scripts/package-app.sh builds the menu-bar .app (LSUIElement) without Tuist; Off/Watching toggle; Carbon global hotkey ⌃⌥⌘H -> Off.
6. handyctl doctor; handyctl state/send over a Unix control socket to prove the app.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Dropped Tuist at the user's request: the app is a SwiftPM executable packaged by scripts/package-app.sh. Fence proven by scripts/prove-fence.sh (part of make verify). make verify green locally in ~11 s; lefthook installed and runs make verify-fast. Not yet proven: the GitHub Actions run (nothing pushed) and a physical ⌃⌥⌘H keypress (the terminal lacks Accessibility to synthesize it; handyctl state reports the hotkey registered and stop-from-every-mode is unit tested).

CI green on GitHub-hosted macos-26 (run 39449849356, main 08a619e): make verify passes in CI, and lefthook runs the fast subset pre-commit. The billing block was the private-repo Actions budget ($0, usage blocked); the repo is now public, so standard runners are free. Remaining: AC5 needs a physical press of the stop hotkey.
<!-- SECTION:NOTES:END -->
