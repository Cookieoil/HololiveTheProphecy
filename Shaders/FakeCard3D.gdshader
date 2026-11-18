// res://Shaders/FakeCard3D.gdshader
shader_type canvas_item;
render_mode unshaded;

// ---------------------------------------------------------------------------
// Fake-3D card warp (Legends of Runeterra style flip, no real 3D involved).
//
// The quad never moves or resizes: every pixel is ray-cast from a virtual
// pinhole camera through the card plane, so the texture inside the quad is
// perspective-warped into a true 3D trapezoid. Because the projection is an
// exact ray/plane intersection the card is pixel-identical to a plain quad when
// x_rot and y_rot are both 0, whatever the field of view.
//
//   camera -> origin, looking down +Z
//   card   -> centred on (0, 0, depth), rotated by Ry(yaw) * Rx(pitch)
//   image  -> the quad itself, so the unrotated mapping is exactly 1:1
//
// `quad_size` is the padded quad in logical pixels and must match the
// SubViewport's logical size. The padding is what keeps the stretched near
// corners of a strongly tilted card inside the quad instead of clipping them.
// `card_size` is the visible card body centred inside that padding.
//
// The printed side samples TEXTURE (the SubViewport holding the whole card).
// The back side paints an ornate procedural card back on the very same 3D
// plane, so flipping past 90 degrees never seams, pops or z-fights.
// ---------------------------------------------------------------------------

// Field of view measured across the card width. Lower = stronger perspective.
uniform float fov : hint_range(10.0, 170.0) = 20.0;
// Yaw (flip) and pitch (tilt) in degrees.
uniform float y_rot : hint_range(-180.0, 180.0) = 0.0;
uniform float x_rot : hint_range(-180.0, 180.0) = 0.0;

uniform vec2 quad_size = vec2(140.0, 185.0);
uniform vec2 card_size = vec2(100.0, 145.0);
uniform float corner_radius = 6.0;
uniform float edge_softness : hint_range(0.0, 3.0) = 1.0;

// Paint the procedural card back while the printed side faces away.
uniform bool draw_back = true;

// Strength of the metallic sheen that sweeps the surface as the card tilts.
// A dead flat card gets none, so the resting card stays exactly as designed.
uniform float glint_strength : hint_range(0.0, 2.0) = 0.55;

// Card back palette.
uniform vec4 back_deep : source_color = vec4(0.035, 0.042, 0.105, 1.0);
uniform vec4 back_mid : source_color = vec4(0.115, 0.135, 0.295, 1.0);
uniform vec4 back_gold : source_color = vec4(0.965, 0.795, 0.400, 1.0);
uniform vec4 back_cyan : source_color = vec4(0.470, 0.890, 1.000, 1.0);

// The built-in fragment COLOR already has TEXTURE baked in, and the card is
// sampled at a warped UV, so the CanvasItem modulate (and every inherited one)
// is carried across by hand.
varying vec4 v_modulate;
// Plane-local ray for this pixel. It is linear in UV, so interpolation between
// the four quad corners is exact.
varying vec3 v_ray;

mat3 card_rotation() {
	float cy = cos(radians(y_rot));
	float sy = sin(radians(y_rot));
	float cx = cos(radians(x_rot));
	float sx = sin(radians(x_rot));
	mat3 yaw = mat3(
		vec3(cy, 0.0, -sy),
		vec3(0.0, 1.0, 0.0),
		vec3(sy, 0.0, cy)
	);
	mat3 pitch = mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, cx, sx),
		vec3(0.0, -sx, cx)
	);
	return yaw * pitch;
}

// Distance from the pinhole camera to the card centre, in logical pixels.
float camera_depth() {
	return 0.5 * card_size.x / max(tan(radians(fov) * 0.5), 0.0001);
}

float sd_rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void vertex() {
	v_modulate = COLOR;
	v_ray = transpose(card_rotation()) * vec3((UV - 0.5) * quad_size, camera_depth());
}

