shader_type spatial;
// Act II's masonry (#660 II.3, `city_kit.gd`): the causeways' walls, piers,
// parapets and paving on one atlas (`masonry-albedo.png` over
// `masonry-normal.png`: ashlar in its top half, paving in its bottom, each 2 m
// by 1 m in the world). The decks read the paving along their own UV (metres
// across and along the road); everything else is ashlar projected on the
// world, its courses level, along each wall's face or, on a top, across the
// plan. Stone near the water is wet and darker; the lamps' pools and the
// pilgrim's flame light the paving (`city_mask.gd`, `walker_*`). Three
// samplers, none anisotropic (the A12's sampler slots).
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_atlas : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_atlas : hint_normal, filter_linear_mipmap, repeat_enable;
// R the masonry's footprint, G the lamps' pools, B their reflections; over
// `mask_rect` (x, z, width, depth) of the plan.
uniform sampler2D city_mask : filter_linear, repeat_disable;
uniform vec4 mask_rect = vec4(-52.0, -34.0, 104.0, 68.0);
uniform bool paving = false;
uniform vec3 tint = vec3(1.0);
// The still water's level; stone up to `wet_height` over it is wet.
uniform float water_level = -1.18;
uniform float wet_height = 0.55;
uniform vec3 wet_tint = vec3(0.46, 0.55, 0.52);
uniform vec3 lamp_colour = vec3(0.25, 1.0, 0.62);
uniform float lamp_strength = 0.55;
// The pilgrim's flame: where it stands (x, y, z) and its pool's reach (w), and
// its colour (linear) with the pool's strength in a.
uniform vec4 walker = vec4(0.0, -100.0, 0.0, 2.6);
uniform vec4 walker_colour = vec4(1.0, 0.55, 0.2, 0.0);
uniform float walker_strength = 2.2;
uniform float roughness_dry = 0.82;
uniform float roughness_wet = 0.32;

varying vec3 world_at;
varying vec3 world_normal;

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// The atlas texel for layer coordinates `at` (metres over the layer's 2 x 1),
// in the top (ashlar) or bottom (paving) half, with the unwrapped coordinates'
// gradients so a wrap never steps the mip.
vec4 layer_sample(sampler2D atlas, vec2 at, bool floor_layer) {
	vec2 cell = at / vec2(2.0, 1.0);
	vec2 uv = vec2(fract(cell.x), (fract(cell.y) + (floor_layer ? 1.0 : 0.0)) * 0.5);
	vec2 scale = vec2(1.0, 0.5);
	return textureGrad(atlas, uv, dFdx(cell) * scale, dFdy(cell) * scale);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec2 at;
	vec3 along;
	vec3 down;
	if (paving) {
		// The deck's own UV: across the road (x) and along it (y), in metres.
		at = UV;
		// Its frame from the surface's own derivatives (the deck carries no
		// tangents).
		vec3 dp1 = dFdx(world_at);
		vec3 dp2 = dFdy(world_at);
		vec2 duv1 = dFdx(UV);
		vec2 duv2 = dFdy(UV);
		vec3 dp2perp = cross(dp2, n);
		vec3 dp1perp = cross(n, dp1);
		vec3 t = dp2perp * duv1.x + dp1perp * duv2.x;
		vec3 b = dp2perp * duv1.y + dp1perp * duv2.y;
		float inverse = inversesqrt(max(max(dot(t, t), dot(b, b)), 1e-12));
		along = t * inverse;
		down = b * inverse;
	} else if (abs(n.y) > 0.7) {
		at = world_at.xz;
		along = vec3(1.0, 0.0, 0.0);
		down = vec3(0.0, 0.0, 1.0);
	} else {
		vec2 face = normalize(vec2(-n.z, n.x));
		at = vec2(dot(world_at.xz, face), -world_at.y);
		along = vec3(face.x, 0.0, face.y);
		down = vec3(0.0, -1.0, 0.0);
	}
	vec3 stone = layer_sample(albedo_atlas, at, paving).rgb * tint;
	vec2 xy = layer_sample(normal_atlas, at, paving).rg * 2.0 - 1.0;
	vec3 mapped = vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));
	// The atlas's green points up its image, against `down`.
	vec3 bent = normalize(along * mapped.x - down * mapped.y + n * mapped.z);
	float wet = 1.0 - smoothstep(water_level, water_level + wet_height, world_at.y);
	stone *= mix(vec3(1.0), wet_tint, wet);
	vec2 plan = (world_at.xz - mask_rect.xy) / mask_rect.zw;
	vec4 mask = texture(city_mask, plan);
	float top = smoothstep(0.45, 0.85, n.y);
	vec3 glow = lamp_colour * mask.g * lamp_strength * top;
	float near = 1.0 - smoothstep(0.0, walker.w, distance(world_at.xz, walker.xz));
	float level = 1.0 - smoothstep(0.6, 1.8, abs(world_at.y - walker.y));
	// The flame warms the stone round the pilgrim, the parapets' faces too.
	glow += walker_colour.rgb * walker_colour.a * near * near * level * mix(0.45, 1.0, top) * walker_strength;
	ALBEDO = stone;
	EMISSION = glow * stone * 2.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
	ROUGHNESS = mix(roughness_dry, roughness_wet, wet);
	SPECULAR = mix(0.35, 0.6, wet);
}
