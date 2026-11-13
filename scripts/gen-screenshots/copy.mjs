// App Store のスクショの文言。言語ごとに copy/<lang>.json に置く (ja が元。ほかは scripts/l10n/apply.py が訳を書き込む)。
//
// - h1 / closing は \n で改行し、*...* で囲んだ語を強調色にする。自動の折り返しに頼らない
// - 文言はアプリが実際にすることだけを言う (README.md・docs/FREE_OSS.md)。たとえば再送は「次に開いたとき」で、裏での自動再送はまだ無い (ROADMAP)
// - 価格の語 (無料・free 等) は入れない (Guideline 2.3.7)。validate.mjs が止める
// - 画面の中の例 (送り先の名前・話した内容) も言語ごとにここで持つ

import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const DIR = path.join(HERE, "copy");

/** 文言のある言語 (ja を先頭に) */
export const LANGS = fs.readdirSync(DIR).filter((f) => f.endsWith(".json")).map((f) => f.slice(0, -5))
  .sort((a, b) => (a === "ja" ? -1 : b === "ja" ? 1 : a.localeCompare(b)));

export const COPY = Object.fromEntries(LANGS.map((lang) => [lang, JSON.parse(fs.readFileSync(path.join(DIR, `${lang}.json`), "utf8"))]));

/** 右から左に書く言語 */
export const RTL = new Set(["ar", "he", "ur"]);

/** アプリの言語 → App Store Connect のロケール (scripts/l10n/locales.json) */
export const ASC_LOCALES = (() => {
  const { _comment, ...map } = JSON.parse(fs.readFileSync(path.join(HERE, "../l10n/locales.json"), "utf8"));
  return map;
})();

/** ja と同じ形 (キー・配列の長さ) でない箇所。2026-11-13 にメモ寄りの構成へ変えたので、訳し直す前の言語はここで止まる */
export function shapeErrors(lang) {
  const errs = [];
  const walk = (a, b, p) => {
    if (Array.isArray(a)) {
      if (!Array.isArray(b) || a.length !== b.length) errs.push(`${p} は ${a.length} 個の配列`);
      else a.forEach((x, i) => walk(x, b[i], `${p}[${i}]`));
    } else if (a && typeof a === "object") {
      if (!b || typeof b !== "object") return errs.push(`${p} が無い`);
      for (const k of Object.keys(a)) walk(a[k], b[k], p ? `${p}.${k}` : k);
    } else if (typeof b !== "string" || !b) errs.push(`${p} が無い`);
  };
  walk(COPY.ja, COPY[lang], "");
  return errs;
}
