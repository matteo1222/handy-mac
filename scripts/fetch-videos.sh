#!/usr/bin/env bash
# Downloads freely licensed hand videos from Wikimedia Commons into .build/videos/ and transcodes
# them to H.264 (AVFoundation does not read WebM), plus a dimmed, noisier copy of each for the
# dim-light backend comparison. The videos stay out of git; only derived .lmk landmarks are committed.
# Needs curl and ffmpeg. Usage: scripts/fetch-videos.sh
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=.build/videos
mkdir -p "$OUT/source"

# name|licence|Commons file URL
CLIPS=(
  "ghana-alphabet|CC0|https://upload.wikimedia.org/wikipedia/commons/d/d8/Alphabets_-_Ghanaian_Sign_Language.webm"
  "rock-paper-scissors|CC BY 4.0|https://upload.wikimedia.org/wikipedia/commons/f/fd/Rock%2C_Paper%2C_Scissors.webm"
  "hand-wave|CC BY-SA 4.0|https://upload.wikimedia.org/wikipedia/commons/5/58/HandWaveExample.webm"
  "six-seven|CC0|https://upload.wikimedia.org/wikipedia/commons/6/6e/6-7_hand_gesture_2025.webm"
)

: >"$OUT/SOURCES.txt"
for entry in "${CLIPS[@]}"; do
  IFS='|' read -r name licence url <<<"$entry"
  source="$OUT/source/$name.webm"
  [[ -s "$source" ]] || curl -fsSL -A "handy-fixture-fetch/0.1" -o "$source" "$url"
  # 30 fps, at most 1280 px wide: what a laptop camera delivers.
  [[ -s "$OUT/$name.mp4" ]] || ffmpeg -loglevel error -y -i "$source" -an \
    -vf "fps=30,scale='min(1280,iw)':-2" -c:v libx264 -pix_fmt yuv420p -crf 18 "$OUT/$name.mp4"
  # Dim light: a third of the exposure plus sensor noise.
  [[ -s "$OUT/$name-dim.mp4" ]] || ffmpeg -loglevel error -y -i "$OUT/$name.mp4" -an \
    -vf "eq=brightness=-0.25:contrast=0.45:gamma=0.8,noise=alls=14:allf=t" \
    -c:v libx264 -pix_fmt yuv420p -crf 28 "$OUT/$name-dim.mp4"
  echo "$name: $licence, $url" >>"$OUT/SOURCES.txt"
  echo "fetched $name ($licence)"
done
