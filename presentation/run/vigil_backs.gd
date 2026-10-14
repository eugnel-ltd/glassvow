class_name VigilBacks
extends Control
## The Backs look of the Vigil's hall (#657 PR 7; docs/design/
## 2026-10-03-cards-real-objects §5.4): the card backs on a shelf by the
## fire, every back a card. An earned back stands as itself, a live card (its
## lamp and tilt under the finger, its stage released at rest, CardView), and
## is chosen with a tap, a click or its key; the back in use stands raised,
## with IN USE under its name. A back not yet earned stands as a silhouette of
## a card with the deed that earns it under it, and takes no choice.
##
## Choosing is the hall's to carry out: this look says which (`chosen`), and
## Main stores it and wears it on the table at once (CardTurn.choose). The
## catalogue and the unlocks are CardBacks' own reads of the Vigil; nothing
## here writes the Vigil, a run or a save.
##
## Built when the look is first wanted (VigilScreen, as the Rose look is): an
## earned back's first card compiles its picture there, in the tap's frame.

signal chosen(id: String)

## The card's widest (pad, phone), stage px, and the least it shrinks to.
const CARD_W: Vector2 = Vector2(132.0, 84.0)
const CARD_MIN: float = 64.0
## The gap between two backs (pad, phone).
const GAP: Vector2 = Vector2(36.0, 20.0)
## How far the back in use stands raised (pad, phone), and how long it takes.
const LIFT: Vector2 = Vector2(12.0, 7.0)
const LIFT_TIME: float = 0.24
## A silhouette: the dark of a card unlit, its rim in dim gold.
const SILHOUETTE_FILL: Color = Color(LeadlightTokens.VOID, 0.82)
const SILHOUETTE_RIM: Color = Color(LeadlightTokens.GOLD_DIM, 0.5)

var shape: StringName = StageShape.IDENTITY
var _vigil: VigilState
var _in_use: String = ""
var _row: HBoxContainer
var _slots: Array[_Slot] = []


## One back on the shelf: its seat, its card (or silhouette), its words.
class _Slot:
	extends VBoxContainer
	var id: String = ""
	var earned: bool = false
	var seat: Control
	var face: Control
	var key: Button
	var name_label: Label
	var line: Label
	## The card's top-left at rest in its seat, before the lift.
	var base: Vector2 = Vector2.ZERO
	var lift_tween: Tween = null


func _init(vigil: VigilState, stage_shape: StringName = StageShape.IDENTITY) -> void:
	name = "Backs"
	_vigil = vigil
	shape = stage_shape
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_in_use = CardBacks.chosen(Preferences.active, vigil)
	var cat: CardBackCatalogue = CardBacks.catalogue()
	for i: int in cat.ids().size():
		var id: String = cat.ids()[i]
		_slots.append(_slot(id, cat.is_unlocked(id, vigil), 9300 + i))
	set_shape(shape)


func _slot(id: String, earned: bool, uid: int) -> _Slot:
	var slot: _Slot = _Slot.new()
	slot.id = id
	slot.earned = earned
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.alignment = BoxContainer.ALIGNMENT_BEGIN
	slot.add_theme_constant_override("separation", 6)
	slot.seat = Control.new()
	slot.seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.seat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.add_child(slot.seat)
	if earned:
		var card: CardView = CardBacks.build(id, uid)
		card.releases_at_rest = true
		card.released_at.connect(func(_u: int, _p: Vector2) -> void: _pick(id))
		slot.face = card
	else:
		slot.face = _Silhouette.new()
	slot.seat.add_child(slot.face)
	slot.key = Button.new()
	slot.key.flat = true
	# The pointer reaches the card under it (its lamp); the key is the keyboard's.
	slot.key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for state: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		slot.key.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	slot.key.add_theme_stylebox_override("focus", GlassStyle.focus_ring(LeadlightTokens.GOLD, CardView.RADIUS))
	slot.key.pressed.connect(_pick.bind(id))
	slot.seat.add_child(slot.key)
	slot.name_label = _label(Locale.active.t("ui.back.%s.name" % id), LeadlightTokens.ROLE_CARVED)
	slot.add_child(slot.name_label)
	slot.line = _label("", LeadlightTokens.ROLE_READ)
	slot.line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.add_child(slot.line)
	_row.add_child(slot)
	return slot


func _label(text: String, role: StringName) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_meta(&"role", role)
	label.add_theme_color_override("font_shadow_color", Color(LeadlightTokens.VOID, 0.85))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 3)
	return label


## A tap, a click or a key on a back: an earned back not in use is chosen.
func _pick(id: String) -> void:
	var slot: _Slot = _slot_of(id)
	if slot == null or not slot.earned or id == _in_use:
		return
	_in_use = id
	_dress(true)
	chosen.emit(id)


func _slot_of(id: String) -> _Slot:
	for slot: _Slot in _slots:
		if slot.id == id:
			return slot
	return null


## The back in use: the one raised, IN USE under its name.
func in_use() -> String:
	return _in_use


## The backs, in the catalogue's order: what the firelight reaches.
func slots() -> Array[Control]:
	var out: Array[Control] = []
	for slot: _Slot in _slots:
		out.append(slot)
	return out


