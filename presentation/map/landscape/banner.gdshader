shader_type spatial;
// The bridge banners' cloth (R2 step 3): the authored colour on both faces,
// and a slow travelling ripple that grows with the drop below the bar, so the
// bar holds still and the hem moves most. Phase by where the banner hangs.
// `motion` 0 holds it still (Reduce Motion; `LandMotion`).
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.9;
uniform float wave = 0.07;
uniform float motion = 1.0;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.53 + origin.z * 0.31;
	float hang = clamp(-VERTEX.y, 0.0, 2.0);
	float ripple = sin(TIME * 2.1 + VERTEX.x * 4.0 + hang * 3.2 + phase) * 0.75
		+ sin(TIME * 3.7 + hang * 5.0 + phase * 2.0) * 0.25;
	VERTEX.z += ripple * hang * wave * motion;
	VERTEX.x += sin(TIME * 0.9 + phase) * hang * hang * 0.02 * motion;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
}
