// The home page's motion, clips and opt-in sound. Without this file the page is
// the still, finished page that story.css draws. Heavy parts load only when
// their section comes near: the shards, the three rigged foes and the glass.
// Sound starts off and plays only after a press; the clips have no sound.

const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
const sound = setupSound(document.querySelector(".sound"));

heroLight(document.querySelector("#top"), document.querySelector(".hglow"));
clips(document.querySelectorAll(".gv video"));
near(document.querySelector(".shardbox"), () =>
  import("./story-shards.js").then((m) => m.shards(document.querySelector(".shardbox"), { still, sound })));
const foes = [...document.querySelectorAll(".mob-cv")];
if (foes.length) {
  near(foes[0], () => import("./story-mobs.js").then((m) => m.mobs(foes, { still })), "1200px 0px");
}
near(document.querySelector("#glass"), () =>
  import("./story-glass.js").then((m) => m.glass(document.querySelectorAll(".card-cv"), { still })), "900px 0px");

function near(el, run, margin = "600px 0px") {
  if (!el) return;
  const io = new IntersectionObserver((entries) => {
    if (entries.some((e) => e.isIntersecting)) {
      io.disconnect();
      run().catch((error) => console.warn("story:", error));
    }
  }, { rootMargin: margin });
  io.observe(el);
}

// The lantern's light follows the pointer across the hero.
function heroLight(section, glow) {
  if (!section || !glow || still) return;
  section.addEventListener("pointermove", (event) => {
    const box = section.getBoundingClientRect();
    glow.style.transform = `translate(${Math.round(event.clientX - box.left)}px,${Math.round(event.clientY - box.top)}px)`;
  });
}

// In-game footage: muted, looped, and playing only while on screen.
function clips(videos) {
  const io = new IntersectionObserver((entries) => {
    for (const { target, isIntersecting } of entries) {
      if (isIntersecting && !still) {
        target.preload = "auto";
        target.play().catch(() => {});
      } else {
        target.pause();
      }
    }
  }, { threshold: 0.25 });
  for (const video of videos) {
    video.muted = true;
    io.observe(video);
  }
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
      const t = Math.min(1, (now - start) / 900);
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
      effects.shatter ??= new Audio(pick("shatter"));
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
