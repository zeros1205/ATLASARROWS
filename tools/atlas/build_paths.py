#!/usr/bin/env python3
"""Interleave PATH ("travel") stages into the campaign bank.

A PATH stage sits between two content stages and plays out as a puzzle on a
transport silhouette (bus, train, plane, ...). One is inserted *before every
content stage* of a country's round — so the round becomes
``[path, city_0, path, city_1, ..., path, finale]`` — except the very first
country of the campaign, which has no "travel here" leg.

Snowmobile is special: for a cold country (see cold_countries.json,
|centroid lat| >= 55) it is forced on the round's **entry** path (arriving at
the first city) and its **finale** path (leaving for the country stage); the
inter-city paths use a random non-snowmobile vehicle. Snowmobile never appears
anywhere else, so it reads as "you have reached the far north".

Idempotent: existing ``kind == 'path'`` stages are stripped first, so re-running
regenerates cleanly. Puzzles are seeded by (rank, index) — reproducible, and
the same silhouette yields a different layout at each position.
"""
import json
import os
import random

import relayout_difficulty as rl

HERE = os.path.dirname(os.path.abspath(__file__))
BANK = os.path.join(HERE, "..", "..", "assets", "campaign", "bank.json")
MASKS = os.path.join(HERE, "vehicle_masks.json")
COLD = os.path.join(HERE, "cold_countries.json")

SNOW = "snowmobile"
MIN_ARROWS = 100


def load_masks():
    raw = json.load(open(MASKS, encoding="utf-8"))
    masks = {}
    for name, m in raw.items():
        grid = m["grid"]
        cells = {(r, c) for r, row in enumerate(grid)
                 for c, ch in enumerate(row) if ch == "#"}
        masks[name] = (m["rows"], m["cols"], grid, cells)
    return masks


def gen_puzzle(mask_entry, seed):
    """Best-of-N solvable, fully-bent layout on a vehicle mask."""
    rows, cols, grid, cells = mask_entry
    best = None
    for a in range(4):
        sd = seed + a * 131
        ori = rl.gen_level(rows, cols, cells, sd, 0.97, 26, rl.SHORTBENT)
        ori = rl.chain_reorient(rows, cols, ori, 1.0, random.Random(sd + 7))
        if not ori or not rl.solvable(rows, cols, ori):
            continue
        if best is None or len(ori) > len(best):
            best = ori
        if len(best) >= 110:
            break
    return grid, [rl.encode(l) for l in best] if best else None


def main():
    bank = json.load(open(BANK, encoding="utf-8"))
    masks = load_masks()
    cold = set(json.load(open(COLD, encoding="utf-8"))["countries"])
    others = sorted(v for v in masks if v != SNOW)

    countries = bank["countries"]
    total_paths = snow_paths = 0
    min_arrows = 10 ** 9

    for ci, entry in enumerate(countries):
        content = [s for s in entry["stages"] if s.get("kind") != "path"]
        entry["stages"] = content  # strip any prior paths (idempotent)
        if ci == 0:
            continue  # first country: no travel-in leg
        is_cold = entry["name"] in cold
        rng = random.Random(entry["rank"] * 1009 + 17)
        new_stages = []
        prev_vehicle = None
        for idx, stage in enumerate(content):
            is_entry = idx == 0
            is_finale = idx == len(content) - 1
            if is_cold and (is_entry or is_finale):
                vehicle = SNOW
            else:
                pool = [v for v in others if v != prev_vehicle]
                vehicle = pool[rng.randrange(len(pool))]
            prev_vehicle = vehicle
            seed = entry["rank"] * 100003 + idx * 7919
            grid, lines = gen_puzzle(masks[vehicle], seed)
            if lines is None:
                raise SystemExit(f"unsolvable path {entry['name']}#{idx} {vehicle}")
            m = masks[vehicle]
            new_stages.append({
                "kind": "path",
                "vehicle": vehicle,
                "name": "",
                "ko": "",
                "rows": m[0],
                "cols": m[1],
                "grid": grid,
                "lines": lines,
            })
            total_paths += 1
            if vehicle == SNOW:
                snow_paths += 1
            min_arrows = min(min_arrows, len(lines))
            new_stages.append(stage)
        entry["stages"] = new_stages
        print(f"{entry['name']:22s} cold={is_cold} +{len(content)} paths")

    json.dump(bank, open(BANK, "w", encoding="utf-8"), ensure_ascii=False)
    tot = sum(len(e["stages"]) for e in countries)
    print(f"\npath stages: {total_paths} (snowmobile {snow_paths}) | "
          f"min arrows {min_arrows} | total stages now {tot}")


if __name__ == "__main__":
    main()
