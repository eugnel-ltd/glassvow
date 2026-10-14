// THE MYTHIC (epic) TOOLKIT. Each mythic card owns its own shader and its own
// constants and composes these modules to tell ITS story; nothing here is a
// shared tune. The one thing every mythic shares on purpose is the GRADE
// MARK (myth_grade): the prismatic gilt frame and the six-petal seal, which
// is what puts the whole grade above every other tier at a glance.
//
//   myth_window   parallax depth: the art recessed behind the frame
//   myth_reveal   a hidden layer that one lean (and only that lean) brings up
//   myth_motes    a layer IN FRONT of the art, sliding the other way
//   myth_grade    the grade's frame and seal
//   motifs        story shapes for foil masks and hidden layers

vec3 myth_art(sampler2D art, vec4 win, vec2 l) {
	return textureLod(art, win.xy + clamp(l, 0.0, 1.0) * win.zw, 0.0).rgb;
}

// The art window's local 0..1 coordinate.
vec2 myth_local(vec2 cp) {
	return (cp - HOLO_ART.xy) / HOLO_ART.zw;
}

// Parallax: the picture sits depth_px behind the frame; returns the sample
// coordinate, and the wall's shadow on the side the eye leans toward.
vec2 myth_window(vec2 local, float depth_px, float zoom, out float wall) {
	vec2 l = (local - 0.5) / zoom + 0.5 - tilt * depth_px / HOLO_ART.zw;
	vec2 px = local * HOLO_ART.zw;
	vec2 far = (1.0 - local) * HOLO_ART.zw;
	float w = 0.0;
	w += 1.0 - smoothstep(0.0, 6.0 * (0.4 + 0.9 * max(0.0, tilt.x)), px.x);
	w += 1.0 - smoothstep(0.0, 6.0 * (0.4 + 0.9 * max(0.0, -tilt.x)), far.x);
	w += 1.0 - smoothstep(0.0, 6.0 * (0.4 + 0.9 * max(0.0, tilt.y)), px.y);
	w += 1.0 - smoothstep(0.0, 6.0 * (0.4 + 0.9 * max(0.0, -tilt.y)), far.y);
	wall = clamp(w, 0.0, 1.0);
	return l;
}

// 0 until the card leans toward `dir` by `lo`, 1 by `hi`.
float myth_reveal(vec2 dir, float lo, float hi) {
	return smoothstep(lo, hi, dot(tilt, normalize(dir)));
}

float myth_motes(vec2 cp, float px, float density, float slide) {
	vec2 mp = (cp + tilt * slide) / px;
	vec2 mi = floor(mp);
	vec2 mh = holo_hash2(mi);
	float md = length(fract(mp) - mh);
	float on = step(1.0 - density, holo_hash(mi + 4.4));
	float tw = 0.35 + 0.65 * abs(sin(dot(tilt, vec2(5.0, 4.0)) + mh.x * 6.28));
	return (1.0 - smoothstep(0.03, 0.12, md)) * on * tw;
}

// --- motifs (signed or soft masks in a unit space) ---
float motif_petals(vec2 p, float w) {
	float r = length(p);
	float a = atan(p.y, p.x);
	return 1.0 - smoothstep(w * 0.4, w, abs(r - (0.55 + 0.22 * cos(6.0 * a))));
}

float motif_flame(vec2 p) {
	// a teardrop flame, point up, in -1..1
	p.x *= 1.0 + 0.25 * p.y;
	float body = length(vec2(p.x * 1.6, (p.y + 0.25) * 0.9));
	float tip = p.y > -0.1 ? abs(p.x) * 2.3 + (p.y + 0.1) * 0.9 : 0.0;
	return 1.0 - smoothstep(0.55, 0.75, max(body, tip));
}

float motif_door(vec2 p) {
	// an arched door, -1..1 box with a round head
	float box = max(abs(p.x) - 0.42, abs(p.y - 0.2) - 0.75);
	float arch = length(p - vec2(0.0, -0.55)) - 0.42;
	float d = min(box, max(arch, p.y + 0.55 - 0.0 * 1.0));
	d = p.y < -0.55 ? arch : box;
	return 1.0 - smoothstep(-0.02, 0.02, d);
}

