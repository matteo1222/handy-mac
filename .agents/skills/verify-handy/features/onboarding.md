# Onboarding

A first-run tutorial that asks for permissions in context and calibrates the user's hand: start,
camera, framing, engage, move, click, scroll, let go, done.

## Sub-features

- Camera asked on Start; Accessibility asked at the click step and detected automatically.
- Live framing advice; calibration stored as numbers in Application Support/Handy/calibration.json.
- Opens on first launch and from the menu (Tutorial…).

## How to get to it (user POV)

First launch, or the menu-bar menu → Tutorial….

## Driving it with handyctl

```bash
.build/debug/handyctl screenshot onboarding .build/verify/evidence/onboarding.png
.build/debug/handyctl screenshot onboarding:click .build/verify/evidence/onboarding-click.png
```

The tutorial's progression is driven by engine events; `TutorialTests` walks it end to end with a
synthetic clip.

## Gotchas

- Finishing the tutorial writes the user's calibration and the `onboarded` default; do not finish it
  on someone else's machine just to test it.
