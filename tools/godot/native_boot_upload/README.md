# Native boot upload component proof (#660 / #661)

The raw boot PNG is loaded before resource import or scripts. The governed
`glassvow-661-native-boot-upload-cap.patch` preserves one full native texture,
its original dimensions, normalized sampler coordinates and single full-image
quad. Only the boot data submissions are divided into full-width owned-row
bands. GLES allocates the original 2360 x 1640 texture without initial data, then uses
four 410-row subimage transfers, each 3,870,400 conservative RGBA bytes. RD
chooses balanced full-width row bands using the actual driver's row-pitch
requirement and the existing frame-staging block capacity. Every request is at
most the smaller of 4 MiB and that real capacity. With a 256-byte pitch and the
pinned 256 KiB default block, the splash uses 61 bands of 26 or 27 rows, at most
255,744 bytes each. The full validated payload is still 15,481,600 bytes; those
aligned staging requests total 15,534,080 bytes. Different supported driver
pitch or configured block sizes produce a truthfully recorded different count.
RD creates the full empty texture and reuses its existing staging, copy,
required-action/flush and draw-graph update lifetime without global pool changes.

RD retains clamp sampling and GLES retains repeat sampling on the original
full texture. No page boundaries, gutters, source remapping or extra quads enter
the active draw path. Blend, color/HDR conversion, pre-rotation, filter, clear
and final presentation remain the original compositor code. The PNG, its
resource path, settings, resolution and runtime/template pins remain unchanged.
Other Image API formats and mipmaps retain their previous initialization path.
The original slice helper and its immutable native tests remain as historical
controls; the compositor no longer calls that helper.

The 4 MiB limit governs individual native upload/staging requests. This change
retains the full GPU allocation and decoded source image. It establishes no
reduction in total VRAM, decoder lifetime, existing staging-pool capacity or
peak process memory. The existing pool may grow and retain multiple blocks
under its unchanged policy; the request cap alone establishes no total-memory
gain. A full conservative row must fit the actual block or the boot upload
rejects before submitting a partial texture. The shipped guard stays failing until an identified
patched template is actually adopted and qualified.

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

These portable `template_debug` builds explicitly use
`disable_path_overrides=no` for both variants. Their isolated fixture projects
and scripts require native `--path`/`--script` support; the pinned engine resets
cwd to the executable directory and discards script overrides without it.
Changing cwd alone cannot support these probes. `build-manifest.json` records
the identical SCons flags and `runtime_test_configuration`, explicitly marking
portable component proof with `shipping_template_qualification: false`.
This test configuration changes no shipping template, runtime/source pin or
production patch. Historical builds without the flag retain their own receipts
and need a new compiled/runtime run under this supported test configuration.

The additive schema 2 verifier requires one full allocation, exact contiguous
row coverage, original source offsets and UVs, the original quad, actual driver
pitch, real staging capacity and the derived band count. The schema 1 upload
contract is retained. The independent pixel oracle now handles exact nearest
boundaries as described below; its former prefix remains historical evidence.

The observer is **CI-only source instrumentation**. It logs the actual decoded
source, full native allocation, actual transfer calls and native staging
requests, then counts boot clears/draws and holds after the final presentation.
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

The native quad, uniforms and interpolated UVs are floats. At an exact rational
interior texel boundary, rounding can choose either adjacent nearest sample.
The oracle compares whole source colours, including alpha blending, from those
exact boundary samples. It never searches neighbouring pixels, admits nearby
values or mixes channels from different samples. Other pixels and linear
filtering keep the original reference. Frame pairing remains exact; the global
source channel-error limit remains 2 and bounding-box checks are unchanged.
Reports expose both the nominal error and the error against admissible samples.

Before paired builds, `stock_oracle.py` hashes the official 4.7.2 binary and
checks all 17 source cases on both software renderers within 180 seconds. It
captures once per case during native minimum display time, with unique project
and XDG state and process-group cleanup. Missing capability, early script entry,
source mismatch or deadline exhaustion fails the screen. This is an oracle
preflight; paired builds, upload observations, exact captures and live negatives
remain required.

## Trigger, cost and scope

The single bounded public-hosted workflow runs for a PR changing this patch or
its evidence tools, or by an explicit workflow dispatch. It has no feature
branch push trigger, provider credentials, private-network dependency or device
step. Limits cover source download, native compilation, native tests, process
groups, captures and the whole job. Logs and small captures are retained on
failure as well as success.

On failure, the job prints the active renderer/case/variant/phase and bounded
tails of that capture's generated `capture-worker.log` and `native.log` (at
most 8 KiB / 80 lines each). It reads neither environment values nor command
or project files, prefixes every line and omits URLs and credential fields.
The active capture is persisted before launch so an outer timeout still leaves
useful context. The CLI regression observes the worker's actual argv without
launching an engine: pinned Godot requires `--resolution WxH`, while
`--position X,Y` retains its distinct comma delimiter.

After the complete real matrix succeeds, `contact_sheets.py` transports two
labeled JPEG review sheets through job stdout, one per renderer. Every
baseline/candidate pair appears in `cases.json` order; GLES also includes the
actual live negative comparison. The reader accepts only successful report
entries and exact PNG/native-hold metadata paths, checks screenshot hashes,
and rejects missing, symlinked or outside-root proof. It never reads source
paths, environment, commands, specifications or unrelated files.

