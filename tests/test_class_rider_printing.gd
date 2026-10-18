extends RefCounted
## #544 A4: real display consumers must scope the four shared Dusk riders,
## retaining exact shipped copy and the live Unbroken Flame exception.

const COPY: Dictionary = {
	"en": {
		"preparation": {
			"full": [
				"Draw 2 cards. Kindle. Amber flame: gain 1 Ember.",
				"Draw 2 cards. Amber flame: gain 1 Ember."
			],
			"plain": [
				"Draw 2 cards. Kindle.",
				"Draw 2 cards."
			]
		},
		"surge": {
			"full": [
				"Gain 1 Energy. Draw 1 card. Kindle. Amber flame: gain 1 Ember.",
				"Gain 2 Energy. Draw 1 card. Kindle. Amber flame: gain 1 Ember."
			],
			"plain": [
				"Gain 1 Energy. Draw 1 card. Kindle.",
				"Gain 2 Energy. Draw 1 card. Kindle."
			]
		},
		"tithe": {
			"full": [
				"Gain 2 Embers. Draw 1 card. Amber flame: gain 1 Ember.",
				"Gain 3 Embers. Draw 1 card. Amber flame: gain 1 Ember."
			],
			"plain": [
				"Gain 2 Embers. Draw 1 card.",
				"Gain 3 Embers. Draw 1 card."
			]
		},
		"warCry": {
			"full": [
				"Apply 1 Dimmed and 1 Cracked to ALL enemies. Blood-moon flame: gain #3# Ward.",
				"Apply 2 Dimmed and 2 Cracked to ALL enemies. Blood-moon flame: gain #3# Ward."
			],
			"plain": [
				"Apply 1 Dimmed and 1 Cracked to ALL enemies.",
				"Apply 2 Dimmed and 2 Cracked to ALL enemies."
			]
		}
	},
	"zh-Hant": {
		"preparation": {
			"full": [
				"抽 2 張牌。燃燼。金黃之火：獲得 1 點餘燼。",
				"抽 2 張牌。金黃之火：獲得 1 點餘燼。"
			],
			"plain": [
				"抽 2 張牌。燃燼。",
				"抽 2 張牌。"
			]
		},
		"surge": {
			"full": [
				"獲得 1 點能量。抽 1 張牌。燃燼。金黃之火：獲得 1 點餘燼。",
				"獲得 2 點能量。抽 1 張牌。燃燼。金黃之火：獲得 1 點餘燼。"
			],
			"plain": [
				"獲得 1 點能量。抽 1 張牌。燃燼。",
				"獲得 2 點能量。抽 1 張牌。燃燼。"
			]
		},
		"tithe": {
			"full": [
				"獲得 2 點餘燼。抽 1 張牌。金黃之火：獲得 1 點餘燼。",
				"獲得 3 點餘燼。抽 1 張牌。金黃之火：獲得 1 點餘燼。"
			],
			"plain": [
				"獲得 2 點餘燼。抽 1 張牌。",
				"獲得 3 點餘燼。抽 1 張牌。"
			]
		},
		"warCry": {
			"full": [
				"對所有敵人施加 1 層黯淡與 1 層裂痕。血月之火：獲得 #3# 點護光。",
				"對所有敵人施加 2 層黯淡與 2 層裂痕。血月之火：獲得 #3# 點護光。"
			],
			"plain": [
				"對所有敵人施加 1 層黯淡與 1 層裂痕。",
				"對所有敵人施加 2 層黯淡與 2 層裂痕。"
			]
		}
	}
}


static func run(fails: Array[String]) -> void:
	var previous: Locale = Locale.active
	for language: String in COPY:
		Locale.active = Locale.new(StringName(language))
		var content: ContentDB = ContentDB.load_full(false)
		Locale.active.hydrate_content(content)
		var before: String = JSON.stringify(content.cards)
		_deck_and_picker(content, language, fails)
		_ui_callers(content, language, fails)
		_unbroken(content, language, fails)
		_rider_plays(content, fails)
		if JSON.stringify(content.cards) != before:
			fails.append("class rider printing: concurrent class displays mutated shared content")
		Locale.active.restore_content()
	Locale.active = previous


static func _main(content: ContentDB, aspect: int) -> Main:
	var main: Main = Main.new()
	TestProfile.install(main)
	main.content = content
	main.game = GlassvowGame.new(content,
		RunState.new_run(content, 54404, "class-rider-printing", {"aspect": aspect}))
	main._map = WorldMap.new()
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	return main


