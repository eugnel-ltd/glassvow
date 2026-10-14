# R3.5 follow-up: the gateway arch faces the camera (issue #660)

**The owner's decision (James, 14 Oct 2026, 08:20):** the gateway arch may
stand in front of a waystone's base so that it can face the camera. The pin
is drawn on top and must stay fully visible and tappable.

## What changed

R3.5 found no gateway site within 70° of the camera's line. Every road that
runs up the screen leads to a waystone, and the kit's projected reserve keeps
the arch's body off every stone. Main's arch therefore spans a road across the
screen, and the fixed camera sees it edge-on, as a ladder of voussoirs.

- **A face-on site** (`gateway_sites.gd` `facing`). The arch now stands on a
  straight, dry, level leg within 30° of running up the screen. The leg rules
  are those of `choose`: off the streams, and no other road under a pier.
  Only for the arch, the reserve is relaxed on the camera's side. The arch may
  stand wholly in front of a waystone's seat, with both piers at least 1.8 m
  off it. Behind or beside a waystone, the reserve still holds. Of the
  candidate spots, the arch takes the one nearest the authored focal region,
  as before.
- **Placed last** (`kit.gd` `_face_gateway`). `_landmark` still stands the
  arch at main's site, so every other placement is made round it there, as
  on main. Last of all, the arch moves to the face-on site. That site must be
  clear of everything placed (`_gateway_clear`): dry and level under both
  piers, no ruin's card hiding it, and no tree trunk, post, stone or ruin at
  a pier or on the lane. Undergrowth may grow round a pier's foot, and the
  woodland trims any foliage that would hide the arch. No random numbers are
  drawn.
- **What goes with it.** The arch's footings now go down at `finish`, where it
  ends up (`ground_contacts.gd`). Its apron of flags, its two lamps and the
  woodland's sight of it also move. Its companions (a memorial, banks and
  conifers) and the terrace stay at main's site. That site is a road through
  a clearing ([the old site](frames/s1-pad-landscape-oldsite.jpg)).
- No geometry is added: the existing arch is moved and turned, and no shader
  or material changes. Where no leg has a face-on site, the arch stays at
  main's site.

At the four seeds:

| Seed | Main | Branch |
|---|---|---|
| 717 | (−32.8, 18.3), 82° | (−6.8, 15.1), −27° |
| 1 | (−28.1, 19.0), −83° | (−2.2, 8.6), −28° |
| 2 | (−27.0, −6.1), −87° | (−2.6, 14.2), 22° |
| 3 | (2.0, 17.8), −84° | (−24.5, 7.6), 23° |

At every seed the arch stands in front of at least one waystone. These are in the suite's frame, the identity shape. The kit's ruins already
place by the shape's touch squares, so the game's seed 2 at the pad puts the
arch at (−33.1, 7.5), 15°.

**What else moves.** No other kit placement moves. Every placement except the
arch is the same as main's at seeds 717 and 1–3 (`mac/digests.txt`), and so
are the layout digests. The woodland trims and refills round the arch's two
sites. It differs from main's in 31, 15, 32 and 13 of about 3,800–4,000 cards
(seeds 717, 1, 2 and 3; main-only plus branch-only).

## The pin

The waystone's token is a 2D overlay drawn above the land's view. A tap is
resolved by projection (`WorldMapScreen.pick_node_at`, ray ∩ ground), so no 3D
scenery can cover a token or take its tap. `tests/test_map_gateway.gd` holds
this for every waystone the arch stands in front of, at seeds 717 and 1–3, at
the phone's and the pad's shape:

- the token is drawn above the land;
- with the camera framed on the waystone, a tap at the pane's centre picks
  that waystone, and so do taps at eight points 0.7 of its radius round it.

At these seeds, every waystone the arch stands in front of is in front of a
pier. There, the token sits over the pier or the arch's shoulder.

## Gates

- **Token gate (#679)**, `tools/map_token_gate.gd`, Act I, seeds 717 and 1–3,
  phone and pad: **0 failed** in all eight runs; worst margin 1.014 (seed 2,
  pad, Whole act; R3.5's was 1.017). See [`mac/token-gate.txt`](mac/token-gate.txt).
- **A12 Metal condition.** Every still below was taken with
  `GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 --rendering-driver metal
  --rendering-method mobile`, 11 branch and 10 main runs. Result: **0
  shader-compile errors, 0 script errors, no other error**
  ([`mac/a12.txt`](mac/a12.txt)).
- **iPad.** No batch was run, because the arch adds no geometry: the same
  piece is moved and turned.
- **The suite**, `tests/test_map_gateway.gd`, at seeds 717 and 1–3, checks:
  - the arch faces within 30°;
  - it stands over a road, with no road under its piers;
  - its piers stand off every seat;
  - its footings and apron lie under it;
  - no waystone stands in front of it within the reserve;
  - the pins are drawn on top and pick on a tap;
  - with the turn off, seed 717's arch is edge-on, and every other placement
    is the same with and without the turn.

  **Mutation proofs, 4 of 4.** The test fails each of these:
  - the turn removed;
  - the turn run straight after `_landmark` (everything else then moves);
  - the footings left at the old site;
  - the arch allowed to stand behind a waystone.

## Stills, looked at

All stills are main `22d0e856` on the left and the branch on the right, two
steps in, framed on the branch's arch. Pad and phone use the lean profile;
the desktop uses the full profile.

- Seed 1, Journey: [pad](frames/s1-pad-landscape-journey.jpg),
  [phone](frames/s1-phone-landscape-journey.jpg),
  [desktop](frames/s1-desktop-landscape-journey.jpg).
- Seed 1, Close: [pad](frames/s1-pad-landscape-close.jpg),
  [phone](frames/s1-phone-landscape-close.jpg),
  [desktop](frames/s1-desktop-landscape-close.jpg).
- Seed 1, main's site at Journey, pad: [the old site](frames/s1-pad-landscape-oldsite.jpg).
- Pad, Journey: [seed 2](frames/s2-pad-landscape-journey.jpg),
  [seed 3](frames/s3-pad-landscape-journey.jpg),
  [seed 717](frames/s717-pad-landscape-journey.jpg).

What they show:

- **The arch.** It reads as an arch: two coursed piers and a round head over
  the road, its lamps on the piers, at a three-quarter turn of 15–28°. Main's
  is a ladder.
- **The tokens over it.** The fronted waystone's token sits over a pier's head
  or the arch's shoulder. At seed 3 this is the open token at the start, and
  it stays legible.
- **Main's site.** It now reads as a plain stretch of road.

**For the owner's eye:**

- At seed 1 the gateway is no longer at the start of the journey but
  mid-act. The face-on legs near the start are taken by posts, ruins or
  uneven ground.
- The turn is 22–28° at most seeds rather than square-on: every leg running
  up the screen is that steep.

## Method

The scripts are in [`tools/`](tools/). `look.gd.txt` is R3.3's capture
harness plus `--look-at`, which pans until a world point is mid-screen.
`arch_probe.gd.txt` prints the arch and the digests per seed.
`stills.zsh.txt` and `cap.sh.txt` take the stills. Main's stills and digests
were taken from the same worktree with the change stashed.
