"""Difficulty relayout pass for the campaign bank.

Runs AFTER build_bank.py. Board GEOMETRY (grids, sizes) is produced by the
Dart pipeline (export_boards.dart -> all_boards.json -> build_bank.py) and is
left untouched here; this pass only re-lays the ARROWS on each fixed grid to
hit a measurable difficulty curve. Every board is validated solvable before it
is written, so the reverse-removal guarantee the app relies on is preserved.

Why a separate pass (2026-07-20): the three levers that actually move
difficulty were measured on the shipped bank and are applied here so the curve
is reproducible without a Dart toolchain.

  WS1  density cap     — stop the repair pass once the fill target is hit
                         (the old repair filled to ~97%, which made every ray
                         hit a wall at the arrowhead: no traps).
  WS2  length mix      — bias toward long arrows; long rays can be blocked far
                         away, which is what a "trap" (looks escapable, isn't)
                         needs.
  WS3  chain reorient  — flip each arrow's head to the end whose exit ray
                         crosses the most OTHER arrows. This raises far-blocks
                         (spatial traps) AND forces removal order (temporal
                         traps: left must leave before right can) at once.

A trap, precisely: a BLOCKED tap whose ray runs >= 3 free cells before hitting
the blocker (board_logic.dart's freeSteps). freeSteps==0 is a visible wall the
player never errs on; large freeSteps is the mistake that spends a heart.

Difficulty is ramped by country rank (campaign is area-ascending, so rank is
the progression axis): early rounds stay gentle, late rounds carry the traps.
Tune the `tier()` table and re-run; `measure()` prints the realised curve.

Usage:
    python tools/atlas/relayout_difficulty.py            # in place
    python tools/atlas/relayout_difficulty.py out.json   # to a copy
"""
import json
import math
import os
import random
import sys
import time
from collections import deque

try:
    from PIL import Image
    _HAS_PIL = True
except ImportError:
    _HAS_PIL = False

# Enlarge each silhouette mask to ~this many cells so even a small territory
# holds 100+ arrows including long ones. Grid resolution is decoupled from
# territory size (per product decision). Idempotent — a mask already at/over
# the target is left as-is, so re-running never re-upscales.
# ~1050 filled cells per board (was 1500): a smaller grid renders at a larger
# on-screen scale — bigger cells, easier to read and tap — and carries ~30%
# fewer arrows. The silhouette stays smooth (bilinear rescale), just coarser.
UPSCALE_TARGET = 1050


def upscale_mask(grid, target=UPSCALE_TARGET):
    """Rescale a mask to ~target filled cells (float scale, bilinear +
    re-threshold, so edges round rather than staircase). Scales both up and
    down; no-op without PIL or when already at the target size."""
    rows = len(grid)
    cols = len(grid[0])
    cells = sum(row.count('#') for row in grid)
    if cells == 0 or not _HAS_PIL:
        return grid, rows, cols
    s = math.sqrt(target / cells)
    nc = max(4, round(cols * s))
    nr = max(4, round(rows * s))
    if (nc, nr) == (cols, rows):
        return grid, rows, cols
    img = Image.new('L', (cols, rows), 0)
    px = img.load()
    for r in range(rows):
        for c in range(cols):
            if grid[r][c] == '#':
                px[c, r] = 255
    big = img.resize((nc, nr), Image.BILINEAR)
    bp = big.load()
    ng = [''.join('#' if bp[c, r] > 100 else '.' for c in range(nc))
          for r in range(nr)]
    return ng, nr, nc

DIRS = [(-1, 0), (1, 0), (0, -1), (0, 1)]  # U D L R
GROW = True  # repair fallback that lengthens an arrow to fill a lone hole;
             # off => keep arrows short (more of them) at the cost of a few holes
REPAIR = True  # bent 3-cell hole-fill pass; off => arrows keep their sampled
               # mid/long length (fewer short fillers) at the cost of some holes

