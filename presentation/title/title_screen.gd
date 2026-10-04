class_name TitleScreen
extends Control
## The title is a place, not a menu (docs/design/2026-10-02-opening-start,
## Concept A "Held Light"). First person on the road at dusk: the wordmark, the
## sealed door with its Emberglass rose, the name plaque, and the hero's lantern
## in the foreground. The lantern is the primary action; the other routes are
## quiet words in its light, three to a side. The player's history is in the
## picture: the saved run's flame, the shards in the rose, the deeds carved in
## the road. Main keeps every route id and behaviour; this screen only emits.
##
## The launch rite (TitleKindling) plays on the first title of a session; any
## tap completes it and chooses nothing. First launch holds the rite at the
## ember for the language (two glass panes) and shows the one consent line.

signal chosen(id: String)
signal language_chosen(code: StringName)
## A tap while the title is leaving: hurry the transition carrying it away.
signal hurry

const TITLE_BACKGROUND: String = "res://assets/art/title-background/background.png"
const WORDMARK_EN: String = "res://assets/art/title/title.png"
const WORDMARK_ZH: String = "res://assets/art/title/title-zh.png"
const BANNER_ALPHA: float = 0.35
## The painting's own rose window (painting px) and its radius: the Emberglass
## rose is set into the door the player can see.
const ROSE_ART: Vector3 = Vector3(775.0, 375.0, 47.0)
const LEFT_IDS: Array[String] = ["begin", "vigil", "help"]
## How far the lantern's reach runs past the plaque's words (x each side, y above).
const REACH_PAD: Vector2 = Vector2(18.0, 10.0)
const RIGHT_IDS: Array[String] = ["settings", "credits", "quit"]
## The rooms a word opens from the title (the Vigil as a route over the held
## title): the passage carries the lantern in and plays their sound.
const ROOM_IDS: Array[String] = ["help", "settings", "credits", "vigil"]
## The turn west to the Vigil (docs/design/2026-10-03-title-rooms §5.2, V1 and
## V3), as shares of the stage's width: the road's pan, and the slide and the
## growth of the painting, its lamps, the door's rose and the wordmark.
const TURN_PAN: float = 0.08
const TURN_SLIDE: float = 0.03
const TURN_GROW: float = 0.03


## Layout in reference units for a shape class: x is an offset from the stage
## centre, y from the top, both scaled by height / reference height.
class Layout:
	# Pad and desktop (orchestrator polish round): the lantern is the largest
	# thing on the stage, ~46% of its height, its wick still at 0.918 of the
	# height where the splash's ember is (0.918 × 820 − 0.785 × 420 = 423);
	# the wordmark sits at 8%, the rose grows 1.5×, the plaque stands on the
	# lantern's ring and the six words flank its glass.
	var ref_h: float = 820.0
	var word_y: float = 66.0
	var word_w: float = 430.0
	var plaque_y: float = 386.0
	var lantern_y: float = 423.0
	var lantern: float = 420.0
	var rose_grow: float = 1.95
	var left: Array[Vector2] = [Vector2(-182.0, 606.0), Vector2(-214.0, 670.0), Vector2(-226.0, 734.0)]
	var right: Array[Vector2] = [Vector2(182.0, 606.0), Vector2(214.0, 670.0), Vector2(226.0, 734.0)]
	# The deeds, carved at the rubric's 18 px as they are seen (#655): two
	# close inscriptions in the road's two corners, each standing from its own
	# edge of the stage (slab_margin, kept clear of the build number) with its
	# foot on slab_foot, lying a little (slab_lie) and leaning toward the
	# road's vanishing point (slab_shear). Lower and further out than the
	# words, and set closer, so they never read as a fourth row of the menu.
	var slab_margin: float = 52.0
	var slab_foot: float = 812.0
	var slab_w: float = 400.0
	var slab_lie: float = 0.14
	var slab_shear: float = 0.28
	var lang_dx: float = 240.0
	var lang_y: float = 688.0
	var consent: Vector3 = Vector3(26.0, 730.0, 440.0)
	# Where the consent line stands when the left foot is taken (a saved run's
	# three left words): the open sky top right, clear of the wordmark.
	var consent_high: Vector3 = Vector3(26.0, 40.0, 330.0)

	static func for_shape(stage_shape: StringName) -> Layout:
		var l: Layout = Layout.new()
		if not LeadlightTokens.is_phone(stage_shape):
			return l
		l.ref_h = 390.0
		l.rose_grow = 1.3
		l.word_y = 8.0
		l.word_w = 226.0
		l.plaque_y = 148.0
		# The wick sits at 0.918 of the stage height on every shape, where the
		# boot splash's ember is: frame 0 and the first frame register.
		l.lantern_y = 181.0
		l.lantern = 226.0
		l.left = [Vector2(-108.0, 218.0), Vector2(-132.0, 264.0), Vector2(-142.0, 308.0)]
		l.right = [Vector2(108.0, 218.0), Vector2(132.0, 264.0), Vector2(142.0, 308.0)]
		l.slab_margin = 44.0
		l.slab_foot = 386.0
		l.slab_w = 310.0
		l.lang_dx = 170.0
		l.lang_y = 300.0
		# Under the two left words a fresh install shows, with room for the
		# privacy word at the touch floor, clear of the lantern: on the stage, whole.
		l.consent = Vector3(14.0, 312.0, 300.0)
		l.consent_high = Vector3(14.0, 10.0, 268.0)
		return l

