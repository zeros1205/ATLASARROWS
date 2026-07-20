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
import os
import random
import sys
import time
from collections import deque

DIRS = [(-1, 0), (1, 0), (0, -1), (0, 1)]  # U D L R

# Relative weights for the short (2-3 cells) / mid (4-6) / long (7-maxLen)
# bands an arrow's length is drawn from. Mirrors lib/models/level_generator
# LenMixes so a future Dart-side port lands the same distribution.
BALANCED = dict(short=0.38, mid=0.42, long=0.20)
LONGER = dict(short=0.22, mid=0.40, long=0.38)


def tier(rank, total):
    """Difficulty knobs for a country's rank. Area-ascending campaign, so a
    higher rank is later in the game. Returns (fill, lenmix, reorient_frac)."""
    t = (rank - 1) / (total - 1) if total > 1 else 1.0
    if t < 0.10:
        return dict(fill=0.90, lenmix=BALANCED, frac=0.0)   # 온보딩/초반: 실수 ~0
    if t < 0.45:
        return dict(fill=0.85, lenmix=BALANCED, frac=0.5)   # 하트의 존재를 알림
    if t < 0.75:
        return dict(fill=0.80, lenmix=LONGER, frac=0.8)     # 함정 본격
    return dict(fill=0.78, lenmix=LONGER, frac=1.0)         # 후반/보스


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
        if x < ws:
            return 2 + rng.randint(0, 1)
        if x < wm:
            return 4 + rng.randint(0, 2)
        return 7 + rng.randint(0, max(0, max_len - 7))

    failures = 0
    while len(occupied) < target and failures < 800:
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
        tlen = sample_len()
        while len(path) < tlen:
            options = []
            for dr, dc in DIRS:
                n = (cur[0] + dr, cur[1] + dc)
                if n in mask and n not in occupied and n not in used:
                    options.append(((dr, dc), n))
            if not options:
                break
            rng.shuffle(options)
            pick = None
            if last_dir is not None and rng.random() < 0.6:
                for o in options:
                    if o[0] == last_dir:
                        pick = o
            if pick is None and rng.random() < 0.7:
                pick = max(options, key=lambda o: depth[o[1]])
            if pick is None:
                pick = options[0]
            path.append(pick[1])
            used.add(pick[1])
            cur = pick[1]
            last_dir = pick[0]
        if len(path) < 2:
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
    progressed = True
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
            for dr, dc in DIRS:
                n = (r + dr, c + dc)
                if n not in mask or n in occupied:
                    continue
                done = splice([cell, n]) or splice([n, cell])
                if done:
                    break
            if not done:
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

    def segname(rank):
        t = (rank - 1) / (total - 1) if total > 1 else 1.0
        return 'A' if t < 0.10 else 'B' if t < 0.45 else 'C' if t < 0.75 else 'D'

    for c in countries:
        rank = c["rank"]
        cfg = tier(rank, total)
        for si, s in enumerate(c["stages"]):
            nstage += 1
            grid = s["grid"]
            rows, cols = s["rows"], s["cols"]
            mask = {(r, cc) for r, row in enumerate(grid)
                    for cc, ch in enumerate(row) if ch == '#'}
            seed = rank * 100000 + si * 997 + len(grid)
            rng = random.Random(seed)
            ori = gen_level(rows, cols, mask, seed, cfg['fill'], 20, cfg['lenmix'])
            ori = chain_reorient(rows, cols, ori, cfg['frac'], rng)
            if not ori or not solvable(rows, cols, ori):
                nfail += 1  # leave the original layout in place
                continue
            s["lines"] = [encode(l) for l in ori]
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


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    default = os.path.join(here, "..", "..", "assets", "campaign", "bank.json")
    src = default
    dst = sys.argv[1] if len(sys.argv) > 1 else default
    relayout(src, dst)