# Relative weights for the short (2-3 cells) / mid (4-6) / long (7-maxLen)
# bands an arrow's length is drawn from. Mirrors lib/models/level_generator
# LenMixes so a future Dart-side port lands the same distribution.
BALANCED = dict(short=0.38, mid=0.42, long=0.20)
LONGER = dict(short=0.22, mid=0.40, long=0.38)
# Short-biased so a board carries >=100 bent arrows; late ranks get a few more
# long arrows for far-block traps.
# Grids are enlarged (mask upscaled) so every board has room for MANY arrows
# AND a high share of long spanning ones — challenge does not scale with
# territory size. Long share is deliberately high; the seeds add more on top.
# Sampling weights (short<=7 / mid 8-15 / long 16+). Long-heavy on purpose:
# arrows get cut short at walls and the hole-fill adds shorts, so heavy long/mid
# sampling lands the FINAL mix near short~40 / mid~40 / long~15-20.
SHORTBENT = dict(short=0.0, mid=0.55, long=0.45)
SHORTMID = dict(short=0.0, mid=0.55, long=0.45)


def tier(rank, total):
    """Difficulty knobs for a country's rank. Area-ascending campaign, so a
    higher rank is later in the game. Returns (fill, lenmix, reorient_frac).

    frac=1.0 EVERYWHERE: every arrow is reoriented to be blocked, so no stage
    is spam-clearable (a cluster all pointing at an open edge). Fill is kept
    high (dense) so most rays hit a wall — tapping a blocked arrow costs a
    heart, which is what punishes spam-tapping. Difficulty ramps via arrow
    length (more far-block traps late), not by leaving arrows freely escapable."""
    t = (rank - 1) / (total - 1) if total > 1 else 1.0
    lenmix = SHORTBENT if t < 0.5 else SHORTMID
    return dict(fill=0.97, lenmix=lenmix, frac=1.0)