var shape: StringName = StageShape.IDENTITY
var world: TitleWorld
var lantern: LeadlightLantern
var rose: LeadlightRose
var rite: LeadlightRite
## A still holds the rite where it is (tools/capture_title.gd); play never sets it.
var hold_rite: bool = false

var _context: Dictionary
var _sfx: SfxBus
var _preferences: Preferences
var _wordmark: Control
var _plaque: LeadlightPlaque
## The plaque, its sub-line and the gap down to the lantern: one press with the
## lantern (build 18: the owner tapped the words, and nothing happened).
var _reach: Button
var _beckon: TitleBeckon
var _secondary: LeadlightPane = null
var _words: Dictionary = {}
var _slabs: Array[LeadlightInscription] = []
var _consent: VBoxContainer = null
var _language: Array[LeadlightPane] = []
var _veil: TitleVeil
var _chain: TitleLampChain
var _catcher: Control
var _version: Label
var _offers: Dictionary = {}
var _primary_id: String = "begin"
var _started: bool = false
var _leaving: bool = false
var _idle: float = 0.0
## Frame 0's cover while the landed title under it builds the rite's pipelines.
var _warm: Control = null
## Lent to a room (docs/design/2026-10-03-title-rooms §2.2): the lantern is at
## the room's seat and the title takes no input of its own.
var _lent: bool = false
## Where the passage holds the lantern instead of its home; empty at home.
var _lantern_at: Rect2 = Rect2()
## The painting over the road, and the wordmark's seat and how far a room's
## roll has carried it (Credits leads its roll with the title's own wordmark).
var _painting: Control = null
var _wordmark_home: Vector2 = Vector2.ZERO
var _wordmark_dy: float = 0.0
var _vignette: Control = null
var _rose_home: Vector2 = Vector2.ZERO
## How far the road has turned away to the Vigil (0..1), and whether it is held.
var _turn: float = 0.0
var _held: bool = false
var _held_focus: int = Control.FOCUS_ALL


## `context`: shape, choices (id/label rows, Main's route ids), sub (where a
## saved run stands), reading (Flame.read of the saved run), shards, deeds
## (carved lines), brand, version, rite (play the launch rite), ask_language,
## language_default, ask_consent, resume (a rite resumed after the language).
func _init(context: Dictionary, sfx: SfxBus = null, preferences: Preferences = null) -> void:
	_context = context
	_preferences = preferences if preferences != null else Preferences.active
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	var asked: StringName = StringName(str(context.get("shape", StageShape.IDENTITY)))
	shape = asked if StageShape.REFERENCES.has(asked) else StageShape.IDENTITY
	for row_v: Variant in context.get("choices", []):
		var row: Dictionary = row_v
		_offers[str(row.get("id", ""))] = str(row.get("label", ""))
	_primary_id = "continue" if _offers.has("continue") else "begin"
	_build()


## Whether the title offers route `id` (and so the player can reach it).
func offers(id: String) -> bool:
	return _offers.has(id)


func label_of(id: String) -> String:
	return str(_offers.get(id, ""))


## The title stops taking choices and holds every tap for the transition
## carrying it away (Main floods the lantern's light over it).
func leave() -> void:
	_leaving = true
	_catcher.visible = true
	_catcher.move_to_front()


## The wick on the stage: where the lantern's light floods out from.
func wick_on_stage() -> Vector2:
	return lantern.global_position + lantern.wick()


## The route the lantern takes: Back to the Road with a saved run, else Rekindle.
func primary_id() -> String:
	return _primary_id


func plaque_text() -> String:
	return _plaque.title_label().text


func set_shape(stage_shape: StringName) -> void:
	if StageShape.REFERENCES.has(stage_shape):
		shape = stage_shape
		_size_hits()
		_layout()


# ------------------------------------------------------------- lent to a room

## A room opens over the title (§2.2): the lantern goes to the room's seat (the
## passage carries it), draws over the room and leaves its taps to the seat;
## the idle ember is held; the title takes none of its own input.
func lend() -> void:
	_lent = true
	_beckon.hold()
	lantern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lantern.z_index = 205


func lent() -> bool:
	return _lent


## The room is leaving: the title takes input again from the next frame while
## the lantern is carried home.
func begin_return() -> void:
	_lent = false


## The lantern home and the title whole, its ember re-armed.
func reclaim() -> void:
	_lent = false
	_lantern_at = Rect2()
	lantern.settle()
	lantern.z_index = 0
	lantern.mouse_filter = Control.MOUSE_FILTER_STOP
	_layout()
	_beckon.arm()


