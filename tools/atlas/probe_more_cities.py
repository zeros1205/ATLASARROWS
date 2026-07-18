"""Probe OSM admin-boundary availability for the two expansion levers:
  A) mid/small cities (does the shape exist as pop drops?)
  B) mega-city districts/boroughs (recognizable extra levels for giants)
Small sample, 1.2s between calls (Nominatim policy). Reports hit rate.
"""
import json
import sys
import time
import urllib.parse
import urllib.request

UA = "z-arrows-level-research/0.1 (contact: jax1205@gmail.com)"

MID = [  # (query, approx pop) — mid/small cities
    ("Reims, France", 180000), ("Kanazawa, Japan", 460000),
    ("Salerno, Italy", 130000), ("Tampere, Finland", 240000),
    ("Coimbra, Portugal", 100000), ("Galway, Ireland", 80000),
    ("Bergen, Norway", 280000), ("Cuenca, Ecuador", 330000),
]
DISTRICTS = [  # mega-city sub-units — recognizable, distinct shapes
    ("Manhattan, New York", 0), ("Brooklyn, New York", 0),
    ("Shibuya, Tokyo", 0), ("Setagaya, Tokyo", 0),
    ("Gangnam-gu, Seoul", 0), ("Westminster, London", 0),
    ("Camden, London", 0), ("16th arrondissement, Paris", 0),
]


def probe(q):
    url = ("https://nominatim.openstreetmap.org/search?"
           + urllib.parse.urlencode({
               "q": q, "format": "jsonv2", "limit": 3,
               "polygon_geojson": 1, "polygon_threshold": 0.002}))
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            res = json.load(r)
    except Exception as e:
        return None, str(e)[:30]
    for x in res:
        gj = x.get("geojson", {})
        if gj.get("type") in ("Polygon", "MultiPolygon"):
            npts = json.dumps(gj).count("[")
            return npts, x.get("type", "")
    return 0, "no polygon"


def run(name, items):
    hits = 0
    print(f"\n=== {name} ===")
    for q, _ in items:
        n, note = probe(q)
        ok = n and n > 0
        hits += 1 if ok else 0
        print(f"  {'OK ' if ok else 'MISS'} {q:<30} {note} ({n} pts)")
        time.sleep(1.2)
    print(f"  -> {hits}/{len(items)} = {hits/len(items):.0%}")
    return hits, len(items)


ha, na = run("A) mid/small cities", MID)
hb, nb = run("B) mega-city districts", DISTRICTS)
print(f"\nSUMMARY  mid-cities {ha}/{na} ({ha/na:.0%})   "
      f"districts {hb}/{nb} ({hb/nb:.0%})")
