<p align="center">
  <a href="https://github.com/matteo1222/handy-mac/actions/workflows/verify.yml"><img alt="verify" src="https://img.shields.io/github/actions/workflow/status/matteo1222/handy-mac/verify.yml?branch=main&style=flat-square&label=verify" /></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple&logoColor=white" />
  <a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" /></a>
</p>

> Handy is in alpha. Builds are unsigned until the first notarized release.

# Handy

Handy lets you drive your Mac with your hands in front of the built-in camera.

Hold an open palm toward the camera to engage, move your hand to point, pinch to click, raise two fingers to scroll. Thumbs up presses Return, a flick presses an arrow key, a quick palm swipe changes Spaces, and a shaka toggles dictation. Press ⌃⌥⌘/ for the full [gesture list](docs/prd.md#prd--default-gesture-vocabulary).

Nothing happens until you engage, and a fist, a lowered hand or a glance away lets go. The goal is under one accidental action per hour, measured on every change by a [false-action bench](docs/spec.md).

Frames never leave your Mac: Handy works in memory on hand landmarks only, and its one network call is the update check.

## Getting started

Handy needs macOS 14 or newer and a camera. Building it needs Xcode 26 (Swift 6.2).

```bash
git clone https://github.com/matteo1222/handy-mac
cd handy-mac
scripts/run-app.sh
```

This builds Handy, puts it in your menu bar and opens the tutorial. Allow the camera, then Accessibility so Handy can move the pointer and press keys.

Stop Handy from anywhere with ⌃⌥⌘H, or cross both hands for a second.

See the [product doc](docs/prd.md) for the design and the [spec](docs/spec.md) for how it works.

## Development

Run every check before submitting changes:

```bash
make verify
```

It formats, lints, builds, runs the tests, replays the gesture fixtures, runs the false-action bench and packages the app. A fast subset runs as a pre-commit hook.

`handyctl` drives the running app and tests gestures without a camera. This synthesizes an engage and a pinch, then replays it through the gesture engine, which reports a click:

```bash
.build/debug/handyctl doctor
.build/debug/handyctl synth --script "openPalm:600ms pinch:150ms openPalm:300ms" -o click.lmk
.build/debug/handyctl replay click.lmk
```

Read [AGENTS.md](AGENTS.md) for repository rules, and [SECURITY.md](SECURITY.md) to report a vulnerability privately.

## License

MIT. Bundled models and training data have their own licences, listed in [NOTICES.md](NOTICES.md).
