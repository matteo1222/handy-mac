# Camera problems

When the camera is taken by another app, unplugged, not permitted or the room is too dark, Handy
pauses and says so plainly in the HUD, with a one-click fix where there is one.

## Sub-features

- Camera in use: Retry. Disconnected: Use the built-in camera. Permission off: Open Settings.
- Too dark: warning with hysteresis, no fix button.
- Settings window camera picker (built-in, external, Continuity), remembered across launches.
- Menu-bar icon changes whenever the camera is live.

## How to get to it (user POV)

Start a video call that takes the camera, unplug a webcam, or dim the room.

## Driving it with handyctl

```bash
.build/debug/handyctl send start
.build/debug/handyctl camera inUse        # state.hud: title "Camera in use by another app", fix "Retry"
.build/debug/handyctl camera fix          # camera restarts: state.camera "starting"
.build/debug/handyctl camera dark         # title "Too dark to see your hands. Add light"
.build/debug/handyctl camera bright       # back to Watching
.build/debug/handyctl screenshot settings .build/verify/evidence/settings.png
```

## Gotchas

- `camera fix` on a disconnected camera switches the saved camera to the built-in one; reset with
  `defaults delete dev.handy.Handy cameraID` if that matters.
- Real camera loss is not simulated by AVFoundation here; `camera` stages the same states the
  AVFoundation notifications produce.
