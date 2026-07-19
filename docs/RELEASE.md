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
| `APPLE_TEAM_ID` | 10자리 팀 ID — `9YM6784Y87` |
| `IOS_DIST_CERT_P12_BASE64` | Apple Distribution 인증서 .p12 base64 |
| `IOS_DIST_CERT_PASSWORD` | .p12 내보내기 비밀번호 |
| `IOS_PROVISIONING_PROFILE_BASE64` | App Store용 프로비저닝 프로파일 base64 |
| `IOS_PROVISIONING_PROFILE_NAME` | `com.loganland.atlasarrows AppStore` |
| `ASC_ISSUER_ID` | App Store Connect API Issuer ID (팀 공통) |
| `ASC_KEY_ID` | API 키 ID — 현재 `Z4CS33J32D` (키 이름 `AtlasArrows CI`) |
| `ASC_PRIVATE_KEY` | .p8 키 파일 **내용 전문**. 발급 시 **한 번만** 다운로드 가능 |

##### 세 앱이 공유하는 값 / 앱마다 다른 값

인증서와 그 비밀번호는 **계정 단위라 세 앱이 같은 값**을 쓴다. 프로파일만 앱별로
다르다. 리포마다 시크릿 **이름이 다르니** 주의:

| 내용 | ATLASARROWS | hiddenblocks | KR_APT_DOC_READER |
|---|---|---|---|
| `.p12` | `IOS_DIST_CERT_P12_BASE64` | `IOS_DIST_CERT_BASE64` | `IOS_CERTIFICATE_P12_BASE64` |
| 비밀번호 | `IOS_DIST_CERT_PASSWORD` | `IOS_DIST_CERT_PASSWORD` | `IOS_CERTIFICATE_PASSWORD` |
| 프로파일 | `IOS_PROVISIONING_PROFILE_BASE64` | `IOS_PROVISION_PROFILE_BASE64` | `IOS_PROVISIONING_PROFILE_BASE64` |
| 프로파일 이름 | `IOS_PROVISIONING_PROFILE_NAME` | (없음) | `IOS_PROVISIONING_PROFILE_NAME` |
| `.cer` / `.key` | (불필요) | (불필요) | `IOS_CERTIFICATE_CER_BASE64` / `IOS_PRIVATE_KEY_BASE64` |

웹 UI로는 세 리포에 한 번에 못 넣는다(Organization 시크릿은 개인 계정에 없음).
`gh secret set --repo`로 한 번에 처리한다 — 스크립트 예시는 이 문서 맨 아래.

Apple Developer Program(연 $99) 멤버십 필요.

시크릿이 없으면 iOS 잡은 `flutter build ios --no-codesign`까지만 돌려서
**컴파일 깨짐은 잡아준다.**

#### Mac / Xcode 없이 iOS 배포하기

**이 프로젝트의 전제이고, 2026-07-19에 실제로 성립을 확인했다**(서명 IPA
아카이브까지 CI에서 통과). 빌드는 GitHub의 macOS 러너가 하므로 Mac은 필요 없고,
인증서·프로파일도 웹 콘솔 + OpenSSL로 만들 수 있다. Git for Windows에 딸려 오는
`C:\Program Files\Git\mingw64\bin\openssl.exe`를 그대로 쓰면 된다.

```powershell
# 1) 개인키 + CSR 생성 (Mac Keychain 대신 OpenSSL)
openssl genrsa -out ios_dist.key 2048
openssl req -new -key ios_dist.key -out ios_dist.csr `
  -subj "/emailAddress=jax1205@gmail.com/CN=Logan Land Distribution/C=KR"
#    ⚠️ Git Bash에서는 -subj 경로가 변환되므로 MSYS_NO_PATHCONV=1 을 앞에 붙일 것

# 2) developer.apple.com › Certificates → Apple Distribution → CSR 업로드
#    → distribution.cer 다운로드

# 3) .cer → .p12  ⚠️ 플래그 3개가 필수다 (아래 함정 참고)
openssl x509 -in distribution.cer -inform DER -out dist.pem -outform PEM
openssl pkcs12 -export -inkey ios_dist.key -in dist.pem -out ios_dist.p12 `
  -macalg sha1 -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES

# 4) base64로 인코딩해 시크릿에 등록
[Convert]::ToBase64String([IO.File]::ReadAllBytes("ios_dist.p12")) | Set-Clipboard
```

##### ⛔ 함정 1 — `.p12`를 OpenSSL 기본값으로 만들면 macOS가 못 읽는다

OpenSSL 3.x는 PKCS#12를 **AES-256 + SHA-256**으로 포장하는데, macOS의
`security import`는 이 형식을 파싱하지 못하고 하필

```
security: SecKeychainItemImport: The user name or passphrase you entered is not correct.
```

라는 **비밀번호가 틀렸다는 엉뚱한 오류**를 낸다. 비밀번호를 아무리 다시 넣어도
해결되지 않으므로, 인증서를 폐기·재발급하는 헛수고로 이어지기 쉽다(실제로 겪었다).

→ **반드시 `-macalg sha1 -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES`를 붙일 것.**

포맷 확인법(비밀번호 없이 가능). `sha1`이 나와야 정상, `sha256`이면 다시 만들어야 한다:
```powershell
openssl asn1parse -inform DER -in ios_dist.p12 | Select-String "OBJECT"
```

