"""Builds world-atlas.html from the atlas_*.json shape sets.

Applies the candidate floor: shapes under MIN_CELLS are excluded — same
threshold as the game's mask validator (80 cells ~= a one-minute board
at 0.87 fill). Watermark debris and micro-states fall out here.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
MIN_CELLS = 80


def load_filtered(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        shapes = json.load(f)["shapes"]
    kept = [s for s in shapes if s["cells"] >= MIN_CELLS]
    dropped = [s["ko"] if s.get("ko") else s["name"]
               for s in shapes if s["cells"] < MIN_CELLS]
    if dropped:
        print(f"{name}: dropped {len(dropped)} under {MIN_CELLS} cells:")
        print("  " + ", ".join(dropped))
    return kept


countries = load_filtered("atlas_countries.json")
cities = load_filtered("atlas_cities.json")
animals = load_filtered("atlas_animals.json")


def js(shapes):
    return json.dumps({"shapes": shapes}, ensure_ascii=False) \
        .replace("</", "<\\/")


with open(os.path.join(HERE, "atlas_template.html"), encoding="utf-8") as f:
    html = f.read()
html = (html
        .replace("__COUNTRIES__", js(countries))
        .replace("__CITIES__", js(cities))
        .replace("__ANIMALS__", js(animals))
        .replace("__NC__", str(len(countries)))
        .replace("__CC__", str(len(cities)))
        .replace("__AC__", str(len(animals))))
out = os.path.join(HERE, "world-atlas.html")
open(out, "w", encoding="utf-8").write(html)
print(f"ok countries={len(countries)} cities={len(cities)}"
      f" animals={len(animals)} -> {out} ({len(html)//1024}KB)")
