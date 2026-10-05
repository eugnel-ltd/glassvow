// Act I's forest floor, worked out in world space for the floor's bake
// (R3.2, `floor_bake.gd`): where the roads wear the land into two ruts with a
// grown-over crown between them and ragged, overgrown verges; the woodland's,
// the rocks' and every base's reach (`floor_fields.gd`); the river's banks;
// the wet; and the pool of every lamp. Shared by the bake's lit pass
// (`floor_paint.gdshader`) and its mask (`floor_mask.gdshader`), so the two
// read one floor. Nothing here runs live: the floor's runtime shader
// (`floor.gdshader`) samples what the bake made of it.
uniform vec4 world_bounds = vec4(-48.0, -30.0, 96.0, 60.0);
// The roads' distance field (`terrain_paint.gd` `create`): metres to the
// nearest road centreline on the ground, smooth to about 4 m. A 32-bit float
// texture, which the A12 cannot filter: read by hand (`floor_route`).
uniform sampler2D route_distance : filter_nearest, repeat_disable;
// The plants' reach (`floor_fields.gd`): r the woodland, g the rocks, b the
// contact occlusion round every base, each summed in the bake's 2D pass.
uniform sampler2D fields : filter_linear, repeat_disable;
uniform vec2 fields_origin = vec2(-48.0, -30.0);
uniform vec2 fields_size = vec2(96.0, 60.0);
// The layout's two ravines (MapRavine.CUTS), the river's channel scale and
// water level, and the gateway's apron.
uniform vec2 river_cuts = vec2(-20.5, 10.5);
uniform float channel = 1.0;
uniform float river_level = -1000.0;
uniform vec2 gateway_position = vec2(-1000.0);
// Every lamp's flame centre (xyz) in the land's space: a real omni light each,
// as Godot lights one (`get_omni_attenuation`), worked out here because the
// Mobile renderer lights a mesh with at most eight.
uniform int lamp_count = 0;
uniform vec4 lamps[48];
// The lamps' lights: brighter than the desktop's few real ones (`lamps.gd`:
// 1.6, 4.2 m, 1.4), since here every lamp has one and it is the pool of light
// round each lantern that the target holds; no wider, so the road between the
// lamps keeps its own grey.
uniform float pool_energy = 4.2;
uniform float pool_range = 4.2;
uniform float pool_decay = 1.2;

