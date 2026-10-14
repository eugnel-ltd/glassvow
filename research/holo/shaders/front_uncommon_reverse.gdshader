shader_type canvas_item;
// FRONT, UNCOMMON: "reverse holo". The picture stays clean; the frame and the
// rules plate carry a fine rainbow sheen with a woven tooth, the bright
// stripe crossing as it tilts. Kept below the text's contrast: rules glyphs
// are dark-on-light or light-on-dark, and the sheen is screened, never over.
#include "res://research/holo/shaders/holo_common.gdshaderinc"

const float FREQ = 3.2;           // hue cycles down the card
const float GAIN = 1.4;
const float STRIPE = 3.0;
const float STRENGTH = 0.30;
const float WEAVE_PX = 3.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float m = holo_face(cp) * (1.0 - holo_art(cp));
	vec2 q = cp / HOLO_CARD;
	float along = dot(q - 0.5, normalize(vec2(-0.55, 1.0)));
	float slide = tilt.y * 0.40 - tilt.x * 0.25;
	vec3 rb = holo_rainbow(along * FREQ + slide * GAIN);
	float env = exp(-pow((along - slide) * STRIPE, 2.0));
	vec2 w = cp / WEAVE_PX;
	float weave = 0.90 + 0.10 * sin(w.x * 3.14159) * sin(w.y * 3.14159);
	float edge_boost = 0.6 + 0.4 * clamp(length(tilt), 0.0, 1.0);
	vec3 sheen = rb * (0.22 + 0.78 * env) * weave * STRENGTH * edge_boost;
	vec3 col = mix(base.rgb, holo_screen(base.rgb, sheen), m);
	COLOR = vec4(col, base.a);
}
