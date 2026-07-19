# Atlas Arrows — 개발 핸드오프 (2026-07-19 기준)

> 이 문서 하나로 다음 세션(사람이든 AI든)이 바로 이어받는다.
> **최신 상태만** 담는다. 옛 Z-Arrows M1~M4 이력은 git 로그와 `DEV_PLAN.md` 참고
> (그 아키텍처 `lib/screens/*`는 새 앱으로 폐기됨).

## 0. 한 줄 요약

**Atlas Arrows: Tap Puzzle** = 화살표 탭 탈출 퍼즐 + **세계지도 캠페인**. 국가=라운드(면적 오름차순),
라운드는 사각형 path 퍼즐 + 도시/국가 실루엣 랜드마크로 구성. 점묘(dot-matrix) 월드맵에서
국가를 골라 플레이한다.

## 1. 지금 상태 (커밋 기준)

- 저장소: https://github.com/zeros1205/ATLASARROWS.git (2026-07-19 `z-arrows` → `ATLASARROWS` 리네임)
  - 로컬 작업 폴더도 `P5_ATLASARROWS/ATLASARROWS/`로 동시 리네임
- 브랜치 `main`. 최신 커밋:
  - `9f0da2f` 점묘 월드맵(줌인/영토색/탭→라운드인트로)
  - `f2de32b` Atlas Arrows 리네임 + 라운드 캠페인 + 라운드 인트로 + 10로케일 + 부트 정리
- **품질 게이트: `dart analyze` 클린 · `flutter test` 10/10 · `flutter build web` 성공.**
- 브라우저 실행 검증: 홈 · 월드맵 · 라운드 인트로 렌더 확인.

## 2-0. 앱 코어 세션 (2026-07-19 · 리네임 이후)

부트→온보딩→플레이→맵→상점→설정 전 구간을 **더미 제거 + 실동작 연결**했다.

