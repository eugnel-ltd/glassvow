class_name CardBacks
extends RefCounted
## The one presentation helper for card backs (issue #657): which back the
## player wears, how to build it, and its bake.
##
## CHOOSING. The choice is a preference (`Preferences.card_back`, the
## `[cosmetics]` section of settings.cfg) and is never trusted: `chosen()`
## resolves an unknown or still-locked id to the catalogue's default, so a
## hand-edited settings file, a back retired from the catalogue or a choice
## carried over from another profile can only ever show the default. Nothing
## here reads or writes RunState, the seeded RNG, a fixture or a save; the
## unlocks are reads of the Vigil (CardBackCatalogue).
##
## BAKING. Everything that shows a back many times over — the piles, the
## reshuffle stream, the picture turn, the slab's back plate — is meant to draw
## one baked texture rather than a live card: a live card holds about 16 MB of
## video memory, a bake about 2 MB at the 2x oversample. `bake()` builds the
## back through the CardView back path under a host, lets it render and reads
## both passes back once. Then it retires the card (CardView.retire): hidden,
## frozen and drawn no more, it leaves with its host. Freed on the spot, its
## video memory would be released two frames later, inside whatever plays
## then: on the iPad 8 that frame of a fight's entrance ran 50 ms in 3 of 7
## runs, against 16-26 ms in every run that released nothing there. Kept, it
## goes with the fight's own teardown.
##
## WHAT A BAKE COSTS (tools/check_card_back_bake.gd, on the Mac and, through a
## QA build, on the iPad 8). The first bake of a back compiles its shaders on
## the main thread, inside the draw: that one frame runs long, and the frame
## wait cannot spread it. On the iPad 8 straight after an install, the
## session's first bake (Vault, the first card the session built) held one
## frame for 3.7 s, Rose's 0.58 s and Eclipse's 0.47 s; on the M1 Max a
## first-ever bake took 290-384 ms. The engine's shader cache keeps those
## compiles across launches, but even warm an iPad 8 bake holds a frame for
## 33-58 ms (wall 77-118 ms; the Mac 3-7 ms and 11-39 ms). A cached repeat
## costs 0.03 ms. The session's first bake also holds about 10 MiB more video
## memory than later ones on both. Since #657 PR 3 a back's slab carries no
## stone (CardView), so its lit, invisible material no longer compiles: on the
## iPad 8 from a cold cache, Vault's first bake in a fight then held a 43-62 ms
## frame where it had held 8.3-9.6 s. So the game bakes the chosen back once, at
## a still moment where a long frame shows nothing moving (a load, a held
## title), never behind an animated transition and never mid-fight; every
## later screen reads the cache, which lasts the session.
##
## THE CACHE holds one bake per back, at the oversample it was made at (a bake
## at another oversample is a miss). It is dropped whole when the catalogue
## changes (`use_catalogue`). Choosing a back (`choose`) drops every other
## back's bake, including one still in flight: that one is handed to whoever
## asked for it and never kept. So straight after a choice the cache holds the
## chosen back at most, and afterwards whatever is baked from then on.

## Frames drawn before the readback: one. That draw renders both passes (the
## face viewport is drawn before the stage that samples it), and a first-use
## shader compile does not need a frame of its own: it stalls the draw it
## happens in. One frame is what lets a fight's load bake its back inside the
## frame that builds it (CardTurn.prewarm): the readback lands straight after
## that frame's draw, before the next frame begins.
const BAKE_FRAMES: int = 1

static var _catalogue: CardBackCatalogue = null
static var _bakes: Dictionary = {}     # back id -> Baked
static var _jobs: Dictionary = {}      # back id -> _Job, a bake in flight
## The render step, when swapped (`use_renderer`); empty means the live one.
static var _renderer: Callable = Callable()


## One back, baked.
class Baked:
	extends RefCounted
	## The lit back as the card stage renders it — (card + 2 * PAD_3D) at the
	## oversample, the card centred PAD_3D in — mipmapped for small canvas draws.
	## Its edge colour is premultiplied by coverage (the stage clears to
	## transparent black and resolves MSAA), so a small draw wants
	## CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA: under the canvas's default
	## straight blend the rim darkens as the mips average it, by about 19 of
	## 255 levels on average at 1/4 scale (tools/check_card_back_bake.gd, EDGE).
	## At 1:1 the default blend matches the live card, which draws it so.
	var stage: Texture2D
	## The back's 2D face — (card + 2 * PAD_IN) at the oversample — the texture
	## a slab's back plate samples through card_surface.gdshader.
	var inner: Texture2D
	## The back card's own face material over `inner`: what the live turn's
	## back plate wears (CardTurn.plate), so the plate is that card's face,
	## finish and all.
	var plate: ShaderMaterial
	## The oversample the card was BUILT at, which is what its pixels are.
	var oversample: float = 0.0


## A bake in flight. Every caller of one back shares it and gets its result.
class _Job:
	extends RefCounted
	signal done
	var result: Baked = null
	## Whether the result goes into the cache. `choose` clears it for every
	## back but the chosen one.
	var keep: bool = true


## The catalogue every call here reads: the shipped file unless swapped.
static func catalogue() -> CardBackCatalogue:
	if _catalogue == null:
		_catalogue = CardBackCatalogue.shipped()
	return _catalogue


## Swap the catalogue (a content reload, or a test's own; null returns to the
## shipped file) and drop every bake made from the old one. A bake still in
## flight is stale when it lands and is handed to nobody.
static func use_catalogue(next: CardBackCatalogue) -> void:
	_catalogue = next
	_bakes.clear()
	_jobs.clear()


