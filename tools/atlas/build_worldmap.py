"""Bake a dotted world map: rasterize ne_50m_countries into an equirectangular
dot grid. Each cell = index into `names` (ADMIN country) or -1 for sea.
Output: assets/campaign/worldmap.json (+ a preview PNG to eyeball it)."""
import json, os, numpy as np
from PIL import Image, ImageDraw

# repo root, derived from this file's location (tools/atlas/ → ../..)
HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
COLS = 238  # ~2x the dots vs the original 168; keep in sync with the shipped asset

LON0, LON1 = -180.0, 180.0
LAT0, LAT1 = -58.0, 90.0          # crop out Antarctica, keep the full north edge
ROWS = round(COLS * (LAT1 - LAT0) / (LON1 - LON0))

g = json.load(open(HERE + "/tools/atlas/ne_50m_countries.geojson", encoding="utf-8"))

# grid cell centres, row 0 = north (LAT1)
lons = LON0 + (np.arange(COLS) + 0.5) / COLS * (LON1 - LON0)
lats = LAT1 - (np.arange(ROWS) + 0.5) / ROWS * (LAT1 - LAT0)
GX, GY = np.meshgrid(lons, lats)          # (ROWS, COLS)
gx = GX.ravel(); gy = GY.ravel()
N = gx.size
cell = np.full(N, -1, dtype=np.int32)     # -1 = sea

def pip(px, py, ring):
    """vectorised crossing-number point-in-polygon for many points vs one ring."""
    vx = np.asarray([p[0] for p in ring]); vy = np.asarray([p[1] for p in ring])
    inside = np.zeros(px.size, dtype=bool)
    j = len(vx) - 1
    for i in range(len(vx)):
        cond = ((vy[i] > py) != (vy[j] > py)) & (
            px < (vx[j] - vx[i]) * (py - vy[i]) / (vy[j] - vy[i] + 1e-12) + vx[i])
        inside ^= cond
        j = i
    return inside

names = []
name_ix = {}
for feat in g["features"]:
    admin = feat["properties"].get("ADMIN") or feat["properties"].get("NAME") or "?"
    geom = feat["geometry"]
    polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
    if admin not in name_ix:
        name_ix[admin] = len(names); names.append(admin)
    idx = name_ix[admin]
    for poly in polys:
        ext = poly[0]; holes = poly[1:]
        ax = np.asarray([p[0] for p in ext]); ay = np.asarray([p[1] for p in ext])
        # bbox prefilter: only test unassigned grid points inside this polygon's bbox
        sel = (cell == -1) & (gx >= ax.min()) & (gx <= ax.max()) & (gy >= ay.min()) & (gy <= ay.max())
        si = np.nonzero(sel)[0]
        if si.size == 0:
            continue
        px, py = gx[si], gy[si]
        inside = pip(px, py, ext)
        for h in holes:
            inside &= ~pip(px, py, h)
        cell[si[inside]] = idx

# Guarantee every campaign country owns >=1 cell (micro-states like Monaco are
# too small for the grid) by stamping its centroid cell.
camp = set(c["name"] for c in json.load(
    open(HERE + "/assets/campaign/campaign.json", encoding="utf-8"))["countries"])
present = set(int(v) for v in np.unique(cell) if v >= 0)
for feat in g["features"]:
    admin = feat["properties"].get("ADMIN") or feat["properties"].get("NAME") or "?"
    if admin not in camp:
        continue
    idx = name_ix[admin]
    if idx in present:
        continue
    geom = feat["geometry"]
    polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
    ext = max((p[0] for p in polys), key=len)
    cx = sum(pt[0] for pt in ext) / len(ext)
    cy = sum(pt[1] for pt in ext) / len(ext)
    c = min(max(int((cx - LON0) / (LON1 - LON0) * COLS), 0), COLS - 1)
    r = min(max(int((LAT1 - cy) / (LAT1 - LAT0) * ROWS), 0), ROWS - 1)
    cell[r * COLS + c] = idx
    present.add(idx)

land = int((cell >= 0).sum())
out = {"cols": COLS, "rows": ROWS, "lon0": LON0, "lon1": LON1,
       "lat0": LAT0, "lat1": LAT1, "names": names,
       "cells": cell.tolist()}
json.dump(out, open(HERE + "/assets/campaign/worldmap.json", "w", encoding="utf-8"),
          ensure_ascii=False, separators=(",", ":"))
print(f"grid {COLS}x{ROWS} = {N} cells, land {land} ({land*100//N}%), countries {len(names)}")

# preview PNG
SC = 7
im = Image.new("RGB", (COLS * SC, ROWS * SC), (247, 246, 242))
d = ImageDraw.Draw(im)
c2 = cell.reshape(ROWS, COLS)
for r in range(ROWS):
    for c in range(COLS):
        x, y = c * SC + SC / 2, r * SC + SC / 2
        col = (35, 37, 46) if c2[r, c] >= 0 else (225, 224, 218)
        rr = SC * 0.34 if c2[r, c] >= 0 else SC * 0.16
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=col)
im.save(HERE + "/tools/atlas/worldmap_preview.png")
print("preview saved")
