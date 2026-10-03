shader_type canvas_item;
// The journey land's tilt-shift (`MapTiltShift`): the stage's picture, sharp
// inside `band` (top and bottom as a share of the height) and blurred beyond
// it, reaching the full `radius_texels` (stage texels) `feather` further out.
// Thirteen taps on a disc; rows inside the band read one.
uniform vec2 band = vec2(0.0, 1.0);
uniform float feather = 0.16;
uniform float radius_texels = 0.0;
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
	COLOR = colour;
}
