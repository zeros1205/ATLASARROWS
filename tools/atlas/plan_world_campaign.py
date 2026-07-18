"""Feasibility analysis for the World-Map Exploration campaign.

Grounds the plan in real numbers:
  1. spherical area per country -> the difficulty ramp (small first)
  2. major cities per country from Natural Earth populated places
     -> how many countries can field >=5 city levels

Outputs a summary + writes world_campaign_order.json (country order +
picked cities) for later pipeline stages.

Usage: python tools/atlas/plan_world_campaign.py
"""
import json
import math
import os
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
COUNTRIES = os.path.join(HERE, "ne_50m_countries.geojson")
PLACES = os.path.join(HERE, "ne_50m_populated_places.geojson")
PLACES_URL = ("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
              "master/geojson/ne_50m_populated_places.geojson")
R = 6371.0  # km


def spherical_area(rings):
    """Signed spherical polygon area (km^2), summed over outer rings only."""
    total = 0.0
    for ring in rings:
        s = 0.0
        for i in range(len(ring) - 1):
            lon1, lat1 = math.radians(ring[i][0]), math.radians(ring[i][1])
            lon2, lat2 = math.radians(ring[i + 1][0]), math.radians(ring[i + 1][1])
            s += (lon2 - lon1) * (2 + math.sin(lat1) + math.sin(lat2))
        total += abs(s * R * R / 2.0)
    return total


def outer_rings(geom):
    if geom["type"] == "Polygon":
        return [geom["coordinates"][0]]
    return [poly[0] for poly in geom["coordinates"]]


def main():
    if not os.path.exists(PLACES):
        print("downloading populated places...")
        urllib.request.urlretrieve(PLACES_URL, PLACES)

    world = json.load(open(COUNTRIES, encoding="utf-8"))
    places = json.load(open(PLACES, encoding="utf-8"))

    # country area
    areas = {}
    for f in world["features"]:
        p = f["properties"]
        name = p["ADMIN"]
        if name in ("Antarctica",):
            continue
        areas[name] = spherical_area(outer_rings(f["geometry"]))

    # cities per country (match on ADM0NAME / SOV0NAME)
    cities = {}
    for f in places["features"]:
        p = f["properties"]
        c = p.get("ADM0NAME") or p.get("SOV0NAME")
        if not c:
            continue
        pop = p.get("POP_MAX") or p.get("POP_MIN") or 0
        cities.setdefault(c, []).append((p.get("NAME"), pop))
    for c in cities:
        cities[c].sort(key=lambda t: -t[1])

    # align city-country names to country-area names where trivially different
    ALIAS = {
        "United States of America": "United States of America",
        "United States": "United States of America",
    }
    def area_of(c):
        return areas.get(c) or areas.get(ALIAS.get(c, ""), None)

    ranked = sorted((c for c in areas), key=lambda c: areas[c])
    n = len(ranked)
    have5 = sum(1 for c in ranked if len(cities.get(c, [])) >= 5)
    have3 = sum(1 for c in ranked if len(cities.get(c, [])) >= 3)
    have1 = sum(1 for c in ranked if len(cities.get(c, [])) >= 1)
    total_top5 = sum(min(5, len(cities.get(c, []))) for c in ranked)

    print(f"countries (excl. Antarctica): {n}")
    print(f"  with >=5 cities: {have5}   >=3: {have3}   >=1: {have1}")
    print(f"  total levels if top-5/country: {total_top5}")
    print("\n--- EASY END (smallest area, first 16) ---")
    for c in ranked[:16]:
        print(f"  {areas[c]:>12,.0f} km2  {len(cities.get(c, [])):>2} cities  {c}")
    print("\n--- HARD END (largest area, last 12) ---")
    for c in ranked[-12:]:
        top = ", ".join(t[0] for t in cities.get(c, [])[:5])
        print(f"  {areas[c]:>13,.0f} km2  {len(cities.get(c, [])):>2} cities  {c}"
              f"  [{top}]")

    order = [{
        "rank": i + 1, "country": c, "area_km2": round(areas[c]),
        "cities": [t[0] for t in cities.get(c, [])[:6]],
    } for i, c in enumerate(ranked)]
    json.dump({"countries": order}, open(
        os.path.join(HERE, "world_campaign_order.json"), "w", encoding="utf-8"),
        ensure_ascii=False, indent=1)
    print("\n-> world_campaign_order.json")


if __name__ == "__main__":
    main()
