shader_type canvas_item;
// THE FLAME IN THE LANTERN (issue #577, lock PR 5). `LanternFlame` drives it on
// the combat HUD's lantern and on the reward and shop screens' `RunLantern`.
//
// The Duskblade's lantern burns whatever glass the hero carries (design lock,
// docs/design/2026-09-29-dusk-flame/README.md §1 and §9). This material goes on
// the lantern ART, the HUD's own TextureRect over assets/art/ui/lantern.png, and
// lights it from the inside: the panes take the flame's colour, the flame
// stands behind them, and the iron stays iron. One quad, one pass, no new node.
//
// THE READING, tweened by LanternFlame over about a second and never snapped:
//   dominant_colour  the way's colour, or Kindling's orange, or Soot's dust.
//   fringe_colour    the second way, drawn at the tips and the outer flanks.
//   fringe_amount    how much of it shows; 0 is no fringe.
//   stability        0 is Soot guttering, 1 is True still. Lean, shiver, the
//                    gasps, the ragged edge, Soot's murk and ash, and True's
//                    halo are all READ from it, so the tier needs no input of
//                    its own.
//   height           the tier's height, as a share of the tallest flame the
//                    glass can hold.
//   shape_weights    the way: x Shatter, y Lantern, z Edge, w the plain flame
//                    that has declared no way. Weights rather than an index,
//                    so a tween between two ways morphs straight across and
//                    never passes through the third.
//   painted          how much of the lantern's own painted light shows
//                    through the glass instead of the relit flame: 1 is the
//                    lantern exactly as painted, which is Kindling (lock §5,
//                    "today's game"); 0 is every tier with a reading of its
//                    own to show.
//
// EACH WAY IS DRAWN AT THE SIZE OF THE WHOLE GLASS. At HUD size the centre pane
// is about twelve pixels wide on a pad and eight on a phone. A flame drawn in
// that pane alone is a smudge. So a way is a figure the three lights carry
// together: Shatter throws sharp tongues out into the side lights, the
// Lantern's hearth fills the foot of all three, and Edge is one thin blade in
// the centre with the side lights left dark. A silhouette at that scale
// survives a phone and a greyscale screen. The glass away from the figure is
// kept deep and dim for the same reason: a bright figure on dark glass is
// legible at eight pixels, a bright figure on bright glass is not.
//
// THE LOOK is leaded: the flame stands behind the glass, soft-edged, carried by
// the glass's own streaks and crossed by every lead line in the pane. The
// spike's second look (a cut-glass tongue with a came of its own) stays in the
// spike's history rather than here.

uniform vec4 dominant_colour : source_color = vec4(1.0, 0.56, 0.23, 1.0);
uniform vec4 fringe_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fringe_amount : hint_range(0.0, 1.0) = 0.0;
uniform float stability : hint_range(0.0, 1.0) = 0.42;
uniform float height : hint_range(0.0, 1.0) = 0.55;
uniform vec4 shape_weights = vec4(0.0, 0.0, 0.0, 1.0);
uniform float painted : hint_range(0.0, 1.0) = 1.0;
// Seconds. Driven by LanternFlame rather than read from TIME, so a still is
// the same still every time it is taken.
uniform float clock = 0.0;

// ── the set-out, in the art's own UV ────────────────────────────────────────
// Where the flame stands: the foot of the centre pane.
const vec2 WICK = vec2(0.5, 0.785);
// The tallest flame the glass holds (True), as a share of the art. Flame space
// below is measured in this unit, from the wick, y up. In it the centre light
// spans |x| < 0.21, the iron mullions 0.21 to 0.36 and the side lights 0.36 to
// 0.57.
const float REACH = 0.29;
// The box the panes stand in (x0, y0, x1, y1). The bronze glints on the hood
// and the foot are warm too; outside this box they are left as they are.
const vec4 PANES = vec4(0.31, 0.43, 0.69, 0.795);
// Soot's dust: pale ash, so a fleck still shows against the dark brown glass.
const vec3 ASH = vec3(0.62, 0.57, 0.52);
// How far the painted light flickers at full unrest. The Kindling lantern must
// read as the painted one (lock §5) and still be livelier than a calm Steady
// flame, so the flicker is small and quick, like a candle's: amplitude costs
// parity, speed buys life. docs/design/2026-09-29-dusk-flame/hud/ measures both.
const float PAINTED_BREATH = 0.07;


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


