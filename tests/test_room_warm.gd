extends RefCounted
## `RoomWarm` (presentation/ui/room_warm.gd) draws the rooms' glyphs a few a
## frame, never all at once: each new glyph sends its whole font page to the
## GPU again, and one frame of every page cost the iPad 8 30 to 270 ms and 53
## to 92 MiB of upload staging it never gave back. With no budget it draws one
## glyph a frame; it draws none while the title is not resting, whatever asks
## it to redraw; and once the last glyph is drawn it frees itself.
##
## Every builder is given up front (#675's follow-up for #655 PR C): a builder
## whose room is not ready yet (the Vigil's art still loading) is asked again
## on a later frame, the builders after it wait, nothing is shaped until the
## last has built, and every room's text is then warmed. A pipeline sample is
## drawn at an alpha the renderer draws: Godot skips a canvas item whose
## modulate's alpha is under 0.007, so at 0.004 the sample built nothing.

const FRAMES_CAP: int = 400


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_room_warm: %s" % what)


static func _room(text: String = "Settings") -> Control:
	var room: Control = Control.new()
	var title: Label = Label.new()
	title.text = text
	room.add_child(title)
	var back: Button = Button.new()
	back.text = "Return"
	room.add_child(back)
	return room


static func run(fails: Array[String]) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var resting: Array[bool] = [false]
	var builders: Array[Callable] = [func() -> Control: return _room()]
	var warm: RoomWarm = RoomWarm.new(builders, func() -> bool: return resting[0])
	warm.budget_us = 0
	var held: WeakRef = weakref(warm)
	tree.root.add_child(warm)

	for i: int in 3:
		await tree.process_frame
	_check(fails, warm._builders.size() == 1, "a room was built while the title was not resting")

	resting[0] = true
	warm._rested = RoomWarm.REST
	var frames: int = 0
	while not warm._jobs.is_empty() or not warm._builders.is_empty():
		await tree.process_frame
		frames += 1
		if frames > FRAMES_CAP:
			break
	var glyphs: int = warm._glyphs.size()
	_check(fails, glyphs > 0, "the room's text gave no glyphs to draw")

	await tree.process_frame
	await tree.process_frame
	var drawn: int = warm._next_glyph
	_check(fails, drawn >= 1 and drawn < glyphs,
		"with no budget, %d of %d glyphs were drawn in two frames" % [drawn, glyphs])

	resting[0] = false
	for i: int in 3:
		warm.queue_redraw()
		await tree.process_frame
	_check(fails, warm._next_glyph == drawn,
		"%d glyphs were drawn while the title was not resting" % (warm._next_glyph - drawn))

	resting[0] = true
	warm._rested = RoomWarm.REST
	var most: int = 0
	frames = 0
	while held.get_ref() != null and frames <= FRAMES_CAP:
		var before: int = warm._next_glyph
		await tree.process_frame
		frames += 1
		if held.get_ref() != null:
			most = maxi(most, warm._next_glyph - before)
	_check(fails, held.get_ref() == null, "the warm did not free itself after its last glyph")
	_check(fails, most <= 1, "with no budget, %d glyphs were drawn in one frame" % most)
	await _late_builder(fails, tree)
	await _sample_drawn(fails, tree)


## A builder not ready yet holds the queue and is asked again; once it builds,
## the rooms after it build, and only then is every room's text shaped.
static func _late_builder(fails: Array[String], tree: SceneTree) -> void:
	var asked: Array[int] = [0]
	var ready: Array[bool] = [false]
	var builders: Array[Callable] = [
		func() -> Control:
			asked[0] += 1
			return _room("Vigil") if ready[0] else null,
		func() -> Control: return _room("Quaff"),
	]
	var warm: RoomWarm = RoomWarm.new(builders, func() -> bool: return true)
	warm.budget_us = 0
	warm._rested = RoomWarm.REST
	var held: WeakRef = weakref(warm)
	tree.root.add_child(warm)
	for i: int in 4:
		await tree.process_frame
	_check(fails, asked[0] >= 3, "a builder that was not ready was asked %d times in four frames" % asked[0])
	_check(fails, warm._builders.size() == 2 and warm._jobs.is_empty() and warm._glyphs.is_empty(),
		"a room was built or shaped past a builder that was not ready")
	ready[0] = true
	var frames: int = 0
	while not warm._builders.is_empty() and frames <= FRAMES_CAP:
		await tree.process_frame
		frames += 1
	var codes: Dictionary = {}
	for glyph: Array in warm._glyphs:
		codes[glyph[2]] = true
	for c: String in ["V", "Q"]:
		_check(fails, codes.has(c.unicode_at(0)), "the text of a room built %s was never warmed" % (
			"late" if c == "V" else "after the late one"))
	if held.get_ref() != null:
		warm.queue_free()


## The hall's pipeline sample goes under everything at an alpha the renderer
## still draws, for one frame, and then the warm frees itself.
static func _sample_drawn(fails: Array[String], tree: SceneTree) -> void:
	var made: Array[Control] = []
	var pipelines: Array[Callable] = [func() -> Control:
		var sample: Control = Control.new()
		made.append(sample)
		return sample]
	var none: Array[Callable] = []
	var warm: RoomWarm = RoomWarm.new(none, func() -> bool: return true, pipelines)
	warm._rested = RoomWarm.REST
	var held: WeakRef = weakref(warm)
	tree.root.add_child(warm)
	var frames: int = 0
	while made.is_empty() and frames <= FRAMES_CAP:
		await tree.process_frame
		frames += 1
	_check(fails, not made.is_empty() and made[0].get_parent() == warm
			and made[0].modulate.a >= 0.007 and RoomWarm.SAMPLE_ALPHA >= 0.007,
		"the pipeline sample is drawn at an alpha the renderer skips (%.3f)" % RoomWarm.SAMPLE_ALPHA)
	frames = 0
	while held.get_ref() != null and frames <= FRAMES_CAP:
		await tree.process_frame
		frames += 1
	_check(fails, held.get_ref() == null, "the warm did not free itself after its pipeline sample")
