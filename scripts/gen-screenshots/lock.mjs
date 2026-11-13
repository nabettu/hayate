// スクショの生成 (index.mjs) とアップロード (upload.mjs) で共有するロック。どちらも 1 つずつ、互いに同時には動かさない
// (生成は前の画像を消してから書き直すので、並行すると相手の画像を消したり、作りかけを上げたりする)。
// OS のロック (flock) を、ロックを持つだけの perl の子に持たせる。標準入力が閉じる (このプロセスが終わる) と perl も終わり、OS がロックを外す。
// ファイルの作成・削除と pid の確認で組むと、残ったロックの引き継ぎに競合の隙間が残った (upload.mjs の ai-review 11〜15 回目)
import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import { ROOT } from "./render.mjs";

export const LOCK = path.join(ROOT, "screenshots/app-store/.upload.lock"); // 名前は前の upload.mjs のまま (動いている古い版とも排他する)

export async function takeLock() {
  fs.mkdirSync(path.dirname(LOCK), { recursive: true });
  const locker = spawn("perl", ["-e", 'use Fcntl ":flock"; open(my $f, ">>", $ARGV[0]) or exit 2; flock($f, LOCK_EX | LOCK_NB) or exit 75; $| = 1; print "ok\n"; <STDIN>;', LOCK],
    // 別のプロセスグループにする (端末の Ctrl+C が perl にも届くと、asc の終了を待つ間にロックが外れる)
    { stdio: ["pipe", "pipe", "inherit"], detached: true });
  const ok = await new Promise((resolve) => {
    locker.stdout.once("data", (d) => resolve(String(d).startsWith("ok")));
    locker.once("exit", () => resolve(false));
    locker.once("error", () => resolve(false));
  });
  if (!ok) { console.error("別の index.mjs / upload.mjs が動いている (またはロックを取れない)。終わってから動かす"); process.exit(2); }
  locker.unref();
  locker.stdout.unref?.();
  locker.stdin._handle?.unref?.();
}
