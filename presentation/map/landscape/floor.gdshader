shader_type spatial;
// Act I's floor (R3.2, issue #660), drawn from its bake (`floor_bake.gd`): the
// lit forest floor as a world-space picture taken from straight above, 16
// texels a metre, its key shadows, contact occlusion and lamp pools already in
// it. Unshaded and receiving no live shadow: one sample of the picture, one of
// its mask (`floor_mask.gdshader`), one of a tiled micro detail. The detail's
// grain is the gravel: deepest where the floor is grey grit (the road, ash
// soil, rock grit) and at the Close stop, where a texel of the picture spans
// several pixels. What stays live: the pools flicker with their own lamp's
// flame (mask r and g, the flame's phase and wave), standing water (mask b)
// lies dark and glints, and the pilgrim's carried light warms the road round
// it. The global `land_motion` 0 (Reduce Motion; `LandMotion`) holds the pools
// steady and puts the glints out.
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
uniform sampler2D lit : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D mask : filter_linear, repeat_disable;
// r: grain; g: where a glint can catch; b: its phase.
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform vec4 world_bounds = vec4(-48.0, -30.0, 96.0, 60.0);
// The bake keeps half the land's light (`FloorBake.EXPOSURE`).
uniform float decode = 2.0;
uniform float detail_metres = 10.0;
uniform float detail_depth = 0.42;
// The grain added where the floor is grey grit: its colour's chroma (0 grey,
// 1 pure) from full grit (x) to none (y); a pool's warmth lifts both.
uniform float grit_depth = 0.38;
uniform vec2 grit_chroma = vec2(0.32, 0.55);
// The camera's view height (metres; the ground's metres a pixel across times
// the view's pixels down) under which the grain deepens (y), and at which it
// is deepest (x): the Close stop is 0.68 of a Journey's 19.2, so Journey and
// Whole act keep their grain.
uniform vec2 close_heights = vec2(13.6, 16.5);
uniform float close_gain = 0.9;
// The flame's flicker (`flame.gdshader`): 0.9 + 0.1 sin(9 t + 40 phase).
uniform float flicker_depth = 0.11;
uniform vec3 glint_colour : source_color = vec3(1.0, 0.86, 0.66);
uniform float glint_strength = 1.1;
// Standing water is the ground it lies on, darker: never a colour of its own.
uniform float water_dark = 0.7;
// The pilgrim's carried light: xz where it stands, its reach (0: none), and
// its colour times its strength.
uniform vec3 walker = vec3(0.0, 0.0, 0.0);
uniform vec3 walker_light = vec3(0.0);
global uniform float land_motion;
varying vec2 at;

void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv = (at - world_bounds.xy) / world_bounds.zw;
	vec3 colour = texture(lit, uv).rgb * decode;
	vec3 kept = texture(mask, uv).rgb;
	vec3 fine = texture(detail, at / detail_metres).rgb;
	float most = max(max(colour.r, colour.g), colour.b);
	float chroma = (most - min(min(colour.r, colour.g), colour.b)) / max(most, 0.02);
	float grit = 1.0 - smoothstep(grit_chroma.x + kept.r * 0.3, grit_chroma.y + kept.r * 0.3, chroma);
	float close = 1.0 - smoothstep(close_heights.x, close_heights.y, length(dFdx(at)) * VIEWPORT_SIZE.y);
	float depth = (detail_depth + grit_depth * grit) * (1.0 + close_gain * close);
	colour *= max(1.0 + (fine.r - 0.5) * 2.0 * depth * (1.0 - kept.b * 0.6), 0.0);
	float water = smoothstep(0.6, 0.95, kept.b);
	colour *= mix(1.0, water_dark, water);
	colour *= 1.0 + kept.r * flicker_depth * sin(TIME * 9.0 + kept.g * 40.0) * land_motion;
	float twinkle = max(sin(TIME * 2.3 + fine.b * 6.2832), 0.0);
	colour += glint_colour * (glint_strength * smoothstep(0.72, 0.95, fine.g) * kept.b
		* twinkle * twinkle * land_motion * (0.25 + kept.r));
	if (walker.z > 0.0) {
		float reach = 1.0 - clamp(distance(at, walker.xy) / walker.z, 0.0, 1.0);
		colour *= 1.0 + walker_light * reach * reach;
	}
	ALBEDO = colour;
}