static func _expected(language: String, id: String, up: bool, full: bool) -> String:
	return str(COPY[language][id]["full" if full else "plain"][1 if up else 0])


static func _equal(fails: Array[String], actual: String, expected: String, tag: String) -> void:
	if actual != expected:
		fails.append("class rider printing: %s expected '%s', got '%s'" % [tag, expected, actual])


static func _words(view: CardView) -> String:
	var out: String = ""
	for token: Dictionary in view._body._tokens:
		out += str(token["text"])
	return out


static func _card_words(fails: Array[String], view: CardView, expected: String, tag: String) -> void:
	if view == null:
		fails.append("class rider printing: %s produced no actual card view" % tag)
		return
	_equal(fails, _words(view), expected.replace("@", "").replace("#", ""), tag)


## Every base/upgrade in both locales reaches Main's actual deck/picker rows.
## The two classes share this very same content object; classless stays full.
static func _deck_and_picker(content: ContentDB, language: String, fails: Array[String]) -> void:
	for aspect: int in [1, 0, 1]:
		var main: Main = _main(content, aspect)
		main.game.run.player.deck.clear()
		for id: String in COPY[language]:
			for up: bool in [false, true]:
				var card: CardInst = CardInst.new(main.game.run.next_uid(), StringName(id), up)
				main.game.run.player.deck.append(card)
				var choice: Dictionary = main._card_choice(card, "pick")
				var definition: Dictionary = choice["definition"]
				var full: String = _expected(language, id, up, true)
				_equal(fails, str(definition["text"]), _expected(language, id, up, aspect == 0),
					"%s aspect%d %s up%s picker" % [language, aspect, id, up])
				_equal(fails, str(main.game.rules.card_data(card)["text"]), full,
					"%s %s classless copy" % [language, id])
				var raw: Dictionary = main.game.rules.card_data(card).duplicate(true)
				var shown: Dictionary = definition.duplicate(true)
				raw.erase("text")
				shown.erase("text")
				if raw != shown:
					fails.append("class rider printing: display changed mechanics on %s" % id)
		for row: Dictionary in main._deck_rows():
			var card: CardInst = row["card"]
			_equal(fails, str(row["definition"]["text"]),
				_expected(language, String(card.id), card.up, aspect == 0), "actual deck rows")
		_dispose(main)


## Main must pass run context into the live reward and shop, not only pickers.
static func _ui_callers(content: ContentDB, language: String, fails: Array[String]) -> void:
	for aspect: int in [0, 1]:
		var main: Main = _main(content, aspect)
		var stock: Array = []
		var ids: Array = COPY[language].keys()
		for id: String in ids:
			stock.append({"id": id, "price": 10})
		main.game.run.quest_scratch["shopStock"] = {
			"cards": stock, "potions": [], "relics": [], "removeCost": 50}
		main._show_shop()
		var shop: ShopScreen = main._route_screen as ShopScreen
		for i: int in range(ids.size()):
			_card_words(fails, shop._card_views[i],
				_expected(language, str(ids[i]), false, aspect == 0), "actual shop " + str(ids[i]))
		main.game.run.pending_reward = {"rewards": {
			"gold": 0, "cards": ids, "potion": null, "relic": null}, "taken": {}}
		main._show_pending_reward(true)
		for i: int in range(ids.size()):
			_card_words(fails, main._reward_screen._cards[i],
				_expected(language, str(ids[i]), false, aspect == 0), "actual reward " + str(ids[i]))
		_dispose(main)


