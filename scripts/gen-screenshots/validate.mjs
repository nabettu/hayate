// App Store のメタデータで弾かれやすい語 (Guideline 2.3.7 の価格表現・順位・誇大表現) を、スクショに出る文言から探す。
// 一覧は ~/work/docs/store-screenshot-design-guide.md の「禁止ワード検知」。見つかったら index.mjs が生成を止める。

const FORBIDDEN = {
  ja: [
    ["無料", /無料/], ["0円", /0\s*円/], ["タダ", /タダ/], ["お得", /お得/], ["セール", /セール/], ["割引", /割引/], ["値引き", /値引き/],
    ["期間限定", /期間限定/], ["今だけ", /今だけ/], ["No.1", /No\.?\s*1/i], ["ナンバーワン", /ナンバーワン/], ["第1位", /第\s*1\s*位/],
    ["日本一", /日本一/], ["世界一", /世界一/], ["ベスト", /ベスト/], ["最高", /最高/], ["最強", /最強/], ["究極", /究極/], ["革命", /革命/],
  ],
  en: [
    ["free", /\bfree\b/i], ["sale", /\bsale\b/i], ["discount", /\bdiscount\b/i], ["limited time", /limited\s*time/i],
    ["% off", /\d+\s*%\s*off/i], ["cheap", /\bcheap\b/i], ["#1", /#\s*1\b/], ["number one", /\bnumber one\b/i], ["best", /\bbest\b/i],
    ["top", /\btop\b/i], ["award-winning", /award[-\s]?winning/i], ["guaranteed", /\bguaranteed\b/i], ["proven", /\bproven\b/i],
  ],
};

const rulesFor = (lang) => FORBIDDEN[lang] ?? (["ko", "zh-Hans", "zh-Hant"].includes(lang) ? FORBIDDEN.ja : FORBIDDEN.en);

/** 画像に出る文字。render.mjs は *...* を強調に変えるだけなので、記号を外したものが見た目どおり */
export const displayText = (text) => text.replace(/\*/g, "");

/** text に含まれる禁止語を返す (強調の記法を外した、画像に出る文字で見る)。 */
export function findForbidden(lang, text) {
  const shown = displayText(text);
  return rulesFor(lang).filter(([, re]) => re.test(shown)).map(([word]) => ({ word }));
}

/** 1 言語ぶんの文言 (copy.mjs の COPY[lang]) から、文字列をパス付きですべて取り出す。 */
export function collectTexts(value, path = "") {
  if (typeof value === "string") return [{ path, text: value }];
  if (Array.isArray(value)) return value.flatMap((v, i) => collectTexts(v, `${path}[${i}]`));
  if (value && typeof value === "object") {
    return Object.entries(value).flatMap(([k, v]) => collectTexts(v, path ? `${path}.${k}` : k));
  }
  return [];
}

/** 禁止語があれば例外を投げる。 */
export function assertNoForbidden(lang, copy) {
  const hits = collectTexts(copy).flatMap((t) => findForbidden(lang, t.text).map((h) => `  [${lang}] ${t.path}: "${t.text}" → ${h.word}`));
  if (hits.length) throw new Error(`禁止語が入っている (Guideline 2.3.7)。copy.mjs を直す:\n${hits.join("\n")}`);
}
