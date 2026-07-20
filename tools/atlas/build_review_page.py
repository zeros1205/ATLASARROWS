#!/usr/bin/env python3
"""Builds a single-file review page: every stage's real territory next to its puzzle.

For each of the 775 stages it pairs the true boundary (OSM for cities via
cities_raw.json, Natural Earth for countries) with the arrow puzzle actually
shipped in bank.json, so shape problems and board problems are visible together.

    python tools/atlas/build_review_page.py [-o tools/atlas/atlas_review.html]

Needs ne_50m_countries.geojson beside this script (see docs/DATA_SOURCES.md).
Outlines are simplified only for display — the source data is untouched.
"""
import argparse
import json
import math
import os
import re
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "cities_raw.json")
CRAW = os.path.join(HERE, "countries_raw.json")
NE = os.path.join(HERE, "ne_10m_countries.geojson")
NE_FALLBACK = os.path.join(HERE, "ne_50m_countries.geojson")
BANK = os.path.join(HERE, "..", "..", "assets", "campaign", "bank.json")

VIEW = 1000.0        # territory viewBox long side
HI_PTS = 900         # "photo-real" outline — full coast, every island
LO_PTS = 110         # the simplified silhouette the game reads as a shape
# Offshore islands are most of what makes a coastline read as real (Korea has
# 53 parts, and dropping them leaves a featureless blob), and they cost very
# few points, so keep every part with any area at all in the detailed pass.
MIN_PART = 0.0
# The silhouette drops specks so it stays legible at thumbnail size.
LO_MIN_PART = 0.004

# Municipalities administering far-flung islands/sea: clip to the built-up area
# so the silhouette is the city, not a mostly-empty ocean box.
CLIPS = {
    "Tokyo": (138.94, 35.49, 139.95, 35.92),
    "Kaohsiung": (120.15, 22.40, 120.95, 23.55),
    "Jakarta": (106.65, -6.40, 107.00, -6.08),
    "Ho Chi Minh City": (106.35, 10.35, 107.05, 11.20),
}


def norm(s):
    if not s:
        return ""
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]", "", s)


def polygons(geom):
    return [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]


def ring_area(r):
    s = 0.0
    for i in range(len(r) - 1):
        x1, y1 = r[i]
        x2, y2 = r[i + 1]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2


def rdp(points, eps):
    """Douglas-Peucker, iterative — rings here reach 47k points, so recursing
    would blow the stack. Display-only simplification."""
    n = len(points)
    if n < 3:
        return points
    keep = [False] * n
    keep[0] = keep[n - 1] = True
    stack = [(0, n - 1)]
    while stack:
        lo, hi = stack.pop()
        if hi <= lo + 1:
            continue
        ax, ay = points[lo]
        bx, by = points[hi]
        dx, dy = bx - ax, by - ay
        L = math.hypot(dx, dy)
        idx, far = lo, -1.0
        for i in range(lo + 1, hi):
            px, py = points[i]
            d = (abs(dx * (ay - py) - (ax - px) * dy) / L) if L else math.hypot(px - ax, py - ay)
            if d > far:
                idx, far = i, d
        if far > eps:
            keep[idx] = True
            stack.append((lo, idx))
            stack.append((idx, hi))
    return [p for p, k in zip(points, keep) if k]


