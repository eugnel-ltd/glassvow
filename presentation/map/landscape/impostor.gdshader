shader_type spatial;
// Act I's woodland impostors (`impostor_wood.gd`): one card per plant, facing
// the journey camera, painted with the plant as baked from that direction
// (`tools/map_atelier/journey/impostors/`). The camera never turns and is orthographic at one
// pitch, so the card is the model's own picture at every zoom stop and pan.
// Lit by the land's key light through the baked world normal, with the
// plant's own crown shadow (and the dark of a leaf seen through a gap) as
// ambient occlusion. Cut out at the baked coverage; drawn nearest first, so
// depth rejects what the cards hide. Cards receive no shadows: opaque cones
// and eggs cast the woodland's shadows on the land.
//
// Per instance: INSTANCE_CUSTOM is the tile's atlas rect; COLOR.rgb a tint
// and COLOR.a where the model's base sits down the card (0 top, 1 bottom).
// The crowns sway with a slow gust that grows with height above the base; the
// global `land_motion` 0 holds them still (Reduce Motion; `LandMotion`).
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, shadows_disabled;
uniform sampler2D atlas_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D atlas_normal : filter_linear_mipmap, repeat_disable;
uniform float scissor = 0.5;
// Metres of sway per metre of height at the gust's peak: half the kit
// foliage's, so a card's crisp silhouette moves about as much of the wood as
// R2's meshes did (2.5% of woodland pixels in 0.6 s on the pad, against 2.8%).
uniform float sway = 0.006;
// The least of the key light a fully self-shadowed fragment keeps.
uniform float occlusion_floor = 0.12;
global uniform float land_motion;
varying vec4 tile_uv;
varying vec3 tint;

void vertex() {
	tile_uv = INSTANCE_CUSTOM;
	tint = COLOR.rgb;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.37 + origin.z * 0.23;
	float card_w = length(MODEL_MATRIX[0].xyz);
	float card_h = length(MODEL_MATRIX[1].xyz);
	// Metres above the model's base, up the picture plane.
	float above = max(COLOR.a - VERTEX.y, 0.0) * card_h;
	float gust = sin(TIME * 1.1 + phase) * 0.7 + sin(TIME * 2.3 + phase * 1.7) * 0.3;
	VERTEX.x += 0.8 * gust * above * sway * land_motion / max(card_w, 0.01);
}

void fragment() {
	vec2 uv = tile_uv.xy + clamp(UV, vec2(0.0), vec2(1.0)) * tile_uv.zw;
	vec4 a = texture(atlas_albedo, uv);
	vec4 n = texture(atlas_normal, uv);
	ALBEDO = a.rgb * tint;
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
	vec3 nw = normalize(n.rgb * 2.0 - 1.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	AO = mix(occlusion_floor, 1.0, n.a);
	AO_LIGHT_AFFECT = 1.0;
	ROUGHNESS = 0.96;
	SPECULAR = 0.5;
}
