"""Packs the generated board bank into the single asset the app ships.

`all_boards.json` holds every playable board (country + city silhouettes)
already generated and verified solvable, but it is a flat list with no notion
of rounds. The app needs the campaign shape instead: countries in play order,
each carrying its city boards followed by the country finale.

Two things happen here that the app would otherwise have to do at runtime:

* **The opening five rounds come from `onboarding_boards.json`.** Those are
  five small island nations rendered as a difficulty ladder (4 -> 15 arrows)
  that teaches tap, then zoom, then drag. Without them the campaign's very
  first board is a full country finale, which is the hardest thing a newcomer
  could be handed.
* **Every board is cropped to its mask.** A 5-cell island upscaled to a
  53x24 grid is mostly empty margin; fitting that bounding box to the screen
  shrinks the playable cells for nothing. Cropping moves the line coordinates
  with the mask.

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
onboarding = load("onboarding_boards.json")["boards"]

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

# --- the tutorial ladder, in the order it teaches --------------------------
ladder = {}
for b in onboarding:
    ladder.setdefault(b["name"], []).append(b)


def span(name):
    """Longest side of a ladder's opening board, after cropping."""
    b = crop(ladder[name][0])
    return max(b["rows"], b["cols"])


# Compact shapes first. A board's longest side decides how small its cells get
# when fitted to the screen, and the first thing a new player touches must be
# comfortably tappable without pinching — an archipelago spread over 53 rows
# gives ~11px cells on a phone. The teaching labels ride along with their own
# boards, so ordering by shape costs nothing pedagogically.
ladder_order = sorted(ladder, key=span)


def country_entry(name, stages, rank, meta):
    return {
        "rank": rank,
        "name": name,
        "ko": meta.get("ko", ""),
        "continent": meta.get("continent", ""),
        "area_km2": meta.get("area_km2", 0),
        "stages": stages,
    }


countries = []
rank = 0

# Opening rounds: the ladder countries, gentlest first. The last rung of each
# ladder is the round's finale — these boards *are* the country silhouette at
# rising density, so no separate finale is needed or wanted.
for name in ladder_order:
    rungs = ladder[name]
    # These islands are small enough that several have no entry in the main
    # country bank, so fall back to the ladder board's own Korean name.
    meta = dict(country_boards.get(name, {}))
    meta.setdefault("ko", "")
    if not meta["ko"]:
        meta["ko"] = next((b.get("ko", "") for b in rungs if b.get("ko")), "")
    stages = []
    for i, b in enumerate(rungs):
        kind = "country" if i == len(rungs) - 1 else "city"
        stages.append(stage(b, kind, teaches=b.get("teaches", "")))
    rank += 1
    countries.append(country_entry(name, stages, rank, meta))

# Then the rest of the world by territory area, skipping anything already used
# as a tutorial round.
for cb in sorted(country_boards.values(), key=lambda b: b["rank"]):
    name = cb["name"]
    if name in ladder:
        continue
    cities = sorted(by_country.get(name, []),
                    key=lambda b: -city_pop.get(b["name"], 0))
    stages = [stage(c, "city", city_ko.get(c["name"], "")) for c in cities]
    stages.append(stage(cb, "country"))
    rank += 1
    countries.append(country_entry(name, stages, rank, cb))

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
size = os.path.getsize(dest) / 1024 / 1024
print(f"countries : {len(countries)}  (multi-stage: {with_city})")
print(f"stages    : {total}")
print(f"tutorial  : {' -> '.join(ladder_order)}")
print(f"orphans   : {len(orphans)} city boards had no country")
print(f"written   : {dest}  ({size:.2f} MB)")
