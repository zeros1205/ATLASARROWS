"""Build campaign.json from world_campaign_order.json + atlas_countries.json.

Walks world_campaign_order.countries (already sorted by area ascending) and
emits every country whose atlas mask has a big enough connected piece to make
a board (see MIN_PIECE). There is no cap on the campaign length — a cap here
silently drops the LARGEST countries, i.e. the whole late game, since the
order is area-ascending.

Writes the result to:
  - tools/atlas/campaign.json
  - assets/campaign/campaign.json
"""
import json
import os
from collections import deque

BASE_DIR = os.path.dirname(os.path.abspath(__file__))  # tools/atlas
REPO_ROOT = os.path.abspath(os.path.join(BASE_DIR, "..", ".."))

ORDER_PATH = os.path.join(BASE_DIR, "world_campaign_order.json")
ATLAS_PATH = os.path.join(BASE_DIR, "atlas_countries.json")

OUT_PATH_1 = os.path.join(BASE_DIR, "campaign.json")
OUT_PATH_2 = os.path.join(REPO_ROOT, "assets", "campaign", "campaign.json")

# Board size is no longer inherited from the mask — export_boards.dart
# resamples every mask until it hits its target arrow count — so the gate no
# longer cares how BIG a mask is, only whether there is a shape worth
# resampling.
#
# Total cell count is the wrong measure for that: a 30-cell country that is
# one solid blob and a 30-cell archipelago scattered across open ocean score
# the same, and only the first makes a board. What matters is the largest
# connected piece. Scaling a 4-cell speck up just yields a giant near-empty
# grid with a few blocks in it (verified by rendering them).
#
# 30 keeps every real archipelago — Indonesia's largest island is 47 cells,
# the Philippines' 85, Japan's 188 — and drops the 16 that cannot make a
# board at any scale: Tonga (3), Maldives (4), Solomon Islands (6), Fiji (29).
MIN_PIECE = 30


def load_json(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except UnicodeDecodeError:
        with open(path, "r", encoding="utf-8-sig") as f:
            return json.load(f)


def largest_piece(grid):
    """Cells in the biggest 4-connected run of '#' — the playable core."""
    cells = {(r, c)
             for r, row in enumerate(grid)
             for c, ch in enumerate(row) if ch == "#"}
    seen, best = set(), 0
    for start in cells:
        if start in seen:
            continue
        queue, n = deque([start]), 0
        seen.add(start)
        while queue:
            r, c = queue.popleft()
            n += 1
            for nb in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
                if nb in cells and nb not in seen:
                    seen.add(nb)
                    queue.append(nb)
        best = max(best, n)
    return best


def main():
    order_data = load_json(ORDER_PATH)
    atlas_data = load_json(ATLAS_PATH)

    mask_by_name = {shape["name"]: shape for shape in atlas_data["shapes"]}

    emitted = []
    skipped_no_mask = []
    skipped_scattered = []
    for entry in order_data["countries"]:
        name = entry["country"]
        shape = mask_by_name.get(name)
        if shape is None:
            skipped_no_mask.append(name)
            continue
        grid = shape.get("grid", [])
        cells = sum(row.count("#") for row in grid)
        piece = largest_piece(grid)
        if piece < MIN_PIECE:
            skipped_scattered.append((name, cells, piece))
            continue
        emitted.append({
            "rank": len(emitted) + 1,
            "name": name,
            "ko": shape.get("ko", name),
            "area_km2": entry.get("area_km2"),
            "continent": shape.get("continent", ""),
            "rows": shape.get("rows"),
            "cols": shape.get("cols"),
            "grid": grid,
            "cells": cells,
        })

    result = {"countries": emitted}

    os.makedirs(os.path.dirname(OUT_PATH_2), exist_ok=True)

    for out_path in (OUT_PATH_1, OUT_PATH_2):
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, separators=(",", ":"))

    total = len(emitted)
    first5 = [c["name"] for c in emitted[:5]]
    last5 = [c["name"] for c in emitted[-5:]]
    size_kb = os.path.getsize(OUT_PATH_1) / 1024.0

    print(f"Total emitted: {total} / {len(order_data['countries'])} in order")
    print(f"  skipped, no mask in atlas ({len(skipped_no_mask)}): "
          f"{', '.join(skipped_no_mask)}")
    print(f"  skipped, largest piece <{MIN_PIECE} cells "
          f"({len(skipped_scattered)}): "
          f"{', '.join(f'{n} {p}/{c}' for n, c, p in skipped_scattered)}")
    print(f"First 5: {first5}")
    print(f"Last 5: {last5}")
    print(f"File size: {size_kb:.2f} KB")
    print(f"Written to: {OUT_PATH_1}")
    print(f"Written to: {OUT_PATH_2}")


if __name__ == "__main__":
    main()
