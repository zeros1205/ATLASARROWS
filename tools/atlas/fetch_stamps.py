"""Generates one visa-stamp image per campaign country via fal.ai.

Reads stamp_plan.json (from build_stamp_plan.py), submits each prompt to the
image model, and writes the PNG into assets/images/stamps/.

Resumable: a country whose file already exists is skipped, so an interrupted
run only generates what is missing, and re-running after deleting a few bad
stamps regenerates exactly those.

Usage:
  export FAL_KEY=...                 # or set it in the environment
  python tools/atlas/fetch_stamps.py            # everything still missing
  python tools/atlas/fetch_stamps.py 109 154    # only these ranks (redo)
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
PLAN = os.path.join(HERE, "stamp_plan.json")
OUT_DIR = os.path.join(REPO, "assets", "images", "stamps")

ENDPOINT = "openai/gpt-image-2"
QUEUE = f"https://queue.fal.run/{ENDPOINT}"
WORKERS = 6          # parallel in-flight requests
POLL_EVERY = 6       # seconds between status checks
GIVE_UP_AFTER = 600  # seconds per image
MAX_ATTEMPTS = 3     # submissions before giving up on a country


def key():
    k = os.environ.get("FAL_KEY") or os.environ.get("FAL_API_KEY")
    if not k:
        sys.exit("FAL_KEY 환경변수가 없습니다.")
    return k


def call(url, payload=None, method="GET"):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Key {key()}",
        "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req, timeout=90) as r:
        return json.load(r)


def generate(row, attempt=1):
    """Submit one prompt, poll until done, save the PNG. Returns (rank, note).

    The queue returns the odd 500 under load, so submission retries with a
    backoff rather than dropping the country — a missed one would otherwise
    have to be hunted down and re-run by rank later.
    """
    dest = os.path.join(OUT_DIR, row["file"])
    try:
        sub = call(QUEUE, {
            "prompt": row["prompt"],
            "image_size": "square_hd",
            "num_images": 1,
            "quality": "high",
            "output_format": "png",
        }, "POST")
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
        if attempt < MAX_ATTEMPTS:
            time.sleep(5 * attempt)
            return generate(row, attempt + 1)
        return row["rank"], f"제출 실패 {e}"

    rid = sub["request_id"]
    status_url = sub.get("status_url", f"{QUEUE}/requests/{rid}/status")
    response_url = sub.get("response_url", f"{QUEUE}/requests/{rid}")

    waited = 0
    while waited < GIVE_UP_AFTER:
        time.sleep(POLL_EVERY)
        waited += POLL_EVERY
        try:
            st = call(status_url)
        except urllib.error.HTTPError:
            continue
        if st.get("status") == "COMPLETED":
            break
        if st.get("status") in ("FAILED", "CANCELLED"):
            if attempt < MAX_ATTEMPTS:
                time.sleep(5 * attempt)
                return generate(row, attempt + 1)
            return row["rank"], f"생성 실패 {st.get('status')}"
    else:
        if attempt < MAX_ATTEMPTS:
            return generate(row, attempt + 1)
        return row["rank"], "시간 초과"

    res = call(response_url)
    images = res.get("images") or []
    if not images:
        if attempt < MAX_ATTEMPTS:
            return generate(row, attempt + 1)
        return row["rank"], "이미지 없음"

    with urllib.request.urlopen(images[0]["url"], timeout=180) as r:
        blob = r.read()
    tmp = dest + ".part"
    with open(tmp, "wb") as f:
        f.write(blob)
    os.replace(tmp, dest)
    return row["rank"], f"OK {len(blob) // 1024}KB"


def main():
    with open(PLAN, encoding="utf-8") as f:
        rows = json.load(f)["stamps"]
    os.makedirs(OUT_DIR, exist_ok=True)

    only = {int(a) for a in sys.argv[1:] if a.isdigit()}
    if only:
        rows = [r for r in rows if r["rank"] in only]
    else:
        rows = [r for r in rows
                if not os.path.exists(os.path.join(OUT_DIR, r["file"]))]

    if not rows:
        print("생성할 것이 없습니다 — 전부 존재함.")
        return

    print(f"생성 대상 {len(rows)}개 · 동시 {WORKERS}개", flush=True)
    done = fail = 0
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = {pool.submit(generate, r): r for r in rows}
        for fut in as_completed(futures):
            r = futures[fut]
            try:
                rank, note = fut.result()
            except Exception as e:                      # noqa: BLE001
                rank, note = r["rank"], f"예외 {e}"
            ok = note.startswith("OK")
            done += ok
            fail += not ok
            print(f"[{done + fail}/{len(rows)}] {rank:>3} {r['ko']:<16}"
                  f"{r['shape']:<9}{r['ink']:<7}{note}", flush=True)

    print(f"\n완료 {done} · 실패 {fail}", flush=True)


if __name__ == "__main__":
    main()
