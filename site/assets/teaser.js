// The teaser's motion and opt-in sound. Without this file, or with reduced
// motion, the page is the still, finished page that teaser.css draws. Each
// [data-scene] section gets one --p from 0 to 1 as it scrolls; the CSS turns
// that into the stage. Sound starts off and plays only after a press.

const clamp = (value, low = 0, high = 1) => Math.min(high, Math.max(low, value));
const ease = (t) => t * t * (3 - 2 * t);
const sound = setupSound(document.querySelector(".sound"));

if (!matchMedia("(prefers-reduced-motion: reduce)").matches) {
  document.documentElement.classList.add("motion");
  driveScenes();
  heroLight(document.querySelector(".hero-light"));
  assembleWordmark(document.querySelector(".wordmark img"));
  tiltCards();
  shatterPane(document.querySelector(".vow"));
  reveal(document.querySelectorAll(".aspect"));
  cue(document.querySelector(".fire"), (p) => Math.floor(clamp(p * 8 - 1, 0, 6)), "rise", 0.35);
  cue(document.querySelector(".deck"),
    // Mirrors --flip in teaser.css: a card counts as turned past half way.
    (p) => [...Array(7).keys()].filter((i) => p * 3.5 - 1.2 - i * 0.18 > 0.5).length, "flip", 0.5);
}

function driveScenes() {
  // "hero" runs while the hero leaves; "pass" while a section rises into view;
  // the rest are sticky stages that run while pinned.
  const modes = { hero: "hero", foes: "pass" };
  const scenes = [...document.querySelectorAll("[data-scene]")].map((el) => (
    { el, mode: modes[el.dataset.scene] ?? "pin", p: -1 }));
  const road = document.querySelector(".road");
  const track = road?.querySelector(".road-track");
  let queued = false;
  const measure = () => {
    road?.style.setProperty("--shift", Math.max(0, track.offsetWidth - innerWidth));
  };
  const update = () => {
    queued = false;
    const vh = innerHeight;
    for (const scene of scenes) {
      const box = scene.el.getBoundingClientRect();
      if (box.bottom < -vh || box.top > 2 * vh) continue;
      const raw = scene.mode === "hero" ? -box.top / box.height
        : scene.mode === "pass" ? (vh - box.top) / (vh * 0.8)
          : -box.top / Math.max(1, box.height - vh);
      const p = clamp(raw);
      if (Math.abs(p - scene.p) < 1e-4) continue;
      scene.p = p;
      scene.el.style.setProperty("--p", p.toFixed(4));
      scene.el.dispatchEvent(new CustomEvent("scene", { detail: p }));
    }
  };
  const queue = () => {
    if (!queued) {
      queued = true;
      requestAnimationFrame(update);
    }
  };
  addEventListener("scroll", queue, { passive: true });
  addEventListener("resize", () => { measure(); queue(); });
  measure();
  update();
}

function cue(section, count, name, volume) {
  let last = null;
  section?.addEventListener("scene", ({ detail }) => {
    const now = count(detail);
    if (last !== null && now > last) sound.play(name, volume);
    last = now;
  });
}

function reveal(elements) {
  const seen = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        entry.target.classList.add("seen");
        seen.unobserve(entry.target);
      }
    }
  }, { rootMargin: "0px 0px -15% 0px" });
  elements.forEach((el) => seen.observe(el));
}