## Hold the lantern at `rect` (title px) instead of its home.
func place_lantern(rect: Rect2) -> void:
	_lantern_at = rect
	if lantern.position != rect.position:
		lantern.position = rect.position
	if lantern.size != rect.size:
		lantern.size = rect.size


## Credits' road onward (§4.3): the eye walks `metres` on down the road and
## the painting and its lamps scale about the door's rose, only ever growing,
## so no edge of the painting can show.
func set_walk(metres: float) -> void:
	world.walk = metres
	var grow: float = 1.0 + world.walk * 0.012
	var about: Vector2 = rose.position + rose.size * 0.5
	for layer: Control in [_painting, _chain]:
		if layer != null:
			layer.pivot_offset = about
			layer.scale = Vector2(grow, grow)


## The turn west (V1) and back east (V3), 0..1: the road's world pans in
## screen space (its sky fills the stage, so no edge shows), and the painting
## with its lamps, the door's rose and the wordmark slide on and go, the
## painting growing about its centre. 0 is the road as it rests.
func turn(amount: float) -> void:
	_turn = clampf(amount, 0.0, 1.0)
	world.pan_px = _turn * TURN_PAN * size.x
	var slide: float = _turn * TURN_SLIDE * size.x
	var fade: float = 1.0 - _turn
	for layer: Control in [_painting, _chain]:
		if layer == null:
			continue
		layer.position.x = slide
		layer.pivot_offset = layer.size * 0.5
		layer.scale = Vector2.ONE * (1.0 + TURN_GROW * _turn)
		layer.modulate.a = fade * (BANNER_ALPHA if layer == _painting else 1.0)
	rose.position = _rose_home + Vector2(slide, 0.0)
	rose.modulate.a = fade
	_wordmark.position = _wordmark_home + Vector2(slide, _wordmark_dy)
	_wordmark.modulate.a = fade
	if _turn <= 0.0:
		set_walk(world.walk)


func turned() -> float:
	return _turn


## Held under the Vigil (docs/design/2026-10-03-title-rooms §2.1, §9 item 2):
## the road and the painting do no work but stay drawn under the hall's opaque
## plate; the painting's lamps, the vignette, the door's rose, the wordmark and
## the furniture are hidden and still; nothing of the title takes focus; the
## lantern, lent to the seat, burns on. Released, it is all where it was, the
## road's clocks going on from where they stopped.
##
## The road and the painting stay drawn so that the GPU's work does not step
## up at the turn east. Hidden, their return under the fading hall took the
## iPad 8's GPU from about 13.5 to 22-25 ms a frame at its lowest clock, and
## the first frames of V3 missed the display while the clock rose (#655 PR C,
## open item 4). The lighter layers stay hidden: drawn too, they cost the hall
## at rest more than they saved the turn.
func hold_world(on: bool) -> void:
	if on == _held:
		return
	_held = on
	for layer: Control in [world, _painting]:
		if layer != null:
			layer.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	for layer: Control in [_vignette, _chain, rose, _wordmark]:
		if layer != null:
			layer.visible = not on
			layer.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	for item_v: Variant in _light_words():
		if item_v is CanvasItem:
			var item: CanvasItem = item_v
			item.visible = not on
	if on:
		_held_focus = lantern.focus_mode
		lantern.focus_mode = Control.FOCUS_NONE
	else:
		lantern.focus_mode = _held_focus as Control.FocusMode


func held() -> bool:
	return _held


## A route lifted off the title (docs/design/2026-10-03-title-rooms §5.2, X2
## and V9): the title stands landed beneath it and its furniture rises from
## 60 to 380 ms. At once under Reduce Motion (a cross-fade covers it).
func rise_after_lift() -> void:
	if LeadlightMotion.reduced() or not is_inside_tree():
		return
	var items: Array = furniture(null, false)
	var rise: Callable = func(t: float) -> void:
		for item_v: Variant in items:
			if is_instance_valid(item_v):
				var item: CanvasItem = item_v
				item.modulate.a = LeadlightMotion.ease_on((t - 0.06) / 0.32, LeadlightMotion.REVEAL)
	rise.call(0.0)
	create_tween().tween_method(rise, 0.0, 0.38, 0.38)


## The wordmark lent to a room's roll: drawn over the room, `dy` from its seat.
func lend_wordmark(lent_to_room: bool) -> void:
	_wordmark.z_index = 201 if lent_to_room else 0
	if not lent_to_room:
		offset_wordmark(0.0)


func offset_wordmark(dy: float) -> void:
	_wordmark_dy = dy
	_wordmark.position = _wordmark_home + Vector2(0.0, dy)


func wordmark() -> Control:
	return _wordmark


