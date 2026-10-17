"""Build labelled reference sheets for character rig planning. Run on the engine."""
from pathlib import Path
from PIL import Image, ImageDraw

LANE = Path(__file__).resolve().parent.parent
GROUPS = {
    "act2": "drownedOne voltEel mirelurker tidecaller shellback deepmaw abyssalKnight siren leviathan",
    "act3": "voidWisp obsidianGolem starCultist shade chaosHound watcherEye voidColossus heraldOfEnd sovereign",
    "act4": "eternalKeeper uncarvedSelf uncrossedSelf unlitSelf unobsidianSelf unopenedSelf unsunkSelf unwalkedSelf unwoodedSelf",
}
for group, names in GROUPS.items():
    canvas = Image.new("RGB", (1050, 1020), (70, 70, 74))
    draw = ImageDraw.Draw(canvas)
    for i, name in enumerate(names.split()):
        with Image.open(LANE / f"mobs/{name}/ref/body-a.png") as source:
            image = source.convert("RGBA")
        image.thumbnail((330, 300))
        x, y = i % 3 * 350, i // 3 * 340
        canvas.paste(image, (x + (350 - image.width) // 2, y + (300 - image.height) // 2), image)
        draw.text((x + 12, y + 310), name, fill="white", font_size=18)
    output = LANE / f"smoke/{group}-refs.png"
    canvas.save(output)
    print(output)
