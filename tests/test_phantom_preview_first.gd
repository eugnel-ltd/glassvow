extends RefCounted
## Frozen first regression for #544: uses the shipped card and four-argument API.


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	for aspect: int in [0, 1]:
		for upgraded: bool in [false, true]:
			var game: GlassvowGame = _position(content, aspect, upgraded)
			var card: CardInst = game.cb.hand[0]
			var before: String = JSON.stringify(game.cb.to_dict())
			var rng_before: int = game.run.rng_state()
			var preview_v: Variant = game.rules.preview_play(game.cb, card, 0, game.run)
			if JSON.stringify(game.cb.to_dict()) != before or game.run.rng_state() != rng_before:
				fails.append("Phantom first: preview mutated combat or RNG")
			var expected: int = 12 if upgraded else 9
			if typeof(preview_v) != TYPE_DICTIONARY:
				fails.append("Phantom first: aspect %d upgraded %s expected damage %d, got %s"
					% [aspect, upgraded, expected, preview_v])
				continue
			var preview: Dictionary = preview_v
			if preview.get("total") != expected or preview.get("loss") != expected:
				fails.append("Phantom first: aspect %d upgraded %s expected damage %d, got %s"
					% [aspect, upgraded, expected, preview])


static func _position(content: ContentDB, aspect: int, upgraded: bool) -> GlassvowGame:
	var run_state: RunState = RunState.new_run(content, 220544, "phantom-first", {"aspect": aspect})
	run_state.player.relics.clear()
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	game.cb.hand.clear()
	game.cb.draw.clear()
	game.cb.discard.clear()
	game.cb.hand.append(CardInst.new(run_state.next_uid(), &"phantomBlades", upgraded))
	for _i: int in range(3):
		game.cb.hand.append(CardInst.new(run_state.next_uid(), &"defend"))
	game.cb.player.statuses.clear()
	game.cb.player.energy = 3
	game.cb.enemies[0].hp = 100
	game.cb.enemies[0].block = 0
	game.cb.enemies[0].statuses.clear()
	return game
