// The map's display (`MapScene`), shared by its two shaders: the stage's
// picture, or the tilt-shift's view of it, upscaled to the screen, with the
// film grain (`MapFilmGrain`) folded in. The grain is one fetch per display
// pixel from a 2048 px white-noise texture, offset by `jitter` (whole pixels,
// moved by the script every TransitionLayer.GRAIN_STEP) and wrapped by `wrap`
// (its side less one), overlaid at `amount`. Nothing is worked out per pixel
// that is the same for every pixel: the A12 is bound by shader arithmetic at
// the map's rest. COLOR arrives as the picture times the screen's modulate.
// `amount` 0 (Reduce Motion, or the TransitionLayer's grain on screen) leaves
// the picture untouched.
uniform sampler2D noise : filter_nearest;
uniform float amount = 0.0;
uniform ivec2 jitter = ivec2(0);
uniform int wrap = 2047;

void fragment() {
	vec4 picture = COLOR;
	if (amount > 0.0) {
		float g = texelFetch(noise, (ivec2(FRAGCOORD.xy) + jitter) & ivec2(wrap), 0).r;
		vec3 base = picture.rgb;
		vec3 over = mix(2.0 * base * g, 1.0 - 2.0 * (1.0 - base) * (1.0 - g),
			step(vec3(0.5), base));
		picture.rgb = mix(base, over, amount);
	}
	COLOR = picture;
}
