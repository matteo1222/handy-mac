#!/usr/bin/env bash
# Copies a user's oops samples (landmark clips of accidental actions, numbers only) into the
# regression corpus, so `make bench` measures them from then on.
#   scripts/collect-misfires.sh <participant-id> [data-dir]
set -euo pipefail
cd "$(dirname "$0")/.."
PARTICIPANT=${1:?participant id, e.g. p01}
DATA=${2:-"$HOME/Library/Application Support/Handy"}
DEST=corpus/misfires/$PARTICIPANT
mkdir -p "$DEST"
shopt -s nullglob
count=0
for sample in "$DATA"/FalsePositives/*.lmk; do
  name=$(basename "$sample")
  [[ -e "$DEST/$name" ]] && continue
  cp "$sample" "$DEST/$name"
  count=$((count + 1))
done
echo "copied $count new misfire clip(s) to $DEST"
