# Engine: stack chosen rows of several temporal sheets into one labelled review image.
#   python3 death_rows.py <output.png> <row-index> <sheet.png> ...   (rows: 0 idle .. 5 death)
from pathlib import Path
import sys

from PIL import Image, ImageDraw

output, row, *sheets = sys.argv[1:]
row = int(row)
assert not Path(output).exists() and sheets
canvas = Image.new("RGB", (1536, 280 * len(sheets)), "#292d35")
draw = ImageDraw.Draw(canvas)
for index, sheet in enumerate(sheets):
    # "sheet.png@N" overrides the default row for that one sheet.
    sheet, _, own = sheet.partition("@")
    pick = int(own) if own else row
    with Image.open(sheet) as image:
        assert image.size == (1536, 1680)
        canvas.paste(image.crop((0, pick * 280, 1536, pick * 280 + 280)), (0, index * 280))
    # Name the source on top of the strip so each row stays attributable.
    draw.rectangle((900, index * 280, 1536, index * 280 + 22), fill="#292d35")
    draw.text((904, index * 280 + 4), Path(sheet).parent.parent.name, fill="#ffd27a")
canvas.save(output)
print(output, len(sheets))
