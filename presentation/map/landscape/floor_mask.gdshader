shader_type spatial;
// The floor bake's mask (R3.2, `floor_bake.gd`): what the runtime floor
// (`floor.gdshader`) keeps alive in the baked picture, at 10 texels a metre.
// r: how much of a texel's light is a lamp's pool, which flickers with it;
// g: the flicker phase of the lamp that lights it most (its flame's own);
// b: the wet, where puddles glint. Unshaded, through a linear tonemap at
// exposure 1, so each value is written as the sRGB curve's inverse and lands
// in the texture as itself.
render_mode unshaded, cull_back, fog_disabled;
#include "res://presentation/map/landscape/floor_ground.gdshaderinc"

// The light a pool must give to be half of what a texel shows (the key and
// the sky on open ground, in the same units as `floor_pools`).
uniform float pool_half = 0.9;
varying vec3 world_at;
varying vec3 world_normal;

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec3 as_stored(vec3 value) {
	return mix(value / 12.92, pow((value + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), value));
}

void fragment() {
	Floor f = floor_at(world_at.xz, world_at.y, world_normal);
	vec2 pools = floor_pools(world_at, world_normal);
	float share = pools.x / (pools.x + pool_half);
	ALBEDO = as_stored(clamp(vec3(share, pools.y, f.wet), 0.0, 1.0));
}
