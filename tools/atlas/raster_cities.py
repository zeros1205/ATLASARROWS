"""Rasterizes fetched city boundary polygons (cities_raw.json) into grids.

Output: atlas_cities.json  [{name, ko, rows, cols, cells, grid}]
"""
import json
import math
import os

import world_atlas as wa

HERE = os.path.dirname(os.path.abspath(__file__))
CITY_LONG_SIDE = 30

# cities whose admin polygon includes far-flung islands
CITY_CLIPS = {
    "Tokyo": (138.94, 35.49, 139.95, 35.92),  # mainland, no Izu/Ogasawara
    "Kaohsiung": (120.15, 22.40, 120.95, 23.55),  # mainland, no Pratas/Taiping
}


def rasterize_city(name, gj):
    orig = wa.long_side_for
    wa.long_side_for = lambda e: CITY_LONG_SIDE
    try:
        return wa.rasterize(gj, CITY_CLIPS.get(name))
    finally:
        wa.long_side_for = orig


def main():
    with open(os.path.join(HERE, "cities_raw.json"), encoding="utf-8") as f:
        raw = json.load(f)
    out, skipped = [], []
    for name, entry in raw.items():
        grid = rasterize_city(name, entry["geojson"])
        if grid is None or sum(r.count("#") for r in grid) < 20:
            skipped.append(name)
            continue
        out.append({
            "name": name, "ko": entry["ko"],
            "rows": len(grid), "cols": len(grid[0]),
            "cells": sum(r.count("#") for r in grid),
            "grid": grid,
        })
        print(f"{len(out):3d} {name:20s} {len(grid)}x{len(grid[0])}"
              f" cells={sum(r.count('#') for r in grid)}")
    with open(os.path.join(HERE, "atlas_cities.json"), "w",
              encoding="utf-8") as f:
        json.dump({"shapes": out}, f, ensure_ascii=False)
    print(f"\nDONE cities={len(out)} skipped={len(skipped)}", skipped)


if __name__ == "__main__":
    main()
