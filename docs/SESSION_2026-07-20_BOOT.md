# 세션 인수인계 — 콜드스타트 + 스탬프 배포 (2026-07-20)

FAD 배포 성공: **0.1.0 (25)** · internal 그룹
`https://console.firebase.google.com/project/atlasarrows-7a720/appdistribution`

---

## 1. 다음에 할 일 — 딱 두 개

### 1.1 ⛔ Storage 버킷 만들기 (콘솔에서 한 번 클릭)

빌링은 Blaze로 켜져 있다(`billingEnabled: True`). 그런데 **버킷이 아직 없다.**
`.firebasestorage.app` 도메인은 Firebase가 소유해서 gcloud로는 못 만든다:

```
ERROR 403: Another user owns the domain atlasarrows-7a720.firebasestorage.app
```

→ 콘솔에서 **Storage → 시작하기**를 한 번 눌러야 한다.
위치는 `asia-northeast3`(서울) 권장. **한 번 정하면 못 바꾼다.**

https://console.firebase.google.com/project/atlasarrows-7a720/storage

그다음:

```bash
python tools/atlas/build_stamp_packs.py   # 대륙별 zip + 매니페스트
bash  tools/atlas/upload_stamp_packs.sh   # 업로드 + storage.rules 배포
```

버킷이 생기기 전까지 앱의 `StampStore`는 **조용히 실패하고 넘어간다**(설계대로).
스탬프만 안 뜨고 게임 진행은 정상이다.

### 1.2 ⚠️ 스탬프 배포 방식이 두 갈래로 갈려 있다 — 정리 필요

같은 시각에 두 방향이 들어갔다:

| | 내 커밋 `89c7dff` | 사용자 커밋 `7a22cee` |
|---|---|---|
| 스탬프 위치 | **번들에서 제거**, Firebase Storage에서 대륙별 다운로드 | `assets/images/stamps/`에 WebP로 **동봉** |
| 원본 1024 PNG | 언급 없음 | `tools/atlas/stamps_raw/` (git-ignore) |
| 재인코딩 | `build_stamp_packs.py` (512px q85, zip으로 묶음) | `optimize_stamps.py` (512px q84, 개별 파일) |

**현재 실제 동작은 다운로드 방식이다** — `pubspec.yaml`의 `assets:`에서
`assets/images/stamps/`를 뺐기 때문에, `optimize_stamps.py`가 거기에 WebP를
만들어도 APK에 안 실린다.

지시가 "번들에 담지 말고 다운로드"였으므로 다운로드 쪽이 맞다고 보고 진행했다.
정리한다면 둘 중 하나:

- **다운로드 유지** → `optimize_stamps.py`는 `build_stamp_packs.py`와 겹치므로
  둘을 하나로 합치고, `assets/images/stamps/`는 중간 산출물 폴더로만 쓴다
- **동봉으로 회귀** → `pubspec.yaml`의 assets 주석을 되돌리고
  `lib/services/stamp_store.dart` · `storage.rules` · `firebase.json` 제거

---

## 2. 이번 세션에 들어간 것

### 2.1 LOGAN LAND 부트킷 적용 (`016eeb4`, `43ef275`)

`docs/LOGANLAND_BOOT_KIT.md` + `APP_WORDMARK_AND_LOADING.md` 규격대로.

```
네이티브 스플래시 #0D0D0D  →  LOGAN LAND 카드 1600ms  →  크림 로딩  →  홈
        (같은 색 점 아이콘)        (공용 LL 모노그램)      (0.65 인계)
```

- **구조가 바뀌었다.** `main()`이 `runApp` 전에 `await`하던 것을 전부 걷어냈다.
  안드로이드는 Flutter가 첫 프레임을 그리는 순간 네이티브 스플래시를 없애므로,
  그 `await`는 전부 OS 화면을 보는 시간이었다. 이제 `LoganLandBootGate`가
  먼저 그리고 초기화는 카드 뒤에서 돈다.
- 진행바는 **하나의 0→100 여정**. 게이트가 0→0.65, `BootScreen`이 0.65→1.
  두 구간이 **같은 위젯**을 그려서 인계에서 안 튄다.
- ⛔ `packages/loganland_boot/`는 **복사본이다. 거기서 고치지 말 것.**
  정본은 `zeros1205/loganland_flutter_kit` v1.0.0. 자세한 건 `VENDORED.md`.
  (킷 리포가 private이라 CI가 클론을 못 해서 복사해 왔다. 킷을 public으로
  바꾸거나 `KIT_TOKEN` 시크릿을 붙이면 git 의존성으로 되돌릴 수 있다.)

### 2.2 워드마크

