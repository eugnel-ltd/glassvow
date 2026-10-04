class_name RoomWarm
extends Control
## The rooms' first opening in a launch, paid for ahead (docs/design/2026-10-03-
## title-rooms §11.6, as built). On the iPad 8 the first opening of Settings,
## How to Play or Credits in every launch ran 15 to 30 ms over every later one
## (a 37 to 55 ms tap frame), past §11.6's 33 ms: the first build of each room
## runs its scripts for the first time, and every glyph of its text at the
## sizes the room sets is rasterised into the font's pages and sent to the GPU
## as the room enters the tree. zh-Hant's hundreds of glyphs cost the most.
##
## Once the title has rested a moment (`rests`), this does that work a slice a
## frame, never as a room opens: each room is built once off the tree, never
## shown, and freed; its text is shaped at the sizes it sets it, a few strings
## at a time within a budget a frame; and its glyphs are drawn, near-invisibly
## under everything, a few a frame within the same budget, so the screen's
## oversampled glyphs and their font pages are on the GPU before the tap. Then
## it frees itself. While a room is open or a passage runs, it waits.
##
## The drawing is paced because every new glyph sends its whole font page to
## the GPU again. Drawing every page in one frame cost 30 ms (en) to 270 ms
## (zh-Hant) of that frame and 50 to 80 ms of the next on the iPad 8, and grew
## the upload staging buffer, which is never given back, by 53 to 92 MiB.
##
## Last, any first-use pipelines a room's drawing needs (the Vigil's hall) are
## drawn once the same way: a sample of it under everything for one frame.

## How long the title rests before the work starts, and the work a frame.
const REST: float = 0.8
const BUDGET_US: int = 1500
## Glyphs shaped a call.
const CHUNK: int = 24

## The work a frame. At least one string is shaped, or one glyph drawn, a frame
## however small it is (a test sets 0 to see one a frame).
var budget_us: int = BUDGET_US

## True once the title rests (no room, no passage, no rite).
var rests: Callable = Callable()
var _builders: Array[Callable] = []
var _rested: float = 0.0
## (font, px) → the characters the rooms set in it.
var _sets: Dictionary = {}
## [font, px, text] still to shape.
var _jobs: Array[Array] = []
## [font, px, codepoint] in the rooms' order, and the next to draw.
var _glyphs: Array[Array] = []
var _next_glyph: int = 0
## Set by a resting frame that wants glyphs drawn, so nothing else's redraw
## (entering the tree, a visibility change) draws them mid-passage.
var _draw_due: bool = false
## Each makes a sample to draw once, near-invisibly, for its pipelines.
var _pipelines: Array[Callable] = []
var _sample: Control = null


## `builders`: each makes one room, whole (every page, the roll's end), off
## the tree, or null when what it needs is not ready yet (the Vigil's art,
## still loading on a worker): it is asked again on a later frame, so no
## frame of the warm waits on a load, and the builders after it wait their
## turn. Every builder is given here, up front: the rooms' text is shaped once
## the last of them has built (`_queue_jobs`), so a builder cannot join later.
func _init(builders: Array[Callable], title_rests: Callable,
		pipelines: Array[Callable] = []) -> void:
	name = "RoomWarm"
	_builders = builders
	_pipelines = pipelines
	rests = title_rests
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Under everything: the frames that draw the glyphs are hidden by the road.
	z_index = -100


func done() -> bool:
	return _builders.is_empty() and _jobs.is_empty() and _next_glyph >= _glyphs.size() \
		and _pipelines.is_empty() and _sample == null


func _process(delta: float) -> void:
	var resting: bool = rests.call() if rests.is_valid() else true
	if not resting:
		_rested = 0.0
		if _sample != null:
			_sample.queue_free()
			_sample = null
		return
	_rested += delta
	if _rested < REST:
		return
	if not _builders.is_empty():
		var room: Control = _builders.front().call()
		if room == null:
			return
		_builders.pop_front()
		_collect(room)
		if _builders.is_empty():
			_queue_jobs()
		return
	if not _jobs.is_empty():
		var until: int = Time.get_ticks_usec() + budget_us
		while not _jobs.is_empty():
			var job: Array = _jobs.pop_back()
			var font: Font = job[0]
			var px: int = job[1]
			var text: String = job[2]
			font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
			if Time.get_ticks_usec() >= until:
				break
		return
	if _next_glyph < _glyphs.size():
		_draw_due = true
		queue_redraw()
		return
	if _sample != null:
		_sample.queue_free()
		_sample = null
	if not _pipelines.is_empty():
		_sample = _pipelines.front().call()
		if _sample != null:
			_pipelines.pop_front()
			_sample.modulate.a = 0.004
			add_child(_sample)
		return
	queue_free()


## Every face and size the room's text is set in, and the characters set in it.
func _collect(room: Control) -> void:
	if room == null:
		return
	var nodes: Array[Node] = room.find_children("*", "Control", true, false)
	for node: Node in nodes:
		if node is RichTextLabel:
			var prose: RichTextLabel = node
			_add(prose.get_theme_font("normal_font"), prose.get_theme_font_size("normal_font_size"),
				_plain(prose.text))
			_add(prose.get_theme_font("bold_font"), prose.get_theme_font_size("bold_font_size"),
				_plain(prose.text))
		elif node is Label:
			var label: Label = node
			_add(label.get_theme_font("font"), label.get_theme_font_size("font_size"), label.text)
		elif node is Button:
			var button: Button = node
			_add(button.get_theme_font("font"), button.get_theme_font_size("font_size"), button.text)
	room.free()


func _add(font: Font, px: int, text: String) -> void:
	if font == null or px <= 0 or text.is_empty():
		return
	var key: String = "%d|%d" % [font.get_instance_id(), px]
	if not _sets.has(key):
		_sets[key] = [font, px, {}]
	var chars: Dictionary = _sets[key][2]
	for c: String in text:
		chars[c] = true


func _queue_jobs() -> void:
	for key: String in _sets:
		var entry: Array = _sets[key]
		var chars: Dictionary = entry[2]
		var all: PackedStringArray = PackedStringArray(chars.keys())
		for at: int in range(0, all.size(), CHUNK):
			_jobs.append([entry[0], entry[1], "".join(all.slice(at, at + CHUNK))])
		for c: String in all:
			_glyphs.append([entry[0], entry[1], c.unicode_at(0)])


## BBCode tags out, so only the text's own characters are shaped.
static func _plain(markup: String) -> String:
	var tags: RegEx = RegEx.create_from_string("\\[[^\\]]*\\]")
	return tags.sub(markup, "", true)


## The next glyphs within the budget, at a level no screen shows, side by side
## so they never stack. Drawn here, the viewport's oversampling applies, so
## each glyph is rasterised at the size the screen draws it.
func _draw() -> void:
	if not _draw_due:
		return
	_draw_due = false
	var until: int = Time.get_ticks_usec() + budget_us
	var x: float = 2.0
	while _next_glyph < _glyphs.size():
		var glyph: Array = _glyphs[_next_glyph]
		_next_glyph += 1
		var font: Font = glyph[0]
		var px: int = glyph[1]
		var code: int = glyph[2]
		x += font.draw_char(get_canvas_item(), Vector2(x, float(px) + 2.0), code, px,
			Color(1.0, 1.0, 1.0, 0.004))
		if Time.get_ticks_usec() >= until:
			break
