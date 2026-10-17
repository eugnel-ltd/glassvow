# Round-4 rig and animation handoff (17 October 2026)

Lab: `/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab` on the MacBook Pro.
`mobs/` and `pipeline/` are not tracked by git. Nothing here is committed or promoted into `assets/`.

## Rules carried forward

- Run Blender 5.2.2, Godot 4.7.2 and any browser on the MacBook Pro only. The Mac mini has too little RAM.
- One heavy job at a time. Start only when load is below 30 and at least 100 GiB is free.
- `production_approved` stays false. Do not promote a candidate on a technical pass alone.
- Do not notify glassvow-main until a candidate passes visual review at normal speed from front, rear and side.
- No paid Tripo generation without owner authorisation.
- No owner approval gate: the agent does technical and visual verification itself, then shows James the images and clips.

## Measurement lessons

- Zero severe stretch (edge > 3x rest and > 0.03 m) is necessary. It does not prove natural motion.
- Check the exported GLB, at integer and fractional sub-frames. After densifying keys, also sample between the new keys.
- Measure absolute world floor contact, not height relative to the mesh minimum.
- `ground_candidate.py` re-solves Hips each quarter frame to keep the mesh minimum at 2 mm. That cancels authored pelvis drops, so a collapse must come from articulation.
- Signed tetrahedral volume of an open mesh is diagnostic only.
- A sleeve slice-centre path does not bound local edge distortion.
- An overlap count can fall while the shape gets worse (Shade death5). Look at the frames first.
- A pinned palm point on a prop is not a grip. Measure the finger vertices.
- Preview crossfades are diagnostic. The game has no 3D actor AnimationPlayer, AnimationTree or blend config in `presentation/` or `application/`.

## Candidate state

| Mob | Variant | GLB sha256 | Status |
|---|---|---|---|
| unlitSelf | `mobs/unlitSelf/rig-round4-collapse4-repair1` | 699bec12163e3e3e021b235c3f05db212bf0b2eb7d6dd52f5239cb085bdda0ec | Frozen pilot. Six clips 0 severe. Death body min 0.979 mm, prop 13.929 mm |
| unobsidianSelf | `mobs/unobsidianSelf/rig-round4-collapse-port1` | be916be1743010b307bedbf5f803bfe61142a703104153f8ef52ad9ebf5a4b06 | Provisionally accepted, frozen. Attack/cast sleeve droop reduced (max 239.1 / 350.7 mm change) |
| sovereign | `mobs/sovereign/rig-round4-collapse-final1` | c3c356cdcb1797eb8cedef46acf44c6c4ed065f6a2be5ef1708ae039ad4dbdd5 | REJECTED. Topology blocker. See `pipeline/sovereign-final1-rejection-20261016.json` |
| shade | `mobs/shade/rig-round4-temporal4` | 5797318236f76db65d74876ff3104f08df83d981fb850735338aff2771d6a2fc | Not approved. Death f24–48: left sleeve passes through the cloak |
| shade | `mobs/shade/rig-round4-death5` | 7a974d5938e49d90563d9e50fd6a6751038a1e84cae66f812955b5a9f3d9206b | REJECTED. Sleeves read as wings. See `pipeline/shade-death5-rejection-20261016.json` |
| gravewarden | `mobs/gravewarden/rig-round4-recessed8-release-ground` | – | Death floor gate passes (385 samples, 0 severe, min 1.485 mm). Staggered arm release accepted |
| gravewarden | `mobs/gravewarden/rig-round4-clearance1` | – | REJECTED. Walk/cast arm-leg crossings; forearm band reads broken |
| gravewarden | `mobs/gravewarden/rig-round4-housing1` | c08c1a2babe3b36d8d598c1a42c4fdd98a71fef4fc57cd431edbcbd422e2b947 | Unreviewed. Six clips 0 severe, floor passes. Arm/leg crossings remain (see its `surface-counts.json`) |

## Records in `pipeline/`

- `production-repair-progress-20261016.json`: owner feedback of 16 October, tiers, `open_findings.hover_death_pop`.
- `round4-review-status-20261016-220156.json`: per-candidate verified and open items.
- `sovereign-final1-rejection-20261016.json`, `shade-death5-rejection-20261016.json`.
- `production-round3-working-selection.json`: comparison references only.

## Tools in `pipeline/`

- `hem_uv_fill.py`: hem UV fill, optional `cap_hem` and `bottom_nz`.
- `ground_candidate.py`: per-quarter-frame Hips ground solve.
- `candidate_motions.py`: authored clips; `drift()` sets the hover that causes the death pop.
- `robe-collapse/robe_export_check_30fps.py`: exported-GLB severe-edge and floor check at 30 fps integer and eighth frames.
- `archive_round3_frames.py`: NAS archive with `--dry-run`. Archives go to `ds1819-clawdbot:Archives/glassvow-asset-lab/`.

## Evidence in `pipeline/handoff-20261017/evidence/`

Copied from the Mac mini `/tmp` on 17 October.

- `robe-death/evidence4-repair1/`: unlitSelf pilot.
- `robe-death/evidence-unobsidian-port1/`: unobsidianSelf port.
- `robe-death/evidence-sovereign-final1/`: `death-side-1x-diagnostic.mp4`, `grip2-rest.png`, `grip2-death-f30.png`, `ring-rest.png`, `ring-end.png`.
- `shade-rebuild/final-review/`: temporal4 six-clip front/rear 1x clips and the f29 sleeve crop.
- `glassvow-review/shade-death5/`: death5 front/rear f24–f48.
- `glassvow-rig-trial-review/`: Gravewarden release, clearance1 and close views.
- `glassvow-round4-review-status-20261016.json`: copy of the review status record.
