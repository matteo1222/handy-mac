#!/usr/bin/env bash
# The recipe for every replay fixture. Each line synthesises one clip.
#
#   scripts/fixtures.sh regen   re-synthesise every .lmk and re-bless every .events.json (review the git diff!)
#   scripts/fixtures.sh check   fail if a committed .lmk no longer matches its recipe
#
# gestures/<Gesture case>.lmk is required for every Gesture case (see ReplayTests).
# scenarios/<name>.lmk holds negative and edge cases.
set -euo pipefail
cd "$(dirname "$0")/.."
MODE=${1:-check}
DIR=Tests/HandyReplayTests/Fixtures
swift build -q --product handyctl
CTL=.build/debug/handyctl
TMP=$(mktemp -d)

fixture() {
  local name=$1; shift
  local target="$DIR/$name.lmk"
  mkdir -p "$(dirname "$target")"
  "$CTL" synth "$@" -o "$TMP/clip.lmk" >/dev/null
  # The header records the synth command, which names the temp file; pin it to the fixture path.
  sed -i '' "s|$TMP/clip.lmk|$target|" "$TMP/clip.lmk"
  if [[ "$MODE" == regen ]]; then
    cp "$TMP/clip.lmk" "$target"
    "$CTL" replay "$target" --write-expected "$DIR/$name.events.json" --quiet >/dev/null
    echo "regenerated $name"
  elif ! cmp -s "$TMP/clip.lmk" "$target"; then
    echo "error: $target does not match its recipe in scripts/fixtures.sh; run scripts/fixtures.sh regen" >&2
    exit 1
  fi
}

# Clutch (TASK-5)
fixture gestures/engage --script "relaxed:300ms openPalm:800ms" --noise 1.5px --seed 1
fixture gestures/disengage --script "openPalm:600ms fist:400ms openPalm:200ms" --noise 1.5px --seed 2
fixture scenarios/disengageOnHandLost --script "openPalm:600ms none:400ms" --noise 1.5px --seed 3
fixture scenarios/abortedArm --script "relaxed:300ms openPalm:200ms relaxed:500ms" --noise 1.5px --seed 4
fixture scenarios/briefCurlDoesNotAbortArm --script "openPalm:200ms fist:60ms openPalm:500ms" --seed 5
fixture scenarios/restingHandNeverEngages --script "relaxed:3s typing:3s relaxed:2s" --noise 2px --seed 6
fixture scenarios/sidewaysPalmNeverEngages --script "sideways:2s" --noise 1.5px --seed 7
fixture scenarios/dropoutWhileEngaged --script "openPalm:2s" --noise 1.5px --dropout 0.1 --seed 8

# Cursor (TASK-6)
fixture gestures/moveCursor --script "openPalm:600ms@0.7,0.7 openPalm:600ms->1.1,0.6 openPalm:300ms" --noise 1px --seed 9
fixture scenarios/stillHandStillCursor --script "openPalm:3s" --noise 2px --seed 10
fixture scenarios/fistDoesNotDragCursor --script "openPalm:600ms fist:400ms" --noise 1px --seed 11

# Clicks (TASK-7)
fixture gestures/click --script "openPalm:700ms pinch:150ms openPalm:400ms" --noise 1px --seed 12
fixture gestures/rightClick --script "openPalm:700ms pinchMiddle:150ms openPalm:400ms" --noise 1px --seed 13
fixture scenarios/nearMissPinchNeverClicks --script "openPalm:700ms nearPinch:400ms openPalm:300ms nearPinch:400ms openPalm:300ms" --noise 1.5px --seed 14
fixture scenarios/lowConfidenceTipsNeverClick --script "openPalm:700ms pinch:150ms openPalm:400ms" --noise 1px --dim-joints thumbTip,indexTip --seed 15
fixture scenarios/clickLandsWhereAimed --script "openPalm:700ms@0.8,0.7 openPalm:300ms->0.9,0.7 pinch:200ms->0.904,0.7 openPalm:300ms" --noise 1px --seed 16

