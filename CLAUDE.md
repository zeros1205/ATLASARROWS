## 1. State Assumptions, Then Proceed

**Say what you assumed. Keep going. Default the rest.**

Before implementing:
- State your assumptions in one line, then start.
- If multiple interpretations exist, pick the likeliest and say which one you picked.
- If a simpler approach exists, say so while doing the work - not as a question that blocks it.
- Ask only when the answer changes what gets built, not how well, and the wrong choice can't be cheaply undone.

A stated assumption gets corrected in seconds. A question costs a round-trip and hands the work back to the user. If you're about to ask a second question in one task, you're doing it wrong.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Verify Before Done

**If you touched code, run the check before saying "done" - and report what actually ran.**

- `npm test`, `pytest`, `cargo test`, whatever the project uses. Smallest relevant check first, broader checks when risk is high.
- No test setup? At minimum, verify the project builds or typechecks.
- Report the exact command and its result: "passed", "failed with X", or "not run because Y".
- Never write "done", "fixed", or "works" unless a concrete check backs it.
- Run it proactively, before the user signals "끝", "완료", "다 됐어".

This is the step LLMs skip most often. Treat it as non-negotiable.

## 5. Teach One Thing On The Way Out

**End with what the user would want to know next time. Two or three sentences.**

When the work is done:
- Name the one concept, tradeoff, or gotcha that actually mattered here.
- Teach what the code doesn't show: why this way over the obvious one, which default you leaned on, what breaks first at scale.
- If it needs a heading, it's too long. If it restates the diff, delete it.
- Skip it when the change is trivial, or when the user is the one who taught you the thing.

Why: an agent that only ships code leaves the user unable to maintain it. They should finish each task slightly more able to do it without you.

---

# Atlas Arrows — 작업 규칙

> 이 파일은 매 세션 자동으로 읽힌다. **작업 전에 반드시 확인할 것.**
> 상세한 개발 현황은 `docs/HANDOFF.md`.
> **데이터 소스·파이프라인 정본은 `docs/DATA_SOURCES.md`** — 영토/도시/국가 데이터 출처를
> 스크립트 뒤지지 말고 여기서 먼저 확인할 것(도시 폴리곤 = `tools/atlas/cities_raw.json`).

---

## ⛔ 절대 다시 묻지 말 것 — 현재 단계에서 "블로커"가 아닌 것들

### 1. 애드몹 광고 ID (가장 자주 반복된 실수)

**앱을 정식 출시해야만 구글 애드몹에 앱을 등록할 수 있고, 그 다음에야 실제 광고 ID가 발급된다.**
출시 전에는 실ID를 **받을 방법 자체가 없다.**

- 지금 단계 = **출시 전 개발 단계**
- 따라서 `lib/services/ads/ads_io.dart`의 **구글 공식 테스트 유닛이 현재로선 정답이다.**
- 이것은 **결함도, 미완성도, 런칭 블로커도 아니다.** 정상 상태다.
- ❌ "AdMob 실ID 필요"를 할 일 / 블로커 / 남은 과제로 **올리지 말 것**
- ❌ 사용자에게 실ID를 요청하거나 발급 방법을 안내하지 말 것
- ✅ 실ID 교체는 **정식 출시 이후** 별도로 진행하는 사후 작업이다

### 2. 그 외 계정·스토어 의존 항목

같은 이유로 아래도 지금 단계에서 우리가 처리할 수 없다. 진행을 막는 요소로 보고하지 말 것:

| 항목 | 가능해지는 시점 |
|---|---|
| 애드몹 실 광고 ID | **정식 출시 이후** |
| IAP 상품 실제 등록 | 스토어 콘솔 등록 시점 (코드는 `준비중` 처리로 이미 대응됨) |
| 릴리즈 keystore 서명 | 출시 준비 시점 |
| 스토어 스크린샷 | 출시 준비 시점 |

---

## 명명 규칙 — 앱 이름은 **Atlas Arrows**

