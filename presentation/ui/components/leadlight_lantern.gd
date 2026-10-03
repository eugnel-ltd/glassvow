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
## The ember's flame quad, as a share of the art's side: the shader's wick sits
## at the lantern's wick and its tallest flame is REACH (0.29) of this.
const EMBER_QUAD: float = 0.55
## The ember's flame height (the shader's `height`) as it catches: a small
## candle at first light, grown towards the lantern's own by the time the glass
## takes it over.
const EMBER_HEIGHT: Vector2 = Vector2(0.42, 0.78)
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
## How much of the lantern itself is there, 0..1. Frame 0 of the launch is
## one ember in the dark (the boot splash), so the iron and glass come up
## after it; the ember is drawn apart and is not dimmed by this.
var presence: float = 1.0:
	set(value):
		presence = value
		_apply_kindle()
## How much light the lantern throws onto the world (the pool), 0..1.
var reach: float = 1.0:
	set(value):
		reach = value
		_apply_kindle()

## The light pool's shape and strength: half-extent in art sides (x, y), how
## far below the glass it is centred (art sides), its core alpha and its
## breath. The defaults are the phone's; the title widens and strengthens the
## pool on pad and desktop so the road visibly carries the flame's colour.
var pool_spread: Vector2 = Vector2(1.7, 1.36)
var pool_drop: float = 0.0
var pool_core: float = 0.55
var pool_breath: float = 0.04

var _cold: TextureRect
var _lit: TextureRect
var _glow: TextureRect
var _pool: TextureRect
var _ember: Ember
## The ember is the lantern's own flame drawn alone (lantern_flame.gdshader,
## `isolate`), in Kindling's colour, with its own clock. Visible from frame 0,
## it also compiles the flame's pipeline before the glass ever needs it.
var _ember_flame: TextureRect
var _ember_fire: LanternFlame
static var _blank: Texture2D = null
var _time: float = 0.0


## The light the ember throws round itself (a soft halo, no hard disc: the
## ember itself is a flame, `_ember_flame`).
class Ember extends Control:
	var strength: float = 1.0
	var colour: Color = LeadlightTokens.EMBER
	## The ember's own flicker, 0.85..1.1: a flame, so it stays under Reduce
	## Motion (T10 keeps the flame's flicker).
	var flicker: float = 1.0

	func _draw() -> void:
		if strength * flicker <= 0.01:
			return
		var c: Vector2 = size * 0.5
		var r: float = size.x * 0.5
		var disc: Texture2D = SkyField.disc()
		var s: float = strength * flicker
		draw_texture_rect(disc, Rect2(c - Vector2(r, r) * 2.4 * flicker, Vector2(r, r) * 4.8 * flicker),
			false, Color(colour, 0.45 * s))


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, empty)
	add_theme_stylebox_override("focus", _FocusHalo.new())
	var texture: Texture2D = _art()
	_pool = _layer(pool_texture(pool_core), true)
	_glow = _layer(null, true)
	_cold = _layer(texture, false)
	_cold.modulate = COLD_TINT
	_lit = _layer(texture, false)
	_ember = Ember.new()
	_ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ember)
	_ember_fire = LanternFlame.new()
	add_child(_ember_fire)
	_ember_fire.material.set_shader_parameter(&"isolate", 1.0)
	_ember_flame = TextureRect.new()
	_ember_flame.name = "EmberFlame"
	_ember_flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ember_flame.texture = blank()
	_ember_flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ember_flame.stretch_mode = TextureRect.STRETCH_SCALE
	_ember_flame.material = _ember_fire.material
	add_child(_ember_flame)
	flame = LanternFlame.new()
	add_child(flame)
	flame.light(_lit, _glow)
	_apply_kindle()


func _ready() -> void:
	_seat()
	# The lit layer carries the flame shader, whose pipeline the first frame
	# would otherwise wait on (~0.14 s on Metal, cold). The launch's first
	# frames show only the ember and the cold lantern, so the lit layer joins
	# one frame later and its compile lands inside the ember's breath; the
	# title takes input from its first frame either way.
	_lit.visible = false
	_glow.visible = false
	get_tree().process_frame.connect(_show_lit, CONNECT_ONE_SHOT)


