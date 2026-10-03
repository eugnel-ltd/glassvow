extends SceneTree
## Stills of the title, the first launch and the settings room at any shape,
## locale and save state, from the production TitleScreen and SettingsPanel
## (docs/design/2026-10-02-opening-start). A composition harness: the state is
## synthesised here, so it proves what the screen draws for a state; the real
## boot (tools/shot.sh) proves Main hands it that state.
##
##   godot --path . --position 40,40 -s res://tools/capture_title.gd -- \
##       --shape=pad-landscape --locale=en --state=saved --out=/tmp/t.png \
##       [--rite=1.6] [--settings] [--embark] [--flood=0.3] [--burst=3] [--reduce-motion] [--scale=2]
##       [--pose=pressed|focused|beckon|ember] [--departure=embark|same|gift|art]
##
## The boot splash is this harness at --state=fresh --rite=0 --scale=2 on the
## identity shape: frame 0 of the launch rite (assets/art/title/splash.png).
##
## --state: fresh (no run, no deeds), first (first launch: language and
## consent), saved (a run with a Steady Frostlight flame), vigil (saved run,
## deeds and three shards), consent (the first title after the language: the
## consent line). --rite=T photographs the launch rite T seconds in;
## --burst=N takes N frames one second apart (idle motion). --pose holds the
## lantern's button in a state: pressed (a finger down on the plaque),
## focused (keyboard focus on the lantern), beckon (the first title's breath at
## its height), ember (the idle ember halfway to the plaque).
## Never --headless: a headless run has no viewport texture.

const SETTLE_FRAMES: int = 45

var _args: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var at: int = arg.find("=")
		if at > 0:
			_args[arg.substr(2, at - 2)] = arg.substr(at + 1)
		else:
			_args[arg.trim_prefix("--")] = "true"
	var shape: StringName = StringName(str(_args.get("shape", "pad-landscape")))
	var stage: Vector2i = StageShape.REFERENCES.get(shape, Vector2i(1180, 820))
	var scale: float = float(str(_args.get("scale", "1")))
	DisplayServer.window_set_size(Vector2i(Vector2(stage) * scale))
	root.content_scale_size = stage
	var code: StringName = StringName(str(_args.get("locale", "en")))
	Locale.active = Locale.new(code)
	Preferences.active = Preferences.new()
	Preferences.active.reduce_motion = _args.has("reduce-motion")
	root.theme = GlassStyle.theme()
	var state: String = str(_args.get("state", "saved"))
	var rite_at: float = float(str(_args.get("rite", "-1")))
	var screen: TitleScreen = TitleScreen.new(context(shape, state, rite_at >= 0.0))
	root.add_child(screen)
	screen.kindle_now()
	if rite_at >= 0.0 and screen.rite != null:
		# Held at T: the screen's own clock never moves the rite on.
		screen.hold_rite = true
		screen.rite.advance(rite_at)
		screen.lantern.flame.pinned = true
	await process_frame
	if _args.has("embark") or _args.has("departure"):
		_depart(screen, shape, state, str(_args.get("departure", "embark")))
	if _args.has("settings"):
		if state != "first":
			Preferences.active.diagnostics_notice_seen = true
		var panel: SettingsPanel = SettingsPanel.new(Preferences.active)
		panel.set_shape(shape)
		root.add_child(panel)
	for _i: int in range(SETTLE_FRAMES):
		await process_frame
	if is_instance_valid(screen):
		_pose(screen, str(_args.get("pose", "")))
	await process_frame
	await process_frame
	if _args.has("flood"):
		# The lantern's exit (§7 T6) photographed T seconds into the flood.
		var layer: TransitionLayer = TransitionLayer.new()
		root.add_child(layer)
		layer.flood(screen.wick_on_stage(), screen.lantern.light(), func() -> void: pass)
		await create_timer(float(str(_args.get("flood", "0.3")))).timeout
	var out: String = str(_args.get("out", "/tmp/glassvow-title.png"))
	var burst: int = int(str(_args.get("burst", "1")))
	if burst <= 1:
		root.get_viewport().get_texture().get_image().save_png(out)
		print("title still: " + out)
		quit(0)
		return
	# Idle-motion proof: `burst` frames one second apart, nothing touched.
	for k: int in range(burst):
		var path: String = out.get_basename() + "-%d.png" % (k + 1)
		root.get_viewport().get_texture().get_image().save_png(path)
		print("title still: " + path)
		if k + 1 < burst:
			await create_timer(1.0).timeout
	quit(0)


