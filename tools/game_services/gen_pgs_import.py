#!/usr/bin/env python3
"""Atlas Arrows — Play Games Services import-bundle generator.

Play Games Services has **no public API** to create achievements/leaderboards
(unlike Apple's App Store Connect). The only bulk path is the Play Console's
built-in importer, which takes a **ZIP** of headerless CSVs + 512x512 icon PNGs.
This script builds those ZIPs; you upload them once in the console:

  Play Console ▸ Play Games Services ▸ Setup and management ▸ Achievements
    ▸ "Import achievements" → upload AtlasArrowsAchievementsImport.zip
  (Leaderboards: see the note printed at the end.)

After importing, the console MINTS the ids (CgkI…). Copy them back into
`lib/services/game_services.dart` (_leaderboard* / _achievements android:).

Achievements match `game_services.dart` + docs/FIREBASE.md §4. English-only
(the console default locale carries the text; add translations later in-console
or by setting EMIT nothing here). Icons are TEMPORARY placeholders borrowed
from another project — swap `tools/game_services/icons/*.png` for real art and
re-run; the console re-reads icons on re-import.

No third-party deps. Run:
  python3 tools/game_services/gen_pgs_import.py
  python3 tools/game_services/gen_pgs_import.py --out DIR
"""
import argparse
import csv
import os
import zipfile

_HERE = os.path.dirname(os.path.abspath(__file__))
_ICONS = os.path.join(_HERE, "icons")
_OUT = os.path.join(_HERE, "out")

# ── Achievements ─────────────────────────────────────────────────────────────
# (key, Name, Description, points, icon). Points: multiple of 5 in [5,200],
# total <= 2000. Name/Description must contain NO commas (importer splits on ,).
# `key` is only for our own reference; the console assigns the real id.
ACHIEVEMENTS = [
    ("first_clear",   "First Clear",   "Clear your first stage.",                  5,  "ach_first_clear.png"),
    ("first_country", "First Country", "Complete your first country.",            10,  "ach_first_country.png"),
    ("stages_50",     "50 Stages",     "Clear 50 stages in total.",               15,  "ach_stages_50.png"),
    ("stages_250",    "250 Stages",    "Clear 250 stages in total.",              25,  "ach_stages_250.png"),
    ("flawless",      "Flawless",      "Clear a stage without losing a heart.",   15,  "ach_flawless.png"),
]

# ── Leaderboards ─────────────────────────────────────────────────────────────
# (key, Name, sort order, score format, icon). Both are plain integer counts,
# higher = better. Play Games leaderboard bulk-import is not always offered in
# the console UI, so these values double as the spec for manual creation.
LEADERBOARDS = [
    ("stages",    "Stages Cleared",      "LARGER_IS_BETTER", "NUMERIC", "lb_stages.png"),
    ("countries", "Countries Completed", "LARGER_IS_BETTER", "NUMERIC", "lb_countries.png"),
]


def _validate_achievements():
    total = 0
    names = set()
    for _key, name, desc, pts, icon in ACHIEVEMENTS:
        if "," in name or "," in desc:
            raise ValueError(f"comma not allowed: {name!r}/{desc!r}")
        if len(name) > 100 or len(desc) > 500:
            raise ValueError(f"name/desc too long: {name!r}")
        if pts % 5 or not (5 <= pts <= 200):
            raise ValueError(f"points {pts} must be a multiple of 5 in [5,200]")
        if name in names:
            raise ValueError(f"duplicate name: {name!r}")
        names.add(name)
        if not os.path.exists(os.path.join(_ICONS, icon)):
            raise FileNotFoundError(f"icon missing: {icon}")
        total += pts
    if total > 2000:
        raise ValueError(f"total points {total} exceeds 2000")
    return total


def _write_csv(path, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        csv.writer(f, lineterminator="\n").writerows(rows)


def _zip(zip_path, csvs, icons):
    os.makedirs(os.path.dirname(zip_path) or ".", exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for name in csvs:
            z.write(os.path.join(_OUT, name), arcname=name)
        for icon in icons:
            src = os.path.join(_ICONS, icon)
            if os.path.getsize(src) >= 1_000_000:
                raise ValueError(f"icon >=1MB (zip limit): {icon}")
            z.write(src, arcname=icon)  # flat, no directory component


def generate(out_dir):
    global _OUT
    _OUT = out_dir
    os.makedirs(_OUT, exist_ok=True)
    total = _validate_achievements()

    # ── Achievements ZIP ────────────────────────────────────────────────────
    # AchievementsMetadata.csv: Name,Description,Incremental,Steps,State,Points,ListOrder
    meta = [
        [name, desc, "False", "", "Revealed", pts, i + 1]
        for i, (_k, name, desc, pts, _icon) in enumerate(ACHIEVEMENTS)
    ]
    _write_csv(os.path.join(_OUT, "AchievementsMetadata.csv"), meta)
    # AchievementsIconsMappings.csv: Name,iconFilename
    _write_csv(os.path.join(_OUT, "AchievementsIconsMappings.csv"),
               [[name, icon] for _k, name, _d, _p, icon in ACHIEVEMENTS])
    ach_zip = os.path.join(_OUT, "AtlasArrowsAchievementsImport.zip")
    _zip(ach_zip,
         ["AchievementsMetadata.csv", "AchievementsIconsMappings.csv"],
         [a[4] for a in ACHIEVEMENTS])

    # ── Leaderboards ZIP (attempt) ──────────────────────────────────────────
    # LeaderboardsMetadata.csv: Name,ScoreOrder,ScoreFormat,ListOrder
    lb_meta = [
        [name, order, fmt, i + 1]
        for i, (_k, name, order, fmt, _icon) in enumerate(LEADERBOARDS)
    ]
    _write_csv(os.path.join(_OUT, "LeaderboardsMetadata.csv"), lb_meta)
    _write_csv(os.path.join(_OUT, "LeaderboardsIconsMappings.csv"),
               [[name, icon] for _k, name, _o, _f, icon in LEADERBOARDS])
    lb_zip = os.path.join(_OUT, "AtlasArrowsLeaderboardsImport.zip")
    _zip(lb_zip,
         ["LeaderboardsMetadata.csv", "LeaderboardsIconsMappings.csv"],
         [b[4] for b in LEADERBOARDS])

    print(f"achievements: {len(ACHIEVEMENTS)}  ·  points {total}/2000")
    print(f"  ZIP → {ach_zip}")
    print(f"leaderboards: {len(LEADERBOARDS)}")
    print(f"  ZIP → {lb_zip}")
    print()
    print("Upload in Play Console ▸ Play Games Services:")
    print("  • Achievements ▸ Import achievements → AtlasArrowsAchievementsImport.zip")
    print("  • Leaderboards: if the console offers 'Import leaderboards', use")
    print("    AtlasArrowsLeaderboardsImport.zip; otherwise create the 2 boards")
    print("    manually from LeaderboardsMetadata.csv (only two).")
    print("Then paste the console-issued CgkI… ids into game_services.dart.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=_OUT, help="output directory")
    generate(ap.parse_args().out)


if __name__ == "__main__":
    main()
