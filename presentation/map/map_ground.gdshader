shader_type spatial;
render_mode cull_back, ambient_light_disabled, specular_disabled;

// A single top-down surface lookup; props keep their own imported UV atlases.
uniform sampler2D surface_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D grade : filter_linear, repeat_disable, source_color;
uniform vec4 grade_rect = vec4(-64.0, -64.0, 128.0, 128.0);
uniform vec3 sun = vec3(-0.35, 0.78, 0.52);
uniform vec3 band_shade : source_color = vec3(0.14, 0.16, 0.28);
uniform vec3 band_key : source_color = vec3(0.96, 0.88, 0.72);
uniform int bands = 3;
uniform float contact = 0.55;
uniform float surface_value = 0.420;
uniform float tex_mean = 0.5;
uniform int tex_stop = 1;
const float TEX_STOPS[4] = {0.035, 0.070, 0.140, 0.280};

// The field is rebuilt only when the canonical route or accepted scenery changes.
uniform bool landscape_enabled = false;
uniform sampler2D landscape : filter_linear, repeat_disable;
uniform vec3 land_light : source_color;
uniform vec3 land_dark : source_color;
uniform vec3 basin : source_color;
uniform float wetness = 0.0;
varying vec3 world_pos;
varying vec3 world_n;

vec3 ramp(float nl) {
	float n = float(max(bands, 2));
	float q = min(floor(clamp(nl, 0.0, 1.0) * n), n - 1.0) / (n - 1.0);
	return mix(band_shade, band_key, q);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (landscape_enabled) {
		vec4 field = texture(landscape, (world_pos.xz + vec2(64.0, 48.0)) / vec2(128.0, 96.0));
		// Gentle continuous relief stays below the road; actual prop contacts
		// flatten it. No disconnected pedestals beneath individual instances.
		VERTEX.y -= smoothstep(1.0, 7.0, field.r * 12.0) *
			(0.15 + field.b * 0.30) * smoothstep(0.65, 1.0, field.a);
		world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
	world_n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	if (landscape_enabled) {
		vec4 field = texture(landscape, (world_pos.xz + vec2(64.0, 48.0)) / vec2(128.0, 96.0));
		float grain = texture(surface_tex, world_pos.xz * 0.21).r / max(tex_mean, 0.01);
		float path = 1.0 - smoothstep(0.8, 3.0 + field.b, field.r * 12.0);
		float clearing = 0.30 + smoothstep(0.25, 0.73, field.g + path * 0.18) * 0.55;
		vec3 earth = mix(land_dark, land_light, clearing);
		earth *= clamp(grain, 0.40, 1.65);
		float silt = smoothstep(0.45, 0.75, field.b) * (1.0 - path) * 0.28;
		earth = mix(earth, basin, silt);
		float pool = smoothstep(0.50, 0.64, field.g) * (1.0 - path) *
			smoothstep(0.82, 1.0, field.a) * wetness;
		earth = mix(earth, basin * (0.85 + field.b * 0.25), pool);
		earth += land_light * pool * (1.0 - pool) * 0.18;
		ALBEDO = earth * field.a * (surface_value / 0.420);
	} else {
		// Asset-free and missing-layout fallback also serves the legacy proxy.
		vec3 albedo = texture(surface_tex, world_pos.xz * TEX_STOPS[clamp(tex_stop, 0, 3)]).rgb
			* (surface_value / max(tex_mean, 1e-4));
		vec4 g = texture(grade, (world_pos.xz - grade_rect.xy) / grade_rect.zw);
		float nl = dot(normalize(world_n), normalize(sun)) * 0.5 + 0.5;
		ALBEDO = albedo * ramp(nl - (1.0 - g.a) * contact) * g.rgb;
	}
}

// One shared directional shadow map anchors the whole diorama. Lighting bands
// stay art-directed; native attenuation supplies only inter-object occlusion.
void light() {
	DIFFUSE_LIGHT += vec3(0.38 + ATTENUATION * 0.62);
}
