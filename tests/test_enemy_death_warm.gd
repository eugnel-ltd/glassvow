extends RefCounted
## The death rite's first-use costs are paid while the fight is built, not on the
## first kill: one shard shader for every actor, made (and its compile started) by
## each foe's build; the rite's FX textures loaded then too; and the painting read
## back once at build rather than on the death frame. A hero never breaks, so it
## warms and keeps nothing.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("enemy death warm: %s" % what)


static func run(fails: Array[String]) -> void:
	_hero_warms_nothing(fails)
	_foe_warms_the_rite(fails)
	_rite_uses_the_warmed_shader(fails)


static func _forget_rite_shaders() -> void:
	EnemyView._shard_shader = null
	EnemyView._fx_shader = null
	EnemyView._fx_cache.erase("burst")
	EnemyView._fx_cache.erase("ember")


static func _hero_warms_nothing(fails: Array[String]) -> void:
	_forget_rite_shaders()
	var hero: EnemyView = EnemyView.new(-1, "", 210.0, &"duskblade")
	_check(fails, hero.tier == "hero", "duskblade is a hero")
	_check(fails, EnemyView._shard_shader == null and EnemyView._fx_shader == null,
		"a hero never breaks, so building one warms no rite shader")
	_check(fails, hero._art_img == null, "a hero keeps no painting for a death cull")
	hero.free()


static func _foe_warms_the_rite(fails: Array[String]) -> void:
	_forget_rite_shaders()
	var foe: EnemyView = EnemyView.new(0, "Duskfang", 210.0, &"duskfang")
	var shard: Shader = EnemyView._shard_shader
	_check(fails, shard != null and shard.code.contains("dissolve"),
		"building a foe makes the shard shader")
	_check(fails, EnemyView._fx_shader != null, "building a foe makes the FX shader")
	_check(fails, EnemyView._fx_cache.has("burst") and EnemyView._fx_cache.has("ember"),
		"building a foe loads the rite's FX textures")
	_check(fails, foe._art_img != null, "a foe reads its painting back at build")
	_check(fails, foe._art_img != null and foe._art_img.get_format() == Image.FORMAT_LA8,
		"a foe keeps its painting as alpha-bearing LA8, not full RGBA, for the fight")
	var other: EnemyView = EnemyView.new(1, "Duskfang", 210.0, &"duskfang")
	_check(fails, EnemyView.shard_shader() == shard,
		"the shard shader is made once and shared by every foe")
	other.free()
	foe.free()


static func _rite_uses_the_warmed_shader(fails: Array[String]) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var foe: EnemyView = EnemyView.new(0, "Duskfang", 210.0, &"duskfang")
	tree.root.add_child(foe)
	var art: Image = foe._art_img
	foe.shatter()
	var pieces: int = 0
	var shared: bool = true
	for node: Node in foe._debris.find_children("", "MeshInstance3D", true, false):
		var smat: ShaderMaterial = (node as MeshInstance3D).get_surface_override_material(0) \
			as ShaderMaterial
		if smat == null:
			continue
		pieces += 1
		shared = shared and smat.shader == EnemyView.shard_shader()
	_check(fails, pieces > 0 and shared, "every flying piece draws the shared shard shader")
	_check(fails, foe._art_img == art, "the death cull reads the image kept at build")
	foe.free()