# ---------------------------------------------------------------------------
# Generator — a faithful port of lib/models/level_generator.dart's insertion
# maze, plus the WS1 density cap. Boards differ cell-for-cell from the Dart RNG
# but the aggregate difficulty matches (validated against the shipped bank).
# ---------------------------------------------------------------------------
def gen_level(rows, cols, mask, seed, fill, max_len, lenmix):
    rng = random.Random(seed)
    mask = set(mask)
    occupied = set()
    oriented = []
    target = int(len(mask) * fill)

    def in_bounds(r, c):
        return 0 <= r < rows and 0 <= c < cols

    # BFS depth from the mask boundary; interior cells are filled first.
    depth = {}
    q = deque()
    for (r, c) in mask:
        if any((r + dr, c + dc) not in mask for dr, dc in DIRS):
            depth[(r, c)] = 0
            q.append((r, c))
    while q:
        r, c = q.popleft()
        d = depth[(r, c)]
        for dr, dc in DIRS:
            n = (r + dr, c + dc)
            if n in mask and n not in depth:
                depth[n] = d + 1
                q.append(n)

    def ray_clear(path):
        (r1, c1), (r2, c2) = path[-2], path[-1]
        dr, dc = r2 - r1, c2 - c1
        r, c = r2 + dr, c2 + dc
        while in_bounds(r, c):
            if (r, c) in occupied:
                return False
            r += dr
            c += dc
        return True

    ws = lenmix['short']
    wm = ws + lenmix['mid']
    wt = wm + lenmix['long']

    def sample_len():
        x = rng.random() * wt
        if x < ws:                          # short: 3-7
            return 3 + rng.randint(0, 4)
        if x < wm:                          # mid: 8-15
            return 8 + rng.randint(0, 7)
        return 16 + rng.randint(0, max(0, max_len - 16))  # long: 16+

    # Long-arrow seeding: place a couple of ~20-cell "spanning" arrows first (on
    # a near-empty board a path can snake far), so every stage has one or two
    # long arrows cutting across the territory plus the short/mid mix.
    LONGMIN = 16          # a seed only counts once it is genuinely long
    long_seeds = 3
    placed_long = 0
    long_tries = 0

    failures = 0
    while len(occupied) < target and failures < 2000:
        empties = [
            cell for cell in mask
            if cell not in occupied and any(
                (cell[0] + dr, cell[1] + dc) in mask
                and (cell[0] + dr, cell[1] + dc) not in occupied
                for dr, dc in DIRS)
        ]
        if not empties:
            break
        empties.sort(key=lambda c: -depth[c])
        band = min(8, len(empties))
        cur = (empties[rng.randrange(band)] if rng.random() < 0.6
               else empties[rng.randrange(len(empties))])
        path = [cur]
        used = {cur}
        last_dir = None
        turned = False
        # First few placements are forced long with long straight runs (a
        # sweeping cut); the rest use the mix with tight turns for dense fill.
        force_long = placed_long < long_seeds and long_tries < 120
        if force_long:
            long_tries += 1
            tlen = 26           # aim well past 20; the builder stops at the wall
            sp = 0.72           # long straight runs => a sweeping cut
        else:
            tlen = sample_len()
            sp = 0.22
        while len(path) < tlen:
            options = []
            for dr, dc in DIRS:
                n = (cur[0] + dr, cur[1] + dc)
                if n in mask and n not in occupied and n not in used:
                    options.append(((dr, dc), n))
            if not options:
                break
            rng.shuffle(options)
            straight = [o for o in options if o[0] == last_dir]
            turn_opts = [o for o in options if o[0] != last_dir]
            last = len(path) == tlen - 1
            pick = None
            # Guarantee a bend: if the arrow is about to finish straight, turn.
            if last and not turned and last_dir is not None and turn_opts:
                pick = max(turn_opts, key=lambda o: depth[o[1]])
            # Otherwise mostly turn (kills long straight runs), rarely continue.
            if pick is None and last_dir is not None and straight and rng.random() < sp:
                pick = straight[0]
            if pick is None and turn_opts:
                pick = max(turn_opts, key=lambda o: depth[o[1]])
            if pick is None:
                pick = options[0]
            if last_dir is not None and pick[0] != last_dir:
                turned = True
            path.append(pick[1])
            used.add(pick[1])
            cur = pick[1]
            last_dir = pick[0]
        # Bent arrows only: a run that never turned (or is < 3 cells) is dropped.
        if len(path) < 3 or not turned:
            failures += 1
            continue
        fwd = path
        rev = path[::-1]
        candidates = ([fwd, rev] if depth[path[-1]] <= depth[path[0]]
                      else [rev, fwd])
        chosen = None
        for cand in candidates:
            if ray_clear(cand):
                chosen = cand
                break
        if chosen is None:
            failures += 1
            continue
        occupied.update(path)
        oriented.append(chosen)
        if len(chosen) >= LONGMIN:
            placed_long += 1
        failures = 0

    # Repair passes fill remaining holes while preserving the reverse-removal
    # invariant. WS1: stop once the fill target is reached so the board keeps
    # the empty space long rays need.
    def ray_cells(line):
        (r1, c1), (r2, c2) = line[-2], line[-1]
        dr, dc = r2 - r1, c2 - c1
        r, c = r2 + dr, c2 + dc
        out = []
        while in_bounds(r, c):
            out.append((r, c))
            r += dr
            c += dc
        return out

    MAX_GROWN = 16
    progressed = REPAIR
    while progressed:
        progressed = False
        if len(occupied) >= target:  # WS1 density cap
            break
        rays = [set(ray_cells(l)) for l in oriented]
        cell_owner = {}
        for i, l in enumerate(oriented):
            for cell in l:
                cell_owner[cell] = i

        def splice(cand):
            max_blocked = -1
            for i in range(len(oriented)):
                if any(c in rays[i] for c in cand):
                    max_blocked = max(max_blocked, i)
            min_blocker = len(oriented)
            for cell in ray_cells(cand):
                if cell in cell_owner:
                    min_blocker = min(min_blocker, cell_owner[cell])
            if max_blocked >= min_blocker:
                return False
            oriented.insert(max_blocked + 1, cand)
            occupied.update(cand)
            return True

        for cell in mask:
            if cell in occupied:
                continue
            r, c = cell
            done = False
            # Bent 3-cell candidates through empty cells only (no straight
            # arrows): cell as the corner, or cell as an end that turns at n.
            empt = [((dr, dc), (r + dr, c + dc)) for dr, dc in DIRS
                    if (r + dr, c + dc) in mask and (r + dr, c + dc) not in occupied]

            # Prefer filling a hole with a MID (4-7 cell) bent snake so empty
            # pockets become mid arrows, not a swarm of 3-cell shorts.
            def snake_from(start, maxlen=7):
                path = [start]; used = {start}; cur = start
                last = None; turned = False
                while len(path) < maxlen:
                    opts = [((dr, dc), (cur[0] + dr, cur[1] + dc)) for dr, dc in DIRS
                            if (cur[0] + dr, cur[1] + dc) in mask
                            and (cur[0] + dr, cur[1] + dc) not in occupied
                            and (cur[0] + dr, cur[1] + dc) not in used]
                    if not opts:
                        break
                    turn = [o for o in opts if o[0] != last]
                    pick = (turn[0] if turn and (last is None or rng.random() < 0.7)
                            else opts[0])
                    if last is not None and pick[0] != last:
                        turned = True
                    path.append(pick[1]); used.add(pick[1])
                    cur = pick[1]; last = pick[0]
                return path if len(path) >= 3 and turned else None

            cands = []
            snake = snake_from((r, c))
            if snake:
                cands.append(snake)
            for i in range(len(empt)):
                for j in range(len(empt)):
                    if i == j:
                        continue
                    (d1, a), (d2, b) = empt[i], empt[j]
                    if d1[0] == -d2[0] and d1[1] == -d2[1]:
                        continue  # opposite dirs through the corner = straight
                    cands.append([a, cell, b])
            for (dr, dc), n in empt:
                for dr2, dc2 in DIRS:
                    if (dr2, dc2) == (dr, dc) or (dr2, dc2) == (-dr, -dc):
                        continue
                    m = (n[0] + dr2, n[1] + dc2)
                    if m in mask and m not in occupied and m != cell:
                        cands.append([cell, n, m])
            for cand in cands:
                done = splice(cand) or splice(cand[::-1])
                if done:
                    break
            if not done and GROW:
                for dr, dc in DIRS:
                    n = (r + dr, c + dc)
                    owner = cell_owner.get(n)
                    if (owner is None or oriented[owner][0] != n
                            or len(oriented[owner]) >= MAX_GROWN):
                        continue
                    crossed = any(cell in rays[j]
                                  for j in range(owner + 1, len(oriented)))
                    if crossed:
                        continue
                    oriented[owner] = [cell] + oriented[owner]
                    occupied.add(cell)
                    done = True
                    break
            if done:
                progressed = True
                break
    return oriented


