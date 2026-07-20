"""Build the Google Play feature graphic background.

Output:
    store/feature_graphic/world_map_bg_1024x500.png

This is only the background layer: cream field plus dotted world map. Arrows
are intentionally left out so they can be composed after the direction is set.
"""
from __future__ import annotations

import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

CREAM = (247, 246, 242, 255)  # #F7F6F2
DOT = (168, 166, 156, 255)    # #A8A69C

WIDTH = 1024
HEIGHT = 500
SS = 4


def load_world_mask() -> list[list[bool]]:
    path = os.path.join(ROOT, "assets", "campaign", "worldmap.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    cols = data["cols"]
    rows = data["rows"]
    cells = data["cells"]
    names = data["names"]

    mask = []
    for row in range(rows):
        out = []
        for col in range(cols):
            idx = cells[row * cols + col]
            out.append(idx >= 0 and names[idx] != "Antarctica")
        mask.append(out)
    return mask


def render() -> Image.Image:
    mask = load_world_mask()
    rows = len(mask)
    cols = len(mask[0])

    width = WIDTH * SS
    height = HEIGHT * SS
    img = Image.new("RGBA", (width, height), CREAM)
    draw = ImageDraw.Draw(img)

    margin_x = width * 0.035
    margin_y = height * 0.085
    pitch = min((width - margin_x * 2) / cols, (height - margin_y * 2) / rows)
    map_w = pitch * cols
    map_h = pitch * rows
    left = (width - map_w) / 2
    top = (height - map_h) / 2
    radius = pitch * 0.34

    for row in range(rows):
        for col in range(cols):
            if not mask[row][col]:
                continue
            x = left + pitch * (col + 0.5)
            y = top + pitch * (row + 0.5)
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=DOT)

    return img.resize((WIDTH, HEIGHT), Image.LANCZOS)


def main() -> None:
    out_dir = os.path.join(ROOT, "store", "feature_graphic")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "world_map_bg_1024x500.png")
    render().save(out)
    print(out)


if __name__ == "__main__":
    main()
