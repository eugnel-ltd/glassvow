shader_type canvas_item;
// BACK DIRECTION B2, "lit panes": the painting is already a leaded window, so
// the hologram lives IN its glass. The bright panes carry the diffraction and
// the dark leading does not; a slow field of pane "leans" (a smooth normal
// field at the back's own pane scale) lights some panes and drops others as
// it tilts, each passing through the back's own hue range. Per-back knobs.
#include "res://research/holo/shaders/holo_common.gdshaderinc"
#include "res://research/holo/shaders/back_knobs.gdshaderinc"

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	float lum = holo_luma(base.rgb);
	float glass = smoothstep(0.10, 0.45, lum);       // the leading is dark
	vec2 p = cp / (18.0 * scale);
	vec2 n = vec2(holo_noise(p), holo_noise(p + 7.3)) * 2.0 - 1.0;
	n *= 0.85;
	vec2 rel = tilt - n;
	float lit = exp(-dot(rel, rel) * 5.0);
	float b = back_band(cp);
	vec3 rb = back_spectrum(b * 1.6 + holo_noise(p * 0.5 + 2.0) * 0.6 + dot(tilt, vec2(0.5, 0.35)));
	vec3 add = rb * (0.12 + 0.88 * lit) * glass * strength;
	vec3 col = holo_screen(base.rgb, add);
	// the leading itself keeps a cool metal glint that runs with the tilt
	float lead = 1.0 - smoothstep(0.04, 0.12, lum);
	float run = exp(-pow((b - back_slide(cp)) * 3.0, 2.0));
	col += vec3(0.45, 0.48, 0.55) * lead * run * 0.35 * strength;
	COLOR = vec4(mix(base.rgb, col, face), base.a);
}