## Swap the render step a bake runs: `func(host: Node, id: String,
## scale: float) -> Baked`, a coroutine. An empty Callable returns to the live
## one. The suite swaps in its own, because a headless run never draws a frame.
static func use_renderer(next: Callable) -> void:
	_renderer = next


## The back the table wears: the player's choice when the catalogue knows it
## and `vigil` has earned it, else the default. A null `vigil` is a blank one.
static func chosen(prefs: Preferences, vigil: VigilState) -> String:
	var cat: CardBackCatalogue = catalogue()
	var want: String = prefs.card_back if prefs != null else ""
	return want if cat.is_unlocked(want, vigil) else cat.default_id


## Record the player's choice and keep only its bake. An id the catalogue does
## not know is refused; a locked one is stored and shows the default until it
## is earned (the shelf offers only earned backs).
static func choose(prefs: Preferences, id: String) -> void:
	if not catalogue().has(id):
		push_warning("card backs: no such back '%s'" % id)
		return
	prefs.set_card_back(id)
	for key: Variant in _bakes.keys():
		if str(key) != id:
			_bakes.erase(key)
	for key: Variant in _jobs:
		if str(key) != id:
			var job: _Job = _jobs[key]
			job.keep = false


## A live back, as the card lab stands one up. Everything that needs many
## wants `bake()` instead.
static func build(id: String, uid: int = 0) -> CardView:
	var known: String = _known(id)
	return CardView.new(CardInst.new(uid, StringName("back:" + known)),
		catalogue().card_data(known), 0)


## The bake of `id` at the current oversample, or null when there is none.
static func cached(id: String) -> Baked:
	var hit: Baked = _bakes.get(id)
	if hit == null or not is_equal_approx(hit.oversample, CardView.oversample):
		return null
	return hit


## Bake `id` under `host` (any node in the tree; the card is built hidden and
## leaves with it), or hand back the cached bake. A coroutine: `await` it.
##
## Every caller of one back shares the bake in flight and gets its result. A
## bake that is stale when it lands (the catalogue or the oversample changed
## under it) goes to nobody, and a bake whose host left gives nothing; either
## way each caller whose own host is still here tries once more with it.
## Returns null when there is still no bake: `host` is gone, out of the tree or
## leaves it, the run is headless, or the second try was interrupted too.
static func bake(host: Node, id: String) -> Baked:
	var out: Baked = await _try(host, id)
	if out == null and is_instance_valid(host):
		out = await _try(host, id)
	return out


## One try: the cached bake, a share of the bake in flight, or a new bake.
static func _try(host: Node, id: String) -> Baked:
	var known: String = _known(id)
	var hit: Baked = cached(known)
	if hit != null:
		return hit
	var running: _Job = _jobs.get(known)
	if running != null:
		await running.done
		return running.result
	var job: _Job = _Job.new()
	_jobs[known] = job
	var made_from: CardBackCatalogue = catalogue()
	# The card reads the oversample when it is built, which is now: a value set
	# later cannot reach its pixels, so it makes the bake stale instead.
	var scale: float = CardView.oversample
	var render: Callable = _renderer if _renderer.is_valid() else _render_live
	var out: Baked = await render.call(host, known, scale)
	if made_from != _catalogue or not is_equal_approx(scale, CardView.oversample):
		out = null
	if out != null and job.keep:
		_bakes[known] = out
	job.result = out
	if _jobs.get(known) == job:
		_jobs.erase(known)
	job.done.emit()
	return out


## The live render step: the back built hidden under `host`, rendered, read
## back once and retired there. Null when it cannot render: a headless run
## never draws a frame (the wait would never end), and a host out of the tree
## draws nothing.
static func _render_live(host: Node, id: String, scale: float) -> Baked:
	if DisplayServer.get_name() == "headless" or not host.is_inside_tree():
		return null
	var view: CardView = build(id)
	# Hidden, not parked off-screen: the card's own viewports render regardless,
	# and a hidden card draws nothing on the host's canvas.
	view.visible = false
	host.add_child(view)
	for _i: int in range(BAKE_FRAMES):
		await RenderingServer.frame_post_draw
	if not is_instance_valid(view):
		return null    # its host was freed, and the card with it
	var out: Baked = _read_back(view, scale) if view.is_inside_tree() else null
	if out == null:
		view.free()
	else:
		view.retire()
	return out


static func _read_back(view: CardView, scale: float) -> Baked:
	var out: Baked = Baked.new()
	var stage_img: Image = view.stage_image()
	stage_img.generate_mipmaps()
	out.stage = ImageTexture.create_from_image(stage_img)
	out.inner = ImageTexture.create_from_image(view.face_image())
	out.plate = plate_of(view, out.inner)
	out.oversample = scale
	return out


## `view`'s face material over `inner` in place of its live face: the back
## plate a bake of `view` dresses a turning card in.
static func plate_of(view: CardView, inner: Texture2D) -> ShaderMaterial:
	var plate: ShaderMaterial = view.face_material().duplicate() as ShaderMaterial
	plate.set_shader_parameter("face_tex", inner)
	return plate


## `id` when the catalogue knows it, else the default (said loudly: callers
## pass `chosen()`, which is always known).
static func _known(id: String) -> String:
	var cat: CardBackCatalogue = catalogue()
	if cat.has(id):
		return id
	push_error("card backs: no such back '%s', building the default" % id)
	return cat.default_id
