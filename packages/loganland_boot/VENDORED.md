# 이 폴더는 복사본이다 — 여기서 고치지 말 것

정본: **[zeros1205/loganland_flutter_kit](https://github.com/zeros1205/loganland_flutter_kit)**
`packages/loganland_boot` · 태그 **v1.0.0**

## 왜 복사해 뒀나

킷 저장소가 private이라 GitHub Actions 러너가 `pub get` 단계에서 클론하지 못한다
(`fatal: could not read Username for 'https://github.com'`). 토큰을 심는 대신
복사본을 두기로 했다.

## 고쳐야 할 때

1. **킷 저장소에서** 고친다
2. 새 태그를 단다 (퍼블리셔 카드 규격 변경이면 major)
3. 이 폴더를 그 태그에서 다시 복사한다
4. `pubspec.yaml`의 주석에 적힌 태그를 갱신한다

여기서 직접 고치면 그 순간 Atlas Arrows의 LOGAN LAND가 다른 앱의 LOGAN LAND와
갈라진다. 킷이 존재하는 이유가 바로 그걸 막는 것이다.

## 되돌리는 방법

킷을 public으로 바꾸거나 `KIT_TOKEN` 시크릿을 붙이면 git 의존성으로 되돌릴 수 있다:

```yaml
loganland_boot:
  git:
    url: https://github.com/zeros1205/loganland_flutter_kit.git
    path: packages/loganland_boot
    ref: v1.0.0
```
