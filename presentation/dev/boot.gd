extends RefCounted
## Excluded Development boot. Picks the save profile a tooling launch runs on,
## and parses a Scenario reference off the command line; both are handed to the
## composition root. No construct/reset of its own.

## The explicit opt-out from the Development profile. A tooling boot that must
## resume or seed the player's real save (`tools/probe_p48_rest.gd` seeds it for
## a live host to continue) names this; nothing else reaches the production files.
const PRODUCTION_SAVE_FLAG: String = "--production-save"


## Any launch that carries an argument is a tooling launch — the line
## `Main._ready` already draws between the player's plain boot and a capture or
## bench — so it runs on the isolated Development profile unless it names the
## production save. Keying on "has an argument" rather than on a list of flags is
## what stops a future flag leaking into the player's save by being left off it.
static func selects_dev_profile(args: PackedStringArray) -> bool:
	return not args.is_empty() and not args.has(PRODUCTION_SAVE_FLAG)


## The profile step every tooling boot passes through, whether or not it carries
## a Scenario: bind the kernel's isolated files before anything can read or write
## a save. A Scenario reaches the same `install_profile` again through
## `apply_dev_scenario`, so there is one place a profile is installed.
static func select_profile(host: Object, args: PackedStringArray) -> void:
	if not selects_dev_profile(args):
		return
	if not host.has_method("install_profile"):
		push_error("host cannot install the Development profile")
		return
	host.call("install_profile", ScenarioKernel.RUN_PATH, ScenarioKernel.VIGIL_PATH)


static func apply(host: Object, args: PackedStringArray) -> void:
	var ref: ScenarioReference = parse_scenario_arg(args)
	if ref == null:
		return
	if not host.has_method("apply_dev_scenario"):
		push_error("host cannot apply a Development Scenario")
		return
	host.call("apply_dev_scenario", ref)


static func parse_scenario_arg(args: PackedStringArray) -> ScenarioReference:
	var found: bool = false
	var raw: String = ""
	for arg: String in args:
		if arg.begins_with("--scenario="):
			found = true
			raw = arg.trim_prefix("--scenario=")
			break
	if not found:
		return null
	var ref: ScenarioReference = ScenarioReference.new()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		ref.error = "Scenario reference is unreadable"
		return ref
	var blob: Dictionary = parsed
	if not blob.has("seed") and not blob.has("overrides"):
		_fill_catalogue_recipe(blob)
	ref.load_from(blob)
	return ref


## Id-only references resolve against catalogue ENTRIES. Named recipes live
## here, not in ScenarioReference — that type only holds the id→revision contract.
static func _fill_catalogue_recipe(blob: Dictionary) -> void:
	var entry: Dictionary = _catalogue_entry(str(blob.get("id", "")))
	if entry.is_empty():
		return
	blob["seed"] = int(float(str(entry.get("seed", 0))))
	var ov_v: Variant = entry.get("overrides", {})
	var ov: Dictionary = ov_v if typeof(ov_v) == TYPE_DICTIONARY else {}
	blob["overrides"] = ov.duplicate(true)


static func _catalogue_entry(id: String) -> Dictionary:
	var script: GDScript = load("res://presentation/dev/catalogue.gd") as GDScript
	if script == null:
		return {}
	var found: Variant = script.call("recipe_for", id)
	return found if typeof(found) == TYPE_DICTIONARY else {}
