class_name TransitionLayer
extends CanvasLayer
## The screen-to-screen ceremony the benchmark runs at z 72–75 — the wipe, the
## transit leaves and the grain — owned by `application/main.gd` and living
## ABOVE every routed screen, so a leaf started before a route swap survives
## the swap and finishes over the incoming screen. That ownership is the whole
## point: the port had victory/defeat leaves inside `CombatScreen`, and
## `_clear_route()` freed them within a frame of their first paint.
##
## Screens never see this layer. Main fires it around its route helpers, the
## way `navigation.js` wraps `show()` — the wipe on every screen change with a
## live run (`navigation.js:80` `if (S.screen !== name && S.run) wipe()`), the
## entrance on every screen root (`.screen-enter`, styles.css:141).
##
## Draw discipline: every leaf here is draw-only. The one screen-reading node
## is the grain, and it is mutually exclusive with `CombatScreen`'s own grain
## (which folds the world-stop drain into the same pass) — `set_grain(false)`
## on combat routes keeps exactly one `hint_screen_texture` visible per frame.

## `#wipe` (styles.css:1520-1531): a 102° band of lantern light on a 280%-wide
## ground, background-position 135% → −135% over 0.6s. In offset terms that is
## the band image travelling from −2.43×W to +2.43×W — off left, across, off
## right — on `wipeSweep`'s own curve.
const WIPE_TIME: float = 0.6
const WIPE_SPAN: float = 2.43
const WIPE_WIDTH: float = 2.8
## `screenIn` (styles.css:141-142): 0.45s, fade with a 1.015 settle.
const SCREEN_IN_TIME: float = 0.45
const SCREEN_IN_SCALE: float = 1.015
## `combat-in` (navigation.js:44-49): the dark disc collapses into the click
## point over 480ms — cover is immediate, the reveal is the animation. CSS
## `circle(150%)` resolves past any corner from any centre; 1.5× the stage
## diagonal does the same here.
const IRIS_TIME: float = 0.48
const IRIS_SPAN: float = 1.5
## `tr-bloom` — `radial-gradient(circle at 50% 45%, #ffe9ac 0%, #f2c14e55 30%,
## transparent 70%)` over 900ms, `[0, 1 @ 0.4, 0]`. The last stop is the SAME
## amber at zero alpha rather than `transparent`: a browser interpolates
## gradient stops premultiplied, so `transparent` there does not drag the ramp
## toward black, and Godot's `Gradient` — which interpolates raw RGBA — would.
## Fired by main on a combat win (`victoryFlow`, combat.js), and living HERE so
## the 900ms leaf survives the route swap to the reward screen.
const BLOOM_TIME: float = 0.9
const BLOOM_CORE: Color = Color(1.0, 0.9137255, 0.6745098, 1.0)      # #ffe9ac
const BLOOM_MID: Color = Color(0.9490196, 0.75686276, 0.30588236, 0.33333334)
const BLOOM_STOPS: Array[float] = [0.0, 0.3, 0.7]
const BLOOM_AT: Array[float] = [0.0, 0.4, 1.0]
const BLOOM_TRACK: Array[float] = [0.0, 1.0, 0.0]
## The gradient's default extent is farthest-corner from (50%, 45%).
const BLOOM_CENTRE: Vector2 = Vector2(0.5, 0.45)
## `tr-crack` — `rgba(3,4,10,.9)` over 700ms, `[0, 1]`, then the host empties:
## the benchmark's `.finally` does not linger, the screen routed underneath
## takes over the dark.
const CRACK_TIME: float = 0.7
const CRACK_TONE: Color = Color(0.011764706, 0.015686275, 0.039215688, 0.9)
const CRACK_AT: Array[float] = [0.0, 1.0]
const CRACK_TRACK: Array[float] = [0.0, 1.0]
## `act-change` (navigation.js:54-59, `.tr-plate` styles.css:1537-1539): an
## opaque plate names the next act and its omen — `[0, 1 @0.15, 1 @0.8, 0]`
## over 2200ms, fired beside the map route rather than awaited. Act line
## `clamp(28px, 5cqw, 44px)` tracked 0.18em in Cinzel gold; omen line 15px
## tracked 0.14em in the omen's own tone.
const PLATE_TIME: float = 2.2
const PLATE_AT: Array[float] = [0.0, 0.15, 0.8, 1.0]
const PLATE_TRACK: Array[float] = [0.0, 1.0, 1.0, 0.0]
const PLATE_GROUND: Color = Color(0.0196, 0.0275, 0.0549, 0.88)
const PLATE_GOLD: Color = Color("#f2c14e")

