shader_type canvas_item;
// THE PICTURE TURN (issue #657): a card turned over on the canvas, with no
// viewport rendering. It is drawn on CardView's own picture node, the frozen
// stage render (the card plus PAD_3D on every side), and each fragment casts
// the ray the card's stage camera would cast into the slab turned by `pose`.
// `pose` is the same Basis the live turn puts on the slab (CardTurn.pose), so
// the two renderers agree on where every point of the card lands.
//
// The front face samples the frozen stage, laid on the slab's front plane
// exactly as the camera framed it (1:1 there at rest). The back face samples
// the baked back (CardBacks.Baked.stage, laid out the same way), unmirrored
// as seen from behind, as the slab's back plate is. A ray that meets the
// slab's rim between its faces paints the stock's cross-section, flat, as the
// slab's unshaded side band does.
//
// What it cannot do is light the turned card: the material is a picture of
// the card at rest, so a finish does not answer the angle. That is what the
// live turn is for. Nothing here reads TIME; the pose is the only input.

uniform sampler2D back_tex : filter_linear, repeat_disable;
// The slab's rotation, in the stage's axes: x right, y up, z toward the lens.
uniform mat3 pose = mat3(1.0);
// The stage camera's distance to the slab's front face, in card px.
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

bool inside(vec2 uv) {
	return uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
}

void fragment() {
	vec2 s = (UV - 0.5) * rect;
	s.y = -s.y;
	float hz = thick * 0.5;
	// The lens and the ray, carried into the slab's own frame.
	mat3 back_to_slab = transpose(pose);
	vec3 o = back_to_slab * vec3(0.0, 0.0, hz + lens);
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

	// The rim: the first point inside the outline along the ray's run between
	// the two face planes, traced on the outline's distance. A ray whose run
	// starts inside the outline came in through a face, which the picture
	// above already covers; one that reaches the outline later meets the side.
	vec4 rim = vec4(0.0);
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
		float t = t0;
		for (int i = 0; i < 32 && t <= t1; i++) {
			float gap = outline((o + d * t).xy);
			if (gap < 0.02) {
				if (i > 0) {
					rim = side;
				}
				break;
			}
			t += gap / run;
		}
	}

	// The picture over the rim: the face is the slab's outermost surface on
	// the lens's side, so only its own transparent texels let the rim show.
	float a = face.a + rim.a * (1.0 - face.a);
	vec3 rgb = (face.rgb * face.a + rim.rgb * rim.a * (1.0 - face.a)) / max(a, 1e-5);
	COLOR = vec4(rgb, a) * tint;
}
