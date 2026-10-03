class_name LeadlightPlaque
extends VBoxContainer
## The lit name that belongs to the lantern (Back to the Road / Rekindle) and its
## optional sub-line: a flame glyph in the run's colour and where the run stands.
## The flame is shown, never named (dusk-flame lock: the player discovers it).

## The plaque is part of the lantern's button (TitleScreen's reach): it lights
## with it. `glow` 0..1 brightens the gold (hover, the beckon, the press) and
## warms the ember light behind the name; `focused` (focus shown on the lantern,
## never merely held) lays the lantern ring's gold hairline beneath the name.
const LIT_GOLD: Color = Color("#fff1c4")
## The ember light behind the name: wider than the name by HALO_GROW.x of its
## width, taller by HALO_GROW.y of its height each way, never flatter than
## HALO_ASPECT (a flat halo read as a second oval), with a contourless falloff.
const HALO_GROW: Vector2 = Vector2(0.10, 0.60)
const HALO_ASPECT: float = 2.6
const HALO_FALLOFF: PackedFloat32Array = [1.0, 0.6, 0.32, 0.17, 0.06, 0.0]
## The name's glow-outline: the same at rest and pressed. A press is the fill
## going LIT_GOLD over a warmer ember light, never a heavier pale stroke.
const SHADOW_ALPHA: float = 0.30
const SHADOW_SIZE: int = 10
static var _halo: Texture2D = null
var glow: float = 0.0:
	set(value):
		glow = clampf(value, 0.0, 1.0)
		_relight()
var focused: bool = false:
	set(value):
		focused = value
		queue_redraw()

var _name: Label
var _sub_row: HBoxContainer
var _glyph: Glyph
var _sub: Label


class Glyph extends Control:
	var colour: Color = LeadlightTokens.EMBER

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(17):
			var t: float = float(i) / 16.0 * TAU
			var x: float = sin(t) * w * 0.42
			var y: float = h * 0.62 - cos(t) * h * 0.36
			if cos(t) > 0.0:
				y -= cos(t) * h * 0.22
				x *= 1.0 - cos(t) * 0.45
			pts.append(Vector2(w * 0.5 + x, y))
		draw_texture_rect(SkyField.disc(), Rect2(Vector2(-w, -h * 0.4), Vector2(w * 3.0, h * 1.8)),
			false, Color(colour, 0.45))
		draw_colored_polygon(pts, colour.lerp(Color.WHITE, 0.35))


func _init(stage_shape: StringName = StageShape.IDENTITY) -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	var px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_PLAQUE, stage_shape)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_PRIMARY, px))
	_name.add_theme_font_size_override("font_size", px)

	_name.add_theme_constant_override("shadow_outline_size", SHADOW_SIZE)
	_name.add_theme_constant_override("shadow_offset_x", 0)
	_name.add_theme_constant_override("shadow_offset_y", 0)
	_name.add_theme_color_override("font_outline_color", Color(LeadlightTokens.VOID, 0.85))
	_name.add_theme_constant_override("outline_size", 4)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)
	_relight()
	_sub_row = HBoxContainer.new()
	_sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_sub_row.add_theme_constant_override("separation", 8)
	_sub_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub_row)
	var sub_px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_CAPTION, stage_shape)
	_glyph = Glyph.new()
	_glyph.custom_minimum_size = Vector2(float(sub_px) * 0.7, float(sub_px) * 1.1)
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sub_row.add_child(_glyph)
	_sub = Label.new()
	_sub.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_LABEL, sub_px))
	_sub.add_theme_font_size_override("font_size", sub_px)
	_sub.add_theme_color_override("font_color", LeadlightTokens.TEXT_DIM)
	_sub.add_theme_color_override("font_outline_color", Color(LeadlightTokens.VOID, 0.8))
	_sub.add_theme_constant_override("outline_size", 4)
	_sub_row.add_child(_sub)
	set_text("", "")


func set_text(title: String, sub: String, flame_colour: Color = LeadlightTokens.EMBER) -> void:
	_name.text = title.to_upper() if not LeadlightTokens.is_zh() else title
	_sub.text = sub.to_upper() if not LeadlightTokens.is_zh() else sub
	_sub_row.visible = not sub.is_empty()
	_glyph.colour = flame_colour
	_glyph.queue_redraw()


func title_label() -> Label:
	return _name


func _relight() -> void:
	if _name == null:
		return
	_name.add_theme_color_override("font_color", LeadlightTokens.GOLD.lerp(LIT_GOLD, glow))
	_name.add_theme_color_override("font_shadow_color", Color(LeadlightTokens.GOLD, SHADOW_ALPHA))
	queue_redraw()


## Where the ember light behind a name of `name_rect` falls. Pure.
static func halo_rect(name_rect: Rect2) -> Rect2:
	var grown: Vector2 = Vector2(name_rect.size.x * (1.0 + HALO_GROW.x * 2.0),
		name_rect.size.y * (1.0 + HALO_GROW.y * 2.0))
	grown.y = maxf(grown.y, grown.x / HALO_ASPECT)
	return Rect2(name_rect.get_center() - grown * 0.5, grown)


static func halo_texture() -> Texture2D:
	if _halo == null:
		_halo = LeadlightShapes.soft_light(HALO_FALLOFF)
	return _halo


func _draw() -> void:
	var name_rect: Rect2 = Rect2(_name.position, _name.size)
	var light: float = maxf(glow, 0.35 if focused else 0.0)
	if light > 0.01:
		# The lantern's light on the plaque: warm behind the name.
		draw_texture_rect(halo_texture(), halo_rect(name_rect), false,
			Color(LeadlightTokens.EMBER, 0.38 * light))
	if not focused:
		return
	# The lantern ring in its unboxed form, under the name (LeadlightWord's hairline).
	var y: float = name_rect.end.y + 1.0
	var a: Vector2 = Vector2(name_rect.position.x + name_rect.size.x * 0.06, y)
	var b: Vector2 = Vector2(name_rect.end.x - name_rect.size.x * 0.06, y)
	var gold: Color = LeadlightTokens.GOLD
	var clear: Color = Color(LeadlightTokens.GOLD, 0.0)
	draw_polyline_colors(PackedVector2Array([a, (a + b) * 0.5, b]),
		PackedColorArray([clear, gold, clear]), 2.0, true)
