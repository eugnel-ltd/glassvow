# Compressed texture upload staging (#660)

`glassvow-660-compressed-upload-staging.patch` corrects one native RD
reservation. It changes no compressed bytes, texture format, pixels, mips,
copy command, runtime pin or export template.

In Godot 4.7.2, `_texture_initialize` computes a **block-row** pitch but then
reserves that pitch times a pixel-row count, with a second format right
shift. It copies only `padded_height / block_height` block rows. On Metal's
unit-pitch path this wastes 2× the tight data for ETC2 RGB8 and 4× for ETC2
RGBA8, EAC RG11 and ASTC 4x4. The patch reserves the real block-row count
while retaining driver row-pitch padding and per-mip/depth alignment.

Apply it separately from the shader-bake and native-boot patches:

```sh
git apply --unidiff-zero /path/to/glassvow/tools/godot/patches/glassvow-660-compressed-upload-staging.patch
```

The patch applies without offsets or fuzz at both exact source pins:

- supported component engine: `ed1daf0bf001b61586d9930840f2f1394092c079`;
- existing template source: `83dec14d549108e1f314f57c1ce7e932c65370dd`.

The original `rendering_device.cpp` is identical at these pins. Merely adding
the patch to this repository does not replace a deployed editor or template.
The existing runtime/template and shader-bake identity contract still applies.
The small hunk has no context lines; apply it only to the exact pinned source.
The hosted builder checks the full original source and applies with zero fuzz.

The immutable native first regression is
`tests/native/test_texture_upload_staging.py`. It compiles the exact upstream
reservation, alignment and copy source statements/functions with C++17,
warnings as errors, ASan and UBSan. It covers odd block dimensions, full mip
chains, depth slices, array layers, nonunit pitch/alignment, untouched padding
and canaries, and byte-identical copies. It needs a C++ compiler, not Godot:

```sh
python3 tests/native/test_texture_upload_staging.py \
  --source /path/to/upstream/servers/rendering/rendering_device.cpp \
  --build-dir work/staging-native-first
```

The original source must exit 1 with named over-reservation failures after
compiling successfully; patched source must exit 0. This CPU-native control
does not substitute for actual RD/driver execution.

The hosted component route uses the separately pinned shared native builder
and `tools/godot/native_texture_staging/`:

The workflow pins shared builder `a08e1ab8f9b5e1c8c0dd3e8c450db839f0a5acb6`
and its exact helper hashes. Both portable template variants explicitly use
`disable_path_overrides=no`, required by these isolated `--path`/`--script`
projects. The pinned native source resets cwd and discards script overrides
without this support, so changing cwd alone is insufficient. The manifest
records `runtime_test_configuration` as portable component proof with
`shipping_template_qualification: false`; no shipping build pin changes.
The wrapper rejects an unsupported shared configuration before downloading or
compiling. Source-only runtime/identity controls run before the hosted build.
On failure, only the two generated RD `native.log` tails are printed (at most
8192 bytes/80 lines each); symlink/outside paths, unrelated files, commands
and environment dumps are excluded. Full logs remain in the artifact.

- `observer.py --source-dir TREE` installs the same opt-in request/copy hooks
  in baseline and candidate. Only a local RD and a probe-selected case emit
  data. Two cases conservatively force 256-byte row pitch / 512-byte alignment
  in both builds; those overrides are evidence-only, never part of the patch.
- `probe.py --binary BIN --output NEWDIR` creates real ETC2/EAC/ASTC and
  uncompressed textures through Vulkan, including mip chains, array layers
  and a 3D control. It reads every layer back and compares exact bytes. A
  missing format/device, script diagnostic or failed readback fails the probe.
- `verify.py` checks all actual worker requests and every mip/depth copy,
  baseline waste, candidate row bounds, nonunit alignment and matching GPU
  readback hashes. It requires all seven cases / eleven layers per variant.
- `run_component.py` composes this protocol with an explicitly supplied,
  hash-locked shared builder and records its selected checks. It first runs
  the native first regression on the real archive source, then builds both
  native engines and runs the actual RD probe. Its work/output directories
  must be new. This is a hosted build, never an implicit local self-test.

Linux software-Vulkan proves that component path. It does not establish
Metal/iOS template qualification, A12 memory measurements, or a release.
There is no source/art exception to make a budget pass. The genuinely large
23 historical images and Vigil Hall's 5,592,432-byte ASTC mip chain require
their separately owned engineering outcomes; this patch only removes unused
compressed staging space.
