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
vec3 myth_grade(vec3 base, vec2 cp, float face) {
	float inset = holo_inset(cp);
	float frame = (1.0 - holo_art(cp)) * face;
	vec2 q = cp / HOLO_CARD;
	float along = dot(q - 0.5, normalize(vec2(1.0, 1.1)));
	float env = exp(-pow((along - tilt.x * 0.42 - tilt.y * 0.30) * 2.2, 2.0));
	vec3 rb = holo_rainbow(along * 3.4 + dot(tilt, vec2(1.2, 0.9)));
	vec3 gold = vec3(1.0, 0.82, 0.44);
	vec3 foil = mix(gold * 0.55, rb, 0.55 + 0.45 * env);
	// a gilt rim, then a prismatic plate
	float rim = 1.0 - smoothstep(3.0, 4.2, inset);
	float band = (1.0 - smoothstep(7.0, 8.5, inset)) * frame;
	vec3 col = holo_screen(base, foil * (0.10 + 0.25 * env) * 0.45 * frame);
	col = holo_screen(col, foil * (0.35 + 0.65 * env) * 0.85 * band);
	col = mix(col, holo_screen(gold * 0.70, rb * 0.55 * (0.3 + 0.7 * env)), rim * face);
	// the six-petal seal on the rule under the window
	vec2 sp = (cp - vec2(76.0, 93.5)) / 8.5;
	float r = length(sp);
	float sa = atan(sp.y, sp.x);
	float seal = 1.0 - smoothstep(0.64 + 0.26 * cos(6.0 * sa), 0.74 + 0.26 * cos(6.0 * sa), r);
	float hub = 1.0 - smoothstep(0.22, 0.30, r);
	vec3 sealc = mix(gold, holo_rainbow(r * 0.9 + dot(tilt, vec2(1.5, 1.0))), 0.6 * (1.0 - hub));
	return mix(col, sealc, seal * face);
}
