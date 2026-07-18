"""Rasterizes ALL Natural Earth 50m countries into high-res cell grids.

Auto per-country framing: keeps the main landmass plus polygons whose
centroid sits within KEEP_DEG of it (drops far overseas territories),
unwraps the antimeridian (Russia, Fiji, NZ), sizes the grid from the
country's effective extent. Manual clip overrides for the usual suspects.

Output: atlas_countries.json  [{name, ko, continent, rows, cols, cells, grid}]
"""
import json
import math
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
COVERAGE = 0.35
SUB = 4
KEEP_DEG = 25.0       # centroid distance to keep secondary polygons
KEEP_AREA = 0.002     # ... if their area is at least this x main area
CHUNK = 2048

# lon0, lat0, lon1, lat1 — frame only what's inside
CLIP_OVERRIDES = {
    "United States of America": (-125.5, 24.3, -66.5, 49.5),  # CONUS
    "France": (-5.5, 41.2, 9.8, 51.3),                        # metropolitan
    "Netherlands": (3.2, 50.7, 7.3, 53.7),
    "Portugal": (-9.6, 36.9, -6.1, 42.2),                     # mainland
    "Spain": (-9.4, 35.9, 4.4, 43.9),                         # iberia only
    "Chile": (-75.8, -56.2, -66.3, -17.4),                    # no Easter Is.
    "Ecuador": (-81.1, -5.1, -75.1, 1.5),                     # no Galápagos
    "United Kingdom": (-8.7, 49.8, 2.0, 60.9),
    "Norway": (4.0, 57.8, 31.3, 71.4),                        # no Svalbard
    "New Zealand": (166.0, -47.5, 179.9, -34.0),
    "Japan": (128.5, 30.0, 146.0, 45.8),                      # no Okinawa
}


def rings_of(geom):
    polys = ([geom["coordinates"]] if geom["type"] == "Polygon"
             else geom["coordinates"])
    return [[list(map(tuple, ring)) for ring in poly] for poly in polys]


def ring_area_centroid(r):
    a = cx = cy = 0.0
    for i in range(len(r) - 1):
        cross = r[i][0] * r[i + 1][1] - r[i + 1][0] * r[i][1]
        a += cross
        cx += (r[i][0] + r[i + 1][0]) * cross
        cy += (r[i][1] + r[i + 1][1]) * cross
    a /= 2
    if abs(a) < 1e-12:
        return 0.0, r[0][0], r[0][1]
    return abs(a), cx / (6 * a), cy / (6 * a)


def unwrap(polys):
    """If the country spans the antimeridian, shift western lons +360."""
    lons = [x for poly in polys for ring in poly for x, _ in ring]
    if max(lons) - min(lons) <= 180:
        return polys
    return [[[(x + 360 if x < 0 else x, y) for x, y in ring]
             for ring in poly] for poly in polys]


def frame(polys, override):
    """Choose which polygons to draw and the lon/lat frame."""
    if override:
        lon0, lat0, lon1, lat1 = override
        kept = [poly for poly in polys
                if any(lon0 <= x <= lon1 and lat0 <= y <= lat1
                       for x, y in poly[0])]
        return kept, override
    metas = [ring_area_centroid(poly[0]) for poly in polys]
    main_i = max(range(len(polys)), key=lambda i: metas[i][0])
    ma, mx, my = metas[main_i]
    kept = [poly for i, poly in enumerate(polys)
            if i == main_i
            or (math.hypot(metas[i][1] - mx, metas[i][2] - my) <= KEEP_DEG
                and metas[i][0] >= ma * KEEP_AREA)]
    xs = [x for poly in kept for x, _ in poly[0]]
    ys = [y for poly in kept for _, y in poly[0]]
    padx = (max(xs) - min(xs)) * 0.02 + 0.01
    pady = (max(ys) - min(ys)) * 0.02 + 0.01
    return kept, (min(xs) - padx, min(ys) - pady,
                  max(xs) + padx, max(ys) + pady)


def make_edges(polys, clipbox):
    lon0, lat0, lon1, lat1 = clipbox
    out = []
    for poly in polys:
        for ring in poly:
            if len(ring) < 4:
                continue
            xs = [x for x, _ in ring]
            ys = [y for _, y in ring]
            if max(xs) < lon0 or min(xs) > lon1 \
               or max(ys) < lat0 or min(ys) > lat1:
                continue
            arr = np.asarray(ring, dtype=float)
            out.append((arr[:-1, 0], arr[:-1, 1], arr[1:, 0], arr[1:, 1]))
    return out


