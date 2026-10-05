shader_type spatial;
// The woodland's shadows in the floor's bake (`floor_stage.gd`): each plant's
// own impostor silhouette (`impostor_atlas.gd`) on an upright card turned to
// face the key light, cut out at its coverage, drawn into the shadow map only.
// The bake's soft filter turns the gaps between leaves into dappled light.
// Per instance: INSTANCE_CUSTOM the tile's atlas rect; COLOR.a how far down
// the picture the plant's base sits (the card shows the picture above it).
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D atlas_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform float scissor = 0.5;
varying vec4 tile_uv;
varying float base_v;

void vertex() {
	tile_uv = INSTANCE_CUSTOM;
	base_v = COLOR.a;
}

void fragment() {
	vec2 uv = tile_uv.xy + vec2(UV.x, UV.y * base_v) * tile_uv.zw;
	ALBEDO = vec3(0.0);
	ALPHA = texture(atlas_albedo, uv).a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
}
