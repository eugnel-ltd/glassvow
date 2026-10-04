class_name VigilScreen
extends LeadlightRoomHost
## The Vigil is the hearth hall (docs/design/2026-10-03-title-rooms §4.1): the
## hearth at the road's west end, where the Keeper keeps his seat by the fire.
## Choosing it from the title turns you back to it (V1): the road turns away,
## the hall comes in from the west, the fire catches and answers the lantern
## as it is set down at the seat, and the word that was tapped becomes the
## hall's crown. Its three tabs are three looks across the one hall (VigilHall):
## to the hearth (the deeds, VigilDeeds), up to the window (the Rose Window,
## RoseWindowView) and down to the floor before the fire (the epitaphs). The
## header never moves between looks: the crown, a carved ledger of the
## pilgrimages, and the look panes.
##
## A place, as Credits is: no veil to tap; the seat's Return and Escape leave
## (V3, the turn east). Every entry is a route (Main): from the title the title
## is held under it; anywhere else it is the route alone, with the seat's word
## and no lantern. The music cue comes after Main connects (`announce`).

signal back_requested
signal cue_requested(cue: StringName)
signal replay_requested

const DEED_IDS: PackedStringArray = [
	"paneBreaker", "lanternFed", "ashSermon", "untouched",
	"darkWalker", "spendthrift", "faultInGlass", "hundredShards", "firstDawn",
]
static func _whisper_lines() -> Array:
	var lines: Array = []
	for index: int in range(24):
		lines.append(Locale.active.whisper(index))
	return lines

## The column (pad and desktop, phone), stage px: its left, the crown's and
## the ledger's tops, the look panes' top and their right margin, the body's
## top and how far above the stage's foot it ends, its widest, and its least
## gap to the Keeper.
const LEFT: Vector2 = Vector2(260.0, 112.0)
const CROWN_Y: Vector2 = Vector2(26.0, 4.0)
const LEDGER_Y: Vector2 = Vector2(62.0, 26.0)
const PANES_Y: Vector2 = Vector2(96.0, 6.0)
const PANES_RIGHT: Vector2 = Vector2(40.0, 10.0)
const BODY_TOP: Vector2 = Vector2(168.0, 62.0)
const BODY_FOOT: Vector2 = Vector2(90.0, 60.0)
const COLUMN_MAX: float = 640.0
const KEEPER_GAP: float = 40.0
## A look change (V4): the old look goes, the new rises in, staggered.
const LOOK_OUT: float = 0.18
const LOOK_IN_FROM: float = 0.14
const LOOK_IN: float = 0.34
const STAGGER: float = 0.04
## The passage's first frames, while the room is still being laid out.
const STEP_ONE: float = 0.034
## A group rising in the firelight: how long it takes. On a cubic's ease, not
## the quint's: the rose and its glass are large, and a quint's first frame
## brought a third of either in at once.
const RISE: float = 0.26

var _vigil: VigilState
var _content: ContentDB
var _has_rose: bool
var _open_rose: bool
var _sfx: SfxBus
## Main's Reduce Motion cross-fade, for a look change (the plate jumps under it).
var cross_fade: Callable = Callable()
var _hall: VigilHall
var _crown: Label
var _ledger: Label
var _looks: HBoxContainer
var _deeds_tab: LeadlightPane
var _rose_tab: LeadlightPane = null
var _epitaph_tab: LeadlightPane = null
var _deed_list: VigilDeeds
var _epitaph_list: VigilEpitaphs = null
var _rose: RoseWindowView = null
var _look: StringName = VigilHall.DEEDS
var _landed: bool = false
var _answered: bool = false
var _time: float = 0.0
## The look change under way: its clock, the nodes going and coming.
var _change: float = -1.0
var _going: Array[Control] = []
var _coming: Array[Control] = []
var _plate_at: Vector2 = Vector2.ZERO
var _rise_order: Array[Control] = []


func _init(vigil: VigilState, content: ContentDB,
		stage_shape: StringName = StageShape.IDENTITY,
		open_rose: bool = false, sfx: SfxBus = null) -> void:
	_vigil = vigil
	_content = content
	_has_rose = vigil.unlocks.has("emberglass")
	_open_rose = open_rose
	_host(stage_shape)
	veil_closes = false
	veil().color = Color(LeadlightTokens.VOID, 0.0)
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_hall = VigilHall.new(shape)
	add_child(_hall)
	_build()
	closed.connect(func() -> void: back_requested.emit())
	_seat_last()


