shader_type spatial;
// The woodland's shadows in the floor's bake (`floor_stage.gd`): each plant's
// own impostor silhouette (`impostor_atlas.gd`) on an upright card turned to
// face the key light, cut out at its coverage, drawn into the shadow map only.
// The bake's soft filter turns the gaps between leaves into dappled light.
// Per instance: INSTANCE_CUSTOM the tile's rect on its page, the page (the
// atlas's layer) added to its top (`ImpostorAtlas.custom`); COLOR.a how far
// down the picture the plant's base sits (the card shows the picture above it).
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2DArray atlas_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform float scissor = 0.5;
varying vec4 tile_uv;
varying flat float tile_layer;
varying float base_v;

void vertex() {
	tile_layer = floor(INSTANCE_CUSTOM.y);
	tile_uv = vec4(INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.y - tile_layer, INSTANCE_CUSTOM.zw);
	base_v = COLOR.a;
}

void fragment() {
	vec2 uv = tile_uv.xy + vec2(UV.x, UV.y * base_v) * tile_uv.zw;
	ALBEDO = vec3(0.0);
	ALPHA = texture(atlas_albedo, vec3(uv, tile_layer)).a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
}
