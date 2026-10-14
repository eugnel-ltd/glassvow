shader_type canvas_item;
// FRONT, UNCOMMON: "spectral frame" (the owner's pick, 14 Oct 2026). The foil
// keeps OFF the rules text: it lives in a 5.5 px frame band inside the cut and
// on the rule under the art window, where it runs a real spectrum (the
// common's rim is silver and half as wide). The plate inside the frame is left
// exactly as rendered, so text contrast is today's, by construction.
#include "res://presentation/cards/holo/holo_common.gdshaderinc"

const float BAND_PX = 5.5;
const float RULE_Y = 93.0;
const float RULE_HALF = 1.6;
const float FREQ = 2.6;           // hue cycles round the frame
const float GAIN = 1.3;
const float STRENGTH = 0.48;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	float inset = holo_inset(cp);
	float band = 1.0 - smoothstep(BAND_PX - 0.7, BAND_PX + 0.7, inset);
	float rule = (1.0 - smoothstep(RULE_HALF - 0.5, RULE_HALF + 0.5, abs(cp.y - RULE_Y)))
		* step(BAND_PX, cp.x) * step(cp.x, HOLO_CARD.x - BAND_PX);
	float m = max(band, rule) * face;
	vec2 q = cp / HOLO_CARD;
	float along = dot(q - 0.5, normalize(vec2(-0.55, 1.0)));
	float slide = tilt.y * 0.40 - tilt.x * 0.25;
	vec3 rb = holo_rainbow(along * FREQ + slide * GAIN);
	float env = exp(-pow((along - slide) * 2.4, 2.0));
	vec3 foil = mix(vec3(0.78, 0.81, 0.88), rb, 0.75) * (0.45 + 0.55 * env);
	vec3 col = mix(base.rgb, holo_screen(base.rgb * 0.45, foil * STRENGTH), m);
	COLOR = vec4(col, base.a);
}
