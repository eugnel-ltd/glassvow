shader_type canvas_item;
// THE PICTURE TURN (issue #657): a card turned over on the canvas, with no
// viewport rendering. It is drawn on CardView's own picture node, the frozen
// stage render (the card plus PAD_3D on every side), and each fragment casts
// the ray the card's stage camera would cast into the slab turned by `pose`
// and lifted by `lift`. Both are what the live turn puts on the slab (the
// turn's CardTurn.pose under the pointer's tilt, and the hover's lift), so the
// two renderers agree on where every point of the card lands.
//
// The front face samples the frozen stage, laid on the slab's front plane
// exactly as the camera framed it (1:1 there at rest). The back face samples
// the baked back (CardBacks.Baked.stage, laid out the same way), unmirrored
// as seen from behind, as the slab's back plate is; with no back baked it is
// clear, as the live turn's slab is without its plate. A ray that meets the
// slab's rim between its faces paints the stock's cross-section, flat, as the
// slab's unshaded side band does, and the rim's edges are smoothed over the
// pixel as the live stage's multisampling smooths them.
//
// What it cannot do is light the turned card: the material is a picture of
// the card at rest, so a finish does not answer the angle. That is what the
// live turn is for. Nothing here reads TIME; the pose is the only input.

uniform sampler2D back_tex : filter_linear, repeat_disable, hint_default_transparent;
// The slab's rotation, in the stage's axes: x right, y up, z toward the lens.
uniform mat3 pose = mat3(1.0);
// How far the slab stands toward the lens (the hover's lift), in card px.
uniform float lift = 0.0;
// The stage camera's distance to the slab's front face at rest, in card px.
uniform float lens = 748.6;
// This node's rect in card px: the card plus PAD_3D on every side.
uniform vec2 rect = vec2(200.0, 264.0);
uniform vec2 half_card = vec2(76.0, 108.0);
uniform float radius = 11.0;
uniform float thick = 7.0;
uniform vec4 side : source_color = vec4(0.5, 0.5, 0.5, 1.0);

// The card's modulate (an unplayable card's dim, the will-burn warmth) rides
// in on the vertex colour; the texture's share is sampled here instead.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

// Signed distance to the card's outline, in card px.
float outline(vec2 p) {
	vec2 q = abs(p) - (half_card - vec2(radius));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

// The outline's outward normal nearest `p`, for a point outside it.
vec2 outward(vec2 p) {
	vec2 q = abs(p) - (half_card - vec2(radius));
	vec2 n = q.x > 0.0 && q.y > 0.0 ? normalize(q) : (q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
	return n * sign(p);
}

bool inside(vec2 uv) {
	return uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
}

void fragment() {
	vec2 s = (UV - 0.5) * rect;
	s.y = -s.y;
	// One screen pixel per unit of ray length, in card px across the ray:
	// the rim's smoothing measures in it. Taken before any branch.
	float pixel = max(length(dFdx(s)), length(dFdy(s))) / length(vec3(s, lens));
	// One texel of the face pictures, in card px on their planes.
	float texel = rect.x / float(textureSize(TEXTURE, 0).x);
	float hz = thick * 0.5;
	// The lens and the ray, carried into the slab's own frame.
	mat3 back_to_slab = transpose(pose);
	vec3 o = back_to_slab * vec3(0.0, 0.0, hz + lens - lift);
	vec3 d = back_to_slab * normalize(vec3(s, -lens));

	// The face the lens is in front of, as a picture on its plane.
	vec4 face = vec4(0.0);
	if (abs(o.z) > hz && abs(d.z) > 1e-6) {
		bool front = o.z > 0.0;
		float t = ((front ? hz : -hz) - o.z) / d.z;
		vec3 p = o + d * t;
		vec2 uv = vec2(front ? p.x : -p.x, -p.y) / rect + 0.5;
		if (t > 0.0 && inside(uv)) {
			face = front ? textureLod(TEXTURE, uv, 0.0) : textureLod(back_tex, uv, 0.0);
		}
	}

	// The rim: how much of the pixel the side band covers, along the ray's
	// run between the two face planes, traced on the outline's distance.
	float cover = 0.0;
	if (abs(d.z) > 1e-6 || abs(o.z) <= hz) {
		float t0 = 0.0;
		float t1 = 1e6;
		if (abs(d.z) > 1e-6) {
			float ta = (-hz - o.z) / d.z;
			float tb = (hz - o.z) / d.z;
			t0 = max(min(ta, tb), 0.0);
			t1 = max(ta, tb);
		}
		float run = max(length(d.xy), 1e-4);
		float entry = outline((o + d * t0).xy);
		if (entry < 0.02) {
			// In through the face on the lens's side, which the picture above
			// covers. Its outline's own soft texels let through what a ray
			// just outside meets: the side, where the run heads inward.
			float beyond = min(t0 + texel / run, t1);
			if (entry > -1.5 * texel && outline((o + d * beyond).xy) < entry) {
				cover = 1.0;
			}
		} else {
			float t = t0;
			float nearest = entry;
			float at = t0;
			for (int i = 0; i < 32 && t <= t1; i++) {
				vec3 p = o + d * t;
				float gap = outline(p.xy);
				if (gap < 0.02) {
					// On the side. Near its far edge, which the side's outer
					// edge always is, the half pixel inside is covered in part.
					cover = 1.0;
					if (t1 < 1e5) {
						float lean = abs(dot(outward(p.xy), d.xy));
						float across = abs((o + d * t1).z - p.z) * lean
							/ max(length(vec2(d.z, lean)), 1e-6);
						cover = clamp(0.5 + across / (pixel * t), 0.5, 1.0);
					}
					break;
				}
				if (gap < nearest) {
					nearest = gap;
					at = t;
				}
				t += gap / run;
			}
			if (cover == 0.0 && t1 < 1e5) {
				float last = outline((o + d * t1).xy);
				if (last < nearest) {
					nearest = last;
					at = t1;
				}
			}
			// A ray that passes the slab closest beyond its first face plane
			// passes the side's outer edge, and the half pixel outside that
			// edge is covered in part. Between the planes the ray runs along
			// the side there, so the gap is its distance from it; at the far
			// plane it passes that face's edge, and the gap in the plane
			// shrinks across the ray by how steeply the ray crosses it.
			// Passing closest AT the first plane, it passes the lens-side
			// face's own edge, which that face's picture already softens.
			if (cover == 0.0 && nearest < entry - 1e-3) {
				float across = nearest;
				if (at == t1) {
					float slope = length(vec2(d.z, dot(outward((o + d * t1).xy), d.xy)));
					across *= abs(d.z) / max(slope, 1e-6);
				}
				cover = clamp(0.5 - across / (pixel * at), 0.0, 0.5);
			}
		}
	}
	vec4 rim = vec4(side.rgb, side.a * cover);

	// The picture over the rim: the face is the slab's outermost surface on
	// the lens's side, so only its own transparent texels let the rim show.
	float a = face.a + rim.a * (1.0 - face.a);
	vec3 rgb = (face.rgb * face.a + rim.rgb * rim.a * (1.0 - face.a)) / max(a, 1e-5);
	COLOR = vec4(rgb, a) * tint;
}
