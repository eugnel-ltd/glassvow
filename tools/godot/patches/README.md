# The patched editor for the iOS shader bake (#682)

The iOS build bakes the game's shaders at export, so that a fresh install on the
iPad 8 (A12, Apple GPU family 5, argument buffers tier 1) compiles none of them
on the device. The stock editor cannot make a bake this device will load, so the
baked export runs a 4.7.3-rc editor built from the iOS template's own engine
commit with `glassvow-682-ios-shader-bake.patch`.

## Why a patched editor

- **The engine must match the template.** The iOS template
  (`~/Library/Application Support/Godot/export_templates/4.7.2.stable/ios.zip`,
  see `GLASSVOW-TEMPLATE-NOTE.txt` inside it) is built from godot
  `83dec14d549108e1f314f57c1ce7e932c65370dd` (4.7.3-rc, with the A12 sampler fix).
  A baked shader's cache key holds the engine version and hash
  (`servers/rendering/renderer_rd/shader_rd.cpp`, `base_sha256`), so a bake made
  by any other editor never loads.
- **What the patch changes** (three files, editor-only; the runtime template is
  untouched):
  1. `drivers/metal/rendering_shader_container_metal.cpp`: the Metal toolchain
     query's quoting (upstream godot PR #122692), without which no metallib is
     embedded; and no `-O3`, because the runtime's compile sets no optimisation
     level.
  2. `editor/shader/shader_baker/shader_baker_export_plugin_platform_metal.cpp`:
     iOS is baked for Apple GPU family 5 (the stock baker targets family 7, which
     the A12 rejects and recompiles) at iPadOS 26, the iPad 8's iOS, whose Metal
     language version (4.0) is the one the runtime compiles at. A bake made at the
     app's minimum iOS drew the map's grain differently on the A12.
  3. `editor/export/shader_baker_export_plugin.cpp`: **the guard.** The scene
     shaders' keys and code depend on settings the renderer resolved with the
     editor process's features. A target that resolves
     `rendering/reflections/sky_reflections/texture_array_reflections` or
     `rendering/shading/overrides/force_lambert_over_burley` otherwise (iOS
     resolves their `.mobile` overrides) would ship a bake it never loads, so the
     baker refuses it with `Shader baker: "<setting>" differs for this export
     target ...` and bakes nothing. The export therefore runs with
     `GODOT_EDITOR_CUSTOM_FEATURES=mobile` (a stock engine variable, read when
     the project settings load), and `tools/godot/bake_export.sh` fails on the
     guard's message.

     The same file stops the baker short of **the engine's own shaders** (its
     renderers', effects' and embedded materials', such as the canvas, sky,
     tonemap, copy and blit shaders), and bakes only ShaderMaterials: a
     material whose shader the engine generates (a BaseMaterial3D in an imported
     scene, the Sprite3D and Label3D defaults) is not baked either. Only the
     game's own shaders, found through the manifest, are baked. On the iPad 8 the QA app's user shader cache,
     which the engine reads before the bake, always held their runtime compile,
     so their baked picture could never be tested there (#682 Part 1); a fresh
     install compiles them as an unbaked build does, at the cost main pays today.
     To bring them back, set `bake_engine_shaders` to true and drop the ShaderMaterial
     check in the patch, rebuild,
     and first prove their picture identity on a fresh app container (a new QA
     bundle id, or a device that never ran the QA app). `bake_export.sh` refuses a
     bake that stores any group but the game's (`SceneForwardMobileShaderRD`,
     `CanvasShaderRD`), so an editor built from an older patch cannot slip them in.

## Build it (macOS, about 10 minutes)

```bash
git clone https://github.com/godotengine/godot.git godot-682
cd godot-682
git checkout 83dec14d549108e1f314f57c1ce7e932c65370dd
git apply /path/to/glassvow/tools/godot/patches/glassvow-682-ios-shader-bake.patch
nice -n 10 python3 -m SCons platform=macos target=editor arch=arm64 vulkan=no metal=yes -j4
touch bin/_sc_   # optional: self-contained, keeps the editor's data beside it
```