// Ornate lacquered back, drawn directly on the warped plane.
// `p` is the card-local pixel offset, `card_uv` the matching 0..1 coordinate.
vec4 card_back_color(vec2 p, vec2 card_uv, float glint) {
	float sd = sd_rounded_box(p, card_size * 0.5 - vec2(0.5), corner_radius);
	float aa = max(fwidth(sd), 0.6) * edge_softness;
	float body = 1.0 - smoothstep(-aa, aa, sd);
	if (body <= 0.001) {
		return vec4(0.0);
	}

	// Radial coordinate that respects the card aspect ratio.
	vec2 cc = card_uv - 0.5;
	vec2 shaped = cc * vec2(1.0, card_size.x / card_size.y);
	float radial = length(shaped);

	// Deep lacquer base with a soft core falloff.
	vec3 col = mix(back_mid.rgb, back_deep.rgb, smoothstep(0.06, 0.62, radial));

	// Faint diagonal brushed-silk striping.
	float stripes = sin((card_uv.x * 0.62 + card_uv.y * 0.38) * 34.0);
	col += vec3(0.020, 0.028, 0.045) * stripes;

	// Astral compass rings.
	float ring_outer = abs(radial - 0.300);
	float ring_inner = abs(radial - 0.168);
	col = mix(col, back_gold.rgb, (1.0 - smoothstep(0.003, 0.012, ring_outer)) * 0.55);
	col = mix(col, back_gold.rgb, (1.0 - smoothstep(0.002, 0.010, ring_inner)) * 0.40);

	// Eight-point prophecy star in the middle.
	float angle = atan(shaped.y, shaped.x);
	float petals = abs(cos(angle * 4.0));
	float star_radius = 0.052 + 0.125 * petals * petals * petals;
	float star = 1.0 - smoothstep(star_radius - 0.008, star_radius + 0.008, radial);
	col = mix(col, mix(back_cyan.rgb, back_gold.rgb, 0.35), star * 0.90);
	col += back_cyan.rgb * (1.0 - smoothstep(0.0, 0.055, radial)) * 0.45;

	// Corner diamonds.
	vec2 corner = abs(cc) - vec2(0.355, 0.395);
	float diamond = abs(corner.x) + abs(corner.y);
	col = mix(col, back_gold.rgb, (1.0 - smoothstep(0.010, 0.019, diamond)) * 0.55);

	// Gold double frame hugging the silhouette.
	float line_aa = max(fwidth(sd), 0.5);
	col = mix(col, back_gold.rgb, (1.0 - smoothstep(0.0, line_aa * 2.0, abs(sd + 2.4))) * 0.85);
	col = mix(col, back_gold.rgb, (1.0 - smoothstep(0.0, line_aa * 1.8, abs(sd + 6.0))) * 0.40);

	// Edge vignette, so the back reads as a glossy curved object.
	col *= mix(0.60, 1.0, 1.0 - smoothstep(0.20, 0.50, radial));

	// Lacquer sheen from the same tilt-driven glint as the printed side.
	col += vec3(1.0, 0.98, 0.92) * glint * 1.20;

	return vec4(col, body);
}

void fragment() {
	mat3 inv_rot = transpose(card_rotation());
	float depth = camera_depth();
	vec3 center_local = inv_rot * vec3(0.0, 0.0, depth);
	vec3 normal_local = inv_rot[2];

	// v_ray.z is dot(ray, normal): it vanishes exactly when the ray runs
	// parallel to the card plane, i.e. when the card is seen edge on.
	float denom = v_ray.z;
	if (abs(denom) < 0.0001) {
		discard;
	}
	// t < 0 means the intersection sits behind the camera.
	float t = center_local.z / denom;
	if (t <= 0.0) {
		discard;
	}

	// Card-local pixel offset from the card centre, plus its 0..1 twin.
	vec2 p = t * v_ray.xy - center_local.xy;
	vec2 card_uv = p / card_size + 0.5;

	// Metallic sheen. normal_local.xy is 0 while the card is flat, so the
	// resting card is untouched and the highlight only appears while tilting.
	vec2 tilt = normal_local.xy;
	float band = card_uv.x * 0.58 + (1.0 - card_uv.y) * 0.42;
	float sweep = 0.5 + tilt.x * 1.25 + tilt.y * 0.60;
	float falloff = (band - sweep) * 3.4;
	float glint = exp(-falloff * falloff) * glint_strength * clamp(length(tilt) * 1.7, 0.0, 1.0);

	vec4 out_color;
	if (normal_local.z > 0.0) {
		// Printed side: the composited card, perspective-warped.
		out_color = texture(TEXTURE, card_uv);
		out_color.rgb += vec3(1.0, 0.97, 0.90) * (glint * out_color.a);
	} else if (draw_back) {
		out_color = card_back_color(p, card_uv, glint);
		if (out_color.a <= 0.001) {
			discard;
		}
	} else {
		discard;
	}

	COLOR = out_color * v_modulate;
}
