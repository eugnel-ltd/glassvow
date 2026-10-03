class_name CreditsScreen
extends LeadlightRoomHost
## Credits is a place: the road onward (docs/design/2026-10-03-title-rooms
## §4.3). The title's furniture goes, the lantern is lowered to the seat, and
## the title's own wordmark stays where it is and heads the roll (CreditsRoll),
## the word "Credits" riding down to the roll's first heading under it. The
## roll stands on a soft band of night over the living road, each line warming
## as it crosses the lamp line; after a still moment the roll drifts on its own
## and the eye walks a little way on down the road with it, so the lamps really
## pass; any touch, drag, wheel or key takes over and the drift resumes three
## seconds later. Under Reduce Motion it is a plain scroll.
##
## The licences are their own glasses (CreditsLicences.Glass) over the paused,
## dimmed roll; the seat's Return and Escape close an open glass first.

## The bundled fonts' licences (CreditsLicences owns the texts).
const FONT_LICENCES: Array[Dictionary] = CreditsLicences.FONT_LICENCES
## The roll's column (pad and desktop, phone): its width, the top of its view,
## and how far above the stage's foot its view ends (clear of the seat).
const ROLL_W: Vector2 = Vector2(600.0, 520.0)
const ROLL_TOP: Vector2 = Vector2(20.0, 6.0)
const ROLL_FOOT: Vector2 = Vector2(90.0, 60.0)
## The lamp line, as a share of the stage's height, and how far its warmth reaches.
const LAMP_LINE: float = 0.56
const LAMP_REACH: float = 0.16
## The drift, px/s (pad, phone); after DRIFT_AFTER s still, DRIFT_RESUME s after a touch.
const DRIFT: Vector2 = Vector2(22.0, 16.0)
const DRIFT_AFTER: float = 1.2
const DRIFT_RESUME: float = 3.0
## The first step on arrival, and the band's strength at its centre.
const FIRST_STEP: float = 0.4
const BAND_ALPHA: float = 0.7

## The band's soft light, made once: the same texture every opening.
static var _band_light: GradientTexture2D = null

var _sfx: SfxBus
var _band: TextureRect
var _scroll: ScrollContainer
var _roll: CreditsRoll
var _licences: CreditsLicences.Shelf
## The folds the licence texts are built into, on first opening.
var _font_licence_wrap: MarginContainer
var _licence_wrap: MarginContainer
var _quiet: float = 0.0
var _wait: float = DRIFT_AFTER
var _drift_y: float = 0.0
var _landed: bool = false
var _time: float = 0.0
## Where the leaving began: the walk and the wordmark go home from here.
var _leave_from: Vector2 = Vector2.INF


func _init(stage_shape: StringName = StageShape.IDENTITY, sfx: SfxBus = null,
		unsealed: bool = false, now_playing: StringName = &"") -> void:
	_host(stage_shape)
	veil_closes = false
	veil().color = Color(LeadlightTokens.VOID, 0.0)
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_band = TextureRect.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _band_light == null:
		_band_light = LeadlightShapes.soft_light(PackedFloat32Array([1.0, 0.92, 0.75, 0.4, 0.0]))
	_band.texture = _band_light
	_band.self_modulate = Color(LeadlightTokens.VOID, BAND_ALPHA)
	_band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_band)
	_scroll = ScrollContainer.new()
	_scroll.name = "Roll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.follow_focus = true
	add_child(_scroll)
	_roll = CreditsRoll.new(shape, unsealed, now_playing)
	_roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll.licence_requested.connect(_open_licence)
	_scroll.add_child(_roll)
	_licences = CreditsLicences.Shelf.new(shape)
	_licences.shut.connect(close_licence)
	add_child(_licences)
	_font_licence_wrap = _licences.fonts.wrap
	_licence_wrap = _licences.engine.wrap
	_seat_last()


func roll() -> CreditsRoll:
	return _roll


func scroll() -> ScrollContainer:
	return _scroll