func _build() -> void:
	_crown = _text(Locale.active.t("ui.vigil.title"), LeadlightTokens.ROLE_PRIMARY,
		LeadlightTokens.SIZE_ROOM_CROWN, LeadlightTokens.GOLD)
	_crown.name = "Crown"
	add_child(_crown)
	_ledger = _text(Locale.active.t("ui.vigil.stats", {
		"runs": LeadlightNumerals.carved_drawn(_deed("runs")),
		"wins": LeadlightNumerals.carved_drawn(_deed("wins")),
		"vow": LeadlightNumerals.carved_drawn(_deed("bestVow")) if _deed("bestVow") > 0 else "—",
	}), LeadlightTokens.ROLE_CARVED, LeadlightTokens.SIZE_ROOM_CARVED, Color(LeadlightTokens.GOLD, 0.7))
	_ledger.name = "Ledger"
	add_child(_ledger)
	_looks = HBoxContainer.new()
	_looks.name = "Looks"
	_looks.add_theme_constant_override("separation", 10)
	_looks.minimum_size_changed.connect(_fit)
	add_child(_looks)
	_deeds_tab = _tab(Locale.active.t("ui.vigil.deedsTab"), _show_deeds)
	if _has_rose:
		_rose_tab = _tab(Locale.active.t("ui.vigil.roseTab"), _show_rose)
	if not _vigil.defeat_epitaphs.is_empty():
		_epitaph_tab = _tab(Locale.active.t("ui.vigil.epitaphTab"), _show_epitaphs)
	_deed_list = VigilDeeds.new(_vigil, _content, DEED_IDS, shape)
	add_child(_deed_list)
	if not _vigil.defeat_epitaphs.is_empty():
		_epitaph_list = VigilEpitaphs.new(_vigil, _content, shape)
		_epitaph_list.visible = false
		add_child(_epitaph_list)
	_look = VigilHall.ROSE if _open_rose and _has_rose else VigilHall.DEEDS
	if _look == VigilHall.ROSE:
		_build_rose()
	_hall.look_to(_look, false)
	_settle_look()
	set_shape(shape)


func _deed(key: String) -> int:
	return maxi(0, int(float(str(_vigil.deeds.get(key, 0)))))


## The look panes' order is the hall's: the hearth, the window, the floor.
func _tab(text: String, callback: Callable) -> LeadlightPane:
	var pane: LeadlightPane = LeadlightPane.new(text, shape)
	pane.pressed.connect(_choose_look.bind(callback))
	_looks.add_child(pane)
	return pane


## The Rose look is built when it is first wanted (§12: the tap frame builds
## only the look on view).
func _build_rose() -> void:
	if _rose != null or not _has_rose:
		return
	_rose = RoseWindowView.new(
		_vigil.quests, _content.quests, _vigil.whispers, _whisper_lines(), shape)
	_rose.replay_requested.connect(func() -> void: replay_requested.emit())
	_rose.pane_chosen.connect(func(complete: bool) -> void:
		_sfx.play_owed(&"glassTakesLight" if complete else &"paneChoose", &"click"))
	if _rose.replay() != null:
		# V6: the whole rose takes the light as the unsealing is called back.
		_rose.replay().pressed.connect(func() -> void: _sfx.play_owed(&"glassTakesLight", &"click"))
	_rose.visible = false
	add_child(_rose)
	move_child(_rose, _deed_list.get_index())
	_fit()


# ---------------------------------------------------------------- the looks

## The cue for the look on view, once Main has connected (the first cue of the
## Vigil is the Rose Window's when it opens on the rose).
func announce() -> void:
	cue_requested.emit(&"roseWindow" if _look == VigilHall.ROSE else &"vigil")


func _show_deeds() -> void:
	_look_to(VigilHall.DEEDS)
	cue_requested.emit(&"vigil")


func _show_rose() -> void:
	if not _has_rose:
		return
	_build_rose()
	_look_to(VigilHall.ROSE)
	cue_requested.emit(&"roseWindow")


func _show_epitaphs() -> void:
	if _epitaph_list == null:
		return
	_look_to(VigilHall.EPITAPHS)
	cue_requested.emit(&"vigil")


