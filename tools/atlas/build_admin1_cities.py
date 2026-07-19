"""Builds the admin-1 hub-city list for the campaign.

For every campaign country, picks the most populous city in each admin-1
region (US state, Chinese province, Russian oblast, ...) from Natural Earth
populated places. That is the "거점 도시" set: big countries get one stage
per state/province, which is what makes them late-game boss rounds.

Output: admin1_cities.json  [{country, adm1, name, ko, pop, lat, lon, query}]
Feeds fetch_admin1_cities.py, which pulls the OSM boundary polygons.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))

PLACES = os.path.join(HERE, "ne_50m_populated_places.geojson")
CAMPAIGN = os.path.join(REPO, "assets", "campaign", "campaign.json")
EXISTING = os.path.join(HERE, "atlas_cities.json")
OUT = os.path.join(HERE, "admin1_cities.json")


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def main():
    places = load(PLACES)["features"]
    campaign = {c["name"]: c for c in load(CAMPAIGN)["countries"]}
    have = {s["name"] for s in load(EXISTING)["shapes"]}

    # admin-1 별 최다 인구 도시 = 그 지역의 거점
    best = {}
    for f in places:
        p = f["properties"]
        country, adm1 = p.get("ADM0NAME"), p.get("ADM1NAME")
        if country not in campaign or not adm1:
            continue
        pop = p.get("POP_MAX") or 0
        key = (country, adm1)
        if key not in best or pop > best[key][0]:
            best[key] = (pop, p)

    rows = []
    for (country, adm1), (pop, p) in sorted(
            best.items(), key=lambda kv: (-kv[1][0], kv[0])):
        name = p["NAME"]
        rows.append({
            "country": country,
            "ko_country": campaign[country].get("ko", country),
            "adm1": adm1,
            "name": name,
            "ko": p.get("NAME_KO") or name,
            "pop": pop,
            "lat": p.get("LATITUDE"),
            "lon": p.get("LONGITUDE"),
            # Nominatim 질의: 도시 + 상위 행정구역 + 국가 (동명이인 방지)
            "query": f"{name}, {adm1}, {country}",
            "have_mask": name in have,
        })

    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"cities": rows}, f, ensure_ascii=False, indent=1)

    todo = [r for r in rows if not r["have_mask"]]
    per = {}
    for r in rows:
        per[r["country"]] = per.get(r["country"], 0) + 1
    top = sorted(per.items(), key=lambda kv: -kv[1])[:10]

    print(f"admin-1 거점도시 {len(rows)}개 / {len(per)}개국")
    print(f"  마스크 보유 {len(rows) - len(todo)} · 수집 필요 {len(todo)}")
    print("  상위:", ", ".join(f"{k} {v}" for k, v in top))
    print(f"-> {OUT}")


if __name__ == "__main__":
    main()
