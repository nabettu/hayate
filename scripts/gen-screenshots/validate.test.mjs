import { test } from "node:test";
import assert from "node:assert/strict";
import { findForbidden, collectTexts } from "./validate.mjs";
import { COPY, LANGS } from "./copy.mjs";

test("価格・順位・誇大の語を見つける (日本語)", () => {
  assert.deepEqual(findForbidden("ja", "7 日間無料で使える").map((h) => h.word), ["無料"]);
  assert.deepEqual(findForbidden("ja", "No.1 の webhook アプリ").map((h) => h.word), ["No.1"]);
  assert.deepEqual(findForbidden("ja", "最強の音声入力").map((h) => h.word), ["最強"]);
  assert.deepEqual(findForbidden("ja", "話すだけで webhook へ送る"), []);
});

test("価格・順位・誇大の語を見つける (英語は単語の境目で見る)", () => {
  assert.deepEqual(findForbidden("en", "Try it free").map((h) => h.word), ["free"]);
  assert.deepEqual(findForbidden("en", "The best way").map((h) => h.word), ["best"]);
  // 語の一部は拾わない (freeform / topic)
  assert.deepEqual(findForbidden("en", "freeform topic"), []);
});

test("未定義の言語は英語の規則で見る", () => {
  assert.deepEqual(findForbidden("de", "free").map((h) => h.word), ["free"]);
});

test("collectTexts はスクショに出る文言をすべて拾う", () => {
  const texts = collectTexts(COPY.ja);
  assert.ok(texts.some((t) => t.text.includes("webhook")));
  assert.ok(texts.some((t) => t.path === "screen.edit.test"));
});

test("いまの文言に禁止語が無い", () => {
  for (const lang of LANGS) {
    const hits = collectTexts(COPY[lang]).flatMap((t) => findForbidden(lang, t.text).map((h) => `${lang} ${t.path}: ${h.word}`));
    assert.deepEqual(hits, []);
  }
});

test("強調の記法 (*...*) を外した表示の文字で見る", () => {
  assert.deepEqual(findForbidden("ja", "*0*円で使える").map((h) => h.word), ["0円"]);
  assert.deepEqual(findForbidden("ja", "*第1*位").map((h) => h.word), ["第1位"]);
  assert.deepEqual(findForbidden("en", "the *b*est").map((h) => h.word), ["best"]);
});