def ray_cells_g(line, rows, cols):
    (r1, c1), (r2, c2) = line[-2], line[-1]
    dr, dc = r2 - r1, c2 - c1
    r, c = r2 + dr, c2 + dc
    out = []
    while 0 <= r < rows and 0 <= c < cols:
        out.append((r, c))
        r += dr
        c += dc
    return out


def solvable(rows, cols, ori):
    """Greedy fixpoint: removals never block another line, so if the greedy
    solve empties the board a solution exists (mirrors BoardLogic.isSolvable)."""
    owner = {}
    for i, l in enumerate(ori):
        for cell in l:
            owner[cell] = i
    live = dict(owner)
    present = set(range(len(ori)))

    def free(i, l):
        (r1, c1), (r2, c2) = l[-2], l[-1]
        dr, dc = r2 - r1, c2 - c1
        r, c = l[-1][0] + dr, l[-1][1] + dc
        while 0 <= r < rows and 0 <= c < cols:
            o = live.get((r, c))
            if o is not None and o != i:
                return False
            r += dr
            c += dc
        return True

    prog = True
    while present and prog:
        prog = False
        for i in list(present):
            if free(i, ori[i]):
                present.discard(i)
                prog = True
                for cell in ori[i]:
                    if live.get(cell) == i:
                        del live[cell]
    return not present


def chain_reorient(rows, cols, ori, frac, rng):
    """WS3: flip a fraction of arrows' heads to the end whose ray crosses more
    other bodies. Each flip is kept only if the board stays solvable."""
    body = {}
    for i, l in enumerate(ori):
        for cell in l:
            body[cell] = i
    for i in range(len(ori)):
        if rng.random() > frac:
            continue
        fwd = ori[i]
        rev = fwd[::-1]

        def crossings(cand):
            return sum(1 for cell in ray_cells_g(cand, rows, cols)
                       if body.get(cell) not in (None, i))
        if crossings(rev) > crossings(fwd):
            ori[i] = rev
            if not solvable(rows, cols, ori):
                ori[i] = fwd
    return ori


