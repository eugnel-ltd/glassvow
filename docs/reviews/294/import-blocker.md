# Act III grade import blocker — HQ VRAM + mipmaps

Ticket: #294. Asset: `assets/art/map/grades/act3-grade.png`.

Godot 4.7.2.stable (`ed1daf0bf`) was used to import the grade. The generated
sidecar is the importer default:

```
compress/mode=0
compress/high_quality=false
mipmaps/generate=false
detect_3d/compress_to=1
```

`docs/map-scene-asset-bill.md` requires mode 2 (VRAM Compressed),
`high_quality=true`, and `mipmaps/generate=true` for map grades. Those three
keys are not exposed as `godot --import` flags. Project-wide
`importer_defaults` would retarget every new texture. An EditorScript that
sets import-dock values and reimports did not run here: headed `--editor`
startup could not save `editor_settings-4.7.tres` and hung before `_run()`.

The sidecar was **not** hand-edited. `tools/check_map_assets.py` will fail
this row on `compression` / `high-quality` / `mipmaps` until someone sets
those options in the Godot 4.7.2 import dock and reimports.

The PNG itself meets the grade content contract (512×256 RGBA, contact mask,
palette arc, low-frequency residual).

## GPU raster / live captures

Headed Godot 4.7.2 hangs after `Accessibility: AccessKit driver loaded` before
`raster_map_silhouette.gd` writes a mask (windowed `--position 0,0` and
`-4000,-4000`). `--headless` runs the harness and fails at yaw 0:
`texture_2d_get` dummy storage, empty mask — the documented dummy-renderer
trap. So the eight production-camera yaw masks, one-placement clay capture,
and Act III all-shape `shot.sh` frame were not produced in this session.

`inspect_glb` still passes on the source mesh (one surface, POSITION+NORMAL,
1920 tris, one island, Y min 0, 35872 bytes). Linux CI uses `xvfb-run` for
`check_map_assets.py` and should be able to raster there.

Live `MapScene` will not attach `AssetTerminus` until all eight Act III kit
GLBs resolve (`map_scene.gd` `_bind_asset_geometry`); the painted grade
binds on its own when the PNG is present.
