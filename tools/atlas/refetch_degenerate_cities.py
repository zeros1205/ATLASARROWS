#!/usr/bin/env python3
"""Re-fetches city boundaries that collapsed into a bounding box.

`fetch_cities.py` requested Nominatim with `polygon_threshold=0.002`, a
Douglas-Peucker simplification in *degrees*. For a physically small city that
tolerance swallows the whole outline, so the cached polygon degenerated to a
4-5 point rectangle — 39 cities ended up as boxes, and their puzzle grids were
rasterized from those boxes (triangles/trapezoids, not real shapes).

This refetches those entries with **no** polygon_threshold, i.e. full vertex
detail, and only overwrites an entry when the new outline is genuinely richer.

    python tools/atlas/refetch_degenerate_cities.py [--min-pts 6] [--dry-run]

After it runs, regenerate the grids: python tools/atlas/raster_cities.py
"""
import argparse
import json
import math
import os
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "cities_raw.json")
BANK = os.path.join(HERE, "..", "..", "assets", "campaign", "bank.json")
UA = "atlas-arrows-city-boundaries/1.0 (contact: jax1205@gmail.com)"
SLEEP = 1.1  # Nominatim usage policy: <= 1 request/second

# Queries that need disambiguation beyond "<city>, <country>". Without these
# Nominatim happily returns a same-named village on another continent
# (Copenhagen, New York) or a district of the wrong city (Baguio in Davao).
QUERY_OVERRIDE = {
    "Archangel": "Arkhangelsk, Russia",
    "Basse-terre": "Basse-Terre, Guadeloupe",
    "Cordoba": "Córdoba, Córdoba, Argentina",
    "Córdoba": "Córdoba, Córdoba, Argentina",
    "Copenhagen": "København, Denmark",
    "Baguio": "Baguio, Benguet, Philippines",
    "Kyiv": "Київ, Ukraine",
    "Lviv": "Львів, Ukraine",
    "Sofia": "Sofia, Sofia-grad, Bulgaria",
    "Ulyanovsk": "Ульяновск, Russia",
    "Bukhara": "Buxoro, Buxoro Viloyati, Uzbekistan",
    "Mahajanga": "Mahajanga I, Boeny, Madagascar",
    "Antsiranana": "Antsiranana I, Madagascar",
    "Davao": "Davao City, Philippines",
    "Tirana": "Bashkia Tiranë, Albania",
    "Copenhagen": "Københavns Kommune, Denmark",
    "Baguio": "City of Baguio, Philippines",
}

# The city polygon must be a settlement, not the region that contains it.
GOOD_TYPES = {"city", "town", "municipality", "village", "borough", "suburb",
              "city_district", "district", "county"}
BAD_TYPES = {"state", "region", "province", "state_district"}
MAX_SPAN_KM = 150  # a city bigger than this is almost certainly a province

# Municipalities that legitimately administer far-flung islands, so their true
# bounding box dwarfs the built-up area. raster_cities.py clips these back to
# the mainland; without the exemption the span guard would reject them.
SPAN_EXEMPT = {"Kaohsiung"}


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
    w = (max(xs) - min(xs)) * 111 * math.cos(math.radians(lat))
    return max(w, (max(ys) - min(ys)) * 111)


def fetch(query, exempt_span=False):
    """Full-detail *settlement* boundary for `query`, or None.

    No polygon_threshold (that is what collapsed these to boxes originally).
    Ranks candidates so a city always beats the oblast/province of the same
    name, and rejects anything too large to be a city.
    """
    url = "https://nominatim.openstreetmap.org/search?" + urllib.parse.urlencode({
        "q": query, "format": "jsonv2", "limit": 10, "polygon_geojson": 1,
        "featureType": "settlement",
    })
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=45) as resp:
        results = json.load(resp)
    best = None
    for res in results:
        gj = res.get("geojson", {})
        if gj.get("type") not in ("Polygon", "MultiPolygon"):
            continue
        atype = (res.get("addresstype") or "").lower()
        if atype in BAD_TYPES:
            continue
        if not exempt_span and span_km(gj) > MAX_SPAN_KM:
            continue
        score = (atype in GOOD_TYPES, npoints(gj))
        if best is None or score > best[2]:
            best = (gj, res.get("display_name", ""), score)
    return best[:2] if best else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--min-pts", type=int, default=6,
                    help="entries with fewer points than this are refetched")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    with open(RAW, encoding="utf-8") as f:
        raw = json.load(f)
    with open(BANK, encoding="utf-8") as f:
        bank = json.load(f)["countries"]

    # city (english) -> country (english), so we can disambiguate the query
    country_of = {}
    for entry in bank:
        for stage in entry["stages"]:
            if stage.get("kind") == "city":
                country_of[stage["name"]] = entry["name"]

    targets = [n for n, v in raw.items() if npoints(v.get("geojson")) < args.min_pts]
    print(f"degenerate entries: {len(targets)}")
    if args.dry_run:
        for n in targets:
            print(f"  {n} ({npoints(raw[n]['geojson'])} pts)")
        return

    fixed = failed = 0
    for i, name in enumerate(targets, 1):
        query = QUERY_OVERRIDE.get(name) or f"{name}, {country_of.get(name, '')}".strip(", ")
        before = npoints(raw[name]["geojson"])
        try:
            got = fetch(query, exempt_span=name in SPAN_EXEMPT)
        except Exception as exc:  # network/ratelimit — report, keep the old value
            print(f"  [{i}/{len(targets)}] {name}: ERROR {type(exc).__name__} {exc}")
            failed += 1
            time.sleep(SLEEP)
            continue
        if not got or npoints(got[0]) <= before:
            got_n = npoints(got[0]) if got else 0
            print(f"  [{i}/{len(targets)}] {name}: no better polygon ({before} -> {got_n}) q={query!r}")
            failed += 1
        else:
            raw[name]["geojson"] = got[0]
            raw[name]["display"] = got[1]
            print(f"  [{i}/{len(targets)}] {name}: {before} -> {npoints(got[0])} pts")
            fixed += 1
        time.sleep(SLEEP)

    with open(RAW, "w", encoding="utf-8") as f:
        json.dump(raw, f, ensure_ascii=False)
    print(f"\nfixed {fixed}, still bad {failed}. Now run raster_cities.py to rebuild grids.")


if __name__ == "__main__":
    main()