def encode(cells):
    b = ["%d,%d:" % (cells[0][0], cells[0][1])]
    for i in range(1, len(cells)):
        dr = cells[i][0] - cells[i - 1][0]
        dc = cells[i][1] - cells[i - 1][1]
        b.append('U' if dr == -1 else 'D' if dr == 1 else 'L' if dc == -1 else 'R')
    return "".join(b)


def measure(rows, cols, ori):
    """Trap ratio (blocks >= 3 cells out) and branching (avg escapable lines
    per solve step) — the two difficulty proxies (audit_traps / audit_diff)."""
    owner = {}
    for i, l in enumerate(ori):
        for cell in l:
            owner[cell] = i

    def block(i, l, live):
        (r1, c1), (r2, c2) = l[-2], l[-1]
        dr, dc = r2 - r1, c2 - c1
        r, c = l[-1][0] + dr, l[-1][1] + dc
        steps = 0
        while 0 <= r < rows and 0 <= c < cols:
            o = live.get((r, c))
            if o is not None and o != i:
                return steps
            steps += 1
            r += dr
            c += dc
        return None

    live = dict(owner)
    present = set(range(len(ori)))
    nb = trap3 = branch_sum = steps = g = 0
    while present and g < 20000:
        g += 1
        freed = []
        for i in list(present):
            b = block(i, ori[i], live)
            if b is None:
                freed.append(i)
            else:
                nb += 1
                if b >= 3:
                    trap3 += 1
        if not freed:
            break
        branch_sum += len(freed)
        steps += 1
        rem = freed[0]
        present.discard(rem)
        for cell in ori[rem]:
            if live.get(cell) == rem:
                del live[cell]
    lens = [len(l) for l in ori]
    return dict(
        two_cell=sum(1 for x in lens if x <= 2) / len(lens),
        long=sum(1 for x in lens if x >= 7) / len(lens),
        trap=(trap3 / nb) if nb else 0.0,
        branching=(branch_sum / steps) if steps else 0.0,
        density=len(set().union(*ori)) / (rows * cols) if ori else 0.0,
        solvable=not present,
    )


