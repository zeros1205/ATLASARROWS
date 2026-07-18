"""Converts the GPT metaphor table (docs/Z_ARROWS_METAPHOR_BOARD_SHAPE_2000.md)
into real, validated silhouette masks: assets/shapes/shapes.json.

Each table row carries a category, bounding size, target cell count, and
difficulty. This script synthesizes a parametric mask per row (seeded by
the row number, family picked from category/keywords), scales it toward
the target cell count, enforces the BOARD_SHAPE_GUIDE constraints, and
falls back to a plain blob when a family fails validation.

Usage: python tools/build_shape_masks.py
"""
import json
import math
import os
import random
import re
import sys
from glob import glob

MIN_ROWS, MAX_ROWS = 10, 18
MIN_COLS, MAX_COLS = 8, 13
MIN_CELLS, MAX_CELLS = 80, 200


def in_ellipse(r, c, cy, cx, ry, rx):
    dy = (r - cy) / ry
    dx = (c - cx) / rx
    return dy * dy + dx * dx <= 1.0


def mask_ellipse(rows, cols, scale, rng):
    cy, cx = (rows - 1) / 2, (cols - 1) / 2
    return {
        (r, c)
        for r in range(rows)
        for c in range(cols)
        if in_ellipse(r, c, cy, cx, rows / 2 * scale, cols / 2 * scale)
    }


def mask_rect(rows, cols, scale, rng):
    rr = max(4, int(rows * scale))
    cc = max(4, int(cols * scale))
    r0, c0 = (rows - rr) // 2, (cols - cc) // 2
    return {(r, c) for r in range(r0, r0 + rr) for c in range(c0, c0 + cc)}


def mask_diamond(rows, cols, scale, rng):
    cy, cx = (rows - 1) / 2, (cols - 1) / 2
    return {
        (r, c)
        for r in range(rows)
        for c in range(cols)
        if abs(r - cy) / (rows / 2 * scale) + abs(c - cx) / (cols / 2 * scale) <= 1.0
    }


def mask_blob(rows, cols, scale, rng):
    mask = set()
    for _ in range(3):
        cy = rows * (0.3 + rng.random() * 0.4)
        cx = cols * (0.3 + rng.random() * 0.4)
        ry = max(2.5, rows * (0.26 + rng.random() * 0.22) * scale)
        rx = max(2.5, cols * (0.26 + rng.random() * 0.22) * scale)
        for r in range(rows):
            for c in range(cols):
                if in_ellipse(r, c, cy, cx, ry, rx):
                    mask.add((r, c))
    return mask


def mask_ring(rows, cols, scale, rng):
    cy, cx = (rows - 1) / 2, (cols - 1) / 2
    outer = mask_ellipse(rows, cols, scale, rng)
    hole = {
        (r, c)
        for r in range(rows)
        for c in range(cols)
        if in_ellipse(r, c, cy, cx, max(1.5, rows * 0.18), max(1.5, cols * 0.18))
    }
    return outer - hole


def mask_cross(rows, cols, scale, rng):
    arm_r = max(2, int(rows * 0.22 * scale))
    arm_c = max(2, int(cols * 0.26 * scale))
    cy, cx = rows // 2, cols // 2
    return {
        (r, c)
        for r in range(rows)
        for c in range(cols)
        if abs(r - cy) <= arm_r or abs(c - cx) <= arm_c
    }


FAMILIES = {
    "organic": [mask_blob, mask_ellipse, mask_blob, mask_ring],
    "geometric": [mask_rect, mask_diamond, mask_ellipse, mask_cross, mask_ring],
}
KEYWORD_FAMILIES = [
    ("소용돌이", mask_ring),
    ("나선", mask_ring),
    ("십자", mask_cross),
    ("교차", mask_cross),
    ("사각", mask_rect),
    ("마름모", mask_diamond),
    ("다이아", mask_diamond),
    ("원형", mask_ellipse),
]


def connected(cells):
    if not cells:
        return False
    seen, stack = set(), [next(iter(cells))]
    while stack:
        cur = stack.pop()
        if cur in seen:
            continue
        seen.add(cur)
        r, c = cur
        for nxt in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
            if nxt in cells and nxt not in seen:
                stack.append(nxt)
    return len(seen) == len(cells)


def largest_component(cells):
    remaining, best = set(cells), set()
    while remaining:
        stack, comp = [next(iter(remaining))], set()
        while stack:
            cur = stack.pop()
            if cur not in remaining:
                continue
            remaining.discard(cur)
            comp.add(cur)
            r, c = cur
            for nxt in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
                if nxt in remaining:
                    stack.append(nxt)
        if len(comp) > len(best):
            best = comp
    return best


