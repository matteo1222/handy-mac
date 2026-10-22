# Regression corpus

`make bench` (and CI) runs `handyctl bench corpus` against `bench/baseline.json`.

- Every `.lmk` and `.lmkz` (the same lines, LZFSE-compressed) under this folder is replayed. Labels
  in each header mark `none` (no-gesture) footage and gesture segments; an unlabelled clip counts
  as no-gesture.
- A deterministic synthetic no-gesture corpus (2 h, `NoGestureGenerator`) is always added.
- Landmark streams only, never video.

## public/

Real hands that never mean to gesture: openly licensed Wikimedia Commons videos of video calls,
podcasts and interviews, where people talk with their hands, type, drink and fidget. Each clip's
header names its source page and licence (CC0, public domain, CC BY). `scripts/fetch-corpus.sh`
rebuilds them from the videos with the default hand backend.

Third-person footage is not a laptop camera: hands are smaller and farther away. It measures how
often everyday movement fires an action; recorded sessions from the corpus recorder (menu bar,
"Record Corpus Session…") cover the laptop view and labelled gestures.
