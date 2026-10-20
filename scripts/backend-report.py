#!/usr/bin/env python3
"""Compares hand-pose backends on landmark clips extracted from the same videos.

Usage: scripts/backend-report.py <lmk dir> <timings json> > docs/backend-report.json
The lmk dir holds <clip>.<backend>.lmk and <clip>-dim.<backend>.lmk from `handyctl video`.
Jitter is the RMS frame-to-frame second difference of the 21 joints (pixels at 720p): the shake
left after the motion itself. Dim-light accuracy compares each backend's dim clip with its own
normal-light clip on frames where both found a hand.
"""
import json
import math
import sys
from pathlib import Path

PIXELS = 720  # frame heights to pixels


def load(path):
    lines = Path(path).read_text().splitlines()[1:]
    # Follow one hand: the one nearest the hand followed on the previous frame.
    frames, last = [], None
    for line in lines:
        frame = json.loads(line)
        hands = [h for h in frame["hands"] if sum(1 for j in h["j"] if j) >= 15]
        if last and hands:
            hand = min(hands, key=lambda h: math.dist(centre(h), last))
            hand = hand if math.dist(centre(hand), last) < 0.15 else None
        else:
            hand = max(hands, key=lambda h: sum(1 for j in h["j"] if j), default=None)
        frames.append(hand)
        last = centre(hand) if hand else None
    return frames


def centre(hand):
    points = [j for j in hand["j"] if j]
    return (sum(p[0] for p in points) / len(points), sum(p[1] for p in points) / len(points))


def joints(hand):
    return [(j[0], j[1]) if j else None for j in hand["j"]]


def jitter(frames):
    squares = []
    for a, b, c in zip(frames, frames[1:], frames[2:]):
        if not (a and b and c):
            continue
        for pa, pb, pc in zip(joints(a), joints(b), joints(c)):
            if pa and pb and pc:
                squares.append(((pa[0] - 2 * pb[0] + pc[0]) ** 2 + (pa[1] - 2 * pb[1] + pc[1]) ** 2) * PIXELS**2)
    return round(math.sqrt(sum(squares) / len(squares)), 2) if squares else None


def distance(normal, dim):
    values = []
    for a, b in zip(normal, dim):
        if not (a and b):
            continue
        for pa, pb in zip(joints(a), joints(b)):
            if pa and pb:
                values.append(math.dist(pa, pb) * PIXELS)
    return round(sum(values) / len(values), 1) if values else None


def main():
    folder, timings = Path(sys.argv[1]), json.loads(Path(sys.argv[2]).read_text())
    clips = sorted({p.name.split(".")[0] for p in folder.glob("*.lmk") if not p.name.split(".")[0].endswith("-dim")})
    report = {"clips": {}, "method": __doc__.strip().splitlines()[0]}
    for clip in clips:
        row = {}
        for backend in ["vision", "coreml"]:
            normal = load(folder / f"{clip}.{backend}.lmk")
            dim = load(folder / f"{clip}-dim.{backend}.lmk")
            found = sum(1 for f in normal if f)
            found_dim = sum(1 for f in dim if f)
            row[backend] = {
                "frames": len(normal),
                "handRate": round(found / len(normal), 3),
                "handRateDim": round(found_dim / len(dim), 3),
                "jitterPixelsRMS": jitter(normal),
                "jitterPixelsRMSDim": jitter(dim),
                "dimVsNormalPixels": distance(normal, dim),
                "inferenceMilliseconds": timings.get(f"{clip}.{backend}"),
                "inferenceMillisecondsDim": timings.get(f"{clip}-dim.{backend}"),
            }
        report["clips"][clip] = row
    json.dump(report, sys.stdout, indent=2, sort_keys=True)
    print()


main()
