"""Packs the generated board bank into the single asset the app ships.

`all_boards.json` holds every playable board (country + city silhouettes)
already generated and verified solvable, but it is a flat list with no notion
of rounds. The app needs the campaign shape instead: countries in play order,
each carrying its city boards followed by the country finale.

Round order is **not decided here**. The board bank already carries it: every
country board has a `rank` running 1..216, Vatican through Russia, and that
sequence is the campaign. Cities inside a round are ordered by arrow count so
the round climbs to its own finale.

Nothing is generated here. The bank is used exactly as it was authored; the
only edit is a crop:

* **Every board is cropped to its mask.** A silhouette can sit in a grid with
  wide empty margins, and fitting that bounding box to the screen shrinks the
  playable cells for nothing. Cropping moves the line coordinates with the
  mask, so the puzzle itself is untouched — verified by comparing the baked
  boards against the source geometry.

City -> country comes from two sources, in this order:
  1. admin1_cities.json  — every entry names its country outright
  2. world_campaign_order.json — country -> city-name list, used for the
     handful of cities admin-1 does not list (Hong Kong, Singapore, …)

Output: assets/campaign/bank.json
Run:    python tools/atlas/build_bank.py
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

STEP = {"U": (-1, 0), "D": (1, 0), "L": (0, -1), "R": (0, 1)}


def load(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        return json.load(f)


def crop(board):
    """Trims empty margin off a board, moving its lines with it."""
    grid = board["grid"]
    rows = [r for r, line in enumerate(grid) if "#" in line]
    if not rows:
        return board
    cols = [c for line in grid for c, ch in enumerate(line) if ch == "#"]
    r0, r1 = min(rows), max(rows)
    c0, c1 = min(cols), max(cols)
    if r0 == 0 and c0 == 0 and r1 == len(grid) - 1 and c1 == len(grid[0]) - 1:
        return board

    out = dict(board)
    out["grid"] = [line[c0:c1 + 1] for line in grid[r0:r1 + 1]]
    out["rows"] = r1 - r0 + 1
    out["cols"] = c1 - c0 + 1
    moved = []
    for spec in board["lines"]:
        pos, moves = spec.split(":")
        r, c = (int(x) for x in pos.split(","))
        moved.append(f"{r - r0},{c - c0}:{moves}")
    out["lines"] = moved
    return out


def check(board, where):
    """Every line cell must land inside the mask, or the app asserts on load."""
    grid = board["grid"]
    mask = {(r, c)
            for r, line in enumerate(grid)
            for c, ch in enumerate(line) if ch == "#"}
    for spec in board["lines"]:
        pos, moves = spec.split(":")
        r, c = (int(x) for x in pos.split(","))
        cells = [(r, c)]
        for ch in moves:
            dr, dc = STEP[ch]
            r, c = r + dr, c + dc
            cells.append((r, c))
        for cell in cells:
            if cell not in mask:
                raise SystemExit(f"{where}: line {spec} leaves the mask at {cell}")


def stage(board, kind, ko_fallback="", teaches=""):
    """A board trimmed to what the app actually reads."""
    board = crop(board)
    out = {
        "kind": kind,
        "name": board["name"],
        "ko": board.get("ko") or ko_fallback,
        "rows": board["rows"],
        "cols": board["cols"],
        "grid": board["grid"],
        "lines": board["lines"],
    }
    if teaches:
        out["teaches"] = teaches
    return out


boards = load("all_boards.json")["boards"]
admin1 = load("admin1_cities.json")["cities"]
order = load("world_campaign_order.json")["countries"]

# Continent per country. all_boards.json (from export_boards.dart) drops it, so
# join it back from campaign.json here — the campaign needs it for the
# continent-completion achievements. "Seven seas (open ocean)" is not a real
# continent; its four open-ocean territories are absorbed into a real one
# (docs/WORLDMAP_PLAN.md §2.2).
_ABSORB = {
    "British Indian Ocean Territory": "Africa",
    "Seychelles": "Africa",
    "Mauritius": "Africa",
    "Heard Island and McDonald Islands": "Oceania",
}
_campaign = load("campaign.json")["countries"]
continent_by_name = {
    c["name"]: _ABSORB.get(c["name"], c.get("continent", ""))
    for c in _campaign
}
# ISO 3166-1 alpha-2 per country (for the flag shown on clear). Empty for
# disputed territories without a standard code.
iso_by_name = {c["name"]: c.get("iso", "") for c in _campaign}

country_boards = {b["name"]: b for b in boards if b["kind"] == "country"}

city_boards = {}
for b in boards:
    if b["kind"] == "city":
        city_boards.setdefault(b["name"], []).append(b)

# --- city name -> country -------------------------------------------------
city_country, city_pop, city_ko = {}, {}, {}
for e in admin1:
    city_country.setdefault(e["name"], e["country"])
    city_pop[e["name"]] = e.get("pop", 0)
    city_ko[e["name"]] = e.get("ko", "")

for c in order:
    for n in c.get("cities", []):
        city_country.setdefault(n, c["country"])

by_country, orphans = {}, []
for name, bs in city_boards.items():
    country = city_country.get(name)
    if country is None or country not in country_boards:
        orphans.extend(bs)
        continue
    by_country.setdefault(country, []).extend(bs)

def arrows(board):
    """Difficulty, as the project defines it."""
    return len(board["lines"])


countries = []
# The campaign order is already decided: `rank` runs 1..216, Vatican to Russia,
# and it is baked into the boards themselves. This file does not get to
# re-sort it. Cities inside a round climb to their own finale.
for cb in sorted(country_boards.values(), key=lambda b: b["rank"]):
    name = cb["name"]
    cities = sorted(by_country.get(name, []), key=arrows)
    stages = [stage(c, "city", city_ko.get(c["name"], "")) for c in cities]
    stages.append(stage(cb, "country"))
    countries.append({
        "rank": cb["rank"],
        "name": name,
        "ko": cb.get("ko", ""),
        "continent": continent_by_name.get(name, cb.get("continent", "")),
        "iso": iso_by_name.get(name, ""),
        "area_km2": cb.get("area_km2", 0),
        "stages": stages,
    })

for c in countries:
    for s in c["stages"]:
        check(s, f"{c['name']} / {s['name']}")

dest = os.path.join(ROOT, "assets", "campaign", "bank.json")
os.makedirs(os.path.dirname(dest), exist_ok=True)
with open(dest, "w", encoding="utf-8") as f:
    json.dump({"countries": countries}, f, ensure_ascii=False,
              separators=(",", ":"))

total = sum(len(c["stages"]) for c in countries)
with_city = sum(1 for c in countries if len(c["stages"]) > 1)
floor = min(len(s["lines"]) for c in countries for s in c["stages"])
size = os.path.getsize(dest) / 1024 / 1024
first, last = countries[0], countries[-1]
print(f"countries : {len(countries)}  (with cities: {with_city})")
print(f"stages    : {total}")
print(f"arrows    : {floor} at the easiest board")
print(f"first     : {first['ko'] or first['name']} "
      f"({arrows(first['stages'][-1])} arrows)")
print(f"last      : {last['ko'] or last['name']} "
      f"({arrows(last['stages'][-1])} arrows)")
print(f"orphans   : {len(orphans)} city boards had no country")
print(f"written   : {dest}  ({size:.2f} MB)")