# Drag and double click (TASK-8)
fixture gestures/drag --script "openPalm:700ms@0.8,0.7 pinch:400ms pinch:600ms->1.0,0.6 openPalm:400ms" --noise 1px --seed 17
fixture gestures/doubleClick --script "openPalm:700ms pinch:120ms openPalm:130ms pinch:120ms openPalm:400ms" --noise 1px --seed 18
fixture scenarios/twoSlowClicksStaySingle --script "openPalm:700ms pinch:120ms openPalm:600ms pinch:120ms openPalm:400ms" --noise 1px --seed 19
fixture scenarios/holdWithoutMovingStartsDrag --script "openPalm:700ms pinch:600ms openPalm:300ms" --noise 1px --seed 20

# Scroll (TASK-9)
fixture gestures/scroll --script "openPalm:700ms twoFingers:300ms twoFingers:600ms->0.9,0.55 twoFingers:300ms openPalm:600ms" --noise 1px --seed 21
fixture scenarios/scrollHorizontal --script "openPalm:700ms twoFingers:300ms twoFingers:600ms->1.1,0.75 twoFingers:300ms openPalm:400ms" --noise 1px --seed 22
fixture scenarios/scrollMomentum --script "openPalm:700ms twoFingers:300ms twoFingers:200ms->0.9,0.6 openPalm:1200ms" --noise 1px --seed 23
fixture scenarios/briefScrollPoseDoesNotScroll --script "openPalm:700ms twoFingers:100ms openPalm:500ms" --noise 1px --seed 24

# Attention gate (TASK-10)
fixture scenarios/lookingAwayNeverEngages --script "openPalm:2s" --face "60:2s" --noise 1px --seed 25
fixture scenarios/noFaceNeverEngages --script "openPalm:2s" --face "none:2s" --noise 1px --seed 26
fixture scenarios/lookingAwayDisengages --script "openPalm:2s" --face "0:1s 50:1s" --noise 1px --seed 27
fixture scenarios/glanceAwayKeepsEngagement --script "openPalm:2s" --face "0:1s 50:200ms 0:800ms" --noise 1px --seed 28

# Crossed-hands hard stop (TASK-11)
fixture gestures/hardStop --script "openPalm:1500ms@0.6,0.75~0.12" --other-hand "openPalm:1500ms@1.2,0.75~0.12" --noise 1px --seed 29
fixture scenarios/briefCrossDoesNotStop --script "openPalm:600ms@0.6,0.75~0.12 none:600ms" --other-hand "openPalm:600ms@1.2,0.75~0.12 none:600ms" --noise 1px --seed 30
fixture scenarios/handsSideBySideDoNotStop --script "openPalm:2s@1.2,0.75~0.12" --other-hand "openPalm:2s@0.6,0.75~0.12" --noise 1px --seed 31
fixture scenarios/hardStopWhileDragging --script "openPalm:700ms@0.6,0.75~0.12 pinch:1500ms" --other-hand "none:700ms openPalm:1500ms@1.2,0.75~0.12" --noise 1px --seed 32

# One-shot poses (TASK-12)
fixture gestures/thumbsUp --script "relaxed:400ms thumbsUp:800ms relaxed:400ms" --noise 1px --seed 33
fixture gestures/thumbsDown --script "relaxed:400ms thumbsDown:800ms relaxed:400ms" --noise 1px --seed 34
fixture scenarios/briefThumbsUpDoesNotFire --script "relaxed:400ms thumbsUp:350ms relaxed:400ms" --noise 1px --seed 35
fixture scenarios/heldThumbsUpFiresOnce --script "relaxed:400ms thumbsUp:2500ms relaxed:400ms" --noise 1px --seed 36
fixture scenarios/thumbsUpWhileEngagedDoesNothing --script "openPalm:700ms thumbsUp:1000ms" --noise 1px --seed 37