The sheets use fixed 288 x 200 thumbnail bounds, at most 200 KiB per JPEG and
600 KiB total base64. A bounded quality ladder must fit every case or the
transport fails; no case is dropped. `GV_BOOT_CONTACT_BEGIN` carries JSON
filename/size/SHA-256/chunk metadata, followed by sequential
`GV_BOOT_CONTACT_DATA <filename> <0000/total> <base64>` records (4096 characters
per chunk) and `GV_BOOT_CONTACT_END <filename> <sha256>`. Decode all chunks
with strict base64 validation, check byte count, SHA and both end records before
viewing. This permits inspection through the existing job-log reader when
artifact byte transport is unavailable. Full PNGs, pixel oracles and the
capture-to-sheet manifest remain in the original artifact. These lossy review
copies add no native/GPU PASS and never replace the exact pixel comparison.

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
python3 tools/godot/native_boot_upload/test_schema2_corrected_oracle.py
python3 tools/godot/native_boot_upload/test_frame_capacity.py
python3 tests/native/test_native_boot_call_setup.py
python3 tests/native/test_native_boot_source_oracle.py
python3 tools/godot/native_boot_upload/native_calls.py --output work/native-boot/native-calls
python3 tests/native/test_boot_capture_cli.py
python3 tests/native/test_boot_capture_diagnostics.py
python3 tests/native/test_boot_contact_sheets.py
python3 tools/godot/native_boot_upload/build.py --splash assets/art/title/splash.png --work work/native-boot/builds --output work/native-boot/evidence
```

The build command accepts `--production-patch` (alias `--patch`), `--observer`
and `--test-suite` so another independently owned component can reuse the
source/build interface without changing this boot patch. `--source-archive`
accepts an already downloaded archive with the sealed hash; an archive hash
override is an explicit source-pin contract change, not a cache convenience.

An optional repeated `--prerequisite-patch PATH` applies each patch in order to
both variants before the candidate's production patch. The manifest records
every patch hash and resulting source-tree hash per variant. With no argument,
boot's original baseline/candidate behavior is unchanged.
The capture invocation is shown in the workflow and consumes only the newly
built executable paths recorded by `build.py`.

The maintained schema2 runner executes all 17 original behavioral cases without
editing their frozen file. It explicitly retires that file's obsolete whole
pixel-prefix assertion, retains the old prefix under `historical/`, and checks
the unchanged active schema1 upload body and original harness bytes. The new
source-oracle controls govern the deliberate pixel-reference correction.

Native-call candidate preparation prevents Git from discovering an enclosing
repository. The same patched RD methods must reach the capacity fixture when
the evidence output is inside the hosted checkout or in a detached directory;
the setup regression exercises both layouts without compiling native code.

An explicit empty `--test-suite ''` is reserved for independently owned
components with a separate compiled test protocol. The build manifest records
that native suite as `NOT RUN` with the reason; it does not count as native
test evidence. This boot workflow explicitly selects `GlassvowBootUpload` and
still requires a nonempty passing native suite.

Initial local preparation ran the real original-PNG failing control, both source-pin
application checks, observer application/refusal checks, and evidence/process
verifier tests. Native engine compilation, C++ doctests, headed renderer
captures, live corrupt-source rendering and hosted execution are **NOT RUN**.
The preparation host has no Xvfb or SCons, and no installation or long local
engine compilation was attempted. Logs and manifests in the task capsule
record the actual results; no native PASS follows from this preparation.

Hosted run `39144005120` at `071395306922586d7384b095753499b28d541efa`
subsequently passed the baseline/candidate build and native C++ control step,
then failed at the first GLES baseline capture. Its inner capture logs were
unavailable to the author. The source-grounded resolution delimiter regression
failed before its harness correction; a new real capture must still establish
renderer behavior. The previous build-step receipt is not a renderer PASS.

Hosted job `117745515281` at `a08e1ab8f9b5e1c8c0dd3e8c450db839f0a5acb6`
compiled both variants and reached actual rendering. It failed exact GLES
linear-filter equality on `asymmetric-s1-f1`: maximum difference 1, with 147
changed pixels. Nearest-filter cases passed. Sliced textures changed the
normalized source interpolation and sampler dimensions; source-bound float
analysis identifies rounding-sensitive source rows. No tolerance was changed.
The subsequent immutable native call regression compiles the actual old
compositor/storage bodies and fails their multiple-texture layout, before the
full-texture transfer correction. Recording GL/RD fixtures then verify exact
assembled bytes, bounded submissions and unchanged ordinary API behavior with
ASan/UBSan. These are compiled native function-body controls with backend/type
stubs, not renderer or engine-build proof. New paired hosted compilation and
exact captures remain required for the correction.

Hosted job `117768816495` at `ab38334f1c03428e8a2fd41d7b2a3590972331b0`
built both engines, passed native controls and preserved exact frame equality.
Its source oracle rejected the unchanged GLES baseline on `asymmetric-s2-f0`
with nominal error 208. The unchanged official ed1 binary reproduced exactly
308 affected pixels on the centre-column nearest boundary. The exact-boundary
correction accepts those whole samples with error 0. This diagnoses the oracle
defect and does not qualify the patched renderer.

The first RD recording proposal (`tests/native/rd_boot_upload_calls/`) is frozen
but superseded: its backend allocated a new unconstrained buffer per request
and omitted the real 256 KiB default capacity. Its green result did not prove
that the four-band draft fit Godot's pool. That draft and receipts are retained.
The capacity-bound successor models a finite block and reuse/flush, first
rejects the oversized draft, then proves adaptive bands against actual block
capacity. The GLES immutable regression remains the original valid lineage.
