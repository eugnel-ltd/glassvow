extends RefCounted
## `RoomWarm` (presentation/ui/room_warm.gd) draws the rooms' glyphs a few a
## frame, never all at once: each new glyph sends its whole font page to the
## GPU again, and one frame of every page cost the iPad 8 30 to 270 ms and 53
## to 92 MiB of upload staging it never gave back. With no budget it draws one
## glyph a frame; it draws none while the title is not resting, whatever asks
## it to redraw; and once the last glyph is drawn it frees itself.

const FRAMES_CAP: int = 400


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_room_warm: %s" % what)


static func _room() -> Control:
	var room: Control = Control.new()
	var title: Label = Label.new()
	title.text = "Settings"
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
