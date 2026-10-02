// Shared state and copy for the three concept mocks.
// Query: ?l=en|zh  &s=title|first|settings  &fresh=1
// Copy is the shipped locale text unless marked PROPOSED (README §9).
const Q = new URLSearchParams(location.search);
const LANG = Q.get("l") === "zh" ? "zh" : "en";
const STATE = Q.get("s") || "title";
const FRESH = Q.get("fresh") === "1" || STATE === "first";
// Stage size comes from the query (render.sh passes it): headless Chrome's
// viewport is shorter than its window, so 100vh would lie.
const SW = +Q.get("w") || innerWidth, SH = +Q.get("h") || innerHeight;
const SHAPE = SW < 1000 ? "phone" : "pad";
document.documentElement.style.setProperty("--sw", SW + "px");
document.documentElement.style.setProperty("--sh", SH + "px");

const COPY = {
  en: {
    back: "Back to the Road", backSub: "Act 2 · Waystone 4",      // ui.menu.backToRoad, ui.hud.actWaystone
    rekindle: "Rekindle", vigil: "The Vigil", help: "How to Play",
    settings: "Settings", credits: "Credits", quit: "Quit",
    deeds: ["XII pilgrimages", "III dawns", "CCXIV slain", "IV secrets"], // ui.brand.stats, numerals PROPOSED
    langEn: "English", langZh: "繁體中文",
    diag: "If the game breaks, it sends crash diagnostics so the road can be mended.", // PROPOSED ui.firstLight.diagnostics
    privacy: "Privacy Policy",
    sAudio: "Audio", sDisplay: "Display", sMotion: "Motion", sPrivacy: "Privacy", sLedger: "The Ledger",
    master: "Master", music: "Music", sfx: "SFX", mute: "Mute", lang: "Language",
    reduce: "Reduce Motion", shake: "Screen Shake", diagT: "Send Crash Diagnostics",
    erase: "Erase All Progress", fullscreen: "Fullscreen", vsync: "Vsync",
  },
  zh: {
    back: "返回路上", backSub: "第 2 幕 · 第 4 塊引路石",
    rekindle: "續火", vigil: "守夜", help: "玩法說明",
    settings: "設定", credits: "製作人員", quit: "離開",
    deeds: ["十二次朝聖", "三次破曉", "二百一十四敵隕落", "四個秘密已現"],
    langEn: "English", langZh: "繁體中文",
    diag: "遊戲若出錯，會傳送當機診斷資料，好讓這條路得以修補。",
    privacy: "私隱政策",
    sAudio: "音訊", sDisplay: "顯示", sMotion: "動態", sPrivacy: "私隱", sLedger: "總帳",
    master: "主音量", music: "音樂", sfx: "音效", mute: "靜音", lang: "語言",
    reduce: "減少動態", shake: "畫面震動", diagT: "傳送當機診斷資料",
    erase: "抹除全部進度", fullscreen: "全螢幕", vsync: "垂直同步",
  },
}[LANG];

document.body.classList.add(LANG, SHAPE, "s-" + STATE);
if (FRESH) document.body.classList.add("fresh");
document.documentElement.lang = LANG === "zh" ? "zh-Hant" : "en";

const WORDMARK = LANG === "zh" ? "../../../assets/art/title/title-zh.png" : "../../../assets/art/title/title.png";

// Fill every [data-t] node with its copy key.
function fillCopy(root = document) {
  root.querySelectorAll("[data-t]").forEach((n) => { n.textContent = COPY[n.dataset.t]; });
}

// Position helper: el, {x, y, w, h} in stage px, anchor "c" centres on x.
function place(el, r) {
  for (const [k, v] of Object.entries(r)) {
    if (k === "x") el.style.left = v + "px";
    else if (k === "y") el.style.top = v + "px";
    else if (k === "w") el.style.width = v + "px";
    else if (k === "h") el.style.height = v + "px";
    else el.style.setProperty(k, v);
  }
}