`bin/godot.macos.editor.arm64 --version` must print
`4.7.3.rc.custom_build.83dec14d5`; `tools/godot/bake_export.sh` refuses any other.
Xcode (not a beta) must be installed: the baker calls its `metal` tool, through
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## Use it

Point `GLASSVOW_BAKE_EDITOR` at the binary. Both export scripts call
`tools/godot/bake_export.sh` whenever the `iOS` preset has
`shader_baker/enabled=true`:

```bash
GLASSVOW_BAKE_EDITOR=$HOME/godot-682/bin/godot.macos.editor.arm64 \
  scripts/ios_release.sh <build-number> <head-sha> [--no-upload] [--no-device]
```

`bake_export.sh` removes the worktree's own stale bake caches
(`.godot/exported/*/` holding a `shader_baker/`; it prints each path first),
writes the bake manifest (`tools/shader_bake_manifest.gd`), exports windowed
(the baker needs a rendering device, so never `--headless`) with the `mobile`
features, and checks that the export stored baked scene shaders and that the
guard did not refuse.

Without the stale-bake clean-up the baker re-adds every bake still listed in its
cache, so earlier shader versions pile up in the pack.

## The template path in the preset

The `iOS` preset names the template by an absolute path,
`custom_template/release="/Users/jamesto/Library/Application Support/Godot/export_templates/4.7.2.stable/ios.zip"`:
the 4.7.3-rc template (the A12 sampler fix) kept in the 4.7.2 directory, which
the stock editor used by its version. The patched editor is version 4.7.3-rc
and looks only for a `4.7.3.rc` template directory, so the preset reads the
zip in place. On another Mac, or another account, change that one line to the
same zip's path there; the stock editor exports the same template either way.

## Checks

- `tools/godot/test_bake_export.sh`: a local self-test of `bake_export.sh`
  against a fake editor (the refusals, the `mobile` features, the stale-cache
  clean-up, project.godot put back). It is not run by CI; run it after changing
  `bake_export.sh`.
- `scripts/ios_release.sh` never falls back to an unbaked build. It asks
  `bake_export.sh --enabled iOS`, which answers 0 (bakes), 1 (does not) or 2
  (any error), and stops on anything else than 0 or 1; while the preset bakes, a
  missing `GLASSVOW_BAKE_EDITOR` stops it before the export, and any failure of
  `bake_export.sh` (an unpinned editor, the guard's refusal, no baked shader
  stored, an engine group stored) stops the release. Its export step runs the
  editor under a fresh scratch HOME in `build/ios/export-home`; the archive and
  the signing keep the real HOME.

## When to rebake or rebuild

- **The floor device's iOS moves to a new major version** (a new Metal language
  version): change `os_version::IOS_26_0` in the patch to that version, rebuild,
  and rerun #682's per-shader picture identity test on the iPad 8 before the
  release ships. A device on an older iOS rejects the baked binaries and compiles
  at runtime, exactly as an unbaked build does: slower, never wrong.
- **The iOS template moves to another engine commit** (4.7.3 stable, say):
  re-apply the patch to that commit (drop the toolchain hunk once upstream
  carries it), rebuild, update the pin in `tools/godot/bake_export.sh`, and
  rerun the identity test. A bake from a mismatched editor never loads (see
  above), so the failure mode is lost speed, not a wrong picture.
- **Any shader changes:** nothing to do by hand. Every baked export rewrites the
  manifest and rebakes from a clean cache.

## Upstream

Worth sending: the toolchain quoting fix (already #122692), and a preset option
for the iOS bake's GPU family and target OS, so a project can bake for its own
floor device without a patch.

## Native boot upload cap candidate (#660 / #661)

`glassvow-661-native-boot-upload-cap.patch` is a separate runtime source patch
for bounded native PNG boot transfers into the original full texture. Its source pins, immutable original PNG,
CPU tests and bounded portable build/render proof are documented in
[`../native_boot_upload/README.md`](../native_boot_upload/README.md).

This candidate does not change or activate the current iOS template, editor
pin or #682 bake patch. Applying an editor-only patch does not fix a shipped
runtime. Adoption still requires the real patched runtime/export identity and
the existing native device gates; portable Linux evidence proves only its
declared component surface.
