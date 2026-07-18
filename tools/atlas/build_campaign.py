"""Build campaign.json from world_campaign_order.json + atlas_countries.json.

Walks world_campaign_order.countries (already sorted by area ascending), and for
each country that has a matching mask in atlas_countries.json with >=80 cells,
emits a campaign entry. Stops after 120 emitted countries.

Writes the result to:
  - tools/atlas/campaign.json
  - assets/campaign/campaign.json
"""
import json
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))  # tools/atlas
REPO_ROOT = os.path.abspath(os.path.join(BASE_DIR, "..", ".."))

ORDER_PATH = os.path.join(BASE_DIR, "world_campaign_order.json")
ATLAS_PATH = os.path.join(BASE_DIR, "atlas_countries.json")

OUT_PATH_1 = os.path.join(BASE_DIR, "campaign.json")
OUT_PATH_2 = os.path.join(REPO_ROOT, "assets", "campaign", "campaign.json")

MIN_CELLS = 80
MAX_EMIT = 120


def load_json(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except UnicodeDecodeError:
        with open(path, "r", encoding="utf-8-sig") as f:
            return json.load(f)


def main():
    order_data = load_json(ORDER_PATH)
    atlas_data = load_json(ATLAS_PATH)

    mask_by_name = {shape["name"]: shape for shape in atlas_data["shapes"]}

    emitted = []
    for entry in order_data["countries"]:
        if len(emitted) >= MAX_EMIT:
            break
        name = entry["country"]
        shape = mask_by_name.get(name)
        if shape is None:
            continue
        grid = shape.get("grid", [])
        cells = sum(row.count("#") for row in grid)
        if cells < MIN_CELLS:
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

    print(f"Total emitted: {total}")
    print(f"First 5: {first5}")
    print(f"Last 5: {last5}")
    print(f"File size: {size_kb:.2f} KB")
    print(f"Written to: {OUT_PATH_1}")
    print(f"Written to: {OUT_PATH_2}")


if __name__ == "__main__":
    main()
