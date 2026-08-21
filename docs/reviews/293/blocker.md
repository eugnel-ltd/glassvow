# #293 shared standing monument — human blocker

This is an unmerged review candidate. It is **not landed**.

Issue #293 lands a row only when it is visually accepted. Canonical
`assets/art/map/provenance.json` therefore has no `shared-standing-monument`
record, and `record_schema.verdicts` remains `accepted` / `rejected` only.
`pending` is not a shipping state.

## Expected gate

A present GLB on the manifest path without an `accepted` provenance record
must fail `python3 tools/check_map_assets.py`:

`present asset lacks an accepted provenance record`

Do not merge until that finding is gone for the right reason: fol2 has
signed the 20-placement, and a canonical `accepted` row has been written.

## Preserved candidate bytes

Do not regenerate these.

| File | SHA-256 | Notes |
|---|---|---|
| `assets/art/map/geometry/shared/standing-monument.glb` | `fb0ee05c97a176559d7b6bc0263a9d4fcd46224c4e1510f9f250373609b6fe8a` | 40012 bytes, 1602 triangles, fused Studio Export |
| `docs/reviews/293/shared-standing-monument-20.png` | `f40dd372c7ac594727210388a415122b2c7cbd251b76cefcaca1f1dd9d5fe0aa` | exact 20-placement capture |
| `assets/art/map-concepts/shared-standing-monument.jpg` | `b4b0ddfaa07e2b6f5083e9185413931123154ee5bd6ec7cb59f2c68aef80d2b3` | fused/isolated concept |

## Human yes/no

**Blocker:** fol2 visual accept/reject of
`docs/reviews/293/shared-standing-monument-20.png`.

- **Yes** — then, as a separate step after this exact PNG is signed, run
  `tools/land_map_glb.py --accept-signed-capture` with `--reviewer` set by
  the human. Default landing must not write that row.
- **No** — keep the candidate unmerged; do not encode a shipping verdict.
