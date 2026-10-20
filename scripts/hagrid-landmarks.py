#!/usr/bin/env python3
"""Turns HaGRID v2 annotations (CC BY-SA 4.0) into the landmark lines `handyctl train-classifier
--hagrid` reads: {"label", "hand", "split", "j": [[x, y] x 21]}, mirrored like the live camera,
in frame heights. Reads the annotation zip directly.

HaGRID has no per-hand chirality, so every hand appears once as each hand: the classes it trains
(thumbs up, thumbs down, shaka) read the same on either hand. Landmarks are already in
proportion: hand width over length does not change with the hand's angle at aspect 1.

Usage: scripts/hagrid-landmarks.py annotations.zip out.jsonl [per-class cap]
"""
import json
import sys
import zipfile

GESTURES = {"like", "dislike", "call"}


def main():
    archive, out = sys.argv[1], sys.argv[2]
    cap = int(sys.argv[3]) if len(sys.argv) > 3 else 4000
    counts = {}
    with zipfile.ZipFile(archive) as z, open(out, "w") as sink:
        names = sorted(n for n in z.namelist() if n.endswith(".json") and "checkpoint" not in n)
        for name in names:
            folder, gesture = name.split("/")[-2], name.split("/")[-1][:-5]
            split = "test" if folder == "test" else "train"
            # Gestures get the full cap; each other gesture a share, so "none" spans many shapes.
            limit = cap if gesture in GESTURES else cap // 6
            if split == "test":
                limit //= 4
            for record in json.loads(z.read(name)).values():
                for label, landmarks in zip(record["labels"], record["hand_landmarks"]):
                    key = (split, label)
                    if len(landmarks) != 21 or counts.get(key, 0) >= limit:
                        continue
                    counts[key] = counts.get(key, 0) + 1
                    joints = [[round(1 - x, 5), round(y, 5)] for x, y in landmarks]
                    for hand in ("right", "left"):
                        sink.write(json.dumps({"label": label, "hand": hand, "split": split, "j": joints}) + "\n")
    for key in sorted(counts):
        print(*key, counts[key], file=sys.stderr)


main()