## The lantern's home square on this stage (the layout's).
func home_rect() -> Rect2:
	var spec: Layout = Layout.for_shape(shape)
	var k: float = size.y / spec.ref_h if size.y > 0.0 else 1.0
	var side: float = spec.lantern * k
	return Rect2(Vector2(size.x * 0.5 - side * 0.5, spec.lantern_y * k), Vector2(side, side))


## The title word for route `id`, or null.
func word(id: String) -> Control:
	return _words.get(id, null)


## What goes from the road while a room is open: the plaque, the Rekindle pane,
## the words (but `except`, which becomes the room's crown), the carved deeds,
## the consent line and the build number; with `wordmark`, the wordmark too (a
## room that stands over it).
func furniture(except: Control = null, wordmark: bool = false) -> Array:
	var items: Array = []
	for item: Variant in _light_words():
		if item != except and item is CanvasItem:
			items.append(item)
	if wordmark:
		items.append(_wordmark)
	return items


## The road at dusk the title stands on — the living world, the painting
## over it and the vignette — added to `host`. The departure (DepartureScreen)
## stands in the same place.
static func add_road(host: Control) -> TitleWorld:
	var road: TitleWorld = TitleWorld.new()
	host.add_child(road)
	var banner: TextureRect = TextureRect.new()
	banner.name = "Painting"
	banner.texture = load(TITLE_BACKGROUND) as Texture2D
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	banner.modulate.a = BANNER_ALPHA
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(banner)
	var vignette: TextureRect = TextureRect.new()
	vignette.texture = GlassStyle.grad_tex(
		PackedColorArray([Color(LeadlightTokens.VOID, 0.0), Color(LeadlightTokens.VOID, 0.0),
			Color(LeadlightTokens.VOID, 0.62)]),
		PackedFloat32Array([0.0, 0.5, 1.0]), true, Vector2(0.5, 0.62), Vector2(1.05, 0.62))
	vignette.name = "Vignette"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(vignette)
	return road


func _build() -> void:
	world = add_road(self)
	_painting = find_child("Painting", false, false) as Control
	_vignette = find_child("Vignette", false, false) as Control
	_chain = TitleLampChain.new()
	add_child(_chain)
	rose = LeadlightRose.new(context_array("shards"))
	rose.pressed.connect(_choose.bind("rose"))
	add_child(rose)
	_build_words()
	_build_history()
	_veil = TitleVeil.new()
	add_child(_veil)
	# While the rite runs, the catcher sits over everything the light has not
	# reached yet, so a faded word can never be pressed; the lantern and the
	# language panes stand above it.
	_catcher = Control.new()
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_catcher_input)
	_catcher.visible = false
	add_child(_catcher)
	_build_lantern()
	_build_wordmark()
	_build_first_light()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func context_array(key: String) -> Array:
	var value: Variant = _context.get(key, [])
	return value if typeof(value) == TYPE_ARRAY else []


func _build_lantern() -> void:
	lantern = LeadlightLantern.new()
	var reading_v: Variant = _context.get("reading", {})
	var reading: Dictionary = reading_v if typeof(reading_v) == TYPE_DICTIONARY else {}
	lantern.set_reading(reading)
	lantern.tooltip_text = label_of(_primary_id)
	lantern.pressed.connect(_on_lantern)
	add_child(lantern)
	_plaque = LeadlightPlaque.new(shape)
	var sub: String = str(_context.get("sub", "")) if _primary_id == "continue" else ""
	_plaque.set_text(label_of(_primary_id), sub, lantern.light())
	add_child(_plaque)
	_reach = Button.new()
	_reach.name = "PrimaryReach"
	_reach.flat = true
	_reach.focus_mode = Control.FOCUS_NONE
	_reach.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_reach.tooltip_text = lantern.tooltip_text
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		_reach.add_theme_stylebox_override(state, empty)
	_reach.pressed.connect(_on_lantern)
	add_child(_reach)
	# The plaque lights with the lantern under the hand, the key and the press.
	for part: BaseButton in [lantern, _reach]:
		part.mouse_entered.connect(_light_plaque.bind(0.35))
		part.mouse_exited.connect(_light_plaque.bind(0.0))
		part.button_down.connect(_light_plaque.bind(1.0))
		part.button_up.connect(_light_plaque.bind(0.0))
	# The plaque's hairline follows focus SHOWN on the lantern: a tap holds
	# focus hidden, and a touch player sees no ring and no hairline.
	lantern.focus_shown.connect(func(shown: bool) -> void: _plaque.focused = shown)
	_beckon = TitleBeckon.new(lantern, _plaque)
	add_child(_beckon)


func _light_plaque(amount: float) -> void:
	if not _leaving:
		_plaque.glow = amount


func _build_words() -> void:
	if _primary_id == "continue" and _offers.has("begin"):
		_secondary = LeadlightPane.new(label_of("begin"), shape)
		_secondary.pressed.connect(_choose.bind("begin"))
		_secondary.button_down.connect(_pressed_now.bind(_secondary))
		add_child(_secondary)
	for id: String in LEFT_IDS + RIGHT_IDS + ["dev"]:
		if id == "begin" or not _offers.has(id):
			continue
		var word: LeadlightWord = LeadlightWord.new(label_of(id), shape)
		word.pressed.connect(_choose.bind(id))
		word.button_down.connect(_pressed_now.bind(word))
		_words[id] = word
		add_child(word)
	_size_hits()


