"""Extracts individual animal silhouettes from the user's sprite-sheet
illustrations (P5_Z-ARROWS/shapes/) and rasterizes each to a cell grid.

Pipeline per image: grayscale -> dark threshold -> dilate (merge broken
parts like the panda's patches) -> connected components -> per-component
coverage rasterization. Duplicate source files are skipped by hash.

Output: atlas_animals.json + animals_sheet.png (visual review)
"""
import hashlib
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = r"D:\Downloads\재혁\★PROJECT_BALI\P5_Z-ARROWS\shapes"
DARK = 128          # gray value below this = silhouette pixel
DILATE = 3          # px iterations to merge nearby fragments
MIN_AREA_FRac = 0.0006  # of image pixels; drops specks/watermark bits
COVERAGE = 0.32
LONG_SIDE = 28


def components(mask):
    """Label connected components on a dilated copy, return pixel masks
    of the ORIGINAL pixels per label, in reading order."""
    dil = mask.copy()
    for _ in range(DILATE):
        d = dil.copy()
        d[1:, :] |= dil[:-1, :]
        d[:-1, :] |= dil[1:, :]
        d[:, 1:] |= dil[:, :-1]
        d[:, :-1] |= dil[:, 1:]
        dil = d
    h, w = dil.shape
    labels = np.zeros((h, w), dtype=np.int32)
    cur = 0
    for sy, sx in zip(*np.nonzero(dil)):
        if labels[sy, sx]:
            continue
        cur += 1
        stack = [(sy, sx)]
        labels[sy, sx] = cur
        while stack:
            y, x = stack.pop()
            for ny, nx in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
                if 0 <= ny < h and 0 <= nx < w \
                   and dil[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = cur
                    stack.append((ny, nx))
    out = []
    for lab in range(1, cur + 1):
        comp = (labels == lab) & mask
        if not comp.any():
            continue
        ys, xs = np.nonzero(comp)
        out.append((ys.min(), xs.min(), ys.max(), xs.max(), comp))
    # reading order: row bands (by top, quantized), then left-to-right
    band = (max(o[2] - o[0] for o in out) + 1) * 0.7
    out.sort(key=lambda o: (int(o[0] // band), o[1]))
    return out


def to_grid(comp, y0, x0, y1, x1):
    crop = comp[y0:y1 + 1, x0:x1 + 1].astype(np.float32)
    h, w = crop.shape
    if w >= h:
        cols = LONG_SIDE
        rows = max(4, round(LONG_SIDE * h / w))
    else:
        rows = LONG_SIDE
        cols = max(4, round(LONG_SIDE * w / h))
    ye = np.linspace(0, h, rows + 1).round().astype(int)
    xe = np.linspace(0, w, cols + 1).round().astype(int)
    grid = []
    for r in range(rows):
        row = ""
        for c in range(cols):
            block = crop[ye[r]:ye[r + 1], xe[c]:xe[c + 1]]
            row += "#" if block.size and block.mean() >= COVERAGE else "."
        grid.append(row)
    rs = [i for i, row in enumerate(grid) if "#" in row]
    cs = [i for i in range(cols) if any(row[i] == "#" for row in grid)]
    if not rs:
        return None
    return [row[cs[0]:cs[-1] + 1] for row in grid[rs[0]:rs[-1] + 1]]


def main():
    seen_hash, out = set(), []
    files = sorted(os.listdir(SRC))
    for fi, fn in enumerate(files, 1):
        path = os.path.join(SRC, fn)
        try:
            raw = open(path, "rb").read()
        except OSError:
            continue
        digest = hashlib.sha1(raw).hexdigest()
        if digest in seen_hash:
            print(f"dup skipped: {fn}")
            continue
        seen_hash.add(digest)
        try:
            img = Image.open(path)
            if img.mode in ("RGBA", "LA", "P"):
                rgba = img.convert("RGBA")
                white = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
                img = Image.alpha_composite(white, rgba)
            img = img.convert("L")
        except Exception as e:
            print(f"unreadable {fn}: {e}")
            continue
        arr = np.asarray(img)
        mask = arr < DARK
        if mask.mean() > 0.5:  # inverted source (light shapes on dark)
            mask = ~mask
        min_area = mask.size * MIN_AREA_FRac
        comps = [c for c in components(mask)
                 if c[4].sum() >= min_area]
        for ci, (y0, x0, y1, x1, comp) in enumerate(comps, 1):
            grid = to_grid(comp, y0, x0, y1, x1)
            if grid is None:
                continue
            cells = sum(r.count("#") for r in grid)
            fill = cells / (len(grid) * len(grid[0]))
            # junk filter: watermark text scraps and dot debris are
            # sparse or extremely flat; real animals are chunky
            if cells < 80 or min(len(grid), len(grid[0])) < 6 or fill < 0.17:
                continue
            out.append({
                "name": f"animal {fi:02d}-{ci:02d}",
                "ko": f"동물 {fi:02d}-{ci:02d}",
                "src": fn,
                "rows": len(grid), "cols": len(grid[0]),
                "cells": sum(r.count("#") for r in grid),
                "grid": grid,
            })
        print(f"{fn}: {len(comps)} components")
    with open(os.path.join(HERE, "atlas_animals.json"), "w",
              encoding="utf-8") as f:
        json.dump({"shapes": out}, f, ensure_ascii=False)
    print(f"\nDONE animals={len(out)}")

    # review sheet
    BG, INK = (0xF7, 0xF6, 0xF2), (0x23, 0x25, 0x2E)
    CELL, PAD, LABEL = 6, 8, 16
    try:
        font = ImageFont.truetype("consola.ttf", 11)
    except OSError:
        font = ImageFont.load_default()
    ncols = 12
    col_w = 30 * CELL + PAD * 2
    row_h = 30 * CELL + LABEL + PAD
    nrows = (len(out) + ncols - 1) // ncols
    sheet = Image.new("RGB", (col_w * ncols, row_h * nrows), BG)
    d = ImageDraw.Draw(sheet)
    for i, s in enumerate(out):
        ox = (i % ncols) * col_w + PAD
        oy = (i // ncols) * row_h + PAD
        for r, row in enumerate(s["grid"]):
            for c, ch in enumerate(row):
                if ch == "#":
                    x, y = ox + c * CELL, oy + r * CELL
                    d.rectangle((x, y, x + CELL - 1, y + CELL - 1), fill=INK)
        d.text((ox, oy + 30 * CELL + 2), s["name"], fill=INK, font=font)
    sheet.save(os.path.join(HERE, "animals_sheet.png"))
    print("sheet -> animals_sheet.png")


if __name__ == "__main__":
    main()
