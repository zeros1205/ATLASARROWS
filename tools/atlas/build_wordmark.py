"""Renders the Atlas Arrows lockup for the cold-start loading plate.

Spec: docs/APP_WORDMARK_AND_LOADING.md in the boot kit -- two lines, two
colours, no ornament, transparent PNG, tight-cropped, >= 592px wide. The
lockup is generated rather than drawn by hand so the two lines stay optically
matched in width and the crop is exact by construction; hand-cropping is where
the transparent margin that breaks widthFactor 0.61 creeps in.

Run: python tools/atlas/build_wordmark.py
"""

from PIL import Image, ImageDraw, ImageFont

FONT = "assets/fonts/Outfit-Bold.ttf"  # the Figma file's weight
OUT = "assets/images/brand/atlas_arrows_wordmark.png"

# Top line is the app accent (여기어때 YDS Cyan 800); slate is the kit value.
ACCENT = (0x1D, 0x8B, 0xFF)  # top line -- also the progress bar fill
SLATE = (0x3A, 0x4A, 0x55)  # bottom line -- also the CTA background

# Rendered oversized, then downsampled: the tracking below is wide enough that
# a small render would land letters on uneven pixel boundaries.
SIZE = 400
TARGET_W = 1184  # 2x the 592px floor
GAP_RATIO = 0.157  # gap between the lines, as a share of the cap height
# Straight from the Figma file: Outfit Bold 112, ATLAS +6% and ARROWS -5%.
# ATLAS is the shorter word tracked slightly out, which leaves the lockup a
# symmetric trapezoid -- that silhouette is the mark. Do NOT track it further
# to match ARROWS in width; that squares it off and has been reverted once.
TRACK_TOP = 0.06
TRACK_BOTTOM = -0.05


def render(text: str, rgb: tuple[int, int, int], tracking: float) -> Image.Image:
    """One line, letter-spaced, cropped to its own ink."""
    font = ImageFont.truetype(FONT, SIZE)
    space = SIZE * tracking
    # Advance per glyph, not the ink width -- otherwise the spacing reads
    # differently after a narrow letter.
    advances = [font.getlength(ch) for ch in text]
    total = sum(advances) + space * (len(text) - 1)
    canvas = Image.new("RGBA", (int(total) + SIZE, SIZE * 3), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    x = SIZE / 2
    for ch, adv in zip(text, advances):
        draw.text((x, SIZE), ch, font=font, fill=rgb + (255,))
        x += adv + space
    return canvas.crop(canvas.getchannel("A").getbbox())


def main() -> None:
    # Both lines are scaled by the SAME factor, so the narrower line stays
    # narrower -- rescaling each to TARGET_W was what squared the lockup off.
    top = render("ATLAS", ACCENT, TRACK_TOP)
    bottom = render("ARROWS", SLATE, TRACK_BOTTOM)

    # The wider line sets the width; the narrower one keeps its true share.
    scale = TARGET_W / bottom.width

    def fit(img: Image.Image) -> Image.Image:
        return img.resize(
            (round(img.width * scale), round(img.height * scale)),
            Image.LANCZOS)

    top, bottom = fit(top), fit(bottom)
    gap = round((top.height + bottom.height) / 2 * GAP_RATIO)

    out = Image.new("RGBA", (TARGET_W, top.height + gap + bottom.height),
                    (0, 0, 0, 0))
    out.paste(top, ((TARGET_W - top.width) // 2, 0), top)
    out.paste(bottom, (0, top.height + gap), bottom)
    out = out.crop(out.getchannel("A").getbbox())

    out.save(OUT)
    w, h = out.size
    print(f"{OUT}  {w}x{h}  ratio={w / h:.2f}:1")


if __name__ == "__main__":
    main()
