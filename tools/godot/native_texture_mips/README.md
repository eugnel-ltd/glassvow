# Complete mip-chain upload requests (#660)

Vigil Hall's 2048×2048 ASTC 4×4 texture has 12 mip levels: a 4,194,304-byte
base level and a 1,398,128-byte tail. Correcting the separate compressed staging
allocator still leaves its complete 5,592,432-byte upload above the 4 MiB
request bound. This patch divides that upload at complete mip boundaries while
retaining the texture, every compressed byte, all mip levels, and copy extents.
It changes no asset, sampler, material, UV, internal ID, export preset, or
installed engine/template.

## Ordered prerequisites and implementation

Apply `glassvow-660-compressed-upload-staging.patch` first, then
`glassvow-660-bounded-mip-upload.patch`. The first patch belongs to the separate
allocator outcome; this patch does not duplicate its correction. `contract.json`
pins both patches, both upstream source revisions, and the original,
allocator-only, and bounded rendering-device source bytes. Both upstream
revisions have the same original rendering-device bytes. The hosted compiler
uses supported 4.7.2 stable; the shipping template's separate 4.7.3-rc source pin
is an application check, not an activated template.

The initializer preflights actual block rows, row pitch, transfer alignment,
depth slices, and source spans. Each worker request contains one or more
complete mips and cannot exceed 4,194,304 bytes. A complete padded mip including
all its depth slices must fit atomically. Larger atomic mips fail before GPU
allocation in `texture_create`, or before any worker acquisition in the update
initializer. Row-band uploads for larger atomic mips are outside this change.

Each batch transitions only its own mip range and original layer. Earlier
batches complete before replacing the texture's single worker dependency;
the last batch keeps the existing asynchronous behavior. A small chain retains
one request and gains no wait. Allocation requests are the bounded quantity;
this is not a bound on total pool allocation, retained texture memory, RSS,
peak VRAM, or latency.

## Proof layers

`tests/native/test_texture_mip_batches.py` compiles the full verbatim native
initializer and copy helpers with a recording CPU driver under ASan/UBSan.
Its first fixture is frozen at the commit in `contract.json`, before the
production patch. It checks first and every source byte, canaries, complete
mip/depth/layer coverage, real native request and copy calls, backend padding,
barriers, waits, and rejected partial uploads. It is executable native control
flow with a recording driver, not an actual renderer.

`check_patch.py` checks the exact original bytes at both source pins, applies
the allocator prerequisite and mip patch without offsets/fuzz, and checks each
resulting source hash. For cached pinned source files:

```bash
python3 -B tools/godot/native_texture_mips/check_patch.py \
  --source /path/to/stable/rendering_device.cpp \
  --shipping-source /path/to/shipping/rendering_device.cpp \
  --prerequisite-patch tools/godot/patches/glassvow-660-compressed-upload-staging.patch \
  --output work/native-mips-source-check
python3 -B -m unittest discover -s tests/native -p 'test_*mip*.py'
python3 -B tools/godot/native_boot_upload/test_harness.py
```

The component workflow `.github/workflows/native-texture-mips.yml` prepares
the next proof layer. It compiles two fresh engines sequentially from one
sealed upstream archive, using the shared builder's ordered prerequisite
support. The baseline has only the allocator correction; the candidate also
has this mip patch. An empty doctest selection explicitly means **NOT RUN**;
the independent CPU contract and actual RD probe supply this component's
checks. No unrelated repository suite is replayed by this workflow.

Both portable test builds explicitly use `disable_path_overrides=no`; the
manifest declares `portable_component_proof` and denies shipping template
qualification. The pinned engine otherwise rejects `--path`, resets the
working directory to the executable directory, and clears `--script`.
Changing only the process working directory cannot run this SceneTree probe.
The verifier requires exactly one enabling flag and the explicit declaration;
the contract also pins the integrated shared builder's bytes. This supported
test-build configuration does not modify an installed or shipping template.

`observer.py` adds opt-in, local-RD-only hooks immediately around actual worker
requests, copy commands, mip barriers, and completed waits. It refuses source
hashes other than the exact allocator-only and bounded candidates. Test-only
padded cases force the same conservative 256-byte pitch and 512-byte transfer
profile in both variants. Observer hooks never enter the production patch.

`probe.py` runs a headed X11/Vulkan process through Xvfb with one explicitly
selected, hashed lavapipe ICD. It reports physical format support before each
case, reads the created RD format descriptor, and compares every GPU readback
byte with a varying source pattern. Its standalone project includes a valid
empty global-class cache because the probe declares no global classes; the
cache hash joins the script and executable identities. ASTC tests include Vigil's exact shape,
two layers, padded and odd-size chains, a single exact-cap level, and an
oversized atomic rejection. RGBA8 depth and oversized full-chain controls
exercise supported RD transport when compressed formats are unavailable;
the RGBA chain is explicitly a transport analogue, not compressed ASTC proof.

`verify.py` binds the compiled binaries, ordered patch stages, source-tree
identities, observer receipts, scripts, and ICD. It rejects missing/duplicate
events, altered payloads, format fallback, incomplete mip copies, wrong
barriers/waits, and unbounded requests. Requested, physically supported,
created, and native observed formats must agree. The verifier independently
reconstructs payload hashes and backend layouts.
Reservation totals come from the actual recorded backend pitch/alignment;
raw payload totals stay fixed. Every copy in one request must share the same
worker base offset. Native ERROR rejection remains strict.

If actual ASTC support is absent, supported RGBA readback can be reported
separately, but the overall result is `INCONCLUSIVE_ASTC_UNSUPPORTED` and exits
2. No decompression fallback earns a compressed-format pass. Even a complete
software-Vulkan component pass is not Metal/iOS, A12/device, frame timing,
peak-VRAM, or release acceptance. Shipping template activation and those
platform proofs remain separate governed work.

## Current execution status

The frozen CPU fixture is red on both original native code and allocator-only
native code. The bounded candidate passes the full CPU fixture and cheap
tooling checks. Hosted engine and observer compilation completed at
`b409e476647564738ed2376ad017a0e069bce4ce`, but job `117733507995` rejected the
baseline probe's `--path` before RD uploads because path overrides were
disabled. That failed attempt remains evidence, not a renderer pass. A
separate source-only regression was frozen before this runtime configuration
correction. The corrected configuration awaits the next hosted build and
actual RD/GPU execution; no pass is inferred from the CPU control or source
checks.

Job `117746266505` subsequently compiled both variants and completed equal
RGBA8 readbacks, with an actual 128-byte transfer alignment. Its baseline
request was 5,592,580 bytes; candidate requests were 4,194,304 and 1,398,276
bytes. ASTC was unsupported. The wrapper exited 1 on the missing global-class
cache, before reaching its separate incorrect unaligned-total assertion.
Those complete failed logs are retained in the archived regression corpus.
The cache/layout regression was frozen at `2dbea2d5752c0e599a293dba8177ac20dc040303`
before correction. Event-only offline replay validates the supported control
arithmetic without qualifying the original failed run or claiming ASTC proof.
The corrected cache setup still awaits actual native execution. See
[macOS venue feasibility](macos-venue.md) for a maintained possible venue;
no GPU capability or new workflow is established by that note.
