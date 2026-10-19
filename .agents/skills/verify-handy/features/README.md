# Handy feature map

What a user can do with Handy, and how to prove each with the running app. One file per feature.

| Feature | File | Proof in one line |
| --- | --- | --- |
| Clutch and HUD | [clutch-and-hud.md](clutch-and-hud.md) | `inject gestures/engage.lmk`: events `arming`, `engaged`; HUD `Engaged` |
| Pointer: move, click, drag | [pointer.md](pointer.md) | `inject gestures/click.lmk`: one `mouseDown`/`mouseUp` pair, clickCount 1 |
| Scroll | [scroll.md](scroll.md) | `inject scenarios/scrollMomentum.lmk`: `began`, `changed`…, `ended`, `momentum` |
| Keys: thumbs and flicks | [keys.md](keys.md) | `inject gestures/thumbsUp.lmk`: one `keyStroke` Return |
| Safety: attention gate and hard stop | [safety.md](safety.md) | `inject gestures/hardStop.lmk`: last event `modeChanged off` |
| Camera problems | [camera-problems.md](camera-problems.md) | `camera inUse`: HUD "Camera in use by another app" with fix "Retry" |
| Onboarding | [onboarding.md](onboarding.md) | `screenshot onboarding`: every step renders |
| Spaces, zoom and palette | [spaces-zoom-palette.md](spaces-zoom-palette.md) | `inject gestures/palette.lmk`: one `keyStroke` ⌘T |
| Settings, dictation, cheat sheet | [settings-and-help.md](settings-and-help.md) | `inject gestures/dictation.lmk`: the user's Dictation shortcut |
