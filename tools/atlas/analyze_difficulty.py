#!/usr/bin/env python3
"""Measures how constrained each shipped board actually is.

Removing a line can never block another one, so the puzzle is monotone: once a
line is free it stays free, and a wrong tap only costs a heart. Difficulty is
therefore entirely "how many lines are tappable right now" — if most of the
board is free from the start the player taps almost anything and wins.

Reported per board:
  free0%   share of lines escapable before the first tap
  waves    greedy layers needed to clear it (dependency depth)
  avgfree% average share of remaining lines that are free, over a full solve
  forced   steps where exactly one line was free (the only real decisions)

    python tools/atlas/analyze_difficulty.py [--csv out.csv]
"""
import argparse
import json
import os
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
BANK = os.path.join(HERE, "..", "..", "assets", "campaign", "bank.json")
DIRS = {"U": (-1, 0), "D": (1, 0), "L": (0, -1), "R": (0, 1)}


def parse_line(spec):
    pos, moves = spec.split(":")
    r, c = (int(v) for v in pos.split(","))
    cells = [(r, c)]
    for ch in moves:
        dy, dx = DIRS[ch]
        r, c = r + dy, c + dx
        cells.append((r, c))
    return cells


class Board:
    def __init__(self, stage):
        self.rows, self.cols = stage["rows"], stage["cols"]
        self.lines = {}
        self.owner = {}
        for i, spec in enumerate(stage["lines"]):
            cells = parse_line(spec)
            self.lines[i] = cells
            for cell in cells:
                self.owner[cell] = i

    def head_dir(self, cells):
        (r1, c1), (r2, c2) = cells[-2], cells[-1]
        return r2 - r1, c2 - c1

    def is_free(self, i):
        cells = self.lines[i]
        dy, dx = self.head_dir(cells)
        r, c = cells[-1]
        r, c = r + dy, c + dx
        while 0 <= r < self.rows and 0 <= c < self.cols:
            owner = self.owner.get((r, c))
            if owner is not None and owner != i:
                return False
            r, c = r + dy, c + dx
        return True

    def free_ids(self):
        return [i for i in self.lines if self.is_free(i)]

    def remove(self, i):
        for cell in self.lines.pop(i):
            self.owner.pop(cell, None)


def analyze(stage):
    b = Board(stage)
    n = len(b.lines)
    if n == 0:
        return None
    free0 = len(b.free_ids())

    # dependency depth: how many greedy waves clear the board
    waves = 0
    while b.lines:
        batch = b.free_ids()
        if not batch:
            break
        for i in batch:
            b.remove(i)
        waves += 1
    solved = not b.lines

    # per-tap freedom over a full solve (remove one at a time)
    b = Board(stage)
    shares, forced = [], 0
    while b.lines:
        free = b.free_ids()
        if not free:
            break
        shares.append(len(free) / len(b.lines))
        if len(free) == 1:
            forced += 1
        b.remove(free[0])
    avg = sum(shares) / len(shares) if shares else 0
    return {
        "n": n, "free0": free0, "free0p": free0 / n,
        "waves": waves, "avgfreep": avg, "forced": forced, "solved": solved,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv")
    args = ap.parse_args()
    bank = json.load(open(BANK, encoding="utf-8"))["countries"]

    rows = []
    for entry in bank:
        for st in entry["stages"]:
            m = analyze(st)
            if m:
                m["name"] = st["name"]
                m["ko"] = st.get("ko", "")
                m["kind"] = st["kind"]
                rows.append(m)

    n = len(rows)
    print(f"{n} boards")
    print(f"  unsolvable: {sum(1 for r in rows if not r['solved'])}")
    print(f"  arrows/board  avg {sum(r['n'] for r in rows)/n:6.1f}")
    print(f"  free at start avg {sum(r['free0p'] for r in rows)/n*100:5.1f}%  "
          f"(median {sorted(r['free0p'] for r in rows)[n//2]*100:.1f}%)")
    print(f"  avg free share    {sum(r['avgfreep'] for r in rows)/n*100:5.1f}%")
    print(f"  waves (depth) avg {sum(r['waves'] for r in rows)/n:6.2f}  "
          f"max {max(r['waves'] for r in rows)}")
    print(f"  forced steps  avg {sum(r['forced'] for r in rows)/n:6.2f}")

    print("\n  wave-depth distribution:")
    for w, c in sorted(Counter(r["waves"] for r in rows).items()):
        print(f"    {w:2} waves: {c:4}  {'#' * (c * 60 // n)}")

    print("\n  boards where >40% is free from the start: "
          f"{sum(1 for r in rows if r['free0p'] > 0.4)}")
    print(f"  boards with zero forced steps: {sum(1 for r in rows if r['forced']==0)}")

    if args.csv:
        with open(args.csv, "w", encoding="utf-8") as f:
            f.write("name,ko,kind,arrows,free0,free0pct,waves,avgfreepct,forced\n")
            for r in rows:
                f.write(f'{r["name"]},{r["ko"]},{r["kind"]},{r["n"]},{r["free0"]},'
                        f'{r["free0p"]*100:.1f},{r["waves"]},{r["avgfreep"]*100:.1f},{r["forced"]}\n')
        print(f"\nwrote {args.csv}")


if __name__ == "__main__":
    main()
