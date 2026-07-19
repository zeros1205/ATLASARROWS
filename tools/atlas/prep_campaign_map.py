"""Prep data for the country-as-round campaign map: for each demo country,
rasterize its outline to a dot grid and place city pins at their REAL
geographic coordinates. Output campaign_map_demo.json."""
import json
import math
import os
import sys

ATLAS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ATLAS)
import world_atlas as wa  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
countries = json.load(open(os.path.join(ATLAS, "ne_50m_countries.geojson"),
                           encoding="utf-8"))
places = json.load(open(os.path.join(ATLAS, "ne_50m_populated_places.geojson"),
                        encoding="utf-8"))

# demo countries: (NE ADMIN, ko, flag, optional clip bbox, cities cleared count)
DEMOS = [
    ("South Korea", "대한민국", "🇰🇷", (125.5, 33.0, 130.0, 38.7), 3),
    ("Japan", "일본", "🇯🇵", (128.5, 30.5, 146.2, 45.7), 1),
    ("Italy", "이탈리아", "🇮🇹", None, 0),
]


def feat(name):
    for f in countries["features"]:
        if f["properties"]["ADMIN"] == name:
            return f
    raise KeyError(name)


def cities_in(name, k=6):
    out = []
    for f in places["features"]:
        p = f["properties"]
        if (p.get("ADM0NAME") or p.get("SOV0NAME")) != name:
            continue
        lon, lat = f["geometry"]["coordinates"]
        out.append((p.get("NAME"), p.get("POP_MAX") or 0, lon, lat))
    out.sort(key=lambda t: -t[1])
    return out[:k]


KO_CITY = {
    "Seoul": "서울", "Busan": "부산", "Incheon": "인천", "Daegu": "대구",
    "Daejeon": "대전", "Gwangju": "광주", "Tokyo": "도쿄", "Osaka": "오사카",
    "Nagoya": "나고야", "Sapporo": "삿포로", "Fukuoka": "후쿠오카", "Kyoto": "교토",
    "Ōsaka": "오사카", "Sendai": "센다이", "Yokohama": "요코하마",
    "Rome": "로마", "Milan": "밀라노", "Naples": "나폴리", "Turin": "토리노",
    "Palermo": "팔레르모", "Genoa": "제노바", "Venice": "베네치아", "Florence": "피렌체",
}

out = []
for name, ko, flag, clip, cleared in DEMOS:
    geom = feat(name)["geometry"]
    grid = wa.rasterize(geom, clip)
    # recover the bbox the rasterizer used (replicate its framing)
    if clip:
        lon0, lat0, lon1, lat1 = clip
    else:
        polys = wa.unwrap(wa.rings_of(geom))
        _, (lon0, lat0, lon1, lat1) = wa.frame(polys, None)
    cs = cities_in(name)
    pins = []
    for i, (cn, pop, lon, lat) in enumerate(cs):
        pins.append({
            "name": cn, "ko": KO_CITY.get(cn, cn),
            "u": (lon - lon0) / (lon1 - lon0),        # 0..1 left→right
            "v": (lat1 - lat) / (lat1 - lat0),        # 0..1 top→bottom
            "done": i < cleared,
            "cur": i == cleared,
        })
    out.append({"name": name, "ko": ko, "flag": flag,
                "rows": len(grid), "cols": len(grid[0]), "grid": grid,
                "cleared": cleared, "total": len(pins), "pins": pins})
    print(f"{ko:6} {len(grid)}x{len(grid[0])}  pins: "
          + ", ".join(f"{p['ko']}({p['u']:.2f},{p['v']:.2f})" for p in pins))

json.dump({"countries": out}, open(os.path.join(HERE, "campaign_map_demo.json"),
          "w", encoding="utf-8"), ensure_ascii=False)
print("-> campaign_map_demo.json")
