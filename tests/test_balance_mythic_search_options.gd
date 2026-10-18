extends RefCounted
## Mythic studies use the qualified greedy pilot until search supports their state.
const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Search: GDScript = preload("res://tools/balance_search.gd")
const DIAGNOSTIC: String = "--mythic requires --play=greedy"

static func run(fails: Array[String]) -> void:
	for arm: String in Sim.MYTHIC_ARMS:
		for version: String in Search.VERSIONS:
			var rejected: Dictionary = Sim._options(PackedStringArray([
				"--mythic=" + arm, "--play=search", "--search=" + version, "--vow=3"]))
			if str(rejected.get("error", "")) != DIAGNOSTIC:
				fails.append("mythic CLI: %s with search %s must fail before simulation" % [arm, version])
		for explicit: bool in [false, true]:
			var arguments: PackedStringArray = PackedStringArray(["--mythic=" + arm, "--vow=3"])
			if explicit:
				arguments.append("--play=greedy")
			var accepted: Dictionary = Sim._options(arguments)
			if accepted.has("error") or str(accepted.get("play", "")) != "greedy" \
					or str(accepted.get("mythic", "")) != arm:
				fails.append("mythic CLI: %s must retain default and explicit greedy reads" % arm)
	for version: String in Search.VERSIONS:
		for empty_mythic: bool in [false, true]:
			var arguments: PackedStringArray = PackedStringArray(["--play=search", "--search=" + version])
			if empty_mythic:
				arguments.append("--mythic=")
			var accepted: Dictionary = Sim._options(arguments)
			if accepted.has("error") or str(accepted.get("play", "")) != "search" \
					or str(accepted.get("search", "")) != version \
					or not str(accepted.get("mythic", "")).is_empty():
				fails.append("mythic CLI: ordinary search %s must remain available" % version)
	var defaults: Dictionary = Sim._options(PackedStringArray())
	if defaults.has("error") or str(defaults.get("play", "")) != "greedy" \
			or not str(defaults.get("mythic", "")).is_empty():
		fails.append("mythic CLI: ordinary default options must remain available")
