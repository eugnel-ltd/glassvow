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
## The top of the chain's ring, as a share of the art's height (the art's
## opaque bounds start at 54 of 1024 px): what the plaque stands on.
const RING_TOP_UV: float = 0.053
## Where a tap is the lantern's: its own body (the art's opaque bounds, 259–762
## by 54–988 of 1024 px, with a little to spare), never the road either side of
## it inside its square, where the title's words stand (#655: a tap on the
## middle of 設定 took the road).
const HIT_UV: Rect2 = Rect2(0.24, 0.04, 0.52, 0.94)
## The ember's flame quad, as a share of the art's side: the shader's wick sits
## at the lantern's wick and its tallest flame is REACH (0.29) of this.
const EMBER_QUAD: float = 0.55
## The ember's flame height (the shader's `height`) as it catches: a small
## candle at first light, grown towards the lantern's own by the time the glass
## takes it over.
const EMBER_HEIGHT: Vector2 = Vector2(0.42, 0.78)
const COLD_TINT: Color = Color(0.17, 0.17, 0.21, 1.0)
## The light pool's falloff, centre to rim: one smooth curve, so no contour
## shows where two linear ramps meet (docs/design/2026-10-03-title-rooms §6.2).
const POOL_FALLOFF: PackedFloat32Array = [1.0, 0.6, 0.32, 0.17, 0.06, 0.0]
const POOL_TEXTURE: int = 512
## Keyboard focus is a gold rim on the lantern's own silhouette (§6.2): the
## body's outline grown outward by the same RIM_WIDTH all round (a share of the
## art's side: about 5 px at 1180×820), drawn behind the iron and over the
## light it throws, in GOLD at RIM_ALPHA. Grown evenly, never scaled about a
## centre, which thickened the rim with distance from it into a cap over the
## chain. The chain is not rimmed: the rim starts at the roof (RIM_TOP_UV, the
## art's 240 of 1024 px), so it never climbs to the plaque on the chain's ring.
## Over the pool, not under it: the pool's additive light washed it to white.
const RIM_ALPHA: float = 0.45
const RIM_WIDTH: float = 3.0 / 256.0
const RIM_TOP_UV: float = 0.235
const RIM_MASK: int = 256
## The damped swing on its chain as it is set down at a room's seat
## (docs/design/2026-10-03-title-rooms §5.2): ±SWING_DEG, still by SWING_TIME.
const SWING_DEG: float = 3.0
const SWING_TIME: float = 0.52

## Focus shown on the lantern (a keyboard or pad player's), as against merely
## held (a tap holds it hidden). The plaque lights with this, never with focus
## alone.
signal focus_shown(shown: bool)

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
static var _rim_mask: Texture2D = null
## Whether a lantern has drawn its lit layer this session (its pipeline warm).
static var _lit_warm: bool = false
var _time: float = 0.0
var _focus_shown: bool = false
## The rim, made on the first shown focus.
var _rim: TextureRect = null
## Time into a swing; below 0 when it hangs still.
var _swing_t: float = -1.0


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
	# Focus is the rim (`_show_rim`), never a box or an ellipse.
	add_theme_stylebox_override("focus", empty)
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
	# title takes input from its first frame either way. Once a lantern has
	# lit, the pipeline is warm: a later lantern (a title rebuilt on a return)
	# is lit from its first frame, never a cold lantern for one (#655: it
	# showed through a Reduce Motion cross-fade).
	if _lit_warm:
		return
	_lit.visible = false
	_glow.visible = false
	get_tree().process_frame.connect(_show_lit, CONNECT_ONE_SHOT)


func _show_lit() -> void:
	_lit.visible = true
	_glow.visible = true
	_lit_warm = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_seat()
	elif what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT \
			or what == NOTIFICATION_DRAW:
		# Godot redraws a control whenever its focus is shown or hidden, so the
		# draw also catches hidden focus becoming shown on the same control.
		_sync_focus_shown()


func _sync_focus_shown() -> void:
	var shown: bool = is_inside_tree() and has_focus(true)
	if shown != _focus_shown:
		_focus_shown = shown
		_show_rim(shown)
		focus_shown.emit(shown)


func _show_rim(on: bool) -> void:
	if on and _rim == null:
		var mask: Texture2D = rim_mask()
		if mask == null:
			return
		_rim = TextureRect.new()
		_rim.name = "FocusRim"
		_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rim.texture = mask
		_rim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_rim.stretch_mode = TextureRect.STRETCH_SCALE
		_rim.modulate = Color(LeadlightTokens.GOLD, RIM_ALPHA)
		add_child(_rim)
		# Over the pool and the glow, under the iron and the glass.
		move_child(_rim, _cold.get_index())
		_seat()
	if _rim != null:
		_rim.visible = on