// Light from the arch: slow rays and rising embers, drawn at reduced
// resolution and screened over the painting. Stops when out of view.
function heroLight(canvas) {
  const gl = canvas?.getContext("webgl", { antialias: false, powerPreference: "low-power" });
  if (!gl) return;
  const vertex = "attribute vec2 a;void main(){gl_Position=vec4(a,0.,1.);}";
  const fragment = `precision mediump float;
uniform vec2 r;uniform float t;uniform float p;
float h(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
float n(float x){float i=floor(x),f=fract(x);return mix(h(vec2(i,0.)),h(vec2(i+1.,0.)),f*f*(3.-2.*f));}
void main(){
  vec2 uv=gl_FragCoord.xy/r;vec2 asp=vec2(r.x/r.y,1.);
  vec2 d=(uv-vec2(.5,.6))*asp;float l=length(d);float a=atan(d.x,-d.y);
  float rays=n(a*7.+t*.05)*n(a*19.-t*.08+3.);
  vec3 c=vec3(1.,.66,.3)*(rays*rays*exp(-l*1.8)*.75+exp(-l*7.)*.45);
  float e=0.;
  for(int i=0;i<3;i++){
    float fi=float(i);vec2 g=uv*asp*(5.+fi*4.);
    g.y-=t*(.07+fi*.045);g.x+=sin(g.y*1.3+fi*2.)*.25;
    vec2 id=floor(g);vec2 f=fract(g)-.5;float k=h(id+fi*7.3);
    if(k>.8){vec2 o=vec2(h(id+1.7),h(id+4.1))-.5;
      float tw=.55+.45*sin(t*(1.5+k*3.)+k*50.);
      e+=smoothstep(.07/(1.+fi*.5),0.,length(f-o*.6))*tw*(1.-fi*.25);}
  }
  c+=vec3(1.,.55,.22)*e*(1.15-uv.y*.7);
  gl_FragColor=vec4(c*(1.-p),1.);
}`;
  const program = gl.createProgram();
  for (const [type, source] of [[gl.VERTEX_SHADER, vertex], [gl.FRAGMENT_SHADER, fragment]]) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    gl.attachShader(program, shader);
  }
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) return;
  gl.useProgram(program);
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
  const at = (name) => gl.getUniformLocation(program, name);
  const [res, time, leave] = ["r", "t", "p"].map(at);
  const hero = canvas.closest(".hero");
  let visible = true;
  let frame = 0;
  let leaving = 0;
  hero.addEventListener("scene", ({ detail }) => { leaving = detail; });
  const size = () => {
    const scale = innerWidth < 720 ? 0.45 : 0.6;
    canvas.width = Math.round(canvas.clientWidth * scale);
    canvas.height = Math.round(canvas.clientHeight * scale);
    gl.viewport(0, 0, canvas.width, canvas.height);
  };
  const draw = (now) => {
    frame = 0;
    if (!visible || document.hidden) return;
    gl.uniform2f(res, canvas.width, canvas.height);
    gl.uniform1f(time, now / 1000);
    gl.uniform1f(leave, leaving);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    canvas.classList.add("on");
    frame = requestAnimationFrame(draw);
  };
  const start = () => { if (!frame) frame = requestAnimationFrame(draw); };
  new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; start(); }).observe(hero);
  document.addEventListener("visibilitychange", start);
  addEventListener("resize", size);
  size();
  start();
}

// The wordmark arrives as panes of its own glass, then catches the light.
function assembleWordmark(img) {
  if (!img) return;
  const run = () => {
    const box = img.closest(".wordmark");
    const url = `url("${img.currentSrc || img.src}")`;
    const cols = 7;
    const rows = 2;
    const point = (x, y) => [
      x === 0 || x === cols ? (x / cols) * 100 : (x + (Math.random() - 0.5) * 0.6) / cols * 100,
      y === 0 || y === rows ? (y / rows) * 100 : (y + (Math.random() - 0.5) * 0.5) / rows * 100,
    ];
    const grid = Array.from({ length: rows + 1 }, (_, y) => Array.from({ length: cols + 1 }, (_, x) => point(x, y)));
    const layer = document.createElement("span");
    layer.className = "shards";
    layer.setAttribute("aria-hidden", "true");
    const flights = [];
    for (let y = 0; y < rows; y += 1) {
      for (let x = 0; x < cols; x += 1) {
        const [a, b, c, d] = [grid[y][x], grid[y][x + 1], grid[y + 1][x + 1], grid[y + 1][x]];
        for (const tri of (x + y) % 2 ? [[a, b, c], [a, c, d]] : [[a, b, d], [b, c, d]]) {
          const shard = document.createElement("i");
          shard.style.backgroundImage = url;
          shard.style.clipPath = `polygon(${tri.map(([px, py]) => `${px}% ${py}%`).join(",")})`;
          layer.append(shard);
          const cx = tri.reduce((sum, [px]) => sum + px, 0) / 3 - 50;
          const lift = (Math.random() - 0.5) * 220;
          flights.push(shard.animate([
            { transform: `translate(${cx * 3}px, ${lift}px) rotate(${(Math.random() - 0.5) * 70}deg) scale(1.25)`, opacity: 0 },
            { opacity: 1, offset: 0.55 },
            { transform: "none", opacity: 1 },
          ], { duration: 1300 + Math.random() * 700, delay: 120 + Math.abs(cx) * 9, easing: "cubic-bezier(.2,.75,.15,1)", fill: "backwards" }));
        }
      }
    }
    img.style.animation = "none";
    img.classList.add("veiled");
    box.append(layer);
    Promise.all(flights.map((flight) => flight.finished)).then(() => {
      img.classList.remove("veiled");
      layer.remove();
      const glint = document.createElement("span");
      glint.className = "glint";
      glint.setAttribute("aria-hidden", "true");
      glint.style.maskImage = url;
      glint.style.webkitMaskImage = url;
      box.append(glint);
    });
  };
  if (img.complete && img.naturalWidth) run();
  else img.addEventListener("load", run, { once: true });
}

