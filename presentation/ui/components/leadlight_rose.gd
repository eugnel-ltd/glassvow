class_name LeadlightRose
extends Button
## The six-pane Emberglass rose, set in the sealed door: each shard the Vigil
## holds lights its pane with the mural's own glass (the masks and shader the
## Rose Window uses); an empty door is dark tracery. With any shard held the
## rose is a way into the Rose Window (route `rose`); without, it is only
## glass and takes no focus.
##
## The Vigil's rose (`LeadlightRose.vigil`, docs/design/2026-10-03-title-rooms
## §4.1) is the same component with every pane in its state: dormant (dark
## glass), armed (pale glass with an ember "?"), revealed (lilac, a came round
## its outer rim carrying its progress, in whole figures), complete (the
## mural, breathing). The selected pane is rimmed in gold drawn from its own
## mask, never a box. The door's held map is that rose's complete-or-dark.

const MURAL: String = "res://assets/art/meta/emberglass-mural.png"
const FRAME: String = "res://assets/art/meta/emberglass-frame.png"
const MASK: String = "res://assets/art/meta/emberglass-mask-%s.png"
const PANE_SHADER: Shader = preload("res://presentation/run/rose_pane.gdshader")
const DARK_PANE: Color = Color(0.10, 0.12, 0.22, 0.85)
const SHARDS: Array[String] = [
	"eighthOmen", "hollowLamplighter", "ownShade", "paleOnes", "unreadablePage", "usurper",
]
const DORMANT: StringName = &"dormant"
const ARMED: StringName = &"armed"
const REVEALED: StringName = &"revealed"
const COMPLETE: StringName = &"complete"
## Each pane's glass, unlit: what the Rose Window has always filled it with.
const FILLS: Dictionary = {
	DORMANT: Color(0.44, 0.41, 0.57, 0.08), ARMED: Color(0.84, 0.88, 1.0, 0.18),
	REVEALED: Color(0.68, 0.57, 0.86, 0.28),
}
## Each pane's centre on the rose (0..1), from its mask's bounds.
const PANE_AT: Dictionary = {
	"paleOnes": Vector2(0.500, 0.284), "ownShade": Vector2(0.704, 0.342),
	"usurper": Vector2(0.704, 0.659), "eighthOmen": Vector2(0.500, 0.717),
	"unreadablePage": Vector2(0.296, 0.659), "hollowLamplighter": Vector2(0.296, 0.342),
}
## The tracery's ring, as a share of the rose's half side (the frame's art).
const RIM: float = 0.84
## A selected pane's gold rim: its mask grown about its own centre.
const RIM_GROW: float = 1.05
const RIM_ALPHA: float = 0.9

## 0..1: how much of the held glass is lit (the reveal brings it up).
var glow: float = 1.0:
	set(value):
		glow = value
		_apply()

## Extra light in the held panes and a warm halo round a rose that holds
## shards, 0..1. 0 is the phone's rose; the title raises it on pad and
## desktop, where the rose is larger and its panes must read lit.
var radiance: float = 0.0:
	set(value):
		radiance = value
		_apply()
		if _halo != null:
			_halo.queue_redraw()

## The Vigil's selected pane (an id of SHARDS), rimmed in gold; "" for none.
var selected: String = "":
	set(value):
		selected = value
		_place_rim(true)

var _lit: Array[TextureRect] = []
var _halo: _Halo = null
var _time: float = 0.0
var _held: int = 0
var _frame: TextureRect = null
## The Vigil's form: each pane's state and its (progress, target).
var _states: Dictionary = {}
var _counts: Dictionary = {}
var _armed: Array[TextureRect] = []
var _rim_gold: TextureRect = null
var _rim_dark: TextureRect = null
var _marks: _Marks = null
var _rim_tween: Tween = null


