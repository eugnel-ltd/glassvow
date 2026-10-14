class_name HoloLab
extends Control
## Research (#657 holo, never shipped): the hologram candidates on real cards.
##
##   godot --path . -- --holo --holo-cand=back-veil              # window
##   godot --path . -- --holo --holo-cand=rare-crackle --holo-sweep
##   godot --path . -- --holo --holo-cand=back-veil --holo-sheet --shot=x.png
##   godot --path . -- --holo --holo-cand=back-veil --holo-device  # gravity
##   --holo-shape=pad|phone  (stage 1180x820 at card 152, or 844x390 at 104)
##
## Sweep: a 5 s Lissajous through the whole -1..1 throw, driving BOTH the
## card's own tilt hook (hold_pose, the slab leans) and the holo uniform.
## Device: HoloMotion (gravity, pointer fallback) drives the holo uniform only;
## the slabs stay frozen, as they would in the hand.

const SH: String = "res://research/holo/shaders/"
const BACK_ART: Array[String] = ["vault-B", "rose-A", "eclipse-C"]
const BACK_SURFACE: String = "plastic"
const SWEEP_S: float = 5.0
const SHEET_TILTS: Array[Vector2] = [Vector2(-0.9, -0.6), Vector2(0.0, 0.0), Vector2(0.9, 0.6)]
const SHAPES: Dictionary = {
	"pad": {"stage": Vector2i(1180, 820), "card_w": 152.0},
	"phone": {"stage": Vector2i(844, 390), "card_w": 104.0},
}
const CANDIDATES: Dictionary = {
	"back-veil": {"shader": "back_veil", "cards": ["@backs"], "title": "Back direction B1 · veil (tuned per back)"},
	"back-panes": {"shader": "back_panes", "cards": ["@backs"], "title": "Back direction B2 · lit panes (tuned per back)"},
	"back-gilt": {"shader": "back_gilt", "cards": ["@backs"], "title": "Back direction B3 · holo gilt (tuned per back)"},
	"starter-none": {"shader": "", "cards": ["strike", "defend"], "title": "Starter · bare (no holo)"},
	"common-rule": {"shader": "front_common_rule", "cards": ["quickSlash", "brace"], "title": "Common · silver rule"},
	"uncommon-reverse": {"shader": "front_uncommon_reverse", "cards": ["tempest", "bulwark"], "title": "Uncommon · reverse holo"},
	"rare-crackle": {"shader": "front_rare_crackle", "cards": ["oblivionStrike", "aegis"], "title": "Rare · crackle glass"},
	"special-oil": {"shader": "front_special_oil", "cards": ["hex", "wound"], "title": "Special (curse/status) · oil"},
	"mythic-lantern": {"shader": "mythic_lantern", "cards": ["emberEye"], "title": "Mythic · 'A Lantern with No Flame' (stand-in art)"},
	"mythic-door": {"shader": "mythic_door", "cards": ["eclipseSlash"], "title": "Mythic · 'The Shadow of a Door' (stand-in art)"},
	"mythic-shade": {"shader": "mythic_shade", "cards": ["phantomBlades"], "title": "Mythic · 'Your Own Shade' (stand-in art)"},
}
## Per-back knobs (owner, 14 Oct): each back's hologram is tuned to its own
## painting, and the same back looks the same on every card.
const BACK_KNOBS: Dictionary = {
	"back_veil": {
		"vault-B": {"band_mode": 0, "band_angle": 8.0, "centre": Vector2(76, 108), "palette": Color(0.55, 0.85, 1.0), "palette_mix": 0.45, "strength": 0.85, "scale": 0.8},
		"rose-A": {"band_mode": 1, "centre": Vector2(76, 108), "palette": Color(1.0, 0.55, 0.9), "palette_mix": 0.2, "strength": 0.80, "scale": 0.7},
		"eclipse-C": {"band_mode": 2, "centre": Vector2(76, 104), "palette": Color(1.0, 0.8, 0.45), "palette_mix": 0.5, "strength": 0.75, "scale": 1.0},
	},
	"back_panes": {
		"vault-B": {"band_mode": 0, "band_angle": 8.0, "centre": Vector2(76, 108), "palette": Color(0.55, 0.85, 1.0), "palette_mix": 0.35, "strength": 1.2, "scale": 1.3},
		"rose-A": {"band_mode": 1, "centre": Vector2(76, 108), "palette": Color(1.0, 0.55, 0.9), "palette_mix": 0.15, "strength": 1.2, "scale": 0.8},
		"eclipse-C": {"band_mode": 2, "centre": Vector2(76, 104), "palette": Color(1.0, 0.8, 0.45), "palette_mix": 0.4, "strength": 1.0, "scale": 1.0},
	},
	"back_gilt": {
		"vault-B": {"band_mode": 0, "band_angle": 8.0, "centre": Vector2(76, 108), "palette": Color(0.6, 0.9, 1.0), "palette_mix": 0.2, "strength": 0.75, "scale": 1.0, "gold_hue": 0.53, "gold_tol": 0.05},
		"rose-A": {"band_mode": 1, "centre": Vector2(76, 108), "palette": Color(1.0, 0.6, 0.9), "palette_mix": 0.1, "strength": 0.85, "scale": 0.8, "gold_hue": 0.11, "gold_tol": 0.06},
		"eclipse-C": {"band_mode": 2, "centre": Vector2(76, 104), "palette": Color(1.0, 0.85, 0.5), "palette_mix": 0.45, "strength": 0.50, "scale": 1.2, "gold_hue": 0.10, "gold_tol": 0.07, "env_only": 1.0},
	},
}

