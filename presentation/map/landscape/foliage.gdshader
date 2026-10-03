shader_type spatial;
// The kit's cut-out foliage exactly as `asset_surfaces.gd` prepared it as a
// StandardMaterial3D (shared painted source, scissor at 0.3, alpha to coverage,
// both faces, roughness 0.96, Burley diffuse, Schlick-GGX specular), now
// swaying (R2 step 3). Every vertex moves with its height above the model's
// ground, so trunks and bases stay put; a slow gust and a quicker flutter, in
// phase by where the plant stands. The shadow pass runs this vertex function
// too, so shadows sway with their crowns. The global `land_motion` 0 holds it
// still (Reduce Motion; `LandMotion`).
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, alpha_to_coverage;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform ivec2 albedo_texture_size = ivec2(1);
uniform float roughness = 0.96;
uniform float specular = 0.5;
uniform float metallic = 0.0;
uniform float alpha_scissor_threshold = 0.3;
uniform float alpha_antialiasing_edge = 0.3;
// Metres of sway per metre of height at the gust's peak.
uniform float sway = 0.014;
global uniform float land_motion;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.37 + origin.z * 0.23;
	float height = max(VERTEX.y, 0.0);
	float gust = sin(TIME * 1.1 + phase) * 0.7 + sin(TIME * 2.3 + phase * 1.7) * 0.3;
	float flutter = sin(TIME * 5.3 + dot(VERTEX, vec3(3.1, 1.7, 2.3))) * 0.2 * min(height, 1.0);
	VERTEX.xz += vec2(0.8, 0.45) * (gust + flutter) * height * sway * land_motion;
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	METALLIC = metallic;
	SPECULAR = specular;
	ROUGHNESS = roughness;
	ALPHA *= albedo.a * albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ALPHA_ANTIALIASING_EDGE = alpha_antialiasing_edge;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(albedo_texture_size);
}
