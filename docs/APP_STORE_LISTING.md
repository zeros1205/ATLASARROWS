# App Store Connect 입력 정보 — Atlas Arrows

> `docs/PLAY_STORE_LISTING.md`의 iOS/Apple 버전. 마케팅 카피는 최대한 공유하고,
> Apple 고유 필드(서브타이틀·키워드·연령 등급·앱 개인정보 라벨 등)만 여기 정리했다.
> 인증서·프로파일·keystore 같은 CI/서명 시크릿은 `docs/RELEASE.md` 참고 —
> 여기는 **App Store Connect 웹 콘솔에 직접 입력하는 값**만 다룬다.

---

## 0. 선행 조건 확인

| 항목 | 상태 |
|---|---|
| Apple Developer Program 멤버십(연 $99) | 이미 있음(팀 ID `9YM6784Y87` 사용 중, TestFlight 서명 성공 이력) |
| App Store Connect에 **앱 레코드 생성** | ⚠️ **미확인.** 인증서·프로파일은 TestFlight 배포용으로 이미 만들어져 있지만,
그것과 "My Apps › +"로 앱 자체를 등록하는 것은 별개 절차다. 스토어 등록정보 입력 화면은
앱 레코드를 만들어야 나타난다. |
| 개인정보처리방침 URL | ✅ 라이브 — `https://atlasarrows.loganland.app/privacy/` (`docs/PLAY_STORE_LISTING.md` 0번 항목 참고) |
| 라이선스 계약(EULA, 선택) | 기본 Apple 표준 EULA 대신 커스텀을 쓰려면 `https://atlasarrows.loganland.app/terms/` 사용 가능 |

**앱 레코드를 아직 안 만들었다면 먼저 할 것**: App Store Connect › 나의 앱 › **+** →
플랫폼 iOS, 이름 `Atlas Arrows: Tap Puzzle`, 기본 언어 한국어, 번들 ID
`com.loganland.atlasarrows` 선택(이미 Identifiers에 등록돼 있어야 목록에 뜬다), **SKU**
입력(스토어에 노출 안 되는 내부 식별자 — 아래 참고).

---

## 1. 앱 정보 (App Information)

| 항목 | 값 |
|---|---|
| 이름 (30자 이하) | `Atlas Arrows: Tap Puzzle` (24자) |
| 서브타이틀 (30자 이하) | `화살 퍼즐을 탭하고, 세계를 탐험하세요.` (22자, 2차 개정 — "Atlas Arrows" 브랜드명의 "atlas(지도책)"와 운을 맞춘 EN 버전과 짝. 아래 §2 참고) |
| SKU (내부 식별자, 비공개) | `atlasarrows-ios-001` (임의값 — 한 번 정하면 이후 앱 레코드 자체는 안 바뀌지만 통일성을 위해 이 값 권장) |
| 기본 언어 | 한국어 |
| 번들 ID | `com.loganland.atlasarrows` |
| 카테고리(주) | 게임(Games) → 퍼즐(Puzzle) |
| 카테고리(부, 선택) | 지정 안 함 |
| 저작권 | `© 2026 Logan Land` |
| 콘텐츠 권리 | "제3자 콘텐츠 포함" **아니오** — 모든 지도/보드 데이터는 빌드 타임에 자체 가공한 것으로, 앱 내에서 제3자 콘텐츠를 실시간으로 표시하지 않음 |

---

## 2. 스토어 등록정보 텍스트 (버전별 입력)

