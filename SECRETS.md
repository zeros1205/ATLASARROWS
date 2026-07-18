# SECRETS — 실제 값으로 교체해야 하는 항목

이 문서는 현재 코드에 **임시 placeholder** 로 들어가 있는, 출시 전 반드시
실제 값으로 교체해야 하는 항목들을 정리한 것이다. 지금은 전부 Google/스토어
**테스트 값**이라 개발·QA 는 문제없이 돌아가지만, 프로덕션 빌드에서는 교체하지
않으면 광고 수익이 잡히지 않거나 결제가 동작하지 않는다.

> ⚠️ 실제 키/시크릿은 이 파일이 아니라 `.env`, CI Secret, 또는 로컬 keystore
> 로 관리하고 이 파일에는 **어디를 바꿔야 하는지만** 남긴다.

---

## 1. AdMob (Google Mobile Ads)

파일: `lib/services/ads/ads_io.dart`

| 용도 | 현재(테스트) 값 | 교체 필요 |
|------|----------------|-----------|
| Banner (Android) | `ca-app-pub-3940256099942544/6300978111` | ✅ 실 배너 단위 ID |
| Banner (iOS) | `ca-app-pub-3940256099942544/2934735716` | ✅ |
| Interstitial (Android) | `ca-app-pub-3940256099942544/1033173712` | ✅ |
| Interstitial (iOS) | `ca-app-pub-3940256099942544/4411468910` | ✅ |
| Rewarded (Android) | `ca-app-pub-3940256099942544/5224354917` | ✅ 하트/힌트 리워드 광고 |
| Rewarded (iOS) | `ca-app-pub-3940256099942544/1712485313` | ✅ |

파일: `android/app/src/main/AndroidManifest.xml` (line ~36)

| 용도 | 현재(테스트) 값 | 교체 필요 |
|------|----------------|-----------|
| AdMob App ID (Android) | `ca-app-pub-3940256099942544~3347511713` | ✅ 실 App ID |

iOS: `ios/Runner/Info.plist` 의 `GADApplicationIdentifier` 도 동일하게 교체.

---

## 2. 인앱결제 (In-App Purchase)

파일: `lib/services/iap.dart` (`hintProducts`)

| Product ID | 지급 | 비고 |
|------------|------|------|
| `zarrows_hints_10` | 힌트 10개 | Play Console / App Store Connect 에 **동일 ID** 로 등록 필요 |
| `zarrows_hints_50` | 힌트 50개 | 〃 |

- 상점 화면(`lib/features/shop/shop_screen.dart`)의 가격 표기(₩1,200 등)는
  현재 하드코딩 라벨이며, 실제 가격은 스토어 등록 가격을 따라간다.
- "광고 제거" IAP 를 추가할 경우 product id 를 여기에 추가하고 지급 로직 연결.

---

## 3. 앱 식별자 / 서명

| 항목 | 위치 | 현재 값 | 비고 |
|------|------|---------|------|
| applicationId (Android) | `android/app/build.gradle.kts:20` | `com.loganland.zarrows` | 확정 시 유지 |
| Bundle ID (iOS) | Xcode / `project.pbxproj` | 미설정 | 스토어 등록 ID 와 일치 필요 |
| 릴리스 keystore | `android/key.properties` (미생성) | — | ✅ 생성 후 CI Secret 으로 주입 |

`android/key.properties` (예시 — 커밋 금지):
```
storePassword=<REDACTED>
keyPassword=<REDACTED>
keyAlias=upload
storeFile=<path-to-upload-keystore.jks>
```

---

## 교체 체크리스트 (출시 전)

- [ ] AdMob 실 계정 생성 → 배너/전면/리워드 단위 6종 + App ID 2종 발급·교체
- [ ] IAP 상품 2종(+광고제거) 스토어 등록 및 활성화
- [ ] 릴리스 keystore 생성 및 `key.properties` 주입 (CI Secret)
- [ ] iOS Bundle ID / `GADApplicationIdentifier` 설정
- [ ] `flutter build appbundle --release` / `flutter build ipa` 검증
