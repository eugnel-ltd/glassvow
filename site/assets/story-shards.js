// Prologue: one fire breaking into six. Beat sheet (seconds): gather and
// tremble → burst with hit-stop, flash, ring, trauma-squared shake and sparks →
// fly out on an overshooting ease with trails → slow orbit with pulsing glows →
// recall → rekindle. Touching the fire pulls the shards home and breaks it again.

const CYCLE = 13, BURST = 1.5, HOLD = 0.1, OUT = 2.6, ORBIT = 10.2, RECALL = 11.8, HOME = 0.07;
const OMEGA = 0.12;
const SPIN = [-1, 1, -1, 1, -1, 1];
const clamp = (p) => Math.max(0, Math.min(1, p));
const outBack = (p) => { const c1 = 1.9, c3 = c1 + 1; return 1 + c3 * (p - 1) ** 3 + c1 * (p - 1) ** 2; };
const outCubic = (p) => 1 - (1 - p) ** 3;
const inCubic = (p) => p * p * p;

export function shards(box, { still, sound }) {
  const els = [...box.querySelectorAll(".shard")];
  const data = els.map((el) => ({ c: el.dataset.c, a: +el.dataset.a, r: +el.dataset.r, t: +el.dataset.t }));
  const core = box.querySelector(".core");
  const ring = box.querySelector(".ring");
  const flash = box.querySelector(".flash");
  const cv = box.querySelector("canvas");
  const place = (i, x, y, rot, sc, glow) => {
    els[i].style.transform = `translate(${x.toFixed(1)}px,${y.toFixed(1)}px) rotate(${rot.toFixed(1)}deg) scale(${sc.toFixed(3)})`;
    els[i].style.filter = `drop-shadow(0 0 ${glow.toFixed(0)}px ${data[i].c})`;
  };
  if (still) {
    const W = box.clientWidth;
    data.forEach((d, i) => { const a = d.a * Math.PI / 180; place(i, Math.cos(a) * d.r * W, Math.sin(a) * d.r * W, d.t, 1, 16); });
    core.style.opacity = ".3";
    core.style.transform = "scale(.6)";
    return;
  }
  const sh = { clock: 0, t0: 0, burst: false, visible: false, trauma: 0, sparks: [], prev: [], emit: 0,
               lastR: [], lastA: [], pullAt: null, pullFrom: [], pullA: [] };
  new IntersectionObserver((entries) => {
    const e = entries[0];
    if (e.isIntersecting && !sh.visible) { sh.t0 = sh.clock; sh.burst = false; }
    sh.visible = e.isIntersecting;
  }, { threshold: 0.2 }).observe(box);
  box.addEventListener("click", () => {
    const tau = sh.clock - sh.t0;
    if (tau > 0.9 && tau < 1.5) return;
    sh.pullFrom = sh.lastR.slice();
    sh.pullA = sh.lastA.slice();
    sh.pullAt = sh.clock;
    sh.t0 = sh.clock - 0.85;
    sh.burst = false;
  });
  let last = performance.now();
  const tick = (now) => {
    requestAnimationFrame(tick);
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    sh.clock += dt;
    if (sh.visible) step(dt);
  };
  requestAnimationFrame(tick);

  function step(dt) {
    const W = box.clientWidth || 1;
    let tau = sh.clock - sh.t0;
    if (tau >= CYCLE) { sh.t0 += CYCLE * Math.floor(tau / CYCLE); tau = sh.clock - sh.t0; sh.burst = false; }
    let coreS = 1, coreO = 1;
    const pos = data.map((d, i) => {
      const base = d.a * Math.PI / 180;
      let r, a, rot, sc, glow;
      if (tau < BURST) {
        const e = inCubic(tau / BURST);
        r = HOME * (1 - 0.35 * e);
        a = base + tau * 0.6;
        if (sh.pullAt !== null && sh.pullFrom[i] !== undefined) {
          const k = clamp((sh.clock - sh.pullAt) / 0.32);
          if (k < 1) { const ek = inCubic(k); r = sh.pullFrom[i] + (r - sh.pullFrom[i]) * ek; a = sh.pullA[i] + (a - sh.pullA[i]) * ek; }
        }
        sh.lastR[i] = r; sh.lastA[i] = a;
        const jit = 0.012 * e * e * W;
        rot = d.t * 0.2 + Math.sin(tau * 40 + i) * 6 * e;
        coreS = 1 + 0.4 * e; coreO = 0.75 + 0.25 * e;
        return [Math.cos(a) * r * W + Math.sin(tau * 53 + i * 7) * jit, Math.sin(a) * r * W + Math.cos(tau * 47 + i * 3) * jit,
                rot, 0.55 + 0.06 * e, 10 + 26 * e];
      }
      if (tau < BURST + HOLD) {
        r = HOME * 0.65; a = base + BURST * 0.6; rot = d.t * 0.2; sc = 0.66; glow = 44; coreS = 1.5; coreO = 1;
      } else if (tau < OUT) {
        const p = clamp((tau - BURST - HOLD) / (OUT - BURST - HOLD));
        a = base + BURST * 0.6 * (1 - outCubic(p));
        r = HOME * 0.65 + (d.r - HOME * 0.65) * outBack(p);
        rot = d.t * 0.2 + (d.t * 0.8 + SPIN[i] * 360) * outCubic(p);
        sc = 0.66 + 0.34 * outCubic(p);
        glow = 44 - 26 * p;
        coreS = 1.5 - 0.95 * outCubic(p); coreO = 1 - 0.75 * p;
      } else if (tau < ORBIT) {
        const q = tau - OUT;
        a = base + OMEGA * q;
        r = d.r * (1 + 0.035 * Math.sin(q * 1.3 + i * 1.7));
        rot = d.t + SPIN[i] * 360 + 7 * Math.sin(q * 0.9 + i);
        sc = 1 + 0.025 * Math.sin(q * 2 + i);
        glow = 16 + 10 * (0.5 + 0.5 * Math.sin(q * 2.4 + i * 1.1));
        coreS = 0.55 + 0.04 * Math.sin(q * 3); coreO = 0.25 + 0.06 * Math.sin(q * 2.2);
      } else if (tau < RECALL) {
        const p = clamp((tau - ORBIT) / (RECALL - ORBIT));
        const e = inCubic(p);
        a = base + OMEGA * (ORBIT - OUT) + p * 0.8;
        r = d.r + (HOME - d.r) * e;
        rot = (d.t + SPIN[i] * 360) * (1 - e) + d.t * 0.2 * e;
        sc = 1 - 0.45 * e;
        glow = 16 + 10 * e;
        coreS = 0.55 + 0.25 * e; coreO = 0.25 + 0.4 * e;
      } else {
        const p = clamp((tau - RECALL) / 0.6);
        a = base + OMEGA * (ORBIT - OUT) + 0.8 + (tau - RECALL) * 0.6;
        r = HOME; rot = d.t * 0.2; sc = 0.55; glow = 12;
        coreS = 0.8 + 0.2 * outBack(p); coreO = 0.65 + 0.1 * p;
      }
      sh.lastR[i] = r; sh.lastA[i] = a;
      return [Math.cos(a) * r * W, Math.sin(a) * r * W, rot, sc, glow];
    });
    if (sh.pullAt !== null && sh.clock - sh.pullAt > 0.4) sh.pullAt = null;

    if (tau >= BURST && !sh.burst) {
      sh.burst = true;
      sh.trauma = 1;
      sound.play("shatter", 0.5);
      for (let n = 0; n < 110; n++) {
        const ang = Math.random() * Math.PI * 2, sp = 260 + Math.random() * 620;
        sh.sparks.push({ x: 0, y: 0, vx: Math.cos(ang) * sp, vy: Math.sin(ang) * sp, life: 0, max: 0.6 + Math.random() * 0.9,
                         c: n % 5 === 0 ? "#fff6dc" : data[n % 6].c, s: 1.2 + Math.random() * 2.4, drag: 2.4 });
      }
    }
    const since = tau - BURST;
    flash.style.opacity = since >= 0 && since < 0.5 ? (since < HOLD ? 1 : 1 - (since - HOLD) / 0.4).toFixed(3) : "0";
    const rp = since / 0.9;
    if (rp >= 0 && rp < 1) { ring.style.opacity = (1 - rp).toFixed(3); ring.style.transform = `scale(${(0.3 + 2.8 * outCubic(rp)).toFixed(3)})`; }
    else ring.style.opacity = "0";
    core.style.opacity = coreO.toFixed(3);
    core.style.transform = `scale(${coreS.toFixed(3)})`;

    sh.trauma = Math.max(0, sh.trauma - dt * 1.7);
    const tr = sh.trauma * sh.trauma, c = sh.clock;
    const nz = (k) => Math.sin(c * 31 + k) * 0.5 + Math.sin(c * 57 + k * 2.1) * 0.3 + Math.sin(c * 89 + k * 4.3) * 0.2;
    box.style.transform = tr > 0.001 ? `translate(${(nz(1) * 22 * tr).toFixed(1)}px,${(nz(5) * 22 * tr).toFixed(1)}px) rotate(${(nz(9) * 2.4 * tr).toFixed(2)}deg)` : "";
    pos.forEach((p, i) => place(i, ...p));
    sparks(dt, tau, pos, W);
  }

  function sparks(dt, tau, pos, W) {
    const dpr = Math.min(devicePixelRatio || 1, 2);
    const cw = cv.clientWidth, ch = cv.clientHeight;
    if (cv.width !== Math.round(cw * dpr)) { cv.width = Math.round(cw * dpr); cv.height = Math.round(ch * dpr); }
    const x = cv.getContext("2d");
    x.setTransform(dpr, 0, 0, dpr, 0, 0);
    x.globalCompositeOperation = "destination-out";
    x.fillStyle = `rgba(0,0,0,${tau > BURST && tau < OUT ? 0.14 : 0.24})`;
    x.fillRect(0, 0, cw, ch);
    x.globalCompositeOperation = "lighter";
    const cx = cw / 2, cy = ch / 2;
    if (tau < BURST && Math.random() < 0.2 + 0.8 * (tau / BURST)) {
      const ang = Math.random() * Math.PI * 2, R = W * (0.42 + Math.random() * 0.1);
      sh.sparks.push({ x: Math.cos(ang) * R, y: Math.sin(ang) * R, vx: -Math.cos(ang) * R * 2.2, vy: -Math.sin(ang) * R * 2.2,
                       life: 0, max: 0.42, c: data[(Math.random() * 6) | 0].c, s: 1.4, drag: 0 });
    }
    if (tau >= OUT && tau < ORBIT) {
      sh.emit += dt;
      while (sh.emit > 0.05) {
        sh.emit -= 0.05;
        const i = (Math.random() * 6) | 0, p = pos[i];
        sh.sparks.push({ x: p[0], y: p[1], vx: (Math.random() - 0.5) * 30, vy: -20 - Math.random() * 30, life: 0,
                         max: 1 + Math.random() * 0.8, c: data[i].c, s: 1 + Math.random() * 1.4, drag: 0.5 });
      }
    }
    if ((tau > BURST + HOLD && tau < OUT) || (tau > ORBIT && tau < RECALL)) {
      x.globalAlpha = 0.55;
      x.lineWidth = 7;
      x.lineCap = "round";
      pos.forEach((p, i) => {
        const q = sh.prev[i];
        if (!q) return;
        x.strokeStyle = data[i].c;
        x.beginPath(); x.moveTo(cx + q[0], cy + q[1]); x.lineTo(cx + p[0], cy + p[1]); x.stroke();
      });
      x.globalAlpha = 1;
    }
    sh.prev = pos.map((p) => [p[0], p[1]]);
    const keep = [];
    for (const k of sh.sparks) {
      k.life += dt;
      if (k.life > k.max) continue;
      const f = Math.exp(-k.drag * dt);
      k.vx *= f; k.vy *= f;
      k.x += k.vx * dt; k.y += k.vy * dt;
      const al = 1 - k.life / k.max;
      x.globalAlpha = al * 0.35; x.fillStyle = k.c;
      x.beginPath(); x.arc(cx + k.x, cy + k.y, k.s * 3.2, 0, 6.283); x.fill();
      x.globalAlpha = al; x.fillStyle = "#fff4dc";
      x.beginPath(); x.arc(cx + k.x, cy + k.y, k.s, 0, 6.283); x.fill();
      keep.push(k);
    }
    x.globalAlpha = 1;
    sh.sparks = keep.length > 600 ? keep.slice(-600) : keep;
  }
}
