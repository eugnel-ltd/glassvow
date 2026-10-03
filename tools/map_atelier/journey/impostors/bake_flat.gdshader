shader_type spatial;
// Impostor bake pass (`bake_impostors.gd`): a kit surface's albedo (mode 0),
// its world-space normal (mode 1) or its distance from the camera in metres
// over 32 (mode 2), unshaded, cut out as the map's foliage is. `recolour`
// (alpha 1) repaints the albedo in its hue at the surface's own luminance,
// times `recolour_gain`.
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform float scissor = 0.3;
uniform int mode = 0;
uniform vec4 recolour : source_color = vec4(0.0);
uniform float recolour_gain = 1.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 t = use_tex ? texture(tex, UV) : vec4(1.0);
	vec3 base = albedo.rgb * t.rgb;
	if (recolour.a > 0.5) {
		base = recolour.rgb * (dot(base, LUMA) / max(dot(recolour.rgb, LUMA), 1e-4)) * recolour_gain;
	}
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	ALBEDO = mode == 0 ? base : (mode == 1 ? (nw * 0.5 + 0.5) : vec3(-VERTEX.z / 32.0));
	ALPHA = albedo.a * t.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
}