> ⚠️ **2026-07-24 개정** — 기존 서브타이틀/프로모션 텍스트에 있던 "점묘"라는 미술 용어가
> 후킹력이 없다는 지적에 따라, 동종 앱(Arrow Puzzle: Tap Away, Arrows – Puzzle Escape,
> Arrow Jam! 등) 스토어 문구를 분석해 다시 썼다. 동종 앱들은 하나같이 "relaxing",
> "no timer, just your brain", "탭·생각·탈출" 같은 두뇌 트레이닝/무압박 톤을 쓰지만,
> **진짜 국가 실루엣이 판이 된다는 것**(가상 미로가 아니라)은 저희만의 차별점이라 이걸
> 전면에 세웠다. 화살표 생김새(꺾인 선) 얘기는 여전히 제목·서브타이틀엔 넣지 않고
> §2 하단 설명 예시의 차별점 문장에만 남긴다(CLAUDE.md 명명 규칙 그대로 유지).
>
> **2차 개정(같은 날)** — 서브타이틀을 브랜드명 "Atlas Arrows"의 "atlas(지도책)"와
> 운을 맞춘 문구로 교체: EN `Tap arrows, tour the atlas.` / KO `화살 퍼즐을 탭하고,
> 세계를 탐험하세요.` — 사용자 제시안. 브랜드명을 서브타이틀 안에서 다시 상기시키는
> 동시에 세계 탐험 컨셉을 훅으로 쓴다. 나머지 5개 언어는 같은 "atlas" 말장난 구조로
> 대응 번역(예: DE `Pfeile tippen, Atlas erkunden.`) — 전체는
> `docs/APP_STORE_LISTING_I18N.md` 참고.

| 항목 | 값 |
|---|---|
| 프로모션 텍스트 (170자 이하, **심사 없이 수시 수정 가능**) | 아래 참고 (89자) |
| 설명 (4,000자 이하) | `docs/PLAY_STORE_LISTING.md` §1의 전체 설명과 **동일 텍스트 재사용** |
| 키워드 (100자 이하, 쉼표 구분·공백 없이) | 아래 참고 (39자) |
| 지원 URL(필수) | `https://atlasarrows.loganland.app/#support` (라이브) |
| 마케팅 URL(선택) | `https://atlasarrows.loganland.app` (라이브) |
| 저작권 표시가 있는 스크린샷 문구 | 해당 없음 |

### 프로모션 텍스트 (89자)

```
실제 나라 모양이 퍼즐 판이 되는 유일한 화살표 게임. 타이머도 인터넷도 필요 없이 언제 어디서든 한 판. 막히면 힌트, 급하면 제거 아이템으로 가볍게 클리어.
```

### 키워드 (39자)

```
퍼즐,화살표퍼즐,탈출게임,두뇌트레이닝,세계지도,캐주얼,오프라인,로직게임
```

