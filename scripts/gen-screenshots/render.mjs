// App Store のスクショの HTML。アプリの画面もシミュレータで撮らずに HTML で描く。実機のスクショより言語ごとに作り直しやすく、架空の例文を載せられる。
//
// 形式は TypeAI / autofill の「広告としてのスクショ」: 太い 2 行の見出し (*...* を強調) → チップ → 端末 (まわりに吹き出し) → 下の一言。
// 最後の 1 枚は「他にもいろいろ」。背景はアプリアイコン (design/app-icon.svg) の夜空に合わせて暗くしている。
//
// - iPhone 6.9" (1320x2868) 5 枚: hero (話す → メモ → 連携) / siri / reminder (合図でリマインダー) / integrations (複数の送り先・Markdown) / more
// - Apple Watch (416x496 = Series 10/11 46mm の実寸) 3 枚: home (メモのボタン) / memos (メモの一覧) / detail (連携ごとの状態)。
//   App Store が時計の枠を付けて見せるので、画面だけを描く (文字も載せない)
//
// 画面の中身は実際の SwiftUI の画面 (WatchHookWatch/WatchHomeView.swift・WatchHook/MemoListView.swift・WatchHook/DestinationListView.swift・
// WatchHook/WatchHookApp.swift のタブ・Shared/Cosmos.swift の色) に合わせる。画面を変えたらここも合わせる。

import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const ROOT = path.resolve(HERE, "../..");

export const IPHONE = { width: 1320, height: 2868 };
export const WATCH = { width: 416, height: 496 };

const ICON_PNG = fs.readFileSync(path.join(ROOT, "WatchHook/Assets.xcassets/AppIcon.appiconset/AppIcon.png")).toString("base64");

export const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const accent = (s) => esc(s).replace(/\*(.+?)\*/g, "<em>$1</em>");
const lines = (s, tag = "span") => s.split("\n").map((l) => `<${tag} class="line">${accent(l)}</${tag}>`).join("");

// ---- アイコン (線。viewBox 24) ----
const ICONS = {
  mic: `<rect x="9" y="2.5" width="6" height="12" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"/>`,
  hash: `<path d="M9 3 7 21M17 3l-2 18M4 8.5h17M3 15.5h17"/>`,
  chat: `<path d="M4 5h16v11H9l-5 4z"/>`,
  code: `<path d="m8 7-5 5 5 5M16 7l5 5-5 5"/>`,
  siri: `<circle cx="12" cy="12" r="9"/><path d="M5 12c2-4 4 4 7 0s5 4 7 0"/>`,
  tap: `<path d="M9 11V5.5a2 2 0 0 1 4 0V11M13 9.5a2 2 0 0 1 4 0V14a7 7 0 0 1-7 7h-.5A5.5 5.5 0 0 1 4 15.5V13a2 2 0 0 1 4 0"/>`,
  watch: `<rect x="6" y="6" width="12" height="12" rx="3.5"/><path d="M8.5 6 9.5 2h5l1 4M8.5 18l1 4h5l1-4"/>`,
  key: `<circle cx="8" cy="15" r="4.5"/><path d="m11.2 11.8 8.3-8.3M16.5 6.5l2.5 2.5M14 9l2 2"/>`,
  braces: `<path d="M8 3c-2 0-3 1-3 3v3c0 1.5-1 2.5-2 3 1 .5 2 1.5 2 3v3c0 2 1 3 3 3M16 3c2 0 3 1 3 3v3c0 1.5 1 2.5 2 3-1 .5-2 1.5-2 3v3c0 2-1 3-3 3"/>`,
  wifi: `<path d="M2 9a15 15 0 0 1 20 0M5.5 12.5a10 10 0 0 1 13 0M9 16a5 5 0 0 1 6 0"/><circle cx="12" cy="19.5" r="1"/>`,
  antenna: `<path d="M12 10v11M8 21h8"/><circle cx="12" cy="8" r="2"/><path d="M7.5 3.5a6.5 6.5 0 0 0 0 9M16.5 3.5a6.5 6.5 0 0 1 0 9"/>`,
  inbox: `<path d="M3 13h5l1.5 3h5L16 13h5M5 5h14l2 8v6H3v-6z"/>`,
  retry: `<path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7"/>`,
  clock: `<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>`,
  check: `<circle cx="12" cy="12" r="9"/><path d="m8 12.5 2.8 2.8L16 9.8"/>`,
  id: `<rect x="3" y="5" width="18" height="14" rx="3"/><path d="M7 9v6M11 9h2.5a3 3 0 0 1 0 6H11z"/>`,
  link: `<path d="M10 14a4.5 4.5 0 0 0 6.4 0l3-3a4.5 4.5 0 0 0-6.4-6.4l-1 1M14 10a4.5 4.5 0 0 0-6.4 0l-3 3a4.5 4.5 0 0 0 6.4 6.4l1-1"/>`,
  server: `<rect x="4" y="3" width="16" height="7" rx="2"/><rect x="4" y="14" width="16" height="7" rx="2"/><path d="M8 6.5h.01M8 17.5h.01"/>`,
  phone: `<rect x="7" y="2" width="10" height="20" rx="2.5"/><path d="M11 18h2"/>`,
  checklist: `<path d="m3.5 6 1.8 1.8L8.5 4.5M3.5 13l1.8 1.8 3.2-3.3M11.5 6.5h9M11.5 13.5h9M11.5 19.5h9M4 19.5h3"/>`,
  doc: `<path d="M6 2.5h8l4.5 4.5v14.5H6z"/><path d="M14 2.5V7h4.5M9 12h6.5M9 16h6.5"/>`,
  note: `<rect x="4" y="3" width="16" height="18" rx="3"/><path d="M8 8h8M8 12h8M8 16h5"/>`,
  plane: `<path d="M21.5 2.5 2.5 10l7.5 3.5L13.5 21z"/><path d="m10 13.5 4.5-4.5"/>`,
  copy: `<rect x="8" y="8" width="12" height="13" rx="2.5"/><path d="M16 8V5.5A2.5 2.5 0 0 0 13.5 3h-7A2.5 2.5 0 0 0 4 5.5v8A2.5 2.5 0 0 0 6.5 16H8"/>`,
  share: `<path d="M12 15V3M7.5 7.5 12 3l4.5 4.5M8 10.5H6v10.5h12V10.5h-2"/>`,
  trash: `<path d="M4 6.5h16M9.5 6.5V4h5v2.5M6.5 6.5l1 14h9l1-14M10 10.5v6.5M14 10.5v6.5"/>`,
  pencil: `<path d="M4 20h4L19.5 8.5a2.8 2.8 0 0 0-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>`,
  book: `<path d="M12 6.5C10 4.5 6.5 4 3 4.5v14c3.5-.5 7 0 9 2 2-2 5.5-2.5 9-2v-14c-3.5-.5-7 0-9 2zM12 6.5v14"/>`,
  connect: `<circle cx="12" cy="5" r="2.5"/><circle cx="5" cy="18.5" r="2.5"/><circle cx="19" cy="18.5" r="2.5"/><path d="M10.8 7.2 6.2 16.3M13.2 7.2l4.6 9.1M7.5 18.5h9" stroke-dasharray="2 2.4"/>`,
  globe: `<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.6 2.6 3.8 5.6 3.8 9s-1.2 6.4-3.8 9c-2.6-2.6-3.8-5.6-3.8-9S9.4 5.6 12 3z"/>`,
  shield: `<path d="M12 2.5 4.5 5.5v6c0 4.8 3.2 8.6 7.5 10 4.3-1.4 7.5-5.2 7.5-10v-6z"/><path d="m8.5 12 2.5 2.5 4.5-5"/>`,
  github: `<path d="M9 19c-4.3 1.4-4.3-2.5-6-3m12 5v-3.5c0-1 .1-1.4-.5-2 2.8-.3 5.5-1.4 5.5-6a4.6 4.6 0 0 0-1.3-3.2 4.2 4.2 0 0 0-.1-3.2s-1.1-.3-3.5 1.3a12.3 12.3 0 0 0-6.2 0C6.5 2.8 5.4 3.1 5.4 3.1a4.2 4.2 0 0 0-.1 3.2A4.6 4.6 0 0 0 4 9.5c0 4.6 2.7 5.7 5.5 6-.6.6-.6 1.2-.5 2V21"/>`,
};
const icon = (name, size, color, width = 2) =>
  `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round">${ICONS[name]}</svg>`;

