"""Bake an approximate map pin for each campaign stage.

The map's next-stage radar wants to sit on the actual place a stage depicts,
not just its country. City silhouettes carry real geometry in cities_raw.json,
so we take each city polygon's centroid, project it into the same
equirectangular grid as worldmap.json, and emit one [col,row] per global stage
(null for path/country stages — the app falls back to the country centroid).

It is deliberately approximate: the map is a coarse dot grid, so a vertex-mean
centroid is close enough and avoids an area-weighted pass. Output:
assets/campaign/city_pins.json — a flat list aligned to the global stage index.
"""
import json
import os

HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

wm = json.load(open(HERE + "/assets/campaign/worldmap.json", encoding="utf-8"))
COLS, ROWS = wm["cols"], wm["rows"]
LON0, LON1 = wm["lon0"], wm["lon1"]
LAT0, LAT1 = wm["lat0"], wm["lat1"]

cities = json.load(open(HERE + "/tools/atlas/cities_raw.json", encoding="utf-8"))
bank = json.load(open(HERE + "/assets/campaign/bank.json", encoding="utf-8"))


def ring_centroid(ring):
    pts = ring[:-1] if len(ring) > 1 and ring[0] == ring[-1] else ring
    n = len(pts)
    return (sum(p[0] for p in pts) / n, sum(p[1] for p in pts) / n)


def geom_centroid(geo):
    coords = geo["coordinates"]
    if geo["type"] == "Polygon":
        return ring_centroid(coords[0])
    # MultiPolygon: the largest ring is a good stand-in for the whole shape.
    biggest = max((poly[0] for poly in coords), key=len)
    return ring_centroid(biggest)


def to_cell(lon, lat):
    # Inverse of worldmap's cell-centre projection, so (col+.5, row+.5) lands on
    # this lon/lat. row 0 = north (LAT1).
    c = (lon - LON0) / (LON1 - LON0) * COLS - 0.5
    r = (LAT1 - lat) / (LAT1 - LAT0) * ROWS - 0.5
    c = min(max(c, 0.0), COLS - 1.0)
    r = min(max(r, 0.0), ROWS - 1.0)
    return [round(c, 2), round(r, 2)]


pins = []
hit = miss = 0
for country in bank["countries"]:
    for stage in country["stages"]:
        pin = None
        if stage.get("kind") == "city":
            city = cities.get(stage.get("name"))
            if city and isinstance(city.get("geojson"), dict):
                lon, lat = geom_centroid(city["geojson"])
                pin = to_cell(lon, lat)
                hit += 1
            else:
                miss += 1
        pins.append(pin)

out = {"cols": COLS, "rows": ROWS, "pins": pins}
json.dump(out, open(HERE + "/assets/campaign/city_pins.json", "w", encoding="utf-8"),
          ensure_ascii=False, separators=(",", ":"))
print(f"stages {len(pins)}, city pins {hit}, city misses {miss}")
