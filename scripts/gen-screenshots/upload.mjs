// 作ったスクショを App Store Connect (バージョン 1.0) の各ロケールへ上げる。既存のセットは入れ替える。
//   node upload.mjs --dry-run        # 何を上げる・消すかだけ出す
//   node upload.mjs [ja en ...]      # 上げる (言語を絞れる)
// 先に scripts/l10n/push-store.mjs でロケール (バージョンのローカライズ) を作っておく。無いロケールには上げられない
// ⚠️ 本番のストアのページに出る。ユーザーの OK を取ってから

import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { ASC_LOCALES } from "./copy.mjs";
import { IPHONE_SLIDES, ROOT, WATCH_SLIDES } from "./render.mjs";

const APP = "6832906978";
const VERSION = "1.0";
const SETS = [["iphone", "IPHONE_67", IPHONE_SLIDES], ["watch", "WATCH_SERIES_10", WATCH_SLIDES]];

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

// 1 セットに数分かかる (asc がサーバー側の処理の完了を待つ) ので、ロケールを並行で上げる。
// 6 本にしたら API の回数制限 (429、「34 分待て」) に当たり 100 セット中 99 が落ちた (2026-11-10)。
// 同じ API キーをほかのアプリの作業でも使うので 2 本にし、制限に当たったら asc 自身に待たせる (ASC_MAX_DELAY)
const CONCURRENCY = Number(process.env.UPLOAD_CONCURRENCY ?? 2);
if (!Number.isInteger(CONCURRENCY) || CONCURRENCY < 1) {
  console.error(`UPLOAD_CONCURRENCY は 1 以上の整数にする (今: ${JSON.stringify(process.env.UPLOAD_CONCURRENCY)})`);
  process.exit(2);
}
// 待つ長さ (ASC_MAX_DELAY) より、ふつうの要求とアップロードの期限 (ASC_TIMEOUT・ASC_UPLOAD_TIMEOUT) を長くする。
// --replace で消してから上げるので、途中で切れるとそのロケールのセットが欠ける
const ASC_ENV = {
  ...process.env,
  ASC_MAX_DELAY: process.env.ASC_MAX_DELAY ?? "40m",
  ASC_TIMEOUT: process.env.ASC_TIMEOUT ?? "90m",
  ASC_UPLOAD_TIMEOUT: process.env.ASC_UPLOAD_TIMEOUT ?? "90m",
};
const jobs = [];
// 同じチェックアウトで 2 つ動くと、記録を上書きし合い、--replace 同士で相手の画像を消すので、1 つだけにする。
// OS のロック (flock) を、ロックを持つだけの perl の子に持たせる。標準入力が閉じる (このプロセスが終わる) と perl も終わり、OS がロックを外す。
// ファイルの作成・削除と pid の確認で組むと、残ったロックの引き継ぎに競合の隙間が残った (ai-review 11〜15 回目)
const LOCK = path.join(ROOT, "screenshots/app-store/.upload.lock");
async function takeLock() {
  fs.mkdirSync(path.dirname(LOCK), { recursive: true });
  const locker = spawn("perl", ["-e", 'use Fcntl ":flock"; open(my $f, ">>", $ARGV[0]) or exit 2; flock($f, LOCK_EX | LOCK_NB) or exit 75; $| = 1; print "ok\n"; <STDIN>;', LOCK],
    // 別のプロセスグループにする (端末の Ctrl+C が perl にも届くと、asc の終了を待つ間にロックが外れる)
    { stdio: ["pipe", "pipe", "inherit"], detached: true });
  const ok = await new Promise((resolve) => {
    locker.stdout.once("data", (d) => resolve(String(d).startsWith("ok")));
    locker.once("exit", () => resolve(false));
    locker.once("error", () => resolve(false));
  });
  if (!ok) { console.error("別の upload.mjs が動いている (またはロックを取れない)。終わってから動かす"); process.exit(2); }
  locker.unref();
  locker.stdout.unref?.();
  locker.stdin._handle?.unref?.();
}
// 起動した asc。止められたら子に止めるよう伝え、全部終わってからロック・一時画像を消す (親だけ先に終わると、子が ASC を書き換え続けたまま次が動ける)
const children = new Set();
let stopping = false;
function stop(code = 130) {
  if (stopping) return;
  stopping = true;
  for (const c of children) c.kill("SIGTERM");
  const wait = () => (children.size ? setTimeout(wait, 200) : process.exit(code));
  wait();
}
if (!dryRun) {
  await takeLock();
  for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"]) process.on(sig, () => stop(130));
}
// 上げ終わったセットの記録 (ロケール・端末 → 画像のハッシュ)。生成物と同じく git に入れない
const DONE_FILE = path.join(ROOT, "screenshots/app-store/.uploaded.json");
const done = fs.existsSync(DONE_FILE) ? JSON.parse(fs.readFileSync(DONE_FILE, "utf8")) : {};
for (const [lang, locales] of Object.entries(ASC_LOCALES)) {
  if (only.length && !only.includes(lang)) continue;
  const dir = path.join(ROOT, "screenshots/app-store", lang);
  if (!fs.existsSync(dir)) { console.warn(`! ${lang}: ${dir} が無い (node index.mjs ${lang})`); continue; }
  for (const [prefix, deviceType, slides] of SETS) {
    // 端末ごとにディレクトリを分けて渡す (asc は渡したディレクトリの PNG を連番の順に上げる)。
    // --replace で既存のセットを消すので、決まった枚数がそろっていなければ上げない (生成が途中で止まった等)
    const files = slides.map((key, i) => `${prefix}-${String(i + 1).padStart(2, "0")}_${key}.png`);
    const missing = files.filter((f) => !fs.existsSync(path.join(dir, f)));
    if (missing.length) {
      console.error(`${lang}: ${missing.join(", ")} が無い。node index.mjs ${lang} で作り直してから上げる`);
      process.exit(1);
    }
    const sub = path.join(tmp, lang, prefix);
    fs.mkdirSync(sub, { recursive: true });
    for (const f of files) fs.copyFileSync(path.join(dir, f), path.join(sub, f));
    const hash = createHash("sha256");
    // 実際に上げるコピーから取る (元の画像が生成し直されても、上げたものと記録をずらさない)
    for (const f of files) hash.update(fs.readFileSync(path.join(sub, f)));
    const digest = hash.digest("hex");
    for (const locale of locales) {
      // 同じ画像をもう上げたセットは飛ばす (回数制限で止まっても、続きから再開できる)
      if (!dryRun && done[`${locale} ${deviceType}`] === digest) continue;
      jobs.push({ locale, deviceType, sub, count: files.length, digest });
    }
  }
}

