# 데이터 소스 · 파이프라인 지도

> **이 파일이 데이터 출처의 단일 정본이다.** 스크립트를 뒤지기 전에 여기부터 볼 것.
> 여기 값과 다른 옛 문서(예: `tools/atlas/README.md`의 "도시 68개")는 낡은 것이니 이 파일을 우선한다.
> 마지막 전수 검증: 2026-07-20.

---

## 1. 앱이 읽는 최종 데이터

### `assets/campaign/bank.json` — 퍼즐 뱅크 (앱이 직접 읽음)
- 구조: `{ "countries": [ 엔트리 ... ] }`
- **엔트리 216개** = 국가 단위. 필드: `rank, name(영문), ko, continent, area_km2, iso, stages[]`
- **스테이지 총 775개.** 스테이지 필드: `kind('city'|'country'), name, ko, rows, cols, grid, lines`
  - `grid` = 마스크. `'.'`/`'#'` 문자열 행 배열(연결된 영토 셀 = `#`).
  - `lines` = 화살표(퍼즐). 난이도는 `relayout_difficulty.py`가 이 부분만 다시 씀.
- **kind 분포: country 216 + city 559.**
- `continent`·`iso`는 `build_bank.py`가 주입(대륙은 campaign.json에서 조인, Seven-seas 흡수 규칙 적용).

---

## 2. 지오메트리 원본 (영토 모양)

### 국가 폴리곤 → **Natural Earth 50m**
- 파일: `ne_50m_admin_0_countries.geojson`
- ⚠️ **리포에 커밋 안 됨.** 스크립트 옆에 두고 씀. 다운로드:
  `https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson`
- 매칭 키: `ISO_A2` → `ISO_A2_EH` → 이름(`ADMIN`/`NAME`/`NAME_LONG`/`GEOUNIT`/`BRK_NAME`).
- 쓰는 곳: `tools/atlas/world_atlas.py`, `build_worldmap.py`, `prep_campaign_map.py`.

### 도시 폴리곤 → **OSM Nominatim 행정경계 (리포에 있음)**
- 파일: **`tools/atlas/cities_raw.json`** — **575개 도시, 전부 실제 Polygon/MultiPolygon.**
- 구조: `{ 영문도시명: { ko, geojson(Polygon|MultiPolygon), display } }`
- `fetch_cities.py`가 Nominatim에서 받아 캐시한 것. **도시 영토의 정본 소스는 이 파일이다.**
- ⚠️ admin1(주/도 경계)은 도시 소스가 **아니다** — 서울처럼 도시=광역단위인 경우만 우연히 맞음.

### admin1(주·도) → 필요 시 별도
- `ne_10m_admin_1_states_provinces.geojson`(비커밋). 도시가 아니라 광역행정구역이 필요할 때만.

---

## 3. 빌드 파이프라인 (원본 → bank.json)

```
[국가] ne_50m_*.geojson ─ world_atlas.py ──▶ atlas_countries.json (격자)
[도시] Nominatim ─ fetch_cities.py ─▶ cities_raw.json ─ raster_cities.py ─▶ atlas_cities.json (격자)
       (격자 = 폴리곤을 긴 변 N셀로 래스터화한 마스크. atlas_cities.json엔 폴리곤 없음, 격자만.)

export_boards.dart (기하) ─▶ all_boards.json ─ build_bank.py ─▶ bank.json
build_campaign.py ─▶ campaign.json (대륙·순서)
relayout_difficulty.py ─▶ bank.json의 화살표 레이아웃만 재작성 (격자·영토는 안 건드림)
```

- ⚠️ 개발환경에 dart/flutter 툴체인 없음 → 컴파일 검증은 FAD 빌드가 담당.

---

## 4. 클리어 화면 "실제 영토 이미지" 확보 현황 (2026-07-20 전수검증)

- **국가 216 → NE로 전부 커버.** 예외 3종만 개별 처리:
  - `Ashmore and Cartier Islands` — iso가 호주와 같은 `AU`(iso 우선 매칭 시 호주가 뜸 → 이름 매칭 우선 필요).
  - 국기 불가 3개(iso 빈값): `Siachen Glacier` · `Northern Cyprus` · `Somaliland` (영토는 이름으로 렌더 가능).
  - 자오선 언랩 필요 3국: 뉴질랜드 · 미국 · 러시아.
- **도시 559 → `cities_raw.json`에 전부 존재(매칭 실패 0).** 520개 정상, 39개는 경계가 작아 실루엣 스케일에서 각짐(폴리곤은 있음).

---

## 5. 국기

- 이모지는 단말/OS별 미표시 위험 → **번들 SVG(예: lipis/flag-icons)** 로 렌더하는 방향.
- iso 빈 3개 지역(위)은 국기 없음.
