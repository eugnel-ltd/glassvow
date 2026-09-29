class_name RunLantern
extends Control
## The hero's lantern between fights: the combat HUD's own lantern (its art, its
## firelight and its flame) hung on the reward and shop screens, so the flame
## answers a pick where the pick is made (lock §9, issue #577).
##
## A screen builds one only once it has a reading to show, so a run whose
## aspect declares no ways keeps those screens exactly as they were. It hangs
## just under the run HUD's chrome, at the size and inset the layout book gives
## the combat lantern for the shape, drawn at the HUD's own 104 inside a scaled
## shell. No numeral and no pips: embers belong to a fight.

## The combat lantern's box and the art inside it (`HudBar._build_lantern`).
const NATURAL: float = 104.0
const ART_SIDE: float = 94.0
## Clear air between the run HUD's chrome and the lantern's ring.
const GAP: float = 4.0
## The HUD's resting firelight: nothing here can be spent.
const GLOW_ALPHA: float = 0.45

var shape: StringName = StageShape.IDENTITY
var flame: LanternFlame

var _hang: Control
var _shell: Control


func _init(stage_shape: StringName = StageShape.IDENTITY) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hang = Control.new()
	_hang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hang)
	_shell = Control.new()
	_shell.size = Vector2(NATURAL, NATURAL)
	_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hang.add_child(_shell)
	var glow: TextureRect = TextureRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate.a = GLOW_ALPHA
	_shell.add_child(glow)
	# Texture, then expand mode, then size: in KEEP_SIZE a TextureRect's
	# texture is its minimum, and a size written first is clamped to it.
	var art: TextureRect = TextureRect.new()
	art.texture = HudBar.icon("ui/lantern")
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size = Vector2(ART_SIDE, ART_SIDE)
	art.position = Vector2.ONE * (NATURAL - ART_SIDE) * 0.5
	_shell.add_child(art)
	flame = LanternFlame.new()
	add_child(flame)
	flame.light(art, glow)
	set_shape(stage_shape)


## The Flame's reading (`EventTypes.FLAME`); `instant` draws it at once, as a
## screen does when it opens on a reading that is already true.
func show_flame(event: Dictionary, instant: bool = false) -> void:
	flame.show_event(event, instant)


func set_shape(stage_shape: StringName) -> void:
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	var seat: Dictionary = LayoutBook.resolve(&"chrome", shape, 0).get("lantern", {})
	var side: Vector2 = Vector2(LayoutBook.num(seat.get("w"), NATURAL),
		LayoutBook.num(seat.get("h"), NATURAL))
	_hang.position = Vector2(LayoutBook.num(seat.get("left")),
		RunHud.chrome_bottom(shape) + GAP)
	_hang.size = side
	_shell.scale = side / NATURAL
