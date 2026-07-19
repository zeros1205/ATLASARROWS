# Atlas Arrows — 개발 핸드오프 (2026-07-19 기준)

> 이 문서 하나로 다음 세션(사람이든 AI든)이 바로 이어받는다.
> **최신 상태만** 담는다. 옛 Z-Arrows M1~M4 이력은 git 로그와 `DEV_PLAN.md` 참고
> (그 아키텍처 `lib/screens/*`는 새 앱으로 폐기됨).

## 0. 한 줄 요약

**Atlas Arrows** = 스네이크 화살표 퍼즐 + **세계지도 캠페인**. 국가=라운드(면적 오름차순),
라운드는 사각형 path 퍼즐 + 도시/국가 실루엣 랜드마크로 구성. 점묘(dot-matrix) 월드맵에서
국가를 골라 플레이한다.

## 1. 지금 상태 (커밋 기준)

- 저장소: https://github.com/zeros1205/z-arrows.git (레포명은 z-arrows 유지, **앱 이름은 Atlas Arrows**)
- 브랜치 `main`. 최신 커밋:
  - `9f0da2f` 점묘 월드맵(줌인/영토색/탭→라운드인트로)
  - `f2de32b` Atlas Arrows 리네임 + 라운드 캠페인 + 라운드 인트로 + 10로케일 + 부트 정리
- **품질 게이트: `dart analyze` 클린 · `flutter test` 10/10 · `flutter build web` 성공.**
- 브라우저 실행 검증: 홈 · 월드맵 · 라운드 인트로 렌더 확인.

## 2. 이번 세션에 바뀐 것 (2026-07-19)

- **이름/패키지**: Z-Arrows → **Atlas Arrows**. applicationId/bundle = `com.loganland.atlasarrows`,
  Dart 패키지 `atlas_arrows`. 내부 클래스 `ZArrowsGame`·IAP SKU `zarrows_hints_10/50`는 유지.
- **부트**: 네이티브 스플래시 = 오프블랙 **빈 화면**(마크 없음). 개발사 페이지 = 로고+`LOGAN LAND`
  (**PRESENTS 부제 없음**). 로딩 = 마크+진행바.
- **홈**: 중앙 로고(현재 `ATLAS·ARROWS` 워드마크가 임시, **실제 로고 제작 예정**). 신규 플레이어
  =‘시작하기’ 하나 / 기존=‘이어서 플레이’+‘맵에서 플레이’.
- **플레이 방식**: 라운드=국가, 스테이지수 = `max(10, 도시×2+1)`(상한 없음). **Path 스테이지=일반
  사각형**, 각 국가의 도시/피날레=**실루엣 보드**. path 도형은 rect로 통일.
- **라운드 인트로**: ROUND / 국가 / 소개(언어별) / N Stages·Cities·Paths. 게임 내 국가 전환 시
  오버레이, 맵에서 진입 시 `RoundIntroScreen`(플레이/잠김 버튼).
- **맵 = 점묘 월드맵**: `assets/campaign/worldmap.json`(등거리 168×65 점격자, 육지=국가/바다=-1).
  진행중 국가=파랑 accent, 클리어=진회색, 잠금=회색, 바다=옅음. 진입 시 현재 국가로 줌인,
  국가 탭→라운드 인트로. **월드맵 자체엔 잠금 아이콘 없음**(잠금은 라운드 인트로 버튼으로).
- **다국어 10개 골격**: en·de·fr·it·ja·ko·pt·ru·es·zh-Hans(간체). 설정 언어선택기=자국어명.
  국가 소개는 언어별 맵(`intro`). ⚠️**UI 문자열은 아직 한국어 하드코딩**(실제 번역은 맨 마지막).

## 3. 핵심 파일

