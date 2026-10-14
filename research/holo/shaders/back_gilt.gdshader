shader_type canvas_item;
// BACK DIRECTION B3, "holo gilt": the painting's own gold (its frame, its
// medallions, the eclipse's rays) becomes the hologram: a fine grating foil
// with a high tilt gain, so a few degrees runs it through the spectrum and
// back to gold. The coloured glass is left exactly as painted. Per-back knobs
// set how gold is found and how the grating runs over each painting.
#include "res://research/holo/shaders/holo_common.gdshaderinc"
#include "res://research/holo/shaders/back_knobs.gdshaderinc"

uniform float gold_hue = 0.11;      // the painting's gold, as a hue 0..1
uniform float gold_tol = 0.06;
uniform float env_only = 0.0;      // 1: the foil shows only where the band is

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	vec3 hsv = rgb2hsv(base.rgb);
	float hd = abs(fract(hsv.x - gold_hue + 0.5) - 0.5);
	float gold = (1.0 - smoothstep(gold_tol, gold_tol * 1.8, hd))
		* smoothstep(0.30, 0.55, hsv.y) * smoothstep(0.35, 0.65, hsv.z);
	float b = back_band(cp);
	float g = b * 9.0 / scale + dot(tilt, vec2(1.0, 0.7)) * 1.5;
	vec3 rb = back_spectrum(g);
	float env = exp(-pow((b - back_slide(cp)) * 2.2, 2.0));
	float groove = 0.75 + 0.25 * cos(dot(cp, vec2(0.9, 0.5)) * 1.7 + tilt.x * 6.0);
	vec3 foil = mix(base.rgb, rb * (0.6 + 0.6 * hsv.z) * groove, strength * (0.35 + 0.65 * env));
	foil += vec3(1.0, 0.95, 0.85) * pow(env, 6.0) * 0.35 * strength;
	vec3 col = mix(base.rgb, foil, gold * mix(1.0, smoothstep(0.15, 0.7, env), env_only));
	COLOR = vec4(mix(base.rgb, col, face), base.a);
}
