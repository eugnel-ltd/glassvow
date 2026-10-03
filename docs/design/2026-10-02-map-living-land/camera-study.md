# R2 (a): the Journey camera study

Design lane, 3 October 2026. Asked by the orchestrator after reviewing R2 steps
1–3: the target is a low oblique view that holds a cluster of the road, while
ours reads near top-down and frames two or three stones with empty margins.
Scratch proofs only; nothing in the production tree changes here.

## Method

The same framed stones (seed 1, two steps in: the pilgrim's stone and the next
one) under the production Journey fit, generalised in one scratch module
([`proof/r2/look_cam.gd.txt`](proof/r2/look_cam.gd.txt)):

- **Pitch** 55° (today), 45°, 40°, 38°, 35°, 32°.
- **Projection** orthographic (today), or perspective at a 30° or 45° vertical
  FOV, the camera's distance and centre solved so the same stones fill the same
  safe frame.
- **Width**: today's fit never frames less than 12 m of height; the study also
  tries 1.4×, 1.6×, 1.8× and 2× that floor, which holds more of the road.

Pins and the tilt-shift band are placed from the camera's true projection
(production's pin projection is orthographic only). For each pose, at pad
(1180×820) and phone (844×390):

- **Touch**: the framed stones stay inside main's safe frame, and their touch
  squares (60 px) stay apart (`min gap`, the larger of |dx| and |dy|).
- **Hidden**: a stone on screen whose line of sight to the camera passes
  through the land or through a placed tree, rock or post (each placement as a
  cylinder of 0.6 of its radius and 0.9 of its height). The two stones it
  reports at 40° both sit at the frame's top edge behind conifer spires
  ([`frames/camera/hidden-edge-stones.jpg`](frames/camera/hidden-edge-stones.jpg));
  no framed stone is ever hidden.
- **Ground** and **void**: a second render with the ground flat magenta and the
  background flat cyan, counted inside the safe frame.
- **Cost**: on the iPad 8 (A12, the QA app), today's camera and the variant in
  the same launch, live rest render.

## Results

Pitch and projection at today's 12 m width (pad; phone in brackets):

| Camera | Ground % | Stones on screen | Hidden | Min gap px |
|---|---|---|---|---|
| 55° ortho (today) | 74.7 (63.7) | 7 (9) | 0 (0) | 372 (177) |
| 45° ortho | 71.2 (62.5) | 7 (9) | 0 (0) | 372 (177) |
| 38° ortho | 68.5 (61.7) | 7 (9) | 0 (0) | 372 (177) |
| 32° ortho | 66.1 (59.7) | 7 (9) | 0 (0) | 372 (177) |
| 45° persp 30 | 67.6 (66.0) | 5 (7) | 0 (0) | 372 (177) |
| 38° persp 30 | 66.3 (63.5) | 6 (9) | 1 (1) | 372 (177) |
| 38° persp 45 | 62.3 (62.4) | 8 (12) | 2 (5) | 372 (177) |
| 32° persp 45 | 58.6 (59.6) | 15 (21) | 7 (11) | 372 (177) |

Lowering the camera alone barely changes how much bare ground shows (75 → 66%
at pad), and at today's width it still frames only the two stones close up:
[`frames/camera/pitch-projection-pad.jpg`](frames/camera/pitch-projection-pad.jpg).
A 45° FOV distorts the near edge (the bridge balloons) and hides more stones
behind trees; 30° reads naturally.

Width is what holds the cluster:

| Camera | Ground % | Void % | Stones | Hidden | Min gap px |
|---|---|---|---|---|---|
| 55° ortho ×1 (today) | 76.9 (64.9) | 0 (0) | 7 (9) | 0 (0) | 372 (177) |
| 55° ortho ×1.6 | 64.9 (65.7) | 0 (0) | 9 (11) | 0 (0) | 232 (111) |
| **40° ortho ×1.6** | **62.8 (62.6)** | **0 (0)** | **12 (13)** | **0 (1)** | **232 (111)** |
| 40° persp 30 ×1.4 | 68.5 (66.6) | 0 (0.1) | 11 (16) | 2 (2) | 266 (126) |
| 45° persp 30 ×1.6 | 68.9 (65.4) | 0 (1.4) | 13 (16) | 2 (2) | 232 (111) |
| 40° persp 30 ×1.8 | 67.1 (61.7) | 0 (4.9) | 17 (23) | 3 (4) | 207 (98) |
| 38° persp 30 ×2.0 | 66.3 (58.6) | 0.3 (8.8) | 22 (31) | 3 (4) | 186 (88) |

[`frames/camera/framing-pad.jpg`](frames/camera/framing-pad.jpg),
[`frames/camera/framing-phone.jpg`](frames/camera/framing-phone.jpg). Past
about ×1.6 the phone starts to see past the land's far edge (void), and the
pins crowd. With the kit's planting reserve computed at 40° instead of 55°
(the reserve that keeps tall plants out of a stone's line of sight), the
perspective candidate's hidden count drops to one; orthographic 40° ×1.6 has
none at pad.

## Cost on the A12

The iPad 8, in the QA app (Glassvow QA), lean profile, two steps into the
act, live rest render: today's camera, then the candidate, in the same launch,
two launches each (`proof/r2/qa_r2_probe.gd.txt`, `camPITCHfFOVwWIDTH`).

| Camera | Mean frame (ms), today → candidate | p95 change (ms) | Stage calls | Shadow primitives |
|---|---|---|---|---|
| 40° ortho ×1.6 | 17.09 → 18.14; 16.71 → 17.91 | +6.4, +7.6 | 59 → 84 | 52k → 64k |
| 40° persp 30 ×1.4 | 16.89 → 17.59; 16.76 → 18.38 | +3.5, +8.0 | 59 → 89 | 52k → 88k |
| 38° persp 30 ×1.6 | 16.99 → 17.31; 16.76 → 18.33 | +1.2, +7.8 | 59 → 102 | 52k → 88k |
| 45° persp 30 ×1.6 | 17.51 → 18.05; 16.76 → 18.29 | +2.5, +9.0 | 59 → 92 | 52k → 87k |

Every wider camera costs about a millisecond of mean frame time at today's
dressing (roughly one frame in fifteen lost), because it puts more of the act in
view; between the candidates the difference is within the noise, except that
perspective's longer view throws a third more into the shadow pass.

For reference, in the same QA app and state: R1 rests at p50 16.64–16.68 ms
(cold open 2.45–2.50 s, warmed 310–327 ms); R2 steps 1–3 at p50 16.92–16.98
ms (cold 2.55–2.59 s, warmed 311–314 ms), and against R1 in the same launch
16.89 against 16.94 ms. A fresh run's opening framing, which holds the start
stone and every reachable stone, already loses frames in R1 (p50 18.8–19.8 ms,
141 draw calls): the widest view the act has today.


## The pick

**40° orthographic, the Journey view at least 1.6 times today's 12 m floor
(about 19 m).**

- **It holds the road's cluster**, as the target does: 12 stones on screen at pad
  and 13 at phone, against 7 and 9 today, with the river and the bridge in
  frame ([`frames/camera/vs-target-camera.jpg`](frames/camera/vs-target-camera.jpg)).
- **It shows the least bare ground** of every candidate (62.8% at pad against
  76.9% today), and no void past the land at any shape.
- **Taps stay safe.** The framed stones' touch squares are at least 232 px apart
  at pad and 111 px at phone (60 px required); no framed stone is ever
  hidden; one edge stone at phone sits behind a conifer, which the planting
  reserve at 40° is for.
- **It costs what every wider camera costs** (about +1.1 ms of mean at today's
  dressing), with the lightest shadow pass of the candidates (64k primitives
  against 87–88k for perspective).
- **The production change is small and stays inside today's guarantees.**
  `MapJourneyCameraContract.PITCH` 55 → 40; the Journey floor 12 → about 19 m;
  the kit's and the gateway's planting reserves read the contract's pitch
  instead of a literal 55°; the tilt-shift's narrowest band widens (about half
  the height), so the whole cluster is sharp, not just the two framed stones;
  the lit seated waystones' glass is toned down (it blows out white under the R2
  grade and now shows round the pins). Pins, hit testing, panning, pan bounds
  and the camera contract's tests stay orthographic and valid.

**Perspective (30° FOV, 40°, ×1.4) is the alternative, not the pick.** Its far
edge recedes as the target's does, but at 30° the difference is slight in the
stills; it costs the same frame time with a third more in the shadow pass,
lets the phone see past the land at wider framings, and needs a new pin
projection, hit test, pan and contract fit. Worth revisiting once density is
in, when the depth cue matters more.

**What it means for (b).** At 40° ×1.6 the A12 rests near 17.9 ms before any
density, so (b) opens by making room at the new camera (shadow distance and
casters, LOD or impostors for far cells, the lean stage scale) and gates every
density sub-step on the device as before.

