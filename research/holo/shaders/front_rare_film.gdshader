shader_type canvas_item;
// FRONT, RARE candidate R1, "filmed plate": the art window is glazed with a
// sheet of dichroic-filmed glass. No lines cross the art: a soft two-jewel
// film (teal turning rose, never a full rainbow) flows over the plate with
// the lean, strongest where the art is light; a broad glare streak slides
// across the glass; the glazing's own edge catches a thin light at the rim
// of the window. Quieter than the mythic's frame, louder than the uncommon.
#include "res://research/holo/shaders/holo_common.gdshaderinc"

const vec3 TEAL = vec3(0.20, 0.85, 0.85);
const vec3 ROSE = vec3(1.00, 0.40, 0.70);
const float FILM = 0.40;          // film strength through the art
const float FLOW_PX = 46.0;       // the film's own scale
const float STREAK = 0.30;        // glare streak strength
const float RIM = 0.55;           // the glazing's edge light

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	float win = holo_art(cp) * face;
	vec2 local = (cp - HOLO_ART.xy) / HOLO_ART.zw;
	// the film: a smooth thickness field, shifted by the lean (path length)
	vec2 p = cp / FLOW_PX + tilt * vec2(0.55, 0.45);
	float th = holo_noise(p) * 0.65 + holo_noise(p * 2.3 + 5.1) * 0.35;
	float turn = smoothstep(0.25, 0.75, th + dot(tilt, vec2(0.35, -0.25)));
	vec3 jewel = mix(TEAL, ROSE, turn);
	float lum = holo_luma(base.rgb);
	float through = 0.35 + 0.65 * smoothstep(0.08, 0.6, lum);
	// the film re-colours the light coming through: the art's own value,
	// carried in the jewel (detail survives), then a little of the jewel's
	// reflection screened on top
	float amt = FILM * (0.6 + 0.4 * clamp(length(tilt) * 1.3 + 0.3, 0.0, 1.0));
	vec3 tinted = mix(base.rgb, vec3(lum) * jewel * 1.9, amt);
	vec3 col = holo_screen(tinted, jewel * 0.22 * through);
	// a broad glare streak across the glass, sliding with the lean
	float along = dot(local - 0.5, normalize(vec2(1.0, 0.55)));
	float streak = exp(-pow((along - tilt.x * 0.45 - tilt.y * 0.25) * 5.0, 2.0));
	col = holo_screen(col, vec3(1.0, 0.98, 0.95) * streak * STREAK);
	// the glazing's edge: a thin light just inside the window, on the lit side
	vec2 e = min(local, 1.0 - local) * HOLO_ART.zw;
	float edge = 1.0 - smoothstep(0.4, 1.6, min(e.x, e.y));
	vec2 side = vec2(local.x < 0.5 ? -1.0 : 1.0, local.y < 0.5 ? -1.0 : 1.0);
	float faces = clamp(dot(side * vec2(e.x < e.y ? 1.0 : 0.0, e.y <= e.x ? 1.0 : 0.0), normalize(tilt + vec2(0.3, -0.2))), 0.0, 1.0);
	col = holo_screen(col, mix(vec3(1.0), jewel, 0.4) * edge * (0.25 + 0.75 * faces) * RIM);
	COLOR = vec4(mix(base.rgb, col, win), base.a);
}
