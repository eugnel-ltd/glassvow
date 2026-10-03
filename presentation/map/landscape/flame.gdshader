shader_type spatial;
// The lanterns' flames: one MultiMesh of camera-facing cards, each playing the
// flipbook (flame-flipbook.png, 4x4 frames) at its own phase. Additive and
// unshaded. The card is pulled `lift` metres toward the camera so it draws
// over its own lantern's glass, while anything truly in front still hides it.
// The global `land_motion` 0 (Reduce Motion; `LandMotion`) holds each flame on
// one frame of its flipbook at a steady brightness.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform sampler2D flipbook : source_color, filter_linear_mipmap, repeat_disable;
uniform float frames_per_second = 12.0;
uniform float intensity = 2.4;
uniform float lift = 0.24;
global uniform float land_motion;
varying float phase;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	phase = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float width = length(MODEL_MATRIX[0].xyz);
	float height = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * width,
		INV_VIEW_MATRIX[1] * height, INV_VIEW_MATRIX[2], vec4(origin, 1.0));
	MODELVIEW_MATRIX[3].z += lift;
}

void fragment() {
	float frame = floor(mod(TIME * land_motion * frames_per_second + phase * 16.0, 16.0));
	vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0));
	vec4 flame = texture(flipbook, (cell + UV) * 0.25);
	float flicker = 0.9 + 0.1 * sin(TIME * 9.0 + phase * 40.0) * land_motion;
	ALBEDO = flame.rgb * intensity * flicker;
	ALPHA = flame.a;
}
