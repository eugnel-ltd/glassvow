extends RefCounted
## The rooms at the rubric's floor (docs/commercial-rubric.md global criteria;
## docs/design/2026-10-03-title-rooms §3, §11.1). In Settings, How to Play,
## Credits and the two licence glasses, laid out at every shape and every flex
## stage a device gives, in both languages:
##
## - every tap (a BaseButton, by the hit it takes) is at least 60×60 at pad and
##   desktop and 44×44 on a phone;
## - every Label and RichTextLabel is at least 18 px at pad and desktop (the
##   build line in Settings' footer is the title's build identifier, the one
##   waiver of §14);
## - no web-modal panel (a PanelContainer, RunStyle.panel or GlassStyle.pane)
##   remains in a room;
## - every content rect lies on the stage and clear of the seat's keep-clear
##   rects, and the seat stands where its rule says;
## - and the project's ground is the night (LeadlightTokens.VOID).
## A room opened in a run (X1) is the same room, its seat the word alone.

const SUITE: String = "res://tests/test_rooms_rubric.gd"
const FLOOR: int = 18
## The rubric's own numbers, never the kit's tokens (a token lowered must fail
## here): 60×60 at pad and desktop, the 44 px touch floor on a phone.
const HIT_FLOOR: Vector2i = Vector2i(60, 44)
const WAIVED: Array[String] = ["BrandLine"]
const STAGES: Array[Array] = [
	[&"pad-landscape", Vector2i(1180, 820)], [&"desktop-landscape", Vector2i(1458, 820)],
	[&"phone-landscape", Vector2i(844, 390)], [&"phone-landscape", Vector2i(845, 390)],
	[&"phone-landscape", Vector2i(844, 443)], [&"pad-landscape", Vector2i(1180, 885)],
	[&"pad-landscape", Vector2i(1180, 824)], [&"desktop-landscape", Vector2i(1458, 911)],
]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("rooms_rubric: %s" % what)


static func run(fails: Array[String]) -> void:
	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	_check(fails, clear.is_equal_approx(LeadlightTokens.VOID), "the project's ground is not the night")
	TreeSuite.spawn(fails, SUITE)


static func run_in_tree(tree: SceneTree, host: SubViewport, fails: Array[String]) -> void:
	var kept: Locale = Locale.active
	var kept_preferences: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	Preferences.active.diagnostics_notice_seen = false
	for code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		Locale.active = Locale.new(code)
		for entry: Array in STAGES:
			var shape: StringName = entry[0]
			var stage: Vector2i = entry[1]
			host.size = stage
			for room: String in ["settings", "help", "credits"]:
				var where: String = "%s %s %dx%d %s" % [code, room, stage.x, stage.y, room]
				var screen: LeadlightRoomHost = _room(room, shape)
				host.add_child(screen)
				await _frames(tree, 3)
				if room == "credits":
					var credits: CreditsScreen = screen as CreditsScreen
					credits._build_font_licences()
					credits._build_licence()
				_rubric(fails, screen, shape, where)
				_clear_of_the_seat(fails, screen, shape, Vector2(stage), where)
				screen.queue_free()
				await tree.process_frame
	host.size = TreeSuite.STAGE
	Locale.active = kept
	Preferences.active = kept_preferences


static func _room(room: String, shape: StringName) -> LeadlightRoomHost:
	match room:
		"settings":
			var settings: SettingsPanel = SettingsPanel.new(Preferences.active)
			settings.set_shape(shape)
			return settings
		"help":
			return HelpScreen.new(shape)
	return CreditsScreen.new(shape)


static func _rubric(fails: Array[String], screen: LeadlightRoomHost, shape: StringName, where: String) -> void:
	var phone: bool = LeadlightTokens.is_phone(shape)
	var hit_floor: float = float(HIT_FLOOR.y if phone else HIT_FLOOR.x)
	for node: Node in screen.find_children("", "BaseButton", true, false):
		var button: BaseButton = node
		if not button.is_visible_in_tree():
			continue
		var hit: Rect2 = Rect2(Vector2.ZERO, button.size)
		if button.has_method(&"hit_rect"):
			hit = button.call(&"hit_rect")
		_check(fails, hit.size.x >= hit_floor - 0.5 and hit.size.y >= hit_floor - 0.5,
			"%s: %s takes a %dx%d tap, under %d px" % [where, _name(button), int(hit.size.x),
				int(hit.size.y), int(hit_floor)])
	if not phone:
		for node: Node in screen.find_children("", "Control", true, false):
			if not (node is Label or node is RichTextLabel) or WAIVED.has(str(node.name)):
				continue
			var text: Control = node
			var px: int = text.get_theme_font_size("font_size" if text is Label else "normal_font_size")
			_check(fails, px >= FLOOR, "%s: %s is set at %d px, under the %d px floor" % [
				where, _name(text), px, FLOOR])
	# The old modals' panels: a PanelContainer dressed in RunStyle.panel or
	# GlassStyle.pane (a flat box). A ScrollContainer's own internal focus
	# panel carries no such dress.
	for node: Node in screen.find_children("", "PanelContainer", true, false):
		var panel: PanelContainer = node
		_check(fails, not (panel.get_theme_stylebox("panel") is StyleBoxFlat),
			"%s: a web-modal panel remains in the room (%s)" % [where, screen.get_path_to(panel)])


static func _clear_of_the_seat(fails: Array[String], screen: LeadlightRoomHost, shape: StringName,
		stage: Vector2, where: String) -> void:
	var seat: Dictionary = LeadlightSeat.for_stage(shape, stage)
	var whole: Rect2 = Rect2(Vector2.ZERO, stage)
	var keep_lantern: Rect2 = seat["keep_lantern"]
	var keep_word: Rect2 = seat["keep_word"]
	for rect: Rect2 in screen.content_rects():
		_check(fails, whole.grow(0.5).encloses(rect), "%s: content runs off the stage (%s)" % [where, rect])
		_check(fails, not rect.intersects(keep_lantern) and not rect.intersects(keep_word),
			"%s: content stands under the seat (%s)" % [where, rect])
	var word: Control = screen.seat().word()
	var rule: Rect2 = seat["word"]
	_check(fails, Rect2(word.position, word.size).is_equal_approx(rule),
		"%s: the seat's Return is not where its rule seats it" % where)


static func _name(node: Node) -> String:
	if node is Button and not (node as Button).text.is_empty():
		return "'%s'" % (node as Button).text
	if node is Label:
		return "'%s'" % (node as Label).text.left(30)
	return str(node.name)


static func _frames(tree: SceneTree, count: int) -> void:
	for _i: int in range(count):
		await tree.process_frame