## The rubric's pressed state, on the frame the finger is down: the dip.
func _pressed_now(control: Control) -> void:
	if not _leaving and not _lent:
		LeadlightMotion.press(control)


## The quiet words and the Rekindle pane take a tap 60 px tall at pad and on
## desktop (the rubric's floor), and 44 on a phone (the touch floor; the pane's
## glass is drawn 34 there), where they are drawn.
func _size_hits() -> void:
	var tall: float = LeadlightTokens.room_hit(shape)
	for word_v: Variant in _words.values():
		var word: LeadlightWord = word_v
		word.hit_height = tall
	if _secondary != null:
		_secondary.hit_height = tall


func _build_history() -> void:
	var deeds: Array = context_array("deeds")
	if deeds.is_empty():
		return
	var half: int = ceili(float(deeds.size()) / 2.0)
	for side: int in range(2):
		var slab: LeadlightInscription = LeadlightInscription.new(shape)
		var part: PackedStringArray = PackedStringArray()
		for i: int in range(side * half, mini(deeds.size(), (side + 1) * half)):
			part.append(str(deeds[i]))
		slab.set_lines(part)
		_slabs.append(slab)
		add_child(slab)


func _build_wordmark() -> void:
	var brand: String = str(_context.get("brand", "GLASSVOW"))
	var raster: String = WORDMARK_ZH if brand == "琉璃誓言" else (WORDMARK_EN if brand == "GLASSVOW" else "")
	if raster.is_empty():
		var label: Label = Label.new()
		label.text = brand
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_PRIMARY, 48))
		label.add_theme_font_size_override("font_size", 48)
		label.add_theme_color_override("font_color", LeadlightTokens.PARCHMENT)
		_wordmark = label
	else:
		var art: TextureRect = TextureRect.new()
		art.texture = load(raster) as Texture2D
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_wordmark = art
	_wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wordmark)
	_version = Label.new()
	_version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_version.text = str(_context.get("version", ""))
	_version.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, 11))
	_version.add_theme_font_size_override("font_size", 11)
	_version.add_theme_color_override("font_color", Color(LeadlightTokens.TEXT_DIM, 0.55))
	add_child(_version)


func _build_first_light() -> void:
	if _context.get("ask_language", false) == true:
		var default_code: StringName = StringName(str(_context.get("language_default", Locale.CODE_EN)))
		for code: StringName in [Locale.CODE_ZH_HANT, Locale.CODE_EN]:
			var pane: LeadlightPane = LeadlightPane.new(
				Locale.active.t("ui.language.zhHant" if code == Locale.CODE_ZH_HANT else "ui.language.en"), shape)
			pane.set_px(18 if not LeadlightTokens.is_phone(shape) else 14)
			pane.lit = code == default_code
			pane.set_meta(&"code", code)
			pane.pressed.connect(_on_language.bind(code))
			_language.append(pane)
			add_child(pane)
	if _context.get("ask_consent", false) == true:
		var spec: Layout = Layout.for_shape(shape)
		var k: float = 1.0 if size.y <= 0.0 else size.y / spec.ref_h
		var low: bool = _side_items(LEFT_IDS).size() < spec.left.size()
		_consent = FirstLight.consent_row(_preferences, shape,
			(spec.consent.z if low else spec.consent_high.z) * k)
		# The note under the switch grows the row: it stays on the stage.
		_consent.minimum_size_changed.connect(_layout)
		add_child(_consent)


func _ready() -> void:
	_layout()
	kindle_now()


## Start the title: the launch rite when this title kindles, else land lit.
## Idempotent; `_ready` calls it, and a test may call it before the tree does.
func kindle_now() -> void:
	if _started:
		return
	_started = true
	var resume: bool = _context.get("resume", false) == true
	if _context.get("rite", false) == true or resume:
		rite = TitleKindling.build({"lantern": lantern, "world": world, "veil": _veil, "chain": _chain,
			"wordmark": _wordmark, "rose": rose, "words": _light_words(), "sfx": _sfx})
		if not _language.is_empty():
			rite.at(0.05, func() -> void: _sfx.play_owed(&"paneRise"))
		if not _language.is_empty():
			rite.hold_at(TitleKindling.HOLD)
		rite.finished.connect(_on_rite_done)
		_catcher.visible = true
		rite.start()
		if resume:
			rite.advance(TitleKindling.HOLD)
		_warm_pipelines()
	else:
		_land()
	_focus_first()