## Whether `id` stands on the shelf earned (a live card) or as a silhouette.
func is_earned(id: String) -> bool:
	var slot: _Slot = _slot_of(id)
	return slot != null and slot.earned


## The key of the back in use: where the keyboard starts on this look.
func first_key() -> Control:
	var slot: _Slot = _slot_of(_in_use)
	return slot.key if slot != null else null


## The shelf stands centred in the hall's body box.
func fit(box: Rect2) -> void:
	position = box.position
	size = box.size
	_lay_out()


func set_shape(stage_shape: StringName) -> void:
	shape = stage_shape
	for slot: _Slot in _slots:
		for label: Label in [slot.name_label, slot.line]:
			var role: StringName = label.get_meta(&"role")
			var token: Vector2i = LeadlightTokens.SIZE_ROOM_LABEL if role == LeadlightTokens.ROLE_CARVED \
				else LeadlightTokens.SIZE_ROOM_READ
			var px: int = LeadlightTokens.size_for(token, shape)
			label.add_theme_font_override("font", LeadlightTokens.font(role, px))
			label.add_theme_font_size_override("font_size", px)
	_lay_out()


func _lay_out() -> void:
	var phone: bool = LeadlightTokens.is_phone(shape)
	var gap: float = GAP.y if phone else GAP.x
	var n: int = maxi(_slots.size(), 1)
	var w: float = clampf(size.x / float(n) - gap, CARD_MIN, CARD_W.y if phone else CARD_W.x)
	var k: float = w / CardView.CARD_W
	var lift: float = LIFT.y if phone else LIFT.x
	var card: Vector2 = Vector2(CardView.CARD_W, CardView.CARD_H) * k
	# Each back's words may use the gap beside its card: a deed set at the
	# card's own width broke a short zh line in two on the phone.
	_row.add_theme_constant_override("separation", 0)
	for slot: _Slot in _slots:
		slot.custom_minimum_size.x = w + gap
		# The seat holds the card and the room it rises into.
		slot.seat.custom_minimum_size = card + Vector2(0.0, lift)
		slot.face.scale = Vector2(k, k)
		# Scaled about its centre (CardView's own pivot), so offset by half the change.
		slot.base = Vector2(CardView.CARD_W, CardView.CARD_H) * (k - 1.0) * 0.5
		slot.key.size = card
		slot.line.custom_minimum_size.x = w + gap
	_row.size = Vector2(size.x, 0.0)
	_row.position = Vector2.ZERO
	_row.reset_size()
	_row.size.x = size.x
	# Centred in the box's height, as the epitaphs are when few.
	_row.position.y = maxf(0.0, (size.y - _row.get_combined_minimum_size().y) * 0.5)
	_dress(false)


## Words and lift for every back: IN USE under the one in use, the deed under
## a silhouette, nothing under the others. `animate` eases the lift.
func _dress(animate: bool) -> void:
	var lift: float = LIFT.y if LeadlightTokens.is_phone(shape) else LIFT.x
	var moving: bool = animate and is_inside_tree() and not LeadlightMotion.reduced()
	for slot: _Slot in _slots:
		var used: bool = slot.id == _in_use
		var text: String = ""
		var colour: Color = LeadlightTokens.TEXT_DIM
		if used:
			text = Locale.active.t("ui.back.inUse")
			colour = LeadlightTokens.GOLD
		elif not slot.earned:
			text = Locale.active.t("ui.back.%s.deed" % slot.id)
		slot.line.text = text
		slot.line.add_theme_color_override("font_color", colour)
		slot.name_label.add_theme_color_override("font_color",
			LeadlightTokens.PARCHMENT if slot.earned else LeadlightTokens.TEXT_DIM)
		slot.key.tooltip_text = "%s · %s" % [slot.name_label.text, text] if text != "" else slot.name_label.text
		var to: float = lift * (0.0 if used else 1.0)
		var home: Vector2 = slot.base + Vector2(0.0, to)
		slot.key.position = Vector2(0.0, to)
		if slot.lift_tween != null and slot.lift_tween.is_valid():
			slot.lift_tween.kill()
		if moving:
			slot.lift_tween = slot.face.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			slot.lift_tween.tween_property(slot.face, "position", home, LIFT_TIME)
		else:
			slot.face.position = home


## A back not yet earned: the dark shape of a card, its rim in dim gold.
## Drawn at the card's own size; the slot scales it as it scales a card.
class _Silhouette:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(CardView.CARD_W, CardView.CARD_H)
		pivot_offset = size * 0.5

	func _draw() -> void:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = SILHOUETTE_FILL
		box.border_color = SILHOUETTE_RIM
		box.set_border_width_all(2)
		box.set_corner_radius_all(CardView.RADIUS)
		box.anti_aliasing = true
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		# The card's inner rule, as its stock would carry it, fainter.
		var inner: StyleBoxFlat = StyleBoxFlat.new()
		inner.draw_center = false
		inner.border_color = Color(SILHOUETTE_RIM, 0.35)
		inner.set_border_width_all(1)
		inner.set_corner_radius_all(CardView.RADIUS - 4)
		draw_style_box(inner, Rect2(Vector2(9.0, 9.0), size - Vector2(18.0, 18.0)))