`tools/atlas/build_wordmark.py`가 생성한다. 손으로 그리지 않는 이유는
로딩 화면이 락업을 **뷰포트 폭 기준**(`widthFactor 0.61`)으로 놓기 때문 —
투명 여백이 1px이라도 있으면 로고가 조용히 작아진다. 생성하면 타이트 크롭이
구조적으로 보장되고, `test/wordmark_test.dart`가 규격 이탈을 잡는다.

- Outfit ExtraBold · 1184×430 · 2.75:1 · ATLAS(`#00A19B`) / ARROWS(`#3A4A55`)
- 색은 **완성 PNG에서 역샘플링**해 `AppBrand`에 상수화. 에셋이 정본이다.

**남은 것:** 두 줄 자간이 다르다(ATLAS 0.22 / ARROWS 0.04). 폭을 맞추려고
그렇게 잡았는데 위줄은 "자간 넓은 디스플레이", 아래줄은 "붙은 로고체"로
읽힌다. HIDDEN BLOCKS는 두 줄 다 넓다. 통일하려면 두 값을 중간에서 만나게.

### 2.3 진행바 트랙 색 (`23e8857`)

킷 기본 트랙 `#6E6961`은 민트와 **명도가 아니라 색상으로만** 갈려서 1.70:1이었다.
문서는 트랙을 밝히라고 권하지만 그건 accent가 회색조인 앱 이야기고, 이 민트에
적용하면 **1.15:1로 더 나빠진다**(직접 계산해 확인). 반대로 어둡게 —
락업 아래줄 `#3A4A55`로 갔다. **2.87:1**, 그리고 바가 로고의 두 색으로만 이뤄진다.

### 2.4 플레이 화면 헤더·하단 바 (`695a20b`)

- 이름이 `Expanded` 안에 있어서 "뒤로가기를 뺀 나머지의 중앙"이었다.
  `Stack`으로 바꿔 **전체 폭에 깔고 뒤로가기를 위에 얹었다.** 좌우 인셋 56 동일.
- 도시 스테이지 = 도시명 18/w600 + 국가명 16/w400 / 국가 스테이지 = 국가명 한 줄
- 하단 바: `[화면맞춤] [힌트][제거] [재시작]` — 유틸·부스터가 각각 같은 폭이라
  부스터 쌍이 화면 중앙선에 고정된다
- 재시작에 컨펌 다이얼로그 (실패 시트의 '다시 시작'은 이미 진 판이라 그대로)

### 2.5 ⛔ 워크플로 전부 dispatch 전용 (`df7d17e`, `17fa098`)

`firebase-distribution`이 **main 푸시마다** 돌고 있었다. 커밋을 저장하는 행위가
곧 테스터 배포였다. `android-play`/`ios-testflight`는 `v*` 태그마다.

**네 개 전부 `workflow_dispatch` 전용으로 바꿨다. 되살리지 말 것.**
상시로 도는 것은 로컬 `dart analyze` · `flutter test`뿐이다.

### 2.6 대륙 분류 정리

`Seven seas (open ocean)`은 대륙이 아니라 Natural Earth의 잔여 버킷이다.
들어있던 인도양 4곳을 실제 소속으로 흡수 → **6대륙**, 스탬프 에셋 6종과 일치.

| 국가 | 편입 |
|---|---|
| 세이셸 · 모리셔스 · 영국령 인도양 지역 | Africa (52 → 55) |
| 허드 맥도널드 제도 | Oceania (14 → 15) |

`docs/WORLDMAP_PLAN.md` 갱신 완료. `build_stamp_packs.py`도 같은 매핑을 쓴다.

---

## 3. 아직 안 한 것

- **실기기 확인.** 지시가 있어야 빌드하므로 안 했다. FAD 25번 빌드가 나가 있으니
  폰에서 받아 보면 된다. 볼 것: ①OS 스플래시→카드 흰 번쩍임 ②카드→로딩
  크로스페이드 ③0.65 인계에서 바가 안 튀는지 ④빠른 기기에서 바가 안 어는지
- **월드맵 구현.** `docs/WORLDMAP_PLAN.md` §4의 진행도 모델 A/B/C 결정 대기 중.
  A(순서 유지)가 아니면 `Progress.unlocked` 정수 하나로는 안 되고 저장 형식이 바뀐다.
- **도시 없는 국가 78개국의 path 보드.** 사용자가 `path_boards.json`으로 작업 중.
- iOS ad-hoc FAD: `FIREBASE_IOS_APP_ID` · `IOS_ADHOC_PROFILE_BASE64` 없어서 스킵됨.

---

## 4. 프리뷰

콜드스타트 4화면 렌더 + 대비 계산:
https://claude.ai/code/artifact/9e19580a-6b18-4c1e-9fbc-768d509d222b

대륙별 문제 현황:
https://claude.ai/code/artifact/b1c6c1cb-fca2-43be-8aeb-62a228e10e19