- **네이티브 스플래시 이음새 수정**: `NormalTheme`의 windowBackground가
  `?android:colorBackground`(=흰색)라 스플래시와 첫 프레임 사이에 흰 플래시가 있었다.
  `@color/splash_ink`(#23252E)로 교체(values / -v31 / -night / -night-v31 4곳).
  ⚠️ `flutter_native_splash:create` 재실행 시 되돌아가므로 재적용 필요(pubspec에 경고 주석).
- **개발사 인트로**: `EnterFade`(ease-out 페이드+상승, reduced-motion 시 정지)로 마크→워드마크
  순차 등장. 로딩 진행바도 스텝 스냅 대신 트윈.
- **온보딩 신규**(`lib/features/onboarding/`): 3장 캐러셀(탭→탈출 / 막힘→하트 / 비우면 클리어).
  각 장은 **실제 보드와 같은 표현**(점격자·잉크 스트로크·삼각 화살촉)으로 그린 루프 다이어그램
  (`onboarding_diagram.dart`, CustomPainter). 언제든 건너뛰기 가능.
  부트가 `Progress.onboarded`로 분기해 첫 실행에만 노출.
- **첫 판 코치**: `coachDone` 전까지 3초마다 탈출 가능한 라인을 자동 하이라이트 + 하단 안내 칩.
  플레이어가 **직접 첫 탈출에 성공하면 자동 종료**(`ZArrowsGame.onEscaped`).
- **플레이 갭 수정**:
  - 제거 아이템이 소모되지 않던 버그 → `onRemoveUsed`(발동 시점 차감, 장전은 무료).
  - 힌트/제거 0개일 때 `+` 배지가 **상점 탭으로 이동**(기존엔 무반응).
  - **전면광고가 어디서도 호출되지 않던 문제** → `_next()`에서 `Ads.maybeShowInterstitial`.
  - 결과시트 MREC 더미 → 실제 `AdsMrec`(AdSize.mediumRectangle).
- **상점 실동작**: 보유량 헤더, 보상형 광고 힌트+1, IAP 상품 바인딩(스토어 현지화 가격),
  미등록 상품은 `준비중`으로 비활성, 구매 복원. 구매 결과 스낵바는 `AppShell`에서 일괄 처리.
- **설정 실동작**: 소리·진동 토글이 `Progress`에 연결(→`Sfx`·`Pressable` 실제 반영.
  `Pressable`의 햅틱이 설정을 무시하던 것도 수정), 광고 제거/구매 복원 IAP 연결,
  **튜토리얼 다시 보기**(진행도는 보존).
- **광고 제거 반영**: `adsRemoved`면 배너·MREC·전면 전부 차단. **보상형은 유지**(플레이어가
  자발적으로 시작하는 교환이므로).
- **IAP 상품 id 접두어 확정 — `atlsars_`** (사용자 결정). 스토어 미등록 상태에서 4종 통일:
  `atlsars_hints_10` · `atlsars_hints_50` · `atlsars_removes_5`(신규) ·
  `atlsars_remove_ads`(신규·비소모성). 상품 id는 등록 후 영구 변경 불가라 지금이 마지막 기회였다.
  스토어 등록 전까지는 상점에서 자동으로 `준비중`으로 뜨므로 **지금 막히는 것 없음**.
- **테스트**: `test/progress_test.dart` 신규 9개(아이템 차감·온보딩 게이트·광고제거·언락 프론티어).
  전체 **19/19 통과**, `dart analyze` 클린, `flutter build web` 성공.

## 2-1. 배포 파이프라인 + 게임서비스 세션 (2026-07-19)

- **릴리즈 서명**: `build.gradle.kts`의 release가 **디버그 키로 서명**되고 있었다
  (Play가 거부하는 상태). `key.properties`(로컬) → 환경변수(CI) → 디버그 폴백 순으로 해결.
- **GitHub Actions 4종**(`.github/workflows/`): `ci`(analyze·test·web) /
  `android-play`(AAB→Play) / `ios-testflight`(IPA→TestFlight) /
  `firebase-distribution`(APK→FAD). 버전코드=`run_number`.
  **시크릿 없으면 빌드만 하고 스킵**, 단 `v*` 태그인데 서명 없으면 실패시킨다.
  → 시크릿 전체 목록·발급 절차는 `docs/RELEASE.md`.
- **게임서비스**(`lib/services/game_services.dart`): Play Games + Game Center를 한 API로.
  리더보드 2종(스테이지/국가) · 업적 5종. 스테이지 진행 시 fire-and-forget 제출,
  설정에 연결/리더보드/업적 행 추가. **미로그인·오프라인·미설정이면 전부 무해한 no-op.**
  ⚠️ **Play Games는 매니페스트 APP_ID가 placeholder면 네이티브 크래시**(Dart로 못 잡음) →
  `GameServices.androidConfigured` 킬 스위치가 false로 막고 있다. 실제 ID 넣는 커밋에서만 true.
- **Firebase**(`lib/services/firebase.dart`): `google-services.json` /
  `GoogleService-Info.plist`가 **있으면 자동으로 붙고 없으면 없는 채로 빌드**된다
  (gradle 플러그인도 조건부 적용). `flutterfire configure`·`firebase_options.dart` 안 씀.
  → 콘솔 설정 절차는 `docs/FIREBASE.md`.
- 검증: `dart analyze` 클린 · `flutter test` 19/19 · `flutter build apk --release` 성공.

## 2-2. iOS 서명 파이프라인 실동작 확인 (2026-07-19)

**Xcode 없이 서명 IPA 아카이브까지 CI에서 통과**(run `29687156452`). Android 서명
AAB도 통과(run `29684013621`). 그 과정에서 고친 것:

- **iOS 수동 서명 고정**(`ios/Flutter/Release.xcconfig`): CI엔 개발용 인증서가 없어
  자동 서명이면 flutter가 `No valid code signing certificates were found`로 죽는다.
  팀(`9YM6784Y87`)·프로파일·아이덴티티를 명시. **프로파일 이름 바꾸면 여기도 수정.**
- **iOS 최소 버전 13.0 → 15.0**: firebase-core 요구사항. iOS 13~14 기기는 제외됨.
- **애플 인증서 1개로 통일**: 배포 인증서는 계정당 2개가 상한이라 앱별 분리가
  불가능하다. `Logan Land`(만료 2027/07/19) 하나로 3앱 공유, 프로파일만 앱별.
  → 세 리포 시크릿 일괄 갱신 스크립트는 `docs/RELEASE.md` 부록.
- **Play 서비스 계정**: `play-publisher@atlasarrows-7a720.iam.gserviceaccount.com`
  (앱별 분리 원칙에 따라 Atlas Arrows 전용으로 신규 생성). Play Console
  `사용자 및 권한`에서 Atlas Arrows에만 권한 부여.
  ⚠️ Play Console의 **API 액세스 메뉴는 `설정`에 없다** — `사용자 및 권한` → ⋮ →
  신규 사용자 초대에서 서비스 계정 이메일을 초대하는 방식으로 바뀌었다.

⚠️ **이 작업에서 크게 돌아간 지점 두 가지** — 같은 실수를 반복하지 말 것:
1. `.p12`를 OpenSSL 3 기본값으로 만들어 macOS가 "비밀번호 틀림"이라는 **거짓 오류**를
   냈고, 비밀번호를 의심해 **인증서를 폐기·재발급하는 헛수고**를 했다.
   → `docs/RELEASE.md` 「함정 1」.
2. 프로파일 생성 시 **인증서를 확인 없이 추측으로 골라** 프로파일 전체를 다시
   만들어야 했다. 어느 `.p12`를 보유 중인지 먼저 확인할 것.

## 2. 이전 세션에 바뀐 것 (2026-07-19)

- **이름/패키지**: Z-Arrows → **Atlas Arrows**. applicationId/bundle = `com.loganland.atlasarrows`,
  Dart 패키지 `atlas_arrows`. 내부 클래스 `ZArrowsGame`은 유지.
  (⚠️ 당시 IAP SKU `zarrows_hints_10/50` 유지로 적었으나 **이후 `atlsars_`로 통일 확정** — 2-0 참고)
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
                                 Campaign/WorldMap/Ads/Iap) → 온보딩 or 셸
    onboarding/onboarding_screen.dart   3장 규칙 캐러셀(첫 실행·설정에서 재생)
    onboarding/onboarding_diagram.dart  규칙별 루프 다이어그램(보드와 동일한 표현)
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
5. **출시 이후/출시 준비 시점 작업** (⚠️ **지금 단계의 블로커가 아님** — `CLAUDE.md` 참고):
   - **애드몹 실 광고 ID = 정식 출시해야 애드몹 앱 등록이 되고 그때 발급된다.**
     출시 전엔 받을 방법이 없으므로 **구글 테스트 유닛이 현재로선 정답**이다. 할 일로 올리지 말 것.
   - IAP 상품 등록(`atlsars_hints_10/50` · `atlsars_removes_5` · `atlsars_remove_ads`),
     릴리즈 keystore 서명, 스토어 스크린샷 — 전부 스토어 콘솔 작업 시점에 처리.

## 6. 확정 사양·참고

- 결과=바텀시트+상단 MREC. 하트 경제(첫 리필 무료→보상형). 아이템: 힌트=돋보기 / 제거=번개,
  **×3 변형 없음**. 상점=힌트·제거+광고제거. 하단탭 4: 홈·맵·상점·설정.
- 사용자 우선순위: **온보딩 > 플레이 > 수익화 > 리텐션**.
- **디자인 참고(사용자 지시)**: `github.com/emilkowalski/skills` — UI 애니메이션/디자인엔지니어링
  원칙(enter=ease-out, 반투명 그림자>실선 보더, 불필요 애니 지양, reduced-motion 존중). UI 모션에 적용.
- 확정 스토리보드 아티팩트: `f6ae33b5-a4e3-4a9a-87c6-204edcb94f9b`.
- ⚠️ **기억 아닌 커밋된 코드/원격을 기준으로 작업할 것**(이전 세션 스펙 임의 변경 금지).
