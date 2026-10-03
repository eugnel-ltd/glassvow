class_name CardFaces
extends RefCounted
## Baked card faces (issue #657): the views that show many cards at once — the
## deck overlay and every deck picker (CardGrid) — draw one baked picture per
## distinct card instead of a live CardView per card.
##
## WHY. A live card holds about 16 MB of video memory: two offscreen passes and
## a 3D stage with 4x MSAA. A face holds one picture, 0.65 MB at the game's 2x
## oversample. Before this, the deck overlay built a live card for every card in
## the deck: on the Mac that held 131 MB more for the 10-card starter deck and
## 399 MB more for 30 cards, 511 MB at the peak of the open.
##
## WHAT A FACE IS. The card's stage at rest, exactly as the live card draws it
## on the canvas, plus the two things the live card draws beside it there: its
## table shadow and, on a rare, the gilt shine. BakedCard lays all three through
## CardView's own nodes (`shadow_panel`, `picture`, `shine`), so a baked card at
## rest is the live card's pixels.
##
## HOW A FACE IS BAKED. The card is built hidden under the view that asked,
## drawn once (one draw renders both passes, the face before the stage that
## samples it), and its stage is copied on the GPU into a texture the face owns
## (RenderingDevice.texture_copy). Nothing is read back, so nothing stalls; the
## card is freed the same frame. PER_FRAME cards are baked per frame, so a view
## of N distinct cards costs N light frames rather than one long one. Without a
## RenderingDevice on this thread (the Compatibility renderer, the web build)
## the stage is read back instead, which stalls the frame it lands in.
##
## THE CACHE holds one face per distinct card — its id, upgrade, cost and
## definition, so a hydrated name or text is a different face — for one locale
## and oversample: asking in another drops every face first. It lasts until
## `forget()`, which Main calls whenever it shows the title, so a run bakes each
## card it shows once, and every later open of a view is drawn from the cache.
## Two asks for one card share one bake. A face's GPU copy is freed with the
## face, when the cache and the last card wearing it have let it go; the cache
## is also dropped as the tree shuts down, before the renderer is.

## Cards baked per frame.
const PER_FRAME: int = 1
## How far a face's picture reaches past the card, in card px: the cost gem's
## overhang (CardView.PAD_IN) and two px of clear glass beyond it, so the
## filtered edge of the crop only ever samples transparent texels. A resting
## stage holds nothing further out — over every card and upgrade in the
## catalogue its content reaches 8 px above the card, 5.5 px left of it and
## nothing past the right or bottom edge — so the rest of the PAD_3D the live
## stage keeps for its tilt is cut away: a quarter of the face's memory.
const REACH: float = CardView.PAD_IN + 2.0
## How many times one card's bake is tried before its askers are given up on.
const TRIES: int = 2

static var _faces: Dictionary = {}     # key -> Face
static var _jobs: Dictionary = {}      # key -> _Job, queued or in flight
static var _queue: Array[_Job] = []
static var _pumping: bool = false
## Bumped by `forget`: a bake asked for before it lands nowhere.
static var _era: int = 0
## The locale and oversample the cache was baked in.
static var _made_in: String = ""
static var _hooked: bool = false
## The render step, when swapped (`use_renderer`); empty means the live one.
static var _renderer: Callable = Callable()


## One card, baked.
class Face:
	extends RefCounted
	## The lit stage at rest, cropped to REACH past the card on every side (at
	## the oversample), drawn by CardView.picture as the live stage is, on the
	## same texel grid.
	var picture: Texture2D
	## The card's table shadow at rest (CardView.rest_shadow).
	var shadow: StyleBoxFlat
	## Whether the card wears the rare's gilt shine.
	var shine: bool = false
	## The GPU copy this face owns, when the picture is one.
	var _gpu: RID = RID()

	## Copy the `crop` of `stage` on `rd` into a texture this face owns, and
	## wear it.
	func copy_on_gpu(rd: RenderingDevice, stage: Texture2D, crop: Rect2i) -> void:
		var source: RID = RenderingServer.texture_get_rd_texture(stage.get_rid())
		var into: RDTextureFormat = RDTextureFormat.new()
		into.width = crop.size.x
		into.height = crop.size.y
		into.format = rd.texture_get_format(source).format
		into.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
			| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT \
			| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		_gpu = rd.texture_create(into, RDTextureView.new())
		rd.texture_copy(source, _gpu, Vector3(crop.position.x, crop.position.y, 0),
			Vector3.ZERO, Vector3(crop.size.x, crop.size.y, 1), 0, 0, 0, 0)
		var copy: Texture2DRD = Texture2DRD.new()
		copy.texture_rd_rid = _gpu
		picture = copy

	func _notification(what: int) -> void:
		if what != NOTIFICATION_PREDELETE or not _gpu.is_valid():
			return
		# The canvas's handle on the copy goes first, then the copy itself:
		# a Texture2DRD never frees the texture it was handed.
		var copy: Texture2DRD = picture as Texture2DRD
		if copy != null:
			copy.texture_rd_rid = RID()
		var rd: RenderingDevice = RenderingServer.get_rendering_device()
		if rd != null and rd.texture_is_valid(_gpu):
			rd.free_rid(_gpu)


## One card's bake, queued or in flight, and everyone waiting on it.
class _Job:
	extends RefCounted
	var key: String
	var inst: CardInst
	var definition: Dictionary
	var cost: int
	var era: int
	var tries: int = 0
	## The views that asked, and what each wants called; parallel arrays.
	var askers: Array = []
	var landed: Array[Callable] = []

	## The first asker still here, under which the card is built; else null.
	## One out of the tree gets a card that never draws, so nothing.
	func host() -> Node:
		for asker: Variant in askers:
			if is_instance_valid(asker):
				return asker
		return null


