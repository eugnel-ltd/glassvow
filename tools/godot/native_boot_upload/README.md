# Native boot upload component proof (#660 / #661)

The raw boot PNG is loaded before resource import or scripts. The governed
`glassvow-661-native-boot-upload-cap.patch` divides large native PNGs into
lossless full-width slices before native texture initialization. The original
2360 x 1640 splash uses four pages; every page is at most 3,889,280 bytes even
after RD expands RGB8 to RGBA8. The PNG, its resource path, settings, resolution
and runtime/template pins remain unchanged.

The native helper copies original-neighbor rows for linear filtering and draws
only each page's owned rows through the original full-image screen rectangle.
RD retains clamp sampling. GLES retains horizontal repeat and copies the
opposite original edge into the outer vertical gutters, preserving its existing
repeat sampling. Existing blend, color/HDR conversion, pre-rotation, filter,
clear and final presentation paths stay in the compositor. Images outside the
helper's format/mipmap predicate retain the previous single-image path.
Qualifying large Image API inputs are sliced regardless of their source file
type. Main supplies four uncompressed native PNG formats, with no mipmaps.

This patch is a source candidate. These files do not activate a template,
change the bake editor pin, replace the installed engine, sign an app or
establish device acceptance. In particular, a portable component PASS cannot
empty the shipped splash ratchet until a real patched export/template is
identified and verified through the existing release integration.

## Exact inputs and build boundary

`contract.json` binds the original PNG and task acceptance. The immutable first
control, `tests/native/boot_upload_baseline.gd`, uses native ImageLoader on the original
PNG and must exit 1 with `FAIL baseline_native_boot_upload`. It establishes
the decoded-image violation, not a renderer result. Do not change it to call
the new planner or convert that original failure into an unqualified PASS.

`source-manifest.json` binds the files patched at both full engine commits:

- stable portable source: `ed1daf0bf001b61586d9930840f2f1394092c079` (4.7.2);
- existing specific iOS runtime/bake source:
  `83dec14d549108e1f314f57c1ce7e932c65370dd` (4.7.3 **rc**, not stable).

`check_patch.py` verifies those source hashes and clean application in new
temporary directories. It downloads only patch-facing public source files, or
accepts an explicit offline cache. The native patch includes real C++ helper
tests in the `GlassvowBootUpload` suite. Source application and Python evidence
verifier tests cannot substitute for compiling/running those tests.

The portable hosted job builds baseline and candidate sequentially from the
same SHA-256-pinned stable source archive with identical SCons options. Only the
candidate receives the production patch. Both receive the same `observer.py`
instrumentation after patch application. The archive's unmodified `version.py`,
complete source tree, patch, observer and binary hashes are captured; a custom
archive build truthfully need not report a git suffix. Neither build replaces
the provisioned official stable engine.

The observer is **CI-only source instrumentation**. It logs the actual decoded
source and validated Images at the actual RD/GLES storage upload callsites,
then counts boot clears/draws and holds after the actual final presentation.
It does not enter the shipping patch. Its environment-controlled hold never
changes the shipped splash timing.

`capture.py` runs real native boot under Xvfb, never headless. It captures while
the observer holds before project scripts can run, and rejects early script
entry, renderer fallback, blank frames, changed content bounds, changed source
sampling, changed pixels and oversized actual candidate payloads. Both GLES
llvmpipe and Vulkan RD lavapipe are required. The unchanged baseline must retain
the oversized upload; an actual corrupted-source run must fail the image
verifier. A supported renderer that cannot start leaves failed/inconclusive
evidence and cannot yield a renderer PASS.

The source oracle and screenshots cover the actual source asset, reference
shapes, fractional scaling, source-size anchor, both filters, all stretch modes
and asymmetric RGB/RGBA edge/seam fixtures. The exact baseline/candidate pixel
comparison is supplemented by an independent source sampler and bounding-box
check. This prevents equality of two empty frames from passing. Captures still
need actual visual inspection before claiming the presentation invariant.

## Trigger, cost and scope

The single bounded public-hosted workflow runs for a PR changing this patch or
its evidence tools, or by an explicit workflow dispatch. It has no feature
branch push trigger, provider credentials, private-network dependency or device
step. Limits cover source download, native compilation, native tests, process
groups, captures and the whole job. Logs and small captures are retained on
failure as well as success.

The reason to retain this component mechanism is the risk of a native upload
fix that compiles but changes pre-script rendering or never reaches the actual
boot call. Run the native job when the patch or observer/proof contract changes;
do not replay unrelated product suites inside it. Remove it when the native
patch is retired in favor of an upstream engine with equivalent maintained
proof, or narrow it when the supported renderer surface changes.

This proves neither Metal/iOS behavior, a shipping template, A12 timing, HDR or
platform pre-rotation, total VRAM, peak RSS, worker overlap, signing nor store
acceptance. Those remain the existing native-host/export/device gates. The
general compressed staging allocator correction belongs to a separate patch.

## Commands and current evidence status

Run from the repository root. A configured Python environment needs the same
Pillow/numpy versions listed in the workflow for verifier/capture commands.

```sh
python3 tools/godot/native_boot_upload/check_patch.py --output work/native-boot/source-check.json
python3 tools/godot/native_boot_upload/test_harness.py
python3 tools/godot/native_boot_upload/build.py --splash assets/art/title/splash.png --work work/native-boot/builds --output work/native-boot/evidence
```

The build command accepts `--production-patch` (alias `--patch`), `--observer`
and `--test-suite` so another independently owned component can reuse the
source/build interface without changing this boot patch. `--source-archive`
accepts an already downloaded archive with the sealed hash; an archive hash
override is an explicit source-pin contract change, not a cache convenience.
The capture invocation is shown in the workflow and consumes only the newly
built executable paths recorded by `build.py`.

An explicit empty `--test-suite ''` is reserved for independently owned
components with a separate compiled test protocol. The build manifest records
that native suite as `NOT RUN` with the reason; it does not count as native
test evidence. This boot workflow explicitly selects `GlassvowBootUpload` and
still requires a nonempty passing native suite.

Local preparation ran the real original-PNG failing control, both source-pin
application checks, observer application/refusal checks, and evidence/process
verifier tests. Native engine compilation, C++ doctests, headed renderer
captures, live corrupt-source rendering and hosted execution are **NOT RUN**.
The preparation host has no Xvfb or SCons, and no installation or long local
engine compilation was attempted. Logs and manifests in the task capsule
record the actual results; no native PASS follows from this preparation.
