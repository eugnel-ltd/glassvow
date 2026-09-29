class_name RunLantern
extends Control
## The hero's lantern between fights: the combat HUD's own lantern (its art, its
## firelight and its flame) hung on the reward, shop and event screens, so the
## flame answers a pick where the pick is made (lock §9, issue #577).
##
## A screen builds one only once it has a reading to show, so a run whose
## aspect declares no ways keeps those screens exactly as they were. It hangs
## just under the run HUD's chrome, at the size and inset the layout book gives
## the combat lantern for the shape, drawn at the HUD's own 104 inside a scaled
## shell. No numeral and no pips: embers belong to a fight. A screen that
## stands its own furniture at that seat (`keep_clear_of`) has the lantern hang from
## the other edge instead, the same size, inset and height.

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
## The stage this lantern is seated on and the furniture its screen keeps at the
## left of it (`keep_clear_of`). Without a stage the lantern keeps the left seat.
var _stage_width: float = 0.0
var _crowd: Rect2 = Rect2()


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
	_seat()


## Keep the lantern clear of `crowd`, the furniture a screen stands at its left
## (a rect in the screen's own px, on a stage `stage_width` wide). The lantern
## hangs from the combat lantern's left inset unless the crowd reaches its box,
## and then from the same inset at the right.
func keep_clear_of(stage_width: float, crowd: Rect2) -> void:
	_stage_width = stage_width
	_crowd = crowd
	_seat()


func _seat() -> void:
	var seat: Dictionary = LayoutBook.resolve(&"chrome", shape, 0).get("lantern", {})
	var side: Vector2 = Vector2(LayoutBook.num(seat.get("w"), NATURAL),
		LayoutBook.num(seat.get("h"), NATURAL))
	var inset: float = LayoutBook.num(seat.get("left"))
	var top: float = RunHud.chrome_bottom(shape) + GAP
	var x: float = inset
	if _stage_width > 0.0 and Rect2(Vector2(inset, top), side).grow(GAP).intersects(_crowd):
		x = _stage_width - inset - side.x
	_hang.position = Vector2(x, top)
	_hang.size = side
	_shell.scale = side / NATURAL
