#!/usr/bin/env bash
# Rebuilds Sources/HandyPerception/Models from MediaPipe's palm detector and hand landmarker
# (Apache-2.0), via the PyTorch port at a pinned commit, traced and converted with coremltools in a
# throwaway uv environment, then compiled with coremlcompiler. Usage: scripts/convert-hand-models.sh
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rip "$WORK" 2>/dev/null || true' EXIT
git clone -q https://github.com/zmurez/MediaPipePyTorch.git "$WORK/src"
git -C "$WORK/src" checkout -q 65f2549ba35cd61dfd29f402f6c21882a32fabb1
uv venv -q --python 3.11 "$WORK/venv"
uv pip install -q --python "$WORK/venv/bin/python" torch==2.5.1 coremltools==8.1 numpy==1.26.4 pillow \
  opencv-python-headless==4.10.0.84
mkdir -p "$WORK/out"
"$WORK/venv/bin/python" -I scripts/models/convert.py "$WORK/src" "$WORK/out"
for model in HandPalmDetector HandLandmarker; do
  xcrun coremlcompiler compile "$WORK/out/$model.mlpackage" Sources/HandyPerception/Models/ >/dev/null
done
echo "models written to Sources/HandyPerception/Models"
