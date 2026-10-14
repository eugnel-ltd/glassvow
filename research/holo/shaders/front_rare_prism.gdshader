shader_type canvas_item;
// FRONT, RARE candidate R2, "prism caustic": light through a prism lands on
// the art. A broad bright band crosses the window with the lean and splits
// into its spectrum at its edges (red leading, violet trailing), and two or
// three soft caustic pools of colour drift inside it. Smooth throughout: no
// line ever crosses the art. The window's rim stays clean.
#include "res://research/holo/shaders/holo_common.gdshaderinc"

const float BAND_W = 0.13;        // band half-width, in window widths
const float SPLIT = 0.10;         // how far the spectrum fans out
const float BAND = 0.62;
const float POOLS = 0.30;
const vec2 REST = vec2(0.30, -0.22);   // the room light: a band shows at rest

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	float win = holo_art(cp) * face;
	vec2 local = (cp - HOLO_ART.xy) / HOLO_ART.zw;
	vec2 lt = tilt + REST;
	vec2 dir = normalize(vec2(1.0, 0.45));
	float along = dot(local - 0.5, dir) * 1.6;
	float centre = lt.x * 0.55 + lt.y * 0.30;
	// the band, dispersed: across its width the light runs red to violet,
	// as a prism throws it, brightest in the middle of the spectrum
	float x = (along - centre) / BAND_W;
	float env = exp(-x * x * 0.9);
	vec3 light = holo_rainbow(0.62 - x * 0.22) * env * (0.75 + 0.25 * exp(-x * x * 4.0));
	vec3 spec = vec3(env);
	// caustic pools: soft, drifting with the lean
	vec2 q = local * vec2(2.0, 1.2) + lt * 0.4;
	float pool = smoothstep(0.62, 0.85, holo_noise(q * 2.2 + 3.0));
	vec3 pool_col = holo_rainbow(holo_noise(q * 1.3) * 0.8 + dot(lt, vec2(0.5, 0.3)));
	float lum = holo_luma(base.rgb);
	float through = 0.45 + 0.55 * smoothstep(0.05, 0.55, lum);
	vec3 col = holo_screen(base.rgb, light * BAND * through);
	col = holo_screen(col, pool_col * pool * POOLS * (0.4 + 0.6 * spec.g) * through);
	COLOR = vec4(mix(base.rgb, col, win), base.a);
}
