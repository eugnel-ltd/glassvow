// MYTHIC FRAME VERSIONS M1–M3 (v3), beside M0 (myth_grade, the v2 leaded
// dichroic frame). Comparison only: the owner picks one, which then becomes
// the shared grade mark. Each may draw OUTSIDE the card's rectangle, into the
// stage picture's 24 px margin (a crest, a halo), which needs no layout
// change and no extra pass: it is the same quad.
//
//   M1 cathedral  gilt frame; the top edge rises into a pointed arch with a
//                 rose window and a finial, glazed in the grade's jewels
//   M2 tracery    a gold band pierced with quatrefoils of jewel glass, and
//                 cabochons at the corners and mid-sides that catch the light
//                 in turn as the lean goes round
//   M3 layered    a glass frame standing proud of a gold one (parallax and a
//                 cast shadow between the layers) and a slow ember halo
//                 breathing behind the card's silhouette

const vec3 MYTH_GOLD = vec3(1.0, 0.80, 0.42);
const vec3 MYTH_GOLD_DEEP = vec3(0.55, 0.36, 0.12);

// brushed gold whose highlight runs with the lean
vec3 myth_gold(vec2 cp, float u) {
	float sheen = exp(-pow((dot(cp / HOLO_CARD - 0.5, vec2(0.8, 0.6)) - tilt.x * 0.45 - tilt.y * 0.3) * 3.0, 2.0));
	float groove = 0.85 + 0.15 * sin(u * 3.14159);
	return mix(MYTH_GOLD_DEEP, MYTH_GOLD, 0.45 + 0.55 * sheen) * groove + vec3(1.0, 0.95, 0.85) * pow(sheen, 8.0) * 0.4;
}

vec3 myth_jewel(float f) {
	vec3 j = mix(MYTH_SAPPHIRE, MYTH_AMBER, f);
	return mix(j, vec3(0.70, 0.36, 0.88), 4.0 * f * (1.0 - f) * 0.45);
}

// ---------- M1: the cathedral crest ----------
const float M1_BAND = 8.5;
const float M1_W = 40.0;          // half-span of the arch
const float M1_H = 21.0;          // its rise above the card's top edge

vec3 m1_inside(vec3 base, vec2 cp, float face, float warm) {
	float inset = holo_inset(cp);
	float band = (1.0 - smoothstep(M1_BAND - 0.6, M1_BAND + 0.6, inset)) * face;
	float u = clamp(inset / M1_BAND, 0.0, 1.0);
	vec3 gold = myth_gold(cp, u);
	// a jewel channel set into the gilt, between two engraved lines
	float chan = smoothstep(4.0, 4.6, inset) * (1.0 - smoothstep(6.6, 7.2, inset));
	float f = smoothstep(-0.5, 0.5, dot(tilt, normalize(cp - HOLO_CARD * 0.5)) * 1.4 + warm * 2.0 - 0.1);
	vec3 col = mix(gold, myth_jewel(f) * (0.8 + 0.4 * holo_noise(cp * 0.3)), chan);
	float line = (1.0 - smoothstep(0.0, 0.5, abs(inset - 3.6))) + (1.0 - smoothstep(0.0, 0.5, abs(inset - 7.6)));
	col *= 1.0 - 0.45 * clamp(line, 0.0, 1.0);
	return mix(base, col, band);
}

