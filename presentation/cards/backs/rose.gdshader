shader_type canvas_item;
// The Rose card back (content/card-backs.json): a leaded rose window in night
// glass, gold-ruled. A procedural back costs no texture payload. It paints the
// back's 2D face in card px — CardView sets `card` from its own CARD_W/CARD_H —
// and the back's surface recipe (prism) adds the light on the slab. Angle, not
// time: the face is frozen at rest, so nothing here may read TIME.

uniform vec2 card = vec2(152.0, 216.0);
uniform vec4 night : source_color = vec4(0.035, 0.055, 0.13, 1.0);
uniform vec4 cobalt : source_color = vec4(0.10, 0.24, 0.62, 1.0);
uniform vec4 ruby : source_color = vec4(0.55, 0.07, 0.12, 1.0);
uniform vec4 amber : source_color = vec4(0.86, 0.52, 0.12, 1.0);
uniform vec4 teal : source_color = vec4(0.08, 0.42, 0.45, 1.0);
uniform vec4 lead : source_color = vec4(0.02, 0.02, 0.035, 1.0);
uniform vec4 gold : source_color = vec4(0.95, 0.76, 0.31, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float rr_sdf(vec2 p, vec2 half_s, float r) {
	vec2 q = abs(p) - (half_s - vec2(r));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// A lead came between cells: dark, with a soft shoulder.
float came(float d, float w) {
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.9, abs(d));
}

vec3 glass(vec3 base, vec2 cell, vec2 p) {
	float mottle = vnoise(p * 0.22 + cell * 3.1) * 0.5 + vnoise(p * 0.6) * 0.25;
	float tone = 0.72 + 0.5 * hash(cell);
	return base * tone * (0.75 + 0.6 * mottle);
}

void fragment() {
	vec2 cp = UV * card;
	vec2 p = cp - card * 0.5;
	vec3 col = night.rgb * (0.85 + 0.3 * vnoise(cp * 0.08));
	// a faint quarry-glass lattice behind everything (diamond panes)
	vec2 q = vec2(p.x + p.y, p.x - p.y) / 13.0;
	vec2 qf = abs(fract(q) - 0.5);
	float lattice = came(min(qf.x, qf.y) * 13.0, 1.0);
	col = mix(col, lead.rgb, lattice * 0.55);
	col += night.rgb * 0.6 * hash(floor(q)) * (1.0 - lattice);

	// THE ROSE — centre of the card, three rings of cells.
	vec2 rc = p;
	float r = length(rc);
	float a = atan(rc.y, rc.x);
	float R = 56.0;
	if (r < R) {
		vec3 cellc;
		vec2 cell;
		float edge;
		if (r < 10.0) {
			cell = vec2(0.0);
			cellc = amber.rgb * 1.25;
			float star = abs(fract(a / TAU * 6.0) - 0.5) * 2.0;
			edge = came(r - (6.0 + 2.5 * star), 1.2);
		} else if (r < 26.0) {
			float k = floor((a / TAU + 0.5) * 6.0);
			cell = vec2(1.0, k);
			cellc = mod(k, 2.0) < 0.5 ? ruby.rgb : cobalt.rgb;
			float sector = abs(fract((a / TAU + 0.5) * 6.0) - 0.5);
			// petal tips: the cell boundary is a cusp, not a ring
			float tip = 26.0 - 7.0 * pow(sector * 2.0, 1.6);
			edge = max(came(sector * r * TAU / 6.0, 1.3), came(r - tip, 1.4));
			if (r > tip) { cellc = cobalt.rgb * 0.6; }
			edge = max(edge, came(r - 10.0, 1.4));
		} else if (r < 45.0) {
			float k = floor((a / TAU + 0.5) * 12.0 + 0.5);
			cell = vec2(2.0, k);
			float m = mod(k, 3.0);
			cellc = m < 0.5 ? cobalt.rgb : (m < 1.5 ? teal.rgb : amber.rgb * 0.85);
			float sector = abs(fract((a / TAU + 0.5) * 12.0 + 0.5) - 0.5);
			// lancets: a pointed arch at the outer end of every cell
			float arch = 45.0 - 9.0 * sqrt(sector * 2.0);
			edge = max(came(sector * r * TAU / 12.0, 1.3), came(r - arch, 1.3));
			if (r > arch) { cellc = ruby.rgb * 0.9; }
			edge = max(edge, came(r - 26.0, 1.5));
		} else {
			float k = floor((a / TAU + 0.5) * 24.0);
			cell = vec2(3.0, k);
			cellc = mod(k, 2.0) < 0.5 ? ruby.rgb : amber.rgb;
			vec2 cc = vec2(cos((k + 0.5) / 24.0 * TAU - PI), sin((k + 0.5) / 24.0 * TAU - PI)) * 50.5;
			float roundel = length(rc - cc) - 4.6;
			edge = max(came(roundel, 1.1), came(r - 45.0, 1.5));
			if (roundel > 0.0) { cellc = night.rgb * 1.4; }
		}
		col = glass(cellc, cell, cp);
		col = mix(col, lead.rgb, edge);
	}
	// gold rim round the rose
	float rim = came(r - R, 2.2);
	col = mix(col, gold.rgb, rim);
	col = mix(col, lead.rgb, came(r - R - 2.0, 0.9) * 0.8);

	// two small roundels above and below, on a gold stem
	for (int i = 0; i < 2; i++) {
		float sy = i == 0 ? -84.0 : 84.0;
		vec2 sp = p - vec2(0.0, sy);
		float sr = length(sp);
		if (sr < 12.5) {
			float sa = atan(sp.y, sp.x);
			float lobe = 12.5 - 3.0 * abs(sin(sa * 1.5));
			vec3 c2 = sr < 4.0 ? amber.rgb * 1.2 : (sr < lobe ? ruby.rgb : night.rgb);
			col = glass(c2, vec2(9.0, float(i)), cp);
			col = mix(col, lead.rgb, max(came(sr - 4.0, 1.1), came(sr - lobe, 1.2)));
		}
		col = mix(col, gold.rgb, came(sr - 13.0, 1.6));
	}
	float stem = came(p.x, 1.2) * step(13.0, abs(p.y)) * step(abs(p.y), 71.0) * step(R + 2.0, abs(p.y));
	col = mix(col, gold.rgb * 0.8, stem);

	// the frame: a double gold rule and corner diamonds
	float d = rr_sdf(p, card * 0.5, 11.0);
	col = mix(col, gold.rgb, came(d + 7.0, 1.6));
	col = mix(col, gold.rgb * 0.7, came(d + 10.5, 0.8));
	col = mix(col, night.rgb * 0.5, smoothstep(-6.0, -1.0, d) * (1.0 - came(d + 7.0, 1.6)));
	vec2 corner = abs(p) - (card * 0.5 - vec2(16.0, 16.0));
	float dia = abs(corner.x) + abs(corner.y) - 4.5;
	col = mix(col, gold.rgb, 1.0 - smoothstep(0.0, 1.0, dia));
	col = mix(col, lead.rgb, came(dia, 0.7) * 0.6);

	COLOR = vec4(col, 1.0);
}
