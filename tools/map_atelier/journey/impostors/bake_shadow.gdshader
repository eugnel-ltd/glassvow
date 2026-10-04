shader_type spatial;
// Impostor bake pass (`bake_impostors.gd`): how much of the map's key light
// reaches each visible fragment through the plant's own crown, white where lit.
render_mode cull_disabled, depth_draw_opaque, ambient_light_disabled, specular_disabled;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform float scissor = 0.3;

void fragment() {
	vec4 t = use_tex ? texture(tex, UV) : vec4(1.0);
	ALBEDO = vec3(1.0);
	ALPHA = albedo.a * t.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
}

void light() {
	DIFFUSE_LIGHT += vec3(ATTENUATION);
}
