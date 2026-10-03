extends SceneTree
## Evidence for the title and its rooms (#655, docs/design/2026-10-03-title-rooms
## §6.3, §11.3–§11.5). Unlike tools/capture_title.gd, which composes the title
## from a synthesised context, this boots the real Main on the Development
## profile of whatever user dir the checkout isolates, seeds that profile to a
## state, and drives it as a player does: real taps and keys through the
## viewport, so focus, its visibility and every route change are the shipping
## ones.
##
##   godot --path . --position 40,40 [--fixed-fps 60] -s res://tools/capture_rooms.gd -- \
##       --shape=pad-landscape --locale=en --state=saved --out=/abs/still.png \
##       [--path=rest|settings|help|credits|vigil|rite|shift|tab|pressed|departure|confirm|
##               back|runmenu|abandon|leave|ledger|erase]
##       [--hold] [--burst=3]
##       [--seq=open|close --room=settings|help|credits|vigil --frames=40] [--rm]
##       [--measure=/abs/image]   (the oval measures of an existing still, at this shape)
##       [--control=/abs/image]   (a cold-boot still of the same state: the oval beyond it)
##
## --state: fresh (no run, no deeds), consent (fresh, with the first launch's
## consent line), saved (a run in Act II), vigil (the run, twelve pilgrimages
## of deeds and three shards); --consent owes the consent line in any state.
## --path: rest is the title at rest. settings, help, credits and vigil tap the
## room's word, then tap the room's own way back (a touch player's round trip).
## rite taps the lantern while the launch rite runs; shift presses a bare Shift
## (a screenshot shortcut); tab presses Tab (a keyboard player); pressed holds a
## finger down on the plaque; departure taps Rekindle (the departure's first
## beat) and confirm answers it over a saved run (the Begin Anew sheet); back
## taps the departure's Back (§6.3 path c); runmenu takes the road to the map,
## opens the run menu from the HUD and taps Return to Title (path e); abandon
## and leave stop on the run menu's Abandon Run and Leave the Road sheets,
## ledger on Settings' Ledger page and erase on its Erase Everything sheet. With --hold a room path stops in
## the room. Each still is taken 1 s after landing and prints the focus report
## and §6.3's oval measures (`_oval_measures`): the spec's 64 gold samples and
## gold band, and the ring line that catches the shipped ring where the spec's
## gold does not; --measure gives a before still's at the same geometry.
## The phone Vigil's RETURN stands below the stage until #655 PR C seats it:
## there the tap is delivered to the button as the viewport delivers a tap
## (a touch noted, focus held hidden, pressed), and the run says so.
## --seq saves every frame from the settled source (frame 0), runs the grey gate
## (no frame with more than 0.5% of its pixels within ±4 of the engine's 0.3
## grey) and the cut gate (no frame-to-frame change above an eighth of the whole
## change plus idle noise, the larger of the source's and the settled
## destination's; graded under --rm, reported otherwise), and exits 1 when a
## graded gate fails. --seq=fight takes a saved run's road to the map and
## enters its first fight through Main's own node handler (the map's 3D nodes
## have no 2D hit to tap).
## Never --headless: a headless run has no viewport texture.

const SETTLE_FRAMES: int = 45
const GREY: Color = Color8(77, 77, 77)
const GREY_TOLERANCE: int = 4
const GREY_SHARE: float = 0.005
## Every fourth pixel each way: a 0.5% share is still measured to ±0.05%.
const STRIDE: int = 4
const ROOM_WORDS: Dictionary = {
	"settings": "ui.menu.settings", "help": "ui.menu.howToPlay",
	"credits": "ui.menu.credits", "vigil": "ui.menu.theVigil",
}
## Each room's own way back, as shipped (the seat's Return replaces them in #655
## PR B). How to Play's Fight On waits at the foot of its scroll, below the fold
## for a touch player, so its way back is a tap on the veil.
const ROOM_EXITS: Dictionary = {
	"settings": "ui.menu.close", "help": "",
	"credits": "ui.credits.close", "vigil": "ui.vigil.return",
}
const VEIL_TAP: Vector2 = Vector2(24.0, 24.0)

