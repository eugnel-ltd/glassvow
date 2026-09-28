# #293 Act I tiles — human blocker

These two tiles are **not landed**. Issue #293 says a landed row is visually
accepted. No fol2 named-device verdict exists. Codex review forbade encoding
`pending` as a passing shipping state, and forbade weakening
`tools/check_map_assets.py` (present payload still requires
`verdict == accepted`; `record_schema.verdicts` stays `accepted` / `rejected`).

The candidate PNGs, Godot `.import` sidecars, and wrap captures are review
evidence in this directory only. They are not under `assets/art/map/`, so the
map gate treats them as declared-but-absent and keeps the placeholder bind.
Putting them on the land path without an accepted provenance record makes the
full map gate fail honestly.

## Evidence

| Intended land path | Evidence | sha256 |
|---|---|---|
| `assets/art/map/materials/act1-ground-ash-loam.png` | `act1-ground-ash-loam.png` + `.import` + `act1-ground-ash-loam-wrap.png` | `1936fcb0df1e41241ba691fc921708ffd6e07a2b28584bc22693ce5a69c0460c` |
| `assets/art/map/materials/act1-prop-charred-bark.png` | `act1-prop-charred-bark.png` + `.import` + `act1-prop-charred-bark-wrap.png` | `0c5dda3dbf7a829f6697279535ab5c8b3bf1b13f25277d1c3238a484173f4a69` |

Machine mean / seam / opaque-RGB / import settings were measured on these
bytes. That is not visual acceptance.

## Expected human blocker (fol2)

Cannot land, merge, or write canonical provenance until **all** of:

1. **Ash-loam wrap** — named-device visual yes/no.
2. **Charred-bark wrap** — named-device visual yes/no.
3. **iPad 8 smoke** — yes/no (Act I would bind two live VRAM tiles).

On **yes** to 1 and 2: copy the two PNGs and `.import` files onto the intended
land paths, add `provenance.json` records with `reviewer: "fol2"` and
`verdict: "accepted"`, then re-run `python3 tools/check_map_assets.py`. Do not
invent a third verdict.

On **no**: leave them out of `assets/art/map/` and out of `provenance.json`.
This is not Codex acceptance.