## Build on frame 0 every pipeline the rite will reach for (build 18: the
## A12 stalled 40-50 ms as the glass's glow, the light pool and the world
## first appeared on a cold launch). For that one frame the title is drawn
## landed — every layer, blend and glyph the rite will show — under a cover
## of the night and the ember alone, which is exactly what frame 0 shows (the
## splash). The cover goes on the next frame and the rite starts from 0
## then, without the warm frame's delta.
func _warm_pipelines() -> void:
	if not is_inside_tree() or rite == null or not rite.is_running() or LeadlightMotion.reduced():
		return
	lantern.kindle = 1.0
	lantern.presence = 1.0
	lantern.reach = 1.0
	world.lamplight = 1.0
	_chain.progress = 1.0
	_veil.reach = 1.0
	_veil.strength = 0.0
	_wordmark.modulate.a = 1.0
	rose.glow = 1.0
	for item_v: Variant in _light_words():
		if item_v is CanvasItem:
			var item: CanvasItem = item_v
			item.modulate.a = 1.0
	_warm = Control.new()
	_warm.name = "FrameZeroCover"
	_warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warm.set_anchors_preset(Control.PRESET_FULL_RECT)
	var night: ColorRect = ColorRect.new()
	night.color = LeadlightTokens.VOID
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	_warm.add_child(night)
	_warm.add_child(lantern.ember_alone(TitleKindling.kindle_at(rite.time())))
	add_child(_warm)


func _end_warm() -> void:
	_warm.queue_free()
	_warm = null
	rite.refresh()


func _process(delta: float) -> void:
	if _warm != null:
		# The warm frame's delta is the compile, not the rite's time.
		_end_warm()
	elif rite != null and rite.is_running() and not hold_rite:
		rite.advance(delta)
	_idle += delta
	# First launch waits on the language without going still: the ember's
	# own light flickers on the road round it (the flame's light, so it stays
	# under Reduce Motion), and the pre-lit pane breathes.
	if rite != null and rite.held():
		_veil.reach = TitleKindling.EMBER_REACH * (0.55 + 0.45 * lantern.ember_flicker())
		# The dark is not empty: the road's ash drifts faintly through it.
		_veil.strength = 0.9
	if not LeadlightMotion.reduced():
		for pane: LeadlightPane in _language:
			var glow: float = 1.0 + (0.10 * (0.5 + 0.5 * LeadlightMotion.breath(_idle, 2.6)) if pane.lit else 0.0)
			pane.self_modulate = Color(glow, glow, glow, 1.0)


## Everything the light brings up as it reaches: the words, plaque, slabs.
func _light_words() -> Array:
	var items: Array = [_plaque, _version]
	if _secondary != null:
		items.append(_secondary)
	for word: Variant in _words.values():
		items.append(word)
	for slab: LeadlightInscription in _slabs:
		items.append(slab)
	if _consent != null:
		items.append(_consent)
	return items


## The title as it rests once lit: the second title of a session lands here.
func _land() -> void:
	lantern.kindle = 1.0
	lantern.presence = 1.0
	lantern.reach = 1.0
	world.lamplight = 1.0
	_chain.progress = 1.0
	_veil.strength = 0.0
	_catcher.visible = false
	_record_consent_shown()
	for language: LeadlightPane in _language:
		language.queue_free()
	_language.clear()
	_wake_beckon()


## The title is lit and taking input: the first of a session shows which thing
## is the button; every one counts idleness for the rising ember.
func _wake_beckon() -> void:
	_beckon.arm()
	if _context.get("beckon", false) == true:
		_beckon.pulse()


## The consent notice is recorded only once its line is lit on screen — the
## rite's reveal has run, or the title landed lit — never when it is built: a
## first title held at the ember for the language never lights it, and the
## title rebuilt in the chosen language must still offer it.
func _record_consent_shown() -> void:
	if _consent != null and is_instance_valid(_consent):
		_preferences.mark_diagnostics_notice_seen()


func _on_rite_done() -> void:
	_record_consent_shown()
	_catcher.visible = false
	_wake_beckon()
	for language: LeadlightPane in _language:
		LeadlightMotion.exit(language)
	_focus_first()


## A tap during the rite completes it and chooses nothing (motion spec T1).
func _on_catcher_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if press and _leaving:
		hurry.emit()
		accept_event()
		return
	if press and rite != null and not rite.is_done() and not rite.held():
		rite.skip()
		accept_event()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventKey \
			or event is InputEventJoypadButton or event is InputEventScreenDrag:
		_beckon.touched()
	if _reveals_focus(event):
		# Consumed here, so Main's `_input` never sees it: note it first.
		LeadlightFocus.note(event)
		get_viewport().set_input_as_handled()


## Focus is for the keyboard and the pad: a touch player never sees a ring.
## The first key or button shows focus — on the lantern, or where a tap left
## it hidden — and acts on nothing; the next one acts. A bare modifier (a
## screenshot shortcut) is not a key here. True when this press was that first.
func _reveals_focus(event: InputEvent) -> bool:
	if not _is_key_press(event) or _leaving or _lent or not is_visible_in_tree() \
			or lantern.focus_mode == Control.FOCUS_NONE:
		return false
	if rite != null and rite.is_running() and not rite.held():
		return false
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner == null:
		_focus_first(true)
		return true
	if is_ancestor_of(owner) and not owner.has_focus(true):
		LeadlightFocus.give(owner, true)
		return true
	return false


