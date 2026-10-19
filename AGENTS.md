# Agent guide

Handy is a macOS menu-bar app that turns hand landmarks from the camera into pointer, scroll and key
input. SwiftPM only; no Xcode project. Docs: [docs/spec.md](docs/spec.md), [docs/prd.md](docs/prd.md).

## Commands

| Need | Command |
| --- | --- |
| Everything CI checks | `make verify` (format, lint, debt ledger, build, tests, fixture recipes, false-action bench, fence proof, app bundle) |
| Fast pre-commit subset | `make verify-fast` (lefthook runs it) |
| Build and launch the app | `scripts/run-app.sh` |
| Headless engine proof | `.build/debug/handyctl replay <clip.lmk> --expect <events.json>` |
| Regenerate fixtures after an engine change | `scripts/fixtures.sh regen`, then review the git diff of every `.events.json` |
| False actions, jitter, lag | `.build/release/handyctl bench corpus` (baseline `bench/baseline.json`) |

## Proving app behaviour

Use the [verify-handy](.agents/skills/verify-handy/SKILL.md) skill: it launches an isolated instance
and drives it with `handyctl inject`, `state`, `camera` and `screenshot`, without a camera.

## Rules the build enforces

- HandyCore imports no platform frameworks and reads no clock; time comes only from frame timestamps.
- `CGEvent` lives only in HandyOutput.
- Every lint suppression or `nonisolated(unsafe)` is listed in [DEBT.md](DEBT.md).
- Every `Gesture` case has a replay fixture.
