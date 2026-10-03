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
##       [--path=rest|settings|help|credits|vigil|rite|shift|tab|pressed|departure|confirm]
##       [--hold] [--burst=3]
##       [--seq=open|close --room=settings|help|credits|vigil --frames=40] [--rm]
##
## --state: fresh (no run, no deeds), consent (fresh, with the first launch's
## consent line), saved (a run in Act II), vigil (the run, twelve pilgrimages
## of deeds and three shards).
## --path: rest is the title at rest. settings, help, credits and vigil tap the
## room's word, then tap the room's own way back (a touch player's round trip).
## rite taps the lantern while the launch rite runs; shift presses a bare Shift
## (a screenshot shortcut); tab presses Tab (a keyboard player); pressed holds a
## finger down on the plaque; departure taps Rekindle (the departure's first
## beat) and confirm answers it over a saved run (the Begin Anew sheet). With
## --hold a room path stops in the room. Each still is taken 1 s after landing
## and prints the focus report and the oval count (a pass is a title at rest's
## own count: the road's lamps alone).
## --seq saves every frame from the settled source (frame 0), runs the grey gate
## (no frame with more than 0.5% of its pixels within ±4 of the engine's 0.3
## grey) and the cut gate (no frame-to-frame change above an eighth of the whole
## change plus idle noise; graded under --rm, reported otherwise), and exits 1
## when a graded gate fails.
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
	# --state=consent: the first title after the language, its consent line lit.
	preferences.diagnostics_notice_seen = str(_args.get("state", "")) != "consent"
	preferences.reduce_motion = _args.has("rm")
	Preferences.active = preferences
	var path: String = str(_args.get("path", "rest"))
	_main._title_kindled = path != "rite"
	_main._show_title()
	_hide_dev_word()
	if _args.has("seq"):
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
		"departure", "confirm":
			var rekindle: Control = title._secondary if title._secondary != null else title.lantern
			await _tap(rekindle.get_global_rect().get_center())
			# The lantern's light floods out and clears before the departure takes a tap.
			await _settle()
			await _wait(1.0)
			var departure: DepartureScreen = _main._route_screen as DepartureScreen
			if path == "confirm" and departure != null:
				await _tap(departure.primary().get_global_rect().get_center())
		"settings", "help", "credits", "vigil":
			await _tap(_word(title, path).get_global_rect().get_center())
			await _settle()
			if _args.has("hold"):
				await _settle()
				return
			var exit: Vector2 = _exit_point(path)
			if exit.x < 0.0:
				push_error("capture_rooms: no way back found in %s" % path)
				_failed = true
				return
			await _tap(exit)
	await _settle()
	await _wait(1.0)


## Where a touch player taps to leave `room`; negative when there is no way.
func _exit_point(room: String) -> Vector2:
	var key: String = str(ROOM_EXITS[room])
	if key.is_empty():
		return VEIL_TAP
	var exit: Control = _labelled(_main, Locale.active.t(key))
	return exit.get_global_rect().get_center() if exit != null else Vector2(-1.0, -1.0)


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
		print("rooms still: %s  oval %d/64" % [file, _oval_count(image)])
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


## §6.3: gold samples on the old focus ring's path round the title's lantern.
## Measured thresholds (hue within 20° of GOLD, saturation over 0.25, value
## over 0.45): the shipped ring after a Vigil return scores 30/64 over the
## Frostlight road and a title at rest 1/64, so a pass is the rest count.
func _oval_count(image: Image) -> int:
	var title: TitleScreen = _title()
	if title == null:
		return -1
	var rect: Rect2 = title.lantern.get_global_rect()
	var side: float = minf(rect.size.x, rect.size.y)
	var centre: Vector2 = rect.get_center() + Vector2(0.0, side * 0.04)
	var radius: Vector2 = Vector2(side * 0.36, side * 0.50)
	var hits: int = 0
	for i: int in range(64):
		var angle: float = TAU * float(i) / 64.0
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		for d: int in range(-2, 3):
			var at: Vector2i = Vector2i(centre + dir * (radius + Vector2(d, d)))
			if _is_gold(image, at):
				hits += 1
				break
	return hits


static func _is_gold(image: Image, at: Vector2i) -> bool:
	if at.x < 0 or at.y < 0 or at.x >= image.get_width() or at.y >= image.get_height():
		return false
	var c: Color = image.get_pixelv(at)
	var hue_gap: float = absf(fposmod(c.h - LeadlightTokens.GOLD.h + 0.5, 1.0) - 0.5) * 360.0
	return hue_gap <= 20.0 and c.s > 0.25 and c.v > 0.45


## A route change, frame by frame from the settled source: open taps the room's
## word on the title; close opens it first and taps its way back.
func _sequence(kind: String, room: String) -> void:
	await _settle()
	var title: TitleScreen = _title()
	if kind == "close":
		await _tap(_word(title, room).get_global_rect().get_center())
		await _settle()
		await _wait(0.6)
	var frames: Array[Image] = []
	await _frames(1)
	var idle: Image = root.get_texture().get_image()
	await _frames(1)
	frames.append(root.get_texture().get_image())
	_tap_now(_word(title, room).get_global_rect().get_center() if kind == "open" else _exit_point(room))
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
	var noise: float = _change(idle, frames[0])
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