float floor_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float floor_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(floor_hash(i), floor_hash(i + vec2(1.0, 0.0)), f.x),
		mix(floor_hash(i + vec2(0.0, 1.0)), floor_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float floor_fbm(vec2 p) {
	return floor_noise(p) * 0.55 + floor_noise(p * 2.07 + 13.1) * 0.3 + floor_noise(p * 4.31 + 37.7) * 0.15;
}

// A lamp's flicker phase, exactly as its flame works it out (`flame.gdshader`).
float floor_lamp_phase(vec2 at) {
	return fract(sin(dot(at, vec2(12.9898, 78.233))) * 43758.5453);
}

// The roads' distance at `uv`, bilinear between its four nearest texels.
float floor_route(vec2 uv) {
	ivec2 size = textureSize(route_distance, 0);
	vec2 at = uv * vec2(size) - 0.5;
	ivec2 base = ivec2(floor(at));
	vec2 f = at - floor(at);
	ivec2 last = size - 1;
	float a = texelFetch(route_distance, clamp(base, ivec2(0), last), 0).r;
	float b = texelFetch(route_distance, clamp(base + ivec2(1, 0), ivec2(0), last), 0).r;
	float c = texelFetch(route_distance, clamp(base + ivec2(0, 1), ivec2(0), last), 0).r;
	float d = texelFetch(route_distance, clamp(base + ivec2(1, 1), ivec2(0), last), 0).r;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

struct Floor {
	float core;    // the worn road surface
	float rut;     // the two wheel ruts within it
	float crown;   // the grown-over strip between the ruts
	float verge;   // the ragged, overgrown band along each edge
	float tuft;    // moss and grass reaching in over the road's edge
	float forest;  // the woodland's reach
	float rock;    // the rocks' reach
	float contact; // occlusion round every base
	float bank;    // the river's banks
	float wet;     // puddles, wet ruts and the waterline
	float puddle;  // standing water
	float paving;  // the gateway's stone apron
	float scarp;   // a steep face
};

Floor floor_at(vec2 p, float height, vec3 normal) {
	Floor f;
	vec2 uv = (p - world_bounds.xy) / world_bounds.zw;
	float d = floor_route(uv);
	vec3 reach = texture(fields, (p - fields_origin) / fields_size).rgb;
	// The edge wanders at three scales, so the road's line is ragged, never a
	// ruled curve: shoulders bitten out, and grown in.
	float edge = (floor_noise(p * 1.3) - 0.5) * 0.24 + (floor_noise(p * 4.1 + 3.0) - 0.5) * 0.11
		+ (floor_noise(p * 11.0 + 9.0) - 0.5) * 0.05;
	float width = 0.64 + (floor_noise(p * 0.55 + 21.0) - 0.5) * 0.18;
	float worn = d + edge;
	f.core = 1.0 - smoothstep(width - 0.05, width + 0.05, worn);
	f.verge = (1.0 - smoothstep(width + 0.1, width + 0.75 + floor_noise(p * 0.9) * 0.35, worn)) * (1.0 - f.core);
	f.tuft = smoothstep(0.58, 0.74, floor_noise(p * 3.3 + 5.0)) * smoothstep(width - 0.32, width, worn) * f.core;
	// Two ruts about a cart's track apart, wandering a little, deep in
	// stretches and worn out in others; a crown between.
	float track = abs(d - 0.31 - (floor_noise(p * 0.8 + 41.0) - 0.5) * 0.1);
	float worn_in = smoothstep(0.25, 0.65, floor_noise(p * 0.37 + 77.0));
	f.rut = (1.0 - smoothstep(0.04, 0.2, track)) * f.core * worn_in;
	f.crown = (1.0 - smoothstep(0.07, 0.2, d)) * f.core
		* smoothstep(0.42, 0.66, floor_noise(p * 2.2 + 17.0));
	f.forest = 1.0 - exp(-reach.r * 3.0);
	f.rock = 1.0 - exp(-reach.g * 3.0);
	f.contact = clamp(reach.b, 0.0, 1.0);
	float wander = sin(p.y * 0.19) * 1.4 + sin(p.y * 0.61) * 0.3;
	float from_water = min(abs(p.x - river_cuts.x - wander), abs(p.x - river_cuts.y - wander)) / channel;
	f.bank = 1.0 - smoothstep(2.5, 5.0, from_water);
	float waterline = (1.0 - smoothstep(river_level - 0.08, river_level + 0.3, height)) * f.bank;
	// Water stands in the ruts' low stretches, spilling over their edges, and
	// in the road's hollows, each pool ragged at its rim. The hollows are
	// layered noise, turned off the noise's grid: one value noise cut at a
	// level takes the grid's square corners, and its pools read as slabs. The
	// ground rises to every base (the contact field), so no standing water, wet
	// rut or wet bank darkens the ground round a waystone, a stone or a trunk.
	vec2 q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p;
	float rim = (floor_noise(q * 5.3 + 8.0) - 0.5) * 0.14;
	float low = floor_fbm(q * 0.9 + 3.0) + rim;
	float drained = 1.0 - smoothstep(0.05, 0.2, f.contact);
	f.puddle = (1.0 - smoothstep(0.1, 0.3, track)) * f.core * smoothstep(0.62, 0.74, low);
	f.puddle = max(f.puddle, f.core * smoothstep(0.74, 0.84, floor_fbm(q * 0.45 + 61.0) + rim));
	f.puddle *= drained;
	f.rut *= 0.35 + 0.65 * drained;
	f.wet = max(max(f.puddle, f.rut * 0.55), waterline) * drained;
	f.paving = (1.0 - smoothstep(1.3, 3.8, distance(p, gateway_position))) * f.core;
	f.scarp = smoothstep(0.1, 0.5, 1.0 - abs(normal.y));
	return f;
}

// The lamps' light falling on `at` with normal `normal` (Godot's omni model,
// energy and colour aside), and the phase of the lamp that gives the most.
vec2 floor_pools(vec3 at, vec3 normal) {
	float total = 0.0;
	float most = 0.0;
	float phase = 0.0;
	float inverse_range = 1.0 / pool_range;
	for (int i = 0; i < lamp_count; i++) {
		vec3 to_lamp = lamps[i].xyz - at;
		float distance_m = length(to_lamp);
		float fade = distance_m * inverse_range;
		fade *= fade;
		fade *= fade;
		fade = max(1.0 - fade, 0.0);
		float light = fade * fade * pow(max(distance_m, 0.0001), -pool_decay)
			* max(dot(normal, to_lamp / max(distance_m, 0.0001)), 0.0);
		total += light;
		if (light > most) {
			most = light;
			phase = floor_lamp_phase(lamps[i].xz);
		}
	}
	return vec2(total * pool_energy, phase);
}
