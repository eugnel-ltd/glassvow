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
