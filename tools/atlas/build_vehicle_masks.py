#!/usr/bin/env python3
"""Turn the curated transport silhouettes into puzzle grid masks.

Source of truth = the 16 approved PNGs in ``vehicle_png/`` (Material Icons,
Apache-2.0, detail-preserving: black body on transparent, windows/wheels left
as transparent holes). These are exactly the shapes the user curated, so we
grid them straight from the PNG rather than re-rasterising the SVGs — that also
preserves the 45deg rotation baked into ``local_airport``.

Each PNG becomes a coverage grid: the long side is split into ~L cells and a
cell is ``#`` when its block is >=THR black. Holes (windows) stay ``.`` and
become empty space the arrows route around, same as a territory mask. Output:
``vehicle_masks.json`` = ``{name: {rows, cols, grid: [str, ...]}}``.
"""
import json
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PNG_DIR = os.path.join(HERE, "vehicle_png")
OUT = os.path.join(HERE, "vehicle_masks.json")

TARGET_CELLS = 1200  # ~110-130 arrows per board, comfortably over the 100 floor
THR = 0.38           # block is a cell once this fraction of it is black


def black_map(path):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    # A pixel is body iff it is opaque *and* dark; holes are transparent.
    return [[px[x, y][3] > 40 and px[x, y][0] < 128 for x in range(w)]
            for y in range(h)], w, h


def to_grid(bmap, w, h, long_cells):
    if w >= h:
        cols = long_cells
        rows = max(1, round(h / w * long_cells))
    else:
        rows = long_cells
        cols = max(1, round(w / h * long_cells))
    bw, bh = w / cols, h / rows
    grid = []
    for r in range(rows):
        row = []
        for c in range(cols):
            x0, x1 = int(c * bw), max(int(c * bw) + 1, int((c + 1) * bw))
            y0, y1 = int(r * bh), max(int(r * bh) + 1, int((r + 1) * bh))
            blk = tot = 0
            for y in range(y0, min(y1, h)):
                for x in range(x0, min(x1, w)):
                    tot += 1
                    blk += 1 if bmap[y][x] else 0
            row.append("#" if tot and blk / tot >= THR else ".")
        grid.append("".join(row))
    return grid


def build(path, target=TARGET_CELLS):
    bmap, w, h = black_map(path)
    best = None
    for long_cells in range(24, 110):
        grid = to_grid(bmap, w, h, long_cells)
        cells = sum(r.count("#") for r in grid)
        if best is None or abs(cells - target) < abs(best[1] - target):
            best = (grid, cells)
        if cells >= target:
            break
    return best[0]


def main():
    out = {}
    for fn in sorted(os.listdir(PNG_DIR)):
        if not fn.endswith(".png"):
            continue
        name = os.path.splitext(fn)[0]
        grid = build(os.path.join(PNG_DIR, fn))
        cells = sum(r.count("#") for r in grid)
        out[name] = {"rows": len(grid), "cols": len(grid[0]), "grid": grid}
        print(f"{name:16s} {len(grid):2d}x{len(grid[0]):2d} cells={cells}")
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)
    print(f"wrote {len(out)} masks -> {OUT}")


if __name__ == "__main__":
    main()