## "Credits", where the word that opened the room lands: while it is on view.
func crown() -> Control:
	var at: Rect2 = _roll.heading_node.get_global_rect()
	return _roll.heading_node if _scroll.get_global_rect().intersects(at) else null


func content_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = [Rect2(_scroll.position, _scroll.size)]
	if _licences.opened != null:
		rects.append(Rect2(_licences.opened.sheet.position, _licences.opened.sheet.size))
	return rects


func arrival_time() -> float:
	return 0.60


func departure_time() -> float:
	return 0.48


func _fit() -> void:
	if _scroll == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var phone: bool = LeadlightTokens.is_phone(shape)
	var width: float = ROLL_W.y if phone else ROLL_W.x
	var top: float = ROLL_TOP.y if phone else ROLL_TOP.x
	var foot: float = ROLL_FOOT.y if phone else ROLL_FOOT.x
	_scroll.position = Vector2((size.x - width) * 0.5, top)
	_scroll.size = Vector2(width, size.y - top - foot)
	_roll.custom_minimum_size.x = width
	# The roll starts under the title's wordmark, which heads it.
	var spec: TitleScreen.Layout = TitleScreen.Layout.for_shape(shape)
	var k: float = size.y / spec.ref_h
	var mark_foot: float = (spec.word_y + spec.word_w * 399.0 / 1536.0) * k
	_roll.head_gap.custom_minimum_size.y = maxf(mark_foot + 6.0 - top, 0.0)
	_band.size = Vector2(width * 1.7, size.y * 1.15)
	_band.position = Vector2((size.x - _band.size.x) * 0.5, (size.y - _band.size.y) * 0.5)
	_licences.place(shape, size)


# ---------------------------------------------------------------- the passage

## C1: the band rises, the roll comes up line by line from the wordmark down,
## and the eye takes its first step on down the road.
func arrive_at(t: float, _wick: Vector2, _colour: Color) -> void:
	_band.modulate.a = LeadlightMotion.ease_on(t / 0.32, LeadlightMotion.SETTLE_OUT)
	var i: int = 0
	# The heading is the crown: the word in flight lands there (the passage's).
	for item: Node in _roll.get_children():
		if item is Control and item != _roll.head_gap and item != _roll.heading_node:
			var from: float = minf(0.12 + 0.04 * float(i), 0.40)
			_reveal(item as Control, LeadlightMotion.ease_on((t - from) / 0.2, LeadlightMotion.REVEAL))
			i += 1
	if title != null:
		title.lend_wordmark(true)
		if not LeadlightMotion.reduced():
			title.set_walk(FIRST_STEP * LeadlightMotion.ease_on(t / 0.6, LeadlightMotion.BREATH))


func rest(_wick: Vector2, _colour: Color) -> void:
	_roll.finish()
	_band.modulate.a = 1.0
	for item: Node in _roll.get_children():
		if item is Control:
			_reveal(item as Control, 1.0)
	if title != null:
		title.lend_wordmark(true)
		title.set_walk(0.0 if LeadlightMotion.reduced() else FIRST_STEP)
	_landed = true


## C2: the roll fades farthest from the lamp line first, the band goes, the eye
## walks back and the wordmark glides home to its seat.
func leave_at(t: float, _wick: Vector2, _colour: Color) -> void:
	_landed = false
	if _leave_from == Vector2.INF:
		_leave_from = Vector2(title.world.walk if title != null else 0.0, -float(_scroll.scroll_vertical))
	var lamp: float = size.y * LAMP_LINE
	for item: Node in _roll.get_children():
		if item is Control and item != _roll.heading_node:
			var far: float = clampf(absf((item as Control).get_global_rect().get_center().y - lamp)
				/ (size.y * 0.5), 0.0, 1.0)
			_reveal(item as Control, 1.0 - LeadlightMotion.ease_on(t / (0.24 * (1.25 - 0.5 * far)),
				LeadlightMotion.EXIT), false)
	_band.modulate.a = 1.0 - LeadlightMotion.ease_on((t - 0.08) / 0.32, LeadlightMotion.SETTLE_OUT)
	if _licences.opened != null:
		_licences.opened.modulate.a = _band.modulate.a
	if title != null:
		var home: float = LeadlightMotion.ease_on(t / departure_time(), LeadlightMotion.IN_OUT)
		title.set_walk(lerpf(_leave_from.x, 0.0, home))
		title.offset_wordmark(lerpf(_leave_from.y, 0.0,
			LeadlightMotion.ease_on(t / departure_time(), LeadlightMotion.REVEAL)))
		if t >= departure_time():
			title_returns()


