# Lane brief: mythic art in layers (round 4, one look per card)

Date: 16 Oct 2026. Orchestrator: the Glassvow orchestrator session.

Read the lane rules first: `/Users/jamesto/Coding/glassvow/.claude/skills/glassvow-orchestrator/references/lane-rules.md`. Then read `/Users/jamesto/Coding/glassvow/.claude/worktrees/orch/mythic-art-layers-3-brief.md` and the round-2 brief it extends. Their method, guards and acceptance still bind, except where this brief changes them.

## Owner decision (16 Oct 2026, verbatim)

On the round-3 review page: "i don't like it. for each of them they should be unique view, unique style. now they just look like the same. i framed you to use layers, not framed you do do unique style and unique presentation."

Layers are the technique. They are not a template. Every card needs its own camera, its own world and its own look.

## Why round 3 looks the same

Measured from the round-3 inventory and sheets:

- Several candidates share one backdrop file (silvering A and B and unbrokenFlame A have the same L0 hash). Most of the rest use one of two backdrops: a blue cathedral interior or a blue ruined arcade.
- Every candidate reuses the same rubble front layer and the same flat slab floor with an oval shadow.
- Every subject sits in the centre, at eye level, frontal, at the same scale.
- Every plate uses the same cobalt palette and the same light.
- Every candidate uses the same depth recipe (back −16, ground +72, front +123 px).
- The round-2 brief told every card "one huge subject, centred", and that overrode the scene each card has in design §6.

## What changes

1. **Design §6 is the scene.** Read `/Users/jamesto/Coding/glassvow/docs/design/2026-10-15-mythic-set/README.md` §6 (line 717 on) for each card and follow its camera, composition, palette and 64 px read. Keep the big strange focal subject from round 2, inside the §6 scene. Where §6 and earlier briefs disagree, §6 wins. Examples: Banked Fire is low and close at the foot of a stone, with ash on a hard diagonal and the coal left of centre. The Known Road is one-point perspective to a small door on the horizon. Clean Break shows the blade's edge just leaving the cut.
2. **One look per card.** For each card, write a one-paragraph look sheet in `LOOKS.md` before you generate anything:
   - camera: height, angle, lens (macro, wide, telephoto, worm's-eye, overhead, one-point, Dutch angle), and where the subject sits in the frame;
   - world: what the place is, and what the back, ground and front layers hold;
   - light: the key light, its colour and direction;
   - palette: the §6 palette and its one accent;
   - layer recipe: the depth of each layer and how the hologram acts on it.
   No two cards may share a camera type, a world, a dominant palette or a layer recipe.
3. **Shared thread only.** Keep what the game's art ledger fixes for all card art: stained glass with heavy lead lines, deep saturated colour, no text, faceless figures. Everything else may differ. Inside that medium, vary the glass itself per card when it helps the look (for example coarse dark slab glass, thin silver came, clear frosted glass, warm cathedral glass).
4. **No shared files.** Generate a new backdrop, ground and front for every candidate. Do not reuse any round-1, 2 or 3 backdrop, ground, front or rubble layer. A and B of one card are two different compositions inside that card's look.
5. **The ground rule stays.** A grounded subject stays locked to its support (contact slide 1 px or less at lean −1, 0, +1) with a contact shadow, as in round 3. Use the layer split that suits the camera: a macro shot may have a shallow ground and a large blurred front; an overhead shot may have almost no parallax step and lean on the hologram instead.

## Acceptance additions

To the round-3 list, add:

10. **Distinct set.** Make `set-overview.jpg`: all flats side by side, full size and at 64 px. Look at it yourself. Each card must be recognisable from the others by its silhouette and palette alone at 64 px. Record in `LOOKS.md` why each pair of cards differs.
11. **No shared sources.** Check that no two candidates share a backdrop, ground or front file (compare hashes). Report the result.
12. **§6 check.** For each candidate, list each §6 element and say present or absent. An absent element is a miss to report, not something to hide.

## Order and gate

1. Write `LOOKS.md` for all six cards.
2. Make candidate A for all six cards. Build `set-overview.jpg` from the six A flats, with their motion previews.
3. Stop and report. Copy `set-overview.jpg`, `LOOKS.md`, the six A sheets and the six A GIFs to `/tmp/mythic-l4/` on the seat. The orchestrator shows the owner the set before the B candidates.

## Lane folder and connection

- Lane folder: `/Users/jamesto/Coding/glassvow/.claude/worktrees/mythic-art-layers-4/` on the engine. Create it. Write only there and in `/tmp/mythic-l4/` on the seat.
- Copy and adapt the round-3 scripts from `mythic-art-layers-3/` (build, preview, validate, resource guard). The earlier lane folders are read-only.
- The seat's SMB mount may be down. Run engine commands with `ssh -o BatchMode=yes mbp '<pipeline>'` and move files with `scp`.

## Budget and guards

- At most 30 image-gen calls for this stage (about 5 per card), logged in this lane's own `generation-count.jsonl`. One call at a time.
- Before every call and every render: wait while the 1-minute load is above 50; stop and report if free disk is below 100 GiB. At 17:00 free disk was 101.5 GiB and load 34. Keep files lean: stream frames to ffmpeg, render one candidate at a time, validate a temporary video before it replaces the final one.
- No git, no Godot, nothing into `assets/`. Delete only inside the lane folder, by literal absolute path, checking and deleting as separate commands. Never run a broad `find` over `/Users/jamesto`. Never print a token, key or account id.
- Label every preview "offline approximation, not the shader".

## Report

Report as the lane rules say: the six looks in one line each, the set overview, the acceptance results, the §6 misses and the generation count. End with a short Hong Kong Cantonese paragraph. Then stop.

## Change (16 Oct 2026, owner)

The 100 GiB free-disk floor is a soft gate. Do not stop below it; storage cleaning happens later. Stop and report only if free disk falls below 50 GiB.
