# Mythic art layers — round 4, A set

16 October 2026. Art-only candidate stage. No git, branch, PR, CI, Godot run or production asset write. Candidate B is outside this stage. The next gate is the orchestrator's owner review of the six A candidates together.

## Method

`LOOKS.md` was written before the first image call. It assigns six different cameras, worlds, lights, palettes, glass treatments and depth recipes. The shared thread is stained glass with heavy lead lines, no text and faceless figures. Design §6 overrides the earlier centred-subject recipe.

Each card has a new generated complete backdrop and separate generated ground and front plates. Subjects are generated as complete isolated objects on a flat magenta key, then cut inside their dark lead boundary and despilled. The build resamples premultiplied float colour before returning straight alpha. It zeros RGB in fully transparent pixels. A visible neutral flat is a recomposition of the layers, never the source from which a hidden backdrop is reconstructed.

All layer canvases are 2304 × 1546. The crop is 2048 × 1374 at (128, 86). World sources are normally 1536 × 1024, so they are upscaled about 1.5 times. Texture is consequently soft at full size. No native-2048 generation claim is made. Contact shadows follow actual lower contours, rather than reusing the previous oval shadow.

The guard waits while the engine's one-minute load exceeds 50. The owner's mid-lane ruling makes 100 GiB a soft floor and 50 GiB the hard stop. Every generation logs the free space, load, start, duration and result. Generation is strictly sequential. Frames stream to ffmpeg; no full-size frame sequence is stored. Each temporary MP4 and GIF is decoded and validated before final replacement.

The GIF encoder gives small saturated focal colours deliberate representation in its palette. A first Banked Fire encode lost the amber fissure in an otherwise grey palette; this was found by inspecting decoded frames and corrected. The delivered GIF is the corrected version. Preview labels and outside-art proof captions are in UK English. Artwork contains no captions.

## Inspection

### Banked Fire A

Inspected the generated back, ground, front, subject and ash ribbon, the full-resolution recomposite, alpha proof over checkerboard and green, all three lean endpoints and six decoded GIF frames. The stone and ember mass stay on the support and their contact slide measures 0 px. No magenta fringe or exposed object cut was observed. The warm fissure survives the corrected GIF. The blunt stone is on the right and the ember mass is left of centre, with no face, inscription or flame tongue. Refinement call 27 added a hard diagonal grey ash ribbon behind the stone; the distant sky is darkened to × 0.62. Remaining §6 partials: the shattered pillar stands far right, not at the stone's base, and the ember mass is nearly the stone's size, so it reads as an ember rock more than one coal. The ground reads as coarse glass strata, not loose ash.

### Silvering A

Inspected all six sources, placed geometry, the full-resolution flat, alpha proof, three lean endpoints, contact crops and six decoded GIF frames. The back-facing walker lowers its blade; the faceless reflected figure raises its blade with one thin crimson line. The tall arch and right-hand open space remain clear. The feet and mirror frame stay grounded with 0 px slide. No visible key fringe, missing world patch or detached attachment was observed. The reflected body is smaller than the real walker; this is a deliberate perspective read, not a second full-scale foreground person. At 64 px the arch carries the read; the exact blade pose is a larger-view detail.

### The Unbroken Flame A

Inspected sources, placed geometry, flat, alpha proof, contact proof, lean frames and decoded GIF frames. The shelf is lowered 250 px so the lantern feet stand on its top face; contact uses the feet only (40 px band). Slide 0 px. The claret surround is darkened to × 0.55 so the lantern leads at 64 px. First converge pass faded the panes to a black chamber at lean +1; this read as the light going out. Fixed: an amber-to-white chamber light under the panes, and the panes tint to white-gold and thin out as they slide inward. The MP4 frame at +1 shows six warm white-gold lobes round the flame. The 128-colour GIF shows the same frame as cream.

### Unbowed A

Inspected sources, geometry, flat, alpha proof, lean frames and GIF frames. The ground is lowered 240 px so its far edge meets the back's ember horizon at every lean; the figure is enlarged to tower above that horizon. Back and front tilt 2.5°; the figure and road do not. Slide 0 px, no hole at ±1. A first preview failed because OpenCV rejects a numpy pivot; the pivot is now plain floats.

### The Known Road A

Measured the road tip (1210, 892) and the door opening before the build, then centred the door on the tip and fitted the leaf inside the frame, so the gold frame strip stays fixed. Ground shear from +4 at the horizon to +90 at the near edge; slide 0 px through the row transform. Added a soft pale-gold halo round the door and larger pale-gold prints with their own glow, so the 64 px read is converging lines to a glowing arch. The prints read as round prints, not clear foot shapes (§6 partial).

### Clean Break A

Measured the bench top (y 284) and the pane corners. The pane is now separated from the blade by connected components, not a guessed polygon. Only the pane locks to the bench; the blade has lifted. The upper half sits 3 px off the cut, so the bench shows through. Two passes made the seam light invisible on the white pane at 64 px. Fixed: pane tinted pale ice (× 0.74/0.82/0.93), a broad blurred white-blue band with a white core, straightedge darkened to × 0.55. The 64 px read is now one bright diagonal across a white quadrilateral. The blade has no handle and may read as a shard (§6 partial).

## Final acceptance

All six pass `validate.py`; numbers are in `acceptance.json` and `LOOKS.md`. Contact slide 0 px on all six, spill 0, MP4 and GIF limits met, travel ≤ 123 px including rotation, lag, shard slide and road shear. The 18 world source files and 18 built world layers are unique by SHA-256; 33 earlier-round sources were compared with 0 matches. 27 of 30 generation calls used. The full-size `set-overview.jpg` and the native 64 px strip `set-small.png` were inspected directly.

## Handoff limitations

Every motion preview is labelled **offline approximation, not the shader**. Lean drives depth, focal sheen and card effects. Time drives sparse particles and the Silvering lag. No shader integration, A12 sampler compliance, frame-time, device or live-game claim is made. The M0 frame is not rendered here. `ENGINE-NOTES.md` names the unresolved two-sampler/no-added-pass contract and the two engine options without selecting one.
