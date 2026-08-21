# #293 Act II tiles — human blocker

These two tiles are **not landed**. Issue #293 says a landed row is visually
accepted. No fol2 named-device verdict exists. Present payload still requires
`verdict == accepted`; `record_schema.verdicts` stays `accepted` / `rejected`.
`pending` is not a shipping state.

The candidate PNGs and wrap captures are review evidence in this directory
only. Do not store Godot `.import` sidecars here: they name a
`res://assets/art/map/materials/` source, so a copy under `docs/reviews/` is
internally invalid and Godot rewrites it. They are not under
`assets/art/map/`, so the map gate treats the tiles as declared-but-absent and
keeps the placeholder bind. Copying a PNG onto the land path without an
`accepted` fol2 record makes the full map gate fail honestly.

## Evidence

| Intended land path | Evidence | sha256 |
|---|---|---|
| `assets/art/map/materials/act2-ground-silted-stone.png` | `act2-ground-silted-stone.png` + `act2-ground-silted-stone-wrap.png` | `2da6c1378181b40fff56c1b2215c51c81794151e0e853ea17476480cf139087a` |
| `assets/art/map/materials/act2-prop-drowned-masonry.png` | `act2-prop-drowned-masonry.png` + `act2-prop-drowned-masonry-wrap.png` | `4dd642b3bb1e21bb9a4c0f4d771fe93b2f83edcf8c5fb44a65d719c5e70b2bda` |

Machine measurements on the candidate PNG bytes (opaque RGB, scalar duplicated
into RGB, method `tileable-value-noise-fbm`):

| File | seed | mean | 8×8 spread | seam | unique levels |
|---|---:|---:|---:|---:|---:|
| silted-stone ground | 293101 | 0.499999 | 0.048666 | 0.451674 | 167 |
| drowned-masonry prop | 293102 | 0.499999 | 0.041051 | 0.101079 | 171 |

Value lock unchanged: linear `GROUND_VALUE − PROP_VALUE` = 0.320 ≥ 0.272.
The Act II under-key gap is derived from live `GROUND_VALUE` /
`PROP_VALUE` / `BAND_KEY[1]`: 0.279816 → 0.280 > 0. That gap remains
unchanged after binding because `tex_mean` / candidate mean is 0.5, not
because tiles are absent. That is not visual acceptance, and it is not a
substitute for a Godot-generated sidecar.

Wrap captures are 2×2 of a 256 px bilinear downsample (512×512), for seam and
repetition review.

## Expected human blocker (fol2)

Cannot land, merge, or write canonical provenance until **all** of:

1. **Silted-stone wrap** — named-device visual yes/no.
2. **Drowned-masonry wrap** — named-device visual yes/no.
3. **iPad 8 smoke** — yes/no (Act II would bind two live VRAM tiles).

On **yes** to 1 and 2, in this order:

1. Copy **only the two PNGs** onto the intended land paths under
   `assets/art/map/materials/`. Do not copy `.import` files.
2. Run Godot import there (`tools/check_imports.sh`, or
   `godot --headless --import`) so fresh sidecars are generated at the land
   path. The checker still requires `compress/mode=2`,
   `compress/high_quality=true`, and `mipmaps/generate=true`.
3. Add `provenance.json` records with `reviewer: "fol2"` and
   `verdict: "accepted"`. Do not invent a third verdict.
4. Re-run `python3 tools/check_map_assets.py` and the rest of the landing
   gates.

On **no**: leave them out of `assets/art/map/` and out of `provenance.json`.
This is not Codex acceptance.
