"""Render the Atlas Arrows app icon and every platform-sized export.

The artwork is drawn, not painted: the dotted landmass comes straight out of
`assets/campaign/worldmap.json` (the same grid the in-game world map uses), so
the icon and the map are literally the same data. Everything else is exact
geometry — the three arrows share one bar thickness and one arrowhead size and
differ only in length, which a raster/AI pass cannot guarantee.

    python tools/icon/build_icon.py

Writes:
    assets/icon/icon.png          1024, opaque, full bleed  (iOS + legacy Android)
    assets/icon/icon_fg.png       1024, transparent, safe-zone (Android adaptive)
    store/icon/play_512.png       Google Play listing icon (32-bit PNG)
    store/icon/appstore_1024.png  App Store listing icon (no alpha)
    store/icon/preview_48.png     shrink test — if it dies here, it dies on a phone

`dart run flutter_launcher_icons` then fans the two assets/ files out into
ios/Runner/Assets.xcassets and android/app/src/main/res.
"""
from __future__ import annotations

import json
import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

from PIL import Image, ImageDraw  # noqa: E402

# --- identity -------------------------------------------------------------
# Matches lib/app/tokens/colors.dart. CREAM must stay equal to
# `adaptive_icon_background` in pubspec.yaml or the adaptive mask shows a seam.
CREAM = (247, 246, 242, 255)   # AppColors.light.bg      #F7F6F2
DOT   = (168, 166, 156, 255)   # darker than the in-app dot: an icon is tiny
BLUE  = (18, 89, 255, 255)     # vivid blue               #1259FF — escaping
INK   = (35, 37, 46, 255)      # AppColors.light.ink     #23252E — blocked
RED   = (255, 36, 78, 255)     # vivid red                #FF244E — blocked

# Africa reads as "a country on the world map" at icon size; Eurasia does not.
AFRICA = {
    "Algeria", "Angola", "Benin", "Botswana", "Burkina Faso", "Burundi",
    "Cameroon", "Cape Verde", "Central African Republic", "Chad", "Comoros",
    "Democratic Republic of the Congo", "Republic of Congo",
    "Republic of the Congo", "Djibouti", "Egypt", "Equatorial Guinea",
    "Eritrea", "Ethiopia", "Gabon", "Gambia", "Ghana", "Guinea",
    "Guinea-Bissau", "Ivory Coast", "Kenya", "Lesotho", "Liberia", "Libya",
    "Madagascar", "Malawi", "Mali", "Mauritania", "Mauritius", "Morocco",
    "Mozambique", "Namibia", "Niger", "Nigeria", "Rwanda",
    "Sao Tome and Principe", "Senegal", "Seychelles", "Sierra Leone",
    "Somalia", "Somaliland", "South Africa", "South Sudan", "Sudan",
    "Swaziland", "eSwatini", "Tanzania", "United Republic of Tanzania",
    "Togo", "Tunisia", "Uganda", "Zambia", "Zimbabwe", "Western Sahara",
}


def africa_mask() -> list[list[bool]]:
    """The world map's own cells, filtered to Africa and cropped to its bbox."""
    path = os.path.join(ROOT, "assets", "campaign", "worldmap.json")
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    cols, rows, cells = d["cols"], d["rows"], d["cells"]
    keep = {i for i, n in enumerate(d["names"]) if n in AFRICA}

    hit = [[cells[r * cols + c] in keep for c in range(cols)] for r in range(rows)]
    ys = [r for r in range(rows) if any(hit[r])]
    xs = [c for c in range(cols) if any(hit[r][c] for r in range(rows))]
    return [row[min(xs):max(xs) + 1] for row in hit[min(ys):max(ys) + 1]]


def downsample(mask: list[list[bool]], factor: int) -> list[list[bool]]:
    """Coarsen the grid. The campaign map is ~35 cells wide across Africa; an
    icon needs ~18 or the dots collapse into grey noise when shrunk."""
    h, w = len(mask), len(mask[0])
    out = []
    for r in range(math.ceil(h / factor)):
        row = []
        for c in range(math.ceil(w / factor)):
            blk = [mask[y][x]
                   for y in range(r * factor, min((r + 1) * factor, h))
                   for x in range(c * factor, min((c + 1) * factor, w))]
            row.append(sum(blk) >= max(1, len(blk) * 0.30))
        out.append(row)
    return out


def _arrow(dr, x_tail, x_tip, y, bar, head_l, head_h, color) -> None:
    """One horizontal arrow. Points left when x_tip < x_tail.

    Shaped after the arrows on the board itself: a thin stroke with a squared
    cap and a small head, not a fat bar with a big one. The genre draws these
    as lines, and a heavy bar reads as a signpost instead.
    """
    rightward = x_tip > x_tail
    x_neck = x_tip - (head_l if rightward else -head_l)
    radius = bar / 2

    if rightward:
        dr.rectangle([x_tail, y - radius, x_neck, y + radius], fill=color)
    else:
        dr.rectangle([x_neck, y - radius, x_tail, y + radius], fill=color)

    dr.polygon(
        [(x_tip, y), (x_neck, y - head_h / 2), (x_neck, y + head_h / 2)],
        fill=color,
    )


