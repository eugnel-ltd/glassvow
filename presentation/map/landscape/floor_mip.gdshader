shader_type canvas_item;
// One level of the floor bake's mip chain (`floor_bake.gd`): each texel the
// mean of the four below it, averaged as light (the picture holds sRGB), so
// the land does not darken as the view widens. A level's last row or column
// repeats when the level below is odd.
render_mode blend_disabled;
uniform sampler2D source : filter_nearest;
uniform ivec2 source_size = ivec2(2);

vec3 as_light(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 as_stored(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

void fragment() {
	ivec2 at = ivec2(FRAGCOORD.xy) * 2;
	ivec2 last = source_size - 1;
	vec3 sum = as_light(texelFetch(source, min(at, last), 0).rgb)
		+ as_light(texelFetch(source, min(at + ivec2(1, 0), last), 0).rgb)
		+ as_light(texelFetch(source, min(at + ivec2(0, 1), last), 0).rgb)
		+ as_light(texelFetch(source, min(at + ivec2(1, 1), last), 0).rgb);
	COLOR = vec4(as_stored(sum * 0.25), 1.0);
}
