"""Turns the stamp art into per-continent download packs.

The masters are 1024x1024 opaque PNGs at ~1.9 MB each; 216 of those is 419 MB,
which is neither shippable in a bundle nor sane to download. A visa stamp is
drawn small -- it never needs more than 512px even at 3x -- and it has no
transparency, so WebP at q85 lands around 43 KB. That is the whole difference
between 419 MB and 9.5 MB.

Packs are split by continent because that is how the player earns them: a
round belongs to one continent, so the app only ever needs the pack for where
it currently is, and the loading screen fetches one at a time rather than
everything up front.

Output (git-ignored, upload targets):
    build/stamp_packs/stamps-<continent>-v<N>.zip
    assets/campaign/stamp_manifest.json   <- this one ships, it is ~2 KB

Run: python tools/atlas/build_stamp_packs.py
"""

from __future__ import annotations

import hashlib
import io
import json
import pathlib
import re
import zipfile

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "images" / "stamps"
OUT = ROOT / "build" / "stamp_packs"
MANIFEST = ROOT / "assets" / "campaign" / "stamp_manifest.json"
CAMPAIGN = ROOT / "tools" / "atlas" / "campaign.json"

VERSION = 3  # v3: edge 512->384, quality 85->75 to shrink the boot download
EDGE = 384
QUALITY = 75

# Alpha ramp for dropping the warm off-white paper. A pixel's luminance runs
# from ~235 (bare paper) down to the ink; alpha rises from 0 at [PAPER] to 1 at
# [INK], so only the stamp impression survives and its worn grain is kept.
PAPER = 200.0
INK = 110.0

# Natural Earth parks open-ocean territories in a leftover "Seven seas" bucket.
# It is not a continent; each one belongs to a real landmass. Kept in step with
# docs/WORLDMAP_PLAN.md §2.2.
OCEAN_HOME = {
    "British Indian Ocean Territory": "Africa",
    "Seychelles": "Africa",
    "Mauritius": "Africa",
    "Heard Island and McDonald Islands": "Oceania",
}

SLUG = {
    "Africa": "africa",
    "Asia": "asia",
    "Europe": "europe",
    "North America": "north-america",
    "South America": "south-america",
    "Oceania": "oceania",
}

# stamp_001_vatican.png -> 1
RANK = re.compile(r"^stamp_(\d{3})_")


def continents_by_rank() -> dict[int, str]:
    rows = json.loads(CAMPAIGN.read_text(encoding="utf-8"))["countries"]
    out = {}
    for r in rows:
        cont = OCEAN_HOME.get(r["name"], r["continent"])
        out[r["rank"]] = cont
    return out


def encode(path: pathlib.Path) -> bytes:
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    alpha = np.clip((PAPER - lum) / (PAPER - INK), 0.0, 1.0) * 255.0
    im = Image.fromarray(
        np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")
    if im.width != EDGE:
        im = im.resize((EDGE, EDGE), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "WEBP", quality=QUALITY, method=6)
    return buf.getvalue()


def main() -> None:
    by_rank = continents_by_rank()
    OUT.mkdir(parents=True, exist_ok=True)

    groups: dict[str, list[tuple[int, pathlib.Path]]] = {}
    orphans = []
    for f in sorted(SRC.glob("stamp_*.png")):
        m = RANK.match(f.name)
        if not m:
            continue  # stamp_00.png and friends -- the old placeholder set
        rank = int(m.group(1))
        cont = by_rank.get(rank)
        if cont is None:
            orphans.append(f.name)
            continue
        groups.setdefault(cont, []).append((rank, f))

    packs = []
    for cont, items in sorted(groups.items()):
        slug = SLUG[cont]
        name = f"stamps-{slug}-v{VERSION}.zip"
        dest = OUT / name
        # Deflate is pointless on WebP and only costs decode time on the phone;
        # the zip is here to make one file out of many, not to compress.
        with zipfile.ZipFile(dest, "w", zipfile.ZIP_STORED) as z:
            for rank, f in sorted(items):
                z.writestr(f"{rank:03d}.webp", encode(f))
        blob = dest.read_bytes()
        packs.append({
            "continent": cont,
            "slug": slug,
            "file": name,
            "count": len(items),
            "bytes": len(blob),
            "sha256": hashlib.sha256(blob).hexdigest(),
            # Which rounds this pack covers. The app resolves rank -> pack from
            # here rather than from a continent field on the round, so the two
            # cannot fall out of step and bank.json needs no new column.
            "ranks": [r for r, _ in sorted(items)],
        })
        print(f"{slug:<14} {len(items):>3} stamps  {len(blob) / 1e6:>6.2f} MB")

    MANIFEST.write_text(
        json.dumps({"version": VERSION, "edge": EDGE, "packs": packs},
                   ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")

    total = sum(p["bytes"] for p in packs)
    done = sum(p["count"] for p in packs)
    print(f"\n{done}/216 stamps · {total / 1e6:.2f} MB total")
    print(f"manifest → {MANIFEST.relative_to(ROOT)}")
    if orphans:
        print(f"⚠ {len(orphans)} file(s) with no matching rank: {orphans[:3]}")


if __name__ == "__main__":
    main()