## The face of a card: the same card, upgrade, cost and definition share one.
static func key_of(inst: CardInst, definition: Dictionary, cost: int) -> String:
	return "%s%s|%d|%d" % [inst.id, "+" if inst.up else "", cost, definition.hash()]


## The part of a stage render of `size` texels a face keeps: REACH past the
## card on every side, on the stage's own texel grid.
static func crop_of(size: Vector2i) -> Rect2i:
	var inset: int = roundi((CardView.PAD_3D - REACH) * CardView.oversample)
	return Rect2i(Vector2i(inset, inset), size - Vector2i(inset, inset) * 2)


## The baked face of this card, or null while there is none.
static func cached(inst: CardInst, definition: Dictionary, cost: int) -> Face:
	_check_made_in()
	return _faces.get(key_of(inst, definition, cost))


## Ask for the face of a card. `landed` is called with it once it is baked —
## at once when it is cached — and never when `asker` has left first or the
## card cannot be baked (a headless run never draws).
static func request(asker: Node, inst: CardInst, definition: Dictionary, cost: int,
		landed: Callable) -> void:
	_check_made_in()
	var key: String = key_of(inst, definition, cost)
	var hit: Face = _faces.get(key)
	if hit != null:
		landed.call(hit)
		return
	if not _hooked and asker.is_inside_tree():
		# The cache is static and would outlive the renderer at exit, leaking
		# every GPU copy it holds; the root leaves the tree before that.
		asker.get_tree().root.tree_exiting.connect(func() -> void: forget(),
			CONNECT_ONE_SHOT)
		_hooked = true
	var job: _Job = _jobs.get(key)
	if job == null:
		job = _Job.new()
		job.key = key
		job.inst = inst
		job.definition = definition
		job.cost = cost
		job.era = _era
		_jobs[key] = job
		_queue.append(job)
	job.askers.append(asker)
	job.landed.append(landed)
	if not _pumping:
		_pump()


## Drop every face and every bake not yet landed. Faces still worn by a card
## stay with it until it goes.
static func forget() -> void:
	_era += 1
	_faces.clear()
	_jobs.clear()
	_queue.clear()


## How many faces the cache holds.
static func count() -> int:
	return _faces.size()


## Swap the render step: `func(jobs: Array[_Job]) -> Array` of a Face or null
## per job, in order; a coroutine. An empty Callable returns to the live one.
## The suite swaps in its own, because a headless run never draws a frame.
static func use_renderer(next: Callable) -> void:
	_renderer = next


## A bake is good for one locale and one oversample: asking in another drops
## the cache first.
static func _check_made_in() -> void:
	var now: String = "%s@%s" % [Locale.active.code, CardView.oversample]
	if now != _made_in:
		forget()
		_made_in = now


static func _pump() -> void:
	_pumping = true
	while not _queue.is_empty():
		var batch: Array[_Job] = []
		while batch.size() < PER_FRAME and not _queue.is_empty():
			var next: _Job = _queue.pop_front()
			if next.host() != null:
				batch.append(next)
			elif _jobs.get(next.key) == next:
				_jobs.erase(next.key)
		if batch.is_empty():
			continue
		var render: Callable = _renderer if _renderer.is_valid() else _render_live
		var made: Array = await render.call(batch)
		for i: int in range(batch.size()):
			var face: Face = made[i] if i < made.size() else null
			_land(batch[i], face)
	_pumping = false


static func _land(job: _Job, face: Face) -> void:
	job.tries += 1
	if job.era != _era:
		return    # forgotten while it baked: it goes to nobody
	if face == null:
		# The card that was building it left with its view; anyone else still
		# asking gets another go, at the front of the queue.
		if job.tries < TRIES and job.host() != null:
			_queue.push_front(job)
		elif _jobs.get(job.key) == job:
			_jobs.erase(job.key)
		return
	if _jobs.get(job.key) == job:
		_jobs.erase(job.key)
	_faces[job.key] = face
	for i: int in range(job.askers.size()):
		if is_instance_valid(job.askers[i]) and job.landed[i].is_valid():
			job.landed[i].call(face)


## The live render step: each card built hidden under its host, drawn once,
## kept and freed. All null in a headless run, which never draws a frame.
static func _render_live(batch: Array[_Job]) -> Array:
	var out: Array = []
	out.resize(batch.size())
	if DisplayServer.get_name() == "headless":
		return out
	var views: Array = []
	for job: _Job in batch:
		var view: CardView = CardView.new(job.inst, job.definition, job.cost)
		# Hidden, not parked off-screen: its viewports render regardless, and a
		# hidden card draws nothing on the view that hosts it.
		view.visible = false
		job.host().add_child(view)
		views.append(view)
	await RenderingServer.frame_post_draw
	for i: int in range(views.size()):
		if not is_instance_valid(views[i]):
			continue    # its host was freed, and the card with it
		var view: CardView = views[i]
		if view.is_inside_tree():
			out[i] = _keep(view)
		view.queue_free()
	return out


static func _keep(view: CardView) -> Face:
	var face: Face = Face.new()
	face.shadow = view.rest_shadow()
	face.shine = view.has_shine()
	var stage: Texture2D = view.stage_texture()
	var crop: Rect2i = crop_of(Vector2i(stage.get_width(), stage.get_height()))
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	if rd != null and RenderingServer.is_on_render_thread():
		face.copy_on_gpu(rd, stage, crop)
	else:
		face.picture = ImageTexture.create_from_image(view.stage_image().get_region(crop))
	return face
