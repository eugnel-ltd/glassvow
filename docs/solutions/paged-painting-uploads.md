# Bounded scene and stage uploads

Twenty-one scene and stage paintings keep their original full-resolution PNG
and import sidecar in the source checkout. During export,
`addons/glassvow_painting_export/plugin.gd` replaces each selected logical PNG
with a generated binary resource. That resource embeds two ImageTexture pages;
each physical leaf is at most 4 MiB even if RGB expands to RGBA8. No generated
art pages are committed or added to LFS.

`tools/painting_upload_inputs.json` pins the source, import settings and exact
decoded imported RGBA bytes. The builder crops the already imported image,
including one neighbour row at the split. It never repeats alpha-border
preprocessing on a cropped region, resizes, grades or changes the source art.
The original content paths, dimensions, crop, opacity, filter and motion stay
owned by their existing consumers. Native boot and the separate title painting
are outside this conversion.

The export callback keeps each original selected and calls `add_file` with
`remap=true` inside that original's `_export_file` callback. Godot omits the
ordinary original import and writes its `.png.remap`. `ResourceLoader.exists`
and loading the original PNG path therefore retain the logical resource path.
Do not exclude these originals in a preset: exclusion happens before the
callback. The generated wrapper depends only on the normal exported runtime
script, which remains under `presentation/stage/`.

Use the checked pack command with the checkout's complete isolated application
override and isolated `XDG_DATA_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME` and
`XDG_CONFIG_HOME`:

```sh
python3 tools/export_paintings.py --preset macOS --output /path/to/new-game.pck
python3 tools/export_paintings.py --audit-existing /path/to/existing-game.pck
```

The command requires supported stable Godot, validates original source/import
hashes, grades the plugin receipt, and starts a cold audit from an empty resource
root with the actual pack. The external frozen regression and source manifest
are its oracle. It checks all 21 logical loads, all 42 actual leaves, exact
imported pixels and gutters, dependency closure, the complete generated
namespace, and absence of original imports. Failed generated resources cannot
fall back to the original texture; the checked command returns nonzero and
does not publish its temporary output. Direct editor export logging alone
cannot promise a nonzero CLI status; an unaudited export is not accepted
shipping evidence. Native signing/device validation remains its own release
contract.

CI runs the same actual-pack contract, including malformed packs with a real
oversized ImageTexture, missing embedded page/remap, broken gutter, unexpected
leaf, stranded original import, forged empty manifest and legacy single-image
uploads. The old `.import` walker still checks ordinary imported textures; it
cannot see generated ImageTexture subresources and is not their cap proof.

The runtime wrapper tessellates the original source crop at its half-texel
clamp boundaries, then draws page-owned polygons. This keeps the original
outer crop clamp while allowing the internal join to sample its neighbour
row. A per-half `clip_uv=true` would incorrectly clamp the join. Rectangles
and primitives use different modulation precision in the inspected renderer;
the polygon route preserves the observed nearest output exactly and linear
output within one 8-bit level. Polygon draws do not batch; this is a bounded
upload change, not a total VRAM or frame-time improvement claim.

Known consumers draw these paintings through ordinary CanvasItem sampling.
Their grade, vignette and lighting overlays are separate nodes. A future
consumer that reads a whole-texture RID, samples a custom shader's whole-image
UVs, tiles, or requires vertex snapping needs its own representation contract.
The composite is not a single GPU texture. It reports actual decoded source
alpha; native CompressedTexture2D currently reports `has_alpha=false` even for
RGBA images. Known consumers do not branch on that metadata; pixel alpha and
blending are preserved rather than changing pixels to match the native stub.

The gutters slightly increase total resident image bytes. Upload caps do not
prove lower peak RSS, total VRAM or smaller retained staging pools. The native
splash and other independently inventoried staging formats remain separate
work; this conversion does not close the entire performance issue.
