// store/metadata/<lang>.json を App Store Connect へ送る (asc の API キー、profile crossedge)。
//   node scripts/l10n/push-store.mjs --dry-run     # 何を作る・変えるかだけ出す
//   node scripts/l10n/push-store.mjs [ja en ...]   # 送る (言語を絞れる)
//
// 送るもの (ロケールは scripts/l10n/locales.json。無いロケールは作る):
// - App 情報: 名前・サブタイトル
// - バージョン (VERSION_ID): 説明文・キーワード・プロモーションテキスト
// - アプリ内課金 2 つ: 表示名・説明
// ⚠️ 本番のストアのページに出る文言。ユーザーの OK を取ってから送る

import { execFileSync } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const APP_INFO_ID = "5faa8218-c59a-445c-be22-0b731f5c5f2c";
const VERSION_ID = "a14da3e0-a800-4267-b815-f5e6fc426c2d"; // 1.0
const IAPS = { trial: "6832907177", unlock: "6832907079" };

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const only = args.filter((a) => !a.startsWith("--"));
const { _comment, ...LOCALES } = JSON.parse(fs.readFileSync(path.join(ROOT, "scripts/l10n/locales.json"), "utf8"));

function api(method, apiPath, body) {
  const a = ["--profile", "crossedge", "api", method, apiPath];
  if (body) a.push("--body", JSON.stringify(body), "--confirm");
  const out = execFileSync("asc", a, { encoding: "utf8", maxBuffer: 64 << 20 });
  return out.trim() ? JSON.parse(out) : {};
}
const byLocale = (list) => Object.fromEntries((list.data ?? []).map((d) => [d.attributes.locale, d]));

// 文字数の上限 (App Store Connect)
const LIMITS = { name: 30, subtitle: 30, promotionalText: 170, keywords: 100, description: 4000 };
function check(lang, m) {
  for (const [k, lim] of Object.entries(LIMITS)) {
    if ((m[k] ?? "").length > lim) throw new Error(`${lang}: ${k} が ${m[k].length} 文字 (上限 ${lim})`);
  }
  for (const k of Object.keys(IAPS)) {
    if (m.iap[k].name.length > 30 || m.iap[k].description.length > 55) throw new Error(`${lang}: iap.${k} が長すぎる`);
  }
}

function upsert(kind, existing, locale, attrs, create, patchType) {
  const cur = existing[locale];
  const changed = cur ? Object.entries(attrs).filter(([k, v]) => cur.attributes[k] !== v).map(([k]) => k) : Object.keys(attrs);
  if (!changed.length) return;
  console.log(`  ${cur ? "更新" : "作成"} ${kind} ${locale}: ${changed.join(", ")}`);
  if (dryRun) return;
  try {
    if (cur) api("PATCH", `/v1/${patchType}/${cur.id}`, { data: { type: patchType, id: cur.id, attributes: attrs } });
    else create();
  } catch (e) {
    // 1 つ失敗しても残りは送る (例: その言語ではアプリ名が他社に使われている)。最後にまとめて出す
    const msg = String(e.stderr || e.message).trim().split("\n")[0];
    failures.push(`${kind} ${locale}: ${msg}`);
    console.log(`    ✗ ${msg}`);
  }
}
const failures = [];

const appInfoLocs = byLocale(api("GET", `/v1/appInfos/${APP_INFO_ID}/appInfoLocalizations?limit=200`));
const versionLocs = byLocale(api("GET", `/v1/appStoreVersions/${VERSION_ID}/appStoreVersionLocalizations?limit=200`));
const iapLocs = Object.fromEntries(Object.entries(IAPS).map(([k, id]) => [k, byLocale(api("GET", `/v2/inAppPurchases/${id}/inAppPurchaseLocalizations?limit=200`))]));

for (const [lang, locales] of Object.entries(LOCALES)) {
  if (only.length && !only.includes(lang)) continue;
  const file = path.join(ROOT, `store/metadata/${lang}.json`);
  if (!fs.existsSync(file)) { console.warn(`! ${lang}: store/metadata/${lang}.json が無い`); continue; }
  const m = JSON.parse(fs.readFileSync(file, "utf8"));
  check(lang, m);
  console.log(`${lang} → ${locales.join(" ")}`);
  for (const locale of locales) {
    upsert("App 情報", appInfoLocs, locale, { name: m.name, subtitle: m.subtitle }, () => api("POST", "/v1/appInfoLocalizations", {
      data: { type: "appInfoLocalizations", attributes: { locale, name: m.name, subtitle: m.subtitle }, relationships: { appInfo: { data: { type: "appInfos", id: APP_INFO_ID } } } },
    }), "appInfoLocalizations");
    const v = { description: m.description, keywords: m.keywords, promotionalText: m.promotionalText };
    // サポート URL は審査提出に要る。決まったら store/metadata/<lang>.json に supportUrl を書く (2026-11-10 時点では未定)
    if (m.supportUrl) v.supportUrl = m.supportUrl;
    upsert("バージョン", versionLocs, locale, v, () => api("POST", "/v1/appStoreVersionLocalizations", {
      data: { type: "appStoreVersionLocalizations", attributes: { locale, ...v }, relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: VERSION_ID } } } },
    }), "appStoreVersionLocalizations");
    for (const [k, id] of Object.entries(IAPS)) {
      const a = { name: m.iap[k].name, description: m.iap[k].description };
      upsert(`IAP ${k}`, iapLocs[k], locale, a, () => api("POST", "/v1/inAppPurchaseLocalizations", {
        data: { type: "inAppPurchaseLocalizations", attributes: { locale, ...a }, relationships: { inAppPurchaseV2: { data: { type: "inAppPurchases", id } } } },
      }), "inAppPurchaseLocalizations");
    }
  }
}
if (failures.length) {
  console.error(`\n失敗 ${failures.length} 件:\n${failures.map((f) => `  ${f}`).join("\n")}`);
  process.exit(1);
}
console.log(dryRun ? "\n(dry-run: 送っていない)" : "\n送った");
