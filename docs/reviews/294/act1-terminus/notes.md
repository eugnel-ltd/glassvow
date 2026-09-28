# Act I hero terminus — #294 (reviewable slice)

Base: `main@76c2fe4`. Local deterministic mesh. No vendor, no paid credits.
James's 'do 1 now' authorized this Act I slice to proceed. That is not a
separate visual verdict of this GLB.

## Mesh

`assets/art/map/geometry/act1/terminus-amber-window-tower.glb`

Traces `assets/art/stage/act1-backdrop.png`: grounded stone shaft,
crenellated crown, pointed gothic window through +Z (production camera
looks −Z), lower-right turret. Voxel occupancy + greedy meshing, one
connected island, Y-up metres, ground Y=0, one triangulated surface,
POSITION+NORMAL, no textures/UVs/animation.

| Metric | Value |
|---|---|
| triangles | 342 (cap 8000) |
| bytes | 11228 (cap 768 KiB) |
| surfaces | 1 (cap 2) |
| Y min / max | 0.0 / 4.5 |
| sha256 | `f560741cc86023ef9d5edebd62accf15143e9821932e26011da75f30ba4317f8` |

`inspect_glb` passes. Headless GPU raster hits the dummy renderer (empty
mask). Headed raster hung on `user://logs/godot.log` in this environment.
No accepted `provenance.json` record.

Landing this GLB completes Act I's eight-kit + terminus set, so
`MapScene` replaces placeholder wedges/slabs/dabs with real kit geometry.
`tests/test_map_scene.gd` `_scene` follows that.
