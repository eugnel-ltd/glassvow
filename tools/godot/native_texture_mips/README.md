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

`observer.py` adds opt-in, local-RD-only hooks immediately around actual worker
requests, copy commands, mip barriers, and completed waits. It refuses source
hashes other than the exact allocator-only and bounded candidates. Test-only
padded cases force the same conservative 256-byte pitch and 512-byte transfer
profile in both variants. Observer hooks never enter the production patch.

`probe.py` runs a headed X11/Vulkan process through Xvfb with one explicitly
selected, hashed lavapipe ICD. It reports physical format support before each
case, reads the created RD format descriptor, and compares every GPU readback
byte with a varying source pattern. ASTC tests include Vigil's exact shape,
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

If actual ASTC support is absent, supported RGBA readback can be reported
separately, but the overall result is `INCONCLUSIVE_ASTC_UNSUPPORTED` and exits
2. No decompression fallback earns a compressed-format pass. Even a complete
software-Vulkan component pass is not Metal/iOS, A12/device, frame timing,
peak-VRAM, or release acceptance. Shipping template activation and those
platform proofs remain separate governed work.

## Current execution status

The frozen CPU fixture is red on both original native code and allocator-only
native code. The bounded candidate passes the full CPU fixture and cheap
tooling checks. Actual hosted engine compilation, observer compilation, and
RD/GPU execution have not run yet. The workflow is the executable next step;
its status must be reported from actual artifacts rather than inferred from
the CPU control or source checks.
