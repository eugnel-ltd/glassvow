# Lane brief: mythic art in layers (round 3, grounded subjects)

Date: 16 Oct 2026. Orchestrator: the Glassvow orchestrator session.

This brief extends `/Users/jamesto/Coding/glassvow/.claude/worktrees/orch/mythic-art-layers-2-brief.md`. Read that brief and the lane rules it links. Everything in it still binds, except where this brief changes it.

## Connection

The seat's SMB mount is down. Run every engine command with `ssh -o BatchMode=yes mbp '<pipeline>'`. To read or view an engine file on the seat, copy it with `scp mbp:<path> /tmp/mythic-l3/` first. To write a file, write it in `/tmp/mythic-l3/` and copy it to the lane folder with `scp`. If `/Users/jamesto/Coding/glassvow/.claude/skills/glassvow-orchestrator/references/mbp.sh` exists again on the seat, you may use it instead.

## Lane folder

`/Users/jamesto/Coding/glassvow/.claude/worktrees/mythic-art-layers-3/` on the engine. Create it. Write only inside it (and `/tmp/mythic-l3/` on the seat). The folders `mythic-art-layers/` and `mythic-art-layers-2/` are read-only: read and copy from them, never write, move or delete there.

## Owner decision (16 Oct 2026, verbatim)

On the round-2 bankedFire A (ember stone in a hearth cradle) and B (iron lantern): "both not ok. the stone should be on the ground. means the background need front/mid/back layers too. the fire/stone should stay on ground."

## What went wrong in round 2

- The backdrop was one layer (L0) that moved −16 px. The subject (L2) moved +123 px. So the stone and the lantern slid over the floor and read as floating.
- B was built as an "unsupported floating lantern". The round-2 attachment rule allowed "let the subject float". That option is withdrawn.
- Separately, the automatic semi-transparent colour gate failed on 72 pixels (alpha ≤ 6/255) after the RGBA resample in `build.py`.

## The ground rule (binding, all six cards)

1. A subject that stands or rests in the world sits on the ground. Its contact (cradle base, lantern feet, a figure's feet, a door's threshold) stays locked to the ground under it at every lean. No grounded subject floats.
2. Split the world into depth layers:

   | Layer | Content |
   |---|---|
   | Back | Sky, far walls, distant arcades. Smallest shift. |
   | Mid (ground) | The floor or ground plane the subject stands on, and the scenery at the subject's depth. |
   | Subject | The focal subject. At its contact line it moves exactly with the ground under it. |
   | Front | Near floor lip, rubble, ash drifts, pillars at the frame edge. Largest shift. May overlap the subject's base. |
   | Particles, emissive, card-specific | As in round 2. |

   Number the files in back-to-front order and record the order in `layers.json`.
3. Choose how the ground moves, and say which you chose:
   - **Shear ground.** The ground layer shifts by row: the far edge moves like Back, the near edge moves like Front. The subject moves with the ground's shift at its contact row.
   - **Flat ground.** The ground layer has one depth, equal to the subject's. The parallax step between Back, Mid and Front sells the depth.
4. Give each grounded subject a contact shadow or occlusion on the ground (dark pool, soot, ash ring). Put it on the ground layer or the subject layer so it moves with the contact.
5. Keep the total shift within the round-2 cap (about 123 px at lean ±1).

## Acceptance additions

To the round-2 acceptance list, add:

7. **Contact lock.** At lean −1, 0 and +1, the relative slide between the subject's contact pixels and the ground directly under them is 1 px or less. Measure it and report the number per candidate.
8. **Reads as grounded.** Look at the lean −1, 0 and +1 frames and the GIF yourself. The subject must read as standing on the floor, not hovering. Numbers alone do not pass this.
9. **Semi-transparent colour gate passes.** Fix the cause, not the threshold: premultiply alpha before any resample (or cut and despill after the resample), then un-premultiply. Report the count, which must be 0.

## Pilot gate

Do bankedFire A and B again first, end to end.

- Reuse the round-2 sources in `mythic-art-layers-2/sources/` where they still fit (copy them; do not regenerate what exists). The back, mid and front split of each backdrop probably needs new generation: generate them as separate complete plates, or as one ground plate plus key-colour front pieces. Your choice.
- B is a lantern standing on the floor on its feet, with a contact shadow. A is the ember stone resting in its hearth cradle on the floor.
- Image-gen budget for this round: 61 calls (68 − 7 used), counted in this lane's own `generation-count.jsonl`, about 5 per candidate as a soft cap. One call at a time; wait while the 1-minute load is above 50; stop if free disk is below 100 GiB.

Check the pilot against the full acceptance list yourself. If it fails, stop and report with evidence. If it holds, continue with silvering, unbrokenFlame, unbowed, knownRoad and cleanBreak without asking, applying the ground rule to each (for unbowed: the figure's feet stay planted on level ground while the world layers tilt around it).

## Deliverables and report

As in the round-2 brief, plus the contact-lock numbers per candidate. Also copy each `sheet-<cardId>.jpg` and each candidate GIF to `/tmp/mythic-l3/` on the seat so the orchestrator can show them. Report as the lane rules say, ending with a short Hong Kong Cantonese paragraph. Then stop.