function tiltCards() {
  if (!matchMedia("(hover: hover) and (pointer: fine)").matches) return;
  for (const card of document.querySelectorAll(".card")) {
    card.addEventListener("pointermove", (event) => {
      const box = card.getBoundingClientRect();
      const x = (event.clientX - box.left) / box.width - 0.5;
      const y = (event.clientY - box.top) / box.height - 0.5;
      card.style.setProperty("--ry", `${x * 22}deg`);
      card.style.setProperty("--rx", `${-y * 16}deg`);
      card.style.setProperty("--glare", `${x * 140}%`);
    });
    card.addEventListener("pointerleave", () => {
      for (const name of ["--rx", "--ry", "--glare"]) card.style.removeProperty(name);
    });
  }
}

// The closing pane: leaded glass over the message. Cracks run from the
// centre, then the pieces fall, scrubbed by scroll in both directions.
function shatterPane(section) {
  const canvas = section?.querySelector(".vow-glass");
  const ctx = canvas?.getContext("2d");
  if (!ctx) return;
  const glass = [["#ffd98a", "#a85a14"], ["#8fc1ff", "#1d3a8f"], ["#ff8a8a", "#7a1530"],
    ["#c9a6ff", "#4b2a8a"], ["#8ff0e2", "#0f5f66"], ["#ffb36b", "#9a3412"]];
  let shards = [];
  let width = 0;
  let height = 0;
  let p = 0;
  let cracked = false;
  let fallen = false;
  const build = () => {
    if (canvas.clientWidth === width && canvas.clientHeight === height) return;
    const ratio = Math.min(devicePixelRatio || 1, 1.5);
    width = canvas.clientWidth;
    height = canvas.clientHeight;
    canvas.width = Math.round(width * ratio);
    canvas.height = Math.round(height * ratio);
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    const centre = [width / 2, height * 0.46];
    const reach = Math.hypot(width, height) * 0.62;
    const spokes = 15;
    const rings = [0, 0.09, 0.22, 0.4, 0.64, 1];
    const angles = Array.from({ length: spokes }, (_, i) => (i + 0.2 + Math.random() * 0.6) / spokes * Math.PI * 2);
    const at = (ring, spoke) => {
      if (ring === 0) return centre;
      const jitter = ring === rings.length - 1 ? 1 : 0.82 + Math.random() * 0.36;
      const angle = angles[spoke % spokes];
      return [centre[0] + Math.sin(angle) * reach * rings[ring] * jitter,
        centre[1] - Math.cos(angle) * reach * rings[ring] * jitter];
    };
    const points = rings.map((_, ring) => angles.map((__, spoke) => at(ring, spoke)));
    shards = [];
    for (let ring = 0; ring < rings.length - 1; ring += 1) {
      for (let spoke = 0; spoke < spokes; spoke += 1) {
        const next = (spoke + 1) % spokes;
        const outline = ring === 0 ? [centre, points[1][spoke], points[1][next]]
          : [points[ring][spoke], points[ring + 1][spoke], points[ring + 1][next], points[ring][next]];
        const mid = outline.reduce(([sx, sy], [x, y]) => [sx + x / outline.length, sy + y / outline.length], [0, 0]);
        const away = [mid[0] - centre[0], mid[1] - centre[1]];
        const distance = Math.hypot(...away) || 1;
        shards.push({
          outline, mid, away: [away[0] / distance, away[1] / distance],
          delay: (distance / reach) * 0.4, spin: (Math.random() - 0.5) * 2.4,
          colour: glass[(ring * 7 + spoke * 3) % glass.length], push: 0.25 + Math.random() * 0.5,
        });
      }
    }
    draw();
  };
  const draw = () => {
    const crack = ease(clamp((p - 0.08) / 0.2));
    const fall = clamp((p - 0.3) / 0.45);
    canvas.classList.toggle("gone", fall >= 1);
    if (fall >= 1) return;
    ctx.clearRect(0, 0, width, height);
    for (const shard of shards) {
      const t = clamp((fall - shard.delay) / 0.6);
      if (t >= 1) continue;
      const drop = t * t;
      ctx.save();
      ctx.globalAlpha = 1 - t * t;
      ctx.translate(shard.mid[0] + shard.away[0] * drop * height * shard.push,
        shard.mid[1] + shard.away[1] * drop * height * shard.push + drop * height * 0.9);
      ctx.rotate(shard.spin * drop);
      ctx.translate(-shard.mid[0], -shard.mid[1]);
      ctx.beginPath();
      shard.outline.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
      ctx.closePath();
      const fill = ctx.createLinearGradient(width / 2, height * 0.46, shard.mid[0], shard.mid[1]);
      fill.addColorStop(0, shard.colour[0]);
      fill.addColorStop(1, shard.colour[1]);
      ctx.fillStyle = fill;
      ctx.fill();
      ctx.lineJoin = "round";
      ctx.strokeStyle = "#07060c";
      ctx.lineWidth = 5;
      ctx.stroke();
      if (crack > 0) {
        ctx.strokeStyle = `rgba(255, 214, 140, ${crack * (1 - t)})`;
        ctx.lineWidth = 1.5;
        ctx.stroke();
      }
      ctx.restore();
    }
  };
  section.addEventListener("scene", ({ detail }) => {
    p = detail;
    if (!cracked && p > 0.1) sound.play("crack", 0.55);
    if (!fallen && p > 0.32) sound.play("shatter", 0.6);
    cracked = p > 0.1;
    fallen = p > 0.32;
    requestAnimationFrame(draw);
  });
  addEventListener("resize", build);
  build();
}

