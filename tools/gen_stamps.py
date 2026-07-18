"""Passport-visa style "COLLECTED" stamps, drawn procedurally (no stock
art). Circular double-ring with arced place name on top, COLLECTED +
VISA in the middle, a date on the bottom arc, stars as separators.
Ink-stamp look in the ZTheme accent (and a red variant).

Outputs into assets/images/stamps/:  one PNG per sample place + a
contact sheet for review.

Usage: python tools/gen_stamps.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

SS = 4            # supersampling
SIZE = 300       # final px
ACCENT = (0x2F, 0x6B, 0xFF)
RED = (0xD8, 0x3A, 0x4E)
INK = (0x23, 0x25, 0x2E)


def _font(px, bold=True):
    for name in (("malgunbd.ttf", "arialbd.ttf") if bold
                 else ("malgun.ttf", "arial.ttf")):
        try:
            return ImageFont.truetype(name, px)
        except OSError:
            continue
    return ImageFont.load_default()


def arc_text(base, text, cx, cy, r, span, mid_deg, font, fill, bottom=False):
    """Draw text along a circular arc centered on mid_deg (image degrees,
    0=east, 90=south), total angular width `span`. bottom=True flips glyphs
    so a bottom arc still reads upright."""
    n = len(text)
    if n == 0:
        return
    step = span / max(n - 1, 1)
    for i, ch in enumerate(text):
        # top arc runs left->right with increasing angle; a bottom arc must
        # decrease so it still reads left->right
        a = (mid_deg + span / 2 - i * step) if bottom else (mid_deg - span / 2 + i * step)
        rad = math.radians(a)
        x = cx + r * math.cos(rad)
        y = cy + r * math.sin(rad)
        # glyph tile
        gw = font.getbbox(ch)
        w = max(gw[2] - gw[0], 1) + 8
        h = (gw[3] - gw[1]) + 8
        tile = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(tile).text((4 - gw[0], 4 - gw[1]), ch, font=font, fill=fill)
        # rotation so the glyph stands tangent, facing outward (or inward)
        rot = (90 - a) if bottom else (270 - a)
        tile = tile.rotate(rot, expand=True, resample=Image.BICUBIC)
        base.alpha_composite(tile, (int(x - tile.width / 2),
                                    int(y - tile.height / 2)))


def star(d, cx, cy, r, fill):
    pts = []
    for i in range(10):
        ang = math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(ang), cy - rr * math.sin(ang)))
    d.polygon(pts, fill=fill)


def stamp(top_text, date_text, color):
    s = SIZE * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = s / 2
    ro = s * 0.46
    lw = int(s * 0.02)
    # double ring
    d.ellipse((cx - ro, cy - ro, cx + ro, cy + ro), outline=color, width=lw)
    ri = ro - s * 0.055
    d.ellipse((cx - ri, cy - ri, cx + ri, cy + ri), outline=color,
              width=int(s * 0.008))
    # arced texts
    arc_text(img, top_text.upper(), cx, cy, ro - s * 0.085, 150, 270,
             _font(int(s * 0.062)), color)
    arc_text(img, date_text, cx, cy, ro - s * 0.075, 120, 90,
             _font(int(s * 0.05)), color, bottom=True)
    # center: VISA (small) over COLLECTED (big), with flanking stars
    f_big = _font(int(s * 0.094))
    f_sm = _font(int(s * 0.046))
    for txt, fnt, dy in (("VISA", f_sm, -0.075), ("COLLECTED", f_big, 0.02)):
        bb = d.textbbox((0, 0), txt, font=fnt)
        d.text((cx - (bb[2] - bb[0]) / 2, cy + dy * s - (bb[3] - bb[1]) / 2),
               txt, font=fnt, fill=color)
    for sx in (-0.135, 0.135):
        star(d, cx + sx * s, cy - 0.062 * s, s * 0.018, color)
    # slight ink roughness: drop overall alpha a touch
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    a = img.split()[3].point(lambda v: int(v * 0.9))
    img.putalpha(a)
    return img.rotate(-8, expand=True, resample=Image.BICUBIC)


SAMPLES = [
    ("REPUBLIC OF KOREA", "2026.07.19", ACCENT),
    ("JAPAN", "2026.07.20", RED),
    ("ITALY", "2026.07.21", ACCENT),
    ("UNITED STATES", "2026.07.22", RED),
    ("SEOUL GANGNAM", "2026.07.19", ACCENT),
    ("NEW YORK CITY", "2026.07.22", INK),
]


def main():
    out = os.path.join(os.path.dirname(__file__), "..", "assets",
                       "images", "stamps")
    os.makedirs(out, exist_ok=True)
    imgs = []
    for i, (top, date, col) in enumerate(SAMPLES):
        im = stamp(top, date, col)
        fn = f"stamp_{i:02d}.png"
        im.save(os.path.join(out, fn))
        imgs.append(im)
        print("wrote", fn, top)
    # contact sheet
    pad, cols = 24, 3
    cw = SIZE + 40
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGBA", (cw * cols + pad, (SIZE + 40) * rows + pad),
                      (247, 246, 242, 255))
    for i, im in enumerate(imgs):
        x = pad + (i % cols) * cw
        y = pad + (i // cols) * (SIZE + 40)
        sheet.paste(im, (x, y), im)
    sheet.convert("RGB").save(os.path.join(out, "_contact_sheet.png"))
    print("-> assets/images/stamps/")


if __name__ == "__main__":
    main()