Z-Arrows에서 **Atlas Arrows**로 리네임됐다. 새로 만드는 식별자는 전부 새 브랜드를 쓴다.

- **스토어 제목 = `Atlas Arrows: Tap Puzzle`** (확정, 24자 / 구글플레이 30자 제한).
  동종 앱(Arrow Puzzle: Tap Puzzle Games, Arrows – Puzzle Escape 등)의 관례를 따른 것 —
  이 장르는 수식어를 **입력(tap)과 목표(escape)**에서 뽑는다.
- ⛔ **화살표의 생김새를 형용하는 수식어를 붙이지 말 것.** 특히 **"스네이크/snake" 금지**
  (사용자 지시). 동종 앱 중 모양을 형용하는 곳은 한 곳도 없고, 저희만 쓰던 잉여어였다.
  장르는 그냥 **"화살표 탭 탈출 퍼즐"**. 코드 주석도 `an ordered path of cells`처럼
  정의로 설명하면 충분하다.
- 참고: 저희와 동종 앱의 진짜 차이는 화살표가 한 칸 타일이 아니라 **여러 칸이 꺾여 이어진
  선**이라는 점이다. 이건 제목 수식어가 아니라 **스토어 설명의 차별점 문장**으로 쓴다.

- 패키지 `atlas_arrows` / applicationId·bundle `com.loganland.atlasarrows`
- **스토어 IAP 상품 id 접두어 = `atlsars_`** (확정. 4종:
  `atlsars_hints_10` · `atlsars_hints_50` · `atlsars_removes_5` · `atlsars_remove_ads`)
  ⚠️ 상품 id는 스토어 등록 후 **영구히 변경 불가**다. 등록 전인 지금이 마지막 수정 기회였다.
- **`ZArrows`/`zarrows_` 계열 식별자는 전부 폐기됐다.** 게임 클래스 =
  `AtlasArrowsGame`(`lib/game/atlas_arrows_game.dart`), 앱 클래스 = `AtlasArrowsApp`.
  새 식별자에 `zarrows_`를 쓰지 말 것(iap.dart의 옛 접두어 언급은 "재도입 금지" 주석).

## ⚠️ 개발 환경 — Windows, **Xcode/Mac 없음**

- 사용자는 **Xcode를 쓸 수 없다.** "Xcode에서 ~하세요"는 실행 불가능한 지시다.
  iOS 관련은 **웹 콘솔 + OpenSSL + pbxproj 직접 편집**으로 대체 경로를 제시할 것.
- iOS 빌드는 **GitHub Actions의 macOS 러너**가 한다 → Mac 없이 TestFlight 배포 가능.
- `GoogleService-Info.plist`는 Xcode 대신 **pbxproj에 직접 등록해 뒀다.**
  그래서 이 파일이 없으면 **iOS 빌드가 실패**한다(CI가 시크릿에서 복원).
- iOS 릴리즈는 **수동 서명 고정** — `ios/Flutter/Release.xcconfig`에 팀·프로파일·
  아이덴티티 명시. CI엔 개발용 인증서가 없어 자동 서명이면 flutter가 죽는다.
- ⛔ **`.p12`는 반드시 `-macalg sha1 -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES`로
  만들 것.** OpenSSL 3 기본값은 macOS `security`가 못 읽으면서 "비밀번호가 틀렸다"는
  엉뚱한 오류를 내 헛수고를 부른다. 자세한 함정 목록은 `docs/RELEASE.md`.
- ⛔ **시크릿 등록에 파이프(`|`) 금지, `--body` 사용.** 파이프는 줄바꿈을 값에
  섞어 서명을 깨고, 마스킹까지 빗나가 로그에 비밀번호를 평문 노출시킨다.
- ✅ **Xcode 없이 서명 IPA 아카이브 성공을 확인했다**(2026-07-19).
- Firebase 설정 파일은 리포에 커밋하지 않고 **base64 시크릿**으로 전달한다(사용자 결정):
  `FIREBASE_ANDROID_CONFIG_BASE64`(선택) · `FIREBASE_IOS_CONFIG_BASE64`(필수).

