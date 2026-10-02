class_name LeadlightRose
extends Button
## The six-pane Emberglass rose, set in the sealed door: each shard the Vigil
## holds lights its pane with the mural's own glass (the masks and shader the
## Rose Window uses); an empty door is dark tracery. With any shard held the
## rose is a way into the Rose Window (route `rose`); without, it is only
## glass and takes no focus.

const MURAL: String = "res://assets/art/meta/emberglass-mural.png"
const FRAME: String = "res://assets/art/meta/emberglass-frame.png"
const MASK: String = "res://assets/art/meta/emberglass-mask-%s.png"
const PANE_SHADER: Shader = preload("res://presentation/run/rose_pane.gdshader")
const SHARDS: Array[String] = [
	"eighthOmen", "hollowLamplighter", "ownShade", "paleOnes", "unreadablePage", "usurper",
]

## 0..1: how much of the held glass is lit (the reveal brings it up).
var glow: float = 1.0:
	set(value):
		glow = value
		_apply()

var _lit: Array[TextureRect] = []
var _dark: Array[TextureRect] = []
var _held: int = 0


func _init(held: Array = []) -> void:
	flat = true
	clip_contents = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, empty)
	add_theme_stylebox_override("focus", _Ring.new())
	var backing: _Disc = _Disc.new()
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	var mural: Texture2D = load(MURAL) as Texture2D
	for id: String in SHARDS:
		var path: String = MASK % id
		if not ResourceLoader.exists(path):
			continue
		var on: bool = held.has(id)
		var pane: TextureRect = _layer(load(path) as Texture2D)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = PANE_SHADER
		material.set_shader_parameter("mural", mural)
		material.set_shader_parameter("show_mural", on)
		material.set_shader_parameter("fill_colour", Color(0.10, 0.12, 0.22, 0.85) if not on else Color.TRANSPARENT)
		pane.material = material
		if on:
			_lit.append(pane)
			_held += 1
		else:
			_dark.append(pane)
	_layer(load(FRAME) as Texture2D)
	focus_mode = Control.FOCUS_ALL if _held > 0 else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if _held > 0 else Control.MOUSE_FILTER_IGNORE
	tooltip_text = Locale.active.t("ui.rose.openLabel") if _held > 0 else ""
	_apply()


func held_count() -> int:
	return _held


func _layer(texture: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _apply() -> void:
	for pane: TextureRect in _lit:
		pane.modulate = Color(1.0, 1.0, 1.0, 0.25 + 0.75 * glow)


class _Disc extends Control:
	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.46
		draw_circle(size * 0.5, r, Color(0.027, 0.035, 0.07, 0.92))


class _Ring extends StyleBox:
	func _draw(ci: RID, rect: Rect2) -> void:
		var c: Vector2 = rect.get_center()
		var r: float = minf(rect.size.x, rect.size.y) * 0.5 + 4.0
		var points: PackedVector2Array = LeadlightShapes.arc_points(c, Vector2(r, r), 0.0, TAU, 49)
		RenderingServer.canvas_item_add_polyline(ci, points,
			PackedColorArray([Color(LeadlightTokens.GOLD, 0.9)]), 1.6, true)
