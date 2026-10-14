shader_type canvas_item;
// BACK DIRECTION B1, "veil": a diffraction veil over the whole painting whose
// band follows the painting's own geometry (the lancets' verticals, the
// rose's rings, the eclipse's sweep round its sun), strongest through the
// light glass, with a glare pool and a fine glitter. Per-back knobs.
#include "res://research/holo/shaders/holo_common.gdshaderinc"
#include "res://research/holo/shaders/back_knobs.gdshaderinc"

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	vec2 q = cp / HOLO_CARD;
	float b = back_band(cp);
	float slide = back_slide(cp);
	float d = band_mode == 2 ? abs(fract(b - slide + 0.5) - 0.5) : abs(b - slide);
	float env = exp(-pow(d * 2.4 / scale, 2.0));
	vec3 rb = back_spectrum(b * 2.4 / scale + slide * 1.8);
	float lum = holo_luma(base.rgb);
	float through = 0.25 + 0.75 * smoothstep(0.06, 0.55, lum);
	float w = (0.15 + 0.85 * env) * through * strength;
	vec2 cell = floor(cp / 2.5);
	vec2 h = holo_hash2(cell);
	float flash = pow(max(0.0, cos(6.2831 * (dot(h - 0.5, vec2(3.1, 2.7)) + tilt.x * 0.9 - tilt.y * 0.7))), 60.0);
	flash *= step(0.62, h.x) * (0.3 + 0.7 * env) * through;
	vec2 ga = vec2(0.5) + tilt * vec2(0.45, 0.40);
	vec2 gd = (q - ga) * vec2(1.6, 1.2);
	float glare = exp(-dot(gd, gd) * 3.0);
	vec3 col = holo_screen(base.rgb, rb * w);
	col += flash * 0.5 * mix(vec3(1.0), rb, 0.5);
	col = holo_screen(col, vec3(glare * 0.20));
	COLOR = vec4(mix(base.rgb, col, face), base.a);
}
