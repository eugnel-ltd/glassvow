// Geometry only, shared by every card hologram (#657): where the card lies
// in the picture it is drawn over, its masks, and a few pure helpers. NO LOOK
// KNOBS live here: each recipe owns its own constants in its own file (the
// per-recipe rule, docs/solutions/conventions/per-recipe-shader-knobs.md).
//
// Each recipe is a canvas_item shader set as the material of a card's
// picture: the card's frozen stage render (CardView's picture), a baked face
// (BakedCard) or a pile's top back (PileStack). It reads TEXTURE (that
// picture) and nothing from the screen, so it costs no backbuffer copy, and
// it runs on the canvas, so the card's 3D stage stays frozen while the device
// moves (CardHolo).

const vec2 HOLO_STAGE = vec2(200.0, 264.0);   // card + 24 px pad each side
const vec2 HOLO_PAD = vec2(24.0, 24.0);
const vec2 HOLO_CARD = vec2(152.0, 216.0);
const float HOLO_RADIUS = 11.0;
const vec4 HOLO_ART = vec4(2.0, 2.0, 148.0, 91.0); // x, y, w, h in card px

// The motion every recipe reads: -1..1 on both axes, the device or pointer
// lean already calibrated, smoothed and clamped (HoloMotion), plus the held
// card's own tilt. x leans right, y leans toward the player.
uniform vec2 tilt = vec2(0.0);
// Where the card's whole stage lies in this draw's UV: (origin, extent). The
// identity for a picture drawn over the whole stage; a cropped bake drawn
// past its edges (CardView._Crop) runs its UV beyond 0..1 (CardHolo.crop_uv).
uniform vec4 stage_uv = vec4(0.0, 0.0, 1.0, 1.0);

vec2 holo_cp(vec2 uv) {
	return (uv - stage_uv.xy) / stage_uv.zw * HOLO_STAGE - HOLO_PAD;
}

// A shift of `px` card px, in this draw's UV.
vec2 holo_uv_of(vec2 px) {
	return px / HOLO_STAGE * stage_uv.zw;
}

float holo_rrect(vec2 cp, vec2 lo, vec2 hi, float r) {
	vec2 c = (lo + hi) * 0.5;
	vec2 h = (hi - lo) * 0.5;
	vec2 q = abs(cp - c) - h + vec2(r);
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	return 1.0 - smoothstep(-0.6, 0.6, d);
}

float holo_face(vec2 cp) {
	return holo_rrect(cp, vec2(0.0), HOLO_CARD, HOLO_RADIUS);
}

float holo_art(vec2 cp) {
	return holo_rrect(cp, HOLO_ART.xy, HOLO_ART.xy + HOLO_ART.zw, 1.0);
}

// Distance inward from the card's edge, in card px (0 on the cut).
float holo_inset(vec2 cp) {
	vec2 h = HOLO_CARD * 0.5;
	vec2 q = abs(cp - h) - h + vec2(HOLO_RADIUS);
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - HOLO_RADIUS;
	return -d;
}

vec3 holo_rainbow(float x) {
	return 0.5 + 0.5 * cos(6.2831853 * (x + vec3(0.0, 0.333, 0.667)));
}

float holo_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 holo_hash2(vec2 p) {
	float a = holo_hash(p);
	return vec2(a, holo_hash(p + a + 17.0));
}

float holo_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(holo_hash(i), holo_hash(i + vec2(1.0, 0.0)), u.x),
		mix(holo_hash(i + vec2(0.0, 1.0)), holo_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float holo_luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 holo_screen(vec3 base, vec3 add) {
	return 1.0 - (1.0 - base) * (1.0 - clamp(add, 0.0, 1.0));
}

// THE COST CRYSTAL (CardView's stone) stands ABOVE every hologram (owner,
// 14 Oct 2026): a recipe lays the picture back over its footprint last, so no
// holo line crosses it and nothing dims it, and lights it with its own small
// glint instead (`holo_gem_keep`). A pointy-top hexagon GEM = 36 card px tall
// (CardView.GEM, HEX), centred at card px (10, 10) where CardView.GEM_AT
// stands it (it overhangs the corner by PAD_IN), grown by its bevel and the
// hover tilt's drift. tests/test_card_holo.gd holds these to CardView's.
const vec2 HOLO_GEM_C = vec2(10.0, 10.0);
const float HOLO_GEM_IN = 15.48;   // inradius across the flats, 0.43 * 36
const float HOLO_GEM_GROW = 2.0;

// 1 on the crystal, 0 off it, soft over one px.
float holo_gem(vec2 cp) {
	vec2 p = abs((cp - HOLO_GEM_C).yx);
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * HOLO_GEM_IN, k.z * HOLO_GEM_IN), HOLO_GEM_IN);
	float d = length(p) * sign(p.y) - HOLO_GEM_GROW;
	return 1.0 - smoothstep(-0.5, 0.5, d);
}

// Where a point lies across the crystal along `dir`, about -1..1 corner to
// corner: a glint band's coordinate.
float holo_gem_along(vec2 cp, vec2 dir) {
	return dot(cp - HOLO_GEM_C, normalize(dir)) / 18.0;
}

// `col` (a recipe's result) with the crystal laid back over it as the picture
// drew it, screened by `glint` (the recipe's own, 0 for none) on its light
// gold facets only: the numeral's dark ink never takes it.
vec3 holo_gem_keep(vec3 col, vec3 base, vec2 cp, vec3 glint) {
	float facet = smoothstep(0.35, 0.60, holo_luma(base));
	return mix(col, holo_screen(base, glint * facet), holo_gem(cp));
}