def shape_path(rings, unwrap=False, clip=None):
    """Project rings to a 0..VIEW box (latitude-corrected) and emit an SVG path."""
    if unwrap:
        rings = [[[x - 360 if x > 0 else x, y] for x, y in r] for r in rings]
    if clip:
        kept = []
        for r in rings:
            cx = sum(p[0] for p in r) / len(r)
            cy = sum(p[1] for p in r) / len(r)
            if clip[0] <= cx <= clip[2] and clip[1] <= cy <= clip[3]:
                kept.append(r)
        rings = kept or rings
    areas = [ring_area(r) for r in rings]
    big = max(areas)
    detailed = [r for r, a in zip(rings, areas) if a >= big * MIN_PART]

    pts = [p for r in detailed for p in r]
    lat = sum(p[1] for p in pts) / len(pts)
    k = math.cos(math.radians(lat))
    xs = [p[0] * k for p in pts]
    ys = [-p[1] for p in pts]
    minx, miny = min(xs), min(ys)
    w, h = max(xs) - minx, max(ys) - miny
    if w <= 0 and h <= 0:
        return None
    s = VIEW / max(w, h)

    def project(rs):
        return [[((p[0] * k - minx) * s, (-p[1] - miny) * s) for p in r] for r in rs]

    def to_path(proj, budget):
        eps = 0.0
        total = sum(len(r) for r in proj)
        while total > budget and eps < 60:
            eps = eps * 1.7 if eps else 0.4
            proj = [rdp(r, eps) for r in proj]
            total = sum(len(r) for r in proj)
        return "".join("M" + " ".join(f"{x:.1f},{y:.1f}" for x, y in r) + "Z"
                       for r in proj if len(r) >= 3)

    # Both passes share one projection, so the two images register exactly.
    hi = to_path(project(detailed), HI_PTS)
    coarse = [r for r, a in zip(rings, areas) if a >= big * LO_MIN_PART]
    lo = to_path(project(coarse or detailed), LO_PTS)
    if not hi:
        return None
    return {"hi": hi, "lo": lo or hi,
            "w": round(w * s, 1), "h": round(h * s, 1),
            "parts": len(detailed)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--out", default=os.path.join(HERE, "atlas_review.html"))
    args = ap.parse_args()

    raw = json.load(open(RAW, encoding="utf-8"))
    craw = json.load(open(CRAW, encoding="utf-8")) if os.path.exists(CRAW) else {}
    bank = json.load(open(BANK, encoding="utf-8"))["countries"]
    ne_path = NE if os.path.exists(NE) else NE_FALLBACK
    ne = json.load(open(ne_path, encoding="utf-8"))["features"]

    by_iso, by_name = {}, {}
    for f in ne:
        p = f["properties"]
        for key in ("ISO_A2", "ISO_A2_EH"):
            v = p.get(key)
            if v and v != "-99":
                by_iso.setdefault(v, f)
        for key in ("ADMIN", "NAME", "NAME_LONG", "GEOUNIT", "BRK_NAME"):
            if p.get(key):
                by_name.setdefault(norm(p[key]), f)

    stages, missing = [], []
    for entry in bank:
        for st in entry["stages"]:
            shape = None
            if st["kind"] == "city":
                city = raw.get(st["name"])
                if city:
                    rings = [p[0] for p in polygons(city["geojson"])]
                    shape = shape_path(rings, clip=CLIPS.get(st["name"]))
            elif entry["name"] in craw:
                # OSM beats Natural Earth for micro-states NE draws as blobs
                rings = [p[0] for p in polygons(craw[entry["name"]]["geojson"])]
                shape = shape_path(rings)
            else:
                # name first: dependencies share their parent's ISO (Ashmore -> AU)
                feat = by_name.get(norm(entry["name"])) or by_iso.get(entry["iso"])
                if feat:
                    rings = [p[0] for p in polygons(feat["geometry"])]
                    xs = [x for r in rings for x, _ in r]
                    shape = shape_path(rings, unwrap=max(xs) - min(xs) > 180)
            if not shape:
                missing.append(f'{st["name"]} ({st["kind"]})')
            stages.append({
                "n": st["name"], "k": st.get("ko", ""), "kind": st["kind"],
                "c": entry["name"], "ck": entry["ko"], "iso": entry["iso"],
                "cont": entry.get("continent", ""),
                "r": st["rows"], "co": st["cols"],
                "g": st["grid"], "l": st["lines"],
                "t": shape,
            })

    data = json.dumps(stages, ensure_ascii=False, separators=(",", ":"))
    html = PAGE.replace("/*DATA*/", data)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(html)
    size = os.path.getsize(args.out) / 1e6
    print(f"{len(stages)} stages -> {args.out} ({size:.1f} MB)")
    print(f"  cities {sum(1 for s in stages if s['kind']=='city')}, "
          f"countries {sum(1 for s in stages if s['kind']=='country')}")
    if missing:
        print(f"  no territory shape for {len(missing)}: {missing}")


PAGE = r"""<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Atlas Arrows — 영토 · 퍼즐 검수</title>
<style>
:root{--bg:#eceae4;--card:#fff;--ink:#23252e;--soft:#6e6f78;--faint:#9a9dab;
 --line:#e3e0d8;--terr:#b9bec8;--edge:#8b9099;--cell:#e6e4dd;--arrow:#2f3440;--accent:#2f6bff}
@media(prefers-color-scheme:dark){:root{--bg:#101116;--card:#191a20;--ink:#eceae4;--soft:#a6a8b0;
 --faint:#787b86;--line:#282a32;--terr:#3d424c;--edge:#5d626d;--cell:#23252c;--arrow:#c9ced9;--accent:#4c82ff}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
 font:14px/1.5 -apple-system,"Segoe UI",Pretendard,system-ui,sans-serif}
header{position:sticky;top:0;z-index:5;background:var(--bg);border-bottom:1px solid var(--line);
 padding:14px 20px;display:flex;gap:12px;align-items:center;flex-wrap:wrap}
h1{font-size:16px;margin:0;font-weight:700;letter-spacing:-.01em}
.count{color:var(--soft);font-size:13px}
input,select{font:inherit;padding:7px 11px;border:1px solid var(--line);border-radius:9px;
 background:var(--card);color:var(--ink);min-width:150px}
input:focus,select:focus{outline:2px solid var(--accent);outline-offset:1px}
#grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(430px,1fr));gap:14px;padding:18px 20px 60px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:12px;
 min-height:200px;content-visibility:auto;contain-intrinsic-size:200px}
.hd{display:flex;justify-content:space-between;align-items:baseline;gap:8px;margin-bottom:8px}
.nm{font-weight:700;font-size:15px}
.sub{color:var(--soft);font-size:12px}
.tag{font-size:10px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;
 padding:2px 7px;border-radius:99px;background:var(--cell);color:var(--soft)}
.tag.city{color:var(--accent)}
.panes{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px}
.pane{background:var(--bg);border-radius:10px;padding:6px;aspect-ratio:1;
 display:flex;align-items:center;justify-content:center}
.pane svg{max-width:100%;max-height:100%;display:block}
.cap{text-align:center;font-size:10px;color:var(--faint);margin-top:3px;letter-spacing:.04em}
.none{color:var(--faint);font-size:11px}
</style></head><body>
<header>
  <h1>영토 · 퍼즐 검수</h1>
  <span class="count" id="count"></span>
  <input id="q" placeholder="도시/국가 이름 검색">
  <select id="kind"><option value="">전체</option><option value="city">도시</option><option value="country">국가</option></select>
  <select id="cont"><option value="">모든 대륙</option></select>
  <select id="sort"><option value="seq">캠페인 순서</option><option value="name">이름순</option></select>
</header>
<div id="grid"></div>
<script>
const D=/*DATA*/;
const grid=document.getElementById('grid'),q=document.getElementById('q'),
      kindSel=document.getElementById('kind'),contSel=document.getElementById('cont'),
      sortSel=document.getElementById('sort'),countEl=document.getElementById('count');
D.forEach((s,i)=>s._i=i);
[...new Set(D.map(s=>s.cont).filter(Boolean))].sort().forEach(c=>{
  const o=document.createElement('option');o.value=o.textContent=c;contSel.appendChild(o);});

function terrSVG(t,key,stroke){
  if(!t) return '<span class="none">형상 없음</span>';
  return `<svg viewBox="0 0 ${t.w} ${t.h}" preserveAspectRatio="xMidYMid meet">
    <path d="${t[key]}" fill="var(--terr)" stroke="var(--edge)" stroke-width="${stroke}"
      stroke-linejoin="round" fill-rule="evenodd"/></svg>`;
}
const DIR={U:[-1,0],D:[1,0],L:[0,-1],R:[0,1]};
function puzzleSVG(s){
  const C=10,W=s.co*C,H=s.r*C,p=[];
  for(let r=0;r<s.g.length;r++){const row=s.g[r];
    for(let c=0;c<row.length;c++) if(row[c]==='#')
      p.push(`<rect x="${c*C}" y="${r*C}" width="${C}" height="${C}" fill="var(--cell)"/>`);}
  for(const spec of s.l){
    const [pos,mv]=spec.split(':'),[r0,c0]=pos.split(',').map(Number);
    let r=r0,c=c0;const cells=[[r,c]];
    for(const ch of mv||''){const d=DIR[ch];if(!d)continue;r+=d[0];c+=d[1];cells.push([r,c]);}
    if(cells.length<2)continue;
    const pts=cells.map(([r,c])=>`${c*C+C/2},${r*C+C/2}`).join(' ');
    p.push(`<polyline points="${pts}" fill="none" stroke="var(--arrow)"
      stroke-width="${C*0.3}" stroke-linecap="round" stroke-linejoin="round"/>`);
    const [hr,hc]=cells[cells.length-1],[pr,pc]=cells[cells.length-2];
    const dy=hr-pr,dx=hc-pc,a=Math.atan2(dy,dx)*180/Math.PI;
    const x=hc*C+C/2,y=hr*C+C/2;
    p.push(`<polygon points="${C*0.42},0 ${-C*0.12},${-C*0.4} ${-C*0.12},${C*0.4}"
      fill="var(--arrow)" transform="translate(${x},${y}) rotate(${a})"/>`);
  }
  return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid meet">${p.join('')}</svg>`;
}
function card(s){
  const el=document.createElement('div');el.className='card';
  const place=s.kind==='city'?`${s.k||s.n}<span class="sub"> · ${s.ck}</span>`:(s.k||s.n);
  el.innerHTML=`<div class="hd"><div><div class="nm">${place}</div>
      <div class="sub">${s.n} · ${s.r}×${s.co} · 화살표 ${s.l.length}</div></div>
      <span class="tag ${s.kind}">${s.kind==='city'?'도시':'국가'}</span></div>
    <div class="panes">
      <div><div class="pane">${terrSVG(s.t,'hi',1.2)}</div><div class="cap">① 실사 영토${s.t?` · ${s.t.parts}조각`:''}</div></div>
      <div><div class="pane">${terrSVG(s.t,'lo',2.5)}</div><div class="cap">② 단순화 실루엣</div></div>
      <div><div class="pane">${puzzleSVG(s)}</div><div class="cap">③ 화살표 퍼즐</div></div>
    </div>`;
  return el;
}
function render(){
  const term=q.value.trim().toLowerCase(),k=kindSel.value,ct=contSel.value;
  let list=D.filter(s=>(!k||s.kind===k)&&(!ct||s.cont===ct)&&(!term||
      s.n.toLowerCase().includes(term)||(s.k||'').includes(term)||
      s.c.toLowerCase().includes(term)||(s.ck||'').includes(term)));
  if(sortSel.value==='name') list=[...list].sort((a,b)=>(a.k||a.n).localeCompare(b.k||b.n,'ko'));
  countEl.textContent=`${list.length} / ${D.length} 스테이지`;
  grid.textContent='';
  const f=document.createDocumentFragment();
  list.forEach(s=>f.appendChild(card(s)));
  grid.appendChild(f);
}
[q,kindSel,contSel,sortSel].forEach(e=>e.addEventListener('input',render));
render();
</script></body></html>
"""


if __name__ == "__main__":
    main()