// Six Emberglass panes; `lit` are shard indices held (Vigil.shards).
// Colours follow the six masks' glass in assets/art/meta (mural palette).
const SHARD_GLASS = ["#8fd0ff", "#f2c14e", "#9c2fa6", "#66ff9e", "#ff9a4d", "#c9d6ff"];
function roseSVG(r, lit, opts = {}) {
  // Six pointed lancet panes, each split by its own lead, inside a foiled ring.
  const lw = Math.max(1.1, r * 0.045), uid = "r" + Math.round(r * 100) + (opts.id || "");
  const P = (a, rr) => [r + Math.cos(a) * rr, r + Math.sin(a) * rr];
  const f = (pt) => pt[0].toFixed(1) + "," + pt[1].toFixed(1);
  const rad = (d) => d * Math.PI / 180;
  let defs = "", panes = "", leads = "", foils = "";
  for (let i = 0; i < 6; i++) {
    const am = rad(i * 60 - 90), a0 = rad(i * 60 - 90 - 24), a1 = rad(i * 60 - 90 + 24);
    const ri = r * 0.30, rs = r * 0.66, rt = r * 0.86;
    const d = `M${f(P(am, ri))} L${f(P(a0, rs * 0.92))} Q${f(P(a0 + rad(4), rt))} ${f(P(am, rt))} Q${f(P(a1 - rad(4), rt))} ${f(P(a1, rs * 0.92))} Z`;
    const on = lit.includes(i), c = SHARD_GLASS[i];
    defs += `<radialGradient id="${uid}g${i}" cx="${(P(am, r * 0.55)[0] / (2 * r)).toFixed(3)}" cy="${(P(am, r * 0.55)[1] / (2 * r)).toFixed(3)}" r="0.42">
      <stop offset="0" stop-color="#fff" stop-opacity="${on ? 0.95 : 0.05}"/><stop offset=".35" stop-color="${on ? c : "#1a2036"}"/>
      <stop offset="1" stop-color="${on ? c : "#0b0f1d"}" stop-opacity="${on ? 0.75 : 1}"/></radialGradient>`;
    panes += `<path d="${d}" fill="url(#${uid}g${i})" ${on ? `filter="url(#${uid}glow)"` : ""}/>`;
    leads += `<path d="${d}" fill="none" stroke="#04050b" stroke-width="${lw}" stroke-linejoin="round"/>`;
    leads += `<path d="M${f(P(am, ri))} L${f(P(am, rt * 0.97))} M${f(P(a0 + rad(6), rs * 0.8))} L${f(P(a1 - rad(6), rs * 0.8))}" stroke="#04050b" stroke-width="${lw * 0.7}"/>`;
  }
  for (let i = 0; i < 12; i++) {
    const c = P(rad(i * 30 - 75), r * 0.93);
    foils += `<circle cx="${c[0].toFixed(1)}" cy="${c[1].toFixed(1)}" r="${(r * 0.07).toFixed(1)}" fill="#0c1020" stroke="#04050b" stroke-width="${lw * 0.8}"/>`;
  }
  return `<svg width="${r * 2}" height="${r * 2}" viewBox="0 0 ${r * 2} ${r * 2}" style="overflow:visible">
    <defs>${defs}<filter id="${uid}glow" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="${(r * 0.07).toFixed(2)}" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>
    <circle cx="${r}" cy="${r}" r="${r}" fill="#080b16" stroke="#04050b" stroke-width="${lw * 1.6}"/>
    <circle cx="${r}" cy="${r}" r="${r * 0.995}" fill="none" stroke="#9c7c34" stroke-opacity=".45" stroke-width="${lw * 0.4}"/>
    ${panes}${leads}${foils}
    <circle cx="${r}" cy="${r}" r="${r * 0.28}" fill="#0b0e1a" stroke="#04050b" stroke-width="${lw * 1.2}"/>
    <circle cx="${r}" cy="${r}" r="${r * 0.12}" fill="${lit.length ? "#ffe9ac" : "#141a2e"}" fill-opacity="${lit.length ? 0.35 + lit.length * 0.1 : 1}"/>
  </svg>`;
}

// The flame a saved run carries. Fresh install: a cold lantern.
const RUN_FLAME = "var(--frost)";
if (!FRESH) document.documentElement.style.setProperty("--flame", RUN_FLAME);
const SHARDS_HELD = FRESH ? [] : [0, 1, 2];

// The settings room's contents, shared by all three concepts: the same kit,
// framed differently by each concept (window, lancet, shrine).
function settingsHTML() {
  const tab = (k, on) => `<div class="s-tab t-label${on ? " on" : ""}">${COPY[k]}</div>`;
  const row = (k, ctl) => `<div class="s-row"><span class="t-read">${COPY[k]}</span>${ctl}</div>`;
  const sl = (v) => `<div class="slider" style="--v:${v}%"><div class="fill"></div><div class="knob"></div></div>`;
  return `<div class="s-tabs">${tab("sAudio", 1)}${tab("sDisplay")}${tab("sMotion")}${tab("sPrivacy")}${tab("sLedger")}</div>
    <div class="s-body">
      ${row("master", sl(80))}${row("music", sl(62))}${row("sfx", sl(74))}
      ${row("mute", '<span class="toggle"></span>')}
      ${row("lang", `<span class="seg"><span class="${LANG === "zh" ? "on" : ""}">繁體中文</span><span class="${LANG === "en" ? "on" : ""}">English</span></span>`)}
    </div>`;
}
