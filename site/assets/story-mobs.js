// One signature rigged foe per act (lab rig round 4), idle clip only, played
// slow. three.js r128 and its GLTFLoader are vendored under /assets/vendor/
// and load only when the first act comes near.

const ACTS = {
  act1: { rot: 0.35, h: 1.2, ts: 0.55, key: 0xffc27a, rim: 0x7ddb8f, hemi: 0x8a7a66 },
  act2: { rot: -0.35, h: 1.0, ts: 0.5, key: 0xcff6ff, rim: 0x53e8ff, hemi: 0x5a7a8a },
  act3: { rot: 0.2, h: 1.2, ts: 0.5, float: 0.035, key: 0xeadcff, rim: 0xff4fd8, hemi: 0x6a5a8a },
};

export async function mobs(canvases, { still }) {
  await import("./vendor/three.min.js");
  await import("./vendor/GLTFLoader.js");
  const T = globalThis.THREE;
  if (!T?.GLTFLoader) return;
  const stages = canvases.map((canvas) => stage(T, canvas, ACTS[canvas.dataset.mob]));
  let last = performance.now(), clock = 0;
  const tick = (now) => {
    requestAnimationFrame(tick);
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    if (!still) clock += dt;
    for (const s of stages) {
      if (!s.visible || !s.mob) continue;
      s.fit();
      if (!still) {
        s.mob.mixer.update(dt);
        s.mob.holder.rotation.y = s.m.rot + Math.sin(clock * 0.22 + s.phase) * 0.1;
        if (s.m.float) s.mob.holder.position.y = s.m.float * (1 + Math.sin(clock * 0.5 + s.phase));
      }
      s.r.render(s.scene, s.cam);
    }
  };
  requestAnimationFrame(tick);
}

function stage(T, canvas, m) {
  const r = new T.WebGLRenderer({ canvas, antialias: true, alpha: true });
  r.setPixelRatio(Math.min(devicePixelRatio || 1, 1.75));
  r.outputEncoding = T.sRGBEncoding;
  r.toneMapping = T.ACESFilmicToneMapping;
  r.toneMappingExposure = 1.1;
  r.setClearColor(0x000000, 0);
  const scene = new T.Scene();
  const cam = new T.PerspectiveCamera(26, 1, 0.05, 100);
  cam.position.set(0, 0.8, 4.0);
  cam.lookAt(0, 0.55, 0);
  scene.add(new T.HemisphereLight(m.hemi, 0x140c06, 1.0));
  const key = new T.DirectionalLight(m.key, 1.7); key.position.set(2.5, 3, 3); scene.add(key);
  const rim = new T.DirectionalLight(m.rim, 2.4); rim.position.set(-3, 2, -2.5); scene.add(rim);
  const s = { m, r, scene, cam, w: 0, h: 0, visible: false, loaded: false, mob: null, phase: Math.random() * 6 };
  s.fit = () => {
    const w = canvas.clientWidth, h = canvas.clientHeight;
    if (!w || !h || (w === s.w && h === s.h)) return;
    s.w = w; s.h = h; r.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix();
  };
  new IntersectionObserver((entries) => {
    const e = entries[0];
    s.visible = e.isIntersecting;
    if (e.isIntersecting && !s.loaded) { s.loaded = true; load(T, s, canvas.dataset.src); }
    canvas.classList.toggle("shown", e.intersectionRatio > 0.3);
  }, { rootMargin: "500px 0px", threshold: [0, 0.3, 0.6] }).observe(canvas);
  return s;
}

function load(T, s, url) {
  new T.GLTFLoader().load(url, (g) => {
    const root = g.scene;
    const box = new T.Box3().setFromObject(root);
    const size = box.getSize(new T.Vector3());
    const sc = s.m.h / size.y;
    const c = box.getCenter(new T.Vector3());
    root.scale.setScalar(sc);
    root.position.set(-c.x * sc, -box.min.y * sc, -c.z * sc);
    const holder = new T.Group();
    holder.add(root);
    holder.rotation.y = s.m.rot;
    const shadow = new T.Mesh(new T.CircleGeometry(0.45, 32),
      new T.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.45, depthWrite: false }));
    shadow.rotation.x = -Math.PI / 2; shadow.position.y = 0.002; shadow.scale.set(1, 0.6, 1);
    const base = new T.Group();
    base.add(holder, shadow);
    s.scene.add(base);
    const mixer = new T.AnimationMixer(root);
    mixer.timeScale = s.m.ts;
    const idle = g.animations.find((a) => a.name === "idle") || g.animations[0];
    if (idle) mixer.clipAction(idle).play();
    s.mob = { holder, mixer };
  }, undefined, () => {});
}
