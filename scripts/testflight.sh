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
#   BUILD_WRAPPER       (任意) xcodebuild の前に付けるコマンド (同時に走るビルドの数を絞るラッパーなど)。
#                       別のマシンへビルドを回すものは、archive / export をこの Mac で走らせるものに限る
#
# 署名の前提:
#   - export は manual signing。API キーにはクラウド署名の権限が無く、automatic だと export で落ちるため。
#   - 配布用の証明書 (iPhone Distribution / Apple Distribution) の秘密鍵がこの Mac の keychain にあること。
#   - 3 つの Bundle ID それぞれに App Store 用のプロファイルを、下の PROFILE_* の名前で発行しておく。
#     プロファイルはその証明書で作る。手元に無ければ -allowProvisioningUpdates と API キーで Xcode が取ってくる。
#   - 署名の鍵がある Mac で走らせる。
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
  # 値をシェルに展開させないよう、1 行ずつ読む (既に環境変数にあるものはそちらを優先)。
  # 読むのは下の名前だけ。最終行に改行が無くても読み、CRLF の \r は落とす
  while IFS='=' read -r k v || [ -n "$k" ]; do
    k="${k%$'\r'}"; v="${v%$'\r'}"
    case "$k" in
      ASC_KEY_ID|ASC_ISSUER_ID|ASC_KEY_PATH|SIGNING_KEYCHAIN|SIGNING_KEYCHAIN_PASS|BUILD_WRAPPER)
        if [ -z "${!k:-}" ]; then export "$k=$v"; fi ;;
      ''|\#*) ;;
      *) echo "testflight.env の知らない名前を無視する: $k" >&2 ;;
    esac
  done < "$ENVFILE"
fi
: "${ASC_KEY_ID:?ASC_KEY_ID を設定する (scripts/testflight.env か環境変数)}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID を設定する}"
: "${ASC_KEY_PATH:?ASC_KEY_PATH を設定する}"
ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"
[ -f "$ASC_KEY_PATH" ] || { echo "API キーが見つからない: $ASC_KEY_PATH" >&2; exit 1; }
WRAP=()
if [ -n "${BUILD_WRAPPER:-}" ]; then WRAP=("${BUILD_WRAPPER/#\~/$HOME}"); fi
AUTH_ARGS=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

MARKETING=$(sed -n 's/^ *MARKETING_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' project.yml | head -1)
BUILD="${1:-$(sed -n 's/^ *CURRENT_PROJECT_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' project.yml | head -1)}"
case "$BUILD" in ''|*[!0-9]*) echo "build 番号が数字でない: '$BUILD'" >&2; exit 1 ;; esac
echo "== Hayate $MARKETING ($BUILD) を TestFlight へ上げる"

# 再起動後は専用 keychain がロックされていて、署名が errSecInternalComponent で止まる
if [ -n "${SIGNING_KEYCHAIN:-}" ]; then
  : "${SIGNING_KEYCHAIN_PASS:?SIGNING_KEYCHAIN を使うなら SIGNING_KEYCHAIN_PASS も設定する}"
  if ! security unlock-keychain -p "$SIGNING_KEYCHAIN_PASS" "$SIGNING_KEYCHAIN"; then
    echo "$SIGNING_KEYCHAIN のアンロックに失敗した" >&2
    exit 1
  fi
  echo "== $SIGNING_KEYCHAIN をアンロックした"
fi

# 実行ごとに別の出力先にする (同時に走らせても互いのアーカイブを消したり上げ違えたりしない)
mkdir -p "$ROOT/build"
OUT=$(mktemp -d "$ROOT/build/testflight.XXXXXX")
ARCHIVE="$OUT/Hayate.xcarchive"

# ログから要点を出す。拾えなければ末尾を出す
show_errors() {
  grep -iE "$2" "$1" | tail -20 >&2 || tail -20 "$1" >&2
}

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
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
EOF

echo "== archive (ログ: $OUT/archive.log)"
if ! ${WRAP[@]+"${WRAP[@]}"} xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  "${AUTH_ARGS[@]}" \
  CURRENT_PROJECT_VERSION="$BUILD" \
  > "$OUT/archive.log" 2>&1; then
  show_errors "$OUT/archive.log" "error:|\*\* ARCHIVE FAILED"
  echo "archive に失敗した" >&2
  exit 1
fi

# dSYM を後から読めるよう、Xcode の Archives にも残す (Organizer がクラッシュをシンボル化する)
KEEP_DIR="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)"
mkdir -p "$KEEP_DIR"
# mkdir で先に場所を取る (同じ名前があれば ditto は中身を混ぜるので、空いている名前を探す)
KEEP="$KEEP_DIR/Hayate $MARKETING ($BUILD).xcarchive"
n=2
until mkdir "$KEEP" 2>/dev/null; do
  KEEP="$KEEP_DIR/Hayate $MARKETING ($BUILD) #$n.xcarchive"
  n=$((n + 1))
  [ "$n" -le 100 ] || { echo "archive を残す場所を作れない: $KEEP_DIR" >&2; exit 1; }
done
ditto "$ARCHIVE" "$KEEP"
echo "== archive を残した: $KEEP"

echo "== export + upload (ログ: $OUT/export.log)"
if ! ${WRAP[@]+"${WRAP[@]}"} xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$OUT/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  "${AUTH_ARGS[@]}" \
  > "$OUT/export.log" 2>&1; then
  show_errors "$OUT/export.log" "error|fail"
  echo "export / upload に失敗した" >&2
  exit 1
fi

echo "== アップロードした: Hayate $MARKETING ($BUILD)。App Store Connect で処理が終わるまで数分〜数十分かかる"