vec4 m1_outside(vec2 cp, float warm) {
	// a pointed (two-centred, depressed) arch: each half is an arc whose
	// centre lies PAST the centre line and below the springing, so the two
	// arcs meet at a point at the apex
	float sh = 26.0;
	float cy = ((M1_W + sh) * (M1_W + sh) - sh * sh - M1_H * M1_H) / (2.0 * M1_H);
	float R = sqrt((M1_W + sh) * (M1_W + sh) + cy * cy);
	vec2 cl = vec2(76.0 + sh, cy);
	vec2 cr = vec2(76.0 - sh, cy);
	float dl = length(cp - cl);
	float dr = length(cp - cr);
	// each half of a pointed arch is an arc centred on the far side of the
	// centre line, so the region under it is "inside the arc of my own half"
	float own = cp.x < 76.0 ? dl : dr;
	float inside = step(own, R) * step(cp.y, 0.5);
	float edge = abs(own - R);
	float rim = (1.0 - smoothstep(1.2, 2.0, edge)) * step(cp.y, 0.5) * step(-M1_H - 2.0, cp.y);
	// the rose window in the crest, a second gilt arch inside the first, and
	// spokes of leading from the rose out to the arch
	vec2 rc = vec2(76.0, -8.5);
	vec2 rp = cp - rc;
	float r = length(rp);
	float a = atan(rp.y, rp.x);
	float petal = 7.0 * (0.70 + 0.30 * cos(6.0 * a));
	float rose = 1.0 - smoothstep(petal - 0.4, petal + 0.4, r);
	float ring = 1.0 - smoothstep(0.5, 1.1, abs(r - 7.6));
	float hub = 1.0 - smoothstep(1.6, 2.3, r);
	float spoke = (1.0 - smoothstep(0.5, 1.1, abs(sin(4.0 * a)) * r)) * step(7.6, r);
	float inner_rim = (1.0 - smoothstep(0.5, 1.1, abs(edge - 3.4))) * inside;
	float lit = exp(-pow(dot(tilt, vec2(0.0, -1.0)) - 0.2, 2.0) * 3.0);
	float pane = floor((a + 3.14159) / 0.785);
	float f = smoothstep(-0.5, 0.5, holo_hash(vec2(pane, 1.0)) - 0.5 + dot(tilt, vec2(1.0, -0.6)) * 0.9 + warm * 2.0 - 0.1);
	vec3 glass = myth_jewel(f) * (0.55 + 0.45 * lit + 0.25 * holo_noise(cp * 0.4));
	vec3 rosec = mix(myth_jewel(1.0 - f), vec3(1.0, 0.95, 0.85), 0.25 * lit) * (0.85 + 0.45 * lit);
	vec3 col = mix(glass, rosec, rose);
	col = mix(col, myth_gold(cp, 0.5) * 0.95, clamp(max(max(ring, hub), max(spoke * 0.9, inner_rim)), 0.0, 1.0));
	col = mix(col, myth_gold(cp, 0.5), rim);
	// the finial at the apex
	vec2 fp = cp - vec2(76.0, -M1_H - 1.5);
	float fin = 1.0 - smoothstep(2.0, 2.8, abs(fp.x) + abs(fp.y) * 0.8);
	col = mix(col, myth_gold(cp, 0.5) * 1.1, fin);
	float alpha = max(max(inside, rim), fin);
	return vec4(col, alpha);
}

// ---------- M2: gilt tracery and cabochons ----------
const float M2_BAND = 9.5;

vec4 m2_cab(vec2 cp, vec2 c, float rad, vec3 jewel) {
	vec2 o = (cp - c) / rad;
	float r = length(o);
	float bezel = (1.0 - smoothstep(1.18, 1.32, r)) * smoothstep(0.92, 1.0, r);
	float dome = 1.0 - smoothstep(0.9, 1.0, r);
	vec3 n = normalize(vec3(o * 0.9, sqrt(max(0.0, 1.0 - dot(o, o)))));
	vec3 l = normalize(vec3(tilt * 0.9 + vec2(0.25, -0.3), 1.0));
	float diff = max(0.0, dot(n, l));
	float spec = pow(max(0.0, dot(reflect(-l, n), vec3(0.0, 0.0, 1.0))), 40.0);
	// in turn: the cabochon the lean points toward glows from within
	vec2 toward = normalize(c - HOLO_CARD * 0.5);
	float turn = smoothstep(0.55, 0.95, dot(normalize(tilt + vec2(0.0001)), toward)) * clamp(length(tilt) * 1.4, 0.0, 1.0);
	vec3 col = jewel * (0.35 + 0.65 * diff) * (0.8 + 1.0 * turn) + vec3(1.0) * spec * 0.9;
	col = holo_screen(col, jewel * exp(-r * r * 3.0) * turn * 0.8);
	col = mix(col, myth_gold(cp, 0.5), bezel);
	return vec4(col, max(dome, bezel));
}

vec3 m2_inside(vec3 base, vec2 cp, float face, float warm) {
	float inset = holo_inset(cp);
	float band = (1.0 - smoothstep(M2_BAND - 0.6, M2_BAND + 0.6, inset)) * face;
	float u = clamp(inset / M2_BAND, 0.0, 1.0);
	vec2 c = cp - HOLO_CARD * 0.5;
	vec2 h = HOLO_CARD * 0.5;
	float side = (h.x - abs(c.x)) < (h.y - abs(c.y)) ? 1.0 : 0.0;
	float s = side > 0.5 ? cp.y : cp.x;
	vec2 tp = vec2((fract(s / 12.0) - 0.5) * 12.0, (u - 0.5) * M2_BAND);
	float a = atan(tp.y, tp.x);
	float qf = 1.0 - smoothstep(-0.3, 0.3, length(tp) - 3.1 * (0.72 + 0.28 * cos(4.0 * a)));
	float f = smoothstep(-0.5, 0.5, dot(tilt, normalize(c + 0.001)) * 1.4 + holo_hash(vec2(floor(s / 12.0), side)) - 0.5 + warm * 2.0);
	vec3 col = mix(myth_gold(cp, u), myth_jewel(f) * 1.1, qf);
	float bead = (1.0 - smoothstep(0.0, 0.6, abs(inset - 1.2))) + (1.0 - smoothstep(0.0, 0.6, abs(inset - M2_BAND + 0.8)));
	col = mix(col, MYTH_GOLD * 1.1, clamp(bead, 0.0, 1.0) * 0.6);
	return mix(base, col, band);
}

