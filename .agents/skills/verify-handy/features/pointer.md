# Pointer: move, click, drag

While engaged, the palm moves the cursor like a trackpad; a thumb-index pinch tap clicks, a
thumb-middle pinch tap right-clicks, a held or moved pinch drags, two quick taps double-click.

## Sub-features

- Relative cursor motion with acceleration and 150 ms edge stick.
- Left click, right click, double click (click count 2), drag and drop.
- Cursor frozen from pinch onset; ring around the cursor tightens as the pinch closes.

## How to get to it (user POV)

Engage, then move the open hand; pinch to click.

## Driving it with handyctl

```bash
F=Tests/HandyReplayTests/Fixtures
.build/debug/handyctl inject $F/gestures/moveCursor.lmk     # actions: moveCursor ... stays on screen
.build/debug/handyctl inject $F/gestures/click.lmk          # mouseDown + mouseUp, clickCount 1
.build/debug/handyctl inject $F/gestures/doubleClick.lmk    # clickCount 1 pair, then clickCount 2 pair
.build/debug/handyctl inject $F/gestures/drag.lmk           # mouseDown, mouseDragged..., mouseUp
.build/debug/handyctl inject $F/scenarios/nearMissPinchNeverClicks.lmk   # no mouseDown
.build/debug/handyctl screenshot cursor-ring .build/verify/evidence/cursor-ring.png
```

Proof: count `injected.actions` by kind; positions stay inside the display bounds.

## Gotchas

- Recorded positions start at the centre of the main display (a virtual cursor).
- `--sink live` without Accessibility shows "Accessibility permission needed" in the HUD and
  `state.output.refused` rises; that is the intended failure path.