## The departure on the road (DepartureScreen) as Main shows it on a later run
## with the Lamplighter met: (a) both classes and three vows, a saved run to
## warn about ("same" adds setting out as before), (b) his gift, (c) the art.
## --embark is the older name for --departure=embark.
func _depart(screen: TitleScreen, shape: StringName, state: String, beat: String) -> void:
	var content: ContentDB = ContentDB.load_full()
	Locale.active.hydrate_content(content)
	var departure: DepartureScreen = DepartureScreen.new(shape)
	if beat == "embark" or beat == "same":
		var same: Dictionary = {"aspect": 0, "vow": 1, "art": "flare"} if beat == "same" else {}
		departure.show_embark(content.aspects, content.vows, true, 3,
			state == "saved" or state == "vigil", 0, 1, same, true)
	else:
		var boon_ids: Array = content.boons.keys().slice(0, 3)
		var aspect: Dictionary = content.aspects[0]
		departure.show_gift(aspect, content.boons, content.arts, boon_ids,
			StringName(str(content.arts.keys()[0])))
	screen.queue_free()
	root.add_child(departure)
	if beat == "art":
		departure._pick_boon(str(departure._boon_ids[0]))


func _pose(screen: TitleScreen, pose: String) -> void:
	var beckon: TitleBeckon = screen._beckon
	match pose:
		"pressed":
			screen._reach.button_down.emit()
			screen._plaque.pivot_offset = screen._plaque.size * 0.5
			screen._plaque.scale = Vector2.ONE * LeadlightMotion.PRESS_SCALE
			screen.lantern.flare = 0.5
		"focused":
			screen.lantern.grab_focus()
		"beckon":
			beckon.pulse()
			beckon._process(TitleBeckon.PULSE * 0.5)
			beckon.process_mode = Node.PROCESS_MODE_DISABLED
		"ember":
			beckon.arm()
			beckon._process(TitleBeckon.IDLE + 0.01)
			beckon._process(TitleBeckon.RISE * 0.55)
			beckon.process_mode = Node.PROCESS_MODE_DISABLED


static func context(shape: StringName, state: String, rite: bool) -> Dictionary:
	var choices: Array[Dictionary] = []
	var saved: bool = state == "saved" or state == "vigil"
	if saved:
		choices.append({"id": "continue", "label": Locale.active.t("ui.menu.backToRoad")})
	for row: Array in [["begin", "ui.menu.rekindle"], ["vigil", "ui.menu.theVigil"],
			["help", "ui.menu.howToPlay"], ["settings", "ui.menu.settings"],
			["credits", "ui.menu.credits"], ["quit", "ui.menu.quit"]]:
		choices.append({"id": row[0], "label": Locale.active.t(str(row[1]))})
	var ctx: Dictionary = {
		"shape": String(shape), "choices": choices,
		"brand": Locale.active.t("ui.brand.title"), "version": "1.0.0",
		"rite": rite or state == "first", "ask_language": state == "first",
		"language_default": String(Locale.active.code),
		"ask_consent": state == "first" or state == "consent",
	}
	if saved:
		ctx["sub"] = Locale.active.t("ui.hud.actWaystone", {"act": 2, "n": 4})
		ctx["reading"] = {"tier": "STEADY", "dominant": "shatter", "fringe": "",
			"shares": {"shatter": 0.71, "lantern": 0.17, "edge": 0.12}}
	if state == "vigil":
		ctx["shards"] = ["hollowLamplighter", "paleOnes", "usurper"]
		var n: Callable = LeadlightNumerals.carved
		var stats: String = Locale.active.t("ui.brand.stats",
			{"runs": n.call(12), "wins": n.call(3), "slain": n.call(214)})
		var lines: Array[String] = []
		for part: String in stats.split(" · "):
			lines.append(Main._carve(part))
		lines.append(Main._carve(Locale.active.t("ui.brand.secrets", {"n": n.call(4)}).trim_prefix(" · ")))
		ctx["deeds"] = lines
	return ctx