## The `.tr-iris` ink (`#05070e`, styles.css:1533), drawn as an annulus by
## shader rather than by clip: dark inside the radius, nothing outside.
const IRIS_SHADER: String = """
shader_type canvas_item;

uniform vec2 centre = vec2(0.0, 0.0);
uniform float radius = 0.0;
uniform vec2 rect_size = vec2(1.0, 1.0);
uniform vec4 ink : source_color = vec4(0.0196, 0.0275, 0.0549, 1.0);
uniform float feather = 0.75;

void fragment() {
	float d = distance(UV * rect_size, centre);
	COLOR = vec4(ink.rgb, ink.a * (1.0 - smoothstep(radius - feather, radius + feather, d)));
}
"""
## `#grain` (styles.css:74-81): whole-pixel jitter jumps, eight per 0.9s —
## the same table `CombatScreen` carries, duplicated by the shared-surface
## rule rather than reached across the lane boundary.
const GRAIN_AMOUNT: float = 0.05
const GRAIN_STEP: float = 0.9 / 8.0
const GRAIN_JUMPS: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(-14.0, 7.0), Vector2(10.0, -17.0), Vector2(-7.0, 14.0),
	Vector2(17.0, 5.0), Vector2(-14.0, -10.0), Vector2(7.0, 17.0), Vector2(-10.0, -7.0)]

## The grain-only sibling of `CombatScreen.GRAIN_SHADER` — same hash, same
## overlay blend, no drain uniforms, because outside combat there is no
## world-stop to fold in.
const GRAIN_SHADER: String = """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 jitter = vec2(0.0);
uniform float amount : hint_range(0.0, 1.0) = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	vec3 g = vec3(hash(floor(FRAGCOORD.xy) + jitter));
	vec3 over = mix(2.0 * base * g,
		1.0 - 2.0 * (1.0 - base) * (1.0 - g), step(vec3(0.5), base));
	COLOR = vec4(mix(base, over, amount), 1.0);
}
"""

## The most a Reduce Motion fade moves in one frame: a route built on the tap
## frame (a long frame) cannot spend the fade before it is seen, so a fade of
## REDUCED_FADE always takes at least nine drawn frames at 60 fps.
const FADE_STEP_MAX: float = 1.0 / 60.0
## A frame's colour formats and their sRGB views (`_capture`).
const SRGB_OF: Dictionary = {
	RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM: RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB,
	RenderingDevice.DATA_FORMAT_B8G8R8A8_UNORM: RenderingDevice.DATA_FORMAT_B8G8R8A8_SRGB,
}

## Captures and headless drives must never wait on a tween: every ceremony
## method returns immediately when set. Main sets it from `--shot=`.
var instant: bool = false
## Where `cross_fade` takes the frame on screen from: the viewport's own image
## (`_capture`). A suite stands in for it, the headless renderer having none.
var snapshot_source: Callable = Callable()