var content: ContentDB
var _cand: String = "back-veil"
var _shape: String = "pad"
var _sweep: bool = false
var _sheet: bool = false
var _device: bool = false
var _fixed: Vector2 = Vector2.ZERO
var _frames_dir: String = ""   # --holo-frames=<dir>: sweep frame by frame to PNGs
var _frame_n: int = 0
var _absolute: bool = false
var _wobble: bool = false
var _nonce: String = ""
var _t: float = 0.0
var _cards: Array[CardView] = []
var _mats: Array[ShaderMaterial] = []
var _tilts: Array[Vector2] = []      # per card, sheet mode only
var _motion: HoloMotion
var _readout: Label
var _frame_ms: float = 0.0
var _worst: PackedFloat32Array = PackedFloat32Array()


func _init(db: ContentDB) -> void:
	content = db
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--holo-cand="):
			_cand = arg.trim_prefix("--holo-cand=")
		elif arg.begins_with("--holo-shape="):
			_shape = arg.trim_prefix("--holo-shape=")
		elif arg == "--holo-sweep":
			_sweep = true
		elif arg == "--holo-sheet":
			_sheet = true
		elif arg.begins_with("--holo-frames="):
			_frames_dir = arg.trim_prefix("--holo-frames=")
		elif arg == "--holo-wobble":
			_wobble = true
		elif arg == "--holo-absolute":
			_absolute = true
		elif arg.begins_with("--holo-nonce="):
			_nonce = arg.trim_prefix("--holo-nonce=")
		elif arg == "--holo-device":
			_device = true
		elif arg.begins_with("--holo-tilt="):
			var p: PackedStringArray = arg.trim_prefix("--holo-tilt=").split(",")
			if p.size() == 2:
				_fixed = Vector2(float(p[0]), float(p[1]))


