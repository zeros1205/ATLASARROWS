"""Validates GPT-generated board silhouettes and packs them into JSON.

Input : one or more text files following docs/BOARD_SHAPE_GUIDE.md format
        (blocks starting with "name:", grid rows of '#'/'.').
Output: assets/shapes/shapes.json with only the shapes that pass every
        rule, plus a rejection report on stdout.

Usage:  python tools/validate_shapes.py shapes_raw/*.txt
"""
import json
import os
import sys
from glob import glob

MIN_ROWS, MAX_ROWS = 10, 18
MIN_COLS, MAX_COLS = 8, 13
MIN_CELLS, MAX_CELLS = 80, 200
MAX_THIN_RATIO = 0.25  # fraction of cells allowed in 1-cell-wide runs


def parse_blocks(text):
    """Yields dicts {name, category, difficulty, grid:[str]}."""
    block = None
    for raw in text.splitlines():
        line = raw.rstrip()
        if line.startswith("name:"):
            if block:
                yield block
            block = {"name": line[5:].strip(), "category": "", "difficulty": "normal", "grid": []}
        elif block is None:
            continue
        elif line.startswith("category:"):
            block["category"] = line.split(":", 1)[1].split("#")[0].strip()
        elif line.startswith("difficulty:"):
            block["difficulty"] = line.split(":", 1)[1].split("#")[0].strip()
        elif line.startswith("size:"):
            pass  # recomputed from the grid
        elif set(line) <= {"#", "."} and line:
            block["grid"].append(line)
    if block:
        yield block


def cells_of(grid):
    return {
        (r, c)
        for r, row in enumerate(grid)
        for c, ch in enumerate(row)
        if ch == "#"
    }


def connected(cells):
    if not cells:
        return False
    seen = set()
    stack = [next(iter(cells))]
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


def thin_ratio(cells):
    """Fraction of cells with no orthogonal-neighbor pair on either axis
    (i.e. sitting in a 1-cell-wide corridor)."""
    thin = 0
    for r, c in cells:
        horiz = (r, c - 1) in cells or (r, c + 1) in cells
        vert = (r - 1, c) in cells or (r + 1, c) in cells
        wide_h = (r - 1, c) in cells and any(
            (r - 1, cc) in cells and (r, cc) in cells for cc in (c - 1, c + 1)
        )
        # Simpler robust check: a cell is "thin" if it has neighbors on at
        # most one axis (pure corridor or dead end).
        if not (horiz and vert):
            thin += 1
            continue
        _ = wide_h
    return thin / len(cells)


def validate(block):
    errors = []
    grid = block["grid"]
    if not grid:
        return ["no grid"]
    rows, cols = len(grid), len(grid[0])
    if any(len(row) != cols for row in grid):
        errors.append("ragged rows")
        return errors
    if not (MIN_ROWS <= rows <= MAX_ROWS):
        errors.append(f"rows {rows} out of {MIN_ROWS}-{MAX_ROWS}")
    if not (MIN_COLS <= cols <= MAX_COLS):
        errors.append(f"cols {cols} out of {MIN_COLS}-{MAX_COLS}")
    cells = cells_of(grid)
    if not (MIN_CELLS <= len(cells) <= MAX_CELLS):
        errors.append(f"cells {len(cells)} out of {MIN_CELLS}-{MAX_CELLS}")
    if cells and not connected(cells):
        errors.append("not one connected region")
    if cells:
        ratio = thin_ratio(cells)
        if ratio > MAX_THIN_RATIO:
            errors.append(f"thin-corridor ratio {ratio:.0%} > {MAX_THIN_RATIO:.0%}")
    return errors


def main(patterns):
    accepted, rejected, seen_names = [], [], set()
    files = [f for p in patterns for f in glob(p)]
    if not files:
        print("no input files matched", patterns)
        return 1
    for path in files:
        with open(path, encoding="utf-8") as f:
            for block in parse_blocks(f.read()):
                errors = validate(block)
                name = block["name"] or "(unnamed)"
                if name in seen_names:
                    errors.append("duplicate name")
                if errors:
                    rejected.append((path, name, errors))
                else:
                    seen_names.add(name)
                    accepted.append(
                        {
                            "name": name,
                            "category": block["category"],
                            "difficulty": block["difficulty"],
                            "rows": len(block["grid"]),
                            "cols": len(block["grid"][0]),
                            "grid": block["grid"],
                        }
                    )
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "shapes")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "shapes.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"shapes": accepted}, f, ensure_ascii=False, indent=1)
    print(f"accepted {len(accepted)}, rejected {len(rejected)} -> {out_path}")
    for path, name, errors in rejected[:50]:
        print(f"  REJECT [{os.path.basename(path)}] {name}: {'; '.join(errors)}")
    if len(rejected) > 50:
        print(f"  ... and {len(rejected) - 50} more")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] or ["shapes_raw/*.txt"]))