def _arrow_vertical(dr, x, y_tail, y_tip, bar, head_l, head_h, color) -> None:
    """One vertical arrow, using the same body and head metrics as _arrow."""
    upward = y_tip < y_tail
    y_neck = y_tip + (head_l if upward else -head_l)
    radius = bar / 2

    top, bottom = sorted((y_tail, y_neck))
    dr.rectangle([x - radius, top, x + radius, bottom], fill=color)

    dr.polygon(
        [(x, y_tip), (x - head_h / 2, y_neck), (x + head_h / 2, y_neck)],
        fill=color,
    )


def render(size: int, mask: list[list[bool]], inset: float,
           background, supersample: int = 4) -> Image.Image:
    """`inset` is the fraction of the canvas the composition may occupy —
    1.0 for a full-bleed store icon, ~0.6 for the Android adaptive foreground,
    whose corners a launcher is free to mask away.

    `background` may be None for a transparent plate.
    """
    S = size * supersample
    img = Image.new("RGBA", (S, S), background or (0, 0, 0, 0))
    dot_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    arrow_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dot_dr = ImageDraw.Draw(dot_layer)
    arrow_dr = ImageDraw.Draw(arrow_layer)
    H, W = len(mask), len(mask[0])

    board_h = S * inset
    board_pitch = board_h / H
    board_w = board_pitch * W
    left = (S - board_w) / 2 - board_pitch * 0.35
    oy = (S - board_pitch * H) / 2
    radius = board_pitch * 0.40

    for ry in range(H):
        for cx in range(W):
            if not mask[ry][cx]:
                continue
            x = left + board_pitch * (cx + 0.5)
            y = oy + board_pitch * (ry + 0.5)
            dot_dr.ellipse(
                [x - radius, y - radius, x + radius, y + radius],
                fill=DOT,
            )

    # One thickness, one head size, three lengths. This is the whole point.
    # The head ratios are measured off the genre's own boards (head ≈ 2.8x the
    # stroke wide, 2.2x long). The stroke itself is set by legibility, not by
    # that grid: at the board's own weight the arrows go pale by 48px, so 0.75
    # of the canvas is the thinnest that still survives the shrink. The arrows
    # live on their own layer, so changing the continent size cannot change
    # their thickness or head size.
    bar = S * 0.0748
    head_l, head_h = bar * 2.35, bar * 3.05

    def gx(c: float) -> float:
        return left + board_pitch * (c + 0.5)

    def gy(r: float) -> float:
        return oy + board_pitch * (r + 0.5)

    # Placed as fractions of the grid, not as cell numbers, so changing the
    # downsample factor rescales the layout instead of shoving the lower
    # arrows off the bottom of a shorter board.
    _arrow_vertical(arrow_dr, S * 0.86, S, gy(0.18 * H), bar, head_l, head_h, BLUE)
    _arrow(arrow_dr, 0, gx(0.67 * W), gy(0.52 * H), bar, head_l, head_h, INK)
    # Red is the shortest, but its shaft still has to out-measure its head or
    # it stops reading as an arrow at all.
    _arrow(arrow_dr, gx(0.62 * W), S * 0.15, gy(0.74 * H), bar, head_l, head_h, RED)

    img.alpha_composite(dot_layer)
    img.alpha_composite(arrow_layer)
    return img.resize((size, size), Image.LANCZOS)


