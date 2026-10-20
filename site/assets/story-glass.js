// Holographic cards: each face is composed in a 2D canvas the way the game's
// CardView draws it, then lit by the ported glass shader as the pointer or the
// phone tilts it. The unnamed glass moves its layered art with the lean.

import { FRAG } from "./story-glass-shader.js";

const K = 3, W = 600, H = 792;
const TINT = { attack: "#FF5964", skill: "#4EA8DE", power: "#B388FF", status: "#7FAE9C", curse: "#C77BD4" };
const KEY_EN = ["kindle", "kindled", "cracked", "ward", "facet", "facets", "ember", "embers", "smolder", "dimmed", "unplayable", "chip"];
const KEY_ZH = ["燃燼", "餘燼", "護光", "裂痕", "璃面", "陰燃", "黯淡", "無法打出", "琢擊"];
const FONTS = [["GVCinzel", "700", "Cinzel-700"], ["GVCinzel", "800", "Cinzel-800"], ["GVAlegreya", "400", "Alegreya-400"], ["GVAlegreya", "700", "Alegreya-700"]];
const DEFAULT_KNOBS = { mode: 0, angle: 35, centre: [76, 108], palette: [1, 1, 1], mix: 0, strength: 0.5, scale: 1 };

export async function glass(canvases, { still }) {
  const fonts = FONTS.map(([family, weight, file]) =>
    new FontFace(family, `url(/assets/fonts/${file}.woff2)`, { weight }).load().then((f) => document.fonts.add(f)).catch(() => {}));
  const image = (src) => new Promise((ok) => { const i = new Image(); i.onload = () => ok(i); i.onerror = () => ok(null); i.src = src; });
  const cards = await Promise.all([...canvases].map(async (el) => {
    const face = JSON.parse(el.dataset.face);
    const sources = el.dataset.src.split(" ");
    const imgs = await Promise.all(sources.map(image));
    return { el, ...face, img: imgs[0], layerImgs: imgs, state: { tilt: [0.35, -0.25], target: null, visible: true } };
  }));
  await Promise.all(fonts);
  const gl = setupGL();
  if (!gl) return;
  for (const c of cards) {
    c.el.width = W; c.el.height = H;
    if (c.layers) {
      c.base = compose(c, true);
      c.work = document.createElement("canvas");
      c.work.width = W; c.work.height = H;
      c.tex = texture(gl, c.base);
    } else {
      c.tex = texture(gl, compose(c, false));
    }
    c.el.addEventListener("pointermove", (e) => {
      const r = c.el.getBoundingClientRect();
      c.state.target = [((e.clientX - r.left) / r.width - 0.5) * 2.2, (0.5 - (e.clientY - r.top) / r.height) * 2.2];
    });
    c.el.addEventListener("pointerleave", () => { c.state.target = null; });
    new IntersectionObserver((entries) => { c.state.visible = entries[0].isIntersecting; }, { rootMargin: "200px 0px" }).observe(c.el);
  }
  let device = null;
  addEventListener("deviceorientation", (e) => {
    if (e.gamma === null || e.beta === null) return;
    device = [Math.max(-1, Math.min(1, e.gamma / 25)), Math.max(-1, Math.min(1, (45 - e.beta) / 25))];
  });
  let last = performance.now(), clock = 0;
  const tick = (now) => {
    requestAnimationFrame(tick);
    const dt = Math.min(0.05, (now - last) / 1000) || 0.016;
    last = now;
    if (!still) clock += dt;
    cards.forEach((c, i) => {
      const st = c.state;
      if (!st.visible) return;
      const idle = still ? [0.35, -0.25] : [0.35 + 0.45 * Math.sin(clock * 0.55 + i * 1.3), -0.2 + 0.35 * Math.cos(clock * 0.43 + i)];
      const goal = st.target || device || idle;
      const f = Math.min(1, dt * 6);
      st.tilt[0] += (Math.max(-1, Math.min(1, goal[0])) - st.tilt[0]) * f;
      st.tilt[1] += (Math.max(-1, Math.min(1, goal[1])) - st.tilt[1]) * f;
      if (c.layers) { composeLayers(c, st.tilt[0], clock); draw(gl, c, st.tilt, c.work); }
      else draw(gl, c, st.tilt, null);
    });
  };
  requestAnimationFrame(tick);
}

