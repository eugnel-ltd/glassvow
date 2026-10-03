# R2: from the revived Act I to the owner's target

Design lane, 3 October 2026. Written after R1 (Act I revived on main, branch
`map/living-land-2026-10-02`) and before any R2 build. North star: the owner's
target, [`target/owner-target-act1-2026-10-03.png`](target/owner-target-act1-2026-10-03.png)
("Living, immersive, DoF, non-static … Make no mistake."). This is a plan, not a
build: every proof below is scratch code on the revived land, and nothing in the
production tree changes with this document.

## 1. The gap, read off the two images

Revived Act I ([`frames/r2/base.jpg`](frames/r2/base.jpg)) next to the target:

| The target has | Act I today | Technique (§3) |
|---|---|---|
| Golden-hour key light, warm highs, cool shadows, saturated reds | A dim violet night; flat values | Colour grade per act (§3.9) |
| A sharp band through the current stones, soft top and bottom: a miniature | Everything equally sharp | Tilt-shift DoF (§3.1) |
| Ground packed with cover, rocks, trees to the frame | Bare soil between sparse groves | Dressing density (§3.2) |
| Every lantern a flame with a pool of light and a bloom | Small amber dots, no fire | Lanterns as real light with fire (§3.3) |
| Wet road, puddles catching the fire | Dry, matte road | Wet ground and puddles (§3.4) |
| A waterfall and a white torrent under a bannered bridge | A calm, dark channel | Waterfall and torrent (§3.5), banners (§3.6) |
| Things move: leaves, banners, embers, water | Only the water and the pilgrim move | Sway (§3.6), embers (§3.7), living motion at 30 Hz (§3.10) |
| Shafts of warm light | None | Fake god rays (§3.8) |

What the target does **not** change, and R2 must not either: the layout is
MapLayoutFast's (digests, quality registry), the waystone chips float over the
land as HUD (main's GlassWaystone pins, hit regions and states, unchanged by
owner instruction), and the chrome stays main's RunHud. The target's fixed
bottom prompt and its Journey / Whole act controls are its own chrome, not a
request.

## 2. Ground rules for every technique

- **The A12 is the gate, not the Mac.** The Mac's frame interval is pinned near
  8.3 ms (120 Hz present) whatever the scene holds; every proof below measures
  8.9–9.4 ms there. Costs are therefore measured on the iPad 8 (A12, Metal,
  Mobile renderer) through the QA export flow, one launch per technique: a
  live-rendered rest is sampled (360 frames) before and after the technique is
  applied to the same land, at the same camera. Proof harness:
  [`proof/r2/`](proof/r2/) (`qa_r2_probe.gd.txt`, `look_r2.gd.txt`).
- **Read the mean, not only the p95.** With R1's lean profile (MSAA off, the
  journey stage at 0.75 scale, the ground without fine noise), Act I at rest on
  the iPad 8 holds a **mean frame interval of 16.66 ms: a sustained 60 fps with
  no lost frames.** Its p95 is 17.1–20.4 ms depending on the launch, because
  frame intervals jitter around the vsync when the GPU is busy. With the land
  hidden the same screen still measures p95 17.6 ms, and main's painted Act II
  on the same screen 16.9 ms (live) and 17.7 ms (at the rest cadence). So a
  technique's cost shows as a rise in the **mean** (lost frames) and in p50.
  The p95 is reported too, and judged against the same launch's baseline,
  never against 16.67 alone.
- **Headroom exists but is invisible until it runs out.** The mean is pinned
  at the vsync, so a technique that fits costs "0.00 ms" here and one that
  does not shows its whole overrun. Seven techniques below fit; three do not as
  proved, and they are planned with the saving that pays for them.
- **One screen-texture reader.** The river already reads `hint_screen_texture`.
  No R2 technique adds a second: no SSR (Forward+ only anyway), no
  refraction elsewhere, no screen-space god rays.
- **Mobile renderer only.** SSR, SSAO, SSIL, SDFGI and volumetric fog are
  Forward+ features and are out. DoF, glow, adjustments and colour correction,
  GPU particles, decals and `hint_screen_texture` are in.
- **Pins are HUD.** The waystone pins are Controls over the stage, so blur,
  bloom and particles never touch them. What R2 must protect is the land *under*
  a pin (its stone and road) and the touch squares the camera contract audits.
- **The layout contract does not move.** Everything here is presentation: the
  layout digest prints the same before and after every proof
  (`a3ecf0fb9f42…af83c` for seed 1). The journey kit's own planting is not the
  layout's `scenery_instances`; where a technique changes the land's
  scenery-acceptance digests, that lands in an explicit commit that says why.
- **Size.** Acts II–IV at ≤ +25 MB each; R2's new art for Act I (flame
  flipbook, banners, cover kinds, a LUT) is small and VRAM-compressed (§5).
- **Reduce Motion.** Every moving technique has a still state; under Reduce
  Motion the rest cadence is 15 Hz and only lantern flicker moves.

## 3. Technique by technique

Each section: what it delivers in the image; the Godot 4.7 Mobile method; the
Mac proof still from the revived Act I, isolating it; measured cost on the Mac
and the A12, and the mitigation; its interaction with tappability and the quality
contract. Mac stills are 1180×820 (pad), seed 1, after two steps, captured
headed with `--rendering-method mobile`. A12 costs are the change in mean frame
interval, p50 and p95 from the same launch's baseline (lean profile, stage
885×663, live render, 360 frames each).

