shader_type canvas_item;
// FRONT, SPECIAL (curses and statuses): "oil" (the owner's pick, 14 Oct 2026).
// The one finish that takes light away. A thin film of tar-iridescence crawls
// over the whole face as it tilts, coloured only in the darks (where a curse
// lives) and dulling the lights, so the card reads as tainted rather than
// precious.
#include "res://presentation/cards/holo/holo_common.gdshaderinc"

const float SCALE_PX = 34.0;
const float GAIN = 1.1;
const float STRENGTH = 0.34;
const float DULL = 0.22;
// The crystal's glint: a faint tar-iridescent band, as dull as the finish.
const float GEM_GLINT = 0.16;
const float GEM_BAND = 0.34;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	vec2 p = cp / SCALE_PX + tilt * vec2(0.35, 0.30);
	float n = holo_noise(p) * 0.6 + holo_noise(p * 2.1 + 3.3) * 0.3 + holo_noise(p * 4.3 - 1.7) * 0.1;
	// thin film: hue from thickness, which the tilt (path length) shifts
	float film = n * 1.6 + dot(tilt, vec2(0.55, 0.40)) * GAIN;
	vec3 iri = holo_rainbow(film) * vec3(0.55, 0.75, 0.85);
	float lum = holo_luma(base.rgb);
	float dark = 1.0 - smoothstep(0.10, 0.55, lum);
	float pool = smoothstep(0.48, 0.72, n);
	vec3 col = base.rgb * (1.0 - DULL * (1.0 - dark));
	float plate = smoothstep(96.0, 104.0, cp.y) * 0.6;
	col += iri * STRENGTH * dark * (0.08 + 0.92 * pool) * (1.0 - plate);
	float gb = exp(-pow((holo_gem_along(cp, vec2(1.0, 1.0)) - dot(tilt, vec2(0.55, 0.4))) / GEM_BAND, 2.0));
	vec3 gem = holo_rainbow(film) * vec3(0.55, 0.75, 0.85) * GEM_GLINT * gb;
	COLOR = vec4(holo_gem_keep(mix(base.rgb, col, face), base.rgb, cp, gem), base.a);
}
