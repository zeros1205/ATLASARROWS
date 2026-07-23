"""Upsample the dotted world map to ~2x the dots, in place.

The proper source (build_worldmap.py) rasterises ne_50m_countries.geojson with
numpy/PIL. When that source geojson isn't checked out, this resamples the
already-baked worldmap.json onto a finer grid instead: a nearest-neighbour
lift that keeps the exact same country set, names, and projection, only denser.

It is deliberately a stopgap — the coastline detail is still the old grid's,
just drawn with more, smaller dots. Run build_worldmap.py (COLS=238) for a crisp
regen once the geojson is available. Output: assets/campaign/worldmap.json.

Every campaign country keeps at least one cell, because a nearest-neighbour lift
only ever adds cells — it can't drop the one dot a micro-state owns.
"""
import json
import os

HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = HERE + "/assets/campaign/worldmap.json"

# ~2x the cells: cols * sqrt(2), rows follows the same projection ratio.
NEW_COLS = 238

wm = json.load(open(SRC, encoding="utf-8"))
oc, orow = wm["cols"], wm["rows"]
cells = wm["cells"]
lat0, lat1 = wm["lat0"], wm["lat1"]
lon0, lon1 = wm["lon0"], wm["lon1"]

new_rows = round(NEW_COLS * (lat1 - lat0) / (lon1 - lon0))
new_cells = [0] * (NEW_COLS * new_rows)
for r in range(new_rows):
    # cell-centre of the new grid → nearest old cell (same projection, so this
    # is a plain ratio map).
    orr = min(int((r + 0.5) * orow / new_rows), orow - 1)
    for c in range(NEW_COLS):
        occ = min(int((c + 0.5) * oc / NEW_COLS), oc - 1)
        new_cells[r * NEW_COLS + c] = cells[orr * oc + occ]

before = {v for v in cells if v >= 0}
after = {v for v in new_cells if v >= 0}
assert before <= after, f"lost countries: {before - after}"

wm["cols"] = NEW_COLS
wm["rows"] = new_rows
wm["cells"] = new_cells
json.dump(wm, open(SRC, "w", encoding="utf-8"),
          ensure_ascii=False, separators=(",", ":"))

land_old = sum(1 for v in cells if v >= 0)
land_new = sum(1 for v in new_cells if v >= 0)
print(f"{oc}x{orow} -> {NEW_COLS}x{new_rows}  land {land_old} -> {land_new} "
      f"({land_new / land_old:.2f}x), countries {len(after)}")
