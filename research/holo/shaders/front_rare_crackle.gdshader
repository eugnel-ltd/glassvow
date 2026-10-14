shader_type canvas_item;
// FRONT, RARE: "cut glass" (v2 of crackle). The art window is a mosaic of
// ~12 px shards of cut, dichroic glass. The art shows THROUGH each shard,
// refracted a little by its own lean; each shard's bevelled edges catch the
// light as thin bright lines whose strength follows how the facet faces the
// tilt; a spectral flare runs along the lit facets. No flat fills anywhere.
#include "res://research/holo/shaders/holo_common.gdshaderinc"

const float SHARD_PX = 12.0;
const float REFRACT_PX = 1.6;     // how far a shard shifts the art behind it
const float EDGE = 0.09;         // bevel half-width, in cells
const float FLARE = 0.20;         // spectral flare reach from the edge, in cells
const float EDGE_GAIN = 1.15;
const float FLARE_GAIN = 0.85;
const float DICHROIC = 0.10;      // per-shard tint toward its jewel
const float SHARD_FLASH = 0.80;   // extra jewel on a shard that faces the light
// The room light is off the view axis, so a card held still still has lit
// facets: the lean the light sees is the tilt plus this offset.
const vec2 ROOM = vec2(0.45, -0.35);

void fragment() {
	vec2 lt = tilt + ROOM;
	vec2 cp = holo_cp(UV);
	float face = holo_face(cp);
	float m = face * holo_art(cp);
	vec2 g = cp / SHARD_PX;
	vec2 gi = floor(g);
	vec2 gf = fract(g);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 p1 = vec2(0.0);
	vec2 p2 = vec2(0.0);
	vec2 c1 = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 pt = o + holo_hash2(gi + o);
			float dd = length(pt - gf);
			if (dd < d1) { d2 = d1; p2 = p1; d1 = dd; p1 = pt; c1 = gi + o; }
			else if (dd < d2) { d2 = dd; p2 = pt; }
		}
	}
	// the art through the shard, refracted by the shard's own lean
	vec2 lean = (holo_hash2(c1 + 9.1) - 0.5) * 2.0;
	vec2 shift = (lean * 0.6 + tilt * 0.4) * REFRACT_PX * m / HOLO_STAGE;
	vec3 art = texture(TEXTURE, UV + shift).rgb;
	vec4 base = texture(TEXTURE, UV);
	// dichroic: each shard leans toward one of two jewels, by tilt
	vec3 jewel = mix(vec3(0.35, 0.65, 1.0), vec3(1.0, 0.55, 0.30),
		smoothstep(-0.4, 0.4, dot(lt, normalize(lean + 0.001)) + holo_hash(c1) - 0.5));
	// a shard whose lean meets the tilt flashes its jewel THROUGH the art
	// (multiplied, so the picture's detail survives; never a flat fill)
	vec2 rel = lt - lean * 0.8;
	float shard_lit = exp(-dot(rel, rel) * 4.5);
	vec3 glass = mix(art, art * jewel * 1.9, DICHROIC + SHARD_FLASH * shard_lit);
	// the bevel at this shard's edge faces AWAY from its neighbour (-fn): it
	// catches the light on the side the card leans toward and falls into
	// shade on the other, so each seam reads as a cut bevel, not a crack
	float gap = d2 - d1;
	vec2 fn = normalize(p2 - p1 + 1e-4);
	float reach = clamp(length(lt) * 1.4, 0.0, 1.0);
	float facing = dot(-fn, normalize(lt + vec2(0.0001))) * reach;
	float bevel = 1.0 - smoothstep(0.0, EDGE, gap);
	float seam = 1.0 - smoothstep(0.0, EDGE * 0.45, gap);
	float hi = bevel * smoothstep(0.25, 0.85, facing);
	float lo = bevel * smoothstep(0.25, 0.85, -facing);
	float flare_zone = (1.0 - smoothstep(EDGE, FLARE, gap)) * step(EDGE * 0.6, gap);
	vec3 spec = holo_rainbow(gap * 5.0 + dot(fn, vec2(0.3, 0.2)) + dot(lt, vec2(0.6, 0.4)));
	vec3 col = glass * (1.0 - 0.22 * seam);
	col *= 1.0 - 0.35 * lo;
	col = holo_screen(col, spec * flare_zone * smoothstep(0.45, 0.95, facing) * FLARE_GAIN);
	col = holo_screen(col, vec3(1.0, 0.97, 0.92) * hi * EDGE_GAIN);
	COLOR = vec4(mix(base.rgb, col, m), base.a);
}
