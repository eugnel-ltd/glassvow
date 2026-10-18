# Keep the title painting's uploads below 4 MiB

The title still uses a covered `TextureRect` at alpha `0.35`. Its `Texture2D`
resource now draws two independent lossless RGB pages, each `1536 × 513`.
The original painting remains `1536 × 1024`; its PNG bytes and existing
`CompressedTexture2D` import are unchanged.

The top page owns source rows `0..511` and includes row `512` for linear
filtering. The bottom owns `512..1023` and includes row `511` above them.
The draw regions meet without overlap, and forward the native TextureRect's
filtering and clipping flags. No shader, rescaling, grading or alpha baking is
involved. The title and departure keep their existing cover and crop geometry.

Each page contains `2,363,904` RGB8 bytes without mipmaps. A renderer that expands
RGB8 to RGBA8 still uploads only `3,151,872` bytes, below `4,194,304`. The original
oversized import is no longer referenced by the running title and is excluded
by its exact path in all six export presets. It stays loadable in the editor
for source compatibility. The generic upload guard has no title exception;
the focused regression also sizes the live page images directly and reconstructs
the original pixels and filter gutters exactly.

Regenerate the derived pages from the unchanged source with Pillow:

```python
from PIL import Image
from pathlib import Path

folder = Path("assets/art/title-background")
source = Image.open(folder / "background.png")
assert source.mode == "RGB" and source.size == (1536, 1024)
source.crop((0, 0, 1536, 513)).save(folder / "background-page-top.png")
source.crop((0, 511, 1536, 1024)).save(folder / "background-page-bottom.png")
```

Keep only these new page assets in Git LFS. Workflows that import the current
product fetch LFS at checkout; existing assets and history are not retracked.
The source-preservation/upload regression is `tests/test_title_upload.gd`.
Headed GLES3 comparisons covered native, reduced, enlarged and cropped shapes,
fractional geometry, inherited nearest/linear filtering and a broken-seam
control. Nearest matched exactly; linear differed by at most one 8-bit level.
This establishes the representation contract, not A12 timing or total VRAM.
