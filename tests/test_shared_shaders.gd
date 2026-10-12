extends RefCounted
## One Shader per code string (#682 Part 2). The renderer keeps a material's
## pipelines with its Shader, so the title's warm (PathWarm) serves a use only
## when both wear the same Shader:
## - `SharedShaders.of` hands out one Shader per code, for the process;
## - the warm and the fight's, the transitions' and the reward's use sites
##   wear that very Shader, never one of their own made from the same string;
## - no script outside SharedShaders makes a Shader from a string (the guard
##   that catches a new use site, and an old one put back).

## The script roots the game is built from (tests and tools may make their own).
const ROOTS: Array[String] = ["res://presentation", "res://application"]
const FACTORY: String = "res://presentation/stage/shared_shaders.gd"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_shared_shaders: %s" % what)


static func run(fails: Array[String]) -> void:
	_one_per_code(fails)
	_enemy_view_wears_them(fails)
	_transitions_wear_them(fails)
	_warm_wears_them(fails)
	_no_other_factory(fails)


static func _one_per_code(fails: Array[String]) -> void:
	var a: Shader = SharedShaders.of("shader_type canvas_item;\n// test_shared_shaders a\n")
	var b: Shader = SharedShaders.of("shader_type canvas_item;\n// test_shared_shaders a\n")
	var c: Shader = SharedShaders.of("shader_type canvas_item;\n// test_shared_shaders c\n")
	_check(fails, a != null and a == b, "one code string gives one Shader")
	_check(fails, a != c, "another code string gives another Shader")
	_check(fails, a.code == "shader_type canvas_item;\n// test_shared_shaders a\n", "the Shader carries its code")


static func _wears(mat: Material, code: String) -> bool:
	return mat is ShaderMaterial and (mat as ShaderMaterial).shader == SharedShaders.of(code)


static func _enemy_view_wears_them(fails: Array[String]) -> void:
	var foe: EnemyView = EnemyView.new(0, "Duskfang", 210.0, &"duskfang")
	_check(fails, _wears(foe._body_mat, EnemyView.with_tint(EnemyView.with_erode(EnemyView.BODY_SHADER))),
		"a foe's body wears the shared Shader")
	_check(fails, _wears(foe._shadow_mat, EnemyView.SHADOW_SHADER), "a foe's shadow wears the shared Shader")
	_check(fails, _wears(foe._display_mat, EnemyView.RESEAM_SHADER), "a foe's reseam wears the shared Shader")
	_check(fails, _wears(foe._ward_mat, EnemyView.WARD_SHADER), "a foe's ward wears the shared Shader")
	_check(fails, _wears(foe._glass_material(), EnemyView.with_tint(EnemyView.GLASS_SHADER)),
		"a foe's glass wears the shared Shader")
	_check(fails, EnemyView.shard_shader() == SharedShaders.of(EnemyView.with_tint(EnemyView.with_erode(EnemyView.SHARD_SHADER))),
		"the shard shader is the shared Shader")
	_check(fails, _wears(EnemyView._add_mat(null), EnemyView.FX_SHADER), "the rite's FX wears the shared Shader")
	foe.free()


static func _transitions_wear_them(fails: Array[String]) -> void:
	var layer: TransitionLayer = TransitionLayer.new()
	_check(fails, _wears(layer._iris_mat, TransitionLayer.IRIS_SHADER), "the iris wears the shared Shader")
	_check(fails, _wears(layer._flood_mat, TransitionLayer.IRIS_SHADER), "the flood wears the iris's shared Shader")
	_check(fails, _wears(layer._grain_mat, TransitionLayer.GRAIN_SHADER), "the transitions' grain wears the shared Shader")
	layer.free()


## The warm's string materials are the same Shaders the uses wear.
static func _warm_wears_them(fails: Array[String]) -> void:
	for code: String in [EnemyView.RESEAM_SHADER, CombatScreen.VIGNETTE_SHADER, CombatScreen.STAGE_DIM_SHADER,
			CombatScreen.GRAIN_SHADER, TransitionLayer.IRIS_SHADER]:
		_check(fails, _wears(PathWarm._string(code), code), "the warm's material for a string wears the shared Shader")


## No script the game is built from makes a Shader of its own; only the factory.
static func _no_other_factory(fails: Array[String]) -> void:
	var stack: Array[String] = ROOTS.duplicate()
	var found: Array[String] = []
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		for sub: String in dir.get_directories():
			stack.append(dir_path.path_join(sub))
		for file: String in dir.get_files():
			var path: String = dir_path.path_join(file)
			if not file.ends_with(".gd") or path == FACTORY:
				continue
			if FileAccess.get_file_as_string(path).contains("Shader.new()"):
				found.append(path)
	_check(fails, found.is_empty(), "only SharedShaders makes a Shader from a string (also: %s)" % ", ".join(found))
