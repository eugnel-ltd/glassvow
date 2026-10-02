class_name LeadlightToggle
extends CheckButton
## A glass switch: a leaded track whose knob is an ember when on. It stays a
## Button with ON / OFF in its own words beside the switch, so state is never
## carried by colour alone, and reads its truth through a getter so it always
## restates what is stored rather than a mirrored local.

const W: int = 46
const H: int = 24

static var _icons: Dictionary = {}

var _getter: Callable
var _setter: Callable


func _init(getter: Callable = Callable(), setter: Callable = Callable()) -> void:
	_getter = getter
	_setter = setter
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size.y = RunStyle.hit_floor(28.0)
	add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_LABEL, 12))
	add_theme_font_size_override("font_size", 12)
	add_theme_constant_override("h_separation", 10)
	# Two switches, drawn once per process; a disabled switch is the same
	# drawing dimmed by the Button's own disabled modulate, not two more.
	for name: String in ["checked", "checked_mirrored", "checked_disabled", "checked_disabled_mirrored"]:
		add_theme_icon_override(name, icon_for(true))
	for name: String in ["unchecked", "unchecked_mirrored", "unchecked_disabled", "unchecked_disabled_mirrored"]:
		add_theme_icon_override(name, icon_for(false))
	add_theme_stylebox_override("focus", LeadlightGlassBox.make(
		LeadlightGlassBox.Shape.RECT, "focus", false, 0.0))
	pressed.connect(_flip)
	sync()


## Restate the stored value: ON / OFF words, the switch, the lit ink.
func sync() -> void:
	var on: bool = _getter.call() if _getter.is_valid() else button_pressed
	set_pressed_no_signal(on)
	text = Locale.active.t("ui.settings.on" if on else "ui.settings.off").to_upper()
	var ink: Color = LeadlightTokens.GOLD if on else LeadlightTokens.TEXT_DIM
	for colour: String in ["font_color", "font_focus_color", "font_pressed_color"]:
		add_theme_color_override(colour, ink)
	add_theme_color_override("font_hover_color", LeadlightTokens.GOLD if on else LeadlightTokens.TEXT)
	add_theme_color_override("font_hover_pressed_color", LeadlightTokens.GOLD)


func _flip() -> void:
	if _getter.is_valid() and _setter.is_valid():
		var was_on: bool = _getter.call()
		_setter.call(not was_on)
	sync()


## The switch, drawn once per state: a rounded leaded track and a knob.
static func icon_for(on: bool) -> ImageTexture:
	var key: String = str(on)
	if _icons.has(key):
		return _icons[key]
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var r: float = float(H) * 0.5
	var knob_c: Vector2 = Vector2(float(W) - r if on else r, r)
	for y: int in range(H):
		for x: int in range(W):
			var p: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5)
			var cx: float = clampf(p.x, r, float(W) - r)
			var d: float = p.distance_to(Vector2(cx, r))
			var colour: Color = Color(0, 0, 0, 0)
			if d <= r:
				var rim: bool = d > r - 1.6
				var body: Color = Color(LeadlightTokens.GOLD, 0.22) if on else Color(0.04, 0.05, 0.10, 0.92)
				colour = (Color(LeadlightTokens.GOLD, 0.75) if on else LeadlightTokens.LEAD_LINE) if rim else body
				colour.a *= clampf(r - d + 0.5, 0.0, 1.0)
			var kd: float = p.distance_to(knob_c)
			var kr: float = r - 4.0
			if kd <= kr + 0.5:
				var t: float = clampf(kd / kr, 0.0, 1.0)
				var knob: Color = Color("#fff3c9").lerp(LeadlightTokens.GOLD, t) if on \
					else Color("#6b7290").lerp(Color("#2a2f45"), t)
				knob.a = clampf(kr - kd + 0.5, 0.0, 1.0)
				colour = colour.blend(knob)
			img.set_pixel(x, y, colour)
	var texture: ImageTexture = ImageTexture.create_from_image(img)
	_icons[key] = texture
	return texture