def relayout(path_in, path_out):
    with open(path_in, encoding="utf-8") as f:
        bank = json.load(f)
    countries = bank["countries"]
    total = len(countries)
    t0 = time.time()
    nfail = nstage = 0
    seg = {'A': [], 'B': [], 'C': [], 'D': []}
    # Verification tallies: every arrow must bend, every stage should carry
    # >=100 arrows, and no stage should be spam-clearable.
    n_straight = n_under100 = 0
    counts = []
    spam_ratios = []
    under100 = []  # (count, mask cells, name, stage)
    catdist = [0, 0, 0]  # short<=7 / mid 8-15 / long>=16
    fills = []

    def segname(rank):
        t = (rank - 1) / (total - 1) if total > 1 else 1.0
        return 'A' if t < 0.10 else 'B' if t < 0.45 else 'C' if t < 0.75 else 'D'

    def build(rows, cols, mask, seed, cfg):
        """Try a few seeds; keep the most-arrows solvable layout, stopping once
        a layout is solid enough (the fill cap sets the count now)."""
        best = None
        for a in range(3):
            sd = seed + a * 131
            ori = gen_level(rows, cols, mask, sd, cfg['fill'], 26, cfg['lenmix'])
            ori = chain_reorient(rows, cols, ori, cfg['frac'],
                                 random.Random(sd + 7))
            if not ori or not solvable(rows, cols, ori):
                continue
            if best is None or len(ori) > len(best):
                best = ori
            if len(best) >= 100:
                break
        return best

    def initial_free(rows, cols, ori):
        live = {}
        for i, l in enumerate(ori):
            for cell in l:
                live[cell] = i

        def blocked(i, l):
            (r1, c1), (r2, c2) = l[-2], l[-1]
            dr, dc = r2 - r1, c2 - c1
            r, c = l[-1][0] + dr, l[-1][1] + dc
            while 0 <= r < rows and 0 <= c < cols:
                o = live.get((r, c))
                if o is not None and o != i:
                    return True
                r += dr
                c += dc
            return False
        return sum(1 for i, l in enumerate(ori) if not blocked(i, l))

    def straight_count(ori):
        return sum(1 for l in ori
                   if all((l[k][0] - l[k - 1][0], l[k][1] - l[k - 1][1])
                          == (l[1][0] - l[0][0], l[1][1] - l[0][1])
                          for k in range(1, len(l))))

    for c in countries:
        rank = c["rank"]
        cfg = tier(rank, total)
        for si, s in enumerate(c["stages"]):
            # PATH (travel) stages own their transport-silhouette grids and are
            # (re)generated by build_paths.py — never touch them here, or their
            # ~1200-cell masks would be upscaled to the content target.
            if s.get("kind") == "path":
                continue
            nstage += 1
            # Enlarge the mask (grid) for small territories so every board has
            # room for many arrows; writes the bigger grid back into the bank.
            grid, rows, cols = upscale_mask(s["grid"])
            s["grid"], s["rows"], s["cols"] = grid, rows, cols
            mask = {(r, cc) for r, row in enumerate(grid)
                    for cc, ch in enumerate(row) if ch == '#'}
            seed = rank * 100000 + si * 997 + len(grid)
            ori = build(rows, cols, mask, seed, cfg)
            if not ori or not solvable(rows, cols, ori):
                nfail += 1  # leave the original layout in place
                continue
            s["lines"] = [encode(l) for l in ori]
            n_straight += straight_count(ori)
            counts.append(len(ori))
            fills.append(len(set().union(*ori)) / len(mask))
            for l in ori:
                L = len(l)
                catdist[0 if L <= 7 else 1 if L <= 15 else 2] += 1
            spam_ratios.append(initial_free(rows, cols, ori) / len(ori))
            if len(ori) < 100:
                n_under100 += 1
                under100.append((len(ori), len(mask), c["name"], s["name"]))
            seg[segname(rank)].append(measure(rows, cols, ori))

    with open(path_out, "w", encoding="utf-8") as f:
        json.dump({"countries": countries}, f, ensure_ascii=False,
                  separators=(",", ":"))

    print("relayout %d boards | %d kept-original (unsolvable) | %.1fs"
          % (nstage, nfail, time.time() - t0))
    print("\nseg  boards  dens  2cell  long  trap  branch  solvable")
    import statistics
    for k in ['A', 'B', 'C', 'D']:
        ms = seg[k]
        if not ms:
            continue

        def mn(field):
            return statistics.mean(m[field] for m in ms)
        print("%s   %5d   %3.0f   %3.0f   %3.0f  %4.1f   %4.1f   %d/%d" % (
            k, len(ms), 100 * mn('density'), 100 * mn('two_cell'),
            100 * mn('long'), 100 * mn('trap'), mn('branching'),
            sum(m['solvable'] for m in ms), len(ms)))

    cs = sorted(counts)
    tot = sum(catdist) or 1
    print("\n=== RULE CHECK ===")
    print("straight arrows (must be 0): %d" % n_straight)
    print("length mix short<=7/mid8-15/long>=16: %d/%d/%d %%"
          % (100 * catdist[0] // tot, 100 * catdist[1] // tot,
             100 * catdist[2] // tot))
    print("fill: mean %.0f%%  min %.0f%%"
          % (100 * statistics.mean(fills), 100 * min(fills)))
    print("arrow count: min %d  median %d  max %d"
          % (cs[0], cs[len(cs) // 2], cs[-1]))
    print("stages with <100 arrows: %d/%d (%.0f%%)"
          % (n_under100, len(counts), 100 * n_under100 / len(counts)))
    print("spam (initial-escapable) ratio: mean %.0f%%  max %.0f%%"
          % (100 * statistics.mean(spam_ratios), 100 * max(spam_ratios)))
    if under100:
        print("under-100 boards (count, cells, country/stage):")
        for row in sorted(under100)[:25]:
            print("   ", row)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    default = os.path.join(here, "..", "..", "assets", "campaign", "bank.json")
    src = default
    dst = sys.argv[1] if len(sys.argv) > 1 else default
    relayout(src, dst)
