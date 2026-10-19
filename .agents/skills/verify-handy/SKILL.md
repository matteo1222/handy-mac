---
name: verify-handy
description: Prove Handy (the macOS hand-gesture menu-bar app in this repo) behaves correctly by driving the real running app without a camera, through handyctl inject/state/screenshot/camera on an isolated control socket. Use after changing gestures, the engine, output, HUD, onboarding or camera handling, before calling the work done.
---

# Verify Handy

Handy is a menu-bar app: a camera feeds hand landmarks into a gesture engine that moves the cursor,
clicks, scrolls and presses keys. You cannot wave a hand at the camera, so every proof drives the
**real running app** with landmark clips (`.lmk`) through `handyctl`, which talks to the app over a
local control socket. Output can be recorded instead of posted, so verification never moves the
user's real cursor.

Headless proofs (`make verify`, `handyctl replay`) check the engine. This skill checks the app:
the engine plus HUD, output driver, camera states and windows, as a user would meet them.

## Launch

```bash
eval "$(scripts/verify/launch.sh)"
```

Builds `.build/app/Handy.app`, starts it from its executable on its own socket
(`/tmp/handy-verify-<pid>.sock`), waits until it answers, and exports `HANDY_CONTROL_SOCKET` so
every later `handyctl` call in this shell reaches that instance. It refuses to start a second
instance. State and logs live in `.build/verify/`.

The instance shares UserDefaults with an installed Handy (same bundle id): on a machine that never
finished the tutorial, the onboarding window opens at launch. That is expected.

## Doctor

```bash
.build/debug/handyctl state
```

Worth driving when it prints `"ok": true` with the expected `version`, `stopHotKey: "⌃⌥⌘H"` and
`camera: "off"`. If it fails, read `.build/verify/handy.log`, run cleanup, launch again.
`.build/debug/handyctl doctor` reports build, permission and camera facts for the machine.

## Drive

All commands print JSON and exit non-zero on failure.

| Goal | Command |
| --- | --- |
| Make a clip | `.build/debug/handyctl synth --script "openPalm:700ms pinch:150ms openPalm:400ms" -o .build/verify/clip.lmk` (poses and grammar: `handyctl synth --help`) |
| Run it through the app, recording output | `.build/debug/handyctl inject .build/verify/clip.lmk --sink record` |
| Watch the HUD animate while it runs | add `--realtime` |
| Turn tracking on / off | `.build/debug/handyctl send start` / `send stop` |
| Read engine, HUD, last events, output counts | `.build/debug/handyctl state` |
| Stage camera conditions | `.build/debug/handyctl camera inUse` (also `disconnected`, `resumed`, `dark`, `bright`, and `fix` to click the HUD's one-click fix) |
| Render Handy's own views | `.build/debug/handyctl screenshot <hud\|hud-gallery\|cursor-ring\|settings\|onboarding\|onboarding:<step>> out.png` |
| Check capture exclusion of Handy's windows | `.build/debug/handyctl windows` |

Committed clips for every gesture live in `Tests/HandyReplayTests/Fixtures/gestures/`; negative
cases in `.../scenarios/`. Their recipes are in `scripts/fixtures.sh`.

`inject` replaces camera input for the duration of the clip and resets the session afterwards,
so clip and camera timestamps never mix. `--sink live` posts real input and needs Accessibility;
use it only when the user asked for real input.

## Evidence

Save proofs under `.build/verify/evidence/` (kept by cleanup):

```bash
.build/debug/handyctl inject Tests/HandyReplayTests/Fixtures/gestures/doubleClick.lmk > .build/verify/evidence/double-click.json
.build/debug/handyctl screenshot hud .build/verify/evidence/hud.png
```

Proof standards:
- Drive the real path: `inject` into the running app, not engine unit calls.
- Capture the action and the resulting state: `injected.events` (what the engine decided),
  `injected.actions` (what would reach macOS) and `state` (HUD, mode) after the run.
- Check the side effect, not only the HUD: a click is a `mouseDown`/`mouseUp` pair with the right
  `clickCount`; a key is a `keyStroke`; a scroll has `began`/`changed`/`ended` phases.
- `--sink record` posts nothing (verify: `state.output.posted` does not rise). Screenshots are
  rendered offscreen with a solid pill instead of Liquid Glass; check glass on screen.

## Cleanup

```bash
scripts/verify/cleanup.sh
```

Stops only the instance `launch.sh` started (by its PID), retires its socket and keeps
`.build/verify/evidence/`. Never `pkill Handy`: that would stop the user's own copy.

## Feature map

`features/README.md` lists what a user can do and how to prove each one. When you change a
feature, prove it from the map; when you add one, add its file. `$pstack maintain-verification-skill`
keeps the map honest.
