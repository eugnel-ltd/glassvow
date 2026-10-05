shader_type spatial;
// The floor bake's lit pass (R3.2, `floor_bake.gd`): Act I's forest floor as
// it lies under the land's key light, drawn once from straight above into a
// world-space picture the runtime floor samples (`floor.gdshader`). It can
// afford what no live frame can: four photographed ground covers blended by
// the land (`floor_ground.gdshaderinc`), a scatter of pebbles, twigs and leaves
// from a decal atlas, a relief from the covers' own shading, the soft key
// shadows of every static caster, contact occlusion at every base and a real
// pool under every lamp. Seen from above, so the key's specular is kept low:
// what the journey camera sees glint in the wet is the runtime shader's.
render_mode cull_back, diffuse_burley, specular_schlick_ggx, fog_disabled;
#include "res://presentation/map/landscape/floor_ground.gdshaderinc"

uniform sampler2D moss : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D litter : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D road : source_color, filter_linear_mipmap, repeat_enable;
// Pebbles, twigs, leaves and clumps, four rows of four, with alpha.
uniform sampler2D splats : source_color, filter_linear_mipmap, repeat_disable;
// Metres each cover's picture spans.
uniform vec4 cover_metres = vec4(2.6, 3.2, 2.4, 2.2);
// Each cover's picture scaled to the land's albedo (linear multipliers): the
// photographs are lit brighter than a dusk woodland's ground.
uniform vec3 moss_tint = vec3(0.55, 0.56, 0.42);
uniform vec3 litter_tint = vec3(0.44, 0.38, 0.38);
uniform vec3 soil_tint = vec3(0.42, 0.4, 0.4);
uniform vec3 road_tint = vec3(0.66, 0.58, 0.5);
// Each cover's saturation (moss, litter, soil, road): the grade lifts it again.
uniform vec4 cover_saturation = vec4(0.85, 0.8, 0.7, 0.45);
uniform vec3 rut_tint = vec3(0.78, 0.76, 0.76);
uniform vec3 wet_tint = vec3(0.62, 0.66, 0.72);
uniform vec3 rock_colour : source_color = vec3(0.3, 0.285, 0.3);
uniform vec3 paving_colour : source_color = vec3(0.325, 0.314, 0.31);
uniform vec3 pool_colour : source_color = vec3(1.0, 0.627, 0.29);
uniform float splat_cell = 0.42;
uniform float relief = 0.06;
uniform float contact_depth = 0.45;
varying vec3 world_at;
varying vec3 world_normal;

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec2 turned(vec2 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// A cover sampled twice, turned and at two scales, and mixed by a slow field,
// so its picture never repeats on the land's scale; at `saturation`.
vec3 cover(sampler2D picture, vec2 p, float metres, float seed, float saturation) {
	vec3 a = texture(picture, p / metres).rgb;
	vec3 b = texture(picture, turned(p, 1.1 + seed) / (metres * 1.37) + seed).rgb;
	vec3 c = mix(a, b, smoothstep(0.3, 0.7, floor_noise(p * 0.21 + seed * 7.0)));
	return mix(vec3(dot(c, vec3(0.2126, 0.7152, 0.0722))), c, saturation);
}

// One splat of row `row` per cell where `density` allows, from the cells round
// `p`: its colour and coverage.
vec4 scatter(vec2 p, float row, float density, float size, float seed) {
	vec4 out_colour = vec4(0.0);
	vec2 base = floor(p / splat_cell - 0.5);
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			float h = floor_hash(cell + seed);
			if (h > density) {
				continue;
			}
			float h2 = floor_hash(cell * 1.7 + seed + 11.0);
			float h3 = floor_hash(cell * 2.3 + seed + 23.0);
			vec2 centre = (cell + 0.5 + (vec2(h2, h3) - 0.5) * 0.7) * splat_cell;
			float scale = size * (0.65 + 0.7 * h2);
			vec2 local = turned(p - centre, h3 * 6.2832) / scale + 0.5;
			if (any(lessThan(local, vec2(0.0))) || any(greaterThan(local, vec2(1.0)))) {
				continue;
			}
			float column = floor(fract(h * 7.31 + h3) * 4.0);
			vec4 texel = texture(splats, (vec2(column, row) + mix(vec2(0.04), vec2(0.96), local)) * 0.25);
			out_colour = mix(out_colour, vec4(texel.rgb, 1.0), texel.a);
		}
	}
	return out_colour;
}