vec4 m2_cabochons(vec2 cp) {
	vec4 acc = vec4(0.0);
	vec3 ruby = vec3(0.95, 0.12, 0.22);
	vec3 emerald = vec3(0.10, 0.80, 0.45);
	vec4 k;
	k = m2_cab(cp, vec2(6.0, 6.0), 7.5, MYTH_SAPPHIRE * 1.2); acc = mix(acc, k, k.a);
	k = m2_cab(cp, vec2(146.0, 6.0), 7.5, ruby); acc = mix(acc, k, k.a);
	k = m2_cab(cp, vec2(6.0, 210.0), 7.5, emerald); acc = mix(acc, k, k.a);
	k = m2_cab(cp, vec2(146.0, 210.0), 7.5, MYTH_AMBER); acc = mix(acc, k, k.a);
	k = m2_cab(cp, vec2(4.8, 108.0), 4.2, ruby); acc = mix(acc, k, k.a);
	k = m2_cab(cp, vec2(147.2, 108.0), 4.2, emerald); acc = mix(acc, k, k.a);
	k = m2_cab(cp, vec2(76.0, 211.2), 4.2, MYTH_SAPPHIRE * 1.2); acc = mix(acc, k, k.a);
	return acc;
}

// ---------- M3: layered glass over gold, and an ember halo ----------
const float M3_BAND = 10.0;
const float M3_PROUD = 2.4;       // px the glass layer shifts per full lean

vec3 m3_inside(vec3 base, vec2 cp, float face, float warm) {
	float inset = holo_inset(cp);
	float band = (1.0 - smoothstep(M3_BAND - 0.6, M3_BAND + 0.6, inset)) * face;
	vec3 gold = myth_gold(cp, clamp(inset / M3_BAND, 0.0, 1.0)) * 0.85;
	// the glass layer stands proud: it slides against the gold, and its
	// shadow falls on the gold below it, offset away from the light
	vec2 o = tilt * M3_PROUD;
	vec2 gp = cp + o;
	float gin = holo_inset(gp);
	float gband = smoothstep(1.6, 2.4, gin) * (1.0 - smoothstep(7.4, 8.2, gin));
	vec2 sp = cp + o * 1.8 + vec2(-1.2, -1.6);
	float sin_ = holo_inset(sp);
	float shadow = smoothstep(1.6, 2.4, sin_) * (1.0 - smoothstep(7.4, 8.2, sin_));
	gold *= 1.0 - 0.55 * shadow * (1.0 - gband);
	vec3 col = myth_grade(gold, gp, face, warm);
	col = mix(gold, col, gband);
	// a bright lip on the glass's lit edge
	float lip = (1.0 - smoothstep(0.0, 0.7, abs(gin - 2.0))) + (1.0 - smoothstep(0.0, 0.7, abs(gin - 7.8)));
	col = holo_screen(col, vec3(1.0, 0.95, 0.85) * clamp(lip, 0.0, 1.0) * 0.35 * clamp(length(tilt) + 0.3, 0.0, 1.0));
	return mix(base, col, band);
}

vec4 m3_outside(vec2 cp, float warm) {
	float out_d = -holo_inset(cp);                   // px outside the cut
	float breathe = 0.62 + 0.38 * sin(TIME * 1.1);
	float glow = exp(-max(out_d, 0.0) / 6.5) * step(0.0, out_d) * breathe;
	vec3 ember = mix(vec3(1.0, 0.45, 0.12), vec3(1.0, 0.75, 0.35), warm);
	// sparks rising in the margin
	vec2 sp = vec2(cp.x / 7.0, (cp.y + TIME * 9.0) / 7.0);
	vec2 si = floor(sp);
	vec2 sh = holo_hash2(si);
	float spark = (1.0 - smoothstep(0.05, 0.16, length(fract(sp) - sh))) * step(0.88, holo_hash(si + 2.2))
		* step(0.0, out_d) * exp(-max(out_d, 0.0) / 12.0);
	return vec4(ember, clamp(glow * 0.85 + spark, 0.0, 1.0));
}