var _args: Dictionary = {}
var _main: Main
var _failed: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var at: int = arg.find("=")
		if at > 0:
			_args[arg.substr(2, at - 2)] = arg.substr(at + 1)
		else:
			_args[arg.trim_prefix("--")] = "true"
	var shape: StringName = StringName(str(_args.get("shape", "pad-landscape")))
	var stage: Vector2i = StageShape.REFERENCES.get(shape, Vector2i(1180, 820))
	DisplayServer.window_set_size(stage)
	_seed(str(_args.get("state", "saved")))
	_main = (load("res://application/main.tscn") as PackedScene).instantiate() as Main
	# Main's own boot reads only these: the Development profile, the shape, the language.
	_main._boot_args = PackedStringArray(["--shape=%s" % shape,
		"--locale=%s" % str(_args.get("locale", "en"))])
	root.add_child(_main)
	_run.call_deferred()


func _run() -> void:
	await _frames(4)
	AudioServer.set_bus_mute(0, true)
	# Settings held in memory only: nothing this tool sets is written to disk.
	var preferences: Preferences = Preferences.new()
	preferences.language = str(_args.get("locale", "en"))
	# --state=consent: the first title after the language, its consent line lit;
	# --consent owes the line in any state (a player from before it existed).
	preferences.diagnostics_notice_seen = str(_args.get("state", "")) != "consent" \
		and not _args.has("consent")
	preferences.reduce_motion = _args.has("rm")
	Preferences.active = preferences
	var path: String = str(_args.get("path", "rest"))
	_main._title_kindled = path != "rite"
	_main._show_title()
	_hide_dev_word()
	if _args.has("measure"):
		await _settle()
		var image: Image = Image.load_from_file(str(_args["measure"]))
		print("measured %s: %s" % [str(_args["measure"]), _oval_measures(image)])
	elif _args.has("seq"):
		await _sequence(str(_args.get("seq", "open")), str(_args.get("room", "settings")))
	else:
		await _drive(path)
		await _still(str(_args.get("out", "/tmp/glassvow-rooms.png")))
	quit(1 if _failed else 0)


## The Development profile at `state`. The checkout's override.cfg keeps the
## whole user dir apart from the player's.
func _seed(state: String) -> void:
	SaveService.clear_run("", ScenarioKernel.RUN_PATH)
	SaveService.clear_vigil(ScenarioKernel.VIGIL_PATH)
	var vigil: VigilState = VigilState.blank()
	vigil.scenes_seen.append("opening")
	if state == "saved" or state == "vigil":
		var content: ContentDB = ContentDB.load_full()
		var run: RunState = RunState.new_run(content, 65501, "capture-rooms")
		run.map = WorldMap.benchmark(run).to_dict()
		run.act = 1
		run.waystones_lit = 4
		_carry_glass(content, run, "shatter")
		SaveService.store(run, ScenarioKernel.RUN_PATH)
	if state == "vigil":
		for deed: Array in [["runs", 12], ["wins", 3], ["slain", 214], ["shatters", 15],
				["kindles", 11], ["perfects", 1], ["bestVow", 2], ["bestWaystone", 9]]:
			vigil.deeds[deed[0]] = deed[1]
		vigil.runs_played = 12
		vigil.unlocks.assign(["emberglass", "aspect2", "card:quakeblow", "card:resonantLance"])
		vigil.shards.assign(["hollowLamplighter", "paleOnes", "usurper"])
		for id: String in ["hollowLamplighter", "paleOnes", "usurper"]:
			vigil.quests[id] = {"state": "complete", "progress": 3, "memory": {}}
	SaveService.store_vigil(vigil, ScenarioKernel.VIGIL_PATH)


