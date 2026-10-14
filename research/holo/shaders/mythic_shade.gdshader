shader_type canvas_item;
// MYTHIC EXAMPLE 3 — working label "Your Own Shade" (the Trail quest of the
// self that still remembers the road; not a designed card). Story as a
// second, deeper layer: a pale copy of the picture lies far behind it and
// lags the other way as the card tilts, so the figure walks with its own
// shade; at a hard lean the shade steps out over the picture. Pale motes
// ("cold motes") hang in front. Toolkit: window x2 (deep + shallow) + reveal +
// motes + grade.
#include "res://research/holo/shaders/holo_common.gdshaderinc"
#include "res://research/holo/shaders/mythic_toolkit.gdshaderinc"

uniform sampler2D art_tex : filter_linear_mipmap, repeat_disable;
uniform vec4 art_win = vec4(0.0, 0.0, 1.0, 1.0);

const float NEAR_PX = 2.5;
const float FAR_PX = -12.0;    // negative: the shade moves against the art

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	float win = holo_art(cp);
	vec2 local = myth_local(cp);
	float wall;
	vec2 l = myth_window(local, NEAR_PX, 1.06, wall);
	float wall2;
	vec2 l2 = myth_window(local, FAR_PX, 1.14, wall2);
	vec3 art = myth_art(art_tex, art_win, l);
	vec3 ghost = myth_art(art_tex, art_win, l2);
	float gl = holo_luma(ghost);
	vec3 pale = vec3(0.62, 0.78, 1.0) * smoothstep(0.25, 0.85, gl);
	float out_ = myth_reveal(vec2(-1.0, 0.0), 0.10, 0.90) + myth_reveal(vec2(1.0, 0.0), 0.10, 0.90);
	float k = 0.30 + 0.60 * clamp(out_, 0.0, 1.0);
	art = holo_screen(art * (1.0 - 0.25 * k), pale * k);
	art *= 1.0 - 0.5 * wall;
	float m = myth_motes(cp, 7.0, 0.20, 6.0) * win;
	art = holo_screen(art, vec3(0.75, 0.88, 1.0) * m * 0.8);
	vec3 col = myth_grade(base.rgb, cp, face, 0.0);
	col = mix(col, art, win * (1.0 - step(holo_inset(cp), MYTH_BAND)));
	COLOR = vec4(mix(base.rgb, col, face), base.a);
}