// SF Symbols に似せた塗りのアイコン (画面の中で使う)
const SYM = {
  paperplane: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path d="M22 2 2.2 10.3l7.6 3.9L13.7 22z" fill="${c}"/><path d="m9.8 14.2 5.4-5.4" stroke="rgba(76,29,149,.55)" stroke-width="1.4" stroke-linecap="round"/></svg>`,
  mic: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><rect x="8" y="1.5" width="8" height="13.5" rx="4" fill="${c}"/><path d="M4.8 11.2a7.2 7.2 0 0 0 14.4 0M12 18.4v3.4" stroke="${c}" stroke-width="2.2" fill="none" stroke-linecap="round"/></svg>`,
  checkFill: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><circle cx="12" cy="12" r="11" fill="${c}"/><path d="m7 12.4 3.3 3.3L17.2 8.8" stroke="#000" stroke-width="2.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  chevronRight: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path d="m9 4 8 8-8 8" stroke="${c}" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  chevronLeft: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path d="M15 4 7 12l8 8" stroke="${c}" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  check: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path d="m4 12.5 5 5L20 6.5" stroke="${c}" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  updown: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path d="m7 9 5-5 5 5M7 15l5 5 5-5" stroke="${c}" stroke-width="2.4" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  clock: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.5 12A8.5 8.5 0 1 1 18 6"/><path d="M20.5 3.5V8h-4.5M12 7.5V12l3 2"/></svg>`,
  note: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="3" width="16" height="18" rx="3"/><path d="M8 8h8M8 12h8M8 16h5"/></svg>`,
  plus: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path d="M12 4v16M4 12h16" stroke="${c}" stroke-width="2.6" stroke-linecap="round"/></svg>`,
  eye: (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24"><path d="M1.5 12S5.5 5 12 5s10.5 7 10.5 7-4 7-10.5 7S1.5 12 1.5 12z" stroke="${c}" stroke-width="2" fill="none"/><circle cx="12" cy="12" r="3.4" fill="${c}"/></svg>`,
};

// ---- 背景 (夜空) ----
// 星の位置は毎回同じにする (生成し直しても同じ画像になるように)
function stars(w, h, count, seed) {
  let s = seed;
  const rand = () => ((s = (s * 1103515245 + 12345) % 2147483648) / 2147483648);
  let out = "";
  for (let i = 0; i < count; i++) {
    const x = rand() * w, y = rand() * h, r = 1.2 + rand() * 3.2, o = 0.25 + rand() * 0.6;
    out += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${r.toFixed(1)}" fill="#fff" opacity="${o.toFixed(2)}"/>`;
  }
  return out;
}
const sparkle = (x, y, r, color = "#FDE68A") =>
  `<path transform="translate(${x} ${y}) scale(${r / 60})" d="M0 -60 Q6 -6 60 0 Q6 6 0 60 Q-6 6 -60 0 Q-6 -6 0 -60Z" fill="${color}"/>`;
const sky = (w, h, seed) => `<svg class="sky" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0.35" y2="1"><stop offset="0" stop-color="#0B1026"/><stop offset=".55" stop-color="#1E1150"/><stop offset="1" stop-color="#3B1782"/></linearGradient>
    <radialGradient id="glow" cx=".5" cy=".55" r=".5"><stop offset="0" stop-color="#8B5CF6" stop-opacity=".45"/><stop offset="1" stop-color="#8B5CF6" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="${w}" height="${h}" fill="url(#bg)"/>
  <ellipse cx="${w / 2}" cy="${h * 0.52}" rx="${w * 0.85}" ry="${h * 0.32}" fill="url(#glow)"/>
  ${stars(w, h, 90, seed)}
  ${sparkle(w * 0.1, h * 0.06, 34)}${sparkle(w * 0.92, h * 0.33, 22, "#C4B5FD")}${sparkle(w * 0.07, h * 0.7, 18, "#C4B5FD")}
</svg>`;