function setupSound(button) {
  if (!button) return { play() {} };
  const probe = document.createElement("audio");
  const pick = (name) => {
    const [ogg, mp3] = button.dataset[name].split(" ");
    return probe.canPlayType('audio/ogg; codecs="opus"') ? ogg : mp3;
  };
  const effects = {};
  let on = false;
  let theme = null;
  let fading = 0;
  const fade = (target, done) => {
    cancelAnimationFrame(fading);
    const from = theme.volume;
    const start = performance.now();
    const step = (now) => {
      const t = clamp((now - start) / 900);
      theme.volume = from + (target - from) * t;
      if (t < 1) fading = requestAnimationFrame(step);
      else done?.();
    };
    fading = requestAnimationFrame(step);
  };
  const set = (value) => {
    on = value;
    button.setAttribute("aria-pressed", String(on));
    button.querySelector(".sound-label").textContent = button.dataset[on ? "on" : "off"];
    if (on) {
      theme ??= Object.assign(new Audio(pick("theme")), { loop: true, volume: 0 });
      for (const name of ["flip", "rise", "crack", "shatter"]) effects[name] ??= new Audio(pick(name));
      theme.play().then(() => fade(0.4)).catch(() => set(false));
    } else if (theme) {
      fade(0, () => theme.pause());
    }
  };
  button.hidden = false;
  button.addEventListener("click", () => set(!on));
  document.addEventListener("visibilitychange", () => {
    if (theme && on) document.hidden ? theme.pause() : theme.play().catch(() => {});
  });
  return {
    play(name, volume) {
      const effect = on && effects[name];
      if (!effect) return;
      effect.volume = volume;
      effect.currentTime = 0;
      effect.play().catch(() => {});
    },
  };
}
