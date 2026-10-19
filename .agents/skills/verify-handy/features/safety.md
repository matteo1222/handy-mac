# Safety: attention gate and hard stop

Handy engages only while the user faces the screen, drops engagement when they look away, and
two crossed hands held for a second turn tracking off.

## Sub-features

- Face yaw within ±30° to engage; looking away 0.3 s while engaged returns to Watching.
- Crossed hands 1 s: Off from any state, releasing a held drag first.

## How to get to it (user POV)

Look away while engaged; cross both hands in front of the camera.

## Driving it with handyctl

```bash
F=Tests/HandyReplayTests/Fixtures
.build/debug/handyctl inject $F/scenarios/lookingAwayDisengages.lmk   # engaged, then watching
.build/debug/handyctl inject $F/gestures/hardStop.lmk                 # ... modeChanged off
.build/debug/handyctl inject $F/scenarios/hardStopWhileDragging.lmk   # dragEnded before off
```

## Gotchas

- Clips without face readings leave the gate open (the detector is treated as not running).
