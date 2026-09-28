# #293 shared standing monument — human blocker

Unmerged review candidate, not landed. Canonical provenance has no monument
row; `record_schema.verdicts` is `accepted` / `rejected` only. `pending` is
not a shipping state. Default `land_map_glb.py` must not write provenance.

Present `geometry/shared/standing-monument.glb` must fail
`check_map_assets`: `present asset lacks an accepted provenance record`.

Do not regenerate: GLB `fb0ee05c97a176559d7b6bc0263a9d4fcd46224c4e1510f9f250373609b6fe8a`
(40012 bytes, 1602 triangles); 20-placement
`f40dd372c7ac594727210388a415122b2c7cbd251b76cefcaca1f1dd9d5fe0aa`; concept
`b4b0ddfaa07e2b6f5083e9185413931123154ee5bd6ec7cb59f2c68aef80d2b3`.

**Blocker:** fol2 yes/no on `docs/reviews/293/shared-standing-monument-20.png`.
Yes: a later `--accept-signed-capture` + `--reviewer` writes `accepted`.
No: keep unmerged. Do not merge before that yes.