var _wipe: TextureRect
var _iris: ColorRect
var _iris_mat: ShaderMaterial
var _bloom: TextureRect
var _crack: ColorRect
var _plate: ColorRect
var _plate_act: Label
var _plate_omen_row: HBoxContainer
var _plate_omen_icon: TextureRect
var _plate_omen: Label
var _grain: ColorRect
var _grain_mat: ShaderMaterial
var _grain_t: float = 0.0
var _wipe_tween: Tween = null
## The transit-slot guard, `navigation.js`'s `transitionSeq`: a later leaf
## takes the slot and an earlier one's finish must not hide it.
var _transit_seq: int = 0
## The Leadlight leaves (docs/design/2026-10-02-opening-start §8.5): the flood
## (light filling the screen from a point, the iris's own shader in reverse)
## and the flare (the bloom, centred where the light is).
var _flood: ColorRect
var _flood_mat: ShaderMaterial
var _flood_tween: Tween = null
var _flare: TextureRect
var _flare_tween: Tween = null
## The Reduce Motion fades running now, one per item: {"from", "to", "t",
## "entry" (an entrance's number, or -1 for the snapshot)}.
var _fades: Dictionary = {}
## Reduce Motion's cross-fade: the last frame drawn, laid over whatever the
## change puts on screen and faded out (`cross_fade`). Under the leaves.
var _snapshot: TextureRect
## The frame `_snapshot` was taken on: an entrance then lands whole under it.
var _snapshot_frame: int = -1
## The GPU texture `_snapshot` shows, when the renderer made one; freed with it.
var _snapshot_rid: RID = RID()


func _init() -> void:
	layer = 10
	_snapshot = TextureRect.new()
	_snapshot.name = "ReducedMotionSnapshot"
	_snapshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_snapshot.stretch_mode = TextureRect.STRETCH_SCALE
	_snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_snapshot.visible = false
	add_child(_snapshot)
	_wipe = TextureRect.new()
	_wipe.texture = _band_texture()
	_wipe.stretch_mode = TextureRect.STRETCH_SCALE
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.visible = false
	add_child(_wipe)
	var iris_sh: Shader = Shader.new()
	iris_sh.code = IRIS_SHADER
	_iris_mat = ShaderMaterial.new()
	_iris_mat.shader = iris_sh
	_iris = ColorRect.new()
	_iris.material = _iris_mat
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_iris.set_anchors_preset(Control.PRESET_FULL_RECT)
	_iris.visible = false
	add_child(_iris)
	# The bloom is a TextureRect because a radial ramp IS a texture in Godot
	# and a shader would buy nothing; the crack is a flat plate.
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array(BLOOM_STOPS)
	grad.colors = PackedColorArray([BLOOM_CORE, BLOOM_MID,
		Color(BLOOM_MID.r, BLOOM_MID.g, BLOOM_MID.b, 0.0)])
	var bloom_tex: GradientTexture2D = GradientTexture2D.new()
	bloom_tex.gradient = grad
	bloom_tex.fill = GradientTexture2D.FILL_RADIAL
	bloom_tex.fill_from = BLOOM_CENTRE
	# Farthest-corner, expressed in the texture's own UV so it re-solves
	# against whatever the window is rather than the stage it was measured in.
	bloom_tex.fill_to = BLOOM_CENTRE + Vector2(0.5, 0.55)
	bloom_tex.width = 256
	bloom_tex.height = 256
	_bloom = TextureRect.new()
	_bloom.texture = bloom_tex
	_bloom.stretch_mode = TextureRect.STRETCH_SCALE
	_bloom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloom.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bloom.visible = false
	add_child(_bloom)
	_crack = ColorRect.new()
	_crack.color = CRACK_TONE
	_crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crack.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crack.visible = false
	add_child(_crack)
	_plate = ColorRect.new()
	_plate.color = PLATE_GROUND
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.visible = false
	add_child(_plate)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 10)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(stack)
	_plate_act = Label.new()
	_plate_act.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate_act.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_plate_act.add_theme_color_override("font_color", PLATE_GOLD)
	stack.add_child(_plate_act)
	_plate_omen_row = HBoxContainer.new()
	_plate_omen_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_plate_omen_row.add_theme_constant_override("separation", 8)
	_plate_omen_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_plate_omen_row)
	_plate_omen_icon = TextureRect.new()
	_plate_omen_icon.custom_minimum_size = Vector2(16.0, 16.0)
	_plate_omen_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate_omen_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_plate_omen_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_plate_omen_row.add_child(_plate_omen_icon)
	_plate_omen = Label.new()
	_plate_omen.add_theme_font_size_override("font_size", 15)
	_plate_omen_row.add_child(_plate_omen)
	_flood_mat = ShaderMaterial.new()
	_flood_mat.shader = iris_sh
	_flood = ColorRect.new()
	_flood.material = _flood_mat
	_flood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flood.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flood.visible = false
	add_child(_flood)
	_flare = TextureRect.new()
	_flare.texture = bloom_tex
	_flare.stretch_mode = TextureRect.STRETCH_SCALE
	_flare.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flare.visible = false
	add_child(_flare)
	var sh: Shader = Shader.new()
	sh.code = GRAIN_SHADER
	_grain_mat = ShaderMaterial.new()
	_grain_mat.shader = sh
	_grain_mat.set_shader_parameter("amount", GRAIN_AMOUNT)
	_grain = ColorRect.new()
	_grain.material = _grain_mat
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grain.visible = false
	add_child(_grain)


