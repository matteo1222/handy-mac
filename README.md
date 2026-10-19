# Handy

Camera hand-gesture control for macOS: drive the trackpad and keyboard with your hands in front of the built-in camera, with under 1 accidental action per hour. Working name.

## Docs

| Doc | What is in it |
| --- | --- |
| [docs/research.md](docs/research.md) | Existing apps (incl. Pawvis), papers and techniques we build on |
| [docs/prd.md](docs/prd.md) | Problem, users, goals, UX principles, gesture vocabulary, requirements, release plan |
| [docs/spec.md](docs/spec.md) | Architecture, gesture engine, OS integration, tech stack, agent workflow, evaluation, risks |
| [docs/sources.md](docs/sources.md) | Every source cited |

## TL;DR — use it, or build it?

**Try [Pawvis](https://github.com/alexandriax/pawvis) first; it is the only open-source app that already does most of this natively on macOS. But it is not "well supported" yet, so if you want top-notch UX you can rely on, build — by forking its MIT core, not from scratch.**

- **What Pawvis already does:** native Swift menu-bar app, Apple Vision hand tracking (21 joints), palm-driven cursor, finger-dip click / right-click / drag / scroll, dwell click, custom and user-trained gestures bound to any keyboard shortcut, app launch, window snapping or shell command, per-app bindings. Signed, notarized, macOS 14+, MIT license.
- **Why it is not a safe "just use it":** as of today the repo shows 5 stars, 0 forks and a single maintainer (316 commits). No community, no track record on bug fixes, and its newest energy goes into voice and AI-agent hand-off rather than input polish.
- **Everything else** is either a Python/MediaPipe demo (not a product), Google's Project Gameface (face and head, not hands), or macOS's built-in Head Pointer (head, not hands).

**Recommendation:** spend 30 minutes with Pawvis this week. If cursor feel, false-click rate and shortcut gestures satisfy you, stop and use it (and maybe contribute). If not, the docs above are the PRD and spec for **Handy** (working name): a focused, keyboard-and-trackpad replacement that reuses Pawvis's proven ideas and adds what it lacks — a fast onboarding, an explicit clutch, a gesture command palette and a measurable quality bar.

## Status

Planning. Next step: Week 0 Pawvis bake-off, then scaffold the Swift packages, the fence and `handyctl` (see [spec](docs/spec.md)).