func _ready() -> void:
	var shape: Dictionary = SHAPES.get(_shape, SHAPES["pad"])
	var stage: Vector2i = shape["stage"]
	get_window().content_scale_size = stage
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.043, 0.055, 0.102)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# One candidate, or several side by side ("a,b": the device check).
	var parts: PackedStringArray = _cand.split(",", false)
	var titles: PackedStringArray = PackedStringArray()
	var tilts: Array[Vector2] = [_fixed]
	if _sheet:
		tilts = SHEET_TILTS
	var catalog: Dictionary = CardLab.load_catalog(content)
	var uid: int = 1
	var rows_n: int = 0
	for part: String in parts:
		if not CANDIDATES.has(part):
			push_error("holo lab: no such candidate %s" % part)
			continue
		var spec: Dictionary = CANDIDATES[part]
		var title_text: String = spec["title"]
		titles.append(title_text)
		var ids: Array[String] = []
		for c: String in spec["cards"]:
			if c == "@backs":
				for b: String in BACK_ART:
					ids.append("back:" + b)
			else:
				ids.append(c)
		rows_n += ids.size()
		for id: String in ids:
			for t: Vector2 in tilts:
				var card: CardView = _build(id, catalog, uid)
				uid += 1
				add_child(card)
				_cards.append(card)
				_tilts.append(t)
				var mat: ShaderMaterial = _material(spec, id)
				_mats.append(mat)
				if mat != null:
					card.set_holo(mat)
	var card_w: float = shape["card_w"]
	_layout(stage, card_w, rows_n, tilts.size())
	var title: Label = Label.new()
	title.text = "%s   [%s]%s" % [" + ".join(titles), _shape,
		"   tilts: lean left-up · flat · lean right-down" if _sheet else ""]
	title.add_theme_font_size_override("font_size", 14 if _shape == "pad" else 11)
	title.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
	title.position = Vector2(16, 8)
	add_child(title)
	if _device:
		_motion = HoloMotion.new()
		_motion.reduce_motion = Preferences.active != null and Preferences.active.reduce_motion
		_motion.absolute = _absolute
		add_child(_motion)
		_readout = Label.new()
		_readout.add_theme_font_size_override("font_size", 12)
		_readout.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
		_readout.position = Vector2(16, get_viewport_rect().size.y - 40)
		add_child(_readout)
	# Hold the sheet's and the fixed poses once the cards have mounted.
	for _i: int in range(3):
		await get_tree().process_frame
	for i: int in range(_cards.size()):
		if not _sweep and not _device:
			_cards[i].hold_pose(_tilts[i])
		_push(i, _tilts[i])


func _build(id: String, catalog: Dictionary, uid: int) -> CardView:
	var data: Dictionary
	if id.begins_with("back:"):
		data = {"back": "res://research/holo/backs/%s.png" % id.trim_prefix("back:"),
			"surface": BACK_SURFACE}
	else:
		data = catalog.get(id, {}).duplicate()
		if data.is_empty():
			data = _full_content_card(id)
	var cost_v: Variant = data.get("cost")
	var cost: int = 0 if cost_v == null else int(float(str(cost_v)))
	var card: CardView = CardView.new(CardInst.new(uid, StringName(id)), data, cost)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _material(spec: Dictionary, id: String) -> ShaderMaterial:
	var name: String = spec["shader"]
	if name == "":
		return null
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(SH + name + ".gdshader")
	if name.begins_with("mythic_"):
		var art: Texture2D = load(CardView.ART_DIR + id + ".jpg")
		mat.set_shader_parameter("art_tex", art)
		mat.set_shader_parameter("art_win", _cover(art))
	elif BACK_KNOBS.has(name):
		var knobs: Dictionary = BACK_KNOBS[name].get(id.trim_prefix("back:"), {})
		for k: String in knobs:
			mat.set_shader_parameter(k, knobs[k])
	return mat


static func _full_content_card(id: String) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/full-content.json"))
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var doc: Dictionary = raw
	var cards: Dictionary = doc.get("cards", {})
	var row: Dictionary = cards.get(id, {})
	var out: Dictionary = {}
	for k: String in ["name", "type", "rarity", "cost", "text", "target", "unplayable"]:
		if row.has(k):
			out[k] = row[k]
	return out