function rr(x, X, Y, w, h, r) {
  x.beginPath();
  x.moveTo(X + r, Y); x.arcTo(X + w, Y, X + w, Y + h, r); x.arcTo(X + w, Y + h, X, Y + h, r);
  x.arcTo(X, Y + h, X, Y, r); x.arcTo(X, Y, X + w, Y, r); x.closePath();
}
function cover(x, img, X, Y, w, h) {
  const s = Math.max(w / img.width, h / img.height);
  x.drawImage(img, X + (w - img.width * s) / 2, Y + (h - img.height * s) / 2, img.width * s, img.height * s);
}
const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const mix = (a, b, t) => { const A = rgb(a), B = rgb(b); return `rgb(${A.map((v, i) => Math.round(v + (B[i] - v) * t)).join(",")})`; };
const alpha = (h, a) => `rgba(${rgb(h).join(",")},${a})`;

// The face as CardView draws it: stock, art window, rule, name, type, rules, cost crystal.
function compose(c, layered) {
  const zh = c.lang !== "en";
  const cv = document.createElement("canvas");
  cv.width = W; cv.height = H;
  const x = cv.getContext("2d");
  x.scale(K, K);
  x.translate(24, 24);
  if (c.knobs) {
    x.save(); rr(x, 0, 0, 152, 216, 11); x.clip();
    if (c.img) cover(x, c.img, 0, 0, 152, 216);
    x.restore();
    rr(x, 0.5, 0.5, 151, 215, 11); x.strokeStyle = "rgba(242,193,78,.55)"; x.lineWidth = 1.2; x.stroke();
    return cv;
  }
  const tint = TINT[c.type] || "#9aa2bd";
  const g = x.createLinearGradient(0, 0, 0, 216);
  g.addColorStop(0, mix("#0B0E1A", tint, 0.2)); g.addColorStop(0.55, "#0d1122"); g.addColorStop(1, "#0B0E1A");
  rr(x, 0, 0, 152, 216, 11); x.fillStyle = g; x.fill();
  if (!layered) {
    x.save(); rr(x, 2, 2, 148, 91, 9); x.clip();
    if (c.img) cover(x, c.img, 2, 2, 148, 91);
    const w = x.createLinearGradient(0, 40, 0, 93); w.addColorStop(0, "rgba(0,0,0,0)"); w.addColorStop(1, alpha(tint, 0.22));
    x.fillStyle = w; x.fillRect(2, 2, 148, 91);
    x.restore();
  }
  x.fillStyle = "rgba(242,193,78,.6)"; x.fillRect(8, 93, 136, 1);
  x.textAlign = "center"; x.textBaseline = "alphabetic";
  const nameFont = (fs) => zh ? `600 ${fs}px "Noto Serif TC", "Songti TC", serif` : `700 ${fs}px GVCinzel, Cinzel, serif`;
  let fs = zh ? 15 : 14;
  x.font = nameFont(fs);
  while (x.measureText(c.name).width > 132 && fs > 10) { fs -= 0.5; x.font = nameFont(fs); }
  x.fillStyle = "#E8DFC8"; x.fillText(c.name, 76, 110);
  x.font = zh ? '400 9.5px "Noto Serif TC", "Songti TC", serif' : "400 9px GVAlegreya, serif";
  try { x.letterSpacing = zh ? "2px" : "1.4px"; } catch { /* older canvas */ }
  x.fillStyle = layered ? "#9cc0ff" : tint;
  x.fillText(c.typeLabel, 76, 123);
  try { x.letterSpacing = "0px"; } catch { /* older canvas */ }
  if (zh) rulesZh(x, c.text, 140, c.text.length > 44 ? 11 : 12);
  else rulesEn(x, c.text, c.text.length > 120 ? 134 : 140, c.text.length > 120 ? 10 : 13);
  rr(x, 0.6, 0.6, 150.8, 214.8, 11); x.strokeStyle = alpha(tint, 0.75); x.lineWidth = 1.2; x.stroke();
  rr(x, 3.5, 3.5, 145, 209, 8.5); x.strokeStyle = "rgba(242,193,78,.28)"; x.lineWidth = 0.6; x.stroke();
  gem(x, c.cost);
  return cv;
}

