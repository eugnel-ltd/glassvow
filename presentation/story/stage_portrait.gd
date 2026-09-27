class_name StagePortrait
extends Control
## One actor on the dialogue stage: a bust cut from their full-figure glass
## cutout, lit when they speak and dark when they listen. Mood swaps cross-
## fade on the same canvas; a mood whose art has not landed is carried by
## posture and light alone (MOOD_LOOKS). Entrances slide in from the actor's
## own side; exits fade toward it. All motion is driven by `tick` so the
## scene player — and headless tests — own the clock.

const SHADER: String = "res://presentation/story/glass_portrait.gdshader"
const ENTER_TIME: float = 0.42
const EXIT_TIME: float = 0.30
const LIGHT_TIME: float = 0.26
const MOOD_TIME: float = 0.24
const ENTER_SLIDE: float = 90.0
const LISTEN_SINK: float = 8.0
const LISTEN_LIGHT: float = 0.0
const IDLE_LIGHT: float = 0.42
const RIM_COLOURS: Dictionary[StringName, Color] = {
	&"warm": Color(1.0, 0.64, 0.30),
	&"cold": Color(0.62, 0.78, 1.0),
}
## Posture and light that carry a mood when its own art is missing — and a
## lighter touch of the same when it is present. `lean` is pixels toward the
## conversation, `rise` pixels up, `grade` a multiply on the lit glass.
const MOOD_LOOKS: Dictionary = {
	"tender": {"grade": Color(1.06, 0.97, 0.88), "rise": 4.0},
	"offering": {"grade": Color(1.10, 0.98, 0.84), "rise": 6.0, "lean": 14.0},
	"weary": {"grade": Color(0.82, 0.80, 0.86), "rise": -12.0},
	"revealed": {"grade": Color(0.86, 0.92, 1.10), "rim": &"cold"},
	"beckon": {"grade": Color(0.84, 0.90, 1.12), "lean": 16.0, "rim": &"cold"},
	"wary": {"grade": Color(0.92, 0.95, 1.02), "lean": -14.0},
	"asking": {"lean": 10.0},
	"recognising": {"lean": 20.0, "scale": 1.03},
	"urgent": {"grade": Color(1.04, 0.98, 0.95), "lean": 24.0, "scale": 1.04},
	"grieving": {"grade": Color(0.78, 0.80, 0.90), "rise": -16.0},
}

var actor_id: String = ""
var slot: StringName = &"right"
var mood: String = ""
var leaving: bool = false
var flipped: bool = false
var reduce_motion: bool = false

var _book: ActorBook
var _hero: String = ""
var _sprite: TextureRect
var _prev: TextureRect
var _halo: TextureRect
var _material: ShaderMaterial
var _prev_material: ShaderMaterial
var _look: Dictionary = {}
var _light: float = IDLE_LIGHT
var _light_goal: float = IDLE_LIGHT
var _enter: float = 1.0
var _exit: float = 0.0
var _mood_t: float = 1.0
var _hop: float = 0.0
var _recoil: float = 0.0
var _tremble: float = 0.0
var _flash: float = 0.0
var _clock: float = 0.0
var _phase: float = 0.0
var _seat: Rect2 = Rect2()


func _init(book: ActorBook, id: String, hero: String = "") -> void:
	_book = book
	_hero = hero
	actor_id = id
	name = "Portrait_%s" % id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase = float(hash(id) % 628) / 100.0
	var shader: Shader = load(SHADER) as Shader
	_halo = TextureRect.new()
	_halo.name = "Halo"
	_halo.texture = GlassStyle.disc(Color.WHITE, 1.0, 128)
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.stretch_mode = TextureRect.STRETCH_SCALE
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.modulate = Color(book.tint(id), 0.0)
	add_child(_halo)
	_prev = _make_sprite("Previous")
	_prev_material = _make_material(shader)
	_prev.material = _prev_material
	_prev.visible = false
	add_child(_prev)
	_sprite = _make_sprite("Sprite")
	_material = _make_material(shader)
	_sprite.material = _material
	add_child(_sprite)


