#!/usr/bin/env python3
"""翻訳 (言語ごとの JSON) をリポジトリへ取り込む。

    python3 -I scripts/l10n/apply.py <units.json> <言語ごとの JSON があるディレクトリ>

- units.json: `xcodebuild -exportLocalizations` の XLIFF から作った一覧 (file / id / ja)。作り方は scripts/l10n/README.md
- <dir>/<lang>.json: {"app": {id: 訳}, "appShortcuts": [...], "store": {...}, "shots": {...}}

書き込む先:
- アプリの文言: 各 Localizable.xcstrings / AppShortcuts.xcstrings / InfoPlist.xcstrings
- ストアの文言: store/metadata/<lang>.json (scripts/l10n/push-store.mjs が ASC へ送る)
- スクショの文言: scripts/gen-screenshots/copy/<lang>.json
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
units = json.load(open(sys.argv[1]))
src = sys.argv[2]
langs = sorted(f[:-5] for f in os.listdir(src) if f.endswith(".json"))

catalogs = {}
def catalog(rel):
    if rel not in catalogs:
        path = os.path.join(ROOT, rel)
        catalogs[rel] = json.load(open(path)) if os.path.exists(path) else {"sourceLanguage": "ja", "strings": {}, "version": "1.0"}
    return catalogs[rel]

for lang in langs:
    t = json.load(open(os.path.join(src, f"{lang}.json")))
    for u in units:
        c = catalog(u["file"])
        entry = c["strings"].setdefault(u["id"], {})
        locs = entry.setdefault("localizations", {})
        if u["file"].endswith("AppShortcuts.xcstrings"):
            locs[lang] = {"stringSet": {"state": "translated", "values": t["appShortcuts"]}}
            continue
        if u["file"].endswith("InfoPlist.xcstrings"):
            # Info.plist の値は ja も書いておく (InfoPlist.xcstrings はエクスポートでは作られない)
            locs.setdefault("ja", {"stringUnit": {"state": "translated", "value": u["ja"]}})
        value = t["app"][u["id"]]
        locs[lang] = {"stringUnit": {"state": "translated", "value": value}}
    for kind, rel in (("store", f"store/metadata/{lang}.json"), ("shots", f"scripts/gen-screenshots/copy/{lang}.json")):
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            json.dump(t[kind], f, ensure_ascii=False, indent=2)
            f.write("\n")

for rel, c in catalogs.items():
    with open(os.path.join(ROOT, rel), "w") as f:
        json.dump(c, f, ensure_ascii=False, indent=2, separators=(",", " : "), sort_keys=True)
        f.write("\n")
print(f"{len(langs)} 言語: {' '.join(langs)}")