function rulesEn(x, text, top, size) {
  const lh = size * 1.3;
  const isKey = (t) => KEY_EN.includes(t.toLowerCase().replace(/[^a-z]/g, ""));
  const words = text.replace(/@(\d+)@/g, "[$1]").replace(/#(\d+)#/g, "[$1]").split(" ");
  const font = (t) => `${isKey(t) || /^\[\d+\]/.test(t) ? 700 : 400} ${size}px GVAlegreya, serif`;
  x.font = `400 ${size}px GVAlegreya, serif`;
  const sp = x.measureText(" ").width;
  const lines = [];
  let cur = [], w = 0;
  for (const t of words) {
    x.font = font(t);
    const tw = x.measureText(t.replace(/[[\]]/g, "")).width;
    if (cur.length && w + sp + tw > 132) { lines.push([cur, w]); cur = []; w = 0; }
    w += (cur.length ? sp : 0) + tw; cur.push([t, tw]);
  }
  if (cur.length) lines.push([cur, w]);
  x.textAlign = "left";
  lines.slice(0, 7).forEach(([ws, lw], i) => {
    let px = 76 - lw / 2;
    for (const [t, tw] of ws) {
      const num = /^\[\d+\]/.test(t);
      x.font = font(t);
      x.fillStyle = num ? "#ffffff" : isKey(t) ? "#F2C14E" : "#C6CCDF";
      x.fillText(t.replace(/[[\]]/g, ""), px, top + i * lh);
      px += tw + sp;
    }
  });
  x.textAlign = "center";
}

// Chinese rules wrap by character; keywords stay gold and are never split.
function rulesZh(x, text, top, size) {
  const lh = size * 1.55;
  const t = text.replace(/@(\d+)@/g, "\u0001$1\u0002").replace(/#(\d+)#/g, "\u0001$1\u0002");
  const segs = [];
  for (let i = 0; i < t.length;) {
    if (t[i] === "\u0001") { const j = t.indexOf("\u0002", i); segs.push([t.slice(i + 1, j), "num"]); i = j + 1; continue; }
    const k = KEY_ZH.find((kw) => t.startsWith(kw, i));
    if (k) { segs.push([k, "key"]); i += k.length; continue; }
    segs.push([t[i], "txt"]); i += 1;
  }
  const font = (kind) => `${kind === "txt" ? 400 : 600} ${size}px "Noto Serif TC", "Songti TC", serif`;
  const lines = [];
  let cur = [], w = 0;
  for (const sg of segs) {
    x.font = font(sg[1]);
    const tw = x.measureText(sg[0]).width;
    const lead = "，。、：；」）".includes(sg[0]);
    if (cur.length && w + tw > 134 && !lead) { lines.push([cur, w]); cur = []; w = 0; }
    w += tw; cur.push([sg, tw]);
  }
  if (cur.length) lines.push([cur, w]);
  x.textAlign = "left";
  lines.slice(0, 6).forEach(([ss, lw], li) => {
    let px = 76 - lw / 2;
    for (const [sg, tw] of ss) {
      x.font = font(sg[1]);
      x.fillStyle = sg[1] === "num" ? "#ffffff" : sg[1] === "key" ? "#F2C14E" : "#C6CCDF";
      x.fillText(sg[0], px, top + li * lh);
      px += tw;
    }
  });
  x.textAlign = "center";
}

function gem(x, cost) {
  x.save();
  x.beginPath();
  for (let i = 0; i < 6; i++) { const a = (-90 + 60 * i) * Math.PI / 180; x.lineTo(10 + 18 * Math.cos(a), 10 + 18 * Math.sin(a)); }
  x.closePath();
  const g = x.createLinearGradient(-8, -8, 28, 28);
  g.addColorStop(0, "#fff3c4"); g.addColorStop(0.45, "#FFE9AC"); g.addColorStop(1, "#b77a1a");
  x.fillStyle = g; x.shadowColor = "rgba(0,0,0,.6)"; x.shadowBlur = 4; x.fill();
  x.shadowBlur = 0; x.strokeStyle = "#3a2a10"; x.lineWidth = 1.3; x.stroke();
  x.font = "800 17px GVCinzel, Cinzel, serif"; x.textAlign = "center"; x.textBaseline = "middle"; x.fillStyle = "#1a1206";
  x.fillText(cost === null || cost === undefined ? "–" : String(cost), 10, 11);
  x.restore();
}

// The layered art window, moved by lean per each layer's role.
function composeLayers(c, lean, t) {
  const x = c.work.getContext("2d");
  x.setTransform(1, 0, 0, 1, 0, 0);
  x.clearRect(0, 0, W, H);
  x.drawImage(c.base, 0, 0);
  x.save();
  x.scale(K, K); x.translate(24, 24);
  rr(x, 2, 2, 148, 91, 9); x.clip();
  const sF = 148 / 1024;
  x.translate(2, 2); x.scale(sF, sF); x.translate(-64, -43);
  const flare = Math.min(1, Math.max(0, (lean - 0.3) / 0.65));
  c.layers.forEach(([role, depth], i) => {
    const img = c.layerImgs[i];
    if (!img) return;
    let dx = lean * depth / 2, dy = 0, a = 1;
    if (role === "particles") { dx += Math.sin(2 * Math.PI * t / 4) * 6; dy -= Math.sin(2 * Math.PI * t / 4) * 3; }
    if (role === "hot-core") a = 0.15 + 0.85 * flare;
    x.save();
    x.globalAlpha = a;
    x.translate(dx, dy);
    x.drawImage(img, 0, 0);
    if (role === "hot-core") { x.globalCompositeOperation = "lighter"; x.globalAlpha = 0.6 * flare; x.drawImage(img, 0, 0); }
    x.restore();
  });
  x.fillStyle = `rgba(202,119,38,${0.075 * flare})`; x.fillRect(64, 43, 1024, 687);
  const sx = 64 + (lean + 1) * 512;
  const g = x.createLinearGradient(sx - 160, 0, sx + 160, 0);
  g.addColorStop(0, "rgba(177,207,223,0)"); g.addColorStop(0.5, "rgba(177,207,223,.14)"); g.addColorStop(1, "rgba(177,207,223,0)");
  x.globalCompositeOperation = "screen"; x.fillStyle = g; x.fillRect(64, 43, 1024, 687);
  x.restore();
}

function setupGL() {
  const cv = document.createElement("canvas");
  cv.width = W; cv.height = H;
  const gl = cv.getContext("webgl", { premultipliedAlpha: false, preserveDrawingBuffer: true, alpha: true });
  if (!gl) return null;
  const vs = "attribute vec2 p; varying vec2 vUv; void main(){ vUv = vec2(p.x*0.5+0.5, 0.5-p.y*0.5); gl_Position = vec4(p,0.,1.); }";
  const shader = (type, src) => { const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); return s; };
  const prog = gl.createProgram();
  gl.attachShader(prog, shader(gl.VERTEX_SHADER, vs));
  gl.attachShader(prog, shader(gl.FRAGMENT_SHADER, FRAG));
  gl.linkProgram(prog);
  if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) return null;
  gl.useProgram(prog);
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
  const loc = gl.getAttribLocation(prog, "p");
  gl.enableVertexAttribArray(loc);
  gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
  gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
  gl.U = {};
  for (const n of ["uTex", "tilt", "tier", "warm", "bandMode", "bandAngle", "centre", "palette", "paletteMix", "strength", "pscale"]) {
    gl.U[n] = gl.getUniformLocation(prog, n);
  }
  gl.uniform1i(gl.U.uTex, 0);
  gl.out = cv;
  return gl;
}

