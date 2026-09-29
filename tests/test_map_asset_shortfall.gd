extends RefCounted
## A declared act that resolves only part of its landscape fails loudly (#451).
##
## Every act, 0-3, declares a set in `MapLandscapeAssets`, so a partial resolve is
## a defect: `MapScene` must push an error that names the act and the count,
## record the layout failure, and bind nothing. No shipped act fails, so the test
## hands the binder a catalogue that stops part-way, as a missing file would. The
## `ERROR:` lines in the run output are this test's deliberate probe.
##
## An act nobody has authored is not a case any more: the placeholder renderer
## that kept it on placeholders went in `7fc07f66`. What replaces that case is the
## table check below, so an act added to the game without a landscape set fails
## here rather than rendering another act's art.


## `push_error` has no return value to assert on, so this records what the engine
## reports while it is registered.
class ErrorLog:
	extends Logger

	var errors: PackedStringArray = PackedStringArray()

	func _log_error(_function: String, _file: String, _line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_ERROR:
			errors.append(code if rationale.is_empty() else rationale)

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func scene_errors() -> PackedStringArray:
		var out: PackedStringArray = PackedStringArray()
		for text: String in errors:
			if text.begins_with("MapScene: "):
				out.append(text)
		return out


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_asset_shortfall: %s" % what)


static func run(fails: Array[String]) -> void:
	_every_act_declares_a_set(fails)
	_shipped_acts_are_quiet(fails)
	# Act I carries the Vigil and is the act a scene starts bound to, so it needs
	# the salt to rebind; Act II is the act whose art the issue worried about.
	_partial_set_fails_loudly(fails, 0)
	_partial_set_fails_loudly(fails, 1)


static func _every_act_declares_a_set(fails: Array[String]) -> void:
	_check(fails, MapLandscapeAssets.SCENERY.size() == LayoutBook.ACTS
			and MapLandscapeAssets.GATES.size() == LayoutBook.ACTS,
		"every act the game has declares a landscape set, so none is left to guess at")
	for act_index: int in range(LayoutBook.ACTS):
		var declared: Array[String] = MapLandscapeAssets.declared_ids(act_index)
		_check(fails, declared.has(MapLandscapeAssets.GATES[act_index]),
			"act index %d declares its gate" % act_index)
		_check(fails, declared.has("vigil") == (act_index == 0),
			"only Act I declares the Vigil (act index %d)" % act_index)
		var assets: MapLandscapeAssets = MapLandscapeAssets.new(act_index)
		_check(fails, assets.meshes.size() == declared.size(),
			"act index %d resolves all %d declared assets, got %d"
				% [act_index, declared.size(), assets.meshes.size()])
		_check(fails, assets.shortfall().is_empty(),
			"a whole set reports no shortfall (act index %d)" % act_index)


static func _shipped_acts_are_quiet(fails: Array[String]) -> void:
	var log: ErrorLog = ErrorLog.new()
	OS.add_logger(log)
	var scene: MapScene = MapScene.new()
	for act_index: int in range(LayoutBook.ACTS):
		scene.set_act(act_index)
		_check(fails, scene.layout_failure().is_empty()
				and not scene.asset_profile_digest().is_empty(),
			"act index %d binds a whole landscape" % act_index)
	OS.remove_logger(log)
	scene.free()
	_check(fails, log.scene_errors().is_empty(),
		"a whole set pushes no error: %s" % ", ".join(log.scene_errors()))


static func _partial_set_fails_loudly(fails: Array[String], act_index: int) -> void:
	var declared: Array[String] = MapLandscapeAssets.declared_ids(act_index)
	var missing: String = declared[declared.size() - 1]
	var scene: MapScene = MapScene.new()
	# Resolution stops at the first asset that will not load and builds no profile
	# after it, so what resolved before it stays and nothing else does.
	scene._landscape_source = func(index: int) -> MapLandscapeAssets:
		var assets: MapLandscapeAssets = MapLandscapeAssets.new(index)
		assets.meshes.erase(missing)
		assets.profiles.clear()
		assets.digest = ""
		assets.failure = "Cannot load landscape asset: " + missing
		return assets
	var log: ErrorLog = ErrorLog.new()
	OS.add_logger(log)
	# A salt change rebinds the current act, which `set_act` alone would not.
	scene.set_scatter_salt(814)
	scene.set_act(act_index)
	OS.remove_logger(log)

	var errors: PackedStringArray = log.scene_errors()
	_check(fails, errors.size() == 1,
		"act index %d: a partial set pushes exactly one MapScene error, got %d"
			% [act_index, errors.size()])
	var text: String = errors[0] if not errors.is_empty() else ""
	_check(fails, text.contains("Act %d (act_index %d)"
			% [ActFlag.number_of(act_index), act_index]),
		"act index %d: the error names the act by number and index: %s" % [act_index, text])
	_check(fails, text.contains("declares %d landscape assets and resolved %d"
			% [declared.size(), declared.size() - 1]),
		"act index %d: the error carries the declared and resolved counts: %s"
			% [act_index, text])
	_check(fails, text.contains(missing),
		"act index %d: the error names the asset that did not load: %s" % [act_index, text])
	var failure: Dictionary = scene.layout_failure()
	_check(fails, str(failure.get("reason", "")).contains(missing),
		"act index %d: the layout failure is recorded" % act_index)
	_check(fails, scene.layout_asset_bundle().is_empty()
			and scene.layout_hero_contract().is_empty(),
		"act index %d: nothing is bound from a partial set" % act_index)
	scene.free()
