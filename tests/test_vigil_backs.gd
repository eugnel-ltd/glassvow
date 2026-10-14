extends RefCounted
## The card backs' shelf and the ways a back reaches the player (#657 PR 7):
## the Vigil's Backs look shows every back, earned ones choosable and locked
## ones as a silhouette with their deed; a choice is stored in settings.cfg,
## survives a reload and is worn on the table at once, so the deck stack
## follows it; a back earned by a run becomes a Dawn event whose card turns
## over; the reward's offering is dealt face down and turned, a tap lands it,
## and the card taken is counted by the HUD's deck as it lands. How each looks
## is checked in stills.

const TEST_SETTINGS: String = "user://test_vigil_backs_settings.cfg"
const TEST_LEGACY: String = "user://test_vigil_backs_audio.cfg"


static func run(fails: Array[String]) -> void:
	var was_prefs: Preferences = Preferences.active
	var was_wearing: String = CardTurn.wearing()
	_cleanup()
	Preferences.active = Preferences.new()
	CardBacks.use_catalogue(null)
	var render: _FakeRender = _FakeRender.new()
	CardBacks.use_renderer(render.render)
	_shelf_shows_every_back(fails)
	_shelf_choice(fails)
	await _choice_persists_and_is_worn(fails)
	_hall_carries_the_look(fails)
	_dawn_turns_an_earned_back(fails)
	_reward_reveal(fails)
	_hud_counts_the_card_home(fails)
	CardBacks.use_renderer(Callable())
	CardBacks.use_catalogue(null)
	CardTurn._wearing = was_wearing
	Preferences.active = was_prefs
	_cleanup()


## One shard, no win: the starter and Vesper earned, Eclipse locked.
static func _vigil() -> VigilState:
	var vigil: VigilState = VigilState.blank()
	vigil.shards.assign(["hollowLamplighter"])
	return vigil


## Every back in the catalogue's order; the earned ones live cards, the locked
## one a silhouette with its deed; the starter in use, raised, IN USE.
static func _shelf_shows_every_back(fails: Array[String]) -> void:
	var shelf: VigilBacks = VigilBacks.new(_vigil(), &"pad-landscape")
	var ids: Array[String] = []
	for slot: Control in shelf.slots():
		ids.append(str(slot.get("id")))
	if ids != CardBacks.catalogue().ids():
		fails.append("vigil backs: the shelf shows %s, want the catalogue's %s" % [str(ids), str(CardBacks.catalogue().ids())])
	var earned: Dictionary = {"vault": true, "rose": true, "eclipse": false}
	for slot: Control in shelf.slots():
		var id: String = str(slot.get("id"))
		var face: Control = slot.get("face")
		var line: Label = slot.get("line")
		if shelf.is_earned(id) != earned[id] or (face is CardView) != earned[id]:
			fails.append("vigil backs: %s stands %s, want earned=%s" % [id, face.get_class(), str(earned[id])])
		var want: String = Locale.active.t("ui.back.inUse") if id == "vault" \
			else ("" if earned[id] else Locale.active.t("ui.back.%s.deed" % id))
		if line.text != want:
			fails.append("vigil backs: under %s reads '%s', want '%s'" % [id, line.text, want])
	if shelf.in_use() != "vault":
		fails.append("vigil backs: %s in use on a fresh profile, want vault" % shelf.in_use())
	shelf.free()


## An earned back not in use is chosen; the one in use and a locked one are not.
static func _shelf_choice(fails: Array[String]) -> void:
	var shelf: VigilBacks = VigilBacks.new(_vigil(), &"pad-landscape")
	var heard: Array[String] = []
	shelf.chosen.connect(func(id: String) -> void: heard.append(id))
	shelf._pick("eclipse")
	shelf._pick("vault")
	shelf._pick("rose")
	shelf._pick("rose")
	if heard != ["rose"] or shelf.in_use() != "rose":
		fails.append("vigil backs: picks of eclipse, vault, rose, rose said %s with %s in use, want [rose]"
			% [str(heard), shelf.in_use()])
	var rose_line: Label = shelf.slots()[1].get("line")
	if rose_line.text != Locale.active.t("ui.back.inUse"):
		fails.append("vigil backs: the back chosen does not read IN USE")
	shelf.free()


## The choice reaches settings.cfg and reads back after a reload; the table
## wears it at once and the deck stack follows; a locked back is refused.
static func _choice_persists_and_is_worn(fails: Array[String]) -> void:
	var prefs: Preferences = Preferences.read_from_disk(TEST_SETTINGS, TEST_LEGACY)
	var vigil: VigilState = _vigil()
	var host: Node = Node.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(host)
	var deck: DeckStack = DeckStack.new(56.0, null)
	host.add_child(deck)
	if CardTurn.choose(prefs, vigil, host, "eclipse"):
		fails.append("vigil backs: a locked back was chosen")
	if Preferences.read_from_disk(TEST_SETTINGS, TEST_LEGACY).card_back != "":
		fails.append("vigil backs: a refused choice was stored")
	if not CardTurn.choose(prefs, vigil, host, "rose"):
		fails.append("vigil backs: an earned back was refused")
	if CardTurn.wearing() != "rose":
		fails.append("vigil backs: the table wears '%s' after the choice, want rose" % CardTurn.wearing())
	var reloaded: Preferences = Preferences.read_from_disk(TEST_SETTINGS, TEST_LEGACY)
	if reloaded.card_back != "rose" or CardBacks.chosen(reloaded, vigil) != "rose":
		fails.append("vigil backs: the choice read back as '%s'" % reloaded.card_back)
	for _i: int in range(3):
		await tree.process_frame
	if CardTurn.back() == null or deck.worn() != CardTurn.back():
		fails.append("vigil backs: the deck stack does not wear the chosen back once baked")
	host.queue_free()
	await tree.process_frame