static func _is_key_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: InputEventKey = event
		return key.pressed and not key.echo and LeadlightFocus.is_navigation(key)
	if event is InputEventJoypadButton:
		return event.is_pressed()
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) > 0.5
	return false


func _unhandled_input(event: InputEvent) -> void:
	# Lent to a room: Main bars only the key variant, which this never was.
	if _lent:
		return
	if _is_key_press(event) and rite != null and rite.is_running() and not rite.held():
		rite.skip()
		get_viewport().set_input_as_handled()


func _on_lantern() -> void:
	if rite != null and rite.held():
		# The flame tapped while the language waits: accept the pre-lit pane.
		for pane: LeadlightPane in _language:
			if pane.lit:
				var code: StringName = pane.get_meta(&"code")
				_on_language(code)
				return
	if rite != null and rite.is_running():
		rite.skip()
		return
	LeadlightMotion.press(lantern)
	LeadlightMotion.press(_plaque)
	_plaque.glow = 1.0
	_sfx.play_owed(&"paneChoose", &"click")
	_choose(_primary_id, false)


func _on_language(code: StringName) -> void:
	_sfx.play_owed(&"paneChoose", &"click")
	for pane: LeadlightPane in _language:
		pane.lit = pane.get_meta(&"code") == code
	language_chosen.emit(code)


## Main answers a chosen language by rebuilding the title in it (the rite
## resumes past the ember); a language already on screen continues here.
func resume_after_language() -> void:
	if rite == null:
		return
	for pane: LeadlightPane in _language:
		LeadlightMotion.exit(pane)
	rite.release()
	if LeadlightMotion.reduced():
		rite.skip()


func _choose(id: String, click: bool = true) -> void:
	if _leaving:
		return
	if rite != null and rite.is_running():
		rite.skip()
		return
	# One cue per tap (§2.9): a room's word is heard as the room opening.
	if click and not ROOM_IDS.has(id):
		_sfx.play(&"relic" if id == "rose" else &"click")
	chosen.emit(id)


## Focus to the lantern (or the pre-lit language pane), shown only to a
## keyboard or pad player, or with `force` (a key asked for it). Unforced, it
## moves focus only when something holds it: a cold launch places none, while a
## return finds the old screen's tapped button still holding hidden focus (its
## free waits for the frame's end) and takes it over, hidden, for the lantern.
func _focus_first(force: bool = false) -> void:
	if not is_inside_tree():
		return
	if not force and get_viewport().gui_get_focus_owner() == null:
		return
	var target: Control = lantern
	for pane: LeadlightPane in _language:
		if pane.lit:
			target = pane
	LeadlightFocus.give(target, force)


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or lantern == null:
		return
	var spec: Layout = Layout.for_shape(shape)
	var k: float = size.y / spec.ref_h
	var cx: float = size.x * 0.5
	var word_w: float = spec.word_w * k
	var mark_h: float = word_w * 399.0 / 1536.0 if _wordmark is TextureRect else 60.0 * k
	_wordmark_home = Vector2(cx - word_w * 0.5, spec.word_y * k)
	_wordmark.position = _wordmark_home + Vector2(_turn * TURN_SLIDE * size.x, _wordmark_dy)
	_wordmark.size = Vector2(word_w, mark_h)
	var side: float = spec.lantern * k
	var home: Rect2 = home_rect()
	if _lantern_at.has_area():
		place_lantern(_lantern_at)
	else:
		lantern.position = home.position
		lantern.size = home.size
	if not LeadlightTokens.is_phone(shape):
		# The flame colours the road under the lantern, and breathes on it.
		lantern.set_pool(Vector2(2.1, 1.05), 0.22, 0.8, 0.09)
		rose.radiance = 1.0
	_plaque.size = _plaque.get_combined_minimum_size()
	# The plaque stands on the lantern's ring, never over it: a taller plaque
	# (its sub-line at the rubric's 18 px) rises rather than reaching the chain.
	var ring_top: float = home.position.y + side * LeadlightLantern.RING_TOP_UV
	_plaque.position = Vector2(cx - _plaque.size.x * 0.5,
		minf(spec.plaque_y * k, ring_top - _plaque.size.y))
	_reach.position = _plaque.position - Vector2(REACH_PAD.x, REACH_PAD.y)
	var reach_bottom: float = maxf(_plaque.position.y + _plaque.size.y + REACH_PAD.y, home.position.y)
	_reach.size = Vector2(_plaque.size.x + REACH_PAD.x * 2.0,
		maxf(reach_bottom - _reach.position.y, 44.0))
	_veil.centre = home.position + home.size * LeadlightLantern.WICK_UV
	var rose_at: Vector2 = TitleLampChain.to_stage(Vector2(ROSE_ART.x, ROSE_ART.y), size)
	# The rose is drawn larger than the painted one it covers, so the shards
	# read as the end game's mirror.
	var rose_r: float = ROSE_ART.z * spec.rose_grow * TitleLampChain.scale_for(size)
	_rose_home = rose_at - Vector2(rose_r, rose_r)
	rose.position = _rose_home + Vector2(_turn * TURN_SLIDE * size.x, 0.0)
	rose.size = Vector2(rose_r, rose_r) * 2.0
	# The consent line takes the foot of the left side when it is free, so the
	# words there stand from the top of their arc instead of centred on it.
	var consent_low: bool = _consent != null and _side_items(LEFT_IDS).size() < spec.left.size()
	_place_side(LEFT_IDS, spec.left, -1.0, k, cx, consent_low)
	_place_side(RIGHT_IDS, spec.right, 1.0, k, cx)
	if _words.has("dev"):
		var dev: Control = _words["dev"]
		dev.position = Vector2(size.x - dev.get_combined_minimum_size().x - 12.0, 10.0)
	_place_slabs(spec, k)
	for i: int in _language.size():
		var pane: LeadlightPane = _language[i]
		var w: float = pane.get_combined_minimum_size().x + 24.0
		var dx: float = spec.lang_dx * k * (-1.0 if i == 0 else 1.0)
		pane.size = Vector2(w, pane.get_combined_minimum_size().y)
		pane.position = Vector2(cx + dx - w * 0.5, spec.lang_y * k - pane.size.y * 0.5)
	if _consent != null:
		# Its height is its own (the sentence's lines, the switch's row, the
		# note once shown): the row rises from its seat to stay on the stage.
		var own: Vector2 = _consent.get_combined_minimum_size()
		if consent_low:
			_consent.position = Vector2(spec.consent.x * k,
				minf(spec.consent.y * k, size.y - own.y - 6.0 * k))
		else:
			_consent.position = Vector2(size.x - spec.consent_high.x * k - own.x,
				spec.consent_high.y * k)
		_consent.size = own
	_version.position = Vector2(size.x - _version.get_combined_minimum_size().x - 10.0,
		size.y - _version.get_combined_minimum_size().y - 4.0)


