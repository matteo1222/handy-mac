# Spaces, zoom and the command palette

Open-palm swipes switch Spaces and open Mission Control; two pinching hands zoom; the other hand's
pinch-hold opens an eight-slot palette around the cursor; every catalog action also runs from the
menu bar, Shortcuts and handyctl.

## Sub-features

- Swipe left / right / up while not engaged: the user's own Spaces and Mission Control shortcuts
  (com.apple.symbolichotkeys), falling back to ⌃← ⌃→ ⌃↑.
- Two-hand pinch spread / close while engaged: ⌘= / ⌘− per 15% change; never also clicks.
- Palette: other hand pinch-hold 400 ms while engaged, move toward a slot to fire, release cancels;
  slots per app in Settings.
- Action catalog (`NamedAction`): menu bar Actions menu, `PerformHandyActionIntent`, `handyctl perform`.

## How to get to it (user POV)

Swipe a flat hand across the camera; pinch with both hands; while engaged, pinch and hold with the
other hand.

## Driving it with handyctl

```bash
F=Tests/HandyReplayTests/Fixtures
.build/debug/handyctl inject $F/gestures/swipeLeft.lmk      # keyStroke ⌃← (Previous Space)
.build/debug/handyctl inject $F/gestures/zoomIn.lmk         # ⌘= keystrokes, no mouseDown
.build/debug/handyctl inject $F/gestures/palette.lmk        # keyStroke ⌘T (slot 0, New Tab)
.build/debug/handyctl perform missionControl --record       # keyStroke ⌃↑
.build/debug/handyctl screenshot palette .build/verify/evidence/palette.png
```

## Gotchas

- The palette uses the frontmost app's layout; during verification that is whatever app is in front.
- Shortcuts only lists the intent once App Intents metadata is extracted at packaging (TASK-27 note).
