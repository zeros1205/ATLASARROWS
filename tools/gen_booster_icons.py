"""Booster token icons — flat beveled coin + glyph.

Items (2026-07-19 redefinition):
  PULL  = amber coin + lightning bolt  (strike an arrow -> instant fade-out)
  HINT  = blue coin + lightbulb        (highlight one escapable arrow)
          hint1 = one bulb, hint3 = three bulbs (2x price tier)

Outputs (512x512, transparent) into assets/images/icons/:
  pull.png, hint1.png, hint3.png

Usage: python tools/gen_booster_icons.py
"""
import os

from PIL import Image, ImageDraw

SIZE = 512
SS = 4

# palettes: (base, rim, glyph, glyph_extrude)
BLUE = ((0x3B, 0x72, 0xFF, 255), (0x2A, 0x55, 0xD9, 255),
        (0xE9, 0xF0, 0xFF, 255), (0x24, 0x4C, 0xC4, 255))
AMBER = ((0xFF, 0x9E, 0x2C, 255), (0xD9, 0x7E, 0x14, 255),
         (0xFF, 0xF4, 0xE3, 255), (0xC2, 0x6D, 0x0C, 255))


def coin_face(size, pal):
    base, rim, _, _ = pal
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = size * 0.48
    c = size / 2
    d.ellipse((c - r, c - r, c + r, c + r), fill=base)
    ring = r * 0.82
    d.ellipse((c - ring, c - ring, c + ring, c + ring), outline=rim,
              width=int(size * 0.018))
    d.ellipse((c - r, c - r, c + r, c + r), outline=rim, width=int(size * 0.012))
    return img


def bolt_points(cx, cy, s):
    pts = [(0.22, -0.50), (-0.34, 0.08), (-0.06, 0.08), (-0.22, 0.50),
           (0.34, -0.08), (0.06, -0.08)]
    return [(cx + x * s, cy + y * s) for x, y in pts]


import math


def draw_bulb(d, cx, cy, s, fill):
    r = s * 0.34
    d.ellipse((cx - r, cy - r - s * 0.06, cx + r, cy + r - s * 0.06), fill=fill)
    bw = s * 0.30
    by = cy + r - s * 0.10
    d.rounded_rectangle((cx - bw / 2, by, cx + bw / 2, by + s * 0.20),
                        radius=s * 0.05, fill=fill)


def draw_magnifier(d, cx, cy, s, fill, base):
    """Magnifying glass: ring lens + thick handle at 45deg."""
    lx, ly, r = cx - s * 0.08, cy - s * 0.08, s * 0.26
    lw = int(s * 0.11)
    d.ellipse((lx - r, ly - r, lx + r, ly + r), outline=fill, width=lw)
    # handle
    a = math.radians(45)
    x0 = lx + (r + lw * 0.3) * math.cos(a)
    y0 = ly + (r + lw * 0.3) * math.sin(a)
    x1 = lx + s * 0.5 * math.cos(a)
    y1 = ly + s * 0.5 * math.sin(a)
    d.line((x0, y0, x1, y1), fill=fill, width=int(s * 0.14))


def draw_eye(d, cx, cy, s, fill, base):
    """Almond eye + iris."""
    w, h = s * 0.42, s * 0.26
    # two arcs forming an almond via chord fills
    d.ellipse((cx - w, cy - h, cx + w, cy + h), fill=fill)
    d.ellipse((cx - w * 0.62, cy - h * 0.62, cx + w * 0.62, cy + h * 0.62),
              fill=base)
    d.ellipse((cx - s * 0.13, cy - s * 0.13, cx + s * 0.13, cy + s * 0.13),
              fill=fill)


def draw_flash(d, cx, cy, s, fill, base):
    """Flashlight/torch pointing up-right with a beam."""
    # body (tilted rounded rect)
    body = Image.new("RGBA", (int(s * 1.2), int(s * 1.2)), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bx, by = body.width / 2, body.height / 2
    bd.rounded_rectangle((bx - s * 0.11, by - s * 0.02, bx + s * 0.11,
                          by + s * 0.44), radius=s * 0.05, fill=fill)
    # head (flared)
    bd.polygon([(bx - s * 0.17, by + 0.02 * s), (bx + s * 0.17, by + 0.02 * s),
                (bx + s * 0.11, by - s * 0.10), (bx - s * 0.11, by - s * 0.10)],
               fill=fill)
    # beam
    bd.polygon([(bx - s * 0.11, by - s * 0.10), (bx + s * 0.11, by - s * 0.10),
                (bx + s * 0.26, by - s * 0.40), (bx - s * 0.26, by - s * 0.40)],
               fill=fill)
    body = body.rotate(-30, resample=Image.BICUBIC, center=(bx, by))
    return body, (int(cx - bx), int(cy - by))


def render(kind, pal):
    size = SIZE * SS
    face = coin_face(size, pal)
    mask = Image.new("L", (size, size), 0)
    r = size * 0.48
    ImageDraw.Draw(mask).ellipse((size / 2 - r, size / 2 - r, size / 2 + r,
                                  size / 2 + r), fill=255)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    img.paste(face, (0, 0), mask)
    d = ImageDraw.Draw(img)
    base, _, glyph, glyph_ex = pal
    ex = size * 0.016
    cx, cy = size * 0.5, size * 0.5

    if kind == "pull":
        s = size * 0.58
        d.polygon(bolt_points(cx - ex, cy + ex, s), fill=glyph_ex)
        d.polygon(bolt_points(cx, cy, s), fill=glyph)
    elif kind == "mag":
        s = size * 0.62
        draw_magnifier(d, cx - ex, cy + ex, s, glyph_ex, base)
        draw_magnifier(d, cx, cy, s, glyph, base)
    elif kind == "eye":
        s = size * 0.66
        draw_eye(d, cx - ex, cy + ex, s, glyph_ex, base)
        draw_eye(d, cx, cy, s, glyph, base)
    elif kind == "flash":
        s = size * 0.60
        for col, off in ((glyph_ex, ex), (glyph, 0)):
            body, pos = draw_flash(d, cx - off, cy + off, s, col, base)
            img.alpha_composite(body, pos)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..",
                           "assets", "images", "icons")
    # final item set (user-confirmed 2026-07-19):
    #   hint.png    = blue coin + magnifier  (highlight one escapable arrow)
    #   remove.png  = amber coin + bolt       (strike an arrow -> instant fade-out)
    render("mag", BLUE).save(os.path.join(out_dir, "hint.png"))
    render("pull", AMBER).save(os.path.join(out_dir, "remove.png"))
    print("wrote hint.png (magnifier), remove.png (bolt) ->",
          os.path.abspath(out_dir))


if __name__ == "__main__":
    main()