function texture(gl, src) {
  const t = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, t);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, src);
  return t;
}

function draw(gl, c, tilt, upload) {
  const U = gl.U;
  gl.viewport(0, 0, W, H);
  gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT);
  gl.bindTexture(gl.TEXTURE_2D, c.tex);
  if (upload) gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, upload);
  gl.uniform2f(U.tilt, tilt[0], tilt[1]);
  gl.uniform1i(U.tier, c.tier);
  gl.uniform1f(U.warm, c.warm || 0);
  const k = c.knobs || DEFAULT_KNOBS;
  gl.uniform1i(U.bandMode, k.mode); gl.uniform1f(U.bandAngle, k.angle);
  gl.uniform2f(U.centre, k.centre[0], k.centre[1]); gl.uniform3f(U.palette, k.palette[0], k.palette[1], k.palette[2]);
  gl.uniform1f(U.paletteMix, k.mix); gl.uniform1f(U.strength, k.strength); gl.uniform1f(U.pscale, k.scale);
  gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  const x = c.el.getContext("2d");
  x.clearRect(0, 0, W, H);
  x.drawImage(gl.out, 0, 0);
  c.el.style.transform = `perspective(1000px) rotateY(${(tilt[0] * 11).toFixed(2)}deg) rotateX(${(tilt[1] * 9).toFixed(2)}deg)`;
}
