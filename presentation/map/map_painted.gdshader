shader_type spatial;
render_mode cull_back, ambient_light_disabled, specular_disabled;

// The Studio atlas supplies stone, bark and glass identity. One material per
// active mesh, shared by its instances; one shared key light for the map.
uniform sampler2D surface_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 sun = vec3(-0.35, 0.78, 0.52);
uniform vec3 band_shade : source_color = vec3(0.32, 0.39, 0.48);
uniform vec3 band_key : source_color = vec3(0.88, 0.91, 0.84);
uniform float exposure = 1.25;
varying vec3 world_n;

void vertex() {
	world_n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 pigment = texture(surface_tex, UV).rgb;
	float light = dot(normalize(world_n), normalize(sun)) * 0.5 + 0.5;
	float band = floor(light * 4.0) / 3.0;
	vec3 illumination = mix(band_shade, band_key, clamp(band, 0.0, 1.0));
	ALBEDO = pigment * illumination * exposure;
}

// One shared directional shadow map anchors the whole diorama. Lighting bands
// stay art-directed; native attenuation supplies only inter-object occlusion.
void light() {
	DIFFUSE_LIGHT += vec3(0.38 + ATTENUATION * 0.62);
}
