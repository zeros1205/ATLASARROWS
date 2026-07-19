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
   (Xcode에서 Runner 타깃에 추가해야 번들에 포함된다)

두 파일은 `.gitignore` 대상이다. 파일을 넣는 순간 gradle 플러그인이 자동으로
붙고 `FirebaseService.init()`이 성공한다. **코드 수정은 필요 없다.**

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
5. 리더보드 2개 · 업적 5개 생성 → 발급된 ID를
   `game_services.dart`의 `_leaderboard*` / `_achievements`에 반영
6. **`androidConfigured = true`로 바꾼다 — 3·5번과 같은 커밋에서.**

---

## 3. Game Center (App Store Connect 필요)

킬 스위치가 필요 없다. Game Center는 앱 단위 ID가 없고, 등록되지 않은
리더보드 ID로 호출하면 그냥 그 호출만 실패한다(우리는 삼킨다).

1. Xcode › Runner › Signing & Capabilities → **Game Center** 케이퍼빌리티 추가
2. App Store Connect › 앱 › **Game Center** → 리더보드/업적 생성
3. 거기서 정한 ID를 `game_services.dart`의 `ios:` 필드에 반영

---

## 4. 현재 정의된 ID

콘솔에서 만들 때 이 이름으로 맞추면 코드 수정이 최소화된다.
안드로이드 ID는 콘솔이 발급하는 값이라 **반드시 교체**해야 한다.

**리더보드**
| 키 | 의미 |
|---|---|
| stages | 클리어한 총 스테이지 수 |
| countries | 완주한 국가 수 |

**업적**
| 키 | 조건 |
|---|---|
| `first_clear` | 첫 스테이지 클리어 |
| `first_country` | 첫 국가 완주 |
| `stages_50` | 50 스테이지 |
| `stages_250` | 250 스테이지 |
| `flawless` | 하트를 하나도 잃지 않고 클리어 |

제출 시점은 `game_screen.dart`의 `_reportToGameServices()` — 스테이지 진행 시
fire-and-forget으로 보낸다.

---

## 5. 아직 안 한 것 (의도적)

- **Firebase Auth ↔ Play Games 계정 연동**: `firebase_auth`는 의존성만 넣어
  뒀다. 실제 연동은 `GameAuth.getAuthCode()`로 server auth code를 받아
  Firebase 자격증명으로 교환하는 흐름인데, 이걸 붙이려면 **클라우드 저장
  스펙**(무엇을 언제 어느 쪽으로 동기화할지, 충돌 시 누가 이기는지)이 먼저
  정해져야 한다. 진행도는 지금 `shared_preferences` 로컬 저장이다.
- **웹 Firebase**: 네이티브 설정 파일 방식이라 웹은 초기화하지 않는다.
  필요해지면 그때 웹 옵션을 넣는다.
