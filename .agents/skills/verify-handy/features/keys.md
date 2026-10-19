# Keys: thumbs and flicks

While not engaged, a thumbs-up held 500 ms presses Return and a thumbs-down presses Esc; a quick
wrist flick with the index pointing presses an arrow key.

## Sub-features

- One-shot poses (classifier, 0.9 confidence, 0.3 margin over no-gesture, 500 ms hold), with a
  progress arc in the HUD naming the binding.
- Flicks up, down, left, right (wrist-relative, from rest, confirmed after 100 ms).
- Keys resolve through the current keyboard layout.

## How to get to it (user POV)

Make the pose or flick while Handy is watching (not engaged).

## Driving it with handyctl

```bash
F=Tests/HandyReplayTests/Fixtures
.build/debug/handyctl inject $F/gestures/thumbsUp.lmk     # one keyStroke returnKey
.build/debug/handyctl inject $F/gestures/flickLeft.lmk    # one keyStroke left
.build/debug/handyctl inject $F/scenarios/thumbsUpWhileEngagedDoesNothing.lmk   # no keyStroke
```

Proof: exactly one `keyStroke` action with the expected key; `state.hud.detail` names it.

## Gotchas

- Holding the pose longer fires once; relax the hand to fire again.
- After disengaging, one-shots wait until the hand relaxes.