void fragment() {
	vec2 p = world_at.xz;
	Floor f = floor_at(p, world_at.y, world_normal);
	vec3 soil_c = cover(soil, p, cover_metres.z, 0.0, cover_saturation.z) * soil_tint;
	vec3 moss_c = cover(moss, p, cover_metres.x, 1.7, cover_saturation.x) * moss_tint;
	vec3 litter_c = cover(litter, p, cover_metres.y, 3.1, cover_saturation.y) * litter_tint;
	vec3 road_c = cover(road, p, cover_metres.w, 4.9, cover_saturation.w) * road_tint;
	// Open ground: olive moss over most of it, ash soil showing through in
	// patches, the woodland's red litter beneath and round its crowns, grey
	// grit where the rocks reach.
	float drifts = smoothstep(0.24, 0.52, floor_fbm(p * 0.33 + 5.0));
	float fallen = f.forest * smoothstep(0.25, 0.6, floor_fbm(p * 0.47 + 19.0) + f.forest * 0.25);
	vec3 ground = mix(soil_c, moss_c, drifts * (0.7 + 0.3 * (1.0 - f.forest)));
	ground = mix(ground, litter_c, fallen);
	ground = mix(ground, mix(soil_c, rock_colour, 0.45), f.rock * 0.55);
	// The verge: moss and grass grown thick over the road's shoulders.
	vec3 verge_c = mix(moss_c, litter_c, f.forest * 0.35 + 0.1);
	ground = mix(ground, verge_c, f.verge * 0.9);
	// The road: packed earth, the ruts darker and damp, the crown grown over.
	vec3 track = mix(road_c, road_c * rut_tint, f.rut);
	track = mix(track, moss_c * 0.9, f.crown * 0.75);
	track = mix(track, verge_c, f.tuft);
	vec3 albedo = mix(ground, track, f.core);
	// The gateway's apron of worn flags, as R2's ground laid it.
	vec2 stone = vec2(p.x * 0.94 + p.y * 0.342, -p.x * 0.342 + p.y * 0.94) * vec2(1.55, 1.85);
	float row_id = floor(stone.y);
	stone.x = stone.x * (0.88 + 0.26 * floor_hash(vec2(row_id, 23.0))) + floor_hash(vec2(row_id, 17.0)) * 0.72;
	vec2 cell = abs(fract(stone) - 0.5);
	vec2 corner = cell - vec2(0.418, 0.425);
	float stone_edge = length(max(corner, vec2(0.0))) + min(max(corner.x, corner.y), 0.0) + 0.43;
	float joint = smoothstep(0.468, 0.492, stone_edge);
	vec3 masonry = paving_colour * (0.89 + 0.19 * floor_hash(floor(stone) + 9.0)) * (1.0 - joint * 0.19);
	albedo = mix(albedo, masonry, f.paving * 0.85);
	// Slate faces where the land falls steeply.
	albedo = mix(albedo, rock_colour * (0.88 + 0.1 * floor_noise(vec2(p.x * 0.19 + p.y * 0.11, world_at.y * 1.1))), f.scarp * 0.7);
	// The scatter: pebbles on the road's edges and the rocks' reach, twigs and
	// leaves under the woodland and along the verges, clumps here and there.
	float open_ground = 1.0 - f.core * (1.0 - f.tuft);
	vec4 s = scatter(p, 0.0, 0.08 + 0.3 * f.rock + 0.3 * f.verge + 0.55 * f.core, 0.11, 0.0);
	albedo = mix(albedo, s.rgb, s.a);
	s = scatter(p, 1.0, (0.05 + 0.3 * f.forest) * open_ground, 0.34, 5.0);
	albedo = mix(albedo, s.rgb, s.a * 0.9);
	s = scatter(p, 2.0, (0.06 + 0.45 * f.forest + 0.2 * f.verge) * (1.0 - f.rut), 0.2, 9.0);
	albedo = mix(albedo, s.rgb, s.a);
	s = scatter(p, 3.0, 0.04 + 0.3 * f.verge + 0.1 * f.rock + 0.12 * f.core, 0.3, 13.0);
	albedo = mix(albedo, s.rgb, s.a * 0.9);
	// Wet ground darkens and cools; standing water darker still.
	albedo = mix(albedo, albedo * wet_tint, f.wet * 0.75);
	albedo = mix(albedo, albedo * wet_tint * 0.55, f.puddle * 0.8);
	ALBEDO = albedo;
	// The covers' own shading as relief under the low key light (screen space
	// is the land seen from straight above).
	float height_field = dot(albedo, vec3(0.3, 0.59, 0.11)) * relief * (1.0 - f.puddle);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float determinant = dot(dpdx, r1);
	if (abs(determinant) > 0.00000001) {
		NORMAL = normalize(NORMAL - (r1 * dFdx(height_field) + r2 * dFdy(height_field)) / determinant);
	}
	ROUGHNESS = mix(0.97, 0.35, f.puddle);
	SPECULAR = 0.06;
	AO = 1.0 - f.contact * contact_depth;
	AO_LIGHT_AFFECT = 0.55;
	vec2 pools = floor_pools(world_at, world_normal);
	EMISSION = albedo * pool_colour * pools.x * (1.0 - f.contact * contact_depth * 0.5);
}
