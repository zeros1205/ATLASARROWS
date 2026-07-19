"""Draws the app icon set from the ZTheme palette (stdlib + Pillow).

The mark is the game itself: an ink line tracing a "Z" on paper,
escaping right through a blue arrowhead. Outputs into assets/icon/:

  icon.png      1024x1024, off-white background  (launcher icon, stores)
  icon_fg.png   1024x1024, transparent, content inside the adaptive-icon
                safe zone (Android adaptive foreground)
  splash.png    1024x1024, transparent            (native splash logo)

Usage: python tools/gen_icon.py   (then: dart run flutter_launcher_icons
                                   and dart run flutter_native_splash:create)
"""
import os

from PIL import Image, ImageDraw

BG = (0xF7, 0xF6, 0xF2, 255)  # ZTheme.bg
INK = (0x23, 0x25, 0x2E, 255)  # ZTheme.ink
ACCENT = (0x2F, 0x6B, 0xFF, 255)  # ZTheme.accent
DOT = (0xE4, 0xE3, 0xDD, 255)  # ZTheme.dot

SIZE = 1024
SS = 4  # supersampling factor for clean edges


def z_path(scale, cx, cy):
    """The Z polyline: top bar, orthogonal staircase, bottom bar.
    scale = half-extent of the mark; (cx, cy) = center."""
    pts = [
        (-0.64, -0.48),
        (0.64, -0.48),
        (0.64, -0.24),
        (0.21, -0.24),
        (0.21, 0.0),
        (-0.21, 0.0),
        (-0.21, 0.24),
        (-0.64, 0.24),
        (-0.64, 0.48),
        (0.52, 0.48),
    ]
    return [(cx + x * scale, cy + y * scale) for x, y in pts]


def draw_mark(draw, scale, cx, cy):
    pts = z_path(scale, cx, cy)
    w = int(scale * 0.155)
    draw.line(pts, fill=INK, width=w, joint="curve")
    # round the tail cap
    x0, y0 = pts[0]
    draw.ellipse((x0 - w / 2, y0 - w / 2, x0 + w / 2, y0 + w / 2), fill=INK)
    # blue arrowhead escaping right off the bottom bar
    hx, hy = pts[-1]
    ah = scale * 0.34  # arrowhead height
    al = scale * 0.30  # arrowhead length
    draw.polygon(
        [(hx, hy - ah / 2), (hx + al, hy), (hx, hy + ah / 2)],
        fill=ACCENT,
    )


def grid_dots(draw, size):
    """Faint board dots, like empty cells in-game."""
    n = 7
    step = size / n
    r = size * 0.008
    for i in range(1, n):
        for j in range(1, n):
            x, y = i * step, j * step
            draw.ellipse((x - r, y - r, x + r, y + r), fill=DOT)


def render(with_bg, scale_ratio):
    size = SIZE * SS
    img = Image.new("RGBA", (size, size), BG if with_bg else (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if with_bg:
        grid_dots(draw, size)
    draw_mark(draw, size * scale_ratio, size / 2, size / 2)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
    os.makedirs(out_dir, exist_ok=True)
    # full-bleed icon: mark fills most of the square
    render(True, 0.40).save(os.path.join(out_dir, "icon.png"))
    # adaptive foreground: Android crops to the center ~66% circle,
    # so keep the mark inside a ~0.30 half-extent
    render(False, 0.26).save(os.path.join(out_dir, "icon_fg.png"))
    # splash logo: transparent, roomy
    render(False, 0.30).save(os.path.join(out_dir, "splash.png"))
    print("wrote icon.png, icon_fg.png, splash.png ->", os.path.abspath(out_dir))


if __name__ == "__main__":
    main()
