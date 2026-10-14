shader_type canvas_item;
// MYTHIC EXAMPLE 1 — working label "A Lantern with No Flame" (the Usurper's
// Gate item; not a designed card). Story: cold glass, no wick. At rest the
// picture is drained cold and recessed, with only a faint blue glimmer where
// a wick would be. Lean the card TOWARD you past a clear threshold and the
// flame that is not there catches: a white-hot core, a warm halo that floods
// the window, the colour comes back, embers rise in front, and the whole
// leaded frame turns from sapphire to amber. One clear moment, not a fade.
// Toolkit: window + reveal + motes + grade (warm).
#include "res://research/holo/shaders/holo_common.gdshaderinc"
#include "res://research/holo/shaders/mythic_toolkit.gdshaderinc"

uniform sampler2D art_tex : filter_linear_mipmap, repeat_disable;
uniform vec4 art_win = vec4(0.0, 0.0, 1.0, 1.0);

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
	// before: a faint cold glimmer at the wick, a hint to tilt
	float wick = exp(-dot(fp - vec2(0.0, 0.35), fp - vec2(0.0, 0.35)) * 40.0);
	art = holo_screen(art, vec3(0.45, 0.65, 1.0) * wick * 0.55 * (1.0 - rv));
	// after: the flame
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
	vec3 col = myth_grade(base.rgb, cp, face, rv);
	col = mix(col, art, win * (1.0 - step(holo_inset(cp), MYTH_BAND)));
	COLOR = vec4(mix(base.rgb, col, face), base.a);
}