## Place (or re-place) this actor. `instant` stands them without an entrance.
func stand(at: StringName, new_mood: String, instant: bool) -> void:
	var moved: bool = at != slot
	slot = at
	leaving = false
	_exit = 0.0
	if instant:
		_enter = 1.0
	elif moved and _sprite.texture != null:
		_enter = 0.0
	set_mood(new_mood, instant)


func begin_entrance() -> void:
	_enter = 0.0 if not reduce_motion else 1.0


func set_mood(new_mood: String, instant: bool) -> void:
	var resolved: Dictionary = _book.resolve(actor_id, new_mood, _hero)
	var path: String = str(resolved["path"])
	var texture: Texture2D = _crop(path)
	var changed: bool = _sprite.texture == null \
		or str(_sprite.texture.get_meta("source", "")) != path
	mood = new_mood
	var full_look: Dictionary = MOOD_LOOKS.get(new_mood, {})
	_look = full_look.duplicate()
	if resolved["exact"] == true and not _look.is_empty():
		# Real art already carries the mood; keep only a whisper of posture.
		var lean: float = full_look.get("lean", 0.0)
		var rise: float = full_look.get("rise", 0.0)
		_look["lean"] = lean * 0.4
		_look["rise"] = rise * 0.4
		_look["grade"] = Color(1, 1, 1)
		_look.erase("scale")
	var rim_side: StringName = StringName(str(resolved["rim"]))
	var rim_key: StringName = StringName(str(_look.get("rim", &"")))
	for m: ShaderMaterial in [_material, _prev_material]:
		m.set_shader_parameter("rim_dir",
			Vector2(1.0 if rim_side == &"right" else -1.0, -0.35))
		m.set_shader_parameter("rim_color",
			RIM_COLOURS.get(rim_key, RIM_COLOURS[&"warm"]))
		m.set_shader_parameter("grade", _look.get("grade", Color(1, 1, 1)))
	if changed and texture != null:
		if _sprite.texture != null and not instant and not reduce_motion:
			_prev.texture = _sprite.texture
			_prev.visible = true
			_mood_t = 0.0
		_sprite.texture = texture
	elif texture == null:
		_sprite.texture = null
	_layout_sprites()


func set_lit(lit: bool, anyone_lit: bool, instant: bool) -> void:
	_light_goal = 1.0 if lit else (LISTEN_LIGHT if anyone_lit else IDLE_LIGHT)
	if instant or reduce_motion:
		_light = _light_goal
	_apply_light()


func leave(instant: bool) -> void:
	leaving = true
	_exit = 1.0 if instant or reduce_motion else 0.0


func is_gone() -> bool:
	return leaving and _exit >= 1.0


func has_art() -> bool:
	return _sprite.texture != null


func lit() -> bool:
	return _light_goal >= 1.0


func hop() -> void:
	if not reduce_motion:
		_hop = 1.0


func recoil() -> void:
	if not reduce_motion:
		_recoil = 1.0


func tremble() -> void:
	if not reduce_motion:
		_tremble = 1.0


func flash() -> void:
	_flash = 0.55 if reduce_motion else 1.0


## The seat this actor stands in: full stage-space rect of the bust.
func seat(rect: Rect2) -> void:
	_seat = rect
	position = rect.position
	size = rect.size
	pivot_offset = Vector2(rect.size.x * 0.5, rect.size.y)
	_layout_sprites()


## Stage-space point roughly at the figure's hands — where a kindle leaves.
func hands() -> Vector2:
	return _seat.position + Vector2(_seat.size.x * 0.5, _seat.size.y * 0.62)