##### ⛔ 함정 2 — 시크릿 등록에 파이프(`|`)를 쓰지 말 것

PowerShell에서 `$pw | gh secret set ...` 하면 **줄바꿈이 값에 딸려 들어간다.**
그러면 서명이 실패하고, 더 나쁘게는 **GitHub의 시크릿 마스킹이 빗나가 로그에
비밀번호가 평문으로 찍힌다**(저장된 값과 사용된 값이 달라지기 때문). 실제로 한 번
노출되어 `gh run delete`로 실행 기록을 지워야 했다.

→ **`--body`를 쓸 것**: `gh secret set NAME --repo owner/repo --body $pw`

##### ⛔ 함정 3 — 배포 인증서는 계정당 2개가 상한

앱마다 따로 만들 수 없다. **하나로 통일해 세 앱이 공유**하는 것이 정상이다.
인증서를 폐기하면 **그것으로 만든 모든 프로파일이 즉시 Invalid**가 되므로,
폐기 시 세 앱 프로파일을 모두 재발급하고 각 리포 시크릿을 갱신해야 한다.

프로파일은 **어떤 인증서를 인정할지 생성 시점에 박아 넣고 나중에 못 바꾼다.**
`.p12`와 프로파일이 서로 다른 인증서를 가리키면 아카이브가 실패한다.

##### ⛔ 함정 4 — CI에는 개발용 인증서가 없다

CI는 배포용 인증서만 임포트하므로, 프로젝트가 자동 서명이면 flutter 툴이
개발용 인증서를 찾다가 `No valid code signing certificates were found`로 죽는다.
→ `ios/Flutter/Release.xcconfig`에 팀·프로파일·아이덴티티를 명시해 수동 서명으로
고정해 두었다. **프로파일 이름을 바꾸면 이 파일도 같이 고칠 것.**

⚠️ **Xcode 전용 작업이라 대신 처리해 둔 것**: `GoogleService-Info.plist`를
앱 번들에 넣는 설정을 `project.pbxproj`에 직접 등록했다(CI 빌드로 검증 완료).
자세한 건 `docs/FIREBASE.md` 1절.

⚠️ **아직 못 하는 것**: Game Center 엔타이틀먼트는 프로파일이 생긴 뒤에 넣어야
한다(`docs/FIREBASE.md` 5절).

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

| 항목 | 상태 (2026-07-19) |
|---|---|
| CI (analyze/test/web) | ✅ 동작 |
| **서명 AAB 빌드** | ✅ 검증 완료 (run 29684013621) |
| **서명 IPA 아카이브** | ✅ 검증 완료 (run 29687156452) |
| Play 업로드 | ⏳ **첫 AAB를 콘솔에서 수동 업로드**해야 API 업로드가 열림 |
| TestFlight 실업로드 | ⏳ `build_only` 끄고 실행하면 됨 |
| Firebase App Distribution | ⏳ 테스터 그룹 + FAD 시크릿 등록 후 |
| **애드몹 실 광고 ID** | ⛔ **정식 출시 이후에만 발급.** 지금은 테스트 유닛이 정답 |

---

## 부록 — 세 앱 iOS 시크릿 일괄 갱신 스크립트

인증서를 갱신했을 때 이걸 돌리면 세 리포가 한 번에 정리된다.

```powershell
$d = "D:\Downloads"
function B($p) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) }
$p12 = B "$d\ios-signing\ios_dist.p12"
$cer = B "$d\distribution.cer"
$key = B "$d\ios-signing\ios_dist.key"
$aa  = B "$d\comloganlandatlasarrows_AppStore.mobileprovision"
$hb  = B "$d\comloganlandhiddenblocks_AppStore.mobileprovision"
$apt = B "$d\AptNote_AppStore.mobileprovision"
$pw  = Read-Host "p12 비밀번호"

$AA="zeros1205/ATLASARROWS"; $HB="zeros1205/hiddenblocks"; $AP="zeros1205/KR_APT_DOC_READER"

gh secret set IOS_DIST_CERT_P12_BASE64        --repo $AA --body $p12
gh secret set IOS_DIST_CERT_PASSWORD          --repo $AA --body $pw
gh secret set IOS_PROVISIONING_PROFILE_BASE64 --repo $AA --body $aa
gh secret set IOS_PROVISIONING_PROFILE_NAME   --repo $AA --body "com.loganland.atlasarrows AppStore"

gh secret set IOS_DIST_CERT_BASE64            --repo $HB --body $p12
gh secret set IOS_DIST_CERT_PASSWORD          --repo $HB --body $pw
gh secret set IOS_PROVISION_PROFILE_BASE64    --repo $HB --body $hb

gh secret set IOS_CERTIFICATE_P12_BASE64      --repo $AP --body $p12
gh secret set IOS_CERTIFICATE_PASSWORD        --repo $AP --body $pw
gh secret set IOS_CERTIFICATE_CER_BASE64      --repo $AP --body $cer
gh secret set IOS_PRIVATE_KEY_BASE64          --repo $AP --body $key
gh secret set IOS_PROVISIONING_PROFILE_BASE64 --repo $AP --body $apt
gh secret set IOS_PROVISIONING_PROFILE_NAME   --repo $AP --body "AptNote AppStore"
```

⚠️ **`.p12`와 `.key`를 리포지토리 밖에 백업할 것.** 잃으면 인증서를 폐기하고
세 앱 프로파일을 전부 다시 발급해야 한다.
