# Settings, dictation and the cheat sheet

Settings holds presets, per-gesture sensitivity with live meters, palette slots, camera, Dictation
status and Open at login. Shaka toggles Dictation. ⌃⌥⌘/ or the other hand's open palm for 2 s shows
every gesture and its current binding.

## Sub-features

- Presets Desk / Couch / Presenter; sensitivity sliders with live meters; versioned `settings.json`.
- Dictation: shaka sends the user's Dictation shortcut (symbolic hotkey 164); if Dictation is off the
  HUD offers "Open Keyboard Settings".
- Cheat sheet: hotkey, menu item, or the other hand's open palm held 2 s.
- Open at login (SMAppService), off by default.

## How to get to it (user POV)

Menu bar → Settings… (⌘,); menu bar → Cheat Sheet; make a shaka while watching.

## Driving it with handyctl

```bash
.build/debug/handyctl inject Tests/HandyReplayTests/Fixtures/gestures/dictation.lmk   # modifierDoubleTap or keyStroke
.build/debug/handyctl screenshot settings .build/verify/evidence/settings.png
.build/debug/handyctl screenshot cheat-sheet .build/verify/evidence/cheat-sheet.png
cat .build/verify/data/settings.json   # only after a setting changed
```

## Gotchas

- The live meters update only while the Settings window is open on screen.
- The verification instance writes settings into `$HANDY_DATA_DIR`, never the user's.
