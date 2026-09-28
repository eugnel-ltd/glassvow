extends RefCounted
## Compare cached catalogue valuation with the uncached arithmetic, including
## policy/catalogue switches and upgrades. Never replace the whole-run digest.
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Policy: GDScript = preload("res://tools/balance_policy.gd")


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var rules: CombatRules = CombatRules.new(content)
	var alternate: ContentDB = ContentDB.load_full(false)
	var changed: Dictionary = alternate.cards["strike"].duplicate(true)
	changed["cost"] = 7
	alternate.cards["strike"] = changed
	var policies: Array[Dictionary] = [{}, Policy.sample_range(7421, 0, 1)[0]]
	for policy: Dictionary in policies:
		Pilot.apply_policy(policy)
		for aspect: int in [0, 1]:
			for id: String in content.cards:
				for upgraded: bool in [false, true]:
					var card: CardInst = CardInst.new(1, StringName(id), upgraded)
					var expected: float = Pilot.card_score(rules.card_data(card), aspect, id)
					for _repeat: int in range(2):
						var actual: float = Pilot.catalogue_card_score(content, aspect, id, upgraded)
						if actual != expected:
							fails.append("cached valuation changed %s aspect %d up %s" % [id, aspect, upgraded])
		for catalogue: ContentDB in [alternate, content, alternate]:
			var expected: float = Pilot.card_score(catalogue.cards["strike"], 0, "strike")
			if Pilot.catalogue_card_score(catalogue, 0, "strike") != expected:
				fails.append("cached valuation leaked across catalogues")
	Pilot.apply_policy({})
