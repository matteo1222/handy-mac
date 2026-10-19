---
id: doc-1
title: 'Click gesture A/B: pinch vs index dip (synthetic)'
type: specification
created_date: '2026-10-19 18:28'
updated_date: '2026-10-19 18:28'
---
# Click gesture A/B: pinch vs index dip

Measured with `handyctl bench-click` (report: `docs/click-ab-report.json`) on synthetic clips only:
60 deliberate clicks per gesture with random size, position and roll, and 30 minutes of engaged
pointing with fidgets (loosely bent fingers, thumb drifting toward the index).

| Gesture | Click recall | Recall with the thumb tip hidden | False clicks / hour | Fidget headroom |
| --- | --- | --- | --- | --- |
| Thumb–index pinch | 100% | 0% | 0 | 0.102 |
| Index dip | 100% | 100% | 0 | 0.059 |

- Hidden thumb tip models the front-camera risk in the spec: a pinch cannot click when the thumb tip
  is behind the index (by rule, clicks never come from low-confidence tips); a dip needs only the index tip.
- Fidget headroom is how close everyday finger motion came to the press threshold (pinch scale; larger is
  safer). The dip has about half the pinch's margin, so on real hands it is the likelier false click.

Both modes ship: `ClickSettings.gesture` (`pinch` default, `indexDip`). Recommendation pending
recorded clips (TASK-17): keep pinch as default if recorded false clicks favour it; switch to index dip if
recorded occlusion makes pinches fail. The Core ML backend half of the spike needs the MediaPipe hand
landmarker model (download + conversion), not done yet.