# Flicks (TASK-13): a quick wrist turn (roll) or tip (pitch) with the index pointing
fixture gestures/flickRight --script "relaxed:300ms point:400ms point:150ms/-35 point:400ms/-35" --noise 1px --seed 38
fixture gestures/flickLeft --script "relaxed:300ms point:400ms point:150ms/35 point:400ms/35" --noise 1px --seed 39
fixture gestures/flickUp --script "relaxed:300ms point:400ms^55 point:150ms point:400ms" --noise 1px --seed 40
fixture gestures/flickDown --script "relaxed:300ms point:400ms point:150ms^55 point:400ms^55" --noise 1px --seed 41
fixture scenarios/slowWristTurnIsNotAFlick --script "relaxed:300ms point:400ms point:300ms/-9 point:300ms/-18 point:300ms/-27 point:300ms/-35 point:400ms/-35" --noise 1px --seed 42
fixture scenarios/smallFlickDoesNotFire --script "relaxed:300ms point:400ms point:150ms/-12 point:400ms/-12" --noise 1px --seed 43
fixture scenarios/movingAPointingHandIsNotAFlick --script "relaxed:300ms point:400ms point:150ms->1.05,0.75 point:150ms->0.9,0.6 point:400ms" --noise 1px --seed 44
fixture scenarios/flickWhileEngagedDoesNothing --script "openPalm:700ms point:400ms point:150ms/-35 point:400ms/-35" --noise 1px --seed 45

# Spaces swipes and Mission Control (TASK-22)
fixture gestures/swipeLeft --script "relaxed:300ms openPalm:100ms@1.2,0.75 openPalm:300ms->0.6,0.75 relaxed:400ms" --noise 1px --seed 46
fixture gestures/swipeRight --script "relaxed:300ms openPalm:100ms@0.6,0.75 openPalm:300ms->1.2,0.75 relaxed:400ms" --noise 1px --seed 47
fixture gestures/swipeUp --script "relaxed:300ms openPalm:100ms@0.9,0.92 openPalm:300ms->0.9,0.55 relaxed:400ms" --noise 1px --seed 48
fixture scenarios/shortSwipeDoesNotFire --script "relaxed:300ms openPalm:100ms@0.8,0.75 openPalm:300ms->1.0,0.75 relaxed:400ms" --noise 1px --seed 49
fixture scenarios/slowPalmMoveIsNotASwipe --script "relaxed:300ms openPalm:100ms@0.6,0.75 openPalm:1500ms->1.2,0.75 relaxed:400ms" --noise 1px --seed 50
fixture scenarios/swipeWhileEngagedMovesTheCursor --script "openPalm:700ms@0.6,0.75 openPalm:300ms->1.2,0.75 openPalm:300ms" --noise 1px --seed 51

# Two-hand pinch zoom (TASK-23)
fixture gestures/zoomIn --script "openPalm:700ms@1.1,0.75~0.12 pinch:200ms pinch:600ms->1.4,0.75 openPalm:400ms" --other-hand "none:700ms pinch:200ms@0.7,0.75~0.12 pinch:600ms->0.4,0.75 openPalm:400ms" --noise 1px --seed 52
fixture gestures/zoomOut --script "openPalm:700ms@1.4,0.75~0.12 pinch:200ms pinch:600ms->1.05,0.75 openPalm:400ms" --other-hand "none:700ms pinch:200ms@0.4,0.75~0.12 pinch:600ms->0.75,0.75 openPalm:400ms" --noise 1px --seed 53
fixture scenarios/clickWithOtherHandVisibleIsAClick --script "openPalm:700ms@1.1,0.75~0.12 pinch:150ms openPalm:400ms" --other-hand "relaxed:1250ms@0.6,0.8~0.12" --noise 1px --seed 54

# Dictation (TASK-24)
fixture gestures/dictation --script "relaxed:400ms shaka:800ms relaxed:400ms" --noise 1px --seed 55

# Oops (TASK-20): a "no-no" wag of the pointing finger
fixture gestures/oops --script "relaxed:300ms point:400ms point:150ms/-25 point:150ms/25 point:150ms/-25 point:150ms/25 point:400ms" --noise 1px --seed 56
fixture scenarios/twoSwingsAreNotOops --script "relaxed:300ms point:400ms point:150ms/-25 point:150ms/25 point:600ms/25" --noise 1px --seed 57

if [[ "$MODE" == check ]]; then echo "fixtures match their recipes"; fi
