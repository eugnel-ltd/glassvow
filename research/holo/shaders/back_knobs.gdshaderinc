// Per-BACK knobs (owner, 14 Oct: each back has its own hologram, tuned to its
// painting; a back looks the same on every card whatever the card's rarity).
// Every direction reads these; each back sets its own values (HoloLab
// BACK_KNOBS). The defaults are only placeholders, never a shared tune.

uniform int band_mode = 0;          // 0 linear stripe, 1 rings from centre, 2 sweep round centre
uniform float band_angle = 35.0;    // degrees, linear mode
uniform vec2 centre = vec2(76.0, 108.0);   // card px: the painting's focus
uniform vec3 palette = vec3(1.0);   // multiplies the spectrum: the back's own hue range
uniform float palette_mix = 0.0;    // 0 full spectrum .. 1 the palette alone
uniform float strength = 0.5;
uniform float scale = 1.0;          // the direction's own pitch, scaled per back

// The band coordinate for this back's geometry, in "card widths".
float back_band(vec2 cp) {
	vec2 c = cp - centre;
	if (band_mode == 1) {
		return length(c) / 152.0;
	} else if (band_mode == 2) {
		return atan(c.y, c.x) / 6.2831853;
	}
	float a = radians(band_angle);
	return dot(c, vec2(cos(a), sin(a))) / 152.0;
}

// The tilt's push on the band, in the same units.
float back_slide(vec2 cp) {
	vec2 c = cp - centre;
	if (band_mode == 1) {
		return dot(tilt, vec2(0.30, 0.22));
	} else if (band_mode == 2) {
		return atan(tilt.y, tilt.x + 1e-4) / 6.2831853 * clamp(length(tilt) * 1.4, 0.0, 1.0);
	}
	float a = radians(band_angle);
	return dot(tilt, vec2(cos(a), sin(a))) * 0.42;
}

vec3 back_spectrum(float x) {
	vec3 rb = holo_rainbow(x);
	return mix(rb, palette * (0.55 + 0.45 * holo_luma(rb) * 1.6), palette_mix);
}