float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}


// The art's glass is the only warm, saturated, bright thing on the lantern:
// amber at about (0.87, 0.52, 0.05), where the iron is dark and dull. So "is
// this glass" is a question the pixel can answer about itself.
float glass_of(vec3 c) {
	return smoothstep(0.26, 0.48, c.r - c.b) * smoothstep(0.30, 0.52, max(c.r, max(c.g, c.b)));
}


// A flame of height `h` and half-width `w` rooted at the origin: the profile
// s^a (1-s)^b, normalised so `w` is its widest. a < 1 rounds the foot; b > 1
// draws the tip to a point and b < 1 leaves it blunt. Negative inside;
// outside it is roughly the distance, which is all the edge and the glow need.
float profile(vec2 p, float h, float w, float a, float b) {
	float s = p.y / h;
	if (s <= 0.0) {
		return length(p);
	}
	if (s >= 1.0) {
		return length(p - vec2(0.0, h));
	}
	float peak = pow(a / (a + b), a) * pow(b / (a + b), b);
	return abs(p.x) - w * pow(s, a) * pow(1.0 - s, b) / peak;
}


// One shard of Shatter's crown, straight-sided from a round root `w` half-wide
// to a point at `tip`.
float shard(vec2 p, vec2 root, vec2 tip, float w) {
	vec2 axis = tip - root;
	float len = length(axis);
	vec2 dir = axis / len;
	vec2 d = p - root;
	float s = dot(d, dir) / len;
	if (s <= 0.0) {
		return length(d) - w;
	}
	if (s >= 1.0) {
		return length(p - tip);
	}
	return abs(d.x * dir.y - d.y * dir.x) - w * (1.0 - s);
}


// 碎 Shatter, 霜焰: sharp tongues. A crown of five straight shards: one tall in
// the centre light, and two a side leaning out across the iron so their points
// stand in the side lights.
float shatter(vec2 p, float h) {
	float spread = mix(0.8, 1.0, h);
	float f = shard(p, vec2(0.0, -0.03), vec2(0.0, h), 0.11);
	f = min(f, shard(p, vec2(-0.06, -0.03), vec2(-0.42 * spread, 0.74 * h), 0.085));
	f = min(f, shard(p, vec2(0.06, -0.03), vec2(0.43 * spread, 0.70 * h), 0.085));
	f = min(f, shard(p, vec2(-0.12, -0.03), vec2(-0.53 * spread, 0.44 * h), 0.07));
	return min(f, shard(p, vec2(0.12, -0.03), vec2(0.54 * spread, 0.41 * h), 0.07));
}


// 燼 Lantern, 熾焰: a round hearth. A broad, blunt-topped flame on a bed of
// fire that fills the foot of all three lights.
float hearth(vec2 p, float h) {
	float bulb = profile(p, 0.78 * h, 0.40, 0.42, 0.55);
	float bed = (length((p - vec2(0.0, 0.10)) / vec2(0.68, 0.30)) - 1.0) * 0.3;
	return smin(bulb, bed, 0.08);
}


// 蝕 Edge, 蝕焰: thin and tall. One blade in the centre light, taller than any
// other flame of its tier, with nothing in the side lights.
float blade(vec2 p, float h) {
	return profile(p, min(1.1 * h, 1.05), 0.12, 0.4, 1.35);
}


// The plain flame, before any way is declared: a candle's teardrop. Kindling
// shows the painted light over it (`painted`), so this is the flame Soot
// gutters, and the one a tween out of Kindling grows from.
float candle(vec2 p, float h) {
	return profile(p, 0.86 * h, 0.15, 0.5, 0.9);
}


