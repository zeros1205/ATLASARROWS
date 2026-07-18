"""Builds world-atlas.html from atlas_countries.json + atlas_cities.json."""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def load(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        return f.read()


countries = load("atlas_countries.json")
cities = load("atlas_cities.json")
animals = load("atlas_animals.json")
nc = len(json.loads(countries)["shapes"])
cc = len(json.loads(cities)["shapes"])
ac = len(json.loads(animals)["shapes"])

html = (load("atlas_template.html")
        .replace("__COUNTRIES__", countries.replace("</", "<\\/"))
        .replace("__CITIES__", cities.replace("</", "<\\/"))
        .replace("__ANIMALS__", animals.replace("</", "<\\/"))
        .replace("__NC__", str(nc))
        .replace("__CC__", str(cc))
        .replace("__AC__", str(ac)))
out = os.path.join(HERE, "world-atlas.html")
open(out, "w", encoding="utf-8").write(html)
print(f"ok countries={nc} cities={cc} animals={ac}"
      f" -> {out} ({len(html)//1024}KB)")