func _init(held: Array = []) -> void:
	flat = true
	clip_contents = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, empty)
	add_theme_stylebox_override("focus", _Ring.new())
	_halo = _Halo.new()
	_halo.rose = self
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_halo)
	var backing: _Disc = _Disc.new()
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	# A held pane shows the mural's own glass through the Rose Window's shader;
	# a dark pane loads nothing, so a fresh install (no shard) loads neither the
	# mural, the masks nor the shader on the launch path.
	var mural: Texture2D = load(MURAL) as Texture2D if not held.is_empty() else null
	for id: String in SHARDS:
		var path: String = MASK % id
		if not held.has(id) or not ResourceLoader.exists(path):
			# A dark pane is the backing disc showing through the tracery.
			continue
		var pane: TextureRect = _layer(load(path) as Texture2D)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = PANE_SHADER
		material.set_shader_parameter("mural", mural)
		material.set_shader_parameter("show_mural", true)
		material.set_shader_parameter("fill_colour", Color.TRANSPARENT)
		pane.material = material
		_lit.append(pane)
		_held += 1
	_frame = _layer(load(FRAME) as Texture2D)
	focus_mode = Control.FOCUS_ALL if _held > 0 else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if _held > 0 else Control.MOUSE_FILTER_IGNORE
	tooltip_text = Locale.active.t("ui.rose.openLabel") if _held > 0 else ""
	_apply()


func held_count() -> int:
	return _held


## Every pane's mask: the Vigil's rose loads all six (LeadlightRose.vigil), the
## door's only the held ones.
static func mask_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	for id: String in SHARDS:
		paths.append(MASK % id)
	return paths


## The Vigil's rose: `states` maps each shard id to its state, `counts` a
## revealed pane's id to (progress, target). Input-blind: the Rose Window
## lays its own pane hits over it.
static func vigil(states: Dictionary, counts: Dictionary) -> LeadlightRose:
	var rose: LeadlightRose = LeadlightRose.new([])
	rose._fill_states(states, counts)
	return rose


func state_of(id: String) -> StringName:
	return _states.get(id, DORMANT)


func _fill_states(states: Dictionary, counts: Dictionary) -> void:
	_counts = counts
	var mural: Texture2D = load(MURAL) as Texture2D
	_rim_gold = _layer(null)
	_rim_gold.self_modulate = Color(LeadlightTokens.GOLD, 0.0)
	_rim_dark = _layer(null)
	_rim_dark.self_modulate = Color(0.06, 0.07, 0.13, 1.0)
	for id: String in SHARDS:
		var state: StringName = states.get(id, DORMANT)
		_states[id] = state
		var pane: TextureRect = _layer(load(MASK % id) as Texture2D)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = PANE_SHADER
		material.set_shader_parameter("mural", mural)
		material.set_shader_parameter("show_mural", state == COMPLETE)
		material.set_shader_parameter("fill_colour", FILLS.get(state, Color.TRANSPARENT))
		pane.material = material
		if state == COMPLETE:
			_lit.append(pane)
			_held += 1
		elif state == ARMED:
			_armed.append(pane)
	move_child(_frame, get_child_count() - 1)
	_marks = _Marks.new()
	_marks.rose = self
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = ""
	_apply()


## The selected pane's rim: its mask in gold, grown about the pane's centre,
## under the mask in the backing's dark, under the pane itself.
func _place_rim(fade: bool = false) -> void:
	if _rim_gold == null:
		return
	var has: bool = PANE_AT.has(selected)
	_rim_gold.texture = load(MASK % selected) as Texture2D if has else null
	_rim_dark.texture = _rim_gold.texture
	if has:
		var centre: Vector2 = PANE_AT[selected]
		_rim_gold.pivot_offset = centre * size
		_rim_gold.scale = Vector2.ONE * RIM_GROW
	if _rim_tween != null:
		_rim_tween.kill()
	if fade and has and not LeadlightMotion.reduced():
		_rim_gold.self_modulate.a = 0.0
		_rim_tween = create_tween()
		_rim_tween.tween_interval(0.04)
		_rim_tween.tween_property(_rim_gold, "self_modulate:a", RIM_ALPHA, 0.18) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	else:
		_rim_gold.self_modulate.a = RIM_ALPHA if has else 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _halo != null:
		_halo.position = Vector2.ZERO
		_halo.size = size
	if what == NOTIFICATION_RESIZED and _rim_gold != null and PANE_AT.has(selected):
		var centre: Vector2 = PANE_AT[selected]
		_rim_gold.pivot_offset = centre * size


