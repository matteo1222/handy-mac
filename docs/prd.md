# Product requirements (PRD)

_Part of the [Handy](../README.md) planning docs · as of Oct 19, 2026_

## PRD — problem, users, goals

**Handy lets you drive a Mac with your hands in front of the built-in camera, covering everyday trackpad and keyboard actions with under 1 accidental action per hour.**

### Problem

People want to control a Mac without touching it: from the couch, while cooking, while presenting, or to rest a strained wrist. Today's options either jitter and misfire (webcam demos), use the head instead of the hands (Head Pointer), or cover only the mouse and a few shortcuts.

### Target users

1. **Distance user** — Mac on a TV or external display, 1–3 m away; wants browse, play/pause, scroll, switch apps.
2. **Hands-busy user** — cooking, drawing, lab or workshop; occasional scroll, next, back.
3. **Presenter** — slides, demos; needs zero accidental cursor movement.
4. **Wrist-break / RSI user** — at the desk, wants to alternate between trackpad and hands for an hour at a time.

### Goals

- Cover the 90% of daily trackpad actions: point, click, right-click, drag, scroll, zoom, swipe between spaces, Mission Control.
- Cover keyboard intent without an air keyboard: navigation keys, any shortcut, a gesture-opened command palette, and dictation for text.
- Feel as trustworthy as a trackpad: nothing fires unless you meant it.
- Fully on-device; no frames stored or sent.

### Non-goals (v1)

- Typing prose by finger in mid-air (research shows \~11–16 WPM; dictation is faster).
- Windows/Linux, multi-person control, depth cameras.
- Gaming-grade precision (pixel-perfect selection in design tools).
- Voice assistant or AI-agent features.

### Success metrics

| Metric | Target | How measured |
| --- | --- | --- |
| Accidental actions (fired, then undone or reported) | < 1 per hour of active use | In-app "that was wrong" hotkey + undo detection |
| Time to first successful click from install | < 3 minutes median | Onboarding funnel (local, opt-in) |
| Fitts' law pointing throughput | ≥ 2 bits/s at 0.6 m | ISO 9241-411 multi-directional tapping task |
| Motion-to-photon latency | ≤ 80 ms p95 | High-speed camera rig |
| Gesture recognition accuracy | ≥ 97% on held-out users; false-positive rate < 0.5% on "no gesture" clips | HaGRID test split + our own recordings |
| Day-7 retention of beta users | ≥ 40% | Opt-in telemetry |
| CPU while tracking (M1) | < 15% of one core | Instruments |

## PRD — UX principles and key experiences

**The UX bar is "trust": the user always knows whether Handy is listening, what it is about to do, and how to undo it.**

### Principles

1. **Nothing fires uninvited.** Control is off until an explicit engage (open palm toward camera for 300 ms, or a hotkey). It disengages on fist, hand leaves frame, or face turns away from screen.
2. **Show intent before action.** Every click is previewed: the cursor ring tightens as fingers approach; a one-shot gesture shows a progress arc before it fires; the HUD names the action ("⌘⇥ Switch app").
3. **Low arms, small motions.** Default pointing zone sits at chest height with elbow on desk. Relative (trackpad-like) mode is default; absolute mode is optional for distance use.
4. **One hand does the basics.** Two-hand gestures are reserved for rare or protective actions (stop tracking).
5. **Undo is a gesture away.** A dedicated "oops" gesture sends ⌘Z and logs a false-positive sample for tuning.
6. **Feel native.** Menu-bar app, SF Symbols, system accent colour, respects Reduce Motion, works with VoiceOver, never steals focus.

### Key experiences

- **First run (≤ 3 min):** permission sheets for Camera and Accessibility with live "why" previews → camera framing check ("move left, more light") → 60-second interactive tutorial: engage, move, click a big target, scroll a list, disengage. The tutorial doubles as calibration (hand size, pinch distance, comfortable reach box).
- **Ambient HUD:** a small floating pill (top centre, click-through, hidden from screen recording) shows state: Off · Watching · Engaged · Dragging · Scrolling, plus the last fired action. A translucent hand glyph replaces the cursor while engaged.
- **Command palette:** "pinch-hold with left hand" opens a radial menu of 8 user-chosen actions around the cursor; flick toward one to fire. This is how the long tail of keyboard shortcuts is reached without memorising 30 poses.
- **Dictation handoff:** a gesture starts macOS Dictation in the focused field; the same gesture ends it.
- **Cheat sheet:** a hotkey or "show palm + hold 2 s" shows every gesture and its current binding for the frontmost app.
- **Settings:** per-gesture sensitivity slider with a live meter, per-app bindings, training a custom gesture from 5 takes, presets (Desk, Couch, Presenter).
- **Failure states, said plainly:** "Too dark", "Camera in use by Zoom", "Accessibility permission removed", each with a one-click fix.

## PRD — default gesture vocabulary

**Twelve default gestures cover the trackpad; the keyboard is covered by four keys-as-gestures, a command palette and dictation.** All are rebindable; right hand = pointer hand by default (mirrored for left-handed users).

