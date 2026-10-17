# Engine only: make labelled temporal sheets from existing Godot capture frames.
import json
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont

args = sys.argv[1:]
assert args
try:
    font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 14)
except OSError:
    font = ImageFont.load_default()
for argument in args:
    folder = Path(argument).resolve()
    assert folder.is_dir() and "asset-manager-lab" in folder.parts
    manifest = json.loads((folder / "frames.json").read_text())
    output = folder / "temporal-sheet-exact.png"
    assert not output.exists(), "Preserve a previous inspection sheet"
    assert len(manifest) == 6
    canvas = Image.new("RGB", (6 * 256, 6 * 280), "#292d35")
    draw = ImageDraw.Draw(canvas)
    for row, clip in enumerate(manifest):
        assert clip["frames"] >= 6
        for column in range(6):
            index = clip["start"] + round((clip["frames"] - 1) * column / 5)
            source = folder / f"frame-{index:04d}.png"
            with Image.open(source) as image:
                assert image.size == (640, 640)
                canvas.paste(image.convert("RGB").resize((256, 256), Image.Resampling.LANCZOS), (column * 256, row * 280 + 24))
            time = min((index - clip["start"]) / 30, clip["seconds"])
            draw.text((column * 256 + 6, row * 280 + 4), f"{clip['clip']} {time:.2f}s", fill="white", font=font)
    canvas.save(output)
    print("TEMPORAL SHEET", folder.name, output, flush=True)
