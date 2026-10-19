# Scroll

Index and middle fingers up, held 150 ms, scrolls: the cursor parks, content follows the hand, and
releasing coasts with momentum.

## Sub-features

- Vertical and horizontal pixel scrolling with trackpad phases.
- Momentum decaying 0.92 per frame after release.
- HUD shows Scrolling.

## How to get to it (user POV)

Engage, raise two fingers, move up or down.

## Driving it with handyctl

```bash
.build/debug/handyctl inject Tests/HandyReplayTests/Fixtures/scenarios/scrollMomentum.lmk \
  > .build/verify/evidence/scroll.json
```

Proof: `injected.actions` holds `scroll` actions with phases `began`, several `changed`, `ended`,
then `momentum` with `momentumStart: true` on the first; no `moveCursor` while scrolling.

## Gotchas

- A two-finger pose shorter than 150 ms never scrolls (`scenarios/briefScrollPoseDoesNotScroll`).
