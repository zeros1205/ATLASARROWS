# 실루엣 아틀라스 파이프라인 (2026-07-18)

퍼즐 보드 마스크 후보를 실데이터에서 고해상도 격자(긴 변 14~44셀)로 뽑는 도구들.
게임 마스크 규격(연결성 등) 적용 **전** 원본이다. 큰 보드는 인게임 줌/팬 전제.

| 스크립트 | 입력 | 출력 |
|---|---|---|
| `world_atlas.py` | `ne_50m_countries.geojson` (스크립트 옆에 필요, [다운로드](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson)) | `atlas_countries.json` — 233개국 |
| `fetch_cities.py` | OSM Nominatim (1.1s/req, 캐시 `cities_raw.json`) | 도시 경계 GeoJSON 캐시 |
| `raster_cities.py` | `cities_raw.json` | `atlas_cities.json` — 68개 도시 |
| `extract_animals.py` | `P5_ATLASARROWS/shapes/` 실루엣 일러스트 | `atlas_animals.json` — 230마리 |
| `build_atlas_page.py` | atlas_*.json + `atlas_template.html` | `world-atlas.html` 뷰어 |

핵심 파라미터: 커버리지 임계값(0.32~0.35), 서브샘플 4×4, 국가별 클립박스
오버라이드(미국 본토만, 도쿄 본토만 등), 해외영토 자동 제외(주 폴리곤 중심 25° 이내만).
동물 추출은 어두운픽셀 임계 → 3px 팽창(조각 병합) → 연결성분 → 격자화 + 쓰레기 필터.

미해결: 마스크 규격 다운샘플/게임 보드 최대 크기 결정, 태평양 섬나라 9개 스킵,
도시 4개(뭄바이·요하네스버그·케이프타운·아테네) Nominatim 폴리곤 미검색, 동물 이름 미부여.