func _process(delta: float) -> void:
	if not _fades.is_empty():
		advance_fades(delta)
	# `#grain { display: none; }` under prefers-reduced-motion
	# (styles.css:2037): the film disappears entirely — a noise plate held
	# still would read as dirt on the glass. Faded rather than hidden so
	# main's `set_grain` routing (`visible`) stays the single owner of which
	# grain exists on a route.
	var still: bool = Preferences.active.reduce_motion
	_grain.self_modulate.a = 0.0 if still else 1.0
	if not _grain.visible or still:
		return
	_grain_t += delta
	var step: int = int(_grain_t / GRAIN_STEP) % GRAIN_JUMPS.size()
	_grain_mat.set_shader_parameter("jitter", GRAIN_JUMPS[step])


## The band-of-light sweep. Fire-and-forget: main calls it BEFORE the route
## swap and the band crosses whatever arrives underneath, exactly as the
## fixed-position `#wipe` does.
func wipe() -> void:
	# `#wipe, #transit { display: none; }` (styles.css:2038): the band is the
	# largest translating element in the build, and the first thing a
	# vestibular-sensitive player needs gone. Same clean early-out as
	# `instant` — the route swap simply happens.
	if instant or Preferences.active.reduce_motion:
		return
	var stage: Vector2 = _stage_size()
	if stage.x <= 0.0:
		return
	_wipe.size = Vector2(stage.x * WIPE_WIDTH, stage.y)
	_wipe.position.y = 0.0
	_wipe.visible = true
	if _wipe_tween != null:
		_wipe_tween.kill()
	_wipe_tween = Motion.bez(self, _place_wipe.bind(stage.x), WIPE_TIME, Motion.WIPE)
	_wipe_tween.finished.connect(_hide_wipe, CONNECT_ONE_SHOT)


func _place_wipe(eased: float, stage_w: float) -> void:
	_wipe.position.x = lerpf(-WIPE_SPAN * stage_w, WIPE_SPAN * stage_w, eased)


func _hide_wipe() -> void:
	_wipe.visible = false


## Every screen root's entrance: fade in with a 1.015 → 1 settle about the
## centre. The pivot needs a laid-out size, so the scale half waits one frame
## and is skipped when the root has none to offer. The screen comes up out of
## the night, the project's clear colour (docs/design/2026-10-03-title-rooms
## §2.8), never the engine's grey.
##
## Under Reduce Motion a route change is a REDUCED_FADE cross-fade, never a
## hard cut (§2.7): the frame it replaces fades out over it (`cross_fade`), so
## the entrance lands whole beneath; with nothing copied, it fades up from the
## night with no settle.
##
## A root can enter more than once: the map screen is kept off the tree between
## visits (`MapScreenKeep`). Each entrance is numbered on the root, and only the
## latest may write, so an entrance cut short by a route change and resumed
## when the root re-enters never fights the new one.
func screen_in(root: Control) -> void:
	if root == null:
		return
	var entry: int = _entrance_of(root) + 1
	root.set_meta(&"screen_in", entry)
	if instant:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		root.modulate.a = 1.0
		return
	if Preferences.active.reduce_motion:
		_reduced_entrance(root, entry)
		return
	root.modulate.a = 0.0
	await tree.process_frame
	if not is_instance_valid(root) or not root.is_inside_tree() \
			or _entrance_of(root) != entry:
		return
	var sized: bool = root.size.x > 0.0 and root.size.y > 0.0
	if sized:
		root.pivot_offset = root.size * 0.5
		root.scale = Vector2.ONE * SCREEN_IN_SCALE
	# The tween is bound to the root, so a mid-entrance route swap kills it
	# with the screen instead of writing into freed memory.
	var entrance: Callable = func(eased: float) -> void:
		if not is_instance_valid(root) or _entrance_of(root) != entry:
			return
		root.modulate.a = eased
		if sized:
			root.scale = Vector2.ONE * lerpf(SCREEN_IN_SCALE, 1.0, eased)
	Motion.bez(root, entrance, SCREEN_IN_TIME, Motion.SCREEN_IN)