func _show_lit() -> void:
	_lit.visible = true
	_glow.visible = true


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


## The ember's flicker, 0.85..1.1, for anything its light falls on.
func ember_flicker() -> float:
	return _ember.flicker


func glass_centre() -> Vector2:
	return _art_rect().position + _art_rect().size * GLASS_CENTRE_UV


## A 4×4 white texture: the ember's quad has no art, only the shader's flame.
static func blank() -> Texture2D:
	if _blank == null:
		var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_blank = ImageTexture.create_from_image(image)
	return _blank


func _process(delta: float) -> void:
	_time += delta
	# A still pins the lantern's flame; the ember's clock stops with it.
	_ember_fire.pinned = flame.pinned
	if _ember.strength > 0.01:
		_ember.flicker = 0.92 + 0.10 * sin(_time * 9.1) * sin(_time * 3.7 + 1.3) + 0.06 * sin(_time * 1.9)
		_ember.queue_redraw()
	# Under Reduce Motion the pool holds still; only the flame in the glass
	# flickers (motion spec T10).
	if LeadlightMotion.reduced():
		return
	var breath: float = LeadlightMotion.breath(_time)
	_pool.modulate.a = _pool_alpha() * (1.0 + pool_breath * breath)
	_pool.modulate = Color(light(), _pool.modulate.a)


## Set the pool's shape and strength (see `pool_spread`).
func set_pool(spread: Vector2, drop: float, core: float, breath_amount: float) -> void:
	pool_spread = spread
	pool_drop = drop
	pool_breath = breath_amount
	if not is_equal_approx(core, pool_core):
		pool_core = core
		_pool.texture = pool_texture(core)
	_seat()


static func pool_texture(core: float) -> GradientTexture2D:
	return GlassStyle.grad_tex(
		PackedColorArray([Color(1, 1, 1, core), Color(1, 1, 1, core * 0.3), Color(1, 1, 1, 0.0)]),
		PackedFloat32Array([0.0, 0.32, 1.0]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5))


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
	var half: Vector2 = art.size.x * pool_spread
	var at: Vector2 = glass_centre() + Vector2(0.0, art.size.x * pool_drop)
	_pool.position = at - half
	_pool.size = half * 2.0
	var ember_r: float = art.size.x * 0.026
	_ember.position = wick() - Vector2(ember_r, ember_r * 2.6)
	_ember.size = Vector2(ember_r * 2.0, ember_r * 2.0)
	var quad: float = art.size.x * EMBER_QUAD
	_ember_flame.position = wick() - Vector2(quad * WICK_UV.x, quad * WICK_UV.y)
	_ember_flame.size = Vector2(quad, quad)
	pivot_offset = wick()


func _pool_alpha() -> float:
	return clampf(reach * smoothstep(0.35, 1.0, kindle) * (0.85 + 0.6 * flare), 0.0, 1.6)


func _apply_kindle() -> void:
	if _lit == null:
		return
	# Glass takes light: the lit art crosses over the cold one.
	var lit: float = smoothstep(0.25, 0.85, kindle)
	_lit.modulate = Color(1.0 + flare * 0.25, 1.0 + flare * 0.2, 1.0 + flare * 0.1, lit * presence)
	_glow.modulate.a = lit * presence
	_cold.modulate.a = (1.0 - lit * 0.85) * presence
	# The ember: alone at 0, growing as the flame catches, gone once lit.
	_ember.strength = (1.0 - smoothstep(0.55, 0.9, kindle)) * (0.65 + 0.35 * smoothstep(0.0, 0.3, kindle))
	_ember.queue_redraw()
	_ember_flame.modulate.a = _ember.strength
	_ember_flame.visible = _ember.strength > 0.004
	_ember_fire.material.set_shader_parameter(&"height",
		lerpf(EMBER_HEIGHT.x, EMBER_HEIGHT.y, smoothstep(0.05, 0.7, kindle)))
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
