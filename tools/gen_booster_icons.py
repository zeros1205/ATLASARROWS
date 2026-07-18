"""Booster token icons in the relay_token art style: a beveled coin with
diagonal sheen stripes and a softly extruded glyph.

Outputs (512x512, transparent):
  assets/images/icons/hint_bolt1.png  blue coin, one bolt   (HINT x1)
  assets/images/icons/hint_bolt3.png  blue coin, three bolts (HINT x3)

Usage: python tools/gen_booster_icons.py
"""
import os

from PIL import Image, ImageDraw

SIZE = 512
SS = 4

# hint token palette — ZTheme accent family, mirroring relay_token's
# green construction (base / lighter stripe / dark rim / pale glyph)
BASE = (0x3B, 0x72, 0xFF, 255)
STRIPE = (0x5C, 0x8B, 0xFF, 255)
RIM = (0x2A, 0x55, 0xD9, 255)
GLYPH = (0xE9, 0xF0, 0xFF, 255)
GLYPH_EX = (0x24, 0x4C, 0xC4, 255)


def bolt_points(cx, cy, s, tilt=0.0):
    """Classic zigzag bolt, height = s, centered on (cx, cy)."""
    pts = [
        (0.22, -0.50), (-0.34, 0.08), (-0.06, 0.08), (-0.22, 0.50),
        (0.34, -0.08), (0.06, -0.08),
    ]
    out = []
    for x, y in pts:
        x, y = x + tilt * y, y  # slight shear for motion
        out.append((cx + x * s, cy + y * s))
    return out


def draw_coin(d, size):
    # flat face — no sheen stripes (user call, 2026-07-18); just the
    # solid coin with rim rings
    r = size * 0.48
    cx = cy = size / 2
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=BASE)
    ring = r * 0.82
    d.ellipse((cx - ring, cy - ring, cx + ring, cy + ring),
              outline=RIM, width=int(size * 0.018))
    d.ellipse((cx - r, cy - r, cx + r, cy + r),
              outline=RIM, width=int(size * 0.012))


def render(bolts):
    size = SIZE * SS
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # coin face drawn on its own layer, then masked to a circle so the
    # sheen stripes never bleed outside
    face = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_coin(ImageDraw.Draw(face), size)
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    r = size * 0.48
    md.ellipse((size / 2 - r, size / 2 - r, size / 2 + r, size / 2 + r),
               fill=255)
    img.paste(face, (0, 0), mask)

    d = ImageDraw.Draw(img)
    ex = size * 0.016  # glyph extrusion offset (down-left, like the token)
    if bolts == 1:
        marks = [(size * 0.5, size * 0.5, size * 0.56)]
    else:
        marks = [
            (size * 0.30, size * 0.54, size * 0.34),
            (size * 0.50, size * 0.46, size * 0.42),
            (size * 0.70, size * 0.54, size * 0.34),
        ]
    for cx, cy, s in marks:
        d.polygon(bolt_points(cx - ex, cy + ex, s), fill=GLYPH_EX)
        d.polygon(bolt_points(cx, cy, s), fill=GLYPH)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..",
                           "assets", "images", "icons")
    render(1).save(os.path.join(out_dir, "hint_bolt1.png"))
    render(3).save(os.path.join(out_dir, "hint_bolt3.png"))
    print("wrote hint_bolt1.png, hint_bolt3.png ->", os.path.abspath(out_dir))


if __name__ == "__main__":
    main()
