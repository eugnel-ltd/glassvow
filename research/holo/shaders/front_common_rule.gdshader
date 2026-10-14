shader_type canvas_item;
// FRONT, COMMON: "silver rule". Foil on the cut edge only: a thin silver band
// round the card whose one bright glint runs round the rim as it tilts, with
// a whisper of spectrum in it. Everything inside the rim is untouched.
#include "res://research/holo/shaders/holo_common.gdshaderinc"

const float RIM_PX = 3.2;
const float GLINT_W = 0.10;       // fraction of the perimeter the glint covers
const float STRENGTH = 1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	float inset = holo_inset(cp);
	float rim = (1.0 - smoothstep(RIM_PX - 0.7, RIM_PX + 0.7, inset)) * face;
	vec2 c = cp - HOLO_CARD * 0.5;
	float ang = atan(c.y * 0.70, c.x) / 6.2831853;           // -0.5..0.5 round the rim
	float aim = atan(-tilt.y, tilt.x + 1e-4) / 6.2831853;     // where the light sits
	float reach = clamp(length(tilt), 0.0, 1.0);
	float dist = abs(fract(ang - aim + 0.5) - 0.5);
	float glint = exp(-pow(dist / GLINT_W, 2.0)) * (0.35 + 0.65 * reach);
	vec3 rb = holo_rainbow(ang * 2.0 + dot(tilt, vec2(0.6, 0.4)));
	vec3 silver = vec3(0.80, 0.83, 0.90);
	vec3 foil = silver * (0.45 + 0.55 * glint) + rb * 0.18 * glint;
	vec3 col = mix(base.rgb, holo_screen(base.rgb * 0.4, foil * STRENGTH), rim);
	COLOR = vec4(col, base.a);
}
