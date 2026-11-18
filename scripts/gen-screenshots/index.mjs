// App Store のスクショを作る。
//   node index.mjs            # 全言語
//   node index.mjs ja         # 一部の言語だけ
// 出力: <repo>/screenshots/app-store/<lang>/iphone-0N_<名前>.png (1320x2868) と watch-0N_<名前>.png (416x496)。生成物は git に入れない
//
// 止める条件 (直してから作り直す):
// - 文言に禁止語がある (validate.mjs)
// - 見出しが収まらず、決めた大きさより小さく縮んだ (copy.mjs の改行を増やす・短くする)
// - 見出しと端末の間が 40px 未満 (詰まって見える) / 画面の中身が下のタブに重なる
// - 時計の画面の 1 行の文字が、字を小さくしても収まらない

import * as fs from "node:fs";
import * as path from "node:path";
import { chromium } from "playwright";
import { COPY, LANGS, shapeErrors } from "./copy.mjs";
import { assertNoForbidden } from "./validate.mjs";
import { takeLock } from "./lock.mjs";
import { IPHONE, IPHONE_SLIDES, ROOT, WATCH, WATCH_SLIDES, iphoneSlide, watchSlide } from "./render.mjs";

const OUT = path.join(ROOT, "screenshots/app-store");
// これより小さく縮んだら読めないので止める
const MIN_SIZE = 84;

const langs = process.argv.slice(2).length ? process.argv.slice(2) : LANGS;
for (const lang of langs) {
  if (!COPY[lang]) throw new Error(`copy.mjs に ${lang} が無い`);
  const shape = shapeErrors(lang);
  if (shape.length) throw new Error(`copy/${lang}.json が copy/ja.json と同じ形でない (ja から訳し直す。scripts/l10n/README.md):\n  ${shape.slice(0, 5).join("\n  ")}`);
  assertNoForbidden(lang, COPY[lang]);
}

// 消して書き直している間に、別の生成やアップロードが同じ画像を触らないように (lock.mjs)
await takeLock();

// インストール済みの Google Chrome を使う (Playwright のブラウザを落とさない。autofill と同じ)
const browser = await chromium.launch({ channel: "chrome" });
const problems = [];
try {
  for (const lang of langs) {
    const dir = path.join(OUT, lang);
    fs.mkdirSync(dir, { recursive: true });
    // 前の構成の画像 (名前の違うもの) が残っていると upload.mjs が一緒に上げるので、先に消す
    for (const f of fs.readdirSync(dir)) if (/^(iphone|watch)-\d\d_.*\.png$/.test(f)) fs.unlinkSync(path.join(dir, f));

    const phone = await browser.newPage({ viewport: { width: IPHONE.width, height: IPHONE.height }, deviceScaleFactor: 1 });
    for (const [i, key] of IPHONE_SLIDES.entries()) {
      await phone.setContent(iphoneSlide(key, COPY[lang], lang), { waitUntil: "load" });
      await phone.evaluate(() => document.fonts.ready);
      const report = await phone.evaluate(() => {
        const box = (el) => el.getBoundingClientRect();
        const ps = document.querySelector(".ps");
        return {
          fit: window.__fit,
          headGap: box(document.querySelector(".iphone")).top - box(document.querySelector(".head")).bottom,
          // 画面の中身が下のタブに潜り込んでいないか (タブの上端より下まで中身がある)
          contentBottom: Math.max(0, ...[...ps.querySelectorAll(":scope > :not(.appsky):not(.tabbar):not(.status)")].map((el) => el.getBoundingClientRect().bottom)),
          tabTop: box(ps.querySelector(".tabbar")).top,
        };
      });
      const name = `iphone-${String(i + 1).padStart(2, "0")}_${key}`;
      for (const f of report.fit) if (f.size < MIN_SIZE) problems.push(`${lang}/${name}: 見出しが ${f.size}px まで縮んだ (下限 ${MIN_SIZE}px)`);
      if (report.headGap < 40) problems.push(`${lang}/${name}: 見出しと端末の間が ${Math.round(report.headGap)}px`);
      if (report.contentBottom > report.tabTop) problems.push(`${lang}/${name}: 画面の中身が下のタブに重なる`);
      await phone.screenshot({ path: path.join(dir, `${name}.png`) });
      console.log(`  -> ${lang}/${name}.png`);
    }
    await phone.close();

    const watch = await browser.newPage({ viewport: { width: WATCH.width, height: WATCH.height }, deviceScaleFactor: 1 });
    for (const [i, key] of WATCH_SLIDES.entries()) {
      await watch.setContent(watchSlide(key, COPY[lang], lang), { waitUntil: "load" });
      await watch.evaluate(() => document.fonts.ready);
      const name = `watch-${String(i + 1).padStart(2, "0")}_${key}`;
      for (const o of await watch.evaluate(() => window.__watchOverflow)) problems.push(`${lang}/${name}: 収まらない (${o})`);
      await watch.screenshot({ path: path.join(dir, `${name}.png`) });
      console.log(`  -> ${lang}/${name}.png`);
    }
    await watch.close();
  }
} finally {
  await browser.close();
}

if (problems.length) {
  console.error(`\n止めた (画像は書き出してあるので見て直す):\n${problems.map((p) => `  ${p}`).join("\n")}`);
  process.exit(1);
}
console.log(`\n${langs.length} 言語 → ${path.relative(process.cwd(), OUT) || OUT}`);
