class_name DevTools
extends RefCounted
## Production gate for the excluded Development tree. Stays packed so a
## store/RC build can ask whether the boot handler is present; it never
## preloads that tree.

const BOOT: String = "res://presentation/dev/boot.gd"
const CONSOLE: String = "res://presentation/dev/console.gd"
## The explicit opt-out from the Development profile. A tooling boot that must
## resume or seed the player's real save (`tools/probe_p48_rest.gd` seeds it for
## a live host to continue) names this; nothing else reaches the production files.
const PRODUCTION_SAVE_FLAG: String = "--production-save"
## Test seam. `null` keeps the live gate; a bool forces it.
static var forced: Variant = null


static func available() -> bool:
	if typeof(forced) == TYPE_BOOL:
		return forced
	return ResourceLoader.exists(BOOT) and (
			OS.has_feature("editor") or OS.has_feature("dev_tools"))


## Any launch that carries an argument is a tooling launch (the line `Main._ready`
## already draws between the player's plain boot and a capture or bench), so it
## runs on the isolated Development profile unless it names the production save.
## Keying on "has an argument" rather than on a list of flags is what stops a
## future flag leaking into the player's save by being left off it. The rule lives
## here, not in the excluded boot, so an exported build that is handed tooling
## arguments (an iPad launched with `--map`) is isolated too: the profile never
## depends on `presentation/dev/*` being packed.
static func selects_dev_profile(args: PackedStringArray) -> bool:
	return not args.is_empty() and not args.has(PRODUCTION_SAVE_FLAG)
