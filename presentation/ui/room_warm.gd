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
## shown, and freed; the glyphs its text uses are rasterised at the sizes it
## sets them, a few at a time within a budget a frame; and each font page is
## drawn once, near-invisibly under everything, so the GPU has it before the
## tap. Then it frees itself. While a room is open or a passage runs, it waits.

## How long the title rests before the work starts, and the glyph work a frame.
const REST: float = 0.8
const BUDGET_US: int = 1500
## Glyphs shaped a call.
const CHUNK: int = 24

## True once the title rests (no room, no passage, no rite).
var rests: Callable = Callable()
var _builders: Array[Callable] = []
var _rested: float = 0.0
## (font, px) → the characters the rooms set in it.
var _sets: Dictionary = {}
## [font, px, text] still to shape.
var _jobs: Array[Array] = []
var _drawn: bool = false


## `builders`: each makes one room, whole (every page, the roll's end), off
## the tree.
func _init(builders: Array[Callable], title_rests: Callable) -> void:
	name = "RoomWarm"
	_builders = builders
	rests = title_rests
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Under everything: the one frame that draws the pages is hidden by the road.
	z_index = -100


func done() -> bool:
	return _builders.is_empty() and _jobs.is_empty() and _drawn


func _process(delta: float) -> void:
	var resting: bool = rests.call() if rests.is_valid() else true
	if not resting:
		_rested = 0.0
		return
	_rested += delta
	if _rested < REST:
		return
	if not _builders.is_empty():
		var room: Control = _builders.pop_front().call()
		_collect(room)
		if _builders.is_empty():
			_queue_jobs()
		return
	if not _jobs.is_empty():
		var until: int = Time.get_ticks_usec() + BUDGET_US
		while not _jobs.is_empty() and Time.get_ticks_usec() < until:
			var job: Array = _jobs.pop_back()
			var font: Font = job[0]
			var px: int = job[1]
			var text: String = job[2]
			font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		return
	if not _drawn:
		_drawn = true
		queue_redraw()
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


## BBCode tags out, so only the text's own characters are shaped.
static func _plain(markup: String) -> String:
	var tags: RegEx = RegEx.create_from_string("\\[[^\\]]*\\]")
	return tags.sub(markup, "", true)


## Each page drawn once, at a level no screen shows, so the GPU has it.
func _draw() -> void:
	if not _drawn:
		return
	for key: String in _sets:
		var entry: Array = _sets[key]
		var font: Font = entry[0]
		var px: int = entry[1]
		var chars: Dictionary = entry[2]
		font.draw_string(get_canvas_item(), Vector2(2.0, float(px) + 2.0),
			"".join(PackedStringArray(chars.keys())), HORIZONTAL_ALIGNMENT_LEFT, -1, px,
			Color(1.0, 1.0, 1.0, 0.004))
