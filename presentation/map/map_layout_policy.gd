class_name MapLayoutPolicy
extends RefCounted
## Which generator lays out the live map.
##
## Production uses `MapLayoutFast`. Map Compiler v2 is an authoring opt-in: it
## runs only on a desktop build and only when asked for, by the `--map-compiler`
## user argument or the `glassvow/map/layout_compiler` project setting (absent,
## so false, in the shipped project). A mobile build never compiles: a single
## compile takes minutes and gigabytes on a desktop (docs/map/production-layout.md).
##
## The choice is written into the canonical input (`generator_schema` and
## `generator_version`), so the input digest, every layout cache keyed by it and
## the dispatch below all agree on which generator a layout came from.

const SETTING: String = "glassvow/map/layout_compiler"
const FLAG: String = "--map-compiler"
const COMPILER_SCHEMA: String = "map-compiler-v2"

## Test-visible count of dispatches to the compiler in this process.
static var compiler_dispatches: int = 0


static func compiler_requested() -> bool:
	if OS.has_feature("mobile"):
		return false
	var setting: Variant = ProjectSettings.get_setting(SETTING, false)
	return (typeof(setting) == TYPE_BOOL and setting == true) \
		or OS.get_cmdline_user_args().has(FLAG)


## The generator identity to write into a new canonical input.
static func generator_fields(use_compiler: bool) -> Dictionary:
	if use_compiler:
		return {"generator_schema": COMPILER_SCHEMA,
			"generator_version": MapLayoutCompiler.VERSION}
	return {"generator_schema": MapLayoutFast.SCHEMA,
		"generator_version": MapLayoutFast.VERSION}


static func is_compiler_input(input: MapLayoutInput) -> bool:
	return input != null and str(input.to_dict().get("generator_version", "")) \
		== MapLayoutCompiler.VERSION


## Lay out `input` with the generator it names. Returns the compiler's packet
## shape (`status`, `result`, `report`, `failure`, `diagnostics`).
static func generate(input: MapLayoutInput, quality: Dictionary,
		assets: Dictionary) -> Dictionary:
	if is_compiler_input(input):
		compiler_dispatches += 1
		return MapLayoutCompiler.compile(input, quality, assets)
	return MapLayoutFast.compile(input, quality, assets)