```
lib/
  app/{app,shell,app_settings}.dart, app/tokens/*   토큰·테마·로케일(10개)
  features/
    boot/boot_screen.dart        빈 스플래시→개발사→로딩(서비스 init: Progress/ShapeCatalog/
                                 Campaign/WorldMap/Ads/Iap)
    home/home_screen.dart        신규/기존 CTA 분기
    map/map_screen.dart          점묘 월드맵(InteractiveViewer + _WorldPainter)
    map/round_intro_screen.dart  맵 진입용 라운드 인트로(플레이/잠김)
    game/game_screen.dart        플레이 크롬 + 라운드 인트로 오버레이 + 결과 시트
    shop/settings/…
  models/
    campaign_repository.dart      라운드/스테이지 지연생성(_plan: 도시→path→…→국가)
    world_map.dart                worldmap.json 로더 + land dot→캠페인 국가 해소
    level_generator.dart          BoardMasks(rect/ellipse/diamond/blob) + generateLevel(풀림 보장)
tools/atlas/
  build_worldmap.py             ne_50m_countries → worldmap.json (numpy PIP, 초소형국 centroid 스탬프)
  world_campaign_order.json     국가별 도시 리스트(면적순) — campaign.json 재빌드 소스
assets/campaign/{campaign.json, worldmap.json}
```

## 4. 빌드/실행 (이 머신 함정 포함)

```powershell
flutter test                 # 10개
dart analyze                 # ⚠️ flutter analyze는 이 경로에서 크래시 → dart analyze 사용
flutter build web --release  # 웹 미리보기
python -m http.server 8791   # build/web 에서 → localhost:8791
python tools/atlas/build_worldmap.py   # 월드맵 데이터 재생성
```
- ⚠️ **패키지 리네임 후 웹빌드가 옛 패키지명으로 깨지면 `flutter clean` 후 재빌드**.
- 한글/★ 경로: `android/gradle.properties` overridePathCheck·kotlin.incremental=false 이미 적용.

## 5. 다음 할 일 (우선순위)

1. **campaign.json 재빌드** — 현재 앱 asset은 120국·도시/블러브 없음(→ N Cities=0/Paths=9).
   `world_campaign_order.json` + **거대국 admin-1 주(state)별 대표도시 1개**(미국 50→101스테이지)로
   확장, 도시 실루엣 마스크 + 국가 소개(위키) 굽기. → 라운드 인트로 실측값·실도시 랜드마크 활성.
2. **게임 로고** 제작(홈 중앙, 현재 워드마크 임시).
3. **맵 폴리시**: 현재국가 파랑 줌인 시각 재확인, 초소형국 4개(Israel/Rwanda/Albania/N.Cyprus)
   셀 공유 해소(격자 상향 or centroid 충돌 회피).
4. **UI i18n**(맨 마지막): 한국어 하드코딩 문자열 → 10개어(intl/ARB). CJK(일·간중)+키릴(러) 폰트 번들.
5. **런칭 블로커(계정)**: AdMob 실ID(출시 후 발급), IAP 상품 등록(zarrows_hints_10/50),
   릴리즈 keystore 서명, 스토어 스크린샷.

## 6. 확정 사양·참고

- 결과=바텀시트+상단 MREC. 하트 경제(첫 리필 무료→보상형). 아이템: 힌트=돋보기 / 제거=번개,
  **×3 변형 없음**. 상점=힌트·제거+광고제거. 하단탭 4: 홈·맵·상점·설정.
- 사용자 우선순위: **온보딩 > 플레이 > 수익화 > 리텐션**.
- **디자인 참고(사용자 지시)**: `github.com/emilkowalski/skills` — UI 애니메이션/디자인엔지니어링
  원칙(enter=ease-out, 반투명 그림자>실선 보더, 불필요 애니 지양, reduced-motion 존중). UI 모션에 적용.
- 확정 스토리보드 아티팩트: `f6ae33b5-a4e3-4a9a-87c6-204edcb94f9b`.
- ⚠️ **기억 아닌 커밋된 코드/원격을 기준으로 작업할 것**(이전 세션 스펙 임의 변경 금지).
