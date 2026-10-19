# Clutch and HUD

Control is off until the user holds an open palm toward the camera for 300 ms; a fist, a lost hand,
looking away or ⌃⌥⌘H lets go. A pill at the top centre always says what Handy is doing.

## Sub-features

- Open palm held 300 ms engages, with a progress ring while arming.
- A curl during arming aborts; a fist or a lost hand disengages.
- Menu-bar toggle (Start Watching / Stop) and the global stop hotkey ⌃⌥⌘H.
- HUD: Off, Watching, Hold open palm, Engaged, Dragging, Scrolling, last action, problems.
- HUD and cursor ring are excluded from screen capture.

## How to get to it (user POV)

Click the menu-bar hand, choose Start Watching, raise an open palm.

## Driving it with handyctl

```bash
.build/debug/handyctl inject Tests/HandyReplayTests/Fixtures/gestures/engage.lmk
.build/debug/handyctl inject Tests/HandyReplayTests/Fixtures/scenarios/abortedArm.lmk
.build/debug/handyctl send start && .build/debug/handyctl state   # mode watching, HUD Watching
.build/debug/handyctl screenshot hud-gallery .build/verify/evidence/hud-gallery.png
.build/debug/handyctl windows   # every Handy window: "excludedFromCapture": true
```

Proof: `engage` gives `modeChanged arming` then `engaged` 300 ms later; `abortedArm` returns to
`watching` without `engaged`. After `send start`, `state.hud.title` is `Watching`.

## Gotchas

- After an inject the session resets, so `state.mode` returns to the mode before the inject.
- The hotkey cannot be pressed from a sandboxed shell without Accessibility; `state.stopHotKey`
  confirms it registered, and stop-from-every-mode is unit tested.
