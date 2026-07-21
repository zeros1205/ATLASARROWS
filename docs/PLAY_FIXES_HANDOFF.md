# 플레이 화면 수정 — 터미널 세션 인계 (PR #15)

> 이 문서는 **로컬 터미널 Claude 세션**이 폰을 연결하고 이어받아 검증·완결하기 위한 인계문이다.
> 클라우드 세션엔 Flutter 툴체인·adb·실기기가 없어 **컴파일/실기기 검증을 못 했다.**
> 여기 적힌 두 이슈를 **폰으로 확인하며** 마무리할 것.

## 0. 지금 브랜치 상태

- 브랜치 `claude/app-ui-polish-kb7jw3`, **PR #15**(open, draft). 두 커밋이 들어 있다:
  1. `game_screen.dart` — 보드 팬 클램프(`_clampBoard`)
  2. `line_component.dart` — 탈출 광선을 캔버스 끝까지 확장(`_extendExitOffScreen`)
- ⚠️ **둘 다 의도를 완전히 반영하지 못했다.** 아래 리뷰대로 고쳐야 한다.

## 1. 리뷰 결론 (무엇이 왜 부족한가)

### 이슈 A — 팬 클램프가 "격자 기준"이 아니라 "뷰포트 기준"이다 ❌

- 사용자 지시: **격자(화살이 있는 셀 영역) 끝선**이 화면 중앙을 넘지 않게. 예) 오른쪽으로 밀어도 퍼즐 좌측 끝이 화면 중앙에서 멈춰야 함.
- 현재 `_clampBoard`는 뷰포트를 꽉 채우는 **child(GameWidget) 가장자리**(`s * v.width/height`)로 막는다.
- 그런데 격자는 `_fitScale`의 **0.94 여백 + 레터박스**로 child 안쪽에 인셋돼 있다:
  - 가로: 격자가 중앙을 ~3% 더 넘어감(경미).
  - **세로(레터박스 축): 격자가 중앙을 20~30% 넘어갈 수 있음(명백한 위반).**
- **고칠 방법:** 격자 실측 rect 기준으로 클램프.
  - `ZArrowsGame`에 보드 콘텐츠 rect(캔버스 좌표)를 노출:
    `Rect.fromCenter(center: size/2, width: board.size.x*_fitScale, height: board.size.y*_fitScale)`.
  - `_clampBoard`에서 그 rect를 IV 변환(scale s, translate t)으로 매핑해, **rect 가장자리**가 뷰포트 중앙(`Wv/2`,`Hv/2`)을 넘지 않게:
    - `minTx = Wv/2 - s*rect.right`, `maxTx = Wv/2 - s*rect.left` (세로도 동일).

### 이슈 B — 탈출 화살의 "상/하"가 헤더·크롬 밑이 아니다 △

- 사용자 지시: 좌·우·하단 → **스크린 밖**, 상단 → **헤더 밑으로 들어가** 사라짐, 하단도.
- 현재 수정은 광선을 **Flame 캔버스(플레이 영역) 끝**까지 뻗는다. 레이아웃이
  `헤더 → divider → 하트 스트립 → [Expanded=플레이 영역] → 부스터바 → 배너` 라서:
  - **좌/우:** 플레이 영역 좌우 = 화면 좌우 끝 → 스크린 밖 ✓ **맞음.**
  - **상단:** 플레이 영역 top은 **하트 스트립 아래**다(헤더 바로 밑이 아님). 위로 쏜 화살은 하트 스트립 밑에서 사라짐 → "헤더 밑"과 다름. ✗
  - **하단:** 부스터바 위에서 사라짐 → 진짜 화면 밖 아님. △
- **결정 필요 (사용자 확인 대기 중):**
  - (A) 지금처럼 **플레이 영역 경계에서 사라짐**으로 만족 — 구조 변경 없음.
  - (B) **진짜 헤더/부스터바 밑으로 슬라이드-언더**(하단은 화면 끝까지) — 게임 렌더 표면을
    전체 화면으로 확장하고 헤더·하트·부스터바를 그 위에 겹쳐 그려야 함. 탭 좌표(`tapAtScene`)·
    `ClipRect`·레이아웃 재작업 수반.
  - → **폰에서 A를 먼저 눈으로 보고**, B가 필요하면 그때 구조 변경.

## 2. 폰 검증 루프 (adb 하네스)

스크립트: `tools/verify/play_probe.sh` (Git Bash에서 리포 루트에서 실행).

```bash
# 1) 설치 + 실행
./tools/verify/play_probe.sh install

# 2) 플레이 화면 진입 (앱에서 시작/이어서 플레이 탭, 또는:)
./tools/verify/play_probe.sh unlock 40   # 디버그 진행도 점프 후 재실행→이어서

# 3) 팬 클램프 확인 — 화면 크기 보고, 밀고, 스샷
./tools/verify/play_probe.sh size
./tools/verify/play_probe.sh swipe right && ./tools/verify/play_probe.sh shot pan_right
./tools/verify/play_probe.sh swipe up    && ./tools/verify/play_probe.sh shot pan_up
#   → 스샷에서 격자 끝선이 화면 중앙을 넘는지 픽셀로 확인(넘으면 이슈 A 미해결).

# 4) 탈출 화살 확인 — 화살 하나를 탭해 발사, 프레임 추출
./tools/verify/play_probe.sh fire 540 1100 escape   # X Y는 화살 위 좌표
#   → out/escape_f*.png 프레임에서 화살이 화면 밖/헤더 밑까지 가는지 확인.
```

- 산출물은 `tools/verify/out/`(gitignore 대상 — 커밋 금지).
- `fire`는 ffmpeg로 프레임을 뽑는다(없으면 mp4만 pull).
- 스샷은 `adb pull`로만(‛>’ 리다이렉션은 Windows에서 PNG를 깨뜨림), /sdcard 경로는 `MSYS_NO_PATHCONV=1`.

## 3. 마무리 순서 (권장)

1. `install` → 플레이 진입.
2. **이슈 A**: swipe+shot로 격자 초과 확인 → 격자 rect 기준 클램프로 고치고 재확인.
3. **이슈 B**: fire로 상/하 도달점 확인 → 사용자와 A/B 결정 → 반영.
4. `dart analyze` · `flutter test` 그린 확인(클라우드 세션이 못 한 부분).
5. 커밋·푸시 → PR #15 갱신.

## 4. 참고

- 앱 패키지 `com.loganland.atlasarrows`, 디버그 APK `build/app/outputs/flutter-apk/app-debug.apk`.
- 좌표는 물리 픽셀(`adb shell wm size`). 앱은 논리 dp지만 드래그/탭엔 물리 픽셀로 충분.
- 진행도 점프·경로 함정 등은 `docs/HANDOFF.md` 4장 참고.
