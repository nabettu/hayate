import { test } from "node:test";
import assert from "node:assert/strict";
import { COPY, shapeErrors } from "./copy.mjs";
import { IPHONE_SLIDES, LIST_SEP, WATCH_SLIDES, iphoneSlide, watchSlide } from "./render.mjs";

// 文言をすべて英字に置き換えたコピー (英語を足したときの代わり)
const latin = (v) => typeof v === "string" ? v.replace(/[^\n*{}]/g, "x")
  : Array.isArray(v) ? v.map(latin) : Object.fromEntries(Object.entries(v).map(([k, x]) => [k, latin(x)]));

test("画面に出す文字はすべて copy.mjs から来る (日本語が残らない)", () => {
  const copy = latin(COPY.ja);
  const visible = (html) => html.replace(/<style>[\s\S]*?<\/style>/g, "").replace(/<script>[\s\S]*?<\/script>/g, "").replace(/<[^>]+>/g, " ").replaceAll(LIST_SEP, " ");
  for (const key of IPHONE_SLIDES) assert.doesNotMatch(visible(iphoneSlide(key, copy)), /[　-ヿ一-鿿＀-￯]/, key);
  for (const key of WATCH_SLIDES) assert.doesNotMatch(visible(watchSlide(key, copy)), /[　-ヿ一-鿿＀-￯]/, key);
});

test("どの言語も ja と同じ形", () => {
  for (const lang of Object.keys(COPY)) assert.deepEqual(shapeErrors(lang), [], lang);
});

test("ja に無いキーがあると形の違いとして弾く (描画の途中で落ちるのを防ぐ)", () => {
  COPY.en.iphone.memos.chips = ["Reminders"];
  try {
    assert.match(shapeErrors("en").join("\n"), /iphone\.memos\.chips は ja に無い/);
  } finally {
    delete COPY.en.iphone.memos.chips;
  }
});

test("iPhone のスクショはどれもアプリの画面が主役 (広告の図・時計の絵・機能の一覧を載せない。Guideline 2.3.3)", () => {
  for (const key of IPHONE_SLIDES) {
    const html = iphoneSlide(key, COPY.ja);
    assert.match(html, /class="iphone"/, key);
    assert.doesNotMatch(html, /class="(watch|bubble|float|chip|grid|closing|card)[ "]/, key);
  }
});
