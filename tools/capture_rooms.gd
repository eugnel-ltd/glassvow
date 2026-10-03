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
##       [--hold] [--section=<id>] [--at=<ms>] [--burst=3]
##       [--seq=open|close|section|glass|run --room=settings|help|credits|vigil --frames=40]
##       [--sheet=/abs/sheet.jpg] [--rm] [--window=1180x885]
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
## The rooms (#655 PR B): with --hold a room path stays in the room, at
## --section (a section's pane tapped: Settings' audio..ledger, How to Play's
## road..vigil) or, in Credits, at a part of its roll (music, end) or a licence
## glass (fonts, engine); --at holds the room's passage at that many ms after
## the tap (the passage's clock stopped there). --burst=3 with a room open also
## grades §11.4's idle gate: at least 0.5% of the room's own pixels change from
## each frame to the next, 1 s apart (reported, not graded, under --rm).
## --seq=section taps --section in a settled room (G3), --seq=glass taps a
## licence pane at the end of Credits' roll (C3), --seq=run opens --room from
## the run menu over the map (X1); --sheet lays every frame of a sequence out
## as one contact sheet, a quarter size, left to right and down. --window sizes
## the window off the shape's reference, for a device's flex stage (the iPad 8's
## 1180×885); a still saved as .jpg is a JPEG.
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
## Each room's own way back: the seat's Return in the title's rooms (#655 PR B);
## the Vigil's RETURN until PR C seats it.
const ROOM_EXITS: Dictionary = {
	"settings": "ui.menu.return", "help": "ui.menu.return",
	"credits": "ui.menu.return", "vigil": "ui.vigil.return",
}
## The idle gate (§11.4): the least share of a room's pixels that changes
## between frames 1 s apart, and what counts as a change.
const IDLE_SHARE: float = 0.005
const IDLE_STEP: int = 3
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
	if _args.has("window"):
		var wh: PackedStringArray = str(_args["window"]).split("x")
		stage = Vector2i(int(wh[0]), int(wh[1]))
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
			if _args.has("at"):
				await _hold_at(title, path, float(str(_args["at"])) / 1000.0)
				return
			await _tap(_word(title, path).get_global_rect().get_center())
			await _settle()
			if _args.has("hold"):
				# A passage runs on time, not frames: an uncapped frame is ~3 ms.
				await _wait(1.2)
				await _section(str(_args.get("section", "")))
				return
			var key: String = str(ROOM_EXITS[path])
			if key.is_empty():
				await _tap(VEIL_TAP)
			else:
				await _tap_control(_labelled(_main, Locale.active.t(key)))
	await _settle()
	await _wait(1.0)


## --at: the room's passage held `seconds` after the tap that opened it.
func _hold_at(title: TitleScreen, room: String, seconds: float) -> void:
	_tap_now(_word(title, room).get_global_rect().get_center())
	await process_frame
	var passage: LeadlightPassage = _main._passage
	passage.set_process(false)
	var step: float = 1.0 / 60.0
	var at: float = step
	while at < seconds:
		passage.advance(step)
		at += step
	await _frames(2)


## --section: a tap on that section's pane in the open room, then its page at rest.
func _section(id: String) -> void:
	if id.is_empty() or not (_main._modal is LeadlightRoomHost):
		return
	if _main._modal is CreditsScreen:
		await _credits_at(_main._modal as CreditsScreen, id)
		return
	var room: LeadlightRoom = (_main._modal as LeadlightRoomHost).sheet() as LeadlightRoom
	if room == null or room.tab(StringName(id)) == null:
		push_error("capture_rooms: no section '%s' here" % id)
		_failed = true
		return
	await _tap_control(room.tab(StringName(id)))
	await _wait(0.6)


## Credits at a part of its roll: head (as it lands), music, end, or a licence
## glass (fonts, engine) opened by a tap on its pane at the end of the roll.
func _credits_at(credits: CreditsScreen, part: String) -> void:
	var roll: CreditsRoll = credits.roll()
	var to: Control = {"music": roll.find_child("Tracks", true, false), "end": roll.footer_node,
		"fonts": roll.font_pane, "engine": roll.engine_pane}.get(part, null)
	if to == null:
		return
	credits.scroll().ensure_control_visible(to)
	credits._took_over()
	await _frames(2)
	if part == "fonts" or part == "engine":
		await _tap_control(to)
	await _wait(0.8)


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
	var shots: Array[Image] = []
	for k: int in range(burst):
		var file: String = out if burst <= 1 else out.get_basename() + "-%d.%s" % [k + 1, out.get_extension()]
		var image: Image = root.get_texture().get_image()
		_save(image, file)
		shots.append(image)
		print("rooms still: %s  %s" % [file, _oval_measures(image)])
		if k + 1 < burst:
			await _wait(1.0)
	if burst > 1 and _main._modal is LeadlightRoomHost:
		_idle_gate(shots, (_main._modal as LeadlightRoomHost).content_rects()[0])


