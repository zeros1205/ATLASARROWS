# Atlas Arrows — 작업 규칙

> 이 파일은 매 세션 자동으로 읽힌다. **작업 전에 반드시 확인할 것.**
> 상세한 개발 현황은 `docs/HANDOFF.md`.

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

- 패키지 `atlas_arrows` / applicationId·bundle `com.loganland.atlasarrows`
- **스토어 IAP 상품 id 접두어 = `atlsars_`** (확정. 4종:
  `atlsars_hints_10` · `atlsars_hints_50` · `atlsars_removes_5` · `atlsars_remove_ads`)
  ⚠️ 상품 id는 스토어 등록 후 **영구히 변경 불가**다. 등록 전인 지금이 마지막 수정 기회였다.
- 예외는 내부 클래스명 `ZArrowsGame` 하나뿐. **새로 만드는 식별자에 `zarrows_`를 쓰지 말 것.**

## 작업 원칙

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
