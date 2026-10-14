shader_type canvas_item;
// MYTHIC EXAMPLE 2 — working label "The Shadow of a Door" (the Eighth Omen:
// "it was the shadow of a door"; not a designed card). Story motif in the
// foil MASK: the art window's hologram is cut in the shape of an arched door
// whose shadow swings with the lean like a shadow under a moving lamp; at the
// far lean the door opens a slit of light. Toolkit: motif mask + reveal + grade.
#include "res://research/holo/shaders/holo_common.gdshaderinc"
#include "res://research/holo/shaders/mythic_toolkit.gdshaderinc"

uniform sampler2D art_tex : filter_linear_mipmap, repeat_disable;
uniform vec4 art_win = vec4(0.0, 0.0, 1.0, 1.0);

const float DOOR_H = 40.0;                // card px, half height
const float SWING = 18.0;                 // card px the shadow travels per full lean

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	float win = holo_art(cp);
	vec2 local = myth_local(cp);
	vec3 art = myth_art(art_tex, art_win, local);
	vec2 wc = HOLO_ART.xy + HOLO_ART.zw * 0.5;
	// the door's shadow, cast away from the lean and sheared like a real one
	vec2 off = -tilt * SWING;
	vec2 dp = (cp - wc - off) / DOOR_H;
	dp.x -= dp.y * tilt.x * 0.35;
	float door = motif_door(dp);
	// the hologram lives only inside the door's shadow: a deep violet grating
	// the shadow is the grade's own dichroic glass, sapphire turning violet
	float turn = 0.5 + 0.5 * sin(dot(cp, vec2(0.05, 0.03)) + dot(tilt, vec2(2.4, 1.6)));
	vec3 tint = mix(MYTH_SAPPHIRE, vec3(0.70, 0.36, 0.88), turn);
	vec3 shade = art * 0.18 + tint * 0.30;
	art = mix(art, shade, door * 0.85);
	// at the far lean the door opens: a slit of light down its middle
	float open = myth_reveal(vec2(1.0, 0.2), 0.45, 0.95);
	float slit = (1.0 - smoothstep(0.02, 0.10 + 0.18 * open, abs(dp.x))) * door;
	art = holo_screen(art, vec3(1.0, 0.93, 0.75) * slit * open);
	vec3 col = myth_grade(base.rgb, cp, face, 0.0);
	col = mix(col, art, win * (1.0 - step(holo_inset(cp), MYTH_BAND)));
	COLOR = vec4(mix(base.rgb, col, face), base.a);
}
