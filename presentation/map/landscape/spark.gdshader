shader_type spatial;
// One mote in the air (`air.gd`): a soft dot facing the camera, its colour and
// fade from the particle. `intensity` above 1 lets embers reach the bloom.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float intensity = 1.0;

void vertex() {
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size,
		INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float edge = 1.0 - smoothstep(0.35, 1.0, length(UV * 2.0 - 1.0));
	ALBEDO = COLOR.rgb * intensity;
	ALPHA = COLOR.a * edge;
}
