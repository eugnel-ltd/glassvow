shader_type spatial;
// Act II's city water (#660 II.3, `water.gd`): one still, dark sheet under the
// causeways, R3.4's river water (`river_water.gdshaderinc`) made a drowned
// city's. Deep and darker in the ravines' channels, lighter and washing white
// in a thin line at every wall and pier's foot, a cool sky at a grazing angle,
// the jade lamps and the pilgrim's flame mirrored in long, broken columns, and
// a few glints on the swell. It reads no screen and no depth, and samples one
// texture: the land's light mask (`city_mask.gd`; the channels are worked out
// here, on `MapRavine`'s line). `flow_time` stands still
// under Reduce Motion (`water.gd`).
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D city_mask : filter_linear, repeat_disable;
uniform vec4 mask_rect = vec4(-52.0, -34.0, 104.0, 68.0);
uniform float flow_time = 0.0;
// The ravines' channels (`MapRavine`): their cuts, the half width they are
// deep across and how far they open beyond it.
uniform vec2 channel_cuts = vec2(-20.5, 10.5);
uniform float channel_half = 1.5;
uniform float channel_fade = 1.6;
// The palette, linear: the open water, the channels' depth, the wash, the sky
// the water mirrors from overhead to the horizon, and what lights it.
uniform vec3 open_tint = vec3(0.016, 0.046, 0.052);
uniform vec3 deep_tint = vec3(0.005, 0.016, 0.022);
uniform vec3 shallow_tint = vec3(0.030, 0.080, 0.084);
uniform vec3 foam_tint = vec3(0.42, 0.55, 0.56);
uniform vec3 sky_high = vec3(0.012, 0.035, 0.050);
uniform vec3 sky_low = vec3(0.13, 0.29, 0.33);
uniform vec3 lamp_colour = vec3(0.25, 1.0, 0.62);
uniform float lamp_reflection = 0.55;
uniform vec4 walker = vec4(0.0, -100.0, 0.0, 2.6);
uniform vec4 walker_colour = vec4(1.0, 0.55, 0.2, 0.0);
uniform float glints = 1.2;

varying vec3 world_at;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// How deep the water is at `p`: 1 in a ravine's channel, on the GPU's sine
// (`MapRavine.centre`).
float channel(vec2 p) {
	float deep = 0.0;
	for (int i = 0; i < 2; i++) {
		float centre = channel_cuts[i] + sin(p.y * 0.19) * 1.4 + sin(p.y * 0.61) * 0.3;
		deep = max(deep, 1.0 - smoothstep(channel_half, channel_half + channel_fade, abs(p.x - centre)));
	}
	return deep;
}

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_at.xz;
	vec4 mask = texture(city_mask, (p - mask_rect.xy) / mask_rect.zw);
	float t = flow_time * TAU / 12.0;
	// The swell: slow crossing waves, their analytic slope halved as R3.4's.
	float a = p.y * 2.1 + p.x * 0.7 - t;
	float b = p.x * 3.3 - p.y * 1.3 + t * 1.3;
	float c = p.x * 7.1 + p.y * 5.3 - t * 2.1;
	float dx = cos(a) * 0.7 * 0.012 + cos(b) * 3.3 * 0.008 + cos(c) * 7.1 * 0.003;
	float dz = cos(a) * 2.1 * 0.012 - cos(b) * 1.3 * 0.008 + cos(c) * 5.3 * 0.003;
	float drift = noise(p * 1.7 + vec2(t * 0.11, -t * 0.07));
	vec3 n = normalize(vec3(-dx * 0.5, 1.0, -dz * 0.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 world_view = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	// Depth: dark in the channels, a little lighter along the masonry's feet.
	float wall = mask.r;
	vec3 water = mix(open_tint, deep_tint, channel(p));
	water = mix(water, shallow_tint, smoothstep(0.35, 0.9, wall) * 0.6);
	water *= 0.8 + 0.4 * drift;
	// The masonry mirrored: a wall's dark face lies in the water toward the
	// viewer below its foot (the camera looks along -z), broken by the swell.
	vec2 mirrored = (p + vec2(dx * 6.0, -0.9 + dz * 6.0) - mask_rect.xy) / mask_rect.zw;
	float wall_above = texture(city_mask, mirrored).r * (1.0 - wall);
	water *= 1.0 - 0.45 * wall_above;
	// The sky, from overhead to the horizon's glow, at a grazing angle.
	vec3 reflected = reflect(-world_view, n);
	vec3 sky = mix(sky_low, sky_high, smoothstep(0.1, 0.8, reflected.y));
	float fresnel = 0.04 + 0.5 * pow(1.0 - max(0.0, dot(n, world_view)), 4.0);
	water = mix(water, sky, fresnel);
	// The wash: a thin broken line of white where the water meets the stone.
	float lace = noise(p * 6.0 + vec2(t * 0.3, t * 0.2)) * noise(p * 13.0 - vec2(t * 0.25, 0.0));
	float wash = smoothstep(0.82, 0.97, wall) * (1.0 - smoothstep(0.995, 1.0, wall));
	float foam = clamp(wash * smoothstep(0.08, 0.35, lace + 0.1), 0.0, 1.0) * 0.7;
	water = mix(water, foam_tint, foam);
	// The lamps' and the flame's reflections: columns toward the viewer, broken
	// by the swell.
	float broken = noise(vec2(p.x * 7.0 + dx * 40.0, p.y * 3.1 - t * 0.5));
	float shimmer = smoothstep(0.25, 0.75, broken) * 1.6;
	vec3 light = lamp_colour * mask.b * lamp_reflection * shimmer;
	vec2 from_walker = p - walker.xz;
	float column = exp(-pow(from_walker.x / 0.35, 2.0)) * smoothstep(-0.4, 0.3, from_walker.y)
		* (1.0 - smoothstep(0.5, walker.w + 1.5, from_walker.y));
	light += walker_colour.rgb * walker_colour.a * column * shimmer * 0.6;
	// Glints: a few sparks on the swell's crests.
	float spark = smoothstep(0.95, 0.995, noise(p * vec2(8.0, 30.0) + vec2(t * 0.9, t * 0.6))) * glints;
	light += sky_low * spark * (0.3 + fresnel * 3.0);
	ALBEDO = water;
	EMISSION = light;
	METALLIC = 0.15 * (1.0 - foam);
	ROUGHNESS = mix(0.06, 0.5, foam);
	SPECULAR = 0.7;
}