func _layer(texture: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


## Held glass breathes at rest, a slow pulse a little above its own light;
## still under Reduce Motion.
func _process(delta: float) -> void:
	if (_lit.is_empty() and _states.is_empty()) or LeadlightMotion.reduced():
		return
	_time += delta
	_apply()
	if _marks != null:
		_marks.queue_redraw()


func _apply() -> void:
	var swell: float = 0.5 + 0.5 * LeadlightMotion.breath(_time, 4.2)
	var pulse: float = 1.0 + 0.9 * radiance + (0.16 + 0.24 * radiance) * swell
	for pane: TextureRect in _lit:
		pane.modulate = Color(pulse, pulse, pulse, 0.25 + 0.75 * glow)
	# An armed pane pulses every 4.2 s: something is waiting in it.
	var waiting: float = 0.78 + 0.22 * (0.5 + 0.5 * LeadlightMotion.breath(_time + 2.1, 4.2))
	for pane: TextureRect in _armed:
		pane.modulate = Color(waiting, waiting, waiting, 0.25 + 0.75 * glow)
	if _halo != null and radiance > 0.0:
		_halo.swell = swell
		_halo.queue_redraw()


## The warm halo round a rose that holds light, drawn additively behind it.
class _Halo extends Control:
	var rose: LeadlightRose = null
	var swell: float = 0.0

	func _init() -> void:
		var mat: CanvasItemMaterial = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _draw() -> void:
		if rose == null or rose.radiance <= 0.0 or rose.held_count() == 0:
			return
		var c: Vector2 = rose.size * 0.5
		var r: float = minf(rose.size.x, rose.size.y) * (0.95 + 0.06 * swell)
		var share: float = float(rose.held_count()) / 6.0
		draw_texture_rect(SkyField.disc(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(Color("#ffd99a"), rose.radiance * (0.10 + 0.22 * share) * (0.85 + 0.3 * swell)))


class _Disc extends Control:
	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.46
		draw_circle(size * 0.5, r, Color(0.027, 0.035, 0.07, 0.92))
		draw_circle(size * 0.5, r * 0.9, Color(DARK_PANE, 0.55))


class _Ring extends StyleBox:
	func _draw(ci: RID, rect: Rect2) -> void:
		var c: Vector2 = rect.get_center()
		var r: float = minf(rect.size.x, rect.size.y) * 0.5 + 4.0
		var points: PackedVector2Array = LeadlightShapes.arc_points(c, Vector2(r, r), 0.0, TAU, 49)
		RenderingServer.canvas_item_add_polyline(ci, points,
			PackedColorArray([Color(LeadlightTokens.GOLD, 0.9)]), 1.6, true)


## A revealed pane's came and its count, an armed pane's ember "?": drawn over
## the tracery, in the rose's own pixels.
class _Marks extends Control:
	var rose: LeadlightRose = null

	func _draw() -> void:
		if rose == null:
			return
		var half: float = minf(rose.size.x, rose.size.y) * 0.5
		var centre: Vector2 = rose.size * 0.5
		var phone: bool = half < 160.0
		var px: int = 12 if phone else 18
		var font: Font = LeadlightTokens.font(LeadlightTokens.ROLE_CARVED, px)
		for id: String in SHARDS:
			var state: StringName = rose.state_of(id)
			var share: Vector2 = PANE_AT[id]
			var at: Vector2 = share * rose.size
			if state == REVEALED:
				var count: Vector2i = rose._counts.get(id, Vector2i(0, 1))
				var angle: float = (at - centre).angle()
				var arc: PackedVector2Array = LeadlightShapes.arc_points(centre,
					Vector2.ONE * half * RIM * 0.93, angle - deg_to_rad(23.0), angle + deg_to_rad(23.0), 17)
				LeadlightCame.draw_came(self, arc, float(count.x) / float(maxi(count.y, 1)), false,
					rose._time)
				_centred(font, px, at, "%d / %d" % [count.x, count.y],
					Color(LeadlightTokens.GOLD, 0.92))
			elif state == ARMED:
				var big: int = 26 if phone else 40
				var flicker: float = 0.82 + 0.18 * sin(rose._time * 7.3) * sin(rose._time * 2.9 + 1.0)
				_centred(LeadlightTokens.font(LeadlightTokens.ROLE_PRIMARY, big), big, at, "?",
					Color(LeadlightTokens.EMBER, 0.85 * flicker))

	func _centred(font: Font, px: int, at: Vector2, text: String, colour: Color) -> void:
		var wide: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var base: Vector2 = at + Vector2(-wide.x * 0.5, font.get_ascent(px) * 0.5 - font.get_descent(px) * 0.3)
		draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4,
			Color(LeadlightTokens.VOID, 0.75))
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, colour)
