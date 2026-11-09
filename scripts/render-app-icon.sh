#!/bin/bash
# design/app-icon.svg から iPhone / Watch の AppIcon (1024x1024 PNG・アルファなし) を作り直す。
# 使い方: scripts/render-app-icon.sh
# 必要なもの: Google Chrome (SVG の描画) と ImageMagick (アルファの除去)
set -euo pipefail
cd "$(dirname "$0")/.."
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
tmp=$(mktemp -d)
trap 'rm -r "$tmp"' EXIT
cat > "$tmp/icon.html" <<HTML
<!doctype html><html><body style="margin:0"><img src="file://$PWD/design/app-icon.svg" style="display:block;width:1024px;height:1024px"></body></html>
HTML
"$chrome" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
  --force-device-scale-factor=1 --window-size=1024,1024 \
  --screenshot="$tmp/raw.png" "file://$tmp/icon.html" 2>/dev/null
# App Store はアルファ付きのアイコンを弾くので外す
magick "$tmp/raw.png" -background black -alpha remove -alpha off "$tmp/icon.png"
for dir in WatchHook/Assets.xcassets/AppIcon.appiconset WatchHookWatch/Assets.xcassets/AppIcon.appiconset; do
  cp "$tmp/icon.png" "$dir/AppIcon.png"
done
echo "OK: $(magick identify -format '%wx%h %[channels]' "$tmp/icon.png")"
