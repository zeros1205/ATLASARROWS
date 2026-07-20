#!/usr/bin/env python3
"""Checks every cached city boundary actually sits in the country it belongs to.

Nominatim happily answers "Copenhagen, Denmark" with the village of Copenhagen
in the *town of Denmark*, New York, because both tokens match exactly while the
real capital is named Kobenhavn. That entry was caught only because it was also
a degenerate box; a wrong match with a plausible polygon would pass unnoticed.

So: take each city's polygon centroid and test it against the Natural Earth
polygon of the country its stage belongs to. Anything outside (beyond a small
tolerance for coastal/boundary slop) is reported with the distance, worst first.

    python tools/atlas/verify_city_countries.py [--tolerance-km 25]

Needs ne_50m_countries.geojson beside this script (see docs/DATA_SOURCES.md).
"""
import argparse
import json
import math
import os
import re
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "cities_raw.json")
NE = os.path.join(HERE, "ne_50m_countries.geojson")
BANK = os.path.join(HERE, "..", "..", "assets", "campaign", "bank.json")


def norm(s):
    if not s:
        return ""
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]", "", s)


def polygons(geom):
    return [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]


def outer_rings(geom):
    return [poly[0] for poly in polygons(geom)]


def centroid(geom):
    """Area-weighted centroid over outer rings — robust for multi-part cities."""
    best_area, best = 0.0, None
    for ring in outer_rings(geom):
        a = cx = cy = 0.0
        for i in range(len(ring) - 1):
            x1, y1 = ring[i]
            x2, y2 = ring[i + 1]
            cross = x1 * y2 - x2 * y1
            a += cross
            cx += (x1 + x2) * cross
            cy += (y1 + y2) * cross
        a *= 0.5
        if abs(a) > best_area:
            best_area = abs(a)
            best = (cx / (6 * a), cy / (6 * a)) if a else tuple(ring[0])
    if best is None:
        ring = outer_rings(geom)[0]
        best = (sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring))
    return best


def in_ring(pt, ring):
    x, y = pt
    inside = False
    for i in range(len(ring) - 1):
        x1, y1 = ring[i]
        x2, y2 = ring[i + 1]
        if (y1 > y) != (y2 > y):
            xin = (x2 - x1) * (y - y1) / (y2 - y1) + x1
            if x < xin:
                inside = not inside
    return inside


def dist_km_to_ring(pt, ring):
    x, y = pt
    k = math.cos(math.radians(y))
    best = float("inf")
    for i in range(len(ring) - 1):
        ax, ay = ring[i]
        bx, by = ring[i + 1]
        ax, bx, px = ax * k, bx * k, x * k
        dx, dy = bx - ax, by - ay
        L = dx * dx + dy * dy
        t = 0.0 if L == 0 else max(0.0, min(1.0, ((px - ax) * dx + (y - ay) * dy) / L))
        best = min(best, math.hypot(px - (ax + t * dx), y - (ay + t * dy)))
    return best * 111.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tolerance-km", type=float, default=25.0)
    args = ap.parse_args()

    raw = json.load(open(RAW, encoding="utf-8"))
    ne = json.load(open(NE, encoding="utf-8"))["features"]
    bank = json.load(open(BANK, encoding="utf-8"))["countries"]

    by_iso, by_name = {}, {}
    for f in ne:
        p = f["properties"]
        for key in ("ISO_A2", "ISO_A2_EH"):
            v = p.get(key)
            if v and v != "-99":
                by_iso.setdefault(v, f)
        for key in ("ADMIN", "NAME", "NAME_LONG", "GEOUNIT", "BRK_NAME"):
            if p.get(key):
                by_name.setdefault(norm(p[key]), f)

    stages = {}
    for e in bank:
        for s in e["stages"]:
            if s.get("kind") == "city":
                stages[s["name"]] = (e["name"], e["iso"], s.get("ko", ""))

    checked = ok = 0
    bad, nocountry = [], []
    for city, (ctry, iso, ko) in stages.items():
        entry = raw.get(city)
        if not entry:
            continue
        feat = by_name.get(norm(ctry)) or by_iso.get(iso)
        if not feat:
            nocountry.append((city, ctry))
            continue
        checked += 1
        pt = centroid(entry["geojson"])
        rings = outer_rings(feat["geometry"])
        if any(in_ring(pt, r) for r in rings):
            ok += 1
            continue
        d = min(dist_km_to_ring(pt, r) for r in rings)
        if d <= args.tolerance_km:
            ok += 1
            continue
        bad.append((d, city, ko, ctry, pt, entry.get("display", "")[:60]))

    bad.sort(reverse=True)
    print(f"checked {checked} city stages against their country border")
    print(f"  inside (or within {args.tolerance_km:g} km): {ok}")
    print(f"  OUTSIDE: {len(bad)}")
    if nocountry:
        print(f"  country polygon not found for {len(nocountry)}: {nocountry}")
    if bad:
        print("\n  city            km outside  country            centroid            matched as")
        for d, city, ko, ctry, pt, disp in bad:
            print(f"  {city:15} {d:9.0f}  {ctry:18} {pt[0]:7.2f},{pt[1]:6.2f}  {disp}")


if __name__ == "__main__":
    main()
