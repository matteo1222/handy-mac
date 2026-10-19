# Research

_Part of the [Handy](../README.md) planning docs · as of Oct 19, 2026_

## Landscape

Only one existing project is a real Mac product for hand control; the rest are demos or use a different body part.

| Project | What it is | Input | Mac-native app | Keyboard actions | Maturity | Use for us |
| --- | --- | --- | --- | --- | --- | --- |
| [Pawvis](https://github.com/alexandriax/pawvis) | Menu-bar app: hand-as-mouse + custom gestures + voice (beta) | Hand, Apple Vision | Yes (Swift, signed) | Any shortcut, per app | Young, 1 maintainer, 5 stars | Benchmark; fork candidate for core |
| [GestuReMote](https://github.com/samvoisin/gesture-control) | Python tool, fist toggles control mode | Hand, MediaPipe | No (OpenCV script) | Limited | Hobby, part-time | Idea: explicit clutch gesture |
| [SayHi](https://github.com/whyMiso/syncshack_2026) | Hackathon app: held pose fires an action | Hand, Apple Vision | Yes (Swift) | Screenshot, launch app | Hackathon | Ideas: 0.8 s hold-to-fire, cheat-sheet panel, pause gesture |
| Python "virtual mouse" repos ([example](https://github.com/adi-kernelx/Virtual-Mouse)) | MediaPipe + PyAutoGUI scripts | Hand, MediaPipe | No | Rare | Tutorial grade | Nothing beyond basics |
| [Project Gameface](https://blog.google/technology/ai/google-project-gameface/) (Google) | Open-source hands-free mouse | Face + head, MediaPipe | No (Windows/Android) | Bindings | Google-backed | Idea: per-user "gesture size" thresholds |
| macOS Head Pointer + Alternate Pointer Actions ([Apple](https://support.apple.com/en-ke/guide/mac-help/mchl7b437b35/10.15/mac)) | Built-in accessibility | Head + facial expressions | Built in | Clicks only | Stable | Fallback for users who cannot raise a hand |

No existing app offers all of: a reliable clutch against accidental clicks, full keyboard coverage beyond fixed shortcuts, and measured quality targets. That gap is the product.

## Research foundations

The hard parts are solved in the literature: on-device landmarks, jitter filtering, false-trigger rejection and fatigue. Our job is to combine them well.

| Area | Source | Finding | What Handy takes |
| --- | --- | --- | --- |
| Hand landmarks | [MediaPipe Hands, Zhang et al. 2020](https://arxiv.org/abs/2006.10214v1) | Palm detector + 21-landmark model; landmarks from frame N seed the crop for N+1, so the detector rarely runs | Same two-stage, track-between-frames design |
| Hand landmarks (Apple) | [VNDetectHumanHandPoseRequest](https://developer.apple.com/documentation/vision/vndetecthumanhandposerequest.md) | On-device 21-joint hand pose, macOS 11+; Swift-native `DetectHumanHandPoseRequest` on macOS 15+ | Default backend: zero model shipping, Neural Engine |
| Faster landmarks | [fasthands](https://pypi.org/project/fasthands/) | MediaPipe's models on the Apple Neural Engine via Core ML: \~0.55 ms/frame on M4 vs 3.25 ms for MediaPipe CPU; a full-hand detector more robust than the palm detector | Optional backend B if Vision's quality is not enough |
| Jitter vs lag | [1€ filter, Casiez et al. CHI 2012](https://cristal.univ-lille.fr/~casiez/1euro) | Speed-adaptive low-pass: heavy smoothing when slow, light when fast; 2-step tuning (min cutoff, then beta) | Filter every landmark and the cursor; ship tuned presets |
| Gesture data | [HaGRID, WACV 2024](https://openaccess.thecvf.com/content/WACV2024/html/Kapitanov_HaGRID_--_HAnd_Gesture_Recognition_Image_Dataset_WACV_2024_paper.html) | 554,800 images, 18 gestures, \~37.5k people, 0.5–4 m; an explicit "no gesture" class to cut false positives | Train/validate the pose classifier; always model "no gesture" |
| Accidental triggers | [Midas-touch clutching study, 2025](https://epub.uni-regensburg.de/78553/) | Explicit clutches (activation gestures, active zones) control when input is live | Engage gesture + attention gate before anything fires |
| Arm fatigue | [Consumed Endurance, CHI 2014](https://hci.cs.umanitoba.ca/Publications/details/consumed-endurance-a-metric-to-quantify-arm-fatigue-of-mid-air-interactions) · [NICER 2024](https://arxiv.org/html/2406.08875v1) | "Gorilla arm" is measurable; low arm positions and rest periods matter | Elbow-on-desk pointing zone, relative mode, CE in usability tests |
| Look-and-pinch UX | visionOS design guidance ([summary](https://smithery.ai/skills/ehmo/platform-design-skills/visionos-design-guidelines)) | Pinch confirms, something else targets; avoid sustained raising, complex finger patterns, two hands for basics | Small, low-effort confirm gestures; immediate visible state change |
| Mid-air typing | [Adhikary & Vertanen 2021](https://keithv.com/pub/midair/) · [speech + midair](https://www.keithv.com/pub/speechmidair) | Midair QWERTY \~11–16 WPM even with good tracking; speech + correction \~28 WPM | Text comes from dictation, not an air keyboard |
| Per-user thresholds | [Project Gameface](https://blog.google/technology/ai/google-project-gameface/) | A "gesture size" knob per action makes one system fit many bodies | Per-gesture sensitivity, learned in calibration |
| Shipping lessons | [Pawvis README](https://github.com/alexandriax/pawvis) | Cursor rides the palm (not a fingertip); click measured against the middle finger; target frozen during press/scroll; open hand arms control | Adopt all four as defaults |
