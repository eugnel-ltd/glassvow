shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The journey land's tilt-shift (`MapTiltShift`): the stage's picture, sharp
// inside `band` (top and bottom as a share of the height) and blurred beyond
// it, reaching the full `radius_texels` (stage texels) `feather` further out.
// Thirteen taps on a disc; rows inside the band read one. Drawn texel for
// texel at the stage's own size (`MapScene`), so it pays per stage texel, not
// per display pixel.
//
// The lens's depth (R3.6): the fixed camera looks down at 40 degrees, so the
// frame's top is the far land and its foot the near. The far land takes the
// golden haze of the owner's target, up to `haze` of `haze_colour` at the top
// edge and none below `haze_reach` of the height; the near land darkens by up
// to `near_shade` at the foot, from `near_reach` up. A few multiply-adds a
// texel, no fetch: the pass already exists, so the depth adds none.
uniform vec2 band = vec2(0.0, 1.0);
uniform float feather = 0.16;
uniform float radius_texels = 0.0;
uniform vec3 haze_colour : source_color = vec3(0.86, 0.68, 0.46);
uniform float haze = 0.0;
uniform float haze_reach = 0.45;
uniform float near_shade = 0.0;
uniform float near_reach = 0.3;
const vec2 DISC[12] = vec2[](
	vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457),
	vec2(-0.203, 0.621), vec2(0.962, -0.195), vec2(0.473, -0.480),
	vec2(0.519, 0.767), vec2(0.185, -0.893), vec2(0.507, 0.064),
	vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));

void fragment() {
	float outside = max(band.x - UV.y, UV.y - band.y);
	float radius = radius_texels * smoothstep(0.0, feather, outside);
	vec4 colour = texture(TEXTURE, UV);
	if (radius > 0.3) {
		vec2 step = TEXTURE_PIXEL_SIZE * radius;
		for (int i = 0; i < 12; i++) {
			colour += texture(TEXTURE, UV + DISC[i] * step);
		}
		colour /= 13.0;
	}
	float far = max(1.0 - UV.y / haze_reach, 0.0);
	float near = max(1.0 - (1.0 - UV.y) / near_reach, 0.0);
	colour.rgb = mix(colour.rgb, haze_colour, haze * far * far);
	colour.rgb *= 1.0 - near_shade * near * near;
	COLOR = colour;
}
