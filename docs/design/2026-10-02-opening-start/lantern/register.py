"""Register the hero lantern pick onto the HUD lantern's set-out.

`LanternFlame`'s shader lights the art in its own UV: the wick at (0.5, 0.785),
the panes in (0.31, 0.43)-(0.69, 0.795). The HUD art (assets/art/ui/lantern.png,
512 px) puts its centre light at x 226-283 and y 243-401. The pick's centre light
was measured with the shader's own glass test at x 430-593, y 652-1109, so one
uniform scale (0.3465 of HUD space, both axes agree) and a translation put its
glass exactly where the shader expects it. Output is 1024 px square, twice the
HUD art's resolution, so the same shader constants light it unchanged.

Usage: python3 register.py candidate-1.png ../../../../assets/art/title/lantern-hero.png
"""
import sys
from PIL import Image

SIZE = 1024
HUD = 512
SCALE_HUD = 0.3465                 # pick px -> HUD px
PICK_CENTRE_X, PICK_FOOT_Y = 511.5, 1109.0
HUD_CENTRE_X, HUD_FOOT_Y = 254.5, 401.0


def main(src: str, dst: str) -> None:
    pick = Image.open(src).convert("RGBA")
    k = SCALE_HUD * SIZE / HUD
    scaled = pick.resize((round(pick.width * k), round(pick.height * k)), Image.LANCZOS)
    ox = HUD_CENTRE_X * SIZE / HUD - PICK_CENTRE_X * k
    oy = HUD_FOOT_Y * SIZE / HUD - PICK_FOOT_Y * k
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, (round(ox), round(oy)))
    canvas.save(dst, optimize=True)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
