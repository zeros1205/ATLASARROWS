"""Estimates the FINAL playable level count for the world campaign under
several scenarios, from real data (world_campaign_order.json) + attrition
assumptions (OSM boundary availability, 80-cell mask floor).

Usage: python tools/atlas/estimate_levels.py
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
order = json.load(open(os.path.join(HERE, "world_campaign_order.json"),
                      encoding="utf-8"))["countries"]

# area-tier -> target city levels per country
def tier_cap(area):
    if area < 500:        return 1     # micro / city-state
    if area < 50_000:     return 3     # small
    if area < 500_000:    return 5     # mid
    if area < 2_000_000:  return 8     # large
    return 12                          # giant boss chapter

# attrition: OSM admin-boundary hit rate, then 80-cell mask-floor survival
OSM_HIT = 0.82
FLOOR_KEEP = 0.90


def scenario(name, cap_fn, use_attrition):
    raw = 0
    for c in order:
        avail = len(c["cities"])          # cities we actually have in NE
        raw += min(avail, cap_fn(c["area_km2"]))
    if not use_attrition:
        return name, raw, raw
    final = round(raw * OSM_HIT * FLOOR_KEEP)
    return name, raw, final


def scenario_full(name, cap_fn, use_attrition):
    """Ceiling: assume a richer city DB (GeoNames) can supply the full cap
    for every country that has at least one city today."""
    raw = sum(cap_fn(c["area_km2"]) for c in order if c["cities"])
    final = round(raw * OSM_HIT * FLOOR_KEEP) if use_attrition else raw
    return name, raw, final


rows = [
    scenario("top-5 flat, NE data (no attrition)", lambda a: 5, False),
    scenario("top-5 flat, NE data (after attrition)", lambda a: 5, True),
    scenario("tiered, NE data (no attrition)", tier_cap, False),
    scenario("tiered, NE data (after attrition)", tier_cap, True),
    scenario_full("tiered, rich DB ceiling (no attrition)", tier_cap, False),
    scenario_full("tiered, rich DB ceiling (after attrition)", tier_cap, True),
]

playable_countries = sum(1 for c in order if c["cities"])
giants = [c for c in order if c["area_km2"] >= 2_000_000 and c["cities"]]

print(f"countries with >=1 city: {playable_countries} / {len(order)}")
print(f"giant boss chapters (>=2M km2): {len(giants)} -> "
      + ", ".join(g['country'] for g in giants))
print(f"attrition applied: OSM hit {OSM_HIT:.0%} x floor keep {FLOOR_KEEP:.0%}"
      f" = {OSM_HIT*FLOOR_KEEP:.0%}\n")
print(f"{'scenario':<42}{'raw':>8}{'final':>8}")
print("-" * 58)
for name, raw, final in rows:
    print(f"{name:<42}{raw:>8}{final:>8}")

# --- mega-city district lever (recognizable admin subdivisions) ---
# top metros x their district/ward/borough count (real admin units)
DISTRICTS = {
    "Seoul": 25, "Tokyo": 23, "Osaka": 24, "London": 33, "New York": 5,
    "Paris": 20, "Beijing": 16, "Shanghai": 16, "Moscow": 12, "Berlin": 12,
    "Delhi": 11, "Istanbul": 39, "Mexico City": 16, "Buenos Aires": 15,
    "Rome": 15, "Madrid": 21, "Barcelona": 10, "Sao Paulo": 32, "Vienna": 23,
    "Budapest": 23, "Bangkok": 50, "Hong Kong": 18, "Taipei": 12, "Kyoto": 11,
    "Nagoya": 16, "Busan": 16, "Guangzhou": 11, "Warsaw": 18, "Prague": 22,
}
DIST_KEEP = 0.85  # floor + recognizability trim
dist_raw = sum(DISTRICTS.values())
dist_final = round(dist_raw * DIST_KEEP)

# quality build = tiered major cities (attrition) + districts
major = rows[3][2]                       # ~408
quality_total = major + dist_final
print(f"\n--- mega-city districts ({len(DISTRICTS)} metros) ---")
print(f"  district levels: {dist_raw} raw -> {dist_final} after {DIST_KEEP:.0%} keep")
print(f"\n=== RECOMMENDED QUALITY BUILD ===")
print(f"  major cities (tiered): ~{major}")
print(f"  mega-city districts:   ~{dist_final}")
print(f"  TOTAL:                 ~{quality_total} stages "
      f"across ~{playable_countries} country chapters")
print(f"  (all recognizable; max-quantity path to obscure towns -> ~1,000-1,200)")
