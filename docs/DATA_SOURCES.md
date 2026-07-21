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

---

## 6. 다음 작업 — 클리어 화면용 "실측 영토 이미지" (2026-07-21 인계)

사용자가 원하는 것은 **세 가지**다. ②③은 손대지 말고 **①만** 하면 된다.

| | 산출물 | 용도 | 상태 |
|---|---|---|---|
| ① | **실측 영토 이미지** | 스테이지 클리어 화면 | **미완 — 이번 작업 대상** |
| ② | 단순화 실루엣 | ③ 퍼즐 격자의 토대 | 완료(벡터가 맞는 용도) |
| ③ | 화살표 퍼즐 | 게임플레이 화면 | 건드리지 말 것(화살표 개수·난이도는 별도 세션) |

### ①에서 내가 틀렸던 점 (같은 실수 반복 금지)

- **벡터 폴리곤을 단색으로 칠한 도형은 "실사"가 아니다.** 점 개수를 늘려도 실사가 되지 않는다.
  사용자 표현: *"실측 이미지를 찾아오라니까 섬나라 땅 그림그리기나 하고 있냐"*.
- **점 개수를 실사 여부의 근거로 대지 말 것.** 반드시 **렌더해서 눈으로 확인**하고 보고할 것.
- Natural Earth는 소도서의 실제 해안선을 **어떤 레이어에도 갖고 있지 않다**(나우루 = 국가레이어 9점,
  `ne_10m_land` 9점, `ne_10m_minor_islands` 0점). NE로 더 파봐야 소용없다.
- **소도서 국가는 ① 대상에서 제외**한다(사용자 지시).

### 해야 할 것

**실제 위성·지형 래스터를 받아 영토 폴리곤으로 크롭·마스킹**해서, 지형이 보이는 영토 이미지를 만든다.

- **NASA Blue Marble** — 실제 위성 이미지, 퍼블릭 도메인
- **Natural Earth 래스터** — `NE2_HR_LC_SR_W`(자연색+음영기복) / `HYP_HR_SR_OB_DR`(고도채색),
  21600×10800, **퍼블릭 도메인** → 상용 배포 안전
- ⚠️ 라이선스: GADM은 **상용 불가**라 배제. OSM 벡터를 쓸 경우 ODbL이라
  "© OpenStreetMap contributors" 표기 필요.

마스킹용 폴리곤은 이미 있다 — 도시 `cities_raw.json`, 국가 NE 10m(+ `countries_raw.json`).

### 확인 도구

`python tools/atlas/build_review_page.py` → `tools/atlas/atlas_review.html`
(①실사 / ②실루엣 / ③퍼즐 3단, 775 스테이지, 검색·대륙 필터). **결과는 브라우저로 직접 볼 것.**

### 보류(WIP)

`fetch_microstate_shapes.py`에 `place=island` 조회를 반쯤 넣어둔 상태다. 소도서는 ① 대상에서
빠졌으므로 **되살릴 필요 없다.** Aruba·Barbados·Niue·Montserrat은 `countries_raw.json`에서
빠져 NE로 폴백 중.

---

## 7. PATH 스테이지 — 의도·히스토리 (사용자 확정, 2026-07-21)

**목적:** 도시/국가 스테이지만으로는 **목표 2,000 스테이지**를 못 채운다. 그래서 스테이지
**전환 사이에 PATH 스테이지를 끼워 넣어** 수를 채운다. 삽입 지점:
- 도시 → 도시
- 도시 → 국가
- 국가 → (다른 국가의) 도시

**컨셉:** 한 장소에서 다음 장소로 **이동/여행**하는 것 — 차·버스·택시·기차·비행기·헬리콥터
등을 타고 가는 느낌의 스테이지.

**폐기·보류된 시도 (같은 길로 다시 가지 말 것):**
- **교통수단 실루엣 마스크로 퍼즐** — 교통수단 실루엣 마스크 만들기가 너무 어려워 **보류**.
- **산/바다/평지 컨셉 + 화살표 컬러링** — 원하는 퀄리티가 안 나와 **폐기**.

**현재 상태:** 앱 `StageKind` enum은 city/country만 있음(path 미정의). `bank.json`에 path 없음.
`tools/atlas/path_boards.json`은 도시 없는 국가용 준비 자료(WIP)일 뿐 연결 안 됨.
→ **PATH 스테이지의 보드 표현 방식이 아직 미확정**이라 생성 보류 상태.

**교통수단 실루엣 마스크 (확정 진행 중):** Material Icons(Apache-2.0) 글리프에서
디테일 유지(창문·바퀴 = 흰 공란, 검정 몸통만 화살로 채움) 파이프라인으로 추출. 큐레이션 후
16종: directions_boat, directions_bus, directions_car, flight, local_airport,
local_shipping, local_taxi, moped, pedal_bike, sailing, snowmobile, subway,
train, tram, two_wheeler, airport_shuttle.

**차량 선택(vehicle picker) 규칙 — snowmobile 강제:**
한대 국가 = **국가 중심 위도 |위도| ≥ 55°**(NE 50m 폴리곤 중심). 한대 국가 라운드에서
스노모빌 PATH는 **정확히 2개**만 강제 등장한다:
1. **진입** — 직전 국가 스테이지 → 한대 국가의 **첫 스테이지(첫 도시)** 로 넘어가는 PATH.
2. **완주** — 한대 국가의 **마지막 도시 → 그 국가 스테이지**로 넘어가는 PATH.

그 외(한대 국가 내부 도시↔도시 이동 PATH 포함)는 **일반 랜덤 교통수단**.
- 도착지가 "한대 국가의 첫 도시"면 도시 도착이라도 스노모빌(진입).
- 출발지 위도는 보지 않는다. 도시가 없는 한대 국가는 진입=완주가 겹쳐 스노모빌 1개.
- 예: 벨기에 완주 → (스노모빌) → 핀란드 도시1 → (랜덤) → 도시2 → (랜덤) → 도시3 →
  (스노모빌) → 핀란드 국가 스테이지.