> 설명 본문은 Play용과 동일한 걸 그대로 쓴다 — 차별점 문장("한 칸짜리 타일이 아니라
> 여러 칸을 꺾어 이은 선")도 그대로 유지할 것. 스토어별로 다른 얘기를 하면 안 된다.
> 단, 이번 개정으로 **차별점 문단을 설명 맨 앞으로 옮겼다**(후킹은 첫 문장에서 끝나야
> 함) — 최신 본문은 `docs/PLAY_STORE_LISTING.md` §1 참고.

---

## 3. 연령 등급 (Age Rating)

Apple 설문(폭력·공포·도박·마약/술/담배·성적 콘텐츠·비속어·미검수 웹 접근 등) 예상 답변은
전부 **"없음/아니오"** — 지도 위 화살표 퍼즐이라 해당 사항 없음. 인앱 구매나 광고 존재
자체는 연령 등급에 영향 없음(각각 별도 항목으로 스토어에 표시됨).

→ 예상 등급: **4+** (Play의 "전체 이용가"에 대응하는 Apple 최저 등급)

---

## 4. 앱 개인정보 (App Privacy — "Nutrition Label")

`docs/PLAY_STORE_LISTING.md`의 데이터 보안 표와 같은 사실관계를 Apple 카테고리 이름으로:

| Apple 데이터 유형 | 수집 | 사용자와 연결 | 추적(Tracking) 사용 | 용도 |
|---|---|---|---|---|
| 식별자 — 기기 ID(IDFA) | 예 | 아니오 | **예**(AdMob 광고) | 타사 광고 |
| 구매 내역 | 예 | 아니오 | 아니오 | 앱 기능(App Store 결제 경유) |
| 진단 — 충돌 데이터 | 예 | 아니오 | 아니오 | 앱 기능/분석(Sentry) |
| 연락처 정보·위치·건강 등 그 외 전부 | 수집 안 함 | — | — | — |

"추적에 사용됨" 응답이 하나라도 **예**이면 **App Tracking Transparency(ATT) 프롬프트가
필수**다 — 아래 5번 항목 참고.

---

## 5. ⚠️ 코드 갭 — ATT 미구현 (정보 정리 범위 밖, 참고용 플래그)

`site/index.html`의 개인정보처리방침 4번 항목은 "iOS에서는 App Tracking Transparency
프롬프트로 동의한 경우에만 개인 맞춤 광고를 보여준다"고 이미 약속하고 있는데,
현재 코드에는:

- `pubspec.yaml`에 `app_tracking_transparency` 패키지가 없음
- `ios/Runner/Info.plist`에 `NSUserTrackingUsageDescription` 키가 없음

→ **ATT를 실제로 호출하지 않는 상태**다. 이대로 iOS에 제출하면 (a) 앱 개인정보 라벨에서
"추적에 사용됨"으로 신고했는데 ATT 프롬프트가 없어 정책 위반으로 반려되거나, (b) 반대로
ATT 없이 IDFA를 아예 안 읽도록 AdMob을 논타기팅 모드로 강제해야 한다. 둘 중 하나를
출시 전에 정해서 구현해야 한다 — 이번 "정보 정리" 작업 범위 밖이라 코드는 건드리지
않았고, 여기 플래그만 남긴다. (Android도 동일한 성격의 갭이 있다 — EU 사용자 동의(UMP)
미구현, Play 문서 §7 참고.)

---

## 6. 수출 규정 준수 (Export Compliance)

- 앱이 암호화를 사용하는가? → **예**(표준 HTTPS만 사용)
- 프랑스·표준 암호화 예외 대상인가? → **예**(표준/공개 알고리즘만 사용, 자체 암호화 없음)
→ 매 빌드 업로드마다 이 질문에 수동 응답하지 않으려면 `ios/Runner/Info.plist`에
`ITSAppUsesNonExemptEncryption`을 `false`로 미리 넣어두는 걸 권장(선택 사항 — 지금
코드에는 없음).

---

## 7. 가격 및 제공 범위

| 항목 | 값 |
|---|---|
| 가격 | 무료 |
| 제공 국가 | 전체(가정 — Play와 동일) |
| Family Sharing | 인앱 구매 4종 모두 허용 여부 결정 필요 — 소모성(힌트·제거)은 어차피 Family Sharing 대상 아님, 비소모성인 `atlsars_remove_ads`만 해당. 특별한 이유 없으면 **허용** 권장 |

---

## 8. 인앱 구매 (In-App Purchases)

**Play와 완전히 동일한 상품 ID를 그대로 재사용**(스토어별로 ID가 달라야 할 이유 없음 —
`in_app_purchase` 플러그인이 두 스토어에 같은 문자열로 질의한다):

| 상품 ID | 유형(ASC) | 참조 이름(내부용) | 표시 이름 | 설명 |
|---|---|---|---|---|
| `atlsars_hints_10` | 소모성(Consumable) | Hints 10 | 힌트 10개 | 막힌 화살표의 탈출 경로를 자동으로 찾아주는 힌트 10회분 |
| `atlsars_hints_50` | 소모성(Consumable) | Hints 50 | 힌트 50개 | 막힌 화살표의 탈출 경로를 자동으로 찾아주는 힌트 50회분 |
| `atlsars_removes_5` | 소모성(Consumable) | Removes 5 | 제거 아이템 5개 | 원하는 화살표 하나를 즉시 제거할 수 있는 아이템 5회분 |
| `atlsars_remove_ads` | 비소모성(Non-Consumable) | Remove Ads | 광고 제거 | 배너·전면 광고를 영구히 제거 (보상형 광고는 유지) |

가격 등급은 콘솔이 지역별 자동 산정 — Play 문서와 동일하게 별도 입력값 없음.

---

## 9. Game Center

`lib/services/game_services.dart`에 **iOS ID가 이미 코드로 확정**돼 있다 — App Store
Connect에서 새로 짓지 말고 **이 문자열을 그대로** 리더보드/업적 ID에 입력할 것
(자세한 배경은 `docs/FIREBASE.md` 3~4절):

**리더보드 2개**
| ID | 표시 이름 |
|---|---|
| `atlsars.leaderboard.stages` | 클리어한 스테이지 수 |
| `atlsars.leaderboard.countries` | 완주한 국가 수 |

**업적 5개** — 지금 등록할 것

| ID | 조건 |
|---|---|
| `atlsars.achievement.first_clear` | 첫 스테이지 클리어 |
| `atlsars.achievement.first_country` | 첫 국가 완주 |
| `atlsars.achievement.stages_50` | 50 스테이지 클리어 |
| `atlsars.achievement.stages_250` | 250 스테이지 클리어 |
| `atlsars.achievement.flawless` | 하트를 하나도 잃지 않고 클리어 |

⚠️ **대륙 완주 업적 6개(`atlsars.achievement.europe` 등)는 이번 등록에서 제외** —
`game_services.dart`에 ID·`_continentAchievements` 매핑은 있지만, 이걸 채워야 할
**대륙별 스탬프·칭호 부여 자체가 아직 미구현**이다: 앱이 읽는 `bank.json`의
`continent` 필드가 비어 있고(`docs/WORLDMAP_PLAN.md` §2.2), 대륙 스탬프를 캠페인
진행 순서와 어떻게 맞물릴지도 아직 결정 전이다(`docs/WORLDMAP_PLAN.md` §4, 옵션
A/B/C 미확정). 즉 등록해도 영구히 잠금 해제될 수 없는 업적이라 지금은 스킵 —
대륙 스탬프 기능이 실제로 구현된 뒤 별도로 등록한다.

⚠️ **Game Center 자체가 아직 앱에서 동작하지 않는다** — `docs/FIREBASE.md` 5절 대로
App ID에 Game Center capability 활성화 + 프로비저닝 프로파일 재발급 + 엔타이틀먼트
파일 추가가 먼저 필요하다(계정 순서 문제로 미룸). 리더보드/업적 텍스트만 지금 등록해
둬도 무방하지만, 실제로 점수가 쌓이는 건 그 작업 이후다.

---

## 10. 그래픽 자산 (제작은 출시 준비 시점 — Play와 동일 원칙)

| 자산 | 규격 |
|---|---|
| 앱 아이콘 | 1024×1024 PNG, 알파 없음, 둥근 모서리 없이 정사각형 원본 (`flutter_launcher_icons`가 `remove_alpha_ios: true`로 이미 대응) |
| iPhone 스크린샷 | 6.9" 필수(1320×2868 또는 2868×1320), 6.5"·5.5"는 선택(레거시 기기 노출용) |
| iPad 스크린샷 | Info.plist가 iPad 방향을 전부 선언하고 있어 **유니버설 앱** — 13" iPad(2064×2752) 스크린샷도 필요 |
| 프로모션 동영상 | 선택 |

---

## 11. 요약 — Play와 다른 점만 짚으면

- 등급 문항 형태는 다르지만 결과는 같다(4+ ≈ 전체 이용가).
- 개인정보 라벨(App Privacy)은 Play의 데이터 보안 폼과 사실관계 동일, 표기 방식만 Apple식.
- **Game Center ID는 이미 코드에 있다** — Play의 리더보드 ID(`CgkI_atlsars_*`)와 반대로
  콘솔에서 값을 받아오는 게 아니라 이 문서의 ID를 그대로 입력하면 끝.
- ATT 미구현 갭(5번)은 Android의 UMP 갭과 **같은 종류의 문제**이니 한 번에 같이 고치는
  걸 권장(별도 작업으로 요청 시 진행).
