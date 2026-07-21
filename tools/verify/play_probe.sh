#!/usr/bin/env bash
# Play-screen verify harness for the pan-clamp / arrow-escape fixes (PR #15).
#
# Run from the repo ROOT in Git Bash (Windows) with a phone visible on
# `adb devices` (USB debugging on, device authorized). It builds the debug APK,
# drives the app with adb input, and pulls screenshots / recorded frames so a
# resumed Claude session can *see* the result and iterate.
#
# ⚠️ This machine has ★/한글 paths; /sdcard paths are guarded with
# MSYS_NO_PATHCONV=1 so Git Bash doesn't rewrite them. Screenshots are pulled
# (never `>`-redirected — that corrupts the PNG on Windows).
#
# Subcommands:
#   install          flutter build apk --debug + adb install -r + launch
#   size             print the device pixel size (to reason about coordinates)
#   shot NAME        screenshot -> tools/verify/out/NAME.png
#   swipe DIR [MS]   inject a long pan across the screen: right|left|up|down
#   tap X Y          tap at pixel X,Y (fire the arrow nearest there)
#   fire X Y NAME    record ~5s, tap X,Y after 1s, extract frames (needs ffmpeg)
#                    -> out/NAME_f001.png ...  (watch the arrow leave the screen)
#   unlock N         jump progress to global stage N (debug build only)
#
# Typical loop:
#   ./tools/verify/play_probe.sh install
#   # tap into a stage in the app (or: unlock N, then relaunch and Continue)
#   ./tools/verify/play_probe.sh size
#   ./tools/verify/play_probe.sh swipe right ; ./tools/verify/play_probe.sh shot pan_right
#   ./tools/verify/play_probe.sh fire 540 1100 escape_down
set -euo pipefail

PKG=com.loganland.atlasarrows
APK=build/app/outputs/flutter-apk/app-debug.apk
OUT="tools/verify/out"
mkdir -p "$OUT"

sd() { MSYS_NO_PATHCONV=1 adb "$@"; }        # keep /sdcard/... intact in Git Bash
dims() { adb shell wm size | sed 's/.*: //' | tr 'x' ' '; }

cmd_install() {
  flutter build apk --debug
  adb install -r "$APK"
  adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
  echo "installed + launched $PKG"
}

cmd_size() { adb shell wm size; }

cmd_shot() {
  local name="${1:?usage: shot NAME}"
  sd shell screencap -p /sdcard/_probe.png
  sd pull /sdcard/_probe.png "$OUT/$name.png" >/dev/null
  echo "$OUT/$name.png"
}

cmd_swipe() {
  local dir="${1:?usage: swipe right|left|up|down [ms]}"; local ms="${2:-600}"
  read -r W H < <(dims)
  local cx=$((W/2)) cy=$((H/2))
  case "$dir" in
    right) adb shell input swipe "$((W/6))"   "$cy" "$((W*5/6))" "$cy" "$ms";;
    left)  adb shell input swipe "$((W*5/6))" "$cy" "$((W/6))"   "$cy" "$ms";;
    up)    adb shell input swipe "$cx" "$((H*5/6))" "$cx" "$((H/6))"   "$ms";;
    down)  adb shell input swipe "$cx" "$((H/6))"   "$cx" "$((H*5/6))" "$ms";;
    *) echo "dir must be right|left|up|down" >&2; exit 1;;
  esac
  echo "swiped $dir (${ms}ms)"
}

cmd_tap() { adb shell input tap "${1:?x}" "${2:?y}"; echo "tapped $1 $2"; }

cmd_fire() {
  local x="${1:?x}" y="${2:?y}" name="${3:?name}"
  ( sd shell screenrecord --time-limit 5 /sdcard/_probe.mp4 ) &
  local rec=$!
  sleep 1
  adb shell input tap "$x" "$y"
  wait "$rec"
  sd pull /sdcard/_probe.mp4 "$OUT/$name.mp4" >/dev/null
  if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -loglevel error -i "$OUT/$name.mp4" -vf fps=15 "$OUT/${name}_f%03d.png"
    echo "frames: $OUT/${name}_f*.png"
  else
    echo "ffmpeg not on PATH — pulled $OUT/$name.mp4 (extract frames manually)"
  fi
}

# Debug-build progress jump. Global stage index; round boundaries follow
# build_bank.py output order (see docs/HANDOFF.md).
cmd_unlock() {
  local n="${1:?usage: unlock N}"
  local xml=shared_prefs/FlutterSharedPreferences.xml
  adb shell "run-as $PKG sh -c '
    f=$xml
    sed -i \"s#<int name=\\\"flutter.unlocked\\\" value=\\\"[0-9]*\\\" />#<int name=\\\"flutter.unlocked\\\" value=\\\"$n\\\" />#\" \$f 2>/dev/null || true
    grep flutter.unlocked \$f'"
  echo "set flutter.unlocked=$n (relaunch to take effect)"
}

sub="${1:?subcommand — see header}"; shift || true
case "$sub" in
  install) cmd_install ;;
  size)    cmd_size ;;
  shot)    cmd_shot "$@" ;;
  swipe)   cmd_swipe "$@" ;;
  tap)     cmd_tap "$@" ;;
  fire)    cmd_fire "$@" ;;
  unlock)  cmd_unlock "$@" ;;
  *) echo "unknown subcommand: $sub" >&2; exit 1 ;;
esac
