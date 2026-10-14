shader_type canvas_item;
// MYTHIC EXAMPLE 1 — working label "A Lantern with No Flame" (the Usurper's
// Gate item; not a designed card). Story: cold glass, no wick. The art sits
// deep in its window (parallax); lean the card UP toward you and the flame
// that is not there surfaces in the middle of the picture, warming the glass
// round it; embers drift in front. Toolkit: window + reveal + motes + grade.
#include "res://research/holo/shaders/holo_common.gdshaderinc"
#include "res://research/holo/shaders/mythic_toolkit.gdshaderinc"

uniform sampler2D art_tex : filter_linear_mipmap, repeat_disable;
uniform vec4 art_win = vec4(0.0, 0.0, 1.0, 1.0);

const float DEPTH_PX = 6.0;
const vec2 FLAME_AT = vec2(0.50, 0.52);   // in the window
const float FLAME_SIZE = 26.0;            // card px

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	float win = holo_art(cp);
	vec2 local = myth_local(cp);
	float wall;
	vec2 l = myth_window(local, DEPTH_PX, 1.10, wall);
	vec3 art = myth_art(art_tex, art_win, l);
	// cold until revealed: the picture is drained of warmth
	float rv = myth_reveal(vec2(0.0, -1.0), 0.25, 0.85);
	float cold = holo_luma(art);
	art = mix(vec3(cold) * vec3(0.78, 0.86, 1.0), art, 0.35 + 0.65 * rv);
	vec2 fp = ((l - FLAME_AT) * HOLO_ART.zw) / FLAME_SIZE;
	float fl = motif_flame(vec2(fp.x, fp.y * 1.0));
	float flicker = 0.85 + 0.15 * sin(dot(tilt, vec2(9.0, 7.0)));
	vec3 flame = mix(vec3(1.0, 0.45, 0.12), vec3(1.0, 0.92, 0.6), smoothstep(0.2, 1.0, fl));
	float halo = exp(-dot(fp, fp) * 1.2) * rv;
	art = holo_screen(art, vec3(1.0, 0.6, 0.25) * halo * 0.55);
	art = holo_screen(art, flame * fl * rv * flicker);
	art *= 1.0 - 0.6 * wall;
	float m = myth_motes(cp, 8.0, 0.18, -5.0) * win;
	art = holo_screen(art, vec3(1.0, 0.62, 0.30) * m * (0.25 + 0.75 * rv));
	vec3 col = myth_grade(base.rgb, cp, face);
	col = mix(col, art, win);
	COLOR = vec4(mix(base.rgb, col, face), base.a);
}