## The title's road and wordmark as they were, whatever the leaving.
func title_returns() -> void:
	if title != null:
		title.set_walk(0.0)
		title.lend_wordmark(false)


# ---------------------------------------------------------------- at rest

func _process(delta: float) -> void:
	_time += delta
	if _roll.now_glyph != null and not LeadlightMotion.reduced():
		var glow: float = 1.0 + 0.18 * LeadlightMotion.breath(_time, 2.8)
		_roll.now_glyph.modulate = Color(glow, glow, glow, 1.0)
	if not _landed:
		return
	_drift(delta)
	if title != null:
		title.offset_wordmark(-float(_scroll.scroll_vertical))
		if not LeadlightMotion.reduced():
			var span: float = maxf(_roll.size.y - _scroll.size.y, 1.0)
			var progress: float = clampf(float(_scroll.scroll_vertical) / span, 0.0, 1.0)
			title.set_walk(lerpf(FIRST_STEP, TitleWorld.WALK_MAX, progress))
	_roll.warm(size.y * LAMP_LINE, size.y * LAMP_REACH)


## The roll drifts on its own after a still moment, until the footer reaches
## the lamp line; never under Reduce Motion or under an open licence glass.
func _drift(delta: float) -> void:
	_quiet += delta
	if LeadlightMotion.reduced() or _licences.opened != null or _quiet < _wait:
		return
	var footer_y: float = _roll.footer_node.get_global_rect().get_center().y
	if footer_y <= size.y * LAMP_LINE:
		return
	_drift_y += (DRIFT.y if LeadlightTokens.is_phone(shape) else DRIFT.x) * delta
	_scroll.scroll_vertical = int(_drift_y)


## Any touch, drag, wheel, key or pad press takes the roll over; the drift
## waits DRIFT_RESUME seconds after the last.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch \
			or event is InputEventScreenDrag or event is InputEventKey \
			or event is InputEventJoypadButton \
			or (event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask != 0):
		_took_over()


func _took_over(_focus: Control = null) -> void:
	_quiet = 0.0
	_wait = DRIFT_RESUME
	_drift_y = float(_scroll.scroll_vertical)


func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_took_over)


# ---------------------------------------------------------------- the licences

func _open_licence(which: StringName) -> void:
	if _sfx != null:
		_sfx.play_owed(&"paneRise", &"click")
	LeadlightFocus.give(_licences.open(which, shape, _scroll).scroll)


## Close an open licence glass (the seat's Return, Escape, a tap off it).
func close_licence() -> void:
	var glass: CreditsLicences.Glass = _licences.close(_scroll)
	if glass == null:
		return
	if _sfx != null:
		_sfx.play_owed(&"roomClose", &"click")
	LeadlightFocus.give(_roll.font_pane if glass == _licences.fonts else _roll.engine_pane)
	_took_over()


func open_licence() -> CreditsLicences.Glass:
	return _licences.opened


## The seat's Return and Escape close an open glass before the credits.
func leave() -> void:
	if _licences.opened != null:
		close_licence()
		return
	super()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _licences.opened != null:
		get_viewport().set_input_as_handled()
		close_licence()
		return
	super(event)


func _build_licence() -> void:
	_licences.build(&"engine", shape)


func _build_font_licences() -> void:
	_licences.build(&"fonts", shape)