// Edge to heart: the colour itself at the flame's edge, burning towards white
// at its core. A flame is the brightest thing in the lantern at every heat.
vec3 ramp(vec3 c, float heat) {
	return mix(c, vec3(1.0), 0.1 + 0.55 * heat) * (1.0 + 0.12 * heat);
}


varying vec4 tint;

void vertex() {
	// The node's modulate (the HUD dims an unlit lantern and fades a spent one)
	// arrives here; fragment() rebuilds COLOR from the texture, so it is carried.
	tint = COLOR;
}


void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 in_box = step(PANES.xy, UV) * step(UV, PANES.zw);
	float glass = glass_of(art.rgb) * in_box.x * in_box.y;
	// The glass's own streaks and quarries, as a gain around its mean.
	float grain = clamp(max(art.r, max(art.g, art.b)) / 0.87, 0.0, 1.3);

	// ── the flame's motion, all of it read from stability ──
	float t = clock;
	float unrest = 1.0 - stability;
	float lean = unrest * (0.10 * sin(t * 1.9) + 0.05 * sin(t * 3.4 + 1.1) + 0.03 * sin(t * 6.3 + 0.7));
	float shiver = unrest * (0.045 * sin(t * 9.1) + 0.03 * sin(t * 13.7 + 2.3));
	// Guttering: below Kindling the flame gasps, dropping half its height for
	// about half a second every three or so and coming back. The beat of two
	// unrelated sines keeps the gasps from falling on a metronome.
	float gutter = smoothstep(0.34, 0.0, stability);
	float gasp = gutter * smoothstep(0.5, 0.95, sin(t * 2.9) * sin(t * 0.77 + 1.9));
	float h = height * (1.0 + shiver) * (1.0 - 0.5 * gasp);

	// Flame space: from the wick, y up, in units of REACH. The lean bends the
	// flame from its root, so the tip travels and the wick does not.
	vec2 q = vec2(UV.x - WICK.x, WICK.y - UV.y) / REACH;
	vec2 p = vec2(q.x - lean * q.y * q.y * 1.4, q.y);

	vec4 w = shape_weights / max(dot(shape_weights, vec4(1.0)), 0.0001);
	float field = w.x * shatter(p, h) + w.y * hearth(p, h) + w.z * blade(p, h) + w.w * candle(p, h);
	// A torn edge that climbs the flame, only at the unsteady end of the scale.
	float ragged = smoothstep(0.55, 0.0, stability);
	field += ragged * 0.06 * (vnoise(vec2(p.x * 9.0, p.y * 6.0 - t * 2.4)) - 0.5);

	// ── colour: body, core and the fringe at the tips ──
	vec3 dom = dominant_colour.rgb;
	vec3 fringe = fringe_colour.rgb;
	float core_depth = dot(w, vec4(0.10, 0.16, 0.05, 0.085));
	float up = clamp(p.y / max(h, 0.001), 0.0, 1.0);
	float heat = clamp(-field / core_depth, 0.0, 1.0) * (1.0 - 0.5 * smoothstep(0.25, 1.0, up));
	// The light right round the flame. Edge's reaches the width of the centre
	// light, so a thin blade still lights a whole column. The fringe burns on
	// the flame's outer, upper flesh and in this light, never across the far
	// glass: the dominant colour stays the read.
	float near = exp(-max(field, 0.0) / (0.09 * (1.0 + 0.8 * w.z)));
	float tips = fringe_amount * smoothstep(0.05, 0.45, up) * (1.0 - smoothstep(0.15, 0.6, heat));

	// ── the light the flame throws on the glass: deep away from it, a tight
	// glow at its edge, so the figure stands out of the lantern ──
	float breath = 1.0 + 0.03 * sin(t * 1.7);
	float flare = 1.0 + unrest * 0.12 * sin(t * 7.3 + 0.4) - 0.35 * gasp;
	float lum = mix(0.75, 1.0, height) * breath * flare;
	// The flame's own brightness: a guttering flame is a dull one.
	float glare = lum * (1.0 - 0.35 * gutter);
	float halo = smoothstep(0.9, 1.0, stability);
	// How much light fills the far glass is part of each way's figure: the
	// hearth fills the lantern, Edge's eclipse leaves the side lights dark, and
	// Soot's glass is murky with dust rather than clear and dark.
	float fill = mix(0.14, 0.22, height) * dot(w, vec4(1.0, 1.35, 0.4, 1.0)) + 0.16 * gutter;
	float light = fill + 0.42 * near;
	// True: the light evens out a little and a faint ring stands round the
	// flame's head, a nimbus, the way a saint is marked in a window.
	// Squared by hand: pow() of a negative base is undefined in GLSL.
	float off_ring = (length((p - vec2(0.0, 0.62 * h)) * vec2(1.0, 0.9)) - 0.46) / 0.05;
	float ring = exp(-off_ring * off_ring);
	light = clamp(light + halo * (0.08 + 0.32 * ring), 0.0, 1.0);
	vec3 glow = mix(dom, fringe, tips * near * 0.8);
	vec3 lit = mix(glow * glow * 0.8, glow, light) * (0.15 + light) * lum;

	// The flame is only ever seen through the glass.
	float soft = max(fwidth(field) * 1.5, 0.02);
	float inside = 1.0 - smoothstep(-soft, soft, field);
	vec3 flame = mix(ramp(dom, heat), ramp(fringe, heat), tips);
	vec3 through = mix(lit * mix(1.0, grain, 0.7), flame * glare * mix(1.0, grain, 0.3), inside);
	// Kindling: the lantern as it is painted, its own amber light in every
	// pane, flickering a little with the flame's unrest so it is alive.
	float flicker = 1.0 + unrest * PAINTED_BREATH
			* (0.5 * sin(t * 7.3 + 0.4) + 0.3 * sin(t * 11.9 + 1.3) + 0.2 * sin(t * 19.7 + 2.1));
	through = mix(through, art.rgb * flicker, painted);
	vec3 rgb = mix(art.rgb, through, glass);

	// ── Soot throws dust: flecks of ash rising off the flame across the glass,
	// inside the lantern, so they never read as one more ember pip ──
	float motes = smoothstep(0.3, 0.0, stability);
	if (motes > 0.001) {
		float r = max(0.022, fwidth(q.x) * 1.1);
		float fleck = 0.0;
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			float period = 1.9 + 0.61 * fi;
			float ph = fract(t / period + hash(vec2(fi, 1.7)));
			float life = smoothstep(0.0, 0.1, ph) * (1.0 - smoothstep(0.5, 0.7, ph));
			vec2 at = vec2((hash(vec2(fi, 5.3)) - 0.5) * 0.4
					+ sin(t * (1.1 + 0.3 * fi) + fi * 2.0) * 0.07 * ph, h * 0.5 + ph * 0.9);
			fleck = max(fleck, life * (1.0 - smoothstep(r * 0.6, r * 1.25, length(q - at))));
		}
		rgb = mix(rgb, ASH, fleck * motes * glass * 0.8);
	}

	// ── True's halo also spills past the iron: a faint aura behind the lantern ──
	vec2 from_heart = (UV - vec2(0.5, 0.63)) / vec2(0.27, 0.33);
	float aura = halo * 0.30 * (1.0 - smoothstep(0.35, 1.0, length(from_heart)));
	vec3 aura_rgb = mix(dom, vec3(1.0), 0.3) * lum;
	float alpha = art.a + aura * (1.0 - art.a);
	rgb = (rgb * art.a + aura_rgb * aura * (1.0 - art.a)) / max(alpha, 0.0001);

	COLOR = vec4(rgb, alpha) * tint;
}