## Reduce Motion's form of every change of screen (docs/design/2026-10-03-title-
## rooms §2.7): a 150 ms linear cross-fade, never a cut. Called before the
## change: the frame on screen now (the screen leaving, or the screen before a
## room opens or closes over it) is copied and laid over whatever the change
## puts there, then fades out in REDUCED_FADE, so every frame between is a
## straight blend of the two. A copy of the drawn frame, not the leaving nodes
## faded through their root: that blends each of its stacked layers on its
## own and bunches the change into the fade's last frames, and it would keep
## a screen alive (and able to route) after the change. One copy a frame,
## however many changes the frame makes. True when the cross-fade runs; false
## under full motion, for a capture, or with no frame to copy (headless).
func cross_fade() -> bool:
	if instant or not Preferences.active.reduce_motion or get_tree() == null:
		return false
	var now: int = Engine.get_process_frames()
	if _snapshot_frame == now:
		return true
	_release_snapshot()
	var frame: Texture2D = snapshot_source.call() if snapshot_source.is_valid() else _capture()
	if frame == null:
		return false
	_snapshot_frame = now
	_snapshot.texture = frame
	_snapshot.position = Vector2.ZERO
	_snapshot.size = _stage_size()
	var vp: Viewport = get_viewport()
	if vp != null:
		# The copy is the whole window; the stage may be scaled into it.
		var window: Rect2 = vp.get_stretch_transform().affine_inverse() \
			* Rect2(Vector2.ZERO, Vector2(frame.get_size()))
		if window.size.x > 0.0 and window.size.y > 0.0:
			_snapshot.position = window.position
			_snapshot.size = window.size
	_snapshot.modulate.a = 1.0
	_snapshot.visible = true
	_fades[_snapshot] = {"from": 1.0, "to": 0.0, "t": 0.0, "entry": -1}
	return true


## Whether a cross-fade is on screen now.
func cross_fading() -> bool:
	return _snapshot.visible


## The frame on screen as a texture: copied on the GPU when the renderer has a
## device (Forward+, Mobile: a copy of a few hundredths of a millisecond),
## read back otherwise (Compatibility); null in the headless renderer.
func _capture() -> Texture2D:
	var vp: Viewport = get_viewport()
	if vp == null or DisplayServer.get_name() == "headless":
		return null
	var source: ViewportTexture = vp.get_texture()
	var device: RenderingDevice = RenderingServer.get_rendering_device()
	if device != null:
		var from: RID = RenderingServer.texture_get_rd_texture(source.get_rid())
		if from.is_valid():
			var format: RDTextureFormat = device.texture_get_format(from)
			if format.usage_bits & RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT:
				var copy: RDTextureFormat = RDTextureFormat.new()
				copy.width = format.width
				copy.height = format.height
				copy.format = format.format
				copy.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
					| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
				# The canvas samples a colour texture through an sRGB view too:
				# the copy must allow one, or it is no texture to the canvas.
				var srgb: int = SRGB_OF.get(format.format, -1)
				if srgb >= 0:
					copy.add_shareable_format(format.format)
					copy.add_shareable_format(srgb as RenderingDevice.DataFormat)
				var to: RID = device.texture_create(copy, RDTextureView.new())
				if to.is_valid() and device.texture_copy(from, to, Vector3.ZERO, Vector3.ZERO,
						Vector3(format.width, format.height, 1), 0, 0, 0, 0) == OK:
					_snapshot_rid = to
					var texture: Texture2DRD = Texture2DRD.new()
					texture.texture_rd_rid = to
					return texture
				if to.is_valid():
					device.free_rid(to)
	var image: Image = source.get_image()
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _release_snapshot() -> void:
	_snapshot.visible = false
	_snapshot.texture = null
	_fades.erase(_snapshot)
	if _snapshot_rid.is_valid():
		var device: RenderingDevice = RenderingServer.get_rendering_device()
		if device != null:
			device.free_rid(_snapshot_rid)
		_snapshot_rid = RID()


