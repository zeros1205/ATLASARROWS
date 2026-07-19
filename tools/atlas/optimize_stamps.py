"""Shrinks generated stamp PNGs into shippable assets.

The image model returns 1024x1024 PNGs at roughly 1.9MB each — about 400MB
for the full set, which is more than the whole game should weigh. Stamps are
only ever drawn as a collection thumbnail or a round-completion flourish, so
they re-encode to WebP at a fraction of that with no visible loss.

Originals stay put under tools/atlas/stamps_raw/ (git-ignored) so a stamp can
be re-encoded at a different size without paying to generate it again.

Usage:
  python tools/atlas/optimize_stamps.py            # 512px, quality 85
  python tools/atlas/optimize_stamps.py 640 88     # size, quality
"""
import os
import shutil
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(REPO, "assets", "images", "stamps")
RAW = os.path.join(HERE, "stamps_raw")

SIZE = int(sys.argv[1]) if len(sys.argv) > 1 else 512
QUALITY = int(sys.argv[2]) if len(sys.argv) > 2 else 85


def main():
    os.makedirs(RAW, exist_ok=True)
    pngs = sorted(f for f in os.listdir(SRC)
                  if f.startswith("stamp_") and f.endswith(".png"))
    if not pngs:
        print("변환할 PNG가 없습니다.")
        return

    before = after = 0
    for name in pngs:
        src = os.path.join(SRC, name)
        before += os.path.getsize(src)

        # keep the original out of the way before the asset dir is rewritten
        keep = os.path.join(RAW, name)
        if not os.path.exists(keep):
            shutil.copy2(src, keep)

        im = Image.open(src).convert("RGB")
        if im.width != SIZE:
            im = im.resize((SIZE, SIZE), Image.LANCZOS)
        dest = os.path.join(SRC, name[:-4] + ".webp")
        im.save(dest, "WEBP", quality=QUALITY, method=6)
        after += os.path.getsize(dest)
        os.remove(src)

    n = len(pngs)
    print(f"{n}장 · {SIZE}px WebP q{QUALITY}")
    print(f"  이전 {before / 1024 / 1024:6.1f}MB  (장당 {before / n / 1024:5.0f}KB)")
    print(f"  이후 {after / 1024 / 1024:6.1f}MB  (장당 {after / n / 1024:5.0f}KB)")
    print(f"  {before / after:.0f}분의 1로 축소")
    print(f"  원본 보관: {RAW}")


if __name__ == "__main__":
    main()