## A tooling boot offers the Developer Console in the corner; no player sees it.
func _hide_dev_word() -> void:
	var title: TitleScreen = _title()
	if title != null and title._words.has("dev"):
		var dev: Control = title._words["dev"]
		dev.visible = false


## Eight panes of one way's glass in the deck: the saved run's lantern burns
## that way's colour (Frostlight for shatter), so the title's flame is cold
## blue, as in the before-stills, and the road under it holds no gold.
static func _carry_glass(content: ContentDB, run: RunState, way_id: String) -> void:
	for way: Dictionary in Flame.ways(content, run.aspect):
		if str(way.get("id", "")) != way_id:
			continue
		var table: Dictionary = way.get("affinity", {})
		var best: String = ""
		for id_v: Variant in table.keys():
			if best.is_empty() or float(str(table[id_v])) > float(str(table[best])):
				best = str(id_v)
		for _i: int in range(8):
			run.player.deck.append(CardInst.new(run.next_uid(), StringName(best), false))


func _title() -> TitleScreen:
	return _main._choice_screen as TitleScreen


func _drive(path: String) -> void:
	if path != "rite":
		await _settle()
	var title: TitleScreen = _title()
	match path:
		"rite":
			await _wait(0.6)
			await _tap(title.lantern.get_global_rect().get_center() + Vector2(0.0, title.lantern.size.y * 0.1))
		"shift":
			await _key(KEY_SHIFT)
		"tab":
			await _key(KEY_TAB)
		"pressed":
			await _press(title._plaque.get_global_rect().get_center(), true)
		"departure", "confirm", "back":
			var rekindle: Control = title._secondary if title._secondary != null else title.lantern
			await _tap(rekindle.get_global_rect().get_center())
			# The lantern's light floods out and clears before the departure takes a tap.
			await _settle()
			await _wait(1.0)
			var departure: DepartureScreen = _main._route_screen as DepartureScreen
			if path == "confirm" and departure != null:
				await _tap(departure.primary().get_global_rect().get_center())
			elif path == "back" and departure != null:
				await _tap_control(departure.find_child("Back", true, false) as Control)
		"runmenu", "abandon", "leave":
			await _open_run_menu(title)
			var key: String = {"runmenu": "ui.menu.returnTitle", "abandon": "ui.menu.abandonRun",
				"leave": "ui.menu.quitGame"}[path]
			await _tap_control(_labelled(_main._modal, Locale.active.t(key)) if _main._modal != null else null)
		"ledger", "erase":
			await _tap(_word(title, "settings").get_global_rect().get_center())
			await _settle()
			await _tap_control(_labelled(_main._modal, Locale.active.t("ui.settings.ledger")))
			await _settle()
			if path == "erase":
				await _tap_control(_labelled(_main._modal, Locale.active.t("ui.settings.eraseAll")))
		"settings", "help", "credits", "vigil":
			await _tap(_word(title, path).get_global_rect().get_center())
			await _settle()
			if _args.has("hold"):
				await _settle()
				return
			var key: String = str(ROOM_EXITS[path])
			if key.is_empty():
				await _tap(VEIL_TAP)
			else:
				await _tap_control(_labelled(_main, Locale.active.t(key)))
	await _settle()
	await _wait(1.0)


## Back to the Road by tap, the map's HUD menu by tap: the run menu open.
func _open_run_menu(title: TitleScreen) -> void:
	await _tap(title.lantern.get_global_rect().get_center())
	await _settle()
	await _wait(1.5)
	var menu: Control = null
	if _main._run_hud != null:
		for node: Node in _main._run_hud.find_children("", "BaseButton", true, false):
			var button: BaseButton = node
			if button.is_visible_in_tree() and button.tooltip_text == Locale.active.t("ui.hud.menu"):
				menu = button
	await _tap_control(menu)
	await _settle()