## Whole under a cross-fade taken this frame; otherwise (nothing could be
## copied) from nothing on the call's own frame to whole in REDUCED_FADE,
## linear, at full scale. Numbered, so only the latest entrance writes.
func _reduced_entrance(root: Control, entry: int) -> void:
	root.scale = Vector2.ONE
	if _snapshot_frame == Engine.get_process_frames():
		_fades.erase(root)
		root.modulate.a = 1.0
		return
	root.modulate.a = 0.0
	_fades[root] = {"from": 0.0, "to": 1.0, "t": 0.0, "entry": entry}


## Moves every Reduce Motion fade on by `delta` seconds, never by more than
## FADE_STEP_MAX. Called each frame; a suite calls it to step the fades.
func advance_fades(delta: float) -> void:
	var step: float = minf(delta, FADE_STEP_MAX) / LeadlightMotion.REDUCED_FADE
	for key: Variant in _fades.keys():
		var fade: Dictionary = _fades[key]
		if not is_instance_valid(key):
			_fades.erase(key)
			continue
		var item: CanvasItem = key
		var entry: int = fade["entry"]
		if entry >= 0 and _entrance_of(item as Control) != entry:
			_fades.erase(item)
			continue
		var was: float = fade["t"]
		var from: float = fade["from"]
		var to: float = fade["to"]
		var t: float = minf(was + step, 1.0)
		fade["t"] = t
		item.modulate.a = lerpf(from, to, t)
		if t < 1.0:
			continue
		_fades.erase(item)
		if item == _snapshot:
			_release_snapshot()


## The number of the latest `screen_in` on `root`; zero before its first.
static func _entrance_of(root: Control) -> int:
	var entry: int = root.get_meta(&"screen_in", 0)
	return entry


## The combat entry: dark covers the screen the moment this is called, then
## collapses into `at` (stage px) while the fight builds underneath — the
## route swap's frame hitch happens under the cover, which is the point.
func iris(at: Vector2) -> void:
	# `#transit` leaf (styles.css:2038). The early-out never touches
	# `_iris.visible`, so no cover is stranded — the fight arrives the way a
	# capture run's does.
	if instant or Preferences.active.reduce_motion:
		return
	var stage: Vector2 = _stage_size()
	if stage.x <= 0.0:
		return
	_transit_seq += 1
	_iris_mat.set_shader_parameter("rect_size", stage)
	_iris_mat.set_shader_parameter("centre", at)
	var full: float = stage.length() * IRIS_SPAN
	_iris_mat.set_shader_parameter("radius", full)
	_iris.visible = true
	var tw: Tween = Motion.bez(self, _shrink_iris.bind(full), IRIS_TIME, Motion.TRANSIT)
	tw.finished.connect(_end_transit.bind(_transit_seq), CONNECT_ONE_SHOT)


func _shrink_iris(eased: float, full: float) -> void:
	_iris_mat.set_shader_parameter("radius", full * (1.0 - eased))


## The win leaf: amber light swells and fades over whatever the route swap
## delivers underneath (`victory-out`, navigation.js:52). WAAPI semantics —
## the ease runs once across the iteration, offsets interpolate linearly.
func bloom() -> void:
	_play_leaf(_bloom, BLOOM_AT, BLOOM_TRACK, BLOOM_TIME)


## The defeat leaf: the world fades to near-black over 700ms, then the host
## empties and the screen behind takes over (`defeat`, navigation.js:53).
func crack() -> void:
	_play_leaf(_crack, CRACK_AT, CRACK_TRACK, CRACK_TIME)


## The act-change plate: the next act's name and its omen, held over the map
## arriving underneath. Fired beside the route, never awaited.
func act_plate(act_name: String, omen_name: String, omen_tone: Color,
		omen_icon: Texture2D = null) -> void:
	if instant:
		return
	var stage: Vector2 = _stage_size()
	var act_pt: int = int(clampf(stage.x * 0.05, 28.0, 44.0))
	_plate_act.text = act_name.to_upper()
	_plate_act.add_theme_font_size_override("font_size", act_pt)
	_plate_act.add_theme_font_override("font",
		_tracked(GlassStyle.CINZEL_700, int(roundf(act_pt * 0.18)),
			GlassStyle.NOTO_SERIF_TC_BLACK))
	_plate_omen_row.visible = not omen_name.is_empty()
	if not omen_name.is_empty():
		_plate_omen.text = Locale.active.t("ui.omen.prefix") + omen_name.to_upper()
		_plate_omen.add_theme_color_override("font_color", omen_tone)
		_plate_omen.add_theme_font_override("font",
			_tracked(GlassStyle.CINZEL_500, 2))
		_plate_omen_icon.texture = omen_icon
		_plate_omen_icon.visible = omen_icon != null
		_plate_omen_icon.modulate = omen_tone
	_play_leaf(_plate, PLATE_AT, PLATE_TRACK, PLATE_TIME)


func _play_leaf(leaf: Control, at: Array[float], track: Array[float],
		seconds: float) -> void:
	# Bloom, crack and the act plate are all `#transit` children over there,
	# and :2038 hides the whole container under prefers-reduced-motion.
	if instant or Preferences.active.reduce_motion:
		return
	_transit_seq += 1
	_iris.visible = false
	_bloom.visible = leaf == _bloom
	_crack.visible = leaf == _crack
	_plate.visible = leaf == _plate
	leaf.modulate.a = 0.0
	var walk: Callable = func(x: float) -> void:
		leaf.modulate.a = Motion.keyframe(Motion.ease(Motion.TRANSIT, x), at, track)
	var tw: Tween = create_tween()
	tw.tween_method(walk, 0.0, 1.0, seconds)
	tw.finished.connect(_end_transit.bind(_transit_seq), CONNECT_ONE_SHOT)


func _end_transit(seq: int) -> void:
	if seq != _transit_seq:
		return
	_iris.visible = false
	_bloom.visible = false
	_crack.visible = false
	_plate.visible = false


## The tracked-Cinzel idiom `choice_screen.gd` and `settings_panel.gd` carry;
## duplicated here by the shared-surface rule rather than reached across.
static func _tracked(path: String, glyph_spacing: int,
		cjk_path: String = "") -> FontVariation:
	var tracked: FontVariation = FontVariation.new()
	tracked.base_font = GlassStyle.face(path, cjk_path)
	tracked.spacing_glyph = glyph_spacing
	return tracked