// --- the grade mark ---
// A LEADED FRAME OF DICHROIC GLASS, shared by every mythic. An 8.5 px band
// inside the cut (it frames the art window too) is cut by cames into panes
// about 15 px long; each pane is dichroic glass that turns between two
// jewels (sapphire and amber) as the lean crosses its own angle, so a tilt
// walks a wave of colour round the frame. The leading is dark pewter with a
// thin oil-iridescent glint. A gold six-petal seal sits on the rule.
// `warm` (0..1) lets a card's story bias every pane toward amber.
const vec3 MYTH_SAPPHIRE = vec3(0.14, 0.42, 1.0);
const vec3 MYTH_AMBER = vec3(1.0, 0.64, 0.18);
const float MYTH_BAND = 8.5;
const float MYTH_PANE = 15.0;

vec3 myth_grade(vec3 base, vec2 cp, float face, float warm) {
	float inset = holo_inset(cp);
	float band = (1.0 - smoothstep(MYTH_BAND - 0.6, MYTH_BAND + 0.6, inset)) * face;
	// perimeter coordinate, so panes run round the frame
	vec2 c = cp - HOLO_CARD * 0.5;
	vec2 h = HOLO_CARD * 0.5;
	float side = (h.x - abs(c.x)) < (h.y - abs(c.y)) ? 1.0 : 0.0;
	float s = side > 0.5 ? (c.y + (c.x > 0.0 ? 400.0 : 0.0)) : (c.x + (c.y > 0.0 ? 800.0 : 1200.0));
	float sw = s / MYTH_PANE + 0.22 * sin(s * 0.09);   // panes of uneven length
	float pane_id = floor(sw);
	float pf = fract(sw);
	float came_x = 1.0 - smoothstep(0.035, 0.075, min(pf, 1.0 - pf));
	float came_y = max(1.0 - smoothstep(0.7, 1.4, inset), smoothstep(MYTH_BAND - 1.6, MYTH_BAND - 0.6, inset));
	float came = max(came_x, came_y);
	// the pane's own angle: where on the frame it sits, plus a jitter
	vec2 out_dir = normalize(c * vec2(1.0, 0.75) + 0.001);
	float j = holo_hash(vec2(pane_id, 3.0)) - 0.5;
	float turn = dot(tilt, out_dir) * 1.5 + j * 0.9 + warm * 2.0 - 0.1;
	float f = smoothstep(-0.45, 0.45, turn);
	vec3 jewel = mix(MYTH_SAPPHIRE, MYTH_AMBER, f);
	// dichroic glass shows a thin violet fringe as it turns between its two
	jewel = mix(jewel, vec3(0.70, 0.36, 0.88), 4.0 * f * (1.0 - f) * 0.45);
	float lit = exp(-pow(dot(tilt, out_dir) - 0.45 - j * 0.6, 2.0) * 5.0);
	float across = (inset - 0.8) / (MYTH_BAND - 1.6);
	float body = 0.62 + 0.38 * sin(clamp(across, 0.0, 1.0) * 3.14159);
	// glass is never flat: streaks along the pane, and each pane its own density
	body *= 0.78 + 0.34 * holo_noise(vec2(s * 0.22, inset * 0.7 + pane_id * 3.1));
	body *= 0.85 + 0.3 * holo_hash(vec2(pane_id, 7.0));
	vec3 pane = jewel * body * (0.70 + 0.65 * lit) + vec3(1.0, 0.97, 0.9) * pow(lit, 6.0) * 0.45;
	vec3 lead = vec3(0.16, 0.17, 0.20);
	vec3 oil = holo_rainbow(s * 0.012 + dot(tilt, vec2(0.7, 0.5)));
	float glint = exp(-pow((dot(normalize(c + 0.001), normalize(tilt + 0.001)) - 0.8) * 3.0, 2.0)) * clamp(length(tilt) * 1.5, 0.2, 1.0);
	lead += mix(vec3(0.55), oil, 0.55) * glint * 0.45;
	vec3 frame = mix(pane, lead, came);
	vec3 col = mix(base, frame, band);
	// the six-petal seal on the rule under the window, gold with a jewel heart
	vec2 sp = (cp - vec2(76.0, 93.5)) / 9.0;
	float r = length(sp);
	float sa = atan(sp.y, sp.x);
	float seal = 1.0 - smoothstep(0.64 + 0.26 * cos(6.0 * sa), 0.74 + 0.26 * cos(6.0 * sa), r);
	float hub = 1.0 - smoothstep(0.24, 0.32, r);
	vec3 gold = vec3(1.0, 0.82, 0.44) * (0.75 + 0.35 * lit);
	vec3 sealc = mix(gold, mix(MYTH_SAPPHIRE, MYTH_AMBER, f) * 1.2, hub);
	return mix(col, sealc, seal * face);
}