### Trackpad layer (pointer hand, while engaged)

| Gesture | Action | Why this design |
| --- | --- | --- |
| Open palm, held 300 ms | Engage | Explicit clutch; a resting or typing hand never qualifies |
| Fist, or hand leaves frame | Disengage, park cursor | Natural "let go" |
| Move open hand | Move cursor (relative, palm centroid) | Palm is far steadier than a fingertip |
| Thumb–index pinch tap | Left click | Same confirm gesture as Vision Pro; tiny effort |
| Thumb–middle pinch tap | Right click | Distinct finger, same motion |
| Pinch and hold, then move | Drag | Hold > 250 ms or motion > 8 px starts drag |
| Two quick pinches | Double click | Interval < 350 ms, cursor frozen in between |
| Index + middle up, move vertically / horizontally | Scroll | Cursor parks while scrolling; momentum on release |
| Two-hand pinch, spread / close | Zoom (⌘+ / ⌘− or magnify event) | Mirrors trackpad pinch |
| Open-palm swipe left / right | Previous / next Space | Swipe needs > 25% of frame width in < 400 ms |
| Open-palm swipe up | Mission Control | Matches 3-finger swipe up |
| Both hands crossed, held 1 s | Stop tracking entirely | Hard to do by accident |

### Keyboard layer

| Need | How | Default |
| --- | --- | --- |
| Navigation keys | Pointing-hand "flick" (index finger only) in 4 directions while not engaged | ↑ ↓ ← → |
| Confirm / cancel | Thumbs-up / thumbs-down held 500 ms | Return / Esc |
| Any shortcut (long tail) | Command palette: other-hand pinch-hold → radial menu of 8 slots, per app | e.g. ⌘T, ⌘W, ⌘⇥, Space, Tab, ⌘C/⌘V |
| Text | Dictation gesture (shaka) toggles macOS Dictation | — |
| Modifier-click (⌘-click, ⇧-click) | Hold other hand in a fist while clicking = ⌘; flat hand = ⇧ | Off by default |
| Last resort | Opens macOS Accessibility Keyboard, clicked by pinch | Palette slot |

### Gestures we deliberately avoid

- Fingertip pointing as the cursor source (wobbles during clicks).
- Number-of-fingers poses for distinct actions (confusable at distance and under occlusion).
- Anything that needs the arm above the shoulder.

## PRD — requirements and release plan

**P0 is a trustworthy mouse plus four keys; everything else waits until the false-action rate is proven.**

| ID | Requirement | Priority |
| --- | --- | --- |
| R1 | Engage / disengage clutch with attention gate (face toward screen) | P0 |
| R2 | Cursor move, left/right click, drag, double click, scroll with momentum | P0 |
| R3 | Live HUD with state, action preview and last action; hidden from screen capture | P0 |
| R4 | Guided onboarding + calibration in ≤ 3 min | P0 |
| R5 | Menu-bar toggle + global hotkey to stop instantly | P0 |
| R6 | Arrow keys, Return, Esc by gesture | P0 |
| R7 | Camera picker incl. external webcam and Continuity Camera; graceful camera loss | P0 |
| R8 | Undo ("oops") gesture that also records a false-positive sample | P1 |
| R9 | Command palette with 8 per-app slots | P1 |
| R10 | Spaces swipe, Mission Control, two-hand zoom | P1 |
| R11 | Dictation toggle gesture | P1 |
| R12 | Per-gesture sensitivity + presets (Desk, Couch, Presenter) | P1 |
| R13 | Train custom gesture from 5 takes; bind to any shortcut / app / Shortcuts.app action | P2 |
| R14 | Absolute pointing mode for 2–3 m distance | P2 |
| R15 | Dwell click for users who cannot pinch | P2 |
| R16 | Export / import settings | P2 |

**Non-functional:** macOS 14+, Apple Silicon first (Intel best-effort); ≤ 80 ms p95 motion-to-photon; < 15% of one core and < 150 MB RAM while tracking; zero network calls in the default build; signed and notarized; auto-update via Sparkle.

### Release plan

1. **Week 0 — Pawvis bake-off (2 days).** Use Pawvis daily; log every misfire and annoyance. Decide fork vs greenfield (see Spec).
2. **Weeks 1–3 — Perception spike.** Vision backend vs fasthands/Core ML backend on the same recorded clips: latency, jitter, landmark accuracy in dim light. Exit: one backend meets 30 fps at < 10 ms inference.
3. **Weeks 4–7 — Alpha (P0).** Gesture engine, clutch, HUD, onboarding. Exit: < 3 accidental actions/hour on 5 internal users.
4. **Weeks 8–11 — Beta (P1).** Palette, keys, dictation, presets, undo-as-training. Exit: < 1 accidental action/hour, Fitts' throughput ≥ 2 bits/s, 20 external testers.
5. **Week 12+ — 1.0.** Public release, then P2 by demand.