## Light floods the screen from `at` (stage px) in `colour`, then `on_covered`
## runs under the full cover — the route swap's hitch happens there — and the
## light clears over the arriving screen. Reduce Motion: a 150 ms fade to
## cover instead of the growing disc. `instant` (captures) and the headless
## renderer (tests, where nothing draws): the callback runs at once.
func flood(at: Vector2, colour: Color, on_covered: Callable) -> void:
	var stage: Vector2 = _stage_size()
	if instant or stage.x <= 0.0 or DisplayServer.get_name() == "headless":
		on_covered.call()
		return
	if _flood_tween != null:
		_flood_tween.kill()
	var full: float = stage.length() * IRIS_SPAN
	var reduced: bool = Preferences.active.reduce_motion
	_flood_mat.set_shader_parameter("rect_size", stage)
	_flood_mat.set_shader_parameter("centre", at)
	_flood_mat.set_shader_parameter("ink", Color(colour.lerp(Color("#05070e"), 0.55), 1.0))
	_flood_mat.set_shader_parameter("feather", stage.y * 0.18)
	_flood_mat.set_shader_parameter("radius", full if reduced else 0.0)
	_flood.modulate.a = 0.0 if reduced else 1.0
	_flood.visible = true
	_flood_tween = create_tween()
	if reduced:
		_flood_tween.tween_property(_flood, "modulate:a", 1.0, LeadlightMotion.REDUCED_FADE)
	else:
		_flood_tween.tween_method(func(r: float) -> void:
			_flood_mat.set_shader_parameter("radius", r), 0.0, full, IRIS_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_flood_tween.tween_callback(on_covered)
	_flood_tween.tween_property(_flood, "modulate:a", 0.0,
		LeadlightMotion.REDUCED_FADE if reduced else LeadlightMotion.SETTLE)
	_flood_tween.tween_callback(func() -> void: _flood.visible = false)


## The flame's flare: the bloom leaf, centred on `at` instead of the stage's
## fixed point. Draw-only; skipped under Reduce Motion like every leaf.
func flare(at: Vector2) -> void:
	if instant or Preferences.active.reduce_motion:
		return
	var stage: Vector2 = _stage_size()
	var r: float = stage.length() * 0.45
	_flare.size = Vector2(r, r) * 2.0
	_flare.position = at - Vector2(r, r)
	_flare.modulate.a = 0.0
	_flare.visible = true
	if _flare_tween != null:
		_flare_tween.kill()
	var walk: Callable = func(x: float) -> void:
		_flare.modulate.a = Motion.keyframe(Motion.ease(Motion.TRANSIT, x), BLOOM_AT, BLOOM_TRACK)
	_flare_tween = create_tween()
	_flare_tween.tween_method(walk, 0.0, 1.0, BLOOM_TIME * 0.6)
	_flare_tween.tween_callback(func() -> void: _flare.visible = false)


## The rite tap: every running leaf lands at its end. A flood that has not yet
## covered runs its callback first, so a skipped transition still arrives.
func skip() -> void:
	if _flood_tween != null and _flood_tween.is_valid():
		_flood_tween.custom_step(60.0)
	_flood_tween = null
	_flood.visible = false
	if _flare_tween != null:
		_flare_tween.kill()
		_flare_tween = null
	_flare.visible = false
	clear()


func set_grain(on: bool) -> void:
	_grain.visible = on


## Whether one of this layer's leaves is on screen: the wipe, a transit leaf,
## the iris, the flood, the flare or a Reduce Motion cross-fade. Main gives
## this layer the grain while one crosses the map (`Main._sync_map_grain`).
func leaves_showing() -> bool:
	for leaf: CanvasItem in [_wipe, _snapshot, _iris, _bloom, _crack, _plate, _flood, _flare]:
		if leaf.visible:
			return true
	return false


## Route reset: kill anything mid-flight. Main calls this when a route change
## must NOT carry ceremony across (save errors, hard resets).
func clear() -> void:
	if _wipe_tween != null:
		_wipe_tween.kill()
		_wipe_tween = null
	_wipe.visible = false
	_transit_seq += 1
	_iris.visible = false
	_bloom.visible = false
	_crack.visible = false
	_plate.visible = false


func _stage_size() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Vector2.ZERO
	return vp.get_visible_rect().size


## The 102° lantern-light band, stops verbatim from `#wipe`'s gradient.
func _band_texture() -> GradientTexture2D:
	var dir: Vector2 = Vector2(sin(deg_to_rad(102.0)), -cos(deg_to_rad(102.0)))
	var centre: Vector2 = Vector2(0.5, 0.5)
	return GlassStyle.grad_tex(
		PackedColorArray([
			Color(0.949, 0.757, 0.306, 0.0),
			Color(0.949, 0.757, 0.306, 0.0),
			Color(0.949, 0.757, 0.306, 0.10),
			Color(1.0, 0.953, 0.839, 0.22),
			Color(0.949, 0.757, 0.306, 0.10),
			Color(0.949, 0.757, 0.306, 0.0),
			Color(0.949, 0.757, 0.306, 0.0),
		]),
		PackedFloat32Array([0.0, 0.36, 0.45, 0.5, 0.55, 0.64, 1.0]),
		false, centre - dir * 0.5, centre + dir * 0.5)