def contains(edges, pts):
    inside = np.zeros(len(pts), dtype=bool)
    for x1, y1, x2, y2 in edges:
        dy = y2 - y1
        ok = dy != 0
        x1o, y1o, x2o, y2o = x1[ok], y1[ok], x2[ok], y2[ok]
        dyo = y2o - y1o
        for s in range(0, len(pts), CHUNK):
            px = pts[s:s + CHUNK, 0:1]
            py = pts[s:s + CHUNK, 1:2]
            straddle = (y1o > py) != (y2o > py)
            xin = (x2o - x1o) * (py - y1o) / dyo + x1o
            cross = (straddle & (px < xin)).sum(axis=1)
            inside[s:s + CHUNK] ^= (cross % 2).astype(bool)
    return inside


def long_side_for(e_deg):
    return int(round(min(44, max(14, 16 + 7 * math.log2(e_deg + 1)))))


def rasterize(geom, override=None):
    if override:
        # filter on raw coords BEFORE unwrapping, else antimeridian
        # countries (USA via Aleutians) get shifted out of the clip box
        kept, (lon0, lat0, lon1, lat1) = frame(rings_of(geom), override)
    else:
        polys = unwrap(rings_of(geom))
        kept, (lon0, lat0, lon1, lat1) = frame(polys, None)
    if not kept:
        return None
    midlat = math.radians(max(-85, min(85, (lat0 + lat1) / 2)))
    w_deg = (lon1 - lon0) * math.cos(midlat)
    h_deg = lat1 - lat0
    if w_deg <= 0 or h_deg <= 0:
        return None
    long_side = long_side_for(max(w_deg, h_deg))
    if w_deg >= h_deg:
        cols = long_side
        rows = max(6, round(long_side * h_deg / w_deg))
    else:
        rows = long_side
        cols = max(6, round(long_side * w_deg / h_deg))

    edges = make_edges(kept, (lon0, lat0, lon1, lat1))
    grid_pts = np.empty((rows * cols * SUB * SUB, 2))
    i = 0
    for r in range(rows):
        for c in range(cols):
            for sy in range(SUB):
                for sx in range(SUB):
                    grid_pts[i, 0] = lon0 + (lon1 - lon0) \
                        * (c + (sx + 0.5) / SUB) / cols
                    grid_pts[i, 1] = lat1 - (lat1 - lat0) \
                        * (r + (sy + 0.5) / SUB) / rows
                    i += 1
    hit = contains(edges, grid_pts).reshape(rows, cols, SUB * SUB)
    cover = hit.sum(axis=2) / (SUB * SUB)
    grid = ["".join("#" if cover[r, c] >= COVERAGE else "."
                    for c in range(cols)) for r in range(rows)]
    rs = [i for i, row in enumerate(grid) if "#" in row]
    cs = [i for i in range(cols) if any(row[i] == "#" for row in grid)]
    if not rs:
        return None
    return [row[cs[0]:cs[-1] + 1] for row in grid[rs[0]:rs[-1] + 1]]


def main():
    with open(os.path.join(HERE, "ne_50m_countries.geojson"),
              encoding="utf-8") as f:
        world = json.load(f)
    out, skipped = [], []
    feats = sorted(world["features"],
                   key=lambda f: f["properties"]["ADMIN"])
    for feat in feats:
        p = feat["properties"]
        name = p["ADMIN"]
        grid = rasterize(feat["geometry"], CLIP_OVERRIDES.get(name))
        if grid is None or sum(r.count("#") for r in grid) < 4:
            skipped.append(name)
            continue
        out.append({
            "name": name,
            "ko": p.get("NAME_KO") or name,
            "continent": p.get("CONTINENT", ""),
            "rows": len(grid), "cols": len(grid[0]),
            "cells": sum(r.count("#") for r in grid),
            "grid": grid,
        })
        print(f"{len(out):3d} {name:35s} {len(grid)}x{len(grid[0])}"
              f" cells={sum(r.count('#') for r in grid)}")
    with open(os.path.join(HERE, "atlas_countries.json"), "w",
              encoding="utf-8") as f:
        json.dump({"shapes": out}, f, ensure_ascii=False)
    print(f"\nDONE countries={len(out)} skipped={len(skipped)}")
    if skipped:
        print("skipped:", ", ".join(skipped))


if __name__ == "__main__":
    main()
