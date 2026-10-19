# Regression corpus

`make bench` (and CI) runs `handyctl bench corpus` against `bench/baseline.json`.

- Every `.lmk` under this folder is replayed. Labels in each header mark `none` (no-gesture)
  footage and gesture segments; an unlabelled clip counts as no-gesture.
- A deterministic synthetic no-gesture corpus (2 h, `NoGestureGenerator`) is always added.
- Recorded human footage (TASK-17) lives here as landmark streams only, never video. Large sets
  belong in a separate store; point `handyctl bench` at that folder too.