// ---- アプリの中の夜空 (Shared/Cosmos.swift の CosmicBackground: night → deep → nebula、白い星と黄色の 4 つ角の星) ----
const appSky = (w, h, count, seed) => {
  let s = seed;
  const rand = () => ((s = (s * 1103515245 + 12345) % 2147483648) / 2147483648);
  let dots = "";
  for (let i = 0; i < count; i++) {
    const x = rand() * w, y = rand() * h, r = 0.6 + rand() * 1.4, o = 0.3 + rand() * 0.55;
    dots += i % 13 === 5 ? sparkle(x, y, 5 + r * 3, "#FDE68A") : `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${r.toFixed(2)}" fill="#fff" opacity="${o.toFixed(2)}"/>`;
  }
  return `<svg class="appsky" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><defs><linearGradient id="as${seed}" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#0C1024"/><stop offset=".5" stop-color="#1C1244"/><stop offset="1" stop-color="#2E1162"/></linearGradient></defs>
    <rect width="${w}" height="${h}" fill="url(#as${seed})"/>${dots}</svg>`;
};

// ---- Apple Watch の画面 (416x496 の CSS px = 208x248 pt の 2 倍で描く) ----
const WATCH_CSS = `
  .ws { position: relative; width: 416px; height: 496px; color: #fff; overflow: hidden;
    font-family: "SF Compact Text", "SF Compact", var(--cjk), sans-serif; }
  .ws .appsky, .ps .appsky { position: absolute; inset: 0; }
  .ws .bar { position: absolute; left: 26px; right: 30px; top: 22px; height: 56px; display: flex; align-items: center; justify-content: space-between; gap: 12px; z-index: 2; }
  .ws .title { font-family: "SF Compact Display", var(--cjk); font-size: 34px; font-weight: 600; display: flex; align-items: center; gap: 12px; min-width: 0; white-space: nowrap; }
  .ws .title .back { flex: none; }
  .ws .title .tt { min-width: 0; overflow: hidden; }
  .ws .time { flex: none; }
  .ws .back { width: 56px; height: 56px; border-radius: 50%; background: rgba(255,255,255,.16); display: flex; align-items: center; justify-content: center; }
  .ws .time { font-family: "SF Compact Display", var(--cjk); font-size: 34px; font-weight: 600; margin-inline-start: auto; }
  .ws .orbwrap { position: absolute; left: 50%; top: 88px; width: 168px; height: 168px; margin-left: -84px; }
  .ws .ring { position: absolute; inset: 0; border-radius: 50%; border: 3px solid rgba(196,181,253,.5); }
  .ws .orb { position: absolute; inset: 0; border-radius: 50%; background: linear-gradient(45deg,#8B5CF6,#C4B5FD); box-shadow: 0 0 22px rgba(139,92,246,.9), inset 0 0 0 2px rgba(255,255,255,.35);
    display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; font-size: 26px; font-weight: 700; }
  .ws .status { position: absolute; left: 16px; right: 16px; top: 298px; overflow: hidden; text-align: center; font-size: 23px; font-weight: 500; white-space: nowrap; color: #FDE68A; display: flex; align-items: center; justify-content: center; gap: 8px; }
  .ws .destwrap { position: absolute; left: 24px; right: 24px; top: 350px; display: flex; justify-content: center; }
  .ws .destlabel { display: flex; align-items: center; gap: 10px; max-width: 100%; overflow: hidden; white-space: nowrap; font-size: 28px; color: #C4B5FD; }
  .ws .dest { white-space: nowrap; }
  .ws .destlabel svg { flex: none; }
  .ws .pager { position: absolute; right: 8px; top: 92px; display: flex; flex-direction: column; align-items: center; gap: 8px; }
  .ws .pager i { width: 10px; height: 10px; border-radius: 5px; background: rgba(255,255,255,.4); }
  .ws .pager i.on { height: 40px; background: #fff; }
  .ws .ptitle { position: absolute; right: 30px; top: 74px; font-family: "SF Compact Display", var(--cjk); font-size: 34px; font-weight: 600; color: rgba(196,181,253,.75); white-space: nowrap; }
  .ws .status svg { flex: none; }
  .ws .orbtext { max-width: 136px; overflow: hidden; white-space: nowrap; }
  .ws .rows { position: absolute; left: 14px; right: 14px; top: 92px; display: flex; flex-direction: column; gap: 10px; }
  .ws .row { background: rgba(34,27,72,.96); border-radius: 28px; padding: 18px 24px; }
  .ws .row b { display: block; font-size: 31px; font-weight: 500; line-height: 1.25; }
  .ws .row small { display: block; margin-top: 6px; font-size: 25px; color: rgba(196,181,253,.8); }
  .ws .row b { display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
  .ws .row .sum { display: flex; align-items: center; gap: 8px; }
  .ws .row .sum svg { flex: none; }
  .ws .plain { padding: 4px 14px 8px; }
  .ws .plain b { display: block; font-size: 31px; font-weight: 500; line-height: 1.25; }
  .ws .plain small { display: block; margin-top: 6px; font-size: 23px; color: rgba(235,235,245,.6); }
  .ws .row.dl { padding: 14px 24px; border-radius: 24px; }
  .ws .row.dl b { font-size: 27px; }
  .ws .row.dl small { margin-top: 2px; font-size: 23px; }
  .ws .siri { position: absolute; left: 28px; right: 28px; top: 96px; }
  .ws .siri .app { display: flex; align-items: center; gap: 12px; font-size: 24px; font-weight: 600; letter-spacing: .04em; color: #9a9aa0; }
  .ws .siri .app img { width: 40px; height: 40px; border-radius: 50%; }
  .ws .siri p { margin-top: 18px; font-family: "SF Compact Display", var(--cjk); font-size: 40px; font-weight: 600; line-height: 1.3; word-break: keep-all; }
  .ws .siriorb { position: absolute; left: 50%; bottom: -150px; width: 300px; height: 300px; margin-left: -150px; border-radius: 50%;
    background: radial-gradient(circle at 50% 40%, #fff 0, #7dd3fc 14%, #a78bfa 34%, #f472b6 52%, rgba(244,114,182,0) 70%); opacity: .9; }
  .ws.black { background: #000; }
`;

