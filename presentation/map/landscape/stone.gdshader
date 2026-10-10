shader_type spatial;
// Act I's hero stone (R3.3, `land_stone.gd`): the granite outcrops and the
// ravine's cliff pieces, merged into a few meshes, all on one atlas baked from
// their Blender sculpts (`tools/map_atelier/journey/stone/`): the colour,
// carrying its occlusion, and the tangent-space normals at half its size. Moss
// caps what faces the sky, by the mapped normal's world-up share, broken up by
// the moss's own picture (the floor's, sampled in world space). Lit as the
// land is; it casts into the floor's bake, not live. Three samplers, none
// anisotropic (the A12's sampler slots).
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_atlas : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D moss : source_color, filter_linear_mipmap, repeat_enable;
// The baked colour's grade on the land (linear): granite reads grey under
// the warm key, not tan.
uniform vec3 stone_tint = vec3(0.8, 0.83, 0.88);
// Metres the moss's picture spans, and its colour on stone (linear): the
// floor's moss lifted to a living olive green.
uniform float moss_metres = 1.3;
uniform vec3 moss_tint = vec3(1.15, 1.5, 0.6);
// The moss the cliffs' strata take, as a share of the outcrops': the atlas's
// cells (`build_stone.py`, 4 x 3) hold the five outcrops first, then the six
// cliff pieces, so a cliff's UV lies below the first row and right of the
// fifth cell.
uniform float strata_moss = 0.35;
// The world-up share of the mapped normal at which moss starts and is whole.
uniform vec2 moss_rise = vec2(0.5, 0.8);
uniform float roughness_stone = 0.88;
uniform float roughness_moss = 0.97;

// No vertex stage of its own: the stone casts (into the floor's bake) through
// the renderer's shared shadow pipeline, so it adds no shadow pipeline to warm.
void fragment() {
	vec3 world_at = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 stone = texture(albedo_atlas, UV).rgb * stone_tint;
	vec3 mapped = texture(normal_atlas, UV).rgb;
	// The mapped normal in the world, as the renderer will light it.
	vec2 xy = mapped.xy * 2.0 - 1.0;
	vec3 local = vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));
	vec3 view_normal = normalize(TANGENT * local.x + BINORMAL * local.y + NORMAL * local.z);
	float up = (INV_VIEW_MATRIX * vec4(view_normal, 0.0)).y;
	vec3 cover = texture(moss, world_at.xz / moss_metres).rgb * moss_tint;
	float breakup = dot(cover, vec3(0.2126, 0.7152, 0.0722)) / max(dot(moss_tint, vec3(0.2126, 0.7152, 0.0722)), 1e-3);
	float strata = step(1.0 / 3.0, UV.y) * max(step(0.25, UV.x), step(2.0 / 3.0, UV.y));
	float grown = smoothstep(moss_rise.x, moss_rise.y, up + (breakup - 0.45) * 0.35) * mix(1.0, strata_moss, strata);
	ALBEDO = mix(stone, cover, grown);
	NORMAL_MAP = mapped;
	NORMAL_MAP_DEPTH = mix(1.0, 0.45, grown);
	ROUGHNESS = mix(roughness_stone, roughness_moss, grown);
	SPECULAR = 0.3;
}
