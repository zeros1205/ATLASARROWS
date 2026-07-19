"""Fetches OSM admin-boundary polygons for the admin-1 hub cities.

Reads admin1_cities.json (from build_admin1_cities.py) and pulls one boundary
per city from Nominatim, 1.2s apart per their usage policy. Results append to
cities_raw.json, the same cache fetch_cities.py writes, so raster_cities.py
turns the whole set into masks unchanged.

Resumable: anything already in the cache is skipped, so re-running after an
interruption only fetches what is missing.
"""
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
LIST = os.path.join(HERE, "admin1_cities.json")
CACHE = os.path.join(HERE, "cities_raw.json")
MISSES = os.path.join(HERE, "admin1_misses.json")

UA = "atlas-arrows-level-research/0.1 (contact: jax1205@gmail.com)"
DELAY = 1.2  # Nominatim usage policy: max 1 req/sec, keep headroom


def fetch(q):
    url = ("https://nominatim.openstreetmap.org/search?"
           + urllib.parse.urlencode({
               "q": q, "format": "jsonv2", "limit": 5,
               "polygon_geojson": 1, "polygon_threshold": 0.002,
           }))
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=45) as resp:
        results = json.load(resp)
    for res in results:
        gj = res.get("geojson", {})
        if gj.get("type") in ("Polygon", "MultiPolygon"):
            return gj, res.get("display_name", "")
    return None, None


def load(path, default):
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    os.replace(tmp, path)


def main():
    cities = load(LIST, {"cities": []})["cities"]
    cache = load(CACHE, {})
    misses = load(MISSES, {})

    todo = [c for c in cities if c["name"] not in cache
            and c["name"] not in misses]
    print(f"목표 {len(cities)} · 캐시 {len(cache)} · 이번에 받을 것 {len(todo)}",
          flush=True)

    ok = fail = 0
    for i, c in enumerate(todo, 1):
        name = c["name"]
        try:
            gj, display = fetch(c["query"])
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            print(f"ERR  {name}: {e}", flush=True)
            time.sleep(DELAY * 2)
            continue
        if gj is None:
            misses[name] = c["query"]
            fail += 1
            print(f"MISS {i}/{len(todo)} {name} ({c['country']})", flush=True)
            save(MISSES, misses)
        else:
            cache[name] = {"ko": c["ko"], "geojson": gj, "display": display}
            ok += 1
            print(f"OK   {i}/{len(todo)} {name} ({c['country']}) "
                  f"{json.dumps(gj).count('[')}pts", flush=True)
            save(CACHE, cache)
        time.sleep(DELAY)

    print(f"\nDONE 수집 {ok} · 실패 {fail} · 캐시 총 {len(cache)}", flush=True)


if __name__ == "__main__":
    main()
