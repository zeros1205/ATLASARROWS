# 릴리즈 파이프라인 — GitHub Actions

Play / TestFlight / Firebase App Distribution 자동 배포 설정. **시크릿이 없어도
워크플로는 실패하지 않는다** — 빌드까지만 하고 산출물을 run artifact로 남긴 뒤
경고만 띄운다. 계정이 준비되는 대로 시크릿만 채우면 그때부터 업로드가 붙는다.

## 워크플로 4개

| 파일 | 트리거 | 하는 일 |
|---|---|---|
| `ci.yml` | push(main) · PR | `dart analyze` + `flutter test` + `flutter build web` |
| `android-play.yml` | 태그 `v*` · 수동 | 서명 AAB → Play 트랙 업로드 |
| `ios-testflight.yml` | 태그 `v*` · 수동 | 서명 IPA → TestFlight |
| `firebase-distribution.yml` | push(main) · 수동 | APK(+선택 iOS ad-hoc) → 테스터 배포 |

- **버전 코드 = `github.run_number`**. 항상 증가하므로 Play가 거부하지 않는다.
  버전 이름(`0.1.0`)은 `pubspec.yaml`에서 온다.
- 태그 `v*`를 밀었는데 서명 시크릿이 없으면 **일부러 실패시킨다** — 서명 안 된
  릴리즈가 조용히 지나가는 것보다 낫다.

## 릴리즈 절차

```bash
# pubspec.yaml의 version을 올린 뒤
git tag v0.1.0 && git push origin v0.1.0
```
→ Play(internal, draft) + TestFlight 동시 진행.

수동 실행은 Actions 탭에서 트랙(internal/alpha/beta/production)과 상태를 골라 실행.

---

## GitHub Secrets

Settings › Secrets and variables › Actions 에 등록.
(선택: Variables에 `FLUTTER_VERSION`을 두면 워크플로 기본값 `3.44.0`을 덮어쓴다.)

### Android — Play

| 시크릿 | 내용 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | 릴리즈 keystore(.jks)를 base64로 인코딩한 문자열 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 비밀번호 |
| `ANDROID_KEY_ALIAS` | 키 별칭 |
| `ANDROID_KEY_PASSWORD` | 키 비밀번호 |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play Developer API 서비스 계정 JSON **전문** |

**keystore 생성** (한 번만. 잃어버리면 앱 업데이트를 영영 못 올린다 —
리포지토리 밖에 반드시 백업할 것):

```powershell
keytool -genkey -v -keystore atlasarrows-release.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias atlasarrows
```

base64 인코딩 (Windows):
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("atlasarrows-release.jks")) | Set-Clipboard
```

**로컬 릴리즈 빌드**는 `android/key.properties.example`를 `key.properties`로
복사해 값을 채우면 된다. 두 파일 다 `.gitignore` 처리돼 있다.

**Play 서비스 계정**: Google Cloud Console에서 서비스 계정 생성 → JSON 키 발급 →
Play Console › 설정 › API 액세스에서 해당 계정에 **릴리즈 관리자** 권한 부여.
⚠️ 첫 번째 버전은 **콘솔에서 수동으로 한 번 업로드**해야 API 업로드가 열린다.

### iOS — TestFlight

| 시크릿 | 내용 |
|---|---|
| `APPLE_TEAM_ID` | 10자리 팀 ID |
| `IOS_DIST_CERT_P12_BASE64` | Apple Distribution 인증서 .p12 base64 |
| `IOS_DIST_CERT_PASSWORD` | .p12 내보내기 비밀번호 |
| `IOS_PROVISIONING_PROFILE_BASE64` | App Store용 프로비저닝 프로파일 base64 |
| `IOS_PROVISIONING_PROFILE_NAME` | 그 프로파일의 이름 |
| `ASC_ISSUER_ID` | App Store Connect API Issuer ID |
| `ASC_KEY_ID` | API 키 ID |
| `ASC_PRIVATE_KEY` | .p8 키 파일 **내용 전문** |

Apple Developer Program(연 $99) 멤버십 필요. 인증서/프로파일 생성은 Mac이 있어야
편하지만, 없으면 Apple Developer 웹 콘솔 + CSR로도 가능하다.

시크릿이 없으면 iOS 잡은 `flutter build ios --no-codesign`까지만 돌려서
**컴파일 깨짐은 잡아준다.**

### Firebase App Distribution

| 시크릿 | 내용 |
|---|---|
| `FIREBASE_ANDROID_APP_ID` | `1:123...:android:abc...` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Firebase 서비스 계정 JSON 전문 |
| `FIREBASE_IOS_APP_ID` | (선택) iOS 배포용 |
| `IOS_ADHOC_PROFILE_BASE64` | (선택) ad-hoc 프로파일. **App Store 프로파일로는 FAD 배포 불가** |
| `IOS_ADHOC_PROFILE_NAME` | (선택) 그 프로파일 이름 |

서비스 계정에 **Firebase App Distribution 관리자** 역할을 부여할 것.
Firebase 프로젝트 자체 설정은 `docs/FIREBASE.md` 참고.

---

## 지금 단계에서 가능한 것 / 아직 아닌 것

`CLAUDE.md`의 원칙 그대로 — **못 하는 걸 할 일 목록에 올리지 않는다.**

| 항목 | 지금 가능? |
|---|---|
| CI (analyze/test/web) | ✅ 시크릿 없이 바로 동작 |
| APK/AAB/IPA 빌드 검증 | ✅ 서명 없이도 컴파일 검증됨 |
| keystore 생성 + 로컬 서명 | ✅ 지금 해도 된다 |
| Play 업로드 | ⏳ Play Console 개발자 계정 + **첫 수동 업로드** 후 |
| TestFlight | ⏳ Apple Developer Program 가입 후 |
| Firebase App Distribution | ⏳ Firebase 프로젝트 생성 후 (가장 빨리 가능) |
| **애드몹 실 광고 ID** | ⛔ **정식 출시 이후에만 발급.** 지금은 테스트 유닛이 정답 |