## A tap on `control`, or, when it stands off the stage, the same tap delivered
## to it as the viewport would (a touch noted, focus held hidden, pressed).
func _tap_control(control: Control) -> void:
	if control == null:
		push_error("capture_rooms: nothing to tap on this path")
		_failed = true
		return
	_tap_control_now(control)
	await _frames(2)


## The same tap on this frame.
func _tap_control_now(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	if Rect2(Vector2.ZERO, Vector2(root.size)).has_point(at):
		_tap_now(at)
		return
	print("delivered: '%s' stands below the stage at %s; its tap is delivered directly" % [
		(control as Button).text if control is Button else control.name, at])
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	LeadlightFocus.note(touch)
	control.grab_focus(true)
	(control as BaseButton).pressed.emit()


func _word(title: TitleScreen, room: String) -> Control:
	var label: String = Locale.active.t(str(ROOM_WORDS[room]))
	return _labelled(title, label)


## The button whose text reads `text`, in any case, that is on screen.
func _labelled(under: Node, text: String) -> Control:
	for node: Node in under.find_children("", "Button", true, false):
		var button: Button = node
		if button.is_visible_in_tree() and button.text.to_lower() == text.to_lower():
			return button
	return null


func _still(out: String) -> void:
	_hide_dev_word()
	await _frames(1)
	_report()
	var burst: int = int(str(_args.get("burst", "1")))
	for k: int in range(burst):
		var file: String = out if burst <= 1 else out.get_basename() + "-%d.png" % (k + 1)
		var image: Image = root.get_texture().get_image()
		image.save_png(file)
		print("rooms still: %s  %s" % [file, _oval_measures(image)])
		if k + 1 < burst:
			await _wait(1.0)


## Who holds focus, and is it shown? A touch player must see none of it.
func _report() -> void:
	var owner: Control = root.gui_get_focus_owner()
	var shown: PackedStringArray = PackedStringArray()
	for node: Node in _main.find_children("", "BaseButton", true, false):
		var button: BaseButton = node
		if button.has_focus(true):
			shown.append(str(button.get_path()))
	var title: TitleScreen = _title()
	print("focus: owner %s; shown on %s; lantern shown %s; plaque lit %s" % [
		owner.get_path() if owner != null else "none", shown if not shown.is_empty() else "nothing",
		title != null and title.lantern.has_focus(true),
		title != null and title._plaque.focused])


## §6.3's oval measures on `image`, at the title's own lantern geometry: the
## 64 ring samples and the ±6 px band at the spec's gold, then the samples
## where a ring line stands (a ridge: see `_ridge`), and, with --control (a
## cold-boot still of the same state), those ridges the control lacks.
func _oval_measures(image: Image) -> String:
	var out: String = "oval %d/64, ring band gold %d px; ring line %d/64" % [
		_oval_count(image), _band_gold(image), _ridge_count(image)]
	if _args.has("control"):
		var control: Image = Image.load_from_file(str(_args["control"]))
		out += ", beyond the control %d/64" % _ridge_count(image, control)
	return out


## The old focus ring's ellipse round the title's lantern: centre and radii.
func _ring() -> Array[Vector2]:
	var title: TitleScreen = _title()
	if title == null:
		return []
	var rect: Rect2 = title.lantern.get_global_rect()
	var side: float = minf(rect.size.x, rect.size.y)
	return [rect.get_center() + Vector2(0.0, side * 0.04), Vector2(side * 0.36, side * 0.50)]


## §6.3: of 64 samples on the old ring's path (±2 px), how many are gold.
func _oval_count(image: Image) -> int:
	var ring: Array[Vector2] = _ring()
	if ring.is_empty():
		return -1
	var hits: int = 0
	for i: int in range(64):
		var dir: Vector2 = Vector2.from_angle(TAU * float(i) / 64.0)
		for d: int in range(-2, 3):
			if _is_gold(image, Vector2i(ring[0] + dir * (ring[1] + Vector2(d, d)))):
				hits += 1
				break
	return hits


## Of the 64 samples on the old ring's path that fall on the stage, how many
## hold a ring line, and (with a control) how many the control does not. The
## spec's gold misses the shipped ring itself: a 1.2 px line of GOLD at 0.55
## over the blue road reads at saturation 0.10 to 0.15 (before/22 scores 1/64).
## A line is what it is, though: within ±2 px of the path, a pixel brighter by
## 0.12 than the road 4 px to either side of it, along the radius, at a sample
## and at one beside it (a ring runs on; a passing mote does not).
func _ridge_count(image: Image, control: Image = null) -> int:
	var ring: Array[Vector2] = _ring()
	if ring.is_empty():
		return -1
	var here: Array[bool] = []
	var there: Array[bool] = []
	for i: int in range(64):
		var dir: Vector2 = Vector2.from_angle(TAU * float(i) / 64.0)
		here.append(_ridge(image, ring, dir))
		there.append(control != null and _ridge(control, ring, dir))
	var hits: int = 0
	for i: int in range(64):
		var line: bool = here[i] and (here[(i + 63) % 64] or here[(i + 1) % 64])
		if line and not there[i]:
			hits += 1
	return hits


static func _ridge(image: Image, ring: Array[Vector2], dir: Vector2) -> bool:
	for d: int in range(-2, 3):
		var at: float = _value(image, ring[0] + dir * (ring[1] + Vector2(d, d)))
		var inside: float = _value(image, ring[0] + dir * (ring[1] + Vector2(d - 4, d - 4)))
		var outside: float = _value(image, ring[0] + dir * (ring[1] + Vector2(d + 4, d + 4)))
		if at > 0.45 and at - maxf(inside, outside) > 0.12:
			return true
	return false


static func _value(image: Image, at: Vector2) -> float:
	var pixel: Vector2i = Vector2i(at)
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height():
		return 1.0
	return image.get_pixelv(pixel).v


## §6.3: the gold pixels (the spec's gold) within ±6 px of the old ring's path.
func _band_gold(image: Image) -> int:
	var ring: Array[Vector2] = _ring()
	if ring.is_empty():
		return -1
	var seen: Dictionary = {}
	for i: int in range(1440):
		var angle: float = TAU * float(i) / 1440.0
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		for d: int in range(-6, 7):
			var at: Vector2i = Vector2i(ring[0] + dir * (ring[1] + Vector2(d, d)))
			if not seen.has(at):
				seen[at] = _is_gold(image, at)
	return seen.values().count(true)


## §6.3's gold: within ±12° of GOLD's hue, saturation over 0.45, value over 0.55.
static func _is_gold(image: Image, at: Vector2i) -> bool:
	if at.x < 0 or at.y < 0 or at.x >= image.get_width() or at.y >= image.get_height():
		return false
	var c: Color = image.get_pixelv(at)
	var hue_gap: float = absf(fposmod(c.h - LeadlightTokens.GOLD.h + 0.5, 1.0) - 0.5) * 360.0
	return hue_gap <= 12.0 and c.s > 0.45 and c.v > 0.55


## A route change, frame by frame from the settled source: open taps the room's
## word on the title; close opens it first and taps its way back.
func _sequence(kind: String, room: String) -> void:
	await _settle()
	var title: TitleScreen = _title()
	var fight: MapNode = null
	if kind == "close":
		await _tap(_word(title, room).get_global_rect().get_center())
		await _settle()
		await _wait(0.6)
	elif kind == "fight":
		await _tap(title.lantern.get_global_rect().get_center())
		await _settle()
		await _wait(1.5)
		for node: MapNode in _main._map.nodes:
			if node.type == "monster" and fight == null:
				fight = node
	var frames: Array[Image] = []
	await _frames(1)
	var idle: Image = root.get_texture().get_image()
	await _frames(1)
	frames.append(root.get_texture().get_image())
	if fight != null:
		_main._prepare_encounter(fight)
	elif kind == "open":
		_tap_now(_word(title, room).get_global_rect().get_center())
	elif str(ROOM_EXITS[room]).is_empty():
		_tap_now(VEIL_TAP)
	else:
		_tap_control_now(_labelled(_main, Locale.active.t(str(ROOM_EXITS[room]))))
	for _i: int in range(int(str(_args.get("frames", "40")))):
		_hide_dev_word()
		await process_frame
		frames.append(root.get_texture().get_image())
	var out: String = str(_args.get("out", "/tmp/glassvow-seq.png"))
	for i: int in range(frames.size()):
		frames[i].save_png(out.get_basename() + "-%02d.png" % i)
	_gates(frames, idle)


func _gates(frames: Array[Image], idle: Image) -> void:
	var worst_grey: float = 0.0
	var worst_at: int = 0
	for i: int in range(frames.size()):
		var share: float = _grey_share(frames[i])
		if share > worst_grey:
			worst_grey = share
			worst_at = i
	var grey_pass: bool = worst_grey <= GREY_SHARE
	print("grey gate %s: worst frame %d has %.2f%% grey (limit %.1f%%)" % [
		"PASS" if grey_pass else "FAIL", worst_at, worst_grey * 100.0, GREY_SHARE * 100.0])
	var whole: float = _change(frames[0], frames[frames.size() - 1])
	# Idle noise at both ends: the source's before the tap, the settled
	# destination's between its last two frames (a flame flickers under
	# Reduce Motion too).
	var noise: float = maxf(_change(idle, frames[0]),
		_change(frames[frames.size() - 2], frames[frames.size() - 1]))
	var step: float = 0.0
	var step_at: int = 0
	for i: int in range(1, frames.size()):
		var change: float = _change(frames[i - 1], frames[i])
		if change > step:
			step = change
			step_at = i
	var limit: float = whole / 8.0 + noise
	var cut_pass: bool = step <= limit
	var graded: bool = _args.has("rm")
	print("cut gate %s: largest step %.4f at frame %d, whole change %.4f, idle %.4f, limit %.4f%s" % [
		"PASS" if cut_pass else "FAIL", step, step_at, whole, noise, limit,
		"" if graded else " (reported, not graded without --rm)"])
	_failed = _failed or not grey_pass or (graded and not cut_pass)


static func _grey_share(image: Image) -> float:
	var near: int = 0
	var seen: int = 0
	for y: int in range(0, image.get_height(), STRIDE):
		for x: int in range(0, image.get_width(), STRIDE):
			var c: Color = image.get_pixel(x, y)
			seen += 1
			if absi(c.r8 - GREY.r8) <= GREY_TOLERANCE and absi(c.g8 - GREY.g8) <= GREY_TOLERANCE \
					and absi(c.b8 - GREY.b8) <= GREY_TOLERANCE:
				near += 1
	return float(near) / float(maxi(seen, 1))


## Mean absolute channel change between two frames, 0..1.
static func _change(a: Image, b: Image) -> float:
	var total: float = 0.0
	var seen: int = 0
	for y: int in range(0, a.get_height(), STRIDE):
		for x: int in range(0, a.get_width(), STRIDE):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			total += (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)) / 3.0
			seen += 1
	return total / float(maxi(seen, 1))


func _tap(at: Vector2) -> void:
	_tap_now(at)
	await _frames(2)


## A finger down and up in one frame, as a quick tap arrives.
func _tap_now(at: Vector2) -> void:
	_move(at)
	for pressed: bool in [true, false]:
		root.push_input(_button(at, pressed), true)


func _press(at: Vector2, pressed: bool) -> void:
	_move(at)
	root.push_input(_button(at, pressed), true)
	await _frames(2)


func _move(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)


static func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = at
	event.global_position = at
	return event


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)
	await _frames(2)


func _settle() -> void:
	await _frames(SETTLE_FRAMES)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame
