// App Store のスクショを作る。
//   node index.mjs            # 全言語
//   node index.mjs ja         # 一部の言語だけ
// 出力: <repo>/screenshots/app-store/<lang>/iphone-0N_<名前>.png (1320x2868) と watch-0N_<名前>.png (416x496)。生成物は git に入れない
//
// 止める条件 (直してから作り直す):
// - 文言に禁止語がある (validate.mjs)
// - 見出しが収まらず、決めた大きさより小さく縮んだ (copy.mjs の改行を増やす・短くする)
// - 下の一言と、その上の吹き出し・カードの間が 24px 未満 / 見出しと端末・吹き出しが重なった

import * as fs from "node:fs";
import * as path from "node:path";
import { chromium } from "playwright";
import { COPY, LANGS } from "./copy.mjs";
import { assertNoForbidden } from "./validate.mjs";
import { IPHONE, IPHONE_SLIDES, ROOT, WATCH, WATCH_SLIDES, iphoneSlide, watchSlide } from "./render.mjs";

const OUT = path.join(ROOT, "screenshots/app-store");
// これより小さく縮んだら読めないので止める
const MIN_SIZE = { h1: 110, closing: 70 };

const langs = process.argv.slice(2).length ? process.argv.slice(2) : LANGS;
for (const lang of langs) {
  if (!COPY[lang]) throw new Error(`copy.mjs に ${lang} が無い`);
  assertNoForbidden(lang, COPY[lang]);
}

// インストール済みの Google Chrome を使う (Playwright のブラウザを落とさない。autofill と同じ)
const browser = await chromium.launch({ channel: "chrome" });
const problems = [];
try {
  for (const lang of langs) {
    const dir = path.join(OUT, lang);
    fs.mkdirSync(dir, { recursive: true });

    const phone = await browser.newPage({ viewport: { width: IPHONE.width, height: IPHONE.height }, deviceScaleFactor: 1 });
    for (const [i, key] of IPHONE_SLIDES.entries()) {
      await phone.setContent(iphoneSlide(key, COPY[lang], lang), { waitUntil: "load" });
      await phone.evaluate(() => document.fonts.ready);
      const report = await phone.evaluate(() => {
        const box = (el) => el.getBoundingClientRect();
        const closing = document.querySelector(".closing");
        const head = document.querySelector(".head");
        const above = [...document.querySelectorAll(".card, .bubble, .grid, .float")];
        const below = [...document.querySelectorAll(".watch, .iphone, .bubble, .float, .appicon, .grid")];
        return {
          fit: window.__fit,
          closingGap: closing ? box(closing).top - Math.max(0, ...above.map((el) => box(el).bottom)) : null,
          headGap: Math.min(...below.map((el) => box(el).top)) - box(head).bottom,
        };
      });
      const name = `iphone-${String(i + 1).padStart(2, "0")}_${key}`;
      for (const f of report.fit) {
        const kind = f.cls.includes("closing") ? "closing" : "h1";
        if (f.size < MIN_SIZE[kind]) problems.push(`${lang}/${name}: ${kind} が ${f.size}px まで縮んだ (下限 ${MIN_SIZE[kind]}px)`);
      }
      if (report.closingGap !== null && report.closingGap < 24) problems.push(`${lang}/${name}: 下の一言との間が ${Math.round(report.closingGap)}px`);
      if (report.headGap < 24) problems.push(`${lang}/${name}: 見出しとの間が ${Math.round(report.headGap)}px`);
      await phone.screenshot({ path: path.join(dir, `${name}.png`) });
      console.log(`  -> ${lang}/${name}.png`);
    }
    await phone.close();

    const watch = await browser.newPage({ viewport: { width: WATCH.width, height: WATCH.height }, deviceScaleFactor: 1 });
    for (const [i, key] of WATCH_SLIDES.entries()) {
      await watch.setContent(watchSlide(key, COPY[lang], lang), { waitUntil: "load" });
      await watch.evaluate(() => document.fonts.ready);
      const name = `watch-${String(i + 1).padStart(2, "0")}_${key}`;
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
