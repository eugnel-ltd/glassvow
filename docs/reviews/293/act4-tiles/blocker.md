# #293 Act IV tiles — human blocker

These two tiles are **not landed**. Issue #293 says a landed row is visually
accepted. No fol2 named-device verdict exists. Codex review forbade encoding
`pending` as a passing shipping state, and forbade weakening
`tools/check_map_assets.py` (present payload still requires
`verdict == accepted`; `record_schema.verdicts` stays `accepted` / `rejected`).

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
| `assets/art/map/materials/act4-ground-pale-road.png` | `act4-ground-pale-road.png` + `act4-ground-pale-road-wrap.png` | `78c78d6168c79c14346f10270a9a40f55a8536020d3c8ddd3de7c7c434324240` |
| `assets/art/map/materials/act4-prop-inverted-hearth-stone.png` | `act4-prop-inverted-hearth-stone.png` + `act4-prop-inverted-hearth-stone-wrap.png` | `1908fb063ca92ba6e53cddf33efa4f943624c24eb22654560c29aec45a7471e8` |

Machine mean / seam / opaque-RGB were measured on these PNG bytes with
`tools/map_asset_checks.py` (`stored_mean`, `delight_spread`, `seam_ratio`,
`pixels_of`). That is not visual acceptance, and it is not a substitute for a
Godot-generated sidecar.

| Tile | mode | mean | 8×8 spread | seam |
|---|---|---:|---:|---:|
| pale-road ground | RGB 1024×1024, R=G=B | 0.500000 | 0.076390 | 0.523876 |
| inverted-hearth-stone prop | RGB 1024×1024, R=G=B | 0.500000 | 0.137995 | 0.368118 |

Wrap captures tile the original 1024px image 2×2, then resize to 512×512
with Lanczos. Method: `tileable-value-noise-fbm`, seeds `293301` / `293302`.
The Act IV under-key gap is 0.282132 → 0.282, derived from live
`GROUND_VALUE`/`PROP_VALUE`/`BAND_KEY`, and is unchanged after binding
because `tex_mean`/candidate mean is 0.5.

## Expected human blocker (fol2)

Cannot land, merge, or write canonical provenance until **all** of:

1. **Pale-road wrap** — named-device visual yes/no.
2. **Inverted-hearth-stone wrap** — named-device visual yes/no.
3. **iPad 8 smoke** — yes/no (Act IV would bind two live VRAM tiles).

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
