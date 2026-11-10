// 作ったスクショを App Store Connect (バージョン 1.0) の各ロケールへ上げる。既存のセットは入れ替える。
//   node upload.mjs --dry-run        # 何を上げる・消すかだけ出す
//   node upload.mjs [ja en ...]      # 上げる (言語を絞れる)
// 先に scripts/l10n/push-store.mjs でロケール (バージョンのローカライズ) を作っておく。無いロケールには上げられない
// ⚠️ 本番のストアのページに出る。ユーザーの OK を取ってから

import { execFileSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { ASC_LOCALES } from "./copy.mjs";
import { ROOT } from "./render.mjs";

const APP = "6832906978";
const VERSION = "1.0";
const SETS = [["iphone", "IPHONE_67"], ["watch", "WATCH_SERIES_10"]];

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const only = args.filter((a) => !a.startsWith("--"));
// 既存のスクショを入れ替えるので、知らないオプション (--help・--dryrun の誤記など) や言語が来たら何もせずに止める
for (const a of args) {
  if (a.startsWith("--") ? a !== "--dry-run" : !(a in ASC_LOCALES)) {
    console.error(`知らない引数: ${a}\n使い方: node upload.mjs [--dry-run] [言語 ...]  (言語は ${Object.keys(ASC_LOCALES).join(" ")})`);
    process.exit(2);
  }
}

fs.mkdirSync(path.join(os.tmpdir(), "claude-work"), { recursive: true });
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "claude-work", "hayate-upload-"));
process.on("exit", () => fs.rmSync(tmp, { recursive: true, force: true }));

for (const [lang, locales] of Object.entries(ASC_LOCALES)) {
  if (only.length && !only.includes(lang)) continue;
  const dir = path.join(ROOT, "screenshots/app-store", lang);
  if (!fs.existsSync(dir)) { console.warn(`! ${lang}: ${dir} が無い (node index.mjs ${lang})`); continue; }
  for (const [prefix, deviceType] of SETS) {
    // 端末ごとにディレクトリを分けて渡す (asc は渡したディレクトリの PNG を連番の順に上げる)
    const files = fs.readdirSync(dir).filter((f) => f.startsWith(`${prefix}-`) && f.endsWith(".png")).sort();
    const sub = path.join(tmp, lang, prefix);
    fs.mkdirSync(sub, { recursive: true });
    for (const f of files) fs.copyFileSync(path.join(dir, f), path.join(sub, f));
    for (const locale of locales) {
      const a = ["--profile", "crossedge", "screenshots", "upload", "--app", APP, "--version", VERSION, "--locale", locale,
        "--path", sub, "--device-type", deviceType, "--replace", "--confirm", "--output", "table"];
      if (dryRun) a.push("--dry-run");
      console.log(`${locale} ${deviceType} (${files.length} 枚)`);
      // dry-run は上げる・消す予定の表を見るために出す。本番は表が長いので捨てる (エラーは出す)
      execFileSync("asc", a, { stdio: ["ignore", dryRun ? "inherit" : "ignore", "inherit"] });
    }
  }
}
console.log(dryRun ? "(dry-run: 上げていない)" : "上げた");
