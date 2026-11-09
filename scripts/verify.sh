#!/bin/bash
# 確認の入口。
#   scripts/verify.sh         速い段: Core の単体テスト (swift test、macOS 上で数秒〜数十秒)
#   scripts/verify.sh --full  重い段: 上に加えて xcodegen で作り直したプロジェクトが最新か + iOS / watchOS のシミュレータ向けビルド
set -euo pipefail
trap 'exit 130' INT
cd "$(dirname "$0")/.."

full=0
for a in "$@"; do
  case "$a" in
    --full) full=1 ;;
    *) echo "unknown argument: $a" >&2; exit 2 ;;
  esac
done

missing=()
command -v swift >/dev/null || missing+=("swift (Xcode)")
if [ "$full" = 1 ]; then
  command -v xcodegen >/dev/null || missing+=("xcodegen (brew install xcodegen)")
  command -v xcodebuild >/dev/null || missing+=("xcodebuild")
fi
if [ ${#missing[@]} -gt 0 ]; then
  printf '前提が足りません: %s\n' "${missing[@]}" >&2
  exit 1
fi

echo "== Core の単体テスト"
(cd Packages/WatchHookCore && swift test)

[ "$full" = 1 ] || exit 0

echo "== project.yml とプロジェクトの一致"
xcodegen generate --quiet
if ! git diff --quiet -- WatchHook.xcodeproj; then
  echo "WatchHook.xcodeproj が project.yml と一致しません。xcodegen generate の結果をコミットしてください" >&2
  exit 1
fi

echo "== iOS + watchOS のビルド"
heavy="$HOME/bin/heavy"
[ -x "$heavy" ] || heavy=""
$heavy xcodebuild -project WatchHook.xcodeproj -scheme WatchHook \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build -quiet
echo "OK"
