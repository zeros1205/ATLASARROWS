"""EXPERIMENT — globe (hemisphere) variant of the app icon.

A copy of build_icon.py that replaces the flat Africa landmass with a dotted
globe dome: the whole world grid from `assets/campaign/worldmap.json` reprojected
onto a sphere (orthographic), so dots follow the curvature like the reference.

This script does NOT overwrite any tracked asset. It only writes a preview PNG
so the look can be judged before we commit to it:

    python tools/icon/build_icon_globe.py   -> <scratchpad>/globe_preview.png

If approved, we fold render_globe() back into build_icon.py.
"""
from __future__ import annotations

import json
import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

from PIL import Image, ImageDraw  # noqa: E402

# --- identity (same palette as build_icon.py) -----------------------------
CREAM = (247, 246, 242, 255)
DOT   = (168, 166, 156, 255)
BLUE  = (18, 89, 255, 255)
INK   = (35, 37, 46, 255)
RED   = (255, 36, 78, 255)


def _load_world():
    path = os.path.join(ROOT, "assets", "campaign", "worldmap.json")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _land_sampler(d):
    """Return is_land(lat, lon) over the equirectangular world grid.
    Row 0 is the northern edge (lat1); -1 cells are ocean."""
    cols, rows, cells = d["cols"], d["rows"], d["cells"]
    lon0, lon1, lat0, lat1 = d["lon0"], d["lon1"], d["lat0"], d["lat1"]

    def is_land(lat, lon):
        if lat > lat1 or lat < lat0:
            return False
        c = int((lon - lon0) / (lon1 - lon0) * cols)
        r = int((lat1 - lat) / (lat1 - lat0) * rows)
        c = min(max(c, 0), cols - 1)
        r = min(max(r, 0), rows - 1)
        return cells[r * cols + c] != -1

    return is_land


def globe_dots(center_lat, center_lon, n_across):
    """Screen-space dot centres for the visible hemisphere.

    An even square lattice is laid over the projection disk and each candidate
    is inverse-orthographic-projected back to (lat, lon); the ones that land on
    real land become dots. Even *on screen*, so the dots read as a regular grid
    curving over the sphere rather than piling up at the limb.

    Returns (points, step) where points are (x, y) in [-1, 1] disk coords
    (y up) and step is the lattice pitch (for sizing the dot radius).
    """
    d = _load_world()
    is_land = _land_sampler(d)
    phi0 = math.radians(center_lat)
    lam0 = math.radians(center_lon)
    step = 2.0 / n_across

    pts = []
    y = -1.0 + step / 2
    while y < 1.0:
        x = -1.0 + step / 2
        while x < 1.0:
            rho = math.hypot(x, y)
            if rho <= 1.0:
                if rho < 1e-9:
                    lat, lon = center_lat, center_lon
                else:
                    c = math.asin(min(rho, 1.0))
                    sc, cc = math.sin(c), math.cos(c)
                    lat = math.degrees(math.asin(cc * math.sin(phi0) + y * sc * math.cos(phi0) / rho))
                    lon = center_lon + math.degrees(math.atan2(
                        x * sc, rho * cc * math.cos(phi0) - y * sc * math.sin(phi0)))
                    lon = ((lon + 180) % 360) - 180
                if is_land(lat, lon):
                    pts.append((x, y))
            x += step
        y += step
    return pts, step


def _arrow(dr, x_tail, x_tip, y, bar, head_l, head_h, color) -> None:
    rightward = x_tip > x_tail
    x_neck = x_tip - (head_l if rightward else -head_l)
    radius = bar / 2
    if rightward:
        dr.rectangle([x_tail, y - radius, x_neck, y + radius], fill=color)
    else:
        dr.rectangle([x_neck, y - radius, x_tail, y + radius], fill=color)
    dr.polygon([(x_tip, y), (x_neck, y - head_h / 2), (x_neck, y + head_h / 2)], fill=color)


def _arrow_vertical(dr, x, y_tail, y_tip, bar, head_l, head_h, color) -> None:
    upward = y_tip < y_tail
    y_neck = y_tip + (head_l if upward else -head_l)
    radius = bar / 2
    top, bottom = sorted((y_tail, y_neck))
    dr.rectangle([x - radius, top, x + radius, bottom], fill=color)
    dr.polygon([(x, y_tip), (x - head_h / 2, y_neck), (x + head_h / 2, y_neck)], fill=color)


LAND = (150, 148, 138, 255)   # solid continents: darker than the dot so the
#                               filled hemisphere still reads against the cream


def render_globe(size, background, *, center_lat=12.0, center_lon=-30.0,
                 n_across=50, disk_w=1.6, squash=0.68, cx=0.5, cy=0.70,
                 supersample=4, with_arrows=True, style="dots") -> Image.Image:
    """The globe is drawn as a wide, vertically-squashed dome sitting low in the
    canvas, matching the reference: a curved-top world cap at the icon's bottom.

    `disk_w` = horizontal diameter as a fraction of the canvas (may exceed 1 so
    the dome bleeds off the sides). `squash` = vertical scale (<1 flattens the
    circle into the wide dome). `cx`/`cy` = dome-centre position (0..1); a high
    `cy` drops the sphere centre near/below the bottom so only the top cap shows.
    `center_lon=-30` puts the mid-Atlantic dead centre, Americas left, Africa/
    Europe right.
    """
    S = size * supersample
    img = Image.new("RGBA", (S, S), background or (0, 0, 0, 0))
    dot_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    arrow_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dot_dr = ImageDraw.Draw(dot_layer)
    arrow_dr = ImageDraw.Draw(arrow_layer)

    Rx = S * disk_w / 2
    Ry = Rx * squash
    ox, oy = S * cx, S * cy

    if style == "solid":
        # A fine lattice of cells filled edge-to-edge reads as solid continents
        # (dots lose the coastline at icon size). Cells overlap slightly so no
        # seams show between them.
        pts, step = globe_dots(center_lat, center_lon, 240)
        hw, hh = Rx * step * 0.62, Ry * step * 0.62
        for x, y in pts:
            px, py = ox + x * Rx, oy - y * Ry
            dot_dr.rectangle([px - hw, py - hh, px + hw, py + hh], fill=LAND)
    else:
        pts, step = globe_dots(center_lat, center_lon, n_across)
        radius = 0.46 * Ry * step
        for x, y in pts:
            px, py = ox + x * Rx, oy - y * Ry
            dot_dr.ellipse([px - radius, py - radius, px + radius, py + radius], fill=DOT)

    if with_arrows:
        # Size measured off the "ORIGINAL Arrows" reference (plate ~173px):
        # shaft 0.081 of the canvas, arrowhead 3.0x the shaft in both length and
        # width. Positions keep the last build_icon.py layout, resolved from the
        # Africa board grid to canvas fractions.
        bar = S * 0.081
        head_l, head_h = bar * 3.0, bar * 3.0
        _arrow_vertical(arrow_dr, S * 0.86, S, S * 0.2195, bar, head_l, head_h, BLUE)
        _arrow(arrow_dr, 0, S * 0.6701, S * 0.5323, bar, head_l, head_h, INK)
        _arrow(arrow_dr, S * 0.6213, S * 0.15, S * 0.7347, bar, head_l, head_h, RED)

    img.alpha_composite(dot_layer)
    img.alpha_composite(arrow_layer)
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    scratch = os.environ.get(
        "CLAUDE_SCRATCHPAD",
        "/tmp/claude-0/-home-user-ATLASARROWS/"
        "a2b5d670-cec2-5021-ae97-16a302757dc8/scratchpad",
    )
    os.makedirs(scratch, exist_ok=True)

    full = render_globe(1024, CREAM)
    out = os.path.join(scratch, "globe_preview.png")
    full.resize((512, 512), Image.LANCZOS).save(out)

    bare = render_globe(1024, CREAM, with_arrows=False)
    out_bare = os.path.join(scratch, "globe_preview_bare.png")
    bare.resize((512, 512), Image.LANCZOS).save(out_bare)

    print("wrote preview ->", out)
    print("wrote bare globe ->", out_bare)


if __name__ == "__main__":
    main()
