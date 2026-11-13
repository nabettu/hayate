#!/bin/bash
# TestFlight へアップロードする (xcodebuild archive → exportArchive の destination: upload)。
#
# 使い方:
#   scripts/testflight.sh            # project.yml の CURRENT_PROJECT_VERSION を build 番号にする
#   scripts/testflight.sh 7          # build 番号を指定する (project.yml は書き換えない)
#
#   build 番号は App Store Connect に上げたものと重ねられない。上げたら project.yml の
#   CURRENT_PROJECT_VERSION を次の番号にして xcodegen generate → コミットしておく。
#
# 設定 (環境変数、または scripts/testflight.env に KEY=VALUE で書く。testflight.env は git に入れない):
#   ASC_KEY_ID          App Store Connect API キーの Key ID
#   ASC_ISSUER_ID       同じキーの Issuer ID
#   ASC_KEY_PATH        同じキーの .p8 のパス (例: ~/.appstoreconnect/private_keys/AuthKey_XXXX.p8)
#   SIGNING_KEYCHAIN       (任意) 配布用の証明書を置いた keychain の名前。指定するとアンロックする
#   SIGNING_KEYCHAIN_PASS  (任意) その keychain のパスワード
#
# 署名の前提:
#   - export は manual signing。API キーにはクラウド署名の権限が無く、automatic だと export で落ちるため。
#   - 配布用の証明書 (iPhone Distribution / Apple Distribution) の秘密鍵がこの Mac の keychain にあること。
#   - 3 つの Bundle ID それぞれに App Store 用のプロファイルを、下の PROFILE_* の名前で発行しておく。
#     プロファイルはその証明書で作る。手元に無ければ -allowProvisioningUpdates と API キーで Xcode が取ってくる。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
cd "$ROOT"

PROJECT="WatchHook.xcodeproj"
SCHEME="WatchHook"
TEAM_ID="2KDR72P2RA"
SIGNING_CERT="iPhone Distribution"
PROFILE_APP="Hayate AppStore App"
PROFILE_WATCH="Hayate AppStore WatchApp"
PROFILE_WIDGET="Hayate AppStore WatchWidget"

ENVFILE="$SCRIPT_DIR/testflight.env"
if [ -f "$ENVFILE" ]; then
  # 値をシェルに展開させないよう、1 行ずつ読む (既に環境変数にあるものはそちらを優先)
  while IFS='=' read -r k v; do
    case "$k" in ''|\#*) continue ;; esac
    if [ -z "${!k:-}" ]; then export "$k=$v"; fi
  done < "$ENVFILE"
fi
: "${ASC_KEY_ID:?ASC_KEY_ID を設定する (scripts/testflight.env か環境変数)}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID を設定する}"
: "${ASC_KEY_PATH:?ASC_KEY_PATH を設定する}"
ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"
[ -f "$ASC_KEY_PATH" ] || { echo "API キーが見つからない: $ASC_KEY_PATH" >&2; exit 1; }
AUTH_ARGS=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

MARKETING=$(sed -n 's/^ *MARKETING_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' project.yml | head -1)
BUILD="${1:-$(sed -n 's/^ *CURRENT_PROJECT_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' project.yml | head -1)}"
case "$BUILD" in ''|*[!0-9]*) echo "build 番号が数字でない: '$BUILD'" >&2; exit 1 ;; esac
echo "== Hayate $MARKETING ($BUILD) を TestFlight へ上げる"

# 再起動後は専用 keychain がロックされていて、署名が errSecInternalComponent で止まる
if [ -n "${SIGNING_KEYCHAIN:-}" ] && [ -n "${SIGNING_KEYCHAIN_PASS:-}" ]; then
  security unlock-keychain -p "$SIGNING_KEYCHAIN_PASS" "$SIGNING_KEYCHAIN" \
    && echo "== $SIGNING_KEYCHAIN をアンロックした"
fi

OUT="$ROOT/build/testflight"
ARCHIVE="$OUT/Hayate.xcarchive"
rm -rf "$OUT"
mkdir -p "$OUT"

cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
	<key>destination</key>
	<string>upload</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>$SIGNING_CERT</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>com.nabettu.watchhook</key>
		<string>$PROFILE_APP</string>
		<key>com.nabettu.watchhook.watchkitapp</key>
		<string>$PROFILE_WATCH</string>
		<key>com.nabettu.watchhook.watchkitapp.widget</key>
		<string>$PROFILE_WIDGET</string>
	</dict>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
EOF

echo "== archive (ログ: $OUT/archive.log)"
if ! xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  "${AUTH_ARGS[@]}" \
  CURRENT_PROJECT_VERSION="$BUILD" \
  > "$OUT/archive.log" 2>&1; then
  grep -E "error:|\*\* ARCHIVE FAILED" "$OUT/archive.log" | tail -20 >&2
  echo "archive に失敗した" >&2
  exit 1
fi

# dSYM を後から読めるよう、Xcode の Archives にも残す (Organizer がクラッシュをシンボル化する)
KEEP_DIR="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)"
KEEP="$KEEP_DIR/Hayate $MARKETING ($BUILD).xcarchive"
[ -e "$KEEP" ] && KEEP="$KEEP_DIR/Hayate $MARKETING ($BUILD) $(date +%H%M%S).xcarchive"
mkdir -p "$KEEP_DIR"
ditto "$ARCHIVE" "$KEEP"
echo "== archive を残した: $KEEP"

echo "== export + upload (ログ: $OUT/export.log)"
if ! xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$OUT/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  "${AUTH_ARGS[@]}" \
  > "$OUT/export.log" 2>&1; then
  grep -iE "error|fail" "$OUT/export.log" | tail -20 >&2
  echo "export / upload に失敗した" >&2
  exit 1
fi

echo "== アップロードした: Hayate $MARKETING ($BUILD)。App Store Connect で処理が終わるまで数分〜数十分かかる"