**Measured costs.** Mac: frame p95 with vsync off and the stage rendering
every frame (`concept_look --measure`), with stage draw calls and primitives.
A12: one launch per row, baseline then technique.

| Technique (proof) | Mac p95 ms | Mac stage calls / prims | A12 mean ms | A12 p50 ms | A12 p95 ms | Verdict on the A12 |
|---|---|---|---|---|---|---|
| none (base) | 9.05 | 57 / 76k | 16.66 → 16.66 | 16.8 → 16.7 | 20.0 → 20.3 | the noise floor |
| Colour grade (`grade`) | 9.02 | 57 / 76k | 16.66 → 16.66 | 16.6 → 16.7 | 20.2 → 20.4 | free |
| Lantern fire with two-level bloom (`fire+bloom2`) | 9.03 | 58 / 76k | 16.66 → 16.66 | 16.7 → 16.8 | 20.0 → 20.6 | free |
| Lantern fire, default glow (`fire`) | 9.03 | 58 / 76k | 16.66 → 17.78 | 16.8 → 16.7 | 20.0 → 21.4 | p50 unchanged: the mean rise is a one-off stall (the flame's pipeline compiling during the sample), not a per-frame cost; the two-level run above is the reading |
| Tilt-shift, screen band (`tiltshift`) | 9.02 | 57 / 76k | 16.66 → 16.66 | 16.8 → 16.7 | 20.3 → 19.5 | free, at display resolution |
| DoF, depth, far only (`doffar`) | 9.11 | 57 / 76k | 16.66 → 17.92 | 16.8 → 17.2 | 20.0 → 28.2 | +1.3 ms: 7 % of frames lost |
| DoF, depth, near and far (`dof`) | 9.11 | 57 / 76k | 16.66 → 19.17 | 16.6 → 17.4 | 20.4 → 37.6 | +2.5 ms: 13 % of frames lost |
| Wet ground, no glints (`wet`) | 9.36 | 57 / 76k | 16.66 → 16.66 | 16.7 → 16.7 | 20.1 → 20.7 | free |
| Embers (`embers`, 260 particles) | 9.38 | 58 / 76k | 16.66 → 16.66 | 16.7 → 16.9 | 19.9 → 20.0 | free |
| Fake god rays (`rays`, 5 cards) | 9.09 | 63 / 76k | 16.66 → 16.66 | 16.7 → 16.7 | 17.1 → 17.2 | free |
| Foliage sway (`sway`, 41 surfaces) | 9.42 | 57 / 76k | 16.66 → 16.67 | 16.7 → 16.7 | 20.4 → 18.2 | free |
| Torrent foam and mist (`torrent`, river framed) | 9.06 | 58 / 76k | 17.13 → 18.24 | 16.7 → 17.0 | 24.8 → 27.2 | +1.1 ms where the river is in frame |
| Density, cover and trees (`density`, +316) | 8.95 | 58 / 78k | 16.67 → 20.50 | 16.8 → 19.7 | 20.2 → 30.7 | +3.8 ms; shadow primitives 323k on the Mac stack |
| Density, cover only (`densitycover`, +292) | n/a | n/a | 16.66 → 19.82 | 16.8 → 18.5 | 20.1 → 30.1 | +3.2 ms; shadow pass unchanged |
| The stack (`grade+densitycover+fire+bloom2+wet+embers+doffar`) | 9.39 | 62 / 87k | 16.66 → 21.06 | 16.7 → 18.5 | 20.4 → 44.2 | +4.4 ms: density and depth DoF are the whole overrun |

The A12's own stage counters for the base: 34 draw calls and 48.7k primitives
in the stage, 27 calls and 35.2k primitives in the shadow pass. Density added
3 draw calls and 9.4–10.3k primitives. That is not enough geometry to cost
3 ms, so the cost is **fragment cost**: cut-out (alpha-scissor) foliage
`discard`s, which turns off the A12's hidden-surface removal for those
fragments, and cover overlaps itself many times over.

The stacked proof, against the base:
[`frames/r2/stack.jpg`](frames/r2/stack.jpg),
[`frames/r2/stack-gateway.jpg`](frames/r2/stack-gateway.jpg).

### 3.1 Tilt-shift depth of field

**Delivers:** the single strongest "miniature" cue in the target. A sharp band
through the current group, soft at the far edge (top) and the near edge (bottom).

**Methods compared:**

1. **`CameraAttributesPractical` DoF** (depth based). Works on the Mobile
   renderer with the orthographic 55° camera: [`frames/r2/dof.jpg`](frames/r2/dof.jpg)
   (near and far), [`frames/r2/doffar.jpg`](frames/r2/doffar.jpg) (far only). With
   a 55° pitch, ground depth spans only ±6 m over the frame, so the bands are
   tight (far at focus +1.5 m with a 3 m transition; near at focus −1.5 m).
   **Problem shown by the proof:** near blur catches anything *tall* standing
   toward the camera (the bridge's arch, near conifers), mid-frame, because
   height brings it closer. The target blurs the bottom of the *frame*, not tall
   objects in the middle. So near blur by depth is wrong for this camera.
2. **Post blur on the stage's display** (screen band, no depth). A canvas
   shader on `MapScene`'s display rect: [`frames/r2/tiltshift.jpg`](frames/r2/tiltshift.jpg).
   It runs at the *display* resolution (2160×1620 on the iPad 8, about six times
   the lean stage's pixels), so every tap costs six times what it would in the
   stage. Depth-blind: a near tree's crown in the top band blurs like the
   ground under it.
3. **Two-pass near/far render.** Two cameras with split clip ranges into two
   SubViewports, the far one blurred at quarter resolution, then composited. It
   doubles draw submission, and the directional shadow map is rendered per
   viewport, so it doubles the shadow pass too. Rejected for the A12 on cost
   before measuring; it is the Forward+ answer, not the Mobile one.
4. **Static radial-mask fallback.** No blur: two soft haze gradients (top and
   bottom) in one full-screen quad with a pre-made gradient texture, tinted to
   the act's fog colour, plus a slight desaturation. Almost free; reads as
   "atmosphere" rather than "lens".

**Cost on a 2160×1620 stage.** Measured on the A12: depth DoF at the lean
stage (885×663, 0.59 Mpx) costs +1.3 ms (far only) to +2.5 ms (near and far)
of mean frame interval, so it already loses frames. DoF cost scales with
pixels; a native 2160×1620 stage (3.5 Mpx, six times the pixels) would put it
at roughly 8–15 ms, which rules it out at native resolution. The screen band
runs at the display's 2160×1620 already and measured no loss: its nine taps
per pixel are cheap next to the bokeh pass and its depth reads.

**Recommendation:** the **screen band** (method 2), top and bottom, as the
tilt-shift. It is what the target shows (a lens band across the frame, not a
depth effect), it costs nothing measurable on the A12, and it never catches a
tall object mid-frame. The band's centre and width follow the Journey
framing's group, so the reachable stones sit in the sharp band; it eases with
the camera (60 Hz while the camera moves, frozen with the stage at rest). In
Whole act it is off: that view is for reading the act. Depth DoF is kept only
as an experiment for a later device tier. Fallback (if the band ever costs
too much): method 4.

**Cost:** see the paragraph above and the cost table: screen band, Mac p95
9.02 ms and A12 no loss; depth DoF, A12 +1.3 to +2.5 ms.

**Tappability and quality:** pins are never blurred (they are HUD over the
display). The sharp band is derived from the Journey framing's group, which
the camera contract already keeps inside the safe rect, so every reachable
stone and its road stay sharp. The R2 test asserts that every framed member's
projected seat lies inside the band at every reference shape.

### 3.2 Dressing density

**Delivers:** the target's packed ground: cover, rocks and trees to the frame
edges, so the road reads as cut through a wood rather than drawn on soil.

**Method:** a second planting pass in the journey kit after the groves, through
the kit's own clearance rule (`Kit.clear`) and road distance, of ground-cover
kinds only (`ash-heath`, `ash-copse`, `ash-fern`, `ash-bramble`). They batch
into the existing per-32 m-cell MultiMeshes (`StaticScenery`), so the draw-call
cost is per cell and per kind, not per plant. Far conifers past the far DoF
band can become cross-quad impostors: they are blurred anyway.

**Proofs:** [`frames/r2/density.jpg`](frames/r2/density.jpg) (316 plants added in
frame, trees included) and [`frames/r2/densitycover.jpg`](frames/r2/densitycover.jpg)
(292 cover plants only). **Measured on the Mac:** adding trees took shadow
primitives from 52k to 323k in the stacked proof, three times the 100k budget;
adding only cover kinds left the shadow pass unchanged (52,284 → 52,284),
because `StaticScenery.NO_SHADOW` keeps them out. Stage primitives +2.5k per
150 plants.

**A12 cost and mitigation:** +3.2 ms of mean for 292 cover plants, all of it
fragment cost (see the cost table). So density ships only with its saving:
(1) **opaque cover kinds**: heath, fern and bramble clumps modelled with real
silhouettes in the Blender recipes, opaque, no `discard`, so the A12 keeps its
hidden-surface removal; (2) cut-out foliage kept to tree crowns, which are few
and large; (3) cover beyond the far blur band replaced by the ground paint's
own litter colour (the habitat texture already carries it), since it is soft
there anyway; (4) the per-cell limit below. The step lands only when the
device run shows the mean back at 16.66 ms.

**Scenery rules and density limit:** cover never inside a waystone's touch
square, never within 1.2 m of a road's centreline or on a bridge, never taller
than 0.8 m within 3 m of a seat (so no crown hides a stone or road under a
pin); at most 220 instances per 32 m cell and 120k stage primitives at the
default framing; new trees only where they do not raise the shadow pass above
100k primitives (proxy casters if they must). The density rule is
deterministic from the land's own seed, like the kit's current planting.

**Cost:** Mac p95 8.95 ms (floor), stage primitives +2.5k; A12 +3.2 ms
(cover only) to +3.8 ms (cover and trees) of mean. See the mitigation above.

**Tappability and quality:** the clearance rule above; the camera contract audit
already checks seat visibility. The kit's acceptance digests change, in an
explicit commit.

### 3.3 Lanterns as real light with fire

**Delivers:** the target's warm life: each lantern a flame, a pool of light on
the ground around it, and a bloom.

**Method:**

- **Flame:** a camera-facing card per lamp with a 4×4 flipbook (256×256 atlas,
  ASTC; one shared material, the frame offset from a per-lamp hash so they do
  not flicker in step). Additive, unshaded, depth-tested, no depth write.
- **Light pools:** real `OmniLight3D`s only for the Flame (the pilgrim's lamp)
  and the nearest four lamps to the focus, shadowless. The Mobile renderer
  allows 8 omni lights per mesh instance; the chunked terrain (32-cell chunks)
  keeps each chunk under that. Every other lamp gets a painted pool: an
  additive radial blob on the ground (one quad, or a `Decal` with an emission
  texture), flickering in the same shader as its flame.
- **Bloom:** `Environment` glow with **two levels only** (levels 1 and 2: the
  half- and quarter-resolution mips), HDR threshold 0.95 so only flames and
  their brightest pools bloom.

**Proofs:** [`frames/r2/fire.jpg`](frames/r2/fire.jpg), the gateway before and
after ([`frames/r2/gateway-base.jpg`](frames/r2/gateway-base.jpg),
[`frames/r2/gateway-fire.jpg`](frames/r2/gateway-fire.jpg)), and two-level bloom
([`frames/r2/bloom2.jpg`](frames/r2/bloom2.jpg)). The proof's flame is a
procedural shader standing in for the flipbook.

**Cost:** Mac p95 9.03 ms (floor); A12 no loss with two glow levels (mean
16.66 → 16.66). The flame's first draw compiles a pipeline (a one-off stall in
the fire-only run), so the flame material joins the shader warm-up the land
already does behind the charting veil. Mitigation if lamps multiply: painted
pools instead of omni lights beyond the nearest four.

**Tappability and quality:** flames and pools sit on lamp posts and the ground;
bloom is under the HUD. A pool must never be brighter than the selected pin's
ring (luminance check in the capture test).

### 3.4 Wet ground and puddles

**Delivers:** the target's wet road catching the fire.

**Method, with no second screen reader:** in `terrain_paint.gdshader`, a puddle
mask (the road core times a low-frequency noise; or the `habitat` texture's
free alpha channel, baked with the land) lowers roughness and raises specular,
so the key light and the four real lamps give true specular glints. The
"reflection" is faked: a fresnel-weighted emission of the act's sky tint, plus
analytic glints from up to four lamp positions passed as a uniform array
(reflect the view vector off the puddle normal and compare with the direction to
each lamp). No reflection probe, no screen read. In the lean profile the glints
run only inside the puddle mask (a branch), so dry ground pays one noise lookup.

**Proof:** [`frames/r2/wet.jpg`](frames/r2/wet.jpg). It shows the method, not the
look: the puddles read too pale and too uniform (the fake sky term mirrors the
background). The R2 build tunes the sky tint per act and adds the lamp glints,
which the proof does not have.

**Cost:** Mac p95 9.36 ms; A12 no loss (16.66 → 16.66) without the glints.
The glints add ALU only inside the puddle mask; the build measures them on
the device before they ship, and the lean profile can drop them.

**Tappability and quality:** none; the road stays the road. Puddles stop 0.5 m
short of a waystone's seat so the stone's base reads.

### 3.5 Waterfall and torrent

**Delivers:** the white water, waterfall and mist under the target's bridge.

**Method:** in the river's existing shader (no extra draw): a foam layer of
scrolling streak noise along the flow, stronger where the bathymetry is
shallow and around the bridge piers (the shader already has the piers). Mist:
12–20 soft camera-facing sprites per river, near the bridges and the drop,
each ≤ 2.2 × 1.6 m, alpha ≤ 0.22: bounded coverage, bounded overdraw.
Waterfall: MapRavine does not change, but the journey river's *surface level*
can step down at a crossing (a presentation-side change to `River.LEVEL` along
its length and the bank shader's `river_level`), with a scrolling-UV card strip
at the step and a mist cluster at its foot. The water stays on the D2 cadence
(30 Hz, 15 Hz under Reduce Motion).

**Proofs:** the river framed alone and with foam and mist,
[`frames/r2/river-base.jpg`](frames/r2/river-base.jpg),
[`frames/r2/river-torrent.jpg`](frames/r2/river-torrent.jpg). The proof's foam
is separate strips (so it can be isolated); the build folds it into the river
shader.

**Cost:** Mac p95 9.06 ms; A12 +1.1 ms of mean where the river is in frame
(17.13 → 18.24; the river framing's own base is already 17.13). Mitigation:
fold the foam into the river shader (it removes the proof's nine extra
draws), cap the mist sprites and their screen coverage (no sprite larger than
2.2 × 1.6 m, ≤ 20 per river, none within the near blur band), and stop the
mist at the 15 Hz Reduce Motion cadence.

**Tappability and quality:** the river is already kept clear of waystones by the
layout; mist sprites stay below the bridge deck and off the touch squares.

### 3.6 Banners and foliage sway

**Delivers:** "non-static": the target's leaves and banners move.

**Method:** vertex sway in the foliage material (the kit's cut-out
`StandardMaterial3D` becomes a `ShaderMaterial` with the same texture and
scissor): displacement = `sin(TIME × 1.3 + world phase) × amplitude × vertex
height`, so trunks and bases stay put. The shadow pass runs the same vertex
function, so shadows sway with their trees. Banners: cloth cards on the bridge
parapets (a small new GLB from the Blender recipes) with a travelling vertex
wave; no physics. Reduce Motion: amplitude 0.

**Proof:** a still cannot show motion, so the proof is a frame difference:
[`frames/r2/motion-sway-diff.jpg`](frames/r2/motion-sway-diff.jpg). Ten frames
apart, 30,809 pixels change with sway and 113 without (pad, 967,600 pixels).
41 foliage surfaces converted.

**Cost:** Mac p95 9.42 ms; A12 no loss (16.66 → 16.67). Vertex ALU only.

**Tappability and quality:** amplitude ≤ 8 cm at a crown's top; no plant near a
seat is tall enough to sway over it (§3.2's 0.8 m rule).

### 3.7 Embers and ash

**Delivers:** the warm sparks drifting through the target's air.

**Method:** one `GPUParticles3D` (about 260 embers, billboard quads 5 cm,
additive emissive), its emission box following the camera's focus, its
visibility AABB bounded to the frame. Act I adds ash flakes (a second draw pass
in the same system). Reduce Motion: off.

**Proof:** [`frames/r2/embers.jpg`](frames/r2/embers.jpg).

**Cost:** Mac p95 9.38 ms; A12 no loss (16.66 → 16.66) at 260 particles, one
draw call. Mitigation: halve the count on the lean profile if a later step
needs the headroom.

**Tappability and quality:** particles are tiny and additive; none is drawn
in front of the HUD.

### 3.8 Fake god rays

**Delivers:** shafts of warm light through the canopy.

**Method:** a few (≤ 5) long additive cards aligned with the key light's
direction, soft at both ends and both edges, placed by rule at canopy gaps near
the focus, fading as they turn edge-on. No volumetric fog (Forward+ only), no
screen-space radial blur (a second screen read).

**Proof:** [`frames/r2/rays.jpg`](frames/r2/rays.jpg). Honest read: at this
camera they can look like cards. They are last in the build order and need the
owner's eye.

**Cost:** Mac p95 9.09 ms; A12 no loss (16.66 → 16.66) for five cards (five
draw calls of additive overdraw). Mitigation: fewer cards, and off in Whole
act.

### 3.9 Colour grade per act

**Delivers:** more of the target's look than any other single change: the
golden-hour key, warm highs, cool shadows, saturated autumn reds.

**Method:** per act, in the `Environment` the land already owns: key light
colour and energy, ambient colour, exposure, and `adjustment_*` (brightness,
contrast, saturation), with an optional 32³ colour-correction LUT
(`adjustment_color_correction`, 128 KiB) once the look is set. All of it runs in
the tonemap pass that already runs, so it costs almost nothing.

**Proof:** [`frames/r2/grade.jpg`](frames/r2/grade.jpg) (key `ffd1a0` at ×1.45,
ambient `7d86a8` at 0.55, exposure 1.15, saturation 1.18, contrast 1.06).

**Cost:** Mac p95 9.02 ms; A12 no loss (16.66 → 16.66).

**Tappability and quality:** the pins' contrast against the land must hold
under the new key light. The capture test measures pin-ring contrast at every
shape.

### 3.10 Living motion at 30 Hz

**Delivers:** the whole of "non-static" without paying for 60 Hz renders at
rest.

**Method:** D2 is already built in R1: at rest the stage renders every second
frame (30 Hz), every fourth under Reduce Motion (15 Hz), and stops while parked;
input, travel and the camera go to 60 Hz. Every R2 motion (water, flames, sway,
embers, mist, banners) is a function of `TIME` in a shader or a particle system,
so it reads correctly at whatever cadence the stage renders, and no node moves
on the CPU per frame. The dossier's §3 table (cloud shadow, lantern flicker,
road kindle on a step) still applies.

**Cost:** measured on the iPad 8 in R1, the 30 Hz cadence leaves the rest
frame interval where live rendering puts it (mean 16.66 ms, p95 20.2 ms against
20.7 ms live): the stage frames themselves fit in a vsync, so halving their
number saves energy and heat rather than frames. The cadence is still the
right default for a phone held for minutes on the map; every R2 step is
measured both live and at the cadence.

## 4. Ranking and build order

Gain is the owner-visible gain toward the target, judged against the
target image (high, medium, low). Cost is the A12 mean-frame cost measured
above.

| Rank | Technique | Gain | A12 cost | Gain per ms |
|---|---|---|---|---|
| 1 | Colour grade per act (§3.9) | High: most of the target's mood in one change | 0 | free |
| 2 | Tilt-shift, screen band (§3.1) | High: the "miniature" read the owner named ("DoF") | 0 | free |
| 3 | Lanterns with fire, pools, two-level bloom (§3.3) | High: the warmth and focal points | 0 | free |
| 4 | Foliage sway and banners (§3.6) | Medium-high: "non-static" across the frame | 0 | free |
| 5 | Embers and ash (§3.7) | Medium: life in the air | 0 | free |
| 6 | Wet ground and puddles (§3.4) | Medium: catches the lamps | 0 (glints to be measured) | free so far |
| 7 | Dressing density, opaque cover (§3.2) | High: the packed wood | +3.2 ms as proved; ships only once its saving brings it to 0 | high once paid for |
| 8 | Waterfall and torrent (§3.5) | Medium: a set piece, local to the river frames | +1.1 ms in river frames | medium |
| 9 | Fake god rays (§3.8) | Low to uncertain: may read as cards | 0 | needs the owner's eye |
| 10 | Depth DoF (§3.1, method 1) | Superseded by the screen band | +1.3 to +2.5 ms | none |

**Build order.** Each step is one ordinary PR, shippable on its own, gated by
the full core gate, the A12 Metal capture of every new or changed shader, the
pixel captures at the three reference shapes in both locales, and an iPad 8
run of the map probe whose mean frame interval at rest stays at 16.66 ms
(p95 within 1 ms of the R1 baseline in the same launch). A step that fails the
device gate is fixed or cut before the next one starts.

1. **Light and grade.** Act I's golden-hour key, ambient, exposure and
   adjustments; two-level bloom; lantern posts along the roads with the flame
   flipbook on every lamp and a painted pool under each; real lights on the
   Flame and the four nearest lamps on the desktop only (on the iPad 8 they
   were the one part of the lamps that cost frames, so the lean profile has
   none); the flames draw in the land's first frame, behind the veil. Pin
   contrast measured at every shape. *(Built: §8.)*
   - **1b. Contact and canopy light.** (from the owner's Tiny Delivery reference,
     below). A soft contact shadow under every prop, post, stone and waystone:
     one more 4 px/m channel painted by `bind_habitat` from each placement's
     footprint and read once in the ground shader (the habitat map's four
     channels are taken). Dappled canopy light: inside the woodland's reach the
     ground shader breaks the key into patches with one low-frequency noise
     (ALU only). A backlight rim on foliage edges facing the key, in
     `foliage.gdshader` (`BACKLIGHT`, ALU only). Expected cost: one texture
     read and a few ALU on the ground, a few on the foliage; gated on the
     device like step 1, cut piece by piece if the mean leaves 16.66 ms.
2. **Tilt-shift.** The screen band on the stage display, framed by the Journey
   group, off in Whole act, with the band-covers-the-group test.
3. **Living motion.** Foliage sway in the kit's cut-out materials (shadow pass
   included), banners on the bridges (one small GLB from the Blender recipes),
   embers and ash; all off under Reduce Motion except lantern flicker.
   *(Built: §8.)*
   - **3b. Small life.** (from the reference). Moths circling the burning
     lanterns: one MultiMesh of tiny wing cards orbiting each lamp anchor in the
     vertex shader (one draw for every lamp, no CPU per frame). Crows: a few
     per act, a small low-poly crow from the Blender recipes (two poses), each
     perched by rule on a stone, post or verge away from every waystone; when the
     pilgrim walks within 3 m one hops and flies off along a short scripted arc
     and settles again further on (the only CPU-driven motion, a handful of
     nodes, only while walking). Both off under Reduce Motion, both kept out of
     the pins' touch squares, both local (a moth never leaves its lamp's 1 m).
4. **Wet ground.** Puddles in the ground paint with analytic lamp glints, the
   act's sky tint; measured with and without glints on the device.
5. **Water.** Foam folded into the river shader, bounded mist, the waterfall
   step at one crossing and its card strip.
6. **Density and ground detail.** Opaque cover kinds from the Blender
   recipes, the fill pass with the clearance rule and per-cell limit, litter
   paint beyond the far band; the kit's acceptance digests in an explicit
   commit. With it, the reference's ground-detail pass: the ground paint gains
   a macro and a micro scale so no area reads as one flat colour; instanced
   ground cover and flower clusters (opaque, the Ashen Woods palette: ash-grey
   soil, red leaf litter, pale ash flowers, ember berries) drawn to every hard
   edge, at wall and post bases, waystone footings, bridge abutments and road
   verges; ragged verges and wheel ruts on the main road in the paint. And
   story props in small composed groups along the road (fallen lantern posts,
   broken waystones, abandoned pilgrim packs and staffs, a collapsed shrine
   arch); what the Ashen Woods may hold goes through the story skill first.
   This is the step most likely to need a second device iteration, so it comes
   after the free techniques have shipped.
7. **God rays,** only if the owner wants them after seeing step 6.

**Revised order (orchestrator review of steps 1–3, 3 October).** The three
largest remaining gaps against the target are the bare ground, the near
top-down camera and the two-stone framing. Next: (a) a camera study, as
scratch proofs ([camera-study.md](camera-study.md): the pick is 40°
orthographic with the Journey view at 1.6 times today's floor); (b) step 6,
density and ground detail, built at the chosen camera against its own saving;
(c) then steps 3b, 4, 5 and 7.

Steps 1–3 deliver most of the gap at no measured cost; that is why they come
first. Steps 1b and 3b are cheap additions gated the same way. Steps 4–5 are
local; step 6 is the costly one and is built against its own saving.

**The owner's second reference (3 October, 11:05).** James shared an 18 s
trailer of the indie game *Tiny Delivery*
(https://x.com/artem_sini39436/status/2106289186567590144; the clip and its
frames stay in the lane's scratch, never in the repository) as "some idea for
the map design too. some details". It is a reference for detail and life,
not palette: the owner's target (red woodland, golden hour) stays the look.
What it shows is three scales of ground variation, growth softening every
hard edge, ruins in small composed groups, contact and dappled shadows, and
small local life. Those are steps 1b, 3b and the ground-detail half of step
6. Its slow camera pan is a trailer move: the map's camera stays fixed (§6).

## 5. Size

Act I's R2 art is small, and every texture is VRAM-compressed (`compress/mode=2`,
mipmaps), shared where it can be, and never embedded in a GLB:

| Asset | Estimate |
|---|---|
| Flame flipbook, 4×4 frames on a 256×256 atlas, ASTC | under 0.1 MiB |
| Banner GLB and its cloth texture (512×1024) | about 0.4 MiB |
| Three or four opaque cover kinds, sharing the kit's foliage and stone textures | about 1.5 MiB |
| Colour-correction LUT, 32³ | 0.13 MiB |
| Waterfall card strip texture (256×1024) | about 0.2 MiB |
| Contact-shadow channel (step 1b), 384×240 R8, built at run time | 0 in the package, 0.09 MiB of VRAM |
| Moth wing card (step 3b), 64×64, shared by every moth | under 0.01 MiB |
| Crow GLB, two poses (step 3b), flat colours | about 0.05 MiB |
| Ground cover and flower clusters (step 6), four or five kinds sharing one 512×512 atlas | about 0.6 MiB |
| Story props (step 6), five to seven GLBs on the kit's existing stone and bark sources | about 1.0 MiB |

About 4 MiB for Act I's R2 in all, on top of R1's 6.0 MiB (`tools/payload_report.py`:
254.8 → 260.8 MiB against origin/main `dc6d8fb3`; `assets/art/map-journey`
5.7 MiB, now budgeted at 6 MiB). Acts II–IV each stay within +25 MB, reusing
the techniques and sharing textures across acts. The proof stills and
sources live under `docs/`, which the export never packs.

## 6. Later, not in R2

- **Nodes:** the owner will rethink the waystones later ("We rethink the nodes
  later", 3 October 01:25); R2 keeps main's GlassWaystone pins, hit regions and
  states exactly.
- **The establishing shot (D1):** accepted, skippable, not built; it belongs
  after R2's look is approved.
- **Acts II–IV:** each act's journey land after Act I's R2 is reviewed, at ≤ +25
  MB each.
- **Idle camera drift, an open idea only.** The map is a fixed camera by owner
  decision. If the owner ever wants the reference's sense of a moving view:
  drift of at most 0.3 m after 4 s idle, stopped by any touch, and only if the
  pins and their touch squares stay put. Not planned.

## 7. How to rerun the proofs

Copy `proof/r2/look_r2.gd.txt` to `scratch_lane/look_r2.gd`,
`proof/r2/concept_look.gd.txt` to `scratch_lane/concept_look.gd`, and the
phase-1 dressers it preloads (`proof/look_a.gd.txt`, `look_b`, `look_c`, and
the shaders they load, with their real extensions) beside them; never commit
them. Then, headed:

```bash
godot --path . --rendering-method mobile -s res://scratch_lane/concept_look.gd -- \
  --concept=r2grade+densitycover+fire+bloom2 --steps=2 --shape=pad-landscape \
  --measure --output=/tmp/x.png
```

`--concept=r2` alone is the base; techniques join with `+`; `--pose=gateway` and
`--pose=river` frame the gateway and the river. The A12 costs come from the QA
export flow with `proof/r2/qa_r2_probe.gd.txt` as `tools/qa_r2_probe.gd`,
`look_r2.gd` as `tools/look_r2.gd` and `device_patch.py.txt` applied to
`application/main.gd`, launched with
`devicectl … -- --map --map-r2-probe --r2=<techniques> --seed=1 --shape=pad-landscape`;
rows go to `Documents/r2_probe.jsonl`.

## 8. Build log: steps 1–3 (branch `map/r2-light-2026-10-03`)

Every step was gated on the iPad 8 (A12, lean profile, live rest render, 360
frames) against R1 in the same launch (`proof/r2/` `r1look`: Review 10's light,
no lamps, pools, band, motion or air), on the Mac with the A12 Metal condition
(0 errors at pad and phone, lean and full), and at the three shapes in both
locales. Stills: [`frames/r2-build/`](frames/r2-build/).

| Step | Head | iPad 8 rest, mean (ms) | p95 gap to R1, same launch (ms) | Notes |
|---|---|---|---|---|
| 1, first build | `01167f24` | 16.76, 16.75 | +4.0, +0.42 | Failed: real lamp lights cost frames (each ingredient removed in its own launch; only the lights moved p95, 21.3 → 20.2) |
| 1 | `239855a0` | 16.66, 16.66, 16.66 | −0.30, +0.07, +0.06 | No real lamp lights on the lean profile |
| 2 | `d3cd5f15` | 16.67, 16.67, 16.66 | −0.30, +0.05, −0.25 | Placement follow-up `7553b706` changes no pixel cost |
| 3 | `2537127d` | 16.76¹, 16.66, 16.66, 16.66, 16.66, 16.67 | −0.03, +0.20, −0.07, +0.11, +0.37, −0.43 | ¹ first launch after install |
| 3, air fix | `4d7a6420` | — | — | Removes a 133 ms frame on attach (below) |

Opens on the iPad 8 (map probe, pad, seed 1): R1 cold ready 2.70 s, warmed
350 ms, reopen 42–51 ms. Step 1: cold 2.90 s (main thread 967 ms, worst frame
17 ms), warmed 341 ms, reopen 48–57 ms, walk p95 16.8 ms. Step 3 at
`2537127d` showed a 133 ms frame right after the land attached, on cold and
warmed opens alike (cold worst frame 50–82 ms): each new land's embers and
ash pre-simulated a whole lifetime in its first frame. `4d7a6420` starts the
air empty instead.

Pin contrast (rim against the land just outside it, WCAG ratio; R1 light →
R2, same land): phone min 1.26 → 1.41, pad 2.00 → 2.17, desktop 1.22 → 1.18
(one pin at the frame's edge; every other desktop pin holds or rises). Disc
against land: phone 1.75 → 2.17, pad 1.16 → 1.13, desktop 1.16 → 1.13.

Mac (pad, desktop profile, `4d7a6420`): cold open 2.08 s (main thread 654 ms,
worst frame 23 ms), warmed 222 ms, reopen 15–19 ms, kept VRAM 68.0 MiB; rest
p95 7.4–10.9 ms, walk p95 3.0–3.6 ms; stage 155 calls and 144k primitives,
shadow pass 70k primitives. Act II unchanged.

Payload (`tools/payload_report.py`): `assets/art/map-journey` 5.8 MiB of its
6 MiB budget; the iOS pck estimate 260.9 MiB of 400.

## 9. Build log: (b) camera, room, density (rebased onto `0f5aeda6`)

The order the review set: the camera change, then room made at the new camera
until the rest mean is back at 16.66–16.7 ms, then density against that room.
Every device row comes from the QA app (`io.fol2.glassvow.qa`) on the iPad 8,
lean profile, under the batch lock, each launch checked by a nonce its rows
echo. The map probe's rest is 600 frames at the Journey view, mid-route (two
steps, pad); missed means intervals over 25 ms.

**1. Camera** (`72aaed4b`, `916d534f`, `d9d18b6e`, envelopes `2caf16f3`):
the contract at 40°, the 12 m floor, planting reserves and the conifer
envelopes at the new pitch, the sharp band sized to the framed cluster, the
seated waystones' stone texture restored. Fresh comparison with the target:
[`frames/r2-build/vs-target-after-camera.jpg`](frames/r2-build/vs-target-after-camera.jpg).

**2. Room** (`545822f3`, `abef1d9e`, `9f11d63e`):

| Change | Where the cost went |
|---|---|
| River without screen or depth reads on the lean profile (`river_lite.gdshader`), half the grid | about 0.85 ms of mean in river frames |
| Conifers cast through one opaque cone each (lean), not their cut-out foliage | 0.3 ms mean, 1.9 ms p95 |
| Ground chunks cast no shadow; `mesh_lod_threshold` 6 on the lean stage; lighter pilgrim spheres | stage 98.9k → 72.0k primitives, shadow 62.3k → 31.1k (Mac, lean) |
| The journey camera clips to the land's slab (`MapJourneyCameraContract.depth_range`) | an orthographic camera's shadow covers its whole near-to-far slice (the engine ignores the light's max distance for one); 0.05–400 m became about 26–75 m; shadow draws 87 → 63 |
| Stage scale on the lean profile (0.67, 0.60) | nothing: the stage is not fill-bound (kept at 0.75) |

Not changed, and why: a higher LOD threshold or a per-kind LOD bias removes
the trees' and shrubs' cut-out leaves outright (the generated LODs collapse
the cards), so it buys triangles with the woodland itself; shadows off saved
nothing measurable (16.80 → 16.80 in one launch).

At the rebased head `9f11d63e`: rest mean **16.80** and **16.96 ms** (missed 6
and 12 in 600 frames); R1's camera and light in the same launch 16.80 →
16.66 ms, p95 −0.96 ms. Before the rebase, `e9d566e7`: p50 16.73 ms. The p95
half of the gate holds; the mean does not reach 16.66–16.7 at the new camera.
Scripts take about 0.9 ms of main thread a frame and the stage's render setup
0.6 ms, at spikes as at rest, so the missed frames are GPU or presentation
time, not script time (Metal reports no GPU timestamps to the probe).

The fresh run's opening view frames five stones at a 29.9 m view (the Journey
view is 19.2 m), so it draws more: 111 stage draws and 91k primitives against
87 and 72k. It is the same cause as R1's drop and is mostly fixed with it: R1
p50 19.8 ms there, now 17.2 (mean 17.13, missed 19).

Opens at `9f11d63e` (with main's title warm): cold ready 2.15–2.27 s, warmed
100–103 ms, reopen 37–56 ms.

**3. Density** (built, **not landed**: branch `wip/r2-density-2026-10-03`):
the ground's three scales, ruts and ragged verges in `terrain_paint.gdshader`;
eight opaque cover and story pieces (art ledger); clumps at the foot of every
hard edge, along the verges and in a few open patches, 1.2 m off every road
centreline, held to 3,200 triangles per 16 m cell and merged into one
shadowless draw per cell from pieces baked offline (no mesh is read back from
the renderer at run time). Story groups use settled Act I canon only: stones,
spore caps, roots, a pale mask; no walker's belongings. Measured in
interleaved launches of one build of it: cover hidden 17.05 and 17.36 ms, shown
17.52 ms (missed 15 and 29 against 34); on the Mac the Journey view gains 9
draws and 22k primitives. Comparison with the target:
[`frames/r2-build/vs-target-density-candidate.jpg`](frames/r2-build/vs-target-density-candidate.jpg):
the clumps read, the target's packed wood does not.