## The lantern's body grown by RIM_WIDTH all round, as a white mask the art's
## size (its own alpha, the chain above RIM_TOP_UV left out), built once per
## process on the first focus a keyboard shows. The growth is the union of the
## body shifted RIM_WIDTH (and half of it) every way: an even band, drawn by
## the image's own blend, with the body's soft edge kept.
static func rim_mask() -> Texture2D:
	if _rim_mask != null:
		return _rim_mask
	var path: String = ART if ResourceLoader.exists(ART) else ART_FALLBACK
	var art: Texture2D = load(path) as Texture2D
	var image: Image = art.get_image() if art != null else null
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(RIM_MASK, RIM_MASK, Image.INTERPOLATE_LANCZOS)
	var data: PackedByteArray = image.get_data()
	for i: int in range(0, data.size(), 4):
		data[i] = 255
		data[i + 1] = 255
		data[i + 2] = 255
	var body: Image = Image.create_from_data(RIM_MASK, RIM_MASK, false, Image.FORMAT_RGBA8, data)
	body.fill_rect(Rect2i(0, 0, RIM_MASK, roundi(RIM_TOP_UV * RIM_MASK)), Color(1.0, 1.0, 1.0, 0.0))
	var grown: Image = Image.create(RIM_MASK, RIM_MASK, false, Image.FORMAT_RGBA8)
	var whole: Rect2i = Rect2i(0, 0, RIM_MASK, RIM_MASK)
	var reach: float = RIM_WIDTH * float(RIM_MASK)
	for ring: Vector2 in [Vector2(reach, 16.0), Vector2(reach * 0.5, 8.0)]:
		for i: int in range(int(ring.y)):
			var angle: float = TAU * float(i) / ring.y
			grown.blend_rect(body, whole, Vector2i(roundi(cos(angle) * ring.x), roundi(sin(angle) * ring.x)))
	_rim_mask = ImageTexture.create_from_image(grown)
	return _rim_mask


func _has_point(point: Vector2) -> bool:
	return hit_rect().has_point(point)


## The lantern's hit, in its own coordinates.
func hit_rect() -> Rect2:
	var art: Rect2 = _art_rect()
	return Rect2(art.position + art.size * HIT_UV.position, art.size * HIT_UV.size)


## Swing once on the chain, damped (never under Reduce Motion, never blocking).
func swing() -> void:
	if not LeadlightMotion.reduced():
		_swing_t = 0.0


## Hang still at once.
func settle() -> void:
	_swing_t = -1.0
	set_swing(0.0)


func swinging() -> bool:
	return _swing_t >= 0.0


## The lantern swinging on its chain by `angle` radians about the top of its
## ring. Zero hangs it still again, pivoted at the wick as it rests.
func set_swing(angle: float) -> void:
	if is_zero_approx(angle):
		rotation = 0.0
		pivot_offset = wick()
		return
	var art: Rect2 = _art_rect()
	pivot_offset = Vector2(art.get_center().x, art.position.y + art.size.y * RING_TOP_UV)
	rotation = angle


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


## How strongly the ember shows at `kindle`: alone at 0, growing as the flame
## catches, gone once the glass is lit. Pure.
static func ember_strength(at_kindle: float) -> float:
	return (1.0 - smoothstep(0.55, 0.9, at_kindle)) * (0.65 + 0.35 * smoothstep(0.0, 0.3, at_kindle))


## The ember's flame height (the shader's `height`) at `kindle`. Pure.
static func ember_height(at_kindle: float) -> float:
	return lerpf(EMBER_HEIGHT.x, EMBER_HEIGHT.y, smoothstep(0.05, 0.7, at_kindle))


## What the launch's frame 0 shows of this lantern — its ember alone at
## `at_kindle`, halo and flame, clock at 0 — as a control in the lantern's
## parent's space. TitleScreen covers the rest of the title with it for the
## one frame that builds the rite's pipelines, so that frame shows exactly
## the splash's picture.
func ember_alone(at_kindle: float) -> Control:
	var holder: Control = Control.new()
	holder.name = "EmberAlone"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = position
	holder.size = size
	var halo: Ember = Ember.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.position = _ember.position
	halo.size = _ember.size
	halo.strength = ember_strength(at_kindle)
	holder.add_child(halo)
	var fire: LanternFlame = LanternFlame.new()
	fire.pinned = true
	fire.material.set_shader_parameter(&"isolate", 1.0)
	fire.material.set_shader_parameter(&"height", ember_height(at_kindle))
	holder.add_child(fire)
	var rect: TextureRect = TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = blank()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.material = fire.material
	rect.position = _ember_flame.position
	rect.size = _ember_flame.size
	rect.modulate.a = halo.strength
	holder.add_child(rect)
	return holder


## A 4×4 white texture: the ember's quad has no art, only the shader's flame.
static func blank() -> Texture2D:
	if _blank == null:
		var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_blank = ImageTexture.create_from_image(image)
	return _blank


func _process(delta: float) -> void:
	_time += delta
	if _swing_t >= 0.0:
		_swing_t += delta
		var u: float = _swing_t / SWING_TIME
		if u >= 1.0:
			settle()
		else:
			set_swing(deg_to_rad(SWING_DEG) * sin(u * TAU * 1.5) * pow(1.0 - u, 2.0))
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
	var alphas: PackedFloat32Array = PackedFloat32Array()
	for alpha: float in POOL_FALLOFF:
		alphas.append(alpha * core)
	return LeadlightShapes.soft_light(alphas, POOL_TEXTURE)


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
	if _rim != null:
		_rim.position = art.position
		_rim.size = art.size
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
	_ember.strength = ember_strength(kindle)
	_ember.queue_redraw()
	_ember_flame.modulate.a = _ember.strength
	_ember_flame.visible = _ember.strength > 0.004
	_ember_fire.material.set_shader_parameter(&"height", ember_height(kindle))
	if _pool != null:
		# The flame's colour even when the pool holds still (Reduce Motion).
		_pool.modulate = Color(light(), _pool_alpha())
