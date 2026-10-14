shader_type canvas_item;
// FRONT, RARE candidate R3, "cut-glass mount": the art is set in a mount of
// cut crystal. A 4.5 px bevelled frame runs round the art window's INNER
// edge, cut into facets; each facet throws light when it faces the lean and
// a spectral fire at its ends, and the four corners flash like brilliants in
// turn. The art itself is untouched apart from a faint sheet of glass light;
// nothing crosses it.
#include "res://research/holo/shaders/holo_common.gdshaderinc"

const float MOUNT_PX = 5.5;
const float FACET_PX = 22.0;       // facet length along the mount
const float FIRE = 0.40;
const float CORNER = 0.95;
const float SHEET = 0.10;
const vec2 REST = vec2(0.30, -0.22);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	float win = holo_art(cp) * face;
	vec2 lo = HOLO_ART.xy;
	vec2 hi = HOLO_ART.xy + HOLO_ART.zw;
	vec2 dl = cp - lo;
	vec2 dh = hi - cp;
	float d = min(min(dl.x, dl.y), min(dh.x, dh.y));     // inward from the window's edge
	float mount = (1.0 - smoothstep(MOUNT_PX - 0.6, MOUNT_PX + 0.4, d)) * win;
	// which side, its outward normal, and the position along it
	vec2 n;
	float s;
	if (d == dl.x) { n = vec2(-1.0, 0.0); s = cp.y; }
	else if (d == dh.x) { n = vec2(1.0, 0.0); s = cp.y + 300.0; }
	else if (d == dl.y) { n = vec2(0.0, -1.0); s = cp.x + 600.0; }
	else { n = vec2(0.0, 1.0); s = cp.x + 900.0; }
	vec2 lt = tilt + REST;
	// facets: each tilted a little along the mount, alternating, like a cut
	float fid = floor(s / FACET_PX);
	float ff = fract(s / FACET_PX);
	float alt = mod(fid, 2.0) * 2.0 - 1.0;
	vec2 along = vec2(abs(n.y), abs(n.x));
	vec2 fn = normalize(-n * 0.8 + along * alt * 0.3);   // the facet slopes into the window
	float facing = dot(fn, normalize(lt)) * clamp(length(lt) * 1.4, 0.0, 1.0);
	float across = d / MOUNT_PX;
	float glass = 0.55 + 0.45 * across;                    // the bevel darkens toward the cut
	vec3 lit = vec3(1.0, 0.98, 0.94) * smoothstep(0.15, 0.85, facing);
	vec3 fire = holo_rainbow(ff * 0.9 + fid * 0.21 + dot(lt, vec2(0.7, 0.5))) * smoothstep(0.30, 0.95, facing);
	// crystal: the art seen through the bevel, a light gradient across it
	// (the bevel's slope), the lit facet's sheen and its fire at the ends
	float slope = 1.0 - across;
	vec3 bevel = base.rgb * (0.45 + 0.2 * glass) + vec3(0.72, 0.80, 0.95) * (0.18 + 0.30 * slope)
		+ lit * 0.55 * (0.4 + 0.6 * slope) + fire * FIRE * (0.3 + 0.7 * slope);
	float seam = 1.0 - smoothstep(0.004, 0.015, min(ff, 1.0 - ff));
	bevel = mix(bevel, bevel * 0.75 + vec3(0.9) * 0.2, seam);
	// the outer lip of the mount: one thin bright line, like a polished edge
	float lip = 1.0 - smoothstep(0.0, 0.6, abs(d - MOUNT_PX + 0.3));
	bevel = holo_screen(bevel, vec3(1.0, 0.97, 0.9) * lip * 0.5);
	vec3 col = mix(base.rgb, bevel, mount);
	// a faint sheet of glass light over the art
	vec2 local = (cp - lo) / HOLO_ART.zw;
	float sheet = exp(-pow((dot(local - 0.5, vec2(0.9, 0.45)) - lt.x * 0.4 - lt.y * 0.2) * 4.0, 2.0));
	col = holo_screen(col, vec3(1.0) * sheet * SHEET * win * (1.0 - mount));
	// the corners: brilliants that flash in turn
	for (int i = 0; i < 4; i++) {
		vec2 c = vec2(i % 2 == 0 ? lo.x + 2.6 : hi.x - 2.6, i < 2 ? lo.y + 2.6 : hi.y - 2.6);
		vec2 o = cp - c;
		vec2 toward = normalize(c - HOLO_ART.xy - HOLO_ART.zw * 0.5);
		float turn = smoothstep(0.4, 0.95, dot(normalize(lt), toward)) * clamp(length(lt) * 1.4, 0.0, 1.0);
		float star = exp(-dot(o, o) * 0.35) + exp(-abs(o.x) * 1.6 - o.y * o.y * 2.5) * 0.5 + exp(-abs(o.y) * 1.6 - o.x * o.x * 2.5) * 0.5;
		col = holo_screen(col, mix(vec3(1.0), holo_rainbow(float(i) * 0.25 + dot(lt, vec2(0.6, 0.4))), 0.4) * star * turn * CORNER * face);
	}
	COLOR = vec4(col, base.a);
}