const watchBar = (title, { back = false } = {}) => `<div class="bar">${title ? `<div class="title">${back ? `<span class="back">${SYM.chevronLeft(28, "#fff")}</span>` : ""}<span class="tt">${esc(title)}</span></div>` : ""}<div class="time">10:09</div></div>`;
const paperplaneLine = (s, c) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="1.8" stroke-linejoin="round"><path d="M21.5 2.5 2.5 10l7.5 3.5L13.5 21z"/><path d="m10 13.5 4.5-4.5"/></svg>`;
/** 縦のページの位置 (メモする画面の下にメモの一覧がある。WatchHomeView の TabView(.verticalPage)) */
const pager = (page) => `<div class="pager">${[0, 1].map((i) => `<i${i === page ? ' class="on"' : ""}></i>`).join("")}</div>`;
/** メモの一覧の状態 (Memo.Summary の label / symbol) */
const summaryLine = (t, kind) => {
  const sym = { sent: SYM.checkFill(24, "#C4B5FD"), waiting: SYM.clock(24, "#C4B5FD"), memo: SYM.note(24, "#C4B5FD") }[kind];
  return `<small class="sum">${sym}<span>${esc(t.summary[kind])}</span></small>`;
};

export const watchScreens = {
  /** メモした直後のホーム (WatchHomeView: 光るメモのボタン・「保存して送りました」・有効な送り先の件数。メモの一覧は下のページ) */
  home: (t) => `<div class="ws">${appSky(416, 496, 26, 5)}${watchBar("")}
    <div class="orbwrap"><div class="ring" style="transform:scale(1.25);opacity:.75"></div><div class="ring" style="transform:scale(1.45);opacity:.3"></div>
      <div class="orb">${SYM.paperplane(58, "#fff")}<span class="orbtext">${esc(t.memoButton)}</span></div></div>
    <div class="status">${SYM.checkFill(28, "#FDE68A")}${esc(t.savedAndSent)}</div>
    <div class="destwrap"><div class="destlabel">${paperplaneLine(30, "#C4B5FD")}<span class="dest">${esc(t.destinationCount)}</span></div></div>
    ${pager(0)}</div>`,
  /** 時計のメモの一覧 (WatchHistoryView: ホームの下のページ。本文と状態) */
  memos: (t) => `<div class="ws">${appSky(416, 496, 26, 9)}${watchBar("")}<div class="ptitle">${esc(t.memosTitle)}</div>
    <div class="rows" style="top:140px">
      ${[[t.spoken[0], "sent"], [t.reminderSpoken, "sent"], [t.spoken[1], "waiting"]].map(([text, kind]) =>
        `<div class="row"><b>${esc(text)}</b>${summaryLine(t, kind)}</div>`).join("")}
    </div>${pager(1)}</div>`,
  /** 1 件のメモと連携ごとの状態 (WatchMemoDetailView) */
  detail: (t) => `<div class="ws">${appSky(416, 496, 26, 13)}${watchBar(t.memosTitle, { back: true })}
    <div class="rows">
      <div class="plain"><b>${esc(t.spoken[0])}</b><small>${esc(t.date)}</small></div>
      ${t.destinations.slice(0, 3).map((d) =>
        `<div class="row dl"><b>${esc(d)}</b><small>${esc(t.status.done)}</small></div>`).join("")}
    </div></div>`,
  /** Siri の返事 (SendTextIntent の dialog)。Siri の画面なので背景は黒 */
  siri: (t) => `<div class="ws black">${watchBar("")}
    <div class="siri"><div class="app"><img src="data:image/png;base64,${ICON_PNG}">${esc(t.appName.toUpperCase())}</div><p>${esc(t.siriDialog)}</p></div>
    <div class="siriorb"></div></div>`,
};


// Watch の画面の 1 行の文字 (送信結果・送り先・履歴の見出し・見出し・話す) は、収まらなければ字を小さくする。
// 縮めても収まらないものは window.__watchOverflow に残し、index.mjs が生成を止める
const WATCH_FIT = `<script>
  window.__watchOverflow = [];
  document.querySelectorAll(".ws .status, .ws .destlabel, .ws .ptitle, .ws .orbtext, .ws .title .tt").forEach(function (el) {
    var over = function () { return el.scrollWidth > el.clientWidth + 1; };
    var size = parseFloat(getComputedStyle(el).fontSize), min = size * 0.6;
    while (over() && size > min) { size -= 1; el.style.fontSize = size + "px"; }
    if (over()) window.__watchOverflow.push(el.className + ": " + el.textContent.trim());
  });
