shader_type canvas_item;
// Stained glass lives only while light passes through it. A portrait at
// light = 1 is lit glass: saturated, glowing from within, a warm rim on its
// fire-side edge. At light = 0 it is the same window at night — dark,
// cold, desaturated lead-and-glass. Who speaks is lit (StagePortrait).

uniform float light : hint_range(0.0, 1.0) = 1.0;
uniform float rim : hint_range(0.0, 1.5) = 0.6;
// Direction TOWARD the light source in UV space (+x = the art's right).
uniform vec2 rim_dir = vec2(1.0, -0.35);
uniform vec4 rim_color : source_color = vec4(1.0, 0.64, 0.30, 1.0);
uniform vec4 grade : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
// The bust is cut from a full figure; the cut dissolves instead of edging.
// Texture-space v where the crop ends, and how far up the fade reaches.
uniform float cut_v = 1.0;
uniform float cut_fade = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// Unlit: glass at night keeps its leading and most of its value, and
	// loses its colour toward a cold slate — dim glass, never a void.
	vec3 slate = vec3(0.30, 0.36, 0.50) * (lum * 1.9 + 0.04);
	vec3 night = mix(c.rgb * 0.62, slate, 0.62) * 0.72;
	// Lit: light through the panes lifts saturation and a little value.
	vec3 day = mix(vec3(lum), c.rgb, 1.22) * 1.06;
	vec3 rgb = mix(night, day, light) * grade.rgb;
	// Fire-side rim: opaque pixels whose neighbour toward the light is empty.
	vec2 px = TEXTURE_PIXEL_SIZE * 5.0;
	vec2 dir = normalize(rim_dir);
	float toward = texture(TEXTURE, UV + dir * px).a;
	float toward2 = texture(TEXTURE, UV + dir * px * 2.2).a;
	float edge = clamp(c.a - min(toward, toward2), 0.0, 1.0);
	rgb += rim_color.rgb * edge * rim * (0.25 + 0.75 * light);
	rgb = mix(rgb, flash_color.rgb, flash);
	float keep = cut_fade > 0.0 ? smoothstep(cut_v, cut_v - cut_fade, UV.y) : 1.0;
	COLOR = vec4(rgb, c.a * keep) * COLOR;
}