## The art's cover-fit window in its own UV, as the card's TextureRect
## (STRETCH_KEEP_ASPECT_COVERED, centred) crops it into the 148 x 91 window.
static func _cover(tex: Texture2D) -> Vector4:
	var a: float = float(tex.get_width()) / float(tex.get_height())
	var w: float = 148.0 / 91.0
	if a > w:
		var du: float = w / a
		return Vector4((1.0 - du) * 0.5, 0.0, du, 1.0)
	var dv: float = a / w
	return Vector4(0.0, (1.0 - dv) * 0.5, 1.0, dv)


func _layout(stage: Vector2i, card_w: float, rows_n: int, cols_n: int) -> void:
	# Lay out in the canvas the window really has (main may flex the stage),
	# with the card at the shape's width RELATIVE to the stage's width.
	var vis: Vector2 = get_viewport_rect().size
	var k: float = vis.x / float(stage.x)
	var s: float = card_w * k / CardView.CARD_W
	var cw: float = CardView.CARD_W * s
	var ch: float = CardView.CARD_H * s
	var gap: float = 26.0 * s
	var per_row: int = rows_n if cols_n == 1 else cols_n
	var rows: int = 1 if cols_n == 1 else rows_n
	if cols_n == 1 and rows_n * (cw + gap) > vis.x - 40.0 * k:
		per_row = maxi(1, int((vis.x - 40.0 * k) / (cw + gap)))
		rows = ceili(float(rows_n) / float(per_row))
	var total: Vector2 = Vector2(per_row * cw + (per_row - 1) * gap, rows * ch + (rows - 1) * gap)
	var origin: Vector2 = (vis - total) * 0.5 + Vector2(0, 10.0 * k)
	for i: int in range(_cards.size()):
		var col: int = i % per_row
		var row: int = i / per_row
		var c: CardView = _cards[i]
		c.scale = Vector2(s, s)
		c.position = origin + Vector2(col * (cw + gap), row * (ch + gap))


func _grab() -> void:
	if _frames_dir == "" or not _sweep:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/f%04d.png" % [_frames_dir, _frame_n])
	_frame_n += 1
	if _frame_n >= int(SWEEP_S * 30.0):
		get_tree().quit(0)


func _push(i: int, t: Vector2) -> void:
	if _mats[i] != null:
		_mats[i].set_shader_parameter("tilt", t)


func _process(delta: float) -> void:
	_frame_ms = lerpf(_frame_ms, delta * 1000.0, 0.1)
	_worst.append(delta * 1000.0)
	if _worst.size() > 120:
		_worst.remove_at(0)
	if _sweep and not _device:
		_t += (1.0 / 30.0) if _frames_dir != "" else delta
		var ph: float = TAU * _t / SWEEP_S
		var t: Vector2 = Vector2(sin(ph), 0.75 * sin(2.0 * ph))
		for i: int in range(_cards.size()):
			_cards[i].hold_pose(t)
			_push(i, t)
		if _frames_dir != "" and _frame_n >= 0 and _t > 0.0:
			_grab()
	elif _device and _motion != null:
		# --holo-device --holo-sweep: the motion signal plus a synthetic lean,
		# so a resting device still exercises a moving holo (stages frozen).
		var extra: Vector2 = Vector2.ZERO
		if _wobble:
			_t += delta
			var ph: float = TAU * _t / SWEEP_S
			extra = Vector2(sin(ph), 0.75 * sin(2.0 * ph))
		for i: int in range(_cards.size()):
			_push(i, (_motion.tilt + extra).clamp(Vector2(-1, -1), Vector2(1, 1)))
		_readout.text = "[%s%s] source %s   gravity (%.2f, %.2f, %.2f)   tilt (%.2f, %.2f)   frame %.1f ms   worst/2s %.1f ms" % [
			_nonce, " absolute" if _absolute else " calibrated", _motion.source, _motion.raw.x, _motion.raw.y, _motion.raw.z,
			_motion.tilt.x, _motion.tilt.y, _frame_ms, _worst_ms()]


func _worst_ms() -> float:
	var w: float = 0.0
	for v: float in _worst:
		w = maxf(w, v)
	return w