def fit_to_safe_zone(img: Image.Image, zone: float) -> Image.Image:
    """Center the foreground and fit its full alpha bbox inside `zone`.

    Android adaptive icons are 108dp layers with a central 66dp area that OEM
    masks must not clip. This source file is the full 108dp foreground layer,
    so important artwork must fit inside 66/108 of the plate, not rely on
    launcher-specific masks or flutter_launcher_icons' inset wrapper.
    """
    box = img.getbbox()
    if box is None:
        return img
    S = img.width
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    centred = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    centred.alpha_composite(img, (round(S / 2 - cx), round(S / 2 - cy)))

    centred_box = centred.getbbox()
    if centred_box is None:
        return centred
    w = centred_box[2] - centred_box[0]
    h = centred_box[3] - centred_box[1]
    scale = min(zone / w, zone / h) * 0.98
    small = centred.resize((round(S * scale), round(S * scale)), Image.LANCZOS)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.alpha_composite(small, ((S - small.width) // 2, (S - small.height) // 2))
    return out


def save_resized(src: Image.Image, path: str, size: int, rgb: bool = False) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = src.resize((size, size), Image.LANCZOS)
    if rgb:
        img = img.convert("RGB")
    img.save(path)


def export_platform_icons(full: Image.Image, fg: Image.Image) -> None:
    """Write platform icon files directly so the adaptive XML stays exact."""
    android = os.path.join(ROOT, "android", "app", "src", "main", "res")
    for density, size in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        save_resized(
            full,
            os.path.join(android, f"mipmap-{density}", "ic_launcher.png"),
            size,
        )
        save_resized(
            fg,
            os.path.join(android, f"drawable-{density}", "ic_launcher_foreground.png"),
            size * 4,
        )

    xml = os.path.join(android, "mipmap-anydpi-v26", "ic_launcher.xml")
    with open(xml, "w", encoding="utf-8", newline="\n") as f:
        f.write("""<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_background"/>
  <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
""")

    ios = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    with open(os.path.join(ios, "Contents.json"), encoding="utf-8") as f:
        contents = json.load(f)
    for item in contents["images"]:
        filename = item.get("filename")
        if not filename:
            continue
        base = float(item["size"].split("x", 1)[0])
        scale = int(item["scale"].replace("x", ""))
        save_resized(full, os.path.join(ios, filename), round(base * scale), rgb=True)

    web = os.path.join(ROOT, "web")
    save_resized(full, os.path.join(web, "favicon.png"), 32)
    save_resized(full, os.path.join(web, "icons", "Icon-192.png"), 192)
    save_resized(full, os.path.join(web, "icons", "Icon-512.png"), 512)
    save_resized(full, os.path.join(web, "icons", "Icon-maskable-192.png"), 192)
    save_resized(full, os.path.join(web, "icons", "Icon-maskable-512.png"), 512)


def export_android_mask_preview(full: Image.Image, fg: Image.Image, path: str) -> None:
    bg = Image.new("RGBA", (1024, 1024), CREAM)
    adaptive = bg.copy()
    adaptive.alpha_composite(fg)

    def masked(img: Image.Image, kind: str) -> Image.Image:
        mask = Image.new("L", (1024, 1024), 0)
        dr = ImageDraw.Draw(mask)
        if kind == "circle":
            dr.ellipse((0, 0, 1024, 1024), fill=255)
        elif kind == "rounded":
            dr.rounded_rectangle((0, 0, 1024, 1024), radius=230, fill=255)
        else:
            dr.rounded_rectangle((32, 32, 992, 992), radius=260, fill=255)
        out = Image.new("RGBA", (1024, 1024), (230, 230, 230, 255))
        plate = img.copy()
        plate.putalpha(mask)
        out.alpha_composite(plate)
        return out

    safe = adaptive.copy()
    dr = ImageDraw.Draw(safe)
    a = 1024 * (21 / 108)
    b = 1024 - a
    dr.rectangle((a, a, b, b), outline=(255, 36, 78, 255), width=6)

    items = [
        ("store", full),
        ("safe zone", safe),
        ("circle", masked(adaptive, "circle")),
        ("squircle", masked(adaptive, "squircle")),
        ("rounded", masked(adaptive, "rounded")),
    ]
    thumb, pad, gap, label_h = 300, 36, 20, 42
    sheet = Image.new(
        "RGBA",
        (pad * 2 + thumb * len(items) + gap * (len(items) - 1), pad * 2 + label_h + thumb),
        CREAM,
    )
    dr = ImageDraw.Draw(sheet)
    for i, (label, img) in enumerate(items):
        x = pad + i * (thumb + gap)
        y = pad + label_h
        sheet.alpha_composite(img.resize((thumb, thumb), Image.LANCZOS), (x, y))
        dr.text((x, pad), label, fill=INK)
    sheet.convert("RGB").save(path)


def main() -> None:
    mask = africa_mask()
    print(f"grid {len(mask[0])} x {len(mask)} dots")

    assets = os.path.join(ROOT, "assets", "icon")
    store = os.path.join(ROOT, "store", "icon")
    os.makedirs(store, exist_ok=True)

    full = render(1024, mask, 0.92, CREAM)
    full.save(os.path.join(assets, "icon.png"))

    # Android launcher foreground: full 108dp layer, with all foreground art
    # fitted inside the central 66dp safe zone. The XML must not add another
    # inset around this file.
    fg = fit_to_safe_zone(render(1024, mask, 0.90, None), 1024 * (66 / 108))
    fg.save(os.path.join(assets, "icon_fg.png"))

    full.resize((512, 512), Image.LANCZOS).save(os.path.join(store, "play_512.png"))
    full.convert("RGB").save(os.path.join(store, "appstore_1024.png"))
    full.resize((48, 48), Image.LANCZOS).save(os.path.join(store, "preview_48.png"))
    export_platform_icons(full, fg)
    export_android_mask_preview(
        full,
        fg,
        os.path.join(store, "android_mask_preview.png"),
    )

    print("wrote store, Android, iOS, and web icon assets")


if __name__ == "__main__":
    main()
