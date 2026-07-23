# Firebase · Play Games Services · Game Center

리더보드/업적은 **Play Games Services(안드로이드)** 와 **Game Center(iOS)** 가
직접 처리한다. Firebase는 그 위가 아니라 옆에 있다 — App Distribution과
(선택) 계정 연동용이다.

## 설계 원칙 — 전부 "있으면 좋은 것"

게임 서비스는 **곁가지**다. 로그인을 거부했거나, 오프라인이거나, 콘솔 설정이
아직인 플레이어도 **완전히 동일한 게임**을 해야 한다. 그래서:

- `lib/services/game_services.dart` · `lib/services/firebase.dart` 의 모든 호출은
  실패를 삼킨다. 부팅을 막지 않고, 에러를 노출하지 않는다.
- `android/app/build.gradle.kts`는 `google-services.json`이 **있을 때만**
  google-services 플러그인을 적용한다. 없으면 그냥 Firebase 없이 빌드된다.
  (플러그인을 무조건 적용하면 파일이 없을 때 빌드가 통째로 깨진다.)
- 설정 화면의 리더보드/업적 행은 `GameServices.supported`일 때만 그려진다.

---

## 1. Firebase 프로젝트 (지금 바로 가능)

1. console.firebase.google.com → 프로젝트 생성
2. **Android 앱 추가** — 패키지명 `com.loganland.atlasarrows`
   → `google-services.json` 다운로드 → **`android/app/`** 에 배치
3. **iOS 앱 추가** — 번들 ID `com.loganland.atlasarrows`
   → `GoogleService-Info.plist` 다운로드 → **`ios/Runner/`** 에 배치

두 파일은 `.gitignore` 대상이다. 파일을 넣는 순간 gradle 플러그인이 자동으로
붙고 `FirebaseService.init()`이 성공한다. **코드 수정은 필요 없다.**

> **Xcode 없이 iOS를 쓰기 위한 처리 (이 프로젝트 상태)**
> 원래는 Xcode에서 plist를 Runner 타깃에 추가해야 앱 번들에 복사된다.
> Xcode를 못 쓰는 환경이라 **`project.pbxproj`를 직접 편집해 등록해 뒀다**
> (fileRef `A7F1B000…` + Resources 빌드 페이즈). 그러니 파일을 `ios/Runner/`에
> 두기만 하면 된다.
>
> ⚠️ **그 대가로, 이제 이 파일이 없으면 iOS 빌드가 실패한다** (Xcode가 참조된
> 리소스를 못 찾음). 그래서 CI 워크플로가 빌드 전에 시크릿에서 복원한다.

### CI로 설정 파일 전달 — base64 시크릿

리포에는 커밋하지 않기로 했으므로(사용자 결정), 두 파일을 시크릿으로 넣는다.

```powershell
# Windows에서 인코딩
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\google-services.json")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("ios\Runner\GoogleService-Info.plist")) | Set-Clipboard
```

| 시크릿 | 필수 여부 |
|---|---|
| `FIREBASE_ANDROID_CONFIG_BASE64` | 선택 — 없으면 Firebase 없이 빌드 |
| `FIREBASE_IOS_CONFIG_BASE64` | **필수** — 없으면 iOS 빌드 실패 |

⚠️ 콘솔에서 파일을 다시 받으면 **시크릿도 다시 등록**해야 한다.

> `flutterfire configure` / `firebase_options.dart`는 쓰지 않는다.
> 네이티브 설정 파일만으로 초기화하므로 생성 파일을 동기화할 일이 없다.

### App Distribution
Firebase 콘솔 › App Distribution → 테스터 그룹 `internal` 생성.
앱 ID(`1:...:android:...`)와 서비스 계정 JSON을 GitHub Secrets에 등록
(`docs/RELEASE.md`).

---

## 2. Play Games Services (Play Console 필요)

⚠️ **여기가 유일한 크래시 위험 지점이다.**

Play Games v2 SDK는 매니페스트의 `com.google.android.gms.games.APP_ID`를
**프로세스 시작 시** 읽고, 값이 없거나 잘못되면 **네이티브에서 크래시**한다.
Dart의 try/catch로 못 잡는다. 그래서 킬 스위치를 뒀다:

```dart
// lib/services/game_services.dart
static const bool androidConfigured = false;   // ← 설정 끝나면 true
```

`false`인 동안 안드로이드에서는 SDK를 아예 건드리지 않는다.

### 절차

1. Play Console › **Play 게임즈 서비스** › 설정 → 게임 생성
   (앱이 아직 미출시여도 **초안 상태로 가능**)
2. **프로젝트 ID**(숫자 12자리 정도)를 복사
3. `android/app/src/main/res/values/games_ids.xml`의 `games_app_id`를 그 값으로 교체
4. OAuth 동의 화면 구성 + **릴리즈 keystore의 SHA-1**로 자격증명 등록
   ```powershell
   keytool -list -v -keystore atlasarrows-release.jks -alias atlasarrows
   ```
5. **업적 11개(대륙 6 + 일반 5) · 리더보드 2개** — Play Games는 생성 API가 없어 **콘솔 Import**로 올린다:
   - `python3 tools/game_services/gen_pgs_import.py` (또는 GitHub Actions의
     **Play Games · Import Bundle** 워크플로 실행 → 아티팩트 다운로드)로
     `AtlasArrowsAchievementsImport.zip` / `...LeaderboardsImport.zip` 생성
   - Play Console ▸ Play Games Services ▸ 업적 ▸ **가져오기**로 업적 ZIP 업로드
     (리더보드 import 메뉴가 없으면 `LeaderboardsMetadata.csv` 값으로 2개 수동 생성)
   - 임포트 후 **콘솔이 발급한 `CgkI…` ID**를 `game_services.dart`의
     `_leaderboard*` / `_achievements`(android:)에 붙여넣는다
   - ⚠️ 업적/리더보드 아이콘은 **임시 플레이스홀더**(`tools/game_services/icons/`)다.
     실제 아트로 교체 후 재임포트하면 콘솔이 아이콘을 갱신한다.
