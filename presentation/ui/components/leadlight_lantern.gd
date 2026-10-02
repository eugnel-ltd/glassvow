class_name LeadlightLantern
extends Button
## The primary action: the hero's lantern. Its art is the HUD lantern repainted
## at hero size and registered to the same set-out, so `LanternFlame` lights it
## with the same shader and the same reading as the combat HUD (the title shows
## the saved run's real `Flame.read`). Tap the flame: Back to the Road, or
## Rekindle. `kindle` (0..1) carries the launch rite: 0 is a cold lantern with
## one ember; 1 is the lit lantern throwing its light.

const ART: String = "res://assets/art/title/lantern-hero.png"
const ART_FALLBACK: String = "res://assets/art/ui/lantern.png"
## The wick and the glass in the art's own UV (lantern_flame.gdshader set-out).
const WICK_UV: Vector2 = Vector2(0.5, 0.785)
const GLASS_CENTRE_UV: Vector2 = Vector2(0.5, 0.63)
const COLD_TINT: Color = Color(0.17, 0.17, 0.21, 1.0)

var flame: LanternFlame
var kindle: float = 1.0:
	set(value):
		kindle = value
		_apply_kindle()
## 0..1 extra brightness for the press flare and the flood hand-off.
var flare: float = 0.0:
	set(value):
		flare = value
		_apply_kindle()
## How much light the lantern throws onto the world (the pool), 0..1.
var reach: float = 1.0:
	set(value):
		reach = value
		_apply_kindle()

var _cold: TextureRect
var _lit: TextureRect
var _glow: TextureRect
var _pool: TextureRect
var _ember: Ember
var _time: float = 0.0


class Ember extends Control:
	var strength: float = 1.0
	var colour: Color = LeadlightTokens.EMBER

	func _draw() -> void:
		if strength <= 0.01:
			return
		var c: Vector2 = size * 0.5
		var r: float = size.x * 0.5
		var disc: Texture2D = SkyField.disc()
		draw_texture_rect(disc, Rect2(c - Vector2(r, r) * 2.4, Vector2(r, r) * 4.8), false,
			Color(colour, 0.45 * strength))
		draw_texture_rect(disc, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(Color("#ffd2a0"), strength))


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, empty)
	add_theme_stylebox_override("focus", _FocusHalo.new())
	var texture: Texture2D = _art()
	_pool = _layer(GlassStyle.grad_tex(
		PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.0)]),
		PackedFloat32Array([0.0, 0.32, 1.0]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5)), true)
	_glow = _layer(null, true)
	_cold = _layer(texture, false)
	_cold.modulate = COLD_TINT
	_lit = _layer(texture, false)
	_ember = Ember.new()
	_ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ember)
	flame = LanternFlame.new()
	add_child(flame)
	flame.light(_lit, _glow)
	_apply_kindle()


func _ready() -> void:
	_seat()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_seat()


## The saved run's reading, landed at once (no reading arrives on the title).
func set_reading(event: Dictionary) -> void:
	flame.show_event(event, true)
	_apply_kindle()


## The colour the lantern throws this frame.
func light() -> Color:
	return flame.light_now()


## The wick, in this control's coordinates: where the rite's ember sits and
## where light floods from.
func wick() -> Vector2:
	return _art_rect().position + _art_rect().size * WICK_UV


func glass_centre() -> Vector2:
	return _art_rect().position + _art_rect().size * GLASS_CENTRE_UV


func _process(delta: float) -> void:
	_time += delta
	var breath: float = LeadlightMotion.breath(_time)
	_pool.modulate.a = _pool_alpha() * (1.0 + 0.04 * breath)
	_pool.modulate = Color(light(), _pool.modulate.a)


func _art() -> Texture2D:
	var path: String = ART if ResourceLoader.exists(ART) else ART_FALLBACK
	return load(path) as Texture2D


func _layer(texture: Texture2D, additive: bool) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture != null:
		rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	if additive:
		var mat: CanvasItemMaterial = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		rect.material = mat
	add_child(rect)
	return rect


## The art is square and fills the control's height; the pool spreads wide.
func _art_rect() -> Rect2:
	var side: float = minf(size.x, size.y)
	return Rect2(Vector2((size.x - side) * 0.5, (size.y - side) * 0.5), Vector2(side, side))


func _seat() -> void:
	if _cold == null:
		return
	var art: Rect2 = _art_rect()
	for layer: TextureRect in [_cold, _lit, _glow]:
		layer.position = art.position
		layer.size = art.size
	var pool_r: float = art.size.x * 1.7
	var at: Vector2 = glass_centre()
	_pool.position = at - Vector2(pool_r, pool_r * 0.8)
	_pool.size = Vector2(pool_r * 2.0, pool_r * 1.6)
	var ember_r: float = art.size.x * 0.026
	_ember.position = wick() - Vector2(ember_r, ember_r * 2.6)
	_ember.size = Vector2(ember_r * 2.0, ember_r * 2.0)
	pivot_offset = wick()


func _pool_alpha() -> float:
	return clampf(reach * smoothstep(0.35, 1.0, kindle) * (0.85 + 0.6 * flare), 0.0, 1.6)


func _apply_kindle() -> void:
	if _lit == null:
		return
	# Glass takes light: the lit art crosses over the cold one.
	var lit: float = smoothstep(0.25, 0.85, kindle)
	_lit.modulate = Color(1.0 + flare * 0.25, 1.0 + flare * 0.2, 1.0 + flare * 0.1, lit)
	_glow.modulate.a = lit
	_cold.modulate.a = 1.0 - lit * 0.85
	# The ember: alone at 0, growing as the flame catches, gone once lit.
	_ember.strength = (1.0 - smoothstep(0.55, 0.9, kindle)) * (0.65 + 0.35 * smoothstep(0.0, 0.3, kindle))
	_ember.queue_redraw()
	if _pool != null:
		_pool.modulate.a = _pool_alpha()


class _FocusHalo extends StyleBox:
	func _draw(ci: RID, rect: Rect2) -> void:
		var side: float = minf(rect.size.x, rect.size.y)
		# A halo round the whole lantern, not a line across its glass.
		var c: Vector2 = rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 + side * 0.04)
		var radius: Vector2 = Vector2(side * 0.36, side * 0.50)
		var points: PackedVector2Array = LeadlightShapes.arc_points(c, radius, 0.0, TAU, 49)
		RenderingServer.canvas_item_add_polyline(ci, points,
			PackedColorArray([Color(LeadlightTokens.GOLD, 0.55)]), 1.2, true)
		var halo: PackedVector2Array = LeadlightShapes.arc_points(c, radius + Vector2(4, 4), 0.0, TAU, 49)
		RenderingServer.canvas_item_add_polyline(ci, halo,
			PackedColorArray([Color(LeadlightTokens.GOLD, 0.18)]), 4.0, true)
