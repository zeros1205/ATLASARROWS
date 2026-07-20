#!/usr/bin/env python3
"""Fetches OSM boundaries for countries Natural Earth renders as blobs.

Even at 10m, Natural Earth carries city-states and small islands as a handful
of points — Vatican 7, Nauru 9, Monaco 12 — so they draw as featureless
polygons. The campaign is ordered by ascending area, so these are exactly the
first stages a player sees. OSM has proper boundaries for them, the same source
already used for cities.

Output: countries_raw.json  {country_en: {ko, geojson, display}}
Consumers prefer this over Natural Earth when an entry exists.

    python tools/atlas/fetch_microstate_shapes.py [--max-pts 40]
"""
import argparse
import json
import math
import os
import re
import time
import unicodedata
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
NE10 = os.path.join(HERE, "ne_10m_countries.geojson")
OUT = os.path.join(HERE, "countries_raw.json")
BANK = os.path.join(HERE, "..", "..", "assets", "campaign", "bank.json")
UA = "atlas-arrows-country-boundaries/1.0 (contact: jax1205@gmail.com)"
SLEEP = 1.1

QUERY_OVERRIDE = {
    "Vatican": "Vatican City",
    "Saint Barthelemy": "Saint-Barthélemy",
    "Saint Martin": "Saint-Martin, France",
    "Pitcairn Islands": "Pitcairn Islands",
    "Ashmore and Cartier Islands": "Ashmore and Cartier Islands, Australia",
}
# Disputed / no administrative boundary exists in OSM.
# Sint Maarten: OSM only yields the French half (Saint-Martin) for every
# query tried, and a wrong territory is worse than a coarse one, so it stays
# on Natural Earth.
SKIP = {"Siachen Glacier", "Sint Maarten"}
MAX_SPAN_KM = 900  # island groups spread out; still rejects a whole continent


def norm(s):
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]", "", s)


def npoints(gj):
    t = (gj or {}).get("type")
    if t == "Polygon":
        return sum(len(r) for r in gj["coordinates"])
    if t == "MultiPolygon":
        return sum(len(r) for p in gj["coordinates"] for r in p)
    return 0


def span_km(gj):
    t = gj["type"]
    pts = ([p for r in gj["coordinates"] for p in r] if t == "Polygon"
           else [p for poly in gj["coordinates"] for r in poly for p in r])
    xs = [a for a, _ in pts]
    ys = [b for _, b in pts]
    lat = (min(ys) + max(ys)) / 2
    return max((max(xs) - min(xs)) * 111 * math.cos(math.radians(lat)),
               (max(ys) - min(ys)) * 111)


def circularity(gj):
    """4*pi*area/perimeter^2 of the largest ring: 1.0 is a perfect circle.

    Tiny islands often resolve to their 12-nautical-mile territorial-water
    boundary, which comes back as a near-perfect circle (Nauru, Norfolk,
    Ashmore). Real coastlines never score above ~0.75.
    """
    t = gj["type"]
    rings = ([gj["coordinates"][0]] if t == "Polygon"
             else [p[0] for p in gj["coordinates"]])
    best = 0.0
    for r in rings:
        if len(r) < 4:
            continue
        lat = sum(p[1] for p in r) / len(r)
        k = math.cos(math.radians(lat))
        pts = [(x * k * 111, y * 111) for x, y in r]
        a = per = 0.0
        for i in range(len(pts) - 1):
            x1, y1 = pts[i]
            x2, y2 = pts[i + 1]
            a += x1 * y2 - x2 * y1
            per += math.hypot(x2 - x1, y2 - y1)
        a = abs(a) / 2
        if per > 0 and a > best:
            best = a
            circ = 4 * math.pi * a / (per * per)
    return circ if best else 0.0


def _search(query):
    url = "https://nominatim.openstreetmap.org/search?" + urllib.parse.urlencode({
        "q": query, "format": "jsonv2", "limit": 15, "polygon_geojson": 1,
    })
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def fetch(query):
    """Best non-circular boundary for `query`.

    For a small island the administrative relation is its 12-nautical-mile
    territorial water, which comes back as a circle. The landmass lives under
    place=island instead, so that is asked for too and preferred.
    """
    results = _search(query)
    island_q = query.split(",")[0].strip() + " island"
    time.sleep(SLEEP)
    results += _search(island_q)
    best = None
    for res in results:
        gj = res.get("geojson", {})
        if gj.get("type") not in ("Polygon", "MultiPolygon"):
            continue
        if span_km(gj) > MAX_SPAN_KM:
            continue
        # administrative boundaries only — not a hotel called "Monaco"
        if res.get("category") not in ("boundary", "place"):
            continue
        if circularity(gj) > 0.85:
            continue  # territorial waters, not the island
        # a real landmass outranks any administrative area of the same name
        score = (res.get("type") == "island", npoints(gj))
        if best is None or score > best[2]:
            best = (gj, res.get("display_name", ""), score)
    return best[:2] if best else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--max-pts", type=int, default=40)
    args = ap.parse_args()

    ne = json.load(open(NE10, encoding="utf-8"))["features"]
    bank = json.load(open(BANK, encoding="utf-8"))["countries"]
    by_name, by_iso = {}, {}
    for f in ne:
        p = f["properties"]
        for k in ("ADMIN", "NAME", "NAME_LONG", "GEOUNIT", "BRK_NAME"):
            if p.get(k):
                by_name.setdefault(norm(p[k]), f)
        for k in ("ISO_A2", "ISO_A2_EH"):
            v = p.get(k)
            if v and v != "-99":
                by_iso.setdefault(v, f)

    def ne_pts(f):
        g = f["geometry"]
        polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        return sum(len(r) for p in polys for r in p)

    targets = []
    for e in bank:
        f = by_name.get(norm(e["name"])) or by_iso.get(e["iso"])
        if f and ne_pts(f) < args.max_pts and e["name"] not in SKIP:
            targets.append((e["name"], e["ko"], ne_pts(f)))

    out = {}
    if os.path.exists(OUT):
        out = json.load(open(OUT, encoding="utf-8"))
    print(f"{len(targets)} countries below {args.max_pts} points at 10m")
    for i, (name, ko, before) in enumerate(targets, 1):
        query = QUERY_OVERRIDE.get(name, name)
        try:
            got = fetch(query)
        except Exception as exc:
            print(f"  [{i}/{len(targets)}] {name}: ERROR {type(exc).__name__} {exc}")
            time.sleep(SLEEP)
            continue
        if not got or npoints(got[0]) <= before:
            print(f"  [{i}/{len(targets)}] {name}: no better ({before} -> "
                  f"{npoints(got[0]) if got else 0}) q={query!r}")
        else:
            out[name] = {"ko": ko, "geojson": got[0], "display": got[1]}
            print(f"  [{i}/{len(targets)}] {name}: {before} -> {npoints(got[0])} pts")
        time.sleep(SLEEP)

    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)
    print(f"\n{len(out)} entries -> {OUT}")


if __name__ == "__main__":
    main()
