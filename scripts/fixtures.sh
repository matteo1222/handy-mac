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

if [[ "$MODE" == check ]]; then echo "fixtures match their recipes"; fi
