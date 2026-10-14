shader_type canvas_item;
// MYTHIC EXAMPLE 1 — working label "A Lantern with No Flame" (the Usurper's
// Gate item; not a designed card). Story: cold glass, no wick. At rest the
// picture is drained cold and recessed, with only a faint blue glimmer where
// a wick would be. Lean the card TOWARD you past a clear threshold and the
// flame that is not there catches: a white-hot core, a warm halo that floods
// the window, the colour comes back, embers rise in front, and the frame
// turns from sapphire to amber. Toolkit: window + reveal + motes + grade.
// v3: `frame_style` picks the grade mark version for the owner's comparison
// (0 = M0 leaded, 1 = M1 cathedral, 2 = M2 tracery, 3 = M3 layered + halo).
#include "res://research/holo/shaders/holo_common.gdshaderinc"
#include "res://research/holo/shaders/mythic_toolkit.gdshaderinc"
#include "res://research/holo/shaders/mythic_frames.gdshaderinc"

uniform sampler2D art_tex : filter_linear_mipmap, repeat_disable;
uniform vec4 art_win = vec4(0.0, 0.0, 1.0, 1.0);
uniform int frame_style = 0;

const float DEPTH_PX = 6.0;
const vec2 FLAME_AT = vec2(0.50, 0.50);   // in the window
const float FLAME_SIZE = 30.0;            // card px

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	float win = holo_art(cp);
	vec2 local = myth_local(cp);
	float wall;
	vec2 l = myth_window(local, DEPTH_PX, 1.10, wall);
	vec3 art = myth_art(art_tex, art_win, l);
	float rv = myth_reveal(vec2(0.0, -1.0), 0.30, 0.55);
	float cold = holo_luma(art);
	vec3 cold_art = vec3(cold) * vec3(0.70, 0.80, 1.0) * 0.85;
	vec3 warm_art = art * vec3(1.12, 1.0, 0.86);
	art = mix(cold_art, warm_art, rv);
	vec2 fp = ((l - FLAME_AT) * HOLO_ART.zw) / FLAME_SIZE;
	float wick = exp(-dot(fp - vec2(0.0, 0.35), fp - vec2(0.0, 0.35)) * 40.0);
	art = holo_screen(art, vec3(0.45, 0.65, 1.0) * wick * 0.55 * (1.0 - rv));
	float fl = motif_flame(fp);
	float core = motif_flame(fp * 1.9 + vec2(0.0, -0.25));
	float flicker = 0.88 + 0.12 * sin(dot(tilt, vec2(11.0, 9.0)));
	vec3 flame = mix(vec3(1.0, 0.42, 0.10), vec3(1.0, 0.86, 0.45), smoothstep(0.1, 0.9, fl));
	float halo = exp(-dot(fp, fp) * 0.55) * rv;
	art = holo_screen(art, vec3(1.0, 0.55, 0.20) * halo * 0.85);
	art = holo_screen(art, flame * fl * rv * flicker);
	art = holo_screen(art, vec3(1.0, 0.97, 0.90) * core * rv);
	art *= 1.0 - 0.6 * wall;
	float m = myth_motes(cp, 7.0, 0.10 + 0.20 * rv, -6.0) * win;
	art = holo_screen(art, vec3(1.0, 0.60, 0.25) * m * rv);

	float inset = holo_inset(cp);
	vec3 col;
	float bw;
	vec4 outer = vec4(0.0);
	if (frame_style == 1) {
		col = m1_inside(base.rgb, cp, face, rv); bw = M1_BAND; outer = m1_outside(cp, rv);
	} else if (frame_style == 2) {
		col = m2_inside(base.rgb, cp, face, rv); bw = M2_BAND;
	} else if (frame_style == 3) {
		col = m3_inside(base.rgb, cp, face, rv); bw = M3_BAND; outer = m3_outside(cp, rv);
	} else {
		col = myth_grade(base.rgb, cp, face, rv); bw = MYTH_BAND;
	}
	col = mix(col, art, win * (1.0 - step(inset, bw)));
	col = mix(col, base.rgb, myth_gem(cp));    // the crystal above the frame
	vec3 rgb = mix(base.rgb, col, face);
	float a = base.a;
	// what stands outside the card's rectangle (crest, halo), and the cabochons
	float oa = outer.a * (1.0 - face) * (1.0 - myth_gem(cp));
	rgb = mix(rgb, outer.rgb, oa);
	a = max(a, oa);
	if (frame_style == 2) {
		vec4 cab = m2_cabochons(cp) * (1.0 - myth_gem(cp));
		rgb = mix(rgb, cab.rgb, cab.a);
		a = max(a, cab.a);
	}
	COLOR = vec4(rgb, a);
}