## The deeds in the road's two corners (see `Layout`): each slab stands from its
## own edge, clear of the build number in the right-hand corner and the same
## distance in from the left, its carved foot on the layout's line.
func _place_slabs(spec: Layout, k: float) -> void:
	if _slabs.is_empty():
		return
	var margin: float = maxf(spec.slab_margin * k, _version.get_combined_minimum_size().x + 22.0)
	var slab_w: float = spec.slab_w * k
	for i: int in _slabs.size():
		var slab: LeadlightInscription = _slabs[i]
		var left: bool = i == 0
		if not is_equal_approx(slab.lie, spec.slab_lie):
			slab.lie = spec.slab_lie
		slab.shear = spec.slab_shear * (1.0 if left else -1.0)
		slab.align = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		# The carved role, gold at 55%, cut with a groove so it reads on stone.
		slab.colour = Color(LeadlightTokens.GOLD, 0.55)
		slab.groove = true
		slab.size = Vector2(slab_w, slab.box_height())
		slab.position = Vector2(margin if left else size.x - margin - slab_w, 0.0)
		slab.position.y = spec.slab_foot * k - slab.drawn_rect().end.y
		slab.queue_redraw()


## Seat a side's words on its arc, nearest the flame first; a short side is
## centred on its arc so the two sides stay balanced, or stands from its top
## (`from_top`) when the foot of the side is taken.
func _place_side(ids: Array[String], slots: Array[Vector2], dir: float, k: float, cx: float,
		from_top: bool = false) -> void:
	var items: Array[Control] = _side_items(ids)
	var start: float = 0.0 if from_top else float(slots.size() - items.size()) * 0.5
	for i: int in items.size():
		var at: float = start + float(i)
		var lo: int = clampi(floori(at), 0, slots.size() - 1)
		var hi: int = clampi(lo + 1, 0, slots.size() - 1)
		var slot: Vector2 = slots[lo].lerp(slots[hi], at - float(lo)) * k
		var item: Control = items[i]
		var item_size: Vector2 = item.get_combined_minimum_size()
		if item is LeadlightPane:
			item_size.x += 20.0
		item.size = item_size
		var x: float = cx + slot.x - (item_size.x if dir < 0.0 else 0.0)
		item.position = Vector2(x, slot.y - item_size.y * 0.5)
		if item is LeadlightWord:
			(item as LeadlightWord).near = i == 0


## The words and the Rekindle pane a side shows, nearest the flame first.
func _side_items(ids: Array[String]) -> Array[Control]:
	var items: Array[Control] = []
	for id: String in ids:
		if id == "begin":
			if _secondary != null:
				items.append(_secondary)
		elif _words.has(id):
			items.append(_words[id])
	return items
