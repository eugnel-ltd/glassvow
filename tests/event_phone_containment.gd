extends SceneTree
## Headless geometry contract for #595: the event screen under the run HUD.
##
## At the phone reference shape the event title used to overprint the HUD's
## location line and the choices' window used to sit over the HUD's relic row.
## Every event is stood under a live run HUD (dressed like a run: three phial
## seats, an omen, several relics) on each shipping shape, in both locales, as
## a choice screen and as a result beat, and the rects the player sees are held
## apart:
##
##   - the event title clears the HUD's top bar (its location line), the HUD's
##     seats and the relic row;
##   - the choices' window clears every HUD element;
##   - both stay inside the stage, and the window stays above the prose pane.
##
## Same SubViewport + real-frames pattern as `dawn_phone_containment.gd`. Not
## in `run_all.gd` because the discovered suite is synchronous; CI runs this
## script on its own.
##
##   godot --headless -s res://tests/event_phone_containment.gd

const SHAPES: Array[StringName] = [
	&"phone-landscape", &"pad-landscape", &"desktop-landscape",
]
## Relics beyond the starting one. The phone is held to a collection well along
## its first row: with the omen, thirteen seats, which end near x 476 of 844 (a
## seat is 34 px at a 36 px pitch), the case the title's seat is most likely to
## meet. The pad and the desktop keep the modest collection: a centred pad title
## already meets the ninth seat, an older defect outside #595's phone scope.
const EXTRA_RELICS_PHONE: int = 11
const EXTRA_RELICS: int = 4
const MAX_REPORTED: int = 24

var _fails: Array[String] = []
var _checked: int = 0
var _viewport: SubViewport


func _initialize() -> void:
	_viewport = SubViewport.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	call_deferred("_run")


func _run() -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var previous: Locale = Locale.active
	for locale_code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		# Event names and prose come out of ContentDB; hydrate the overlay so the
		# zh rows measure the strings the game renders (see measure_hud_location).
		if Locale.active != null:
			Locale.active.restore_content()
		Locale.active = Locale.new(locale_code)
		Locale.active.hydrate_content(content)
		for stage_shape: StringName in SHAPES:
			for event_id: String in content.events:
				for completed: bool in [false, true]:
					await _check_event(content, locale_code, stage_shape, event_id, completed)
	if Locale.active != null:
		Locale.active.restore_content()
	Locale.active = previous
	if _fails.is_empty():
		print("PASS event containment (%d rects, en + zh-Hant, %d events, 3 shapes)" % [
			_checked, content.events.size()])
		quit(0)
	else:
		for failure: String in _fails.slice(0, MAX_REPORTED):
			print("FAIL event_phone_containment: %s" % failure)
		if _fails.size() > MAX_REPORTED:
			print("FAIL event_phone_containment: ... and %d more" % (
				_fails.size() - MAX_REPORTED))
		quit(1)


func _check_event(content: ContentDB, locale_code: StringName,
		stage_shape: StringName, event_id: String, completed: bool) -> void:
	var reference: Vector2i = StageShape.REFERENCES[stage_shape]
	_viewport.size = reference
	var hud: RunHud = RunHud.new(_dressed_run(content, stage_shape), content, stage_shape)
	var definition: Dictionary = content.events[event_id].duplicate(true)
	var screen: EventScreen = EventScreen.new(event_id, definition, "",
		not completed, completed, stage_shape)
	_viewport.add_child(screen)
	_viewport.add_child(hud)
	for frame: int in 4:
		await process_frame
	var tag: String = "%s %s %s%s" % [locale_code, stage_shape, event_id,
		" beat" if completed else ""]
	var stage: Rect2 = Rect2(Vector2.ZERO, Vector2(reference))
	var window: Rect2 = screen._window.get_global_rect()
	var title: Rect2 = _ink_rect(screen._title)
	var pane: Rect2 = screen._copy.get_global_rect()
	_check(stage.encloses(window), "%s window escapes the stage: %s" % [tag, window])
	_check(stage.encloses(title), "%s title escapes the stage: %s" % [tag, title])
	_check(window.end.y <= pane.position.y + 0.5,
		"%s window %s reaches into the prose pane %s" % [tag, window, pane])
	_check(title.end.y <= window.position.y + 0.5,
		"%s title %s sits on the choices' window %s" % [tag, title, window])
	for element: Dictionary in _hud_elements(hud):
		var rect: Rect2 = element["rect"]
		var label: String = element["label"]
		_check(not rect.intersects(window),
			"%s HUD %s %s overlaps the choices' window %s" % [tag, label, rect, window])
		_check(not rect.intersects(title),
			"%s HUD %s %s overprints the event title %s" % [tag, label, rect, title])
	if not completed:
		await _check_reachable(screen, tag)
	screen.free()
	hud.free()
	await process_frame


## The window scrolls when its choices outrun it (the phone's does), so the
## first choice is seen whole as the screen opens and the last is brought into
## view by focus alone.
func _check_reachable(screen: EventScreen, tag: String) -> void:
	var enabled: Array[Button] = []
	for button: Button in screen._buttons:
		if not button.disabled:
			enabled.append(button)
	if enabled.is_empty():
		return
	# The scroll offset is whole pixels while the window's height is not.
	var view: Rect2 = screen._scroll.get_global_rect().grow(1.0)
	_check(view.encloses(enabled[0].get_global_rect()),
		"%s first choice %s is not whole in the window's view %s" % [
			tag, enabled[0].get_global_rect(), view])
	enabled[enabled.size() - 1].grab_focus()
	for frame: int in 12:
		await process_frame
	_check(view.encloses(enabled[enabled.size() - 1].get_global_rect()),
		"%s last choice %s is not brought into the window's view %s" % [
			tag, enabled[enabled.size() - 1].get_global_rect(), view])


## What the HUD puts on the stage: the top bar's own children (stats, location
## line, phial seats, deck and menu) and each seat in the relic collection.
func _hud_elements(hud: RunHud) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child: Node in hud._row.get_children():
		if child == hud._right:
			for seat: Node in hud._right.get_children():
				out.append(_element("right seat #%d" % seat.get_index(), seat))
		else:
			out.append(_element("bar item #%d" % child.get_index(), child))
	for seat: Node in hud._collection.get_children():
		out.append(_element("collection seat #%d" % seat.get_index(), seat))
	_check(hud._collection.get_child_count() > 1, "the HUD is dressed with a collection")
	return out


func _element(label: String, node: Node) -> Dictionary:
	var control: Control = node as Control
	_checked += 1
	return {"label": label, "rect": control.get_global_rect()}


## The rect the label's ink covers: a centred label is granted more width than
## its text, and only the text can overprint anything.
func _ink_rect(label: Label) -> Rect2:
	var box: Rect2 = label.get_global_rect()
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var text_w: float = minf(box.size.x, font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	return Rect2(box.position.x + (box.size.x - text_w) * 0.5, box.position.y,
		text_w, box.size.y)


## A run as the HUD sees one mid-act: the starting relic and more, the act's
## omen and a full rack of phial seats.
func _dressed_run(content: ContentDB, stage_shape: StringName) -> RunState:
	var run: RunState = RunState.new_run(content, 1)
	run.waystones_lit = 3
	run.player.gold = 120
	var extra: int = EXTRA_RELICS_PHONE if stage_shape == &"phone-landscape" else EXTRA_RELICS
	var ids: Array = content.relics.keys()
	ids.sort()
	for id_v: Variant in ids:
		if run.player.relics.size() > extra:
			break
		if not run.player.relics.has(str(id_v)):
			run.player.relics.append(str(id_v))
	return run


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