## A look pane tapped: its sound, the cross-fade under Reduce Motion, the look.
func _choose_look(callback: Callable) -> void:
	_sfx.play_owed(&"paneChoose", &"click")
	if LeadlightMotion.reduced() and cross_fade.is_valid():
		cross_fade.call()
	callback.call()


func look() -> StringName:
	return _look


func hall() -> VigilHall:
	return _hall


func rose_view() -> RoseWindowView:
	return _rose


## V4: the plate moves to the new framing, the old look drifts with it and
## goes, the new one rises in. At once off the tree, before landing, and under
## Reduce Motion (a cross-fade covers it there).
func _look_to(to: StringName) -> void:
	if to == _look and _change < 0.0:
		_style_tabs()
		return
	var animate: bool = _landed and is_inside_tree() and not LeadlightMotion.reduced()
	_finish_change()
	var going: Array[Control] = _look_nodes(_look)
	_look = to
	_hall.look_to(to, animate)
	_fit()
	if not animate:
		_settle_look()
		return
	_going = going
	_coming = _look_nodes(to)
	_plate_at = _hall.plate().position
	for node: Control in _coming:
		node.visible = true
		_reveal(node, 0.0)
	_change = 0.0
	_style_tabs()


func _look_nodes(which: StringName) -> Array[Control]:
	var nodes: Array[Control] = []
	if which == VigilHall.ROSE and _rose != null:
		nodes.append(_rose)
	elif which == VigilHall.EPITAPHS and _epitaph_list != null:
		nodes.append(_epitaph_list)
	elif which == VigilHall.DEEDS:
		nodes.append(_deed_list)
	return nodes


## Only the look on view is shown, whole.
func _settle_look() -> void:
	for node: Control in [_deed_list, _epitaph_list, _rose]:
		if node != null:
			node.visible = _look_nodes(_look).has(node)
			_reveal(node, 1.0)
	_style_tabs()


func _finish_change() -> void:
	if _change < 0.0:
		return
	_change = -1.0
	_going.clear()
	_coming.clear()
	_settle_look()


func _step_change(delta: float) -> void:
	_change += delta
	var drift: Vector2 = (_hall.plate().position - _plate_at) * 0.6
	# The old look answers at once: on EXIT's slow start it stood whole while
	# the plate had already moved.
	var out: float = 1.0 - LeadlightMotion.ease_on(_change / LOOK_OUT, LeadlightMotion.SETTLE_OUT)
	for node: Control in _going:
		node.modulate.a = out
		RenderingServer.canvas_item_set_transform(node.get_canvas_item(), node.get_transform().translated(drift))
	for i: int in _coming.size():
		var from: float = LOOK_IN_FROM + STAGGER * float(i)
		_reveal(_coming[i], LeadlightMotion.ease_on((_change - from) / LOOK_IN, LeadlightMotion.SETTLE_OUT))
	if _change >= VigilHall.MOVE_TIME:
		_finish_change()


func _style_tabs() -> void:
	for pair: Array in [[_deeds_tab, VigilHall.DEEDS], [_rose_tab, VigilHall.ROSE],
			[_epitaph_tab, VigilHall.EPITAPHS]]:
		var pane: LeadlightPane = pair[0]
		if pane != null:
			pane.lit = _look == pair[1]


func _tab_for(which: StringName) -> LeadlightPane:
	match which:
		VigilHall.ROSE:
			return _rose_tab
		VigilHall.EPITAPHS:
			return _epitaph_tab
	return _deeds_tab


# ---------------------------------------------------------------- the room

func crown() -> Control:
	return _crown


## The lit look pane takes the focus on arrival (hidden for a touch).
func first_focus() -> Control:
	var pane: LeadlightPane = _tab_for(_look)
	return pane if pane != null else super()


## The header, then the look on view, nearest the fire first: what the
## firelight reaches as the hall comes in.
func reveal_groups() -> Array[Control]:
	var groups: Array[Control] = [_ledger, _looks]
	if _look == VigilHall.DEEDS:
		groups.append_array(_deed_list.rows())
	elif _look == VigilHall.ROSE and _rose != null:
		groups.append_array(_rose.parts())
	elif _epitaph_list != null:
		groups.append(_epitaph_list)
	return groups