## The hall's Backs pane opens the look (built only then) and passes a choice on.
static func _hall_carries_the_look(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var screen: VigilScreen = VigilScreen.new(_vigil(), content, &"pad-landscape")
	if screen.backs_view() != null:
		fails.append("vigil backs: the shelf was built before its look was wanted")
	screen._show_backs()
	if screen.look() != VigilHall.BACKS or screen.backs_view() == null \
			or not screen.backs_view().visible:
		fails.append("vigil backs: the Backs pane did not open the shelf")
	var heard: Array[String] = []
	screen.back_chosen.connect(func(id: String) -> void: heard.append(id))
	screen.backs_view()._pick("rose")
	if heard != ["rose"]:
		fails.append("vigil backs: the hall passed on %s, want [rose]" % str(heard))
	screen.free()


## A back the run earned is one Dawn event; its card stands face down as the
## beat starts and turns face up; skipped, it stands face up at once.
static func _dawn_turns_an_earned_back(fails: Array[String]) -> void:
	var before: Array[String] = CardBacks.catalogue().unlocked(_vigil())
	var after: VigilState = _vigil()
	after.deeds["wins"] = 1
	var events: Array = DawnScreen.back_events(before, after)
	if events.size() != 1 or str(events[0].get("back")) != "eclipse" or str(events[0].get("kind")) != "back":
		fails.append("vigil backs: the Dawn's back events are %s, want one for eclipse" % str(events))
		return
	if not DawnScreen.back_events(before, _vigil()).is_empty():
		fails.append("vigil backs: a Dawn announced a back the run did not earn")
	var screen: DawnScreen = DawnScreen.new(events, 0)
	screen._begin_beat()    # what _ready starts in the tree
	if screen._turning.size() != 1:
		fails.append("vigil backs: the Dawn's back is not turning as its beat starts")
		screen.free()
		return
	var card: CardView = screen._turning[0]
	if not card._pose.is_equal_approx(CardTurn.pose(180.0, 0.0)):
		fails.append("vigil backs: the Dawn's back does not start face down")
	screen._turn_backs(DawnScreen.BACK_TURN_AT + DawnScreen.BACK_TURN + 0.01)
	if not screen._turning.is_empty() or not CardTurn.is_rest(card._pose):
		fails.append("vigil backs: the Dawn's back did not end face up")
	screen.free()


## The offering is dealt face down and turned left to right; a tap once the
## deal has begun lands it face up rather than taking a face-down card; under
## Reduce Motion nothing turns.
static func _reward_reveal(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var reward: Dictionary = {"gold": 10, "cards": ["strike", "defend", "strike"]}
	var screen: RewardEmbers = RewardEmbers.new(reward, content)
	screen.size = Vector2(1180.0, 820.0)
	screen._place()
	screen.advance(screen._turn_at(0) - 0.01)
	for i: int in range(3):
		if not is_equal_approx(screen._card_pose[i].x, 180.0):
			fails.append("vigil backs: offering card %d shows yaw %.1f before its turn, want 180" % [i, screen._card_pose[i].x])
	var heard: Array[String] = []
	screen.claimed.connect(func(what: StringName, id: String) -> void:
		if what == &"card":
			heard.append(id))
	screen._take_card("defend")
	if not heard.is_empty() or not screen._settled:
		fails.append("vigil backs: a tap mid-reveal took a card or did not land the offering")
	for i: int in range(3):
		if not screen._card_pose[i].is_equal_approx(Vector2.ZERO) or screen._card_off[i] != Vector2.ZERO:
			fails.append("vigil backs: offering card %d did not land face up at its seat" % i)
	screen._take_card("defend")
	if heard != ["defend"]:
		fails.append("vigil backs: the landed offering's tap took %s, want [defend]" % str(heard))
	screen.free()
	Preferences.active.reduce_motion = true
	var still: RewardEmbers = RewardEmbers.new(reward, content)
	still.size = Vector2(1180.0, 820.0)
	still._place()
	still.advance(still._deal_at() + RewardEmbers.RM_FADE * 0.5)
	if still._card_pose.any(func(p: Vector2) -> bool: return p.x > 0.0):
		fails.append("vigil backs: a card turned under Reduce Motion")
	still.settle()
	still.free()
	Preferences.active.reduce_motion = false


## The deck counts a card taken when it lands, not when it is taken, and bumps.
static func _hud_counts_the_card_home(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new()
	run.player.potions.assign(["", "", ""])
	for i: int in range(10):
		run.player.deck.append(CardInst.new(900 + i, &"strike"))
	var hud: RunHud = RunHud.new(run, content, &"pad-landscape")
	hud.owe_card()
	run.player.deck.append(CardInst.new(950, &"strike"))
	hud.refresh(run)
	if hud._deck_count.text != "10" or hud._deck_stack.stack.count != 10:
		fails.append("vigil backs: the deck counted a card still in flight (%s)" % hud._deck_count.text)
	hud.card_home()
	if hud._deck_count.text != "11" or hud._deck_stack.stack.count != 11:
		fails.append("vigil backs: the deck did not count the card home (%s)" % hud._deck_count.text)
	hud.card_home()
	if hud._deck_count.text != "11":
		fails.append("vigil backs: a second landing with nothing owed moved the count")
	hud.free()


static func _cleanup() -> void:
	for path: String in [TEST_SETTINGS, TEST_LEGACY]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


class _FakeRender:
	extends RefCounted

	func render(_host: Node, _id: String, scale: float) -> CardBacks.Baked:
		await (Engine.get_main_loop() as SceneTree).process_frame
		var out: CardBacks.Baked = CardBacks.Baked.new()
		out.stage = ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
		out.inner = ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
		out.oversample = scale
		return out
