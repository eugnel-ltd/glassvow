shader_type canvas_item;
// FRONT, RARE: "crackle glass". The art window is broken into shards of
// glass (a Voronoi of ~11 px panes), each a mirror with its own lean, so a
// few degrees of tilt light some shards and drop others, each in its own
// hue, with a slow rainbow band underneath. The frame stays quiet: the art is
// the jewel. Glassvow's own material, rather than a borrowed foil.
#include "res://research/holo/shaders/holo_common.gdshaderinc"

const float SHARD_PX = 11.0;
const float LEAN = 0.70;
const float LOBE = 7.0;
const float STRENGTH = 1.05;
const float BAND = 0.20;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float m = holo_face(cp) * holo_art(cp);
	vec2 g = cp / SHARD_PX;
	vec2 gi = floor(g);
	vec2 gf = fract(g);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 best = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 pt = o + holo_hash2(gi + o);
			float dd = length(pt - gf);
			if (dd < d1) { d2 = d1; d1 = dd; best = gi + o; }
			else if (dd < d2) { d2 = dd; }
		}
	}
	float crack = 1.0 - smoothstep(0.0, 0.07, d2 - d1);
	vec2 n = (holo_hash2(best + 9.1) - 0.5) * 2.0 * LEAN;
	vec2 rel = tilt - n;
	float lit = exp(-dot(rel, rel) * LOBE);
	vec3 rb = holo_rainbow(holo_hash(best) * 0.5 + dot(tilt, vec2(0.5, 0.35)));
	vec2 q = cp / HOLO_CARD;
	float band = exp(-pow((q.x + q.y * 0.6 - 0.8 - tilt.x * 0.5 - tilt.y * 0.3) * 3.0, 2.0));
	vec3 rb2 = holo_rainbow(q.x * 1.5 + tilt.x * 0.8);
	float lum = holo_luma(base.rgb);
	float through = 0.45 + 0.55 * smoothstep(0.05, 0.6, lum);
	vec3 add = (rb * lit * STRENGTH + rb2 * band * BAND) * through;
	vec3 col = holo_screen(base.rgb, add);
	col = holo_screen(col, vec3(pow(lit, 4.0) * 0.45));
	col = mix(col, col * 0.55 + vec3(0.85, 0.88, 0.95) * 0.35 * (0.3 + lit), crack * 0.8);
	COLOR = vec4(mix(base.rgb, col, m), base.a);
}