## Where the look's content stands, and the header's: clear of the seat.
func content_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = [_crown.get_rect(), _ledger.get_rect(), _looks.get_rect()]
	if _look == VigilHall.ROSE and _rose != null:
		rects.append_array(_rose.content_rects())
	elif _look == VigilHall.EPITAPHS and _epitaph_list != null:
		rects.append(_epitaph_list.get_rect())
	else:
		rects.append(_deed_list.get_rect())
	return rects


func body_rect(which: StringName) -> Rect2:
	return body_for(size, which, shape)


## The body box of `which` look on a stage of `stage` size: from the column's
## left to the Keeper's left less a gap, at most COLUMN_MAX wide. Pure.
static func body_for(stage: Vector2, which: StringName, stage_shape: StringName) -> Rect2:
	var phone: bool = LeadlightTokens.is_phone(stage_shape)
	var left: float = LEFT.y if phone else LEFT.x
	var keeper: Rect2 = VigilHall.keeper_on_stage(VigilHall.frame(stage, which, stage_shape))
	var right: float = minf(left + COLUMN_MAX, keeper.position.x - KEEPER_GAP)
	var top: float = BODY_TOP.y if phone else BODY_TOP.x
	var foot: float = stage.y - (BODY_FOOT.y if phone else BODY_FOOT.x)
	return Rect2(left, top, maxf(right - left, 0.0), maxf(foot - top, 0.0))


func arrival_time() -> float:
	return 0.60


func departure_time() -> float:
	return 0.48


## The content behind the crown's path home is dark by then.
func crown_leaves_at() -> float:
	return 0.12


func furniture_returns_at() -> float:
	return 0.20


## Opened on the rose from the title, the rose's own sound (relic) is the tap's.
func opening_cue() -> StringName:
	return &"" if _open_rose and title != null else &"roomOpen"


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	_hall.set_shape(shape)
	for label: Label in [_crown, _ledger]:
		_size(label)
	if _epitaph_list != null:
		_epitaph_list.set_shape(shape)
	for pane: Node in _looks.get_children():
		var tab: LeadlightPane = pane
		tab.set_px(LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_LABEL, shape))
		tab.hit_height = LeadlightTokens.room_hit(shape)
		tab.custom_minimum_size.y = 34.0 if LeadlightTokens.is_phone(shape) else 52.0
	_deed_list.set_shape(shape)
	if _rose != null:
		_rose.set_shape(shape)
	super(stage_shape)


func _fit() -> void:
	if _crown == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var phone: bool = LeadlightTokens.is_phone(shape)
	var left: float = LEFT.y if phone else LEFT.x
	_crown.size = _crown.get_combined_minimum_size()
	_crown.position = Vector2(left, CROWN_Y.y if phone else CROWN_Y.x)
	_looks.size = _looks.get_combined_minimum_size()
	_looks.position = Vector2(size.x - (PANES_RIGHT.y if phone else PANES_RIGHT.x) - _looks.size.x,
		PANES_Y.y if phone else PANES_Y.x)
	_ledger.size = _ledger.get_combined_minimum_size()
	_ledger.position = Vector2(left, LEDGER_Y.y if phone else LEDGER_Y.x)
	# On a phone the ledger shares its row with the look panes: where it would
	# run under them, it stands under their row instead, above the body.
	if phone and Rect2(_ledger.position, _ledger.size).intersects(
			Rect2(_looks.position, _looks.size).grow_individual(6.0, 0.0, 6.0, 0.0)):
		_ledger.position.y = _looks.position.y + _looks.size.y + 2.0
	var body: Rect2 = body_rect(VigilHall.DEEDS)
	_deed_list.position = body.position
	_deed_list.size = body.size
	if _epitaph_list != null:
		_epitaph_list.fit(body_rect(VigilHall.EPITAPHS))
	if _rose != null:
		_rose.position = Vector2.ZERO
		_rose.size = size
	# On the Rose look the band holds the header only: the rose and its glass
	# carry their own dark.
	_hall.set_band(body_rect(_look).end.x if _look != VigilHall.ROSE else left + (160.0 if phone else 260.0))


# ---------------------------------------------------------------- the passage