## A still as PNG, or JPEG where the name asks for one.
static func _save(image: Image, file: String) -> void:
	if file.get_extension().to_lower() in ["jpg", "jpeg"]:
		image.save_jpg(file, 0.88)
	else:
		image.save_png(file)


## §11.4: a room at rest is alive: from each frame of a burst to the next (1 s
## apart) at least IDLE_SHARE of the room's own pixels change.
func _idle_gate(shots: Array[Image], rect: Rect2) -> void:
	var least: float = 1.0
	for i: int in range(1, shots.size()):
		least = minf(least, _changed_share(shots[i - 1], shots[i], rect))
	var ok: bool = least >= IDLE_SHARE
	var graded: bool = not _args.has("rm")
	print("idle gate %s: the least change between frames 1 s apart is %.2f%% of the room's pixels (floor %.1f%%)%s" % [
		"PASS" if ok else "FAIL", least * 100.0, IDLE_SHARE * 100.0, "" if graded else " (reported under --rm)"])
	_failed = _failed or (graded and not ok)


static func _changed_share(a: Image, b: Image, rect: Rect2) -> float:
	var changed: int = 0
	var seen: int = 0
	var box: Rect2i = Rect2i(rect).intersection(Rect2i(Vector2i.ZERO, a.get_size()))
	for y: int in range(box.position.y, box.end.y, 2):
		for x: int in range(box.position.x, box.end.x, 2):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			seen += 1
			if maxi(maxi(absi(p.r8 - q.r8), absi(p.g8 - q.g8)), absi(p.b8 - q.b8)) >= IDLE_STEP:
				changed += 1
	return float(changed) / float(maxi(seen, 1))


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
	var trigger: Control = null
	if kind == "section" or kind == "glass":
		await _tap(_word(title, room).get_global_rect().get_center())
		await _settle()
		await _wait(1.0)
		trigger = _section_trigger(str(_args.get("section", "fonts" if kind == "glass" else "")))
		await _frames(2)
	elif kind == "run":
		await _open_run_menu(title)
		trigger = _labelled(_main._modal, Locale.active.t(
			"ui.menu.howToPlay" if room == "help" else "ui.menu.settings"))
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
	elif trigger != null:
		_tap_control_now(trigger)
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
	if _args.has("sheet"):
		_sheet(frames, str(_args["sheet"]))
	_gates(frames, idle)


## The pane a G3 or C3 sequence taps: a section's, or a licence pane at the end
## of Credits' roll (scrolled into view first).
func _section_trigger(id: String) -> Control:
	if _main._modal is CreditsScreen:
		var credits: CreditsScreen = _main._modal
		var pane: Control = credits.roll().font_pane if id == "fonts" else credits.roll().engine_pane
		credits.scroll().ensure_control_visible(pane)
		# A player scrolled there: the roll's own drift waits, as after a touch.
		credits._took_over()
		return pane
	var host: LeadlightRoomHost = _main._modal as LeadlightRoomHost
	var room: LeadlightRoom = host.sheet() as LeadlightRoom if host != null else null
	return room.tab(StringName(id)) if room != null else null


## Every frame of a sequence on one sheet: a quarter size, six to a row.
static func _sheet(frames: Array[Image], file: String) -> void:
	if frames.is_empty():
		return
	var cell: Vector2i = frames[0].get_size() / 4
	var across: int = 6
	var rows: int = ceili(float(frames.size()) / float(across))
	var sheet: Image = Image.create(cell.x * across, cell.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(LeadlightTokens.VOID))
	for i: int in range(frames.size()):
		var small: Image = frames[i].duplicate()
		small.convert(Image.FORMAT_RGB8)
		small.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(small, Rect2i(Vector2i.ZERO, cell), Vector2i(i % across, i / across) * cell)
	_save(sheet, file)
	print("contact sheet: %s (%d frames)" % [file, frames.size()])


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
