"""EXPERIMENT — globe (hemisphere) variant of the app icon.

A copy of build_icon.py that replaces the flat Africa landmass with a dotted
globe dome: the whole world grid from `assets/campaign/worldmap.json` reprojected
onto a sphere (orthographic), so dots follow the curvature like the reference.

Running it writes the full platform icon set (store + Android + iOS + web),
reusing build_icon.py's export helpers so only the artwork differs:

    python tools/icon/build_icon_globe.py
"""
from __future__ import annotations

import json
import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

from PIL import Image, ImageDraw  # noqa: E402

# --- identity (same palette as build_icon.py) -----------------------------
CREAM = (0xF7, 0xF7, 0xF7, 255)  # icon ground #F7F7F7
DOT   = (90, 90, 96, 255)      # dense dark halftone (the approved "best" background)
MINT  = (0x23, 0x23, 0xFF, 255)  # icon-only blue #2323FF
INK   = (0x25, 0x25, 0x25, 255)  # icon-only black #252525
RED   = (0xCD, 0x1C, 0x18, 255)  # icon-only red #CD1C18


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


# Arrowhead corner rounding as a fraction of the shaft, measured off the
# reference: the point softens ~1.5px and each rear tip ~2.5px on a 14px shaft.
TIP_ROUND = 0.11
BASE_ROUND = 0.18


def _round_poly(verts, radii, steps=10):
    """Fill-ready point list for a polygon with a fillet at each vertex.
    radii[i] is the corner radius at verts[i]; 0 keeps the corner sharp."""
    out = []
    n = len(verts)
    for i in range(n):
        v, a, b = verts[i], verts[(i - 1) % n], verts[(i + 1) % n]
        r = radii[i]
        if r <= 0:
            out.append(v)
            continue
        ua = (a[0] - v[0], a[1] - v[1])
        ub = (b[0] - v[0], b[1] - v[1])
        la, lb = math.hypot(*ua), math.hypot(*ub)
        ua, ub = (ua[0] / la, ua[1] / la), (ub[0] / lb, ub[1] / lb)
        half = math.acos(max(-1.0, min(1.0, ua[0] * ub[0] + ua[1] * ub[1]))) / 2
        t = min(r / math.tan(half), la * 0.5, lb * 0.5)
        r_eff = t * math.tan(half)
        bis = (ua[0] + ub[0], ua[1] + ub[1])
        lbis = math.hypot(*bis)
        c = (v[0] + bis[0] / lbis * r_eff / math.sin(half),
             v[1] + bis[1] / lbis * r_eff / math.sin(half))
        t1 = (v[0] + ua[0] * t, v[1] + ua[1] * t)
        t2 = (v[0] + ub[0] * t, v[1] + ub[1] * t)
        a1 = math.atan2(t1[1] - c[1], t1[0] - c[0])
        a2 = math.atan2(t2[1] - c[1], t2[0] - c[0])
        da = a2 - a1
        while da <= -math.pi:
            da += 2 * math.pi
        while da > math.pi:
            da -= 2 * math.pi
        for s in range(steps + 1):
            aa = a1 + da * s / steps
            out.append((c[0] + r_eff * math.cos(aa), c[1] + r_eff * math.sin(aa)))
    return out


def _arrow(dr, x_tail, x_tip, y, bar, head_l, head_h, color) -> None:
    rightward = x_tip > x_tail
    x_neck = x_tip - (head_l if rightward else -head_l)
    radius = bar / 2
    if rightward:
        dr.rectangle([x_tail, y - radius, x_neck, y + radius], fill=color)
    else:
        dr.rectangle([x_neck, y - radius, x_tail, y + radius], fill=color)
    head = [(x_tip, y), (x_neck, y - head_h / 2), (x_neck, y + head_h / 2)]
    dr.polygon(_round_poly(head, [bar * TIP_ROUND, bar * BASE_ROUND, bar * BASE_ROUND]),
               fill=color)


def _arrow_vertical(dr, x, y_tail, y_tip, bar, head_l, head_h, color) -> None:
    upward = y_tip < y_tail
    y_neck = y_tip + (head_l if upward else -head_l)
    radius = bar / 2
    top, bottom = sorted((y_tail, y_neck))
    dr.rectangle([x - radius, top, x + radius, bottom], fill=color)
    head = [(x, y_tip), (x - head_h / 2, y_neck), (x + head_h / 2, y_neck)]
    dr.polygon(_round_poly(head, [bar * TIP_ROUND, bar * BASE_ROUND, bar * BASE_ROUND]),
               fill=color)


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
        pts, step = globe_dots(center_lat, center_lon, 120)
        radius = 0.42 * Ry * step
        for x, y in pts:
            px, py = ox + x * Rx, oy - y * Ry
            dot_dr.ellipse([px - radius, py - radius, px + radius, py + radius], fill=DOT)

    if with_arrows:
        # Size measured off the "ORIGINAL Arrows" reference (plate ~173px):
        # shaft 0.081, arrowhead 3.0x the shaft. Bumped 15% (0.081 -> 0.09315)
        # for more presence; the head scales with the bar, and the tail/tip
        # coordinates are fixed so the arrows keep their length.
        bar = S * 0.09315
        head_l, head_h = bar * 3.0, bar * 3.0
        # tip stretched up to the 10%-of-canvas line (was aligned to the ink
        # arrow's top edge; now reaches noticeably higher on its own).
        _arrow_vertical(arrow_dr, S * 0.81, S, S * 0.10, bar, head_l, head_h, MINT)
        # Three horizontal arrows (black, black, red), evenly spaced: red
        # anchors the bottom (moved down 5%, 0.76 -> 0.81), the top black is a
        # same-size twin of the original placed above it, and the gap between
        # all three is equal ((0.81 - 0.16) / 2 = 0.325).
        _arrow(arrow_dr, 0, S * 0.6701, S * 0.16, bar, head_l, head_h, INK)
        _arrow(arrow_dr, 0, S * 0.6701, S * 0.485, bar, head_l, head_h, INK)
        _arrow(arrow_dr, S * 0.6213, S * 0.10, S * 0.81, bar, head_l, head_h, RED)

    img.alpha_composite(dot_layer)
    img.alpha_composite(arrow_layer)
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    import build_icon as b  # reuse the platform export helpers unchanged

    assets = os.path.join(ROOT, "assets", "icon")
    store = os.path.join(ROOT, "store", "icon")
    os.makedirs(store, exist_ok=True)

    full = render_globe(1024, CREAM)
    full.save(os.path.join(assets, "icon.png"))

    # Android adaptive foreground: fit the whole composition into the 66dp safe
    # zone (the full-bleed globe would otherwise be clipped by OEM masks).
    fg = b.fit_to_safe_zone(render_globe(1024, None), 1024 * (66 / 108))
    fg.save(os.path.join(assets, "icon_fg.png"))

    full.resize((512, 512), Image.LANCZOS).save(os.path.join(store, "play_512.png"))
    full.convert("RGB").save(os.path.join(store, "appstore_1024.png"))
    full.resize((48, 48), Image.LANCZOS).save(os.path.join(store, "preview_48.png"))
    b.export_platform_icons(full, fg)
    b.export_android_mask_preview(full, fg, os.path.join(store, "android_mask_preview.png"))

    print("wrote store, Android, iOS, and web icon assets")


if __name__ == "__main__":
    main()