## 배포 파이프라인

⛔ **빌드·설치·배포는 사용자가 지시할 때만 한다.** 배포 워크플로(FAD·TestFlight·Play)
뿐 아니라 **로컬 `flutter build`, `adb install`, `flutter run`, 실기기 확인 전부** 해당한다.
시크릿이 준비됐다거나 검증이 필요해 보인다는 이유로 돌리는 것도 안 되고,
**"폰 연결해 주시면 올리겠습니다" 같은 제안도 하지 말 것.**

상시 승인된 것은 **`dart analyze` · `flutter test` · git 커밋·푸시**뿐이다.
코드를 고친 뒤에는 정적 검사와 테스트까지만 하고 멈춘다. 실기기 확인이 필요하면
필요하다고만 보고하고, 빌드 여부는 사용자가 정한다.


- GitHub Actions 4종: `ci` · `android-play` · `ios-testflight` · `firebase-distribution`.
  ⛔ **네 개 전부 `workflow_dispatch` 전용이다. 자동 트리거를 되살리지 말 것.**
  예전엔 `firebase-distribution`이 main 푸시마다, `android-play`/`ios-testflight`가
  `v*` 태그마다 돌았다 — **커밋을 저장하는 행위가 곧 테스터·스토어 배포**가 됐고
  사용자가 이를 두 번 지적했다. 푸시가 무언가를 내보내면 안 된다.
- **시크릿이 없으면 빌드만 하고 업로드는 건너뛴다**(실패로 처리하지 않음).
- 시크릿 목록·발급 절차: `docs/RELEASE.md` / Firebase·게임서비스: `docs/FIREBASE.md`
- ⚠️ **Play Games는 매니페스트 APP_ID가 잘못되면 네이티브 크래시**(Dart로 못 잡음).
  `GameServices.androidConfigured` 킬 스위치가 막고 있다. 실제 ID를 넣는
  **같은 커밋에서만** true로 바꿀 것.
- Firebase는 `google-services.json` / `GoogleService-Info.plist`가 있으면 자동으로
  붙고, 없으면 없는 채로 빌드된다. `flutterfire configure`는 쓰지 않는다.

## 작업 원칙

- ⛔ **사용자에게는 항상 존댓말로 답할 것.** 반말 금지.
- ⛔ **지시 없이 예약·스케줄을 걸지 말 것.** `send_later`·트리거·크론·"자가 점검" 예약
  등 미래 시점에 세션을 다시 깨우는 모든 행위는 **사용자가 명시적으로 요청할 때만** 한다.
  PR 구독 지침이 "체크인을 예약하라"고 안내하더라도, 그것만으로는 근거가 되지 않는다.
- **기억이 아니라 커밋된 코드/원격을 기준으로** 작업할 것. 이전 세션 스펙을 임의로 바꾸지 말 것.
- 우선순위: **온보딩 > 플레이 > 수익화 > 리텐션**
- UI 문자열은 아직 한국어 하드코딩. **실제 i18n 번역은 맨 마지막 작업**이다.
- UI 모션: enter = ease-out, 반투명 그림자 > 실선 보더, 불필요한 애니메이션 지양,
  reduced-motion 존중 (`lib/shared/motion.dart`의 `reduceMotion()` 사용).

## 이 머신 함정

```powershell
dart analyze                 # ⚠️ flutter analyze는 이 경로에서 크래시 → dart analyze 사용
flutter test
flutter build web --release
```

- 한글/★ 경로 때문에 `android/gradle.properties`에 overridePathCheck·kotlin.incremental=false 적용됨.
- 패키지 리네임 후 웹빌드가 옛 패키지명으로 깨지면 `flutter clean` 후 재빌드.
- `flutter_native_splash:create` 재실행 시 `values*/styles.xml`의 `NormalTheme` 배경이
  `?android:colorBackground`로 되돌아간다 → **`@color/splash_ink`로 재적용 필요**
  (안 하면 스플래시와 첫 프레임 사이에 흰 화면이 번쩍인다).
