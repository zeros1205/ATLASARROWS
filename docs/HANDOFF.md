# Z-Arrows 개발 핸드오프 (2026-07-17 기준)

> 하루 만에 M1 코어 → M2 연출 → M4 메타/광고 → M3a 카탈로그 1,562레벨 → 보상형+IAP까지 완료.
> 이 문서 하나로 다음 세션(사람이든 AI든)이 바로 이어받을 수 있게 정리한다.
> 기획 전체는 `DEV_PLAN.md`, 실루엣 저작 규칙은 `BOARD_SHAPE_GUIDE.md` 참고.

## 1. 게임이 무엇인가

- **스네이크 화살표 퍼즐**: 화살표는 격자를 따라 꺾이며 이어지는 *선*. 탭하면 선 전체가
  자기 경로를 따라 기차처럼 미끄러져 머리 방향 직선으로 화면 밖 탈출.
- 다른 선에 막히면 밀려갔다 튕겨 복귀 + **하트 차감**(3개 소진 시 실패). 자기 몸통은
  경로를 막지 않는다(나선 가능).
- 아트: **오프화이트(#F7F6F2) 배경 + 오프블랙(#23252E) 얇은 선**. 색은 액션에만 —
  탈출=파랑, 막힘/실수=빨강, 힌트=파랑 깜빡임. (`lib/theme.dart`)
- 보드는 정사각형이 아니라 **실루엣(마스크)**: 블롭/타원/다이아몬드/링/크로스 등.
- 의도된 비즈니스 루프: 체류시간↑ → 하단 배너 상시 노출, 실수/힌트 소진 → 보상형 광고,
  헤비유저 → 힌트 IAP.

## 2. 저장소 구조

```
lib/
  main.dart                  부팅: Progress → ShapeCatalog → Ads → Iap → runApp (runZonedGuarded)
  theme.dart                 ZTheme 색상 팔레트 (아트 아이덴티티의 단일 소스)
  models/
    direction.dart           U/D/L/R + dx/dy
    arrow_line.dart          선 = 셀 경로. "r,c:MOVES" 파싱 (예: "1,2:RRD")
    level.dart               Level = rows/cols + mask(실루엣 셀 집합) + lines. 중복/범위 assert
    level_generator.dart     ★핵심. BoardMasks(rect/ellipse/diamond/blob) + generateLevel()
    levels.dart              번들 50레벨(카탈로그 실패 시 폴백). levelsPerChapter=10
    shape_catalog.dart       assets/shapes/shapes.json 로드 (1,562 실루엣)
    level_repository.dart    레벨 지연 생성+캐시. 카탈로그 있으면 1,562레벨, 없으면 번들 50
  game/
    board_logic.dart         순수 규칙. tap()→MoveEscaped(steps)/MoveBlocked(freeSteps,blockerId),
                             isSolvable() = greedy 솔버(제거는 남을 절대 못 막으므로 정확함)
    z_arrows_game.dart       FlameGame. 콤보(5초 윈도우, x2 텍스트, x3 줌펀치), 하트, 힌트, 쉐이크
    board_component.dart     마스크 셀에 점 찍고 LineComponent 호스팅. cell=100px 고정, 게임이 스케일
    line_component.dart      PathMetric 기반 슬라이드 애니메이션(탈출/범프), 선분 거리 히트테스트
    sfx.dart                 사운드+햅틱 (설정 토글 반영, 에러 무시)
  services/
    progress.dart            shared_preferences: unlocked/hints/totalClears/sound/haptics
    iap.dart                 in_app_purchase: 힌트 번들 소모성 (§5)
    ads/ads.dart             조건부 export: 모바일=ads_io.dart(실제 AdMob), 웹·데스크톱=ads_stub.dart
  screens/
    home_screen.dart         PLAY(이어하기)/LEVELS/설정 다이얼로그
    level_select_screen.dart 챕터별 그리드 (클리어/진행중/잠김)
    game_screen.dart         상단바(하트/힌트/재시작) + GameWidget + GET HINTS 시트 + 배너
test/board_logic_test.dart   규칙 + 데드락 + 번들50 + 카탈로그 샘플링 솔버 검증 (10개 테스트)
tools/
  gen_audio.py               효과음 합성(stdlib). 수정 후 재실행하면 assets/audio 갱신
  build_shape_masks.py       ★GPT 메타포 표 → 마스크 합성 → assets/shapes/shapes.json
  validate_shapes.py         ASCII 실루엣 원본 검증기 (GPT가 진짜 마스크를 줄 때 사용)
docs/
  DEV_PLAN.md                마일스톤/기획 전체
  BOARD_SHAPE_GUIDE.md       실루엣 저작 하드 제약 (GPT 프롬프트용)
  Z_ARROWS_METAPHOR_BOARD_SHAPE_2000.md   GPT 산출물(아이디어 표 — 마스크 아님)
```

## 3. 레벨 파이프라인 (가장 중요한 설계)

1. **풀 수 있음 보장 = 역삽입**: 선을 하나씩 삽입할 때 "머리의 직선 탈출 경로가 *먼저
   삽입된 선들*만 피하면" 됨 → 역순 제거가 항상 성립. 생성기가 이 규칙으로만 삽입하므로
   **모든 생성 레벨은 구성상 풀 수 있고**, 테스트의 greedy 솔버가 재검증한다.
2. **실루엣**: GPT 메타포 표 2,000행 → `build_shape_masks.py`가 카테고리·크기·목표 셀
   수·키워드(소용돌이→링 등)로 파라메트릭 합성 → 검증 통과 1,562개가 `shapes.json`.
   실패 438행은 바운딩이 작아서 탈락(개선 여지, 현재는 방치 결정).
3. **지연 생성**: 부팅 때 1,562개를 만들면 느리므로 `LevelRepository.levelAt(i)`가
   진입 시 생성+캐시. 시드 고정(7000+i), boss는 fill 0.9/maxLen 14.
4. ⚠️ **플랫폼 간 레벨 차이**: dart:math Random이 VM/web에서 다를 수 있어 같은 시드라도
   보드가 플랫폼별로 다를 수 있음(각자 풀 수 있음은 보장). 크로스플랫폼 동기화가 필요해지면
   레벨을 JSON으로 프리베이크할 것 (DEV_PLAN M3 노트).

## 4. 빌드/실행 (이 머신의 함정 포함)

```powershell
flutter test                 # 10개 테스트 (솔버 검증 포함)
dart analyze                 # ⚠️ flutter analyze는 이 경로에서 크래시 — dart analyze 사용
flutter build web --release  # 웹 미리보기 빌드
python -m http.server 8756   # build/web 에서 실행 → localhost:8756
flutter build apk --debug    # Android (아래 워크어라운드 이미 적용됨)
python tools/build_shape_masks.py   # 실루엣 재생성 (표 수정 시)
python tools/gen_audio.py           # 효과음 재생성 (파라미터 수정 시)
```

- **경로에 한글/★가 있어서** 생기는 문제와 해결(모두 적용 완료):
  - `flutter analyze` 크래시 → `dart analyze` 사용
  - Gradle 경로 체크 → `android/gradle.properties`: `android.overridePathCheck=true`
  - Kotlin 증분 캐시(C:/D: 드라이브 분리) → `kotlin.incremental=false`
  - `kotlin {}` unresolved → app/build.gradle.kts에 `org.jetbrains.kotlin.android` 플러그인 적용
- **웹 릴리즈가 흰 화면이면**: 플러그인 추가 후 레지스트런트가 낡은 것 →
  `flutter clean; flutter build web --release` (실제로 겪음: shared_preferences
  MissingPluginException). main()의 runZonedGuarded가 콘솔에 `FATAL:`로 원인을 찍는다.
- **`flutter pub add`가 pubspec의 `assets:` 섹션을 지우거나 중복시킴** — pub add 후 반드시
  pubspec 확인 (오늘 두 번 발생).

## 5. 수익화 현황

| 항목 | 상태 | 런칭 전 할 일 |
|---|---|---|
| 배너 (전 화면 하단 60px) | AdMob **테스트 ID로 실연동**, 웹은 플레이스홀더 | 실제 ID 교체 |
| 전면 (10레벨 이후 3클리어마다) | 테스트 ID로 실연동, 프리로드 | 실제 ID 교체 + 빈도 Remote Config화 |
| 보상형 (힌트 0 → WATCH AD +1) | 테스트 ID로 실연동, 보상은 완주 시에만 | 실제 ID 교체 |
| 힌트 IAP | 코드 완성, 상품 미등록이라 COMING SOON 표시 | 스토어에 `zarrows_hints_10`(10개), `zarrows_hints_50`(50개) 소모성 등록 |

- 테스트 ID 교체 위치: `lib/services/ads/ads_io.dart` 상단,
  `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist` (모두 주석 표시).
- 힌트 지급 훅은 `Progress.instance.grantHints(n)` 하나로 통일 (광고/IAP 둘 다 이걸 호출).

## 6. 커밋 히스토리 (오늘)

| 커밋 | 내용 |
|---|---|
| f7c5b77 | M1 라인 코어: 규칙/솔버/생성기/마스크 보드/잉크 아트/하트 |
| 59eeac1 | M2 juice: 합성 SFX(콤보 반음 상승), 햅틱, 콤보 연출, 쉐이크/플래시 |
| 4fdab4c | M4 메타: 홈/레벨맵/영속화/힌트/광고 스캐폴드, Android 빌드 수정 |
| 705a46b | M3a: GPT 표 → 1,562 실루엣 → 지연 생성 레벨 |
| de35bba | 보상형 광고 + 힌트 IAP + GET HINTS 시트 |

## 7. 다음 세션 후보 (우선순위 제안)

1. **런칭 블로커 (계정 필요 — 코드 아님)**: AdMob 실계정 ID, 스토어 IAP 상품 등록,
   릴리즈 서명(keystore), 스토어 스크린샷
2. 실기기 QA: 햅틱 체감, 광고 타이밍, 레벨 3~10 난이도 곡선(1분+ 체감 확인)
3. 밀린 것들: 한글 UI 폰트 번들(현재 영문 UI), 레벨 JSON 프리베이크, 실루엣 438행 회수(보류),
   데일리 챌린지(보류)

## 8. 2026-07-18 세션 추가분

- **픽처 실루엣 파이프라인 (d6dc838)**: 지난 세션 말미에 `validate_shapes.py`가 GPT 픽처
  10개만으로 shapes.json을 덮어써 1,562 카탈로그가 날아갈 뻔한 걸 수습. 이제 두 도구가 같은
  결과로 수렴: `build_shape_masks.py`가 합성 1,562 뒤에 `shapes_raw/*.txt` 검증 통과분을
  붙이고, `validate_shapes.py`는 기존 파일에 병합(같은 이름은 교체). 현재 카탈로그 1,572개
  (픽처는 `theme:"picture"`, 인덱스 1562+라 뒤쪽 레벨에서 등장).
- **앱 아이콘 + 스플래시 (b94407d)**: `tools/gen_icon.py`가 ZTheme 팔레트로 마크(잉크
  스네이크 라인이 Z를 그리며 파란 화살촉으로 탈출)를 그림 → `dart run flutter_launcher_icons`
  (Android adaptive/iOS/web) + `dart run flutter_native_splash:create`(Android 12 포함,
  오프화이트). 마크 수정은 gen_icon.py 고치고 위 3개 명령 재실행. flutter test + web release
  + apk debug 전부 통과 확인.