def thin_ratio(cells):
    thin = 0
    for r, c in cells:
        horiz = (r, c - 1) in cells or (r, c + 1) in cells
        vert = (r - 1, c) in cells or (r + 1, c) in cells
        if not (horiz and vert):
            thin += 1
    return thin / len(cells) if cells else 1.0


def synth_mask(rows, cols, target, family, rng):
    """Scales the family toward the target cell count, keeps it legal."""
    best = None
    for scale in (1.0, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7):
        mask = largest_component(family(rows, cols, scale, rng))
        if not mask:
            continue
        if len(mask) < MIN_CELLS:
            break  # shrinking further only loses cells
        if thin_ratio(mask) > 0.3:
            continue
        best = mask
        if len(mask) <= max(target, MIN_CELLS) or len(mask) <= MAX_CELLS:
            if abs(len(mask) - target) <= max(20, target * 0.2):
                return mask
    if best and MIN_CELLS <= len(best) <= MAX_CELLS:
        return best
    return None


ROW_RE = re.compile(r"^\|\s*(\d+)\s*\|")


def parse_rows(md_path):
    rows = []
    with open(md_path, encoding="utf-8") as f:
        for line in f:
            if not ROW_RE.match(line):
                continue
            parts = [p.strip() for p in line.strip().strip("|").split("|")]
            if len(parts) < 7:
                continue
            no, theme, category, idea, diff, size, target = parts[:7]
            m = re.match(r"(\d+)\s*x\s*(\d+)", size)
            if not m:
                continue
            rows.append(
                {
                    "no": int(no),
                    "theme": theme,
                    "category": category,
                    "idea": idea,
                    "difficulty": "boss" if "boss" in diff else "normal",
                    "rows": int(m.group(1)),
                    "cols": int(m.group(2)),
                    "target": int(re.sub(r"\D", "", target) or 100),
                }
            )
    return rows


def clamp_size(rows, cols):
    return (
        min(max(rows, MIN_ROWS), MAX_ROWS),
        min(max(cols, MIN_COLS), MAX_COLS),
    )


def pick_family(row, rng):
    for kw, fam in KEYWORD_FAMILIES:
        if kw in row["idea"] or kw in row["theme"]:
            return fam
    fams = FAMILIES.get(row["category"], FAMILIES["organic"])
    return fams[rng.randrange(len(fams))]


def load_picture_shapes(root):
    """Hand-authored picture silhouettes (shapes_raw/*.txt) that pass
    validate_shapes rules — appended after the synthesized catalog."""
    import validate_shapes as vs

    pictures = []
    for path in sorted(glob(os.path.join(root, "shapes_raw", "*.txt"))):
        with open(path, encoding="utf-8") as f:
            for block in vs.parse_blocks(f.read()):
                if vs.validate(block):
                    continue
                pictures.append(
                    {
                        "name": block["name"],
                        "theme": "picture",
                        "category": block["category"] or "picture",
                        "difficulty": block["difficulty"],
                        "rows": len(block["grid"]),
                        "cols": len(block["grid"][0]),
                        "grid": block["grid"],
                    }
                )
    return pictures


def main():
    root = os.path.join(os.path.dirname(__file__), "..")
    md = os.path.join(root, "docs", "Z_ARROWS_METAPHOR_BOARD_SHAPE_2000.md")
    rows = parse_rows(md)
    if not rows:
        print("no rows parsed from", md)
        return 1
    shapes, fallbacks, failures = [], 0, 0
    for row in rows:
        rng = random.Random(row["no"] * 7919)
        rr, cc = clamp_size(row["rows"], row["cols"])
        target = min(max(row["target"], MIN_CELLS), MAX_CELLS)
        if row["difficulty"] == "boss":
            target = max(target, 130)
        mask = synth_mask(rr, cc, target, pick_family(row, rng), rng)
        if mask is None:
            mask = synth_mask(rr, cc, target, mask_blob, rng)
            fallbacks += 1
        if mask is None or not connected(mask):
            failures += 1
            continue
        grid = [
            "".join("#" if (r, c) in mask else "." for c in range(cc))
            for r in range(rr)
        ]
        shapes.append(
            {
                "name": f"{row['no']:04d}-{row['idea']}",
                "theme": row["theme"],
                "category": row["category"],
                "difficulty": row["difficulty"],
                "rows": rr,
                "cols": cc,
                "grid": grid,
            }
        )
    pictures = load_picture_shapes(root)
    shapes += pictures
    out_dir = os.path.join(root, "assets", "shapes")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "shapes.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"shapes": shapes}, f, ensure_ascii=False, separators=(",", ":"))
    print(
        f"rows={len(rows)} shapes={len(shapes)} (pictures={len(pictures)}) "
        f"fallbacks={fallbacks} failures={failures} -> {out} "
        f"({os.path.getsize(out)//1024}KB)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
