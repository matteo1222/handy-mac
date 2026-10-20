# Hand models

MediaPipe's palm detector and hand landmarker (Apache License 2.0, Google), from the PyTorch port
at github.com/zmurez/MediaPipePyTorch (same licence), converted to Core ML at fp16. The palm detector
decodes its anchors in the graph and returns 2944 rows of box, 7 keypoints and score.

Rebuild with `scripts/convert-hand-models.sh`. Used by `CoreMLHandPoseProvider`.
