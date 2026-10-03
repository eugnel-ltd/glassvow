extends RefCounted
## Prepares an imported kit scene's surfaces for the map.
##
## The kit's GLBs import without their images (`embedded_image_handling`
## discards them): every GLB embedded its own copy of one of three painted
## sources, which shipped the same pixels many times over and uncompressed.
## Each surface instead takes the one shared, VRAM-compressed source its
## material is named for. Foliage also uses cut-out depth and coverage rather
## than order-dependent blending.
const STONE: Texture2D = preload("res://assets/art/map-journey/textures/ash-stone-colour.png")
const TWIGS: Texture2D = preload("res://assets/art/map-journey/textures/ash-twigs.png")
const SPRAYS: Texture2D = preload("res://assets/art/map-journey/textures/conifer-sprays.png")


## The shared source a kit material paints with, by its authored name; null
## for the flat-coloured materials (bark, bronze, glass, lead).
static func source_for(material_name: String) -> Texture2D:
	if material_name.begins_with("Foliage /"):
		return TWIGS if material_name.contains("twig") or material_name.contains("thorn") else SPRAYS
	if material_name.begins_with("Ash stone") or material_name == "Worn pale stone":
		return STONE
	return null


## Gives every surface of `root` its prepared material, shared through `pool`
## (one per authored material). Returns how many foliage surfaces it prepared.
static func prepare(root: Node3D, pool: Variant = null) -> int:
	var count: int = 0
	var materials: Dictionary = pool if pool is Dictionary else {}
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child as MeshInstance3D
		if instance.mesh == null:
			continue
		for index: int in range(instance.mesh.get_surface_count()):
			var original: StandardMaterial3D = instance.get_active_material(index) as StandardMaterial3D
			if original == null:
				continue
			var foliage: bool = original.resource_name.begins_with("Foliage /")
			var key: int = original.get_instance_id()
			if materials.has(key):
				var shared: Material = materials[key]
				instance.set_surface_override_material(index, shared)
				count += 1 if foliage else 0
				continue
			var source: Texture2D = source_for(original.resource_name)
			if source == null and not foliage:
				continue
			var material: StandardMaterial3D = original.duplicate() as StandardMaterial3D
			if source != null:
				material.albedo_texture = source
			if foliage:
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold = 0.3
				material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				material.roughness = 0.96
				material.metallic = 0
				count += 1
			materials[key] = material
			instance.set_surface_override_material(index, material)
	return count