## V1, the turn west: the road turns away (the title's own lane), the hall
## comes in from the west over it, the fire catches and answers the lantern as
## it is set down, and the header and the look rise as the firelight reaches
## them, from the hearth's side.
func arrive_at(t: float, _wick: Vector2, _colour: Color) -> void:
	_landed = false
	var came: float = LeadlightMotion.ease_on(t / 0.42, LeadlightMotion.SETTLE_OUT)
	_hall.modulate.a = came
	_hall.slide = -VigilHall.TURN * size.x * (1.0 - came)
	_hall.fire = LeadlightMotion.ease_on((t - 0.2) / 0.4, LeadlightMotion.SETTLE_OUT)
	if t >= 0.48 and not _answered:
		_answered = true
		_hall.answer()
	if title != null:
		title.turn(LeadlightMotion.ease_on(t / 0.40, LeadlightMotion.SETTLE_OUT))
		# The hall stands whole over the road from here: the road is held now,
		# not at the landing, so the two are never drawn together for nothing.
		if came >= 1.0 and not left():
			title.hold_world(true)
	# The order the light reaches them in, found once the room is laid out.
	if _rise_order.size() != reveal_groups().size() or t <= STEP_ONE:
		_rise_order = _by_the_light(reveal_groups(), _look == VigilHall.ROSE)
	var groups: Array[Control] = _rise_order
	for i: int in groups.size():
		var from: float = minf(maxf(0.16 + STAGGER * float(i), _clear_of_ghost(groups[i])), arrival_time() - RISE)
		_reveal(groups[i], LeadlightMotion.ease_on((t - from) / RISE, LeadlightMotion.SETTLE_OUT))
	_deed_list.rail = _looks.modulate.a


## The hall whole and the title's road held under it (hidden and paused).
func rest(_wick: Vector2, _colour: Color) -> void:
	_hall.modulate.a = 1.0
	_hall.slide = 0.0
	_hall.fire = 1.0
	for group: Control in reveal_groups():
		_reveal(group, 1.0)
	_deed_list.rail = 1.0
	if title != null and not left():
		title.turn(1.0)
		title.hold_world(true)
	_landed = true


## V3, the turn east: the look and the header go at once, the hall slides
## back west and fades, and the road turns back into view under it.
func leave_at(t: float, _wick: Vector2, _colour: Color) -> void:
	_landed = false
	_finish_change()
	var gone: float = LeadlightMotion.ease_on(t / 0.20, LeadlightMotion.SETTLE_OUT)
	for group: Control in reveal_groups():
		_reveal(group, 1.0 - gone, false)
	_deed_list.rail = 1.0 - gone
	var away: float = LeadlightMotion.ease_on(t / 0.36, LeadlightMotion.SETTLE_OUT)
	_hall.slide = -VigilHall.TURN * size.x * away
	_hall.modulate.a = 1.0 - away
	# Gone from sight: no longer drawn over the road for the frames left.
	_hall.visible = away < 1.0
	if title != null:
		title.turn(1.0 - LeadlightMotion.ease_on((t - 0.04) / 0.40, LeadlightMotion.SETTLE_OUT))


func title_returns() -> void:
	if title != null:
		title.turn(0.0)


## The groups nearest the light first: the hearth (the stage's right), or on
## the Rose look the window (its left), where the rose you came for stands.
static func _by_the_light(groups: Array[Control], window: bool) -> Array[Control]:
	var sorted: Array[Control] = groups.duplicate()
	sorted.sort_custom(func(a: Control, b: Control) -> bool:
		var ar: Rect2 = a.get_global_rect()
		var br: Rect2 = b.get_global_rect()
		if window:
			return ar.position.x + ar.position.y * 0.5 < br.position.x + br.position.y * 0.5
		return ar.end.x + ar.position.y * 0.5 > br.end.x + br.position.y * 0.5)
	return sorted


# ---------------------------------------------------------------- at rest

func _process(delta: float) -> void:
	_time += delta
	if _change >= 0.0:
		_step_change(delta)
	var held: bool = LeadlightMotion.reduced()
	_deed_list.glow = 1.0 if held else _hall.flicker()
	if _epitaph_list != null:
		_epitaph_list.fire = _hall.flicker()


func _text(text: String, role: StringName, token: Vector2i, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta(&"role", role)
	label.set_meta(&"token", token)
	label.add_theme_color_override("font_color", colour)
	_size(label)
	return label


func _size(label: Label) -> void:
	var token: Vector2i = label.get_meta(&"token")
	var role: StringName = label.get_meta(&"role")
	var px: int = LeadlightTokens.size_for(token, shape)
	label.add_theme_font_override("font", LeadlightTokens.font(role, px))
	label.add_theme_font_size_override("font_size", px)
