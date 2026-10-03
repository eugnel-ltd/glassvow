shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The map's display (`MapScene`): the stage's picture, or the tilt-shift's
// view of it, upscaled to the screen, with the film grain (`MapFilmGrain`)
// folded in. The grain is one fetch of a tiled white-noise texture per display
// pixel, moved by the whole-pixel `jumps`, one every `step_s` seconds, and
// overlaid at `amount`: the TransitionLayer grain's look without its copy of
// the screen. `amount` 0 (Reduce Motion) leaves the picture untouched.
uniform sampler2D noise : filter_nearest, repeat_enable;
uniform float amount = 0.0;
uniform float step_s = 0.1125;
uniform vec2 jumps[8];

void fragment() {
	vec3 base = texture(TEXTURE, UV).rgb;
	if (amount > 0.0) {
		vec2 jitter = jumps[int(mod(floor(TIME / step_s), 8.0))];
		vec2 tile = vec2(textureSize(noise, 0));
		float g = texture(noise, (floor(FRAGCOORD.xy) + jitter + 0.5) / tile).r;
		vec3 over = mix(2.0 * base * g, 1.0 - 2.0 * (1.0 - base) * (1.0 - g),
			step(vec3(0.5), base));
		base = mix(base, over, amount);
	}
	COLOR = vec4(base, 1.0);
}