</script>`;

// ---- iPhone の画面 (402x874 pt の CSS px で描き、端末の中で拡大する。ダーク固定) ----
const PHONE_CSS = `
  .ps { position: relative; width: 402px; height: 874px; color: #fff; overflow: hidden;
    font-family: -apple-system, "SF Pro Text", var(--cjk), sans-serif; font-size: 17px; }
  .ps > *:not(.appsky) { position: relative; }
  .ps .status { height: 54px; display: flex; align-items: center; justify-content: space-between; padding: 6px 34px 0 46px; font-weight: 600; font-size: 17px; }
  .ps .status .r { display: flex; gap: 6px; align-items: center; }
  .ps .nav { height: 72px; display: flex; align-items: center; justify-content: space-between; padding: 8px 10px 0; }
  .ps .nav .t { font-weight: 600; font-size: 17px; }
  .ps .glass { height: 46px; padding: 0 18px; border-radius: 23px; background: rgba(120,110,170,.38); box-shadow: inset 0 0 0 1px rgba(255,255,255,.12); display: flex; align-items: center; font-size: 17px; font-weight: 600; color: #C4B5FD; }
  .ps .sec { margin: 0 16px; }
  .ps .sh { font-size: 15px; font-weight: 600; color: rgba(235,235,245,.6); padding: 16px 12px 8px; }
  .ps .sf { font-size: 12.5px; color: rgba(235,235,245,.6); padding: 8px 12px 0; line-height: 1.45; }
  .ps .grp { background: rgba(34,27,72,.96); border-radius: 26px; overflow: hidden; box-shadow: inset 0 0 0 1px rgba(255,255,255,.12); }
  .ps .cell { min-height: 52px; padding: 14px 20px; display: flex; align-items: center; justify-content: space-between; position: relative; }
  .ps .cell + .cell::before { content: ""; position: absolute; left: 20px; right: 20px; top: 0; height: 1px; background: rgba(255,255,255,.12); }
  .ps .v { color: #C4B5FD; display: flex; align-items: center; gap: 4px; }
  .ps .accent { color: #C4B5FD; }
  .ps .mono { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 13px; white-space: pre; line-height: 1.5; }
  .ps .toggle { width: 51px; height: 31px; border-radius: 16px; background: #8B5CF6; position: relative; flex: none; }
  .ps .toggle.off { background: rgba(120,120,128,.36); }
  .ps .toggle.off::after { right: auto; left: 2px; }
  .ps .round { width: 46px; padding: 0; justify-content: center; }
  .ps .large { font-size: 34px; font-weight: 700; padding: 0 26px 4px; }
  .ps .hl { font-weight: 600; font-size: 17px; }
  .ps .cap { font-size: 12.5px; color: rgba(235,235,245,.6); margin-top: 3px; line-height: 1.35; }
  .ps .cap.lav { color: rgba(196,181,253,.75); }
  .ps .cell.sub { font-size: 12.5px; color: rgba(235,235,245,.6); min-height: 40px; padding-top: 6px; }
  .ps .cell.sub::before { display: none; }
  .ps .ok { font-size: 12.5px; color: #4ADE80; }
  .ps .badge { width: 34px; height: 34px; border-radius: 50%; flex: none; display: flex; align-items: center; justify-content: center;
    background: linear-gradient(45deg,#8B5CF6,#C4B5FD); box-shadow: 0 0 8px rgba(139,92,246,.6); }
  .ps .tabbar { position: absolute !important; left: 22px; right: 22px; bottom: 26px; height: 62px; border-radius: 31px; display: flex; align-items: center; padding: 0 6px;
    background: rgba(40,32,80,.82); box-shadow: inset 0 0 0 1px rgba(255,255,255,.14), 0 8px 24px rgba(0,0,0,.35); }
  .ps .tab { flex: 1; height: 52px; border-radius: 26px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; font-size: 10px; font-weight: 600; white-space: nowrap; overflow: hidden; }
  .ps .tab.on { background: rgba(255,255,255,.12); color: #C4B5FD; }
  .ps .toggle::after { content: ""; position: absolute; right: 2px; top: 2px; width: 27px; height: 27px; border-radius: 50%; background: #fff; box-shadow: 0 2px 4px rgba(0,0,0,.2); }
`;
const statusBar = () => `<div class="status"><span>9:41</span><span class="r" style="fill:#fff">
  <svg width="19" height="12" viewBox="0 0 19 12"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>
  <svg width="17" height="12" viewBox="0 0 17 12"><path d="M8.5 2.5a10 10 0 0 1 7 2.8l1.2-1.3A11.8 11.8 0 0 0 8.5.7 11.8 11.8 0 0 0 .3 4l1.2 1.3a10 10 0 0 1 7-2.8zm0 3.6a6.4 6.4 0 0 1 4.5 1.8l1.2-1.3a8.2 8.2 0 0 0-11.4 0L4 7.9a6.4 6.4 0 0 1 4.5-1.8zm0 3.6c.8 0 1.5.3 2 .8L8.5 12.6 6.5 10.5c.5-.5 1.2-.8 2-.8z"/></svg>
  <svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.5" fill="none" stroke="#fff" opacity=".4"/><rect x="2" y="2" width="20" height="9" rx="2"/><path d="M25 4.5v4a2 2 0 0 0 0-4z" opacity=".4"/></svg>
</span></div>`;

/** 下のタブ (WatchHookApp: 入力 / メモ / 連携 / 使い方)。iOS 26 の浮いたガラスのタブ */
const tabBar = (t, active) => `<div class="tabbar">${t.tabs.map((label, i) =>
  `<div class="tab${i === active ? " on" : ""}">${icon(["pencil", "note", "connect", "book"][i], 24, i === active ? "#C4B5FD" : "#fff", 2)}<span>${esc(label)}</span></div>`).join("")}</div>`;
/** 丸い光るバッジ (DestinationListView の IntegrationRow / KindBadge) */
const badge = (name) => `<span class="badge">${icon(name, 18, "#fff", 2.4)}</span>`;

export const phoneScreens = {
  /** メモの詳細 (MemoDetailView: 本文・入力した端末と日時・送り先と連携ごとの状態・後から送る / コピー / 共有 / 削除) */
  memoDetail: (t) => {
    const d = t.detail;
    const row = (sym, name, sub) => `<div class="cell" style="display:block">
      <div style="display:flex;align-items:center;gap:10px">${icon(sym, 20, "#FDE68A", 2)}<span style="flex:1">${esc(name)}</span><span class="ok">${esc(t.status.done)}</span></div>
      ${[sub ?? []].flat().map((line) => `<div class="cap">${esc(line)}</div>`).join("")}</div>`;
    return `<div class="ps">${appSky(402, 874, 46, 3)}${statusBar()}
    <div class="nav"><span class="glass round">${SYM.chevronLeft(20, "#fff")}</span><span class="t">${esc(t.memosTitle)}</span><span style="width:46px"></span></div>
    <div class="sec"><div class="grp">
      <div class="cell">${esc(t.reminderSpoken)}</div>
      <div class="cell sub"><span style="display:flex;align-items:center;gap:6px">${icon("watch", 16, "rgba(235,235,245,.6)", 2)}Apple Watch</span><span>${esc(t.date)}</span></div>
    </div></div>
    <div class="sec"><div class="sh">${esc(d.deliveries)}</div><div class="grp">
      ${t.destinations.slice(0, 3).map((name) => row("plane", name, ["HTTP 200", d.fromWatch])).join("")}
      ${row("checklist", t.reminderTarget)}
      ${row("doc", t.markdownTarget, t.markdownFile)}
    </div></div>
    <!-- 後から送る・コピー・共有・削除はこの下 (スクロールした先)。吹き出しと重ならないよう描かない -->
    ${tabBar(t, 1)}
  </div>`;
  },
  /** 「連携」タブ (DestinationListView: iPhone に保存するリマインダー・Markdown と、webhook の送り先。スイッチでオン / オフ) */
  integrations: (t) => {
    const g = t.integrations;
    const integ = (sym, title, detail) => `<div class="cell" style="justify-content:flex-start;gap:12px">${badge(sym)}<div style="flex:1;min-width:0"><div class="hl">${esc(title)}</div><div class="cap lav">${esc(detail)}</div></div>${SYM.chevronRight(14, "rgba(235,235,245,.35)")}</div>`;
    const dest = (i, on) => `<div class="cell" style="justify-content:flex-start;gap:12px">${badge(["hash", "chat", "braces", "braces"][i])}<div style="flex:1;min-width:0"><div class="hl">${esc(t.destinations[i])}</div><div class="cap lav">${esc(g.kinds[i])}</div></div><span class="toggle${on ? "" : " off"}"></span></div>`;
    return `<div class="ps">${appSky(402, 874, 46, 29)}${statusBar()}
    <div class="nav"><span></span><span class="glass round">${SYM.plus(20, "#fff")}</span></div>
    <div class="large">${esc(g.title)}</div>
    <div class="sec"><div class="sh">${esc(g.savedOnPhone)}</div><div class="grp">
      ${integ("checklist", g.reminders, g.reminderDetail)}
      ${integ("doc", g.markdown, g.markdownDetail)}
    </div></div>
    <div class="sec"><div class="sh">${esc(g.webhooks)}</div><div class="grp">
      ${[0, 1, 2, 3].map((i) => dest(i, i !== 3)).join("")}
    </div><div class="sf">${esc(g.webhooksFooter)}</div></div>
    ${tabBar(t, 2)}
  </div>`;
  },
};
// ---- 端末の枠 ----
const DEVICE_CSS = `
  .iphone { position: absolute; z-index: 5; left: 50%; width: 850px; margin-left: -425px; padding: 18px; border-radius: 120px; background: #121218;
    box-shadow: 0 60px 140px rgba(0,0,0,.55), inset 0 0 0 3px #3a3a48, 0 0 0 2px rgba(196,181,253,.25); }
  .iphone .screen { position: relative; overflow: hidden; border-radius: 102px; width: 814px; height: 1770px; }
  .iphone .screen > .ps { transform: scale(${814 / 402}); transform-origin: 0 0; }
  .iphone .island { position: absolute; left: 50%; top: 24px; width: 236px; height: 68px; margin-left: -118px; border-radius: 34px; background: #000; z-index: 2; }
  .watch { position: absolute; z-index: 5; left: 50%; }
  .watch .band { position: absolute; left: 13%; right: 13%; height: 20%; background: linear-gradient(90deg,#2a2346,#4a3f78 50%,#2a2346); }
  .watch .band.top { bottom: 94%; -webkit-mask-image: linear-gradient(to top, #000 10%, transparent 95%); }
  .watch .band.bottom { top: 94%; -webkit-mask-image: linear-gradient(to bottom, #000 10%, transparent 95%); }
  .watch .case { position: absolute; inset: 0; border-radius: 30%/26%; background: linear-gradient(145deg,#5b5868,#1d1b24 45%,#3a3846);
    box-shadow: 0 60px 120px rgba(0,0,0,.6), inset 0 0 0 3px rgba(255,255,255,.12); }
  .watch .glass { position: absolute; inset: 3.2%; border-radius: 27%/23%; background: #000; overflow: hidden; }
  .watch .glass .ws { position: absolute; transform-origin: 0 0; }
  .watch .crown { position: absolute; right: -3.6%; top: 22%; width: 5%; height: 16%; border-radius: 10px; background: linear-gradient(90deg,#2a2833,#6b6878 60%,#2a2833); }
  .watch .side { position: absolute; right: -1.6%; top: 50%; width: 2.4%; height: 18%; border-radius: 8px; background: #2a2833; }
`;

/** 時計の枠。width は本体の幅 (px)。画面は 416x496 を縮尺して入れる */
function watchDevice(screenHtml, { width, top, left }) {
  const height = Math.round(width * 1.19);
  const glassInset = width * 0.032;
  const gw = width - glassInset * 2, gh = height - glassInset * 2;
  // 画面のまわりの黒い縁 (ディスプレイの非表示部分)
  const pad = width * 0.045;
  const scale = (gw - pad * 2) / WATCH.width;
  const sh = WATCH.height * scale;
  const offY = (gh - sh) / 2;
  return `<div class="watch" style="width:${width}px;height:${height}px;top:${top}px;${left === undefined ? `margin-left:${-width / 2}px` : `left:${left}px`}">
    <div class="band top"></div><div class="band bottom"></div>
    <div class="case"></div>
    <div class="glass"><div style="position:absolute;left:${pad}px;top:${offY}px;width:${WATCH.width * scale}px;height:${sh}px;border-radius:${18 * scale}px;overflow:hidden;">
      <div style="transform:scale(${scale});transform-origin:0 0;width:${WATCH.width}px;height:${WATCH.height}px">${screenHtml}</div></div></div>
    <div class="crown"></div><div class="side"></div>
  </div>`;
}

const iphoneDevice = (screenHtml, top) => `<div class="iphone" style="top:${top}px"><div class="screen">${screenHtml}<div class="island"></div></div></div>`;


// 漢字・ハングルは言語ごとのフォントで描く (中国語・韓国語が日本語の字形にならないように)。ほかの文字は Chrome が OS のフォントを選ぶ
const CJK_FONT = { ja: '"Hiragino Sans"', "zh-Hans": '"PingFang SC"', "zh-Hant": '"PingFang TC"', ko: '"Apple SD Gothic Neo"' };
const fontVars = (lang) => `:root { --cjk: ${CJK_FONT[lang] ?? '"Hiragino Sans"'}; }`;
const RTL_LANGS = new Set(["ar", "he", "ur"]);
const htmlOpen = (lang) => `<html lang="${esc(lang)}" dir="${RTL_LANGS.has(lang) ? "rtl" : "ltr"}">`;

// ---- 1 枚の組み立て ----
const SLIDE_CSS = `
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: ${IPHONE.width}px; height: ${IPHONE.height}px; overflow: hidden; background: #0B1026; }
  body { font-family: -apple-system, "SF Pro Display", var(--cjk), sans-serif; font-synthesis: none; -webkit-font-smoothing: antialiased; }
  .slide { position: relative; width: ${IPHONE.width}px; height: ${IPHONE.height}px; overflow: hidden; }
  .sky { position: absolute; inset: 0; }
  .head { position: absolute; left: 0; right: 0; text-align: center; z-index: 10; color: #fff; }
  .head h1 { font-size: 138px; font-weight: 900; line-height: 1.16; letter-spacing: -.02em; }
  .line { display: block; white-space: nowrap; }
  em { font-style: normal; padding-bottom: .12em; background: linear-gradient(95deg,#FDE68A,#FDBA74 45%,#F9A8D4); -webkit-background-clip: text; color: transparent; }
  .chips { display: flex; justify-content: center; gap: 24px; margin-top: 80px; white-space: nowrap; }
  .chip { display: inline-flex; align-items: center; gap: 16px; border-radius: 999px; padding: 26px 44px; font-size: 56px; font-weight: 800; color: #fff;
    background: rgba(255,255,255,.1); box-shadow: inset 0 0 0 2px rgba(255,255,255,.16); }
  .closing { position: absolute; left: 0; right: 0; bottom: 96px; text-align: center; z-index: 30; color: #fff; font-size: 88px; font-weight: 900; line-height: 1.24; letter-spacing: -.01em; }
  .fade { position: absolute; left: 0; right: 0; bottom: 0; height: 640px; z-index: 20; background: linear-gradient(to bottom, rgba(59,23,130,0), #2f1470 45%, #34167a); }
  .float { position: absolute; z-index: 25; display: inline-flex; align-items: center; gap: 18px; border-radius: 999px; padding: 28px 44px; font-size: 50px; font-weight: 800;
    white-space: nowrap; color: #1b1340; background: #fff; box-shadow: 0 20px 50px rgba(0,0,0,.35); }
  .float.warm { background: linear-gradient(95deg,#FDE68A,#FDBA74); }
  .float.violet { background: #EDE9FE; }
  .bubble { position: absolute; z-index: 25; max-width: 1000px; padding: 34px 50px; border-radius: 60px; font-size: 54px; font-weight: 800; white-space: nowrap; box-shadow: 0 20px 50px rgba(0,0,0,.35); }
  .bubble.me { background: #fff; color: #1b1340; border-bottom-right-radius: 14px; }
  .bubble.siri { background: rgba(255,255,255,.12); color: #fff; box-shadow: inset 0 0 0 2px rgba(255,255,255,.18), 0 20px 50px rgba(0,0,0,.3); border-bottom-left-radius: 14px; }
  .card { position: absolute; z-index: 25; left: 110px; right: 110px; border-radius: 56px; padding: 46px 56px; background: rgba(13,10,38,.82); color: #fff;
    box-shadow: inset 0 0 0 2px rgba(196,181,253,.3), 0 30px 70px rgba(0,0,0,.4); font-family: ui-monospace, "SF Mono", Menlo, var(--cjk), monospace; }
  .card .req { display: flex; align-items: center; gap: 20px; font-size: 38px; color: #C9C2F2; }
  .card .verb { padding: 6px 18px; border-radius: 14px; background: #8B5CF6; color: #fff; font-weight: 700; }
  .card pre { margin-top: 26px; font-size: 44px; line-height: 1.45; font-family: inherit; }
  .card .key { color: #C4B5FD; } .card .str { color: #FDE68A; }
  .card .res { position: absolute; right: 50px; top: 44px; display: flex; align-items: center; gap: 12px; font-size: 38px; font-weight: 700; color: #4ADE80; }
  .card.fan { font-family: -apple-system, "SF Pro Text", var(--cjk), sans-serif; padding: 40px 56px 30px; }
  .card.fan .memo { display: flex; align-items: center; gap: 22px; font-size: 48px; font-weight: 700; padding-bottom: 26px; margin-bottom: 8px; border-bottom: 2px solid rgba(196,181,253,.22); white-space: nowrap; }
  .card.fan .drow { display: flex; align-items: center; gap: 22px; font-size: 42px; padding: 14px 0; white-space: nowrap; }
  .card.fan .dn { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; }
  .card.fan .dok { display: flex; align-items: center; gap: 10px; color: #4ADE80; font-weight: 700; font-size: 38px; }
  .card svg { flex: none; }
  .grid { position: absolute; left: 80px; right: 80px; z-index: 5; display: grid; grid-template-columns: 1fr 1fr; gap: 40px; }
  .grid .cell { border-radius: 64px; padding: 54px 20px 40px; height: 400px; text-align: center; background: rgba(255,255,255,.08); box-shadow: inset 0 0 0 2px rgba(255,255,255,.14); }
  .grid .tile { width: 132px; height: 132px; border-radius: 38px; margin: 0 auto 30px; display: flex; align-items: center; justify-content: center; background: rgba(196,181,253,.16); }
  .grid b { font-size: 50px; font-weight: 800; line-height: 1.3; color: #fff; }
  .appicon { position: absolute; left: 50%; width: 220px; height: 220px; margin-left: -110px; border-radius: 22.5%; box-shadow: 0 24px 60px rgba(0,0,0,.5), 0 0 0 2px rgba(196,181,253,.3); z-index: 5; }
  ${WATCH_CSS}
  ${PHONE_CSS}
  ${DEVICE_CSS}
  /* 右から左の言語: 縮小して入れる画面の置き場は左から右のまま (右寄せになると端末からはみ出す)。画面の中身だけ右から左にする。コードのカードは左から右 */
  .iphone .screen, .watch .glass, .watch .glass > div, .watch .glass > div > div, .card, .ps .mono { direction: ltr; }
  [dir=rtl] .ps, [dir=rtl] .ws { direction: rtl; }
`;

// 見出しが横に収まらないときは字を小さくする (行ごとではなく要素全体で揃える)。縮めすぎた言語は index.mjs が止める
const FIT = `<script>
  window.__fit = [];
  document.querySelectorAll(".head h1, .closing").forEach(function (el) {
    var size = parseFloat(getComputedStyle(el).fontSize), start = size;
    var over = function () {
      var parts = el.querySelectorAll(".line"); if (!parts.length) parts = [el];
      return [].some.call(parts, function (l) { var r = document.createRange(); r.selectNodeContents(l); return r.getBoundingClientRect().width > ${IPHONE.width} - 100; });
    };
    while (over() && size > 20) { size -= 2; el.style.fontSize = size + "px"; }
    window.__fit.push({ cls: el.className || el.tagName, start: start, size: size });
  });
  document.querySelectorAll(".chips").forEach(function (el) {
    var w = [].reduce.call(el.children, function (a, c) { return a + c.offsetWidth + 24; }, -24);
    if (w > ${IPHONE.width} - 160) el.style.zoom = (${IPHONE.width} - 160) / w;  // 左右に 80px ずつ空ける
  });
</script>`;

const CHIP_ICONS = { hero: ["note", "link", "checklist"], siri: ["siri", "tap", "watch"], integrations: ["link", "doc", "book"] };
const head = (c, key, top) => `<div class="head" style="top:${top}px"><h1>${lines(c.h1)}</h1>
  ${c.chips ? `<div class="chips">${c.chips.map((label, i) => `<span class="chip">${icon(CHIP_ICONS[key][i], 62, "#FDE68A")}${esc(label)}</span>`).join("")}</div>` : ""}</div>`;
const closing = (s) => `<div class="fade"></div><div class="closing">${lines(s)}</div>`;

const page = (body, seed, lang) => `<!doctype html>${htmlOpen(lang)}<head><meta charset="utf-8"><style>${fontVars(lang)}${SLIDE_CSS}</style></head>
<body><div class="slide">${sky(IPHONE.width, IPHONE.height, seed)}${body}</div>${FIT}${WATCH_FIT}</body></html>`;

/** iPhone のスクショ 1 枚の HTML */
export function iphoneSlide(key, copy, lang = "ja") {
  const c = copy.iphone[key];
  const t = copy.screen;
  switch (key) {
    case "hero": {
      // 話す → メモに保存 → オンにした連携へ。カードは送り先・連携ごとの結果 (MemoDetailView の「送り先・連携」と同じ並び)
      const done = (sym, name) => `<div class="drow">${icon(sym, 46, "#FDE68A", 2.2)}<span class="dn">${esc(name)}</span><span class="dok">${icon("check", 40, "#4ADE80", 2.6)}${esc(t.status.done)}</span></div>`;
      return page(`${head(c, key, 200)}
        ${watchDevice(watchScreens.home(t), { width: 700, top: 930 })}
        <div class="bubble me" style="top:860px;left:70px">${icon("mic", 50, "#8B5CF6", 2.4)} ${esc(t.spoken[0])}</div>
        <div class="card fan" style="top:1930px">
          <div class="memo">${icon("note", 48, "#C4B5FD", 2.2)}<span>${esc(t.spoken[0])}</span></div>
          ${t.destinations.slice(0, 3).map((name) => done("plane", name)).join("")}
        </div>
        ${closing(c.closing)}`, 7, lang);
    }
    case "siri":
      return page(`${head(c, key, 200)}
        ${watchDevice(watchScreens.siri(t), { width: 640, top: 900 })}
        <div class="bubble me" style="top:1830px;right:90px">${esc(t.quote[0] + t.siriAsk + t.quote[1])}</div>
        <div class="bubble siri" style="top:2010px;left:90px">${esc(t.siriQuestion)}</div>
        <div class="bubble me" style="top:2190px;right:90px">${esc(t.quote[0] + t.spoken[0] + t.quote[1])}</div>
        ${closing(c.closing)}`, 11, lang);
    case "reminder":
      return page(`${head(c, key, 200)}
        <div class="bubble me" style="top:600px;left:70px">${icon("mic", 50, "#8B5CF6", 2.4)} ${esc(t.reminderSpoken)}</div>
        ${iphoneDevice(phoneScreens.memoDetail(t), 800)}
        <div class="float warm" style="top:1250px;right:30px">${icon("checklist", 54, "#1b1340", 2.4)}${esc(c.floats[0])}</div>
        <div class="float violet" style="top:2235px;left:30px">${icon("phone", 54, "#5b21b6", 2.4)}${esc(c.floats[1])}</div>
        ${closing(c.closing)}`, 19, lang);
    case "integrations":
      return page(`${head(c, key, 200)}
        ${iphoneDevice(phoneScreens.integrations(t), 800)}
        <div class="float warm" style="top:950px;left:30px">${icon("doc", 54, "#1b1340", 2.4)}${esc(c.floats[0])}</div>
        <div class="float violet" style="top:2290px;left:30px">${icon("plane", 54, "#5b21b6", 2.4)}${esc(c.floats[1])}</div>
        ${closing(c.closing)}`, 23, lang);
    case "more":
      return page(`${head(c, key, 200)}
        <img class="appicon" style="top:640px" src="data:image/png;base64,${ICON_PNG}">
        <div class="grid" style="top:960px">${c.cells.map((label, i) => `<div class="cell"><div class="tile">${icon(["inbox", "key", "github", "retry", "shield", "globe"][i], 78, "#FDE68A", 2)}</div><b>${esc(label).replace(/\n/g, "<br>")}</b></div>`).join("")}</div>
        ${closing(c.closing)}`, 43, lang);
    default:
      throw new Error(`unknown slide ${key}`);
  }
}

/** Apple Watch のスクショ 1 枚の HTML (画面だけ) */
export function watchSlide(key, copy, lang = "ja") {
  return `<!doctype html>${htmlOpen(lang)}<head><meta charset="utf-8"><style>${fontVars(lang)}* { margin: 0; padding: 0; box-sizing: border-box; } html, body { width: ${WATCH.width}px; height: ${WATCH.height}px; background: #000; overflow: hidden; -webkit-font-smoothing: antialiased; } ${WATCH_CSS}</style></head>
<body>${watchScreens[key](copy.screen)}${WATCH_FIT}</body></html>`;
}

export const IPHONE_SLIDES = ["hero", "siri", "reminder", "integrations", "more"];
export const WATCH_SLIDES = ["home", "memos", "detail"];
