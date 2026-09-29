class_name FlameLab
extends Control
## The flame bench, issue #577 step 1: the Duskblade's lantern burning a Flame
## reading, in the real combat HUD at the real shape, beside a large copy of the
## same lantern for looking at the figure itself.
##
## A spike, not wiring. The HUD is the production HudBar untouched; the lab puts
## the flame's material on its lantern art and tints its glow from outside, the
## two calls step 2 moves into HudBar behind a FLAME event (see `_light_hud`).
##
##   godot --path . -- --flame                     # bench: keys below
##   tools/shot.sh --flame --pose=true-edge --look=vector --time=1.2 --shot=/tmp/f.png
##   tools/shot.sh --flame --shape=phone-landscape --vp=1688x780 \
##       --record=/tmp/flame --poses=all --look=all --time=1.2
##
## Poses are FLAME events as the domain emits them, most taken from the lock's
## worked examples (§4). `--time=S` photographs S seconds after the reading
## arrived; with `--from=POSE` the flame starts there and is caught mid-tween.
## `--record=DIR` captures `--frames=N` frames `--step=S` apart for every pose
## in `--poses=` (and every look with `--look=all`), cropped to the HUD lantern
## and the large one, then quits. `--flame=off` is today's lantern,
## `--numeral=off` hides the ember count, `--inspect=off` the large lantern.
##
## Keys: ←/→ pose · 1-9, 0 pose · L look · F flame on/off · N numeral ·
## R art ready · Space hold the clock · H help.

const BACKDROP: Color = Color(0.043, 0.055, 0.102)
## The large lantern, as a share of the stage's height; it stands right of
## centre, where no HUD cluster sits at any shape.
const INSPECT_SHARE: float = 0.62
const INSPECT_AT: Vector2 = Vector2(0.60, 0.46)
## Crop margin round the HUD lantern's art: enough to keep the ember pips.
const HUD_CROP: float = 1.2

## id, caption, FLAME event.
const POSES: Array = [
	["kindling", "Kindling · the starter deck", {"tier": "KINDLING", "dominant": "",
		"fringe": "", "shares": {"shatter": 0.34, "lantern": 0.33, "edge": 0.33}}],
	["steady-shatter", "Steady · Shatter 霜焰", {"tier": "STEADY", "dominant": "shatter",
		"fringe": "", "shares": {"shatter": 0.60, "lantern": 0.20, "edge": 0.20}}],
	["steady-lantern", "Steady · Lantern 熾焰", {"tier": "STEADY", "dominant": "lantern",
		"fringe": "", "shares": {"shatter": 0.20, "lantern": 0.60, "edge": 0.20}}],
	["steady-edge", "Steady · Edge 蝕焰", {"tier": "STEADY", "dominant": "edge",
		"fringe": "", "shares": {"shatter": 0.20, "lantern": 0.20, "edge": 0.60}}],
	["true-shatter", "True · Shatter 霜焰", {"tier": "TRUE", "dominant": "shatter",
		"fringe": "", "shares": {"shatter": 0.84, "lantern": 0.08, "edge": 0.08}}],
	["true-lantern", "True · Lantern 熾焰", {"tier": "TRUE", "dominant": "lantern",
		"fringe": "", "shares": {"shatter": 0.08, "lantern": 0.84, "edge": 0.08}}],
	["true-edge", "True · Edge 蝕焰", {"tier": "TRUE", "dominant": "edge",
		"fringe": "", "shares": {"shatter": 0.08, "lantern": 0.08, "edge": 0.84}}],
	["shatter-edge-fringe", "Steady · Shatter, Edge fringe (0.25)", {"tier": "STEADY",
		"dominant": "shatter", "fringe": "edge",
		"shares": {"shatter": 0.63, "lantern": 0.12, "edge": 0.25}}],
	["lantern-shatter-fringe", "Steady · Lantern, Shatter fringe (0.33)", {"tier": "STEADY",
		"dominant": "lantern", "fringe": "shatter",
		"shares": {"shatter": 0.33, "lantern": 0.62, "edge": 0.05}}],
	["soot", "Soot · two of each way", {"tier": "SOOT", "dominant": "shatter",
		"fringe": "lantern", "shares": {"shatter": 0.34, "lantern": 0.33, "edge": 0.33}}],
]
const LOOK_NAMES: PackedStringArray = ["leaded", "vector"]

var shape: StringName = StageShape.IDENTITY
var flame: LanternFlame