## Reach the bypass by actually playing its card in a legacy Ash fight. Every
## existing hand face must refresh, and a replacement combat clears the bypass.
static func _unbroken(content: ContentDB, language: String, fails: Array[String]) -> void:
	for up: bool in [false, true]:
		var main: Main = _main(content, 1)
		var game: GlassvowGame = main.game
		var screen: CombatScreen = CombatScreen.new(game)
		screen.seq.instant = true
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		tree.root.add_child(screen)
		screen.start_encounter(["sporeling"], "normal", "class rider printing")
		game.cb.hand.clear()
		game.cb.draw.clear()
		game.cb.discard.clear()
		game.cb.player.energy = 20
		var cards: Array[CardInst] = []
		for id: String in COPY[language]:
			var card: CardInst = CardInst.new(game.run.next_uid(), StringName(id), up)
			cards.append(card)
			game.cb.hand.append(card)
		var mythic: CardInst = CardInst.new(game.run.next_uid(), &"unbrokenFlame")
		game.cb.hand.append(mythic)
		screen._sync_all()
		for card: CardInst in cards:
			_card_words(fails, screen._hand.card_view(card.uid),
				_expected(language, String(card.id), up, false), "ordinary Ash combat " + String(card.id))
			_check_effects(fails, game, card, false)
		_inspector(fails, screen, cards, language, up, false)
		if not screen.request_play(mythic.uid, null) or not game.cb.unbroken:
			fails.append("class rider printing: real Unbroken play did not enable the bypass")
		for card: CardInst in cards:
			_card_words(fails, screen._hand.card_view(card.uid),
				_expected(language, String(card.id), up, true), "live Unbroken hand " + String(card.id))
			var row: Dictionary = main._card_choice(card, "combat-picker")
			_equal(fails, str(row["definition"]["text"]),
				_expected(language, String(card.id), up, true), "live Unbroken picker")
			_check_effects(fails, game, card, true)
		_inspector(fails, screen, cards, language, up, true)
		# A new combat is the real lifetime boundary of this fight-scoped flag.
		screen.start_encounter(["sporeling"], "normal", "cleared bypass")
		game.cb.hand.assign(cards)
		screen._sync_all()
		if game.cb.unbroken:
			fails.append("class rider printing: replacement combat kept the Unbroken bypass")
		for card: CardInst in cards:
			_card_words(fails, screen._hand.card_view(card.uid),
				_expected(language, String(card.id), up, false), "cleared bypass hand")
			var row: Dictionary = main._card_choice(card, "new-fight-picker")
			_equal(fails, str(row["definition"]["text"]),
				_expected(language, String(card.id), up, false), "cleared bypass picker")
		tree.root.remove_child(screen)
		screen.free()
		_dispose(main)


static func _inspector(fails: Array[String], screen: CombatScreen, cards: Array[CardInst],
		language: String, up: bool, full: bool) -> void:
	screen._show_inspector("class rider printing", cards)
	for baked: BakedCard in screen._inspector_grid.cards():
		_equal(fails, str(baked._definition["text"]),
			_expected(language, String(baked.inst.id), up, full), "actual pile inspector")
	screen._close_inspector()


## Confirm the real card plays still add exactly the old rider only under the
## accepted bypass. The same effect_lit seam also governs the Art's lit effects.
static func _rider_plays(content: ContentDB, fails: Array[String]) -> void:
	for id: String in COPY["en"]:
		for up: bool in [false, true]:
			var gains: Array[int] = []
			for bypass: bool in [false, true]:
				var run_state: RunState = RunState.new_run(content, 54404, "rider-resolution", {"aspect": 1})
				var game: GlassvowGame = GlassvowGame.new(content, run_state)
				game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
				game.cb.hand.clear()
				game.cb.draw.clear()
				game.cb.discard.clear()
				game.cb.player.energy = 20
				if bypass:
					var mythic: CardInst = CardInst.new(run_state.next_uid(), &"unbrokenFlame")
					game.cb.hand.append(mythic)
					game.apply({"t": "playCard", "uid": mythic.uid, "target": null})
				game.cb.embers = 0
				game.cb.player.block = 0
				game.cb.first_gain_turn = game.cb.turn
				var card: CardInst = CardInst.new(run_state.next_uid(), StringName(id), up)
				game.cb.hand.append(card)
				game.apply({"t": "playCard", "uid": card.uid, "target": null})
				if game.last_ret != true:
					fails.append("class rider printing: real rider play failed on " + id)
				gains.append(game.cb.player.block if id == "warCry" else game.cb.embers)
				for way: String in ["edge", "lantern", "shatter"]:
					if CombatRules.effect_lit(game.cb, {"lit": way}) != bypass:
						fails.append("class rider printing: Art/shared rider bypass changed")
			if gains[1] - gains[0] != (3 if id == "warCry" else 1):
				fails.append("class rider printing: existing Ash+Unbroken rider gain changed on " + id)


static func _check_effects(fails: Array[String], game: GlassvowGame, card: CardInst,
		want: bool) -> void:
	var data: Dictionary = game.rules.card_data(card)
	var riders: int = 0
	for fx: Dictionary in data["effects"]:
		if fx.has("lit"):
			riders += 1
			if CombatRules.effect_lit(game.cb, fx) != want:
				fails.append("class rider printing: executable rider disagrees with %s" % card.id)
	if riders != 1:
		fails.append("class rider printing: fixture lost %s's existing rider" % card.id)


static func _dispose(main: Main) -> void:
	for child: Node in main.get_children():
		child.free()
	main.free()