const saveDone = () => fs.writeFileSync(DONE_FILE, JSON.stringify(done, null, 1));
const run = (job) => new Promise((resolve) => {
  // --replace は既存のセットを先に消す。途中で失敗したら ASC 側は欠けているので、始める前に成功の記録を消しておく
  if (!dryRun) { delete done[`${job.locale} ${job.deviceType}`]; saveDone(); }
  const a = ["--profile", "crossedge", "screenshots", "upload", "--app", APP, "--version", VERSION, "--locale", job.locale,
    "--path", job.sub, "--device-type", job.deviceType, "--replace", "--confirm", "--output", "table"];
  if (dryRun) a.push("--dry-run");
  // dry-run は上げる・消す予定の表を見るために出す。本番は表が長いので捨てる (エラーは集める)
  let err = "";
  const p = spawn("asc", a, { env: ASC_ENV, stdio: ["ignore", dryRun ? "inherit" : "ignore", "pipe"] });
  children.add(p);
  let settled = false;
  const finish = (code, message) => { if (!settled) { settled = true; resolve({ ...job, code, err: message.trim() }); } };
  p.stderr.on("data", (d) => { err += d; });
  // asc が無い・起動できないときも 1 件の失敗として集め、ほかのジョブは続ける
  p.on("error", (e) => { children.delete(p); finish(-1, String(e)); });
  p.on("close", (code) => { children.delete(p); finish(code, err); });
});

const failures = [];
let finished = 0;
const queue = [...jobs];
try {
  await Promise.all(Array.from({ length: dryRun ? 1 : CONCURRENCY }, async () => {
    while (queue.length && !stopping) {
      const r = await run(queue.shift());
      finished++;
      console.log(`[${finished}/${jobs.length}] ${r.locale} ${r.deviceType} (${r.count} 枚) ${r.code === 0 ? "OK" : "失敗"}`);
      if (r.code !== 0) failures.push(`${r.locale} ${r.deviceType}: ${r.err.split("\n")[0]}`);
      else if (!dryRun) {
        done[`${r.locale} ${r.deviceType}`] = r.digest;
        saveDone();
      }
    }
  }));
} catch (e) {
  // ワーカーの例外 (記録を書けない等) でも、子の asc を止めて終わるのを待ってから片付ける
  console.error(e);
  stop(1);
  await new Promise(() => {}); // stop が子の終了を待って exit する
}
if (failures.length) {
  console.error(`\n失敗 ${failures.length} 件 (その言語だけ上げ直す: node upload.mjs <言語>):\n${failures.map((f) => `  ${f}`).join("\n")}`);
  process.exit(1);
}
console.log(dryRun ? "(dry-run: 上げていない)" : "上げた");