func tick(delta: float) -> void:
	_clock += delta
	var rate: float = 1.0 / LIGHT_TIME
	_light = move_toward(_light, _light_goal, delta * rate)
	if _enter < 1.0:
		_enter = minf(1.0, _enter + delta / ENTER_TIME)
	if leaving and _exit < 1.0:
		_exit = minf(1.0, _exit + delta / EXIT_TIME)
	if _mood_t < 1.0:
		_mood_t = minf(1.0, _mood_t + delta / MOOD_TIME)
		if _mood_t >= 1.0:
			_prev.visible = false
	_hop = maxf(0.0, _hop - delta * 2.6)
	_recoil = maxf(0.0, _recoil - delta * 2.2)
	_tremble = maxf(0.0, _tremble - delta * 1.8)
	_flash = maxf(0.0, _flash - delta * 2.4)
	_apply_light()
	_apply_pose()


const HALO_ALPHA: float = 0.30


func _apply_light() -> void:
	_halo.modulate.a = HALO_ALPHA * _light * _light
	for m: ShaderMaterial in [_material, _prev_material]:
		m.set_shader_parameter("light", _light)
		m.set_shader_parameter("rim", 0.35 + 0.65 * _light)
		m.set_shader_parameter("flash", _flash * 0.6)


func _apply_pose() -> void:
	var toward: float = 1.0 if StageDirection.SLOT_X.get(slot, 0.5) < 0.5 else -1.0
	var home: Vector2 = _seat.position
	var away: float = -toward
	var slide: float = 0.0
	var alpha: float = 1.0
	if _enter < 1.0:
		var u: float = Motion.ease(Motion.ENTER, _enter)
		slide += away * ENTER_SLIDE * (1.0 - u)
		alpha *= u
	if leaving:
		var v: float = Motion.ease(Motion.CSS_EASE, _exit)
		slide += away * ENTER_SLIDE * 0.5 * v
		alpha *= 1.0 - v
	var sink: float = (1.0 - _light) * LISTEN_SINK
	var lean_px: float = _look.get("lean", 0.0)
	var lean: float = lean_px * toward
	var rise: float = _look.get("rise", 0.0)
	var hop_y: float = -sin(_hop * PI) * 18.0
	var recoil_x: float = -toward * sin(_recoil * PI) * 26.0
	var tremble_x: float = sin(_clock * 70.0) * 5.0 * _tremble
	var breath: float = 0.0 if reduce_motion else sin(_clock * 1.25 + _phase)
	position = home + Vector2(slide + lean + recoil_x + tremble_x,
		sink - rise + hop_y)
	var look_scale: float = _look.get("scale", 1.0)
	var s: float = look_scale * (1.0 - (1.0 - _light) * 0.015)
	scale = Vector2(s, s * (1.0 + breath * 0.006))
	modulate.a = alpha
	if _prev.visible:
		_prev.modulate.a = 1.0 - _mood_t
		_sprite.modulate.a = _mood_t


func _layout_sprites() -> void:
	for sprite: TextureRect in [_prev, _sprite]:
		sprite.position = Vector2.ZERO
		sprite.size = size
		sprite.flip_h = flipped
	var glow: Vector2 = Vector2(size.x * 1.25, size.y * 0.95)
	_halo.size = glow
	_halo.position = Vector2((size.x - glow.x) * 0.5, size.y * 0.02)


func _crop(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var source: Texture2D = load(path) as Texture2D
	if source == null:
		return null
	var region: Rect2 = _book.crop(actor_id)
	var full: Vector2 = source.get_size()
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(region.position * full, region.size * full)
	atlas.set_meta("source", path)
	# Busts cut above the canvas foot dissolve over their lowest 16%.
	var cut: float = region.end.y
	var fade: float = region.size.y * 0.16 if cut < 0.995 else 0.0
	for m: ShaderMaterial in [_material, _prev_material]:
		m.set_shader_parameter("cut_v", cut)
		m.set_shader_parameter("cut_fade", fade)
	return atlas


## Aspect (w / h) of this actor's bust; 1 when no art is bound.
func bust_aspect() -> float:
	if _sprite.texture == null:
		return 1.0
	var s: Vector2 = _sprite.texture.get_size()
	return s.x / maxf(s.y, 1.0)


static func _make_sprite(node_name: String) -> TextureRect:
	var sprite: TextureRect = TextureRect.new()
	sprite.name = node_name
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sprite


static func _make_material(shader: Shader) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = shader
	return m