6. ~~`androidConfigured = true`~~ — **완료(2026-07-20)**: 실 app id(182438652200)를
   `games_ids.xml`에 넣고 스위치를 켰다. 사인인은 이미 라이브고, 위 5번 ID만 채우면
   리더보드/업적 호출도 동작한다.

---

## 3. Game Center (App Store Connect 필요) — Xcode 없이

킬 스위치가 필요 없다. Game Center는 앱 단위 ID가 없고, 등록되지 않은
리더보드 ID로 호출하면 그냥 그 호출만 실패한다(우리는 삼킨다).

원래 절차는 "Xcode › Signing & Capabilities → Game Center 추가"인데, 그건
결국 **두 가지**를 하는 것뿐이다. 둘 다 Xcode 없이 가능하다:

1. **App ID에 Game Center 활성화** — developer.apple.com › Certificates,
   Identifiers & Profiles › Identifiers › `com.loganland.atlasarrows`
   → Game Center 체크 → Save.
   ⚠️ 활성화 후 **프로비저닝 프로파일을 재발급**받아야 반영된다
   (기존 프로파일은 무효화됨 → 시크릿도 재등록).
2. **엔타이틀먼트 파일** — `ios/Runner/Runner.entitlements`에
   `com.apple.developer.game-center`를 넣고 pbxproj의
   `CODE_SIGN_ENTITLEMENTS`로 연결. 이건 **아직 안 해 뒀다**(아래 5절 참고).
3. App Store Connect › 앱 › **Game Center** → 리더보드/업적 생성
4. 거기서 정한 ID를 `game_services.dart`의 `ios:` 필드에 반영

---

## 4. 현재 정의된 ID

콘솔에서 만들 때 이 이름으로 맞추면 코드 수정이 최소화된다.
안드로이드 ID는 콘솔이 발급하는 값이라 **반드시 교체**해야 한다.

**리더보드**
| 키 | 의미 |
|---|---|
| stages | 클리어한 총 스테이지 수 |
| countries | 완주한 국가 수 |

**업적 — 일반 5개**
| 키 | 조건 |
|---|---|
| `first_clear` | 첫 스테이지 클리어 |
| `first_country` | 첫 국가 완주 |
| `stages_50` | 50 스테이지 |
| `stages_250` | 250 스테이지 |
| `flawless` | 하트를 하나도 잃지 않고 클리어 |

**업적 — 대륙 완주 6개** (`_continentAchievements`, `bank.json`의 `continent` 문자열이 키)
| 대륙 | 국가 수 |
|---|---|
| Europe | 50 |
| Asia | 52 |
| Africa | 55 |
| North America | 31 |
| South America | 13 |
| Oceania | 15 |

국가 수는 `tools/game_services/gen_pgs_import.py`의 업적 설명 문구에 박혀 있다 — 캠페인
데이터가 바뀌면 그 스크립트도 같이 갱신해야 문구가 안 어긋난다.

⚠️ **iOS ID는 이미 코드에 확정돼 있다** — `game_services.dart`의 `ios:` 필드
(`atlsars.leaderboard.stages/countries`, `atlsars.achievement.first_clear` 등 11개)를
**그대로** App Store Connect › Game Center에 입력하면 된다. 콘솔에서 새로 짓지 말 것.
Android는 반대로 `CgkI_atlsars_*`가 전부 **플레이스홀더**라, 5번 절차대로 Play Console
Import를 거쳐 받은 진짜 `CgkI…` 값으로 교체해야 한다.

제출 시점은 `game_screen.dart`의 `_reportToGameServices()` — 스테이지 진행 시
fire-and-forget으로 보낸다.

---

## 5. 아직 안 한 것 (의도적)

- **iOS Game Center 엔타이틀먼트**: `Runner.entitlements` 생성 + pbxproj 연결은
  하지 않았다. 지금 넣으면 **엔타이틀먼트를 지원하지 않는 프로비저닝
  프로파일로 서명할 때 빌드가 실패**하는데, Apple Developer 계정과 프로파일이
  아직 없어서 순서가 맞지 않는다. 위 3절 1번(App ID에서 Game Center 활성화 +
  프로파일 재발급)을 먼저 하고, **그 다음** 엔타이틀먼트를 추가해야 한다.
  → 계정이 준비되면 말해 주면 그때 넣는다.
- **iOS 수동 서명 전환**: 프로젝트가 `CODE_SIGN_STYLE = Automatic`이다. CI는
  수동 프로파일로 export하므로, 실제 첫 아카이브에서 조정이 필요할 수 있다.
  프로파일이 생겨야 검증 가능한 항목이라 미리 건드리지 않았다.

- **Firebase Auth ↔ Play Games 계정 연동**: `firebase_auth`는 의존성만 넣어
  뒀다. 실제 연동은 `GameAuth.getAuthCode()`로 server auth code를 받아
  Firebase 자격증명으로 교환하는 흐름인데, 이걸 붙이려면 **클라우드 저장
  스펙**(무엇을 언제 어느 쪽으로 동기화할지, 충돌 시 누가 이기는지)이 먼저
  정해져야 한다. 진행도는 지금 `shared_preferences` 로컬 저장이다.
- **웹 Firebase**: 네이티브 설정 파일 방식이라 웹은 초기화하지 않는다.
  필요해지면 그때 웹 옵션을 넣는다.
