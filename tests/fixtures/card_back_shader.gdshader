shader_type canvas_item;
// A procedural card back for the suite (tests/test_card_backs.gd). The shipped
// backs are paintings, but the catalogue still takes a `shader` back, so the
// suite keeps one to prove that path: CardView sizes `card` in card px, and a
// resting face is frozen, so nothing here reads the clock.

uniform vec2 card = vec2(152.0, 216.0);

void fragment() {
	vec2 cp = UV * card;
	float ring = step(abs(length(cp - card * 0.5) - 40.0), 2.0);
	COLOR = vec4(mix(vec3(0.04, 0.05, 0.1), vec3(0.95, 0.76, 0.31), ring), 1.0);
}
