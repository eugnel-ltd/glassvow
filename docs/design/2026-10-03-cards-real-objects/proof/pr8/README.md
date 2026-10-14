# #657 PR 8, the owner's card-back art: evidence

James picked the backs on 14 Oct 2026: the Lancet **B**, Vesper **A**, Eclipse
**C** (the candidates and their prompts: `docs/art-ledger.md`, "Card backs").
`land.py.txt` cut each pick to the face and wrote `assets/art/backs/`; it prints
the border measures quoted below.

## The crop

Each candidate is 1024 × 1536 with a gold border. The face is 152:216, so a
full-width cut is 1024 × 1455, and the script centres that cut on the border
rather than on the canvas. Then the border sits the same distance in on the left
and right, and on the top and bottom, in card px:

| Back | Pick | Cut (y) | Left / right | Top / bottom | Gold under the corners or the 2 px edge |
|---|---|---|---|---|---|
| vault | Lancet B | 34–1489 | 9.9 / 9.9 | 6.1 / 5.9 | 0 px |
| rose | Vesper A | 27–1482 | 11.0 / 11.0 | 7.0 / 7.0 | 0 px |
| eclipse | Eclipse C | 22–1477 | 9.2 / 9.2 | 7.4 / 7.6 | 8 px (ray tips at the sides) |

The sides cannot match the ends exactly without repainting. Each border is
taller than the card (0.64–0.67 against 0.70), and the cut is already the full
width, so the ends sit 3–4 card px closer to the edge than the sides. Eclipse
C's corner medallions are whole, about 6 card px in from the side and 4 from the
end, inside the rounded corner (radius 11).

## Stills (looked at)

All were taken on the real Main, windowed, on the lane's isolated user dir.

- `01-landed-backs.jpg`: the three files as shipped, with the card's corners.
- `02-vigil-backs-shelf.jpg`: the Backs shelf at pad, phone and desktop, in
  en and zh-Hant. The Lancet is earned, Vesper chosen and Eclipse locked
  (`tools/capture_rooms.gd --state=mid --path=vigil --hold --look=backs --nowins --back=rose`).
- `03-vigil-backs-all-earned.jpg`: all three earned, Eclipse chosen, pad en.
- `04-fight-draw-pile.jpg` and `05-fight-pile-zoom.jpg`: the chosen back face down
  on a fight's draw pile and the HUD deck (`--fight=duskfang`). Each back
  appears at least once across the three shapes and both locales.
- `06-dawn-earned-back.jpg`: Eclipse revealed at Dawn, at the three shapes, in
  en and zh-Hant.

## The A12 repro

`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 godot --rendering-driver metal
--rendering-method mobile` (Forward Mobile, classic binding, as on the A12) ran
the shelf with all three backs earned and Eclipse chosen. It logged no
sampler error and no shader compile error, and its still is byte-identical
to the one in `03`.