var _hud: HudBar
## The HUD's own amber glow, kept to put back when the flame is off, and the
## same falloff drawn white so `_process` can give it the flame's colour.
var _amber_glow: Texture2D
var _white_glow: Texture2D = GlassStyle.grad_tex(
	PackedColorArray([Color(1.0, 1.0, 1.0, 0.30), Color(1.0, 1.0, 1.0, 0.0)]),
	PackedFloat32Array([0.0, 1.0]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
var _inspect: TextureRect
var _caption: Label
var _help: Label
var _pose: int = 0
var _look: LanternFlame.Look = LanternFlame.Look.LEADED
var _lit: bool = true
var _ready_art: bool = false
var _args: Dictionary = {}


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			_args[pair[0]] = pair[1] if pair.size() > 1 else ""
	shape = StringName(str(_args.get("shape", StageShape.IDENTITY)))
	if not StageShape.REFERENCES.has(shape):
		shape = StageShape.IDENTITY
	_pose = maxi(0, _pose_index(str(_args.get("pose", "kindling"))))
	_look = LanternFlame.Look.VECTOR if _args.get("look", "") == "vector" \
		else LanternFlame.Look.LEADED
	_lit = _args.get("flame", "on") != "off"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	flame = LanternFlame.new()
	flame.pinned = _args.has("time") or _args.has("record")
	add_child(flame)


func _ready() -> void:
	_build_stage()
	_hud = HudBar.new(true, true, true, shape)
	add_child(_hud)
	_hud.set_values(62, 80, 0, 128, 2, 3, 5, 3, 1, 5)
	_hud.set_lantern(3, _ready_art, 9)
	_hud.set_title("The Ashen Woods", "Floor I · The Rootheart")
	_hud._lantern_count.visible = _args.get("numeral", "on") != "off"
	_amber_glow = _hud._lantern_glow.texture
	_build_inspect()
	_build_help()
	flame.set_look(_look)
	_light_hud()
	var target: int = _pose
	if _args.has("from"):
		_show_pose(maxi(0, _pose_index(str(_args["from"]))), true)
	_show_pose(target, not _args.has("from"))
	flame.seek(0.0)
	flame.advance(float(str(_args.get("time", "0"))))
	if _args.has("record"):
		_record.call_deferred(str(_args["record"]))


func _process(_delta: float) -> void:
	# The HUD's glow is the lantern's firelight on the chrome: it burns the
	# flame's colour, tweened with it.
	_hud._lantern_glow.self_modulate = flame.colour_now()


# ---------------------------------------------------------------- build

## A stand-in for the battlefield: the night gradient the combat screen runs.
func _build_stage() -> void:
	var field: ColorRect = ColorRect.new()
	field.color = BACKDROP
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)
	var night: TextureRect = TextureRect.new()
	night.texture = GlassStyle.grad_tex(
		PackedColorArray([GlassStyle.NIGHT_TOP, GlassStyle.NIGHT_MID, GlassStyle.NIGHT_BOT]),
		PackedFloat32Array([0.0, 0.55, 1.0]), false, Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	night.stretch_mode = TextureRect.STRETCH_SCALE
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night)


## The large lantern: the same art and the same material, so it is the HUD's
## flame at a size where the figure itself can be judged. No numeral, no pips.
func _build_inspect() -> void:
	var stage: Vector2 = get_viewport_rect().size
	var side: float = stage.y * INSPECT_SHARE
	_inspect = TextureRect.new()
	_inspect.texture = HudBar.icon("ui/lantern")
	_inspect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_inspect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_inspect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_inspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect.size = Vector2(side, side)
	_inspect.position = stage * INSPECT_AT - _inspect.size * 0.5
	_inspect.visible = _args.get("inspect", "on") != "off"
	add_child(_inspect)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", maxi(11, int(stage.y * 0.024)))
	_caption.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.position = Vector2(_inspect.position.x - side * 0.25, _inspect.position.y + side)
	_caption.size = Vector2(side * 1.5, 24.0)
	_caption.visible = _inspect.visible
	add_child(_caption)


func _build_help() -> void:
	_help = Label.new()
	_help.text = "←/→ pose · 1-9, 0 pose · L look · F flame · N numeral · R art ready · Space hold · H help"
	_help.add_theme_font_size_override("font_size", 11)
	_help.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	_help.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help.position = Vector2(-_help.get_minimum_size().x * 0.5, 64.0)
	_help.visible = not (_args.has("shot") or _args.has("record"))
	add_child(_help)


## The two calls step 2 moves into HudBar, made here from outside the widget:
## the flame's material on the lantern art, and a glow that takes its colour.
## Off, the lantern is today's: no material, the amber glow, nothing ticking.
func _light_hud() -> void:
	var material: ShaderMaterial = flame.material if _lit else null
	_hud._lantern_art.material = material
	_inspect.material = material
	_hud._lantern_glow.texture = _white_glow if _lit else _amber_glow
	_hud._lantern_glow.self_modulate = Color.WHITE
	set_process(_lit)
	flame.set_process(_lit)


## The HUD's lantern art, for probes that need its size, texture and material.
func hud_lantern_art() -> TextureRect:
	return _hud._lantern_art


# ---------------------------------------------------------------- drive

func _pose_index(id: String) -> int:
	for i: int in range(POSES.size()):
		var row: Array = POSES[i]
		if str(row[0]) == id:
			return i
	return -1


func _show_pose(i: int, instant: bool) -> void:
	_pose = posmod(i, POSES.size())
	var row: Array = POSES[_pose]
	var event: Dictionary = row[2]
	flame.show_event(event, instant)
	_caption.text = "%s · %s" % [str(row[1]), LOOK_NAMES[int(_look)]]


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_RIGHT:
			_show_pose(_pose + 1, false)
		KEY_LEFT:
			_show_pose(_pose - 1, false)
		KEY_L:
			_look = LanternFlame.Look.VECTOR if _look == LanternFlame.Look.LEADED \
				else LanternFlame.Look.LEADED
			flame.set_look(_look)
			_show_pose(_pose, true)
		KEY_F:
			_lit = not _lit
			_light_hud()
		KEY_N:
			_hud._lantern_count.visible = not _hud._lantern_count.visible
		KEY_R:
			_ready_art = not _ready_art
			_hud.set_lantern(3, _ready_art, 9)
		KEY_SPACE:
			flame.pinned = not flame.pinned
		KEY_H:
			_help.visible = not _help.visible
		_:
			if key.keycode >= KEY_0 and key.keycode <= KEY_9:
				_show_pose((key.keycode - KEY_0 + 9) % 10, false)


# ---------------------------------------------------------------- record

## Every pose (and look) in turn, `--frames` frames `--step` seconds apart from
## `--time`, each saved as two crops at the window's own pixels: the HUD
## lantern with its pips and numeral, and the large lantern. Then quit.
func _record(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var ids: PackedStringArray = PackedStringArray()
	var wanted: String = str(_args.get("poses", "all"))
	for row: Array in POSES:
		if wanted == "all" or wanted.split(",").has(str(row[0])):
			ids.append(str(row[0]))
	var looks: Array[LanternFlame.Look] = [_look]
	if _args.get("look", "") == "all":
		looks = [LanternFlame.Look.LEADED, LanternFlame.Look.VECTOR]
	var frames: int = maxi(1, int(str(_args.get("frames", "1"))))
	var step: float = float(str(_args.get("step", "0.0333")))
	var start: float = float(str(_args.get("time", "0")))
	# The pips blend over .25s and the first frames of a window paint black.
	for _i: int in range(30):
		await get_tree().process_frame
	for look: LanternFlame.Look in looks:
		_look = look
		flame.set_look(look)
		for id: String in ids:
			if _args.has("from"):
				_show_pose(_pose_index(str(_args["from"])), true)
			_show_pose(_pose_index(id), not _args.has("from"))
			flame.seek(0.0)
			flame.advance(start)
			for k: int in range(frames):
				if k > 0:
					flame.advance(step)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				_save_crops(get_viewport().get_texture().get_image(),
					"%s/%s_%s_%03d" % [dir, id, LOOK_NAMES[int(look)], k])
	print("flame lab: recorded %d pose(s) × %d look(s) × %d frame(s) into %s" % [
		ids.size(), looks.size(), frames, dir])
	get_tree().quit(0)


func _save_crops(img: Image, stem: String) -> void:
	var k: float = float(img.get_width()) / get_viewport_rect().size.x
	var art: Rect2 = _hud._lantern_art.get_global_rect()
	var hud: Rect2 = Rect2(art.get_center() - art.size * 0.5 * HUD_CROP, art.size * HUD_CROP)
	img.get_region(_pixels(hud, k, img)).save_png(stem + "_hud.png")
	if _inspect.visible:
		img.get_region(_pixels(_inspect.get_global_rect(), k, img)).save_png(stem + "_big.png")


func _pixels(r: Rect2, k: float, img: Image) -> Rect2i:
	var px: Rect2i = Rect2i(Vector2i((r.position * k).round()), Vector2i((r.size * k).round()))
	return px.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
