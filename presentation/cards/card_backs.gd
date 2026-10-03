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
## back through the CardView back path, lets it render, reads both passes back
## once and frees the card. The readback stalls the GPU, so callers bake behind
## a transition, never mid-fight.
##
## THE CACHE holds one bake per back, at the oversample it was made at (a bake
## at another oversample is a miss). It is dropped whole when the catalogue
## changes (`use_catalogue`), and every bake but the new choice's is dropped
## when the choice changes (`choose`), so at rest it holds the one back the
## table wears.

## Frames drawn before the readback: the face pass, the stage that samples it,
## and one spare for a first-use shader compile.
const BAKE_FRAMES: int = 3

static var _catalogue: CardBackCatalogue = null
static var _bakes: Dictionary = {}     # back id -> Baked
static var _jobs: Dictionary = {}      # back id -> _Job, a bake in flight


## One back, baked.
class Baked:
	extends RefCounted
	## The lit back as the card stage renders it — (card + 2 * PAD_3D) at the
	## oversample, the card centred PAD_3D in — mipmapped for small canvas draws.
	var stage: Texture2D
	## The back's 2D face — (card + 2 * PAD_IN) at the oversample — the texture
	## a slab's back plate samples through card_surface.gdshader.
	var inner: Texture2D
	var oversample: float = 0.0


## A bake in flight, so a second caller waits for it instead of baking twice.
class _Job:
	extends RefCounted
	signal done


## The catalogue every call here reads: the shipped file unless swapped.
static func catalogue() -> CardBackCatalogue:
	if _catalogue == null:
		_catalogue = CardBackCatalogue.shipped()
	return _catalogue


## Swap the catalogue (a content reload, or a test's own; null returns to the
## shipped file) and drop every bake made from the old one.
static func use_catalogue(next: CardBackCatalogue) -> void:
	_catalogue = next
	_bakes.clear()


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
## freed after), or hand back the cached bake. A coroutine: `await` it.
## Returns null only when `host` is not in the tree, or leaves it mid-bake.
static func bake(host: Node, id: String) -> Baked:
	var known: String = _known(id)
	var hit: Baked = cached(known)
	if hit != null:
		return hit
	if not host.is_inside_tree():
		return null
	var running: _Job = _jobs.get(known)
	if running != null:
		await running.done
		# That bake may not have landed (its host left, or the catalogue
		# changed under it); then this caller bakes for itself.
		hit = cached(known)
		return hit if hit != null else await bake(host, known)
	var job: _Job = _Job.new()
	_jobs[known] = job
	var made_from: CardBackCatalogue = catalogue()
	var view: CardView = build(known)
	# Hidden, not parked off-screen: the card's own viewports render regardless,
	# and a hidden card draws nothing on the host's canvas.
	view.visible = false
	host.add_child(view)
	for _i: int in range(BAKE_FRAMES):
		await RenderingServer.frame_post_draw
	var out: Baked = null
	if is_instance_valid(view):
		if view.is_inside_tree():
			out = _read_back(view)
			# A catalogue swapped mid-bake made this bake stale before it landed.
			if made_from == _catalogue:
				_bakes[known] = out
		view.queue_free()
	_jobs.erase(known)
	job.done.emit()
	return out


static func _read_back(view: CardView) -> Baked:
	var out: Baked = Baked.new()
	var stage_img: Image = view.stage_image()
	stage_img.generate_mipmaps()
	out.stage = ImageTexture.create_from_image(stage_img)
	out.inner = ImageTexture.create_from_image(view.face_image())
	out.oversample = CardView.oversample
	return out


## `id` when the catalogue knows it, else the default (said loudly: callers
## pass `chosen()`, which is always known).
static func _known(id: String) -> String:
	var cat: CardBackCatalogue = catalogue()
	if cat.has(id):
		return id
	push_error("card backs: no such back '%s', building the default" % id)
	return cat.default_id
