# #293 Act III tiles — human blocker

These two tiles are **not landed**. Issue #293 says a landed row is visually
accepted. No fol2 named-device verdict exists. Present payload still requires
`verdict == accepted`; `record_schema.verdicts` stays `accepted` / `rejected`.
`pending` is not a shipping state.

The candidate PNGs and wrap captures are review evidence in this directory
only. Each wrap is a 2×2 of a 256 px BOX downsample. Do not store Godot
`.import` sidecars here: they name a `res://assets/art/map/materials/` source,
so a copy under `docs/reviews/` is internally invalid and Godot rewrites it.
They are not under `assets/art/map/`, so the map gate treats the tiles as
declared-but-absent and keeps the placeholder bind. Copying a PNG onto the
land path without an `accepted` fol2 record makes the full map gate fail
honestly.

## Evidence

| Intended land path | Evidence | sha256 |
|---|---|---|
| `assets/art/map/materials/act3-ground-obsidian-dust.png` | `act3-ground-obsidian-dust.png` + `act3-ground-obsidian-dust-wrap.png` | `0ea765c1f5b4e4599b6c9e8baadf387a1dacfc3d02e77c365a3bc97de06e4144` |
| `assets/art/map/materials/act3-prop-obsidian-facet.png` | `act3-prop-obsidian-facet.png` + `act3-prop-obsidian-facet-wrap.png` | `0d4b6d74a58c11d06c65225943b8a8674f66c56fcb796bd4ce1d05221a525d17` |

Machine mean / seam / opaque-RGB were measured on these PNG bytes.
Methods and seeds match the ledger:

| Tile | method | seed | mean | 8×8 spread | seam |
|---|---|---:|---:|---:|---:|
| obsidian-dust | `tileable-value-noise-fbm` | 293201 | 0.500000 | 0.132904 | 0.493706 |
| obsidian-facet | `tileable-worley-f2f1+fbm-grit` | 293202 | 0.500000 | 0.089249 | 1.163891 |

Linear `GROUND_VALUE − PROP_VALUE` remains `0.320` ≥ `0.272`. Act III
under-key gap is `0.260960` → `0.261` from live `GROUND_VALUE` /
`PROP_VALUE` / `BAND_KEY`, and remains after binding because `tex_mean`
/ candidate mean is `0.5`. It is not because candidates are absent.
That is not visual acceptance, and it is not a substitute for a
Godot-generated sidecar.

## Expected human blocker (fol2)

Cannot land, merge, or write canonical provenance until **all** of:

1. **Obsidian-dust wrap** — named-device visual yes/no.
2. **Obsidian-facet wrap** — named-device visual yes/no.
3. **iPad 8 smoke** — yes/no (Act III would bind two live VRAM tiles).

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
