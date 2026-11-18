// res://Shaders/KintsugiWeld.gdshader
shader_type canvas_item;
render_mode unshaded;

// ---------------------------------------------------------------------------
// Kintsugi forge weld.
//
// Two cards in hand are struck edge to edge and fused along a molten seam of
// gold light, the way broken lacquerware is rejoined with kintsugi. This paints
// a jagged procedural fracture down the middle of the card silhouette that
// branches into hairline gold veins, a forge shockwave, and - for a double
// merge - carved crystal facets lifted from the Moxie orb's gemstone work.
// The glow then cools inward until the card face is clean again.
//
// The quad matches CardUI's padded quad, so `card_size` is the visible card
// body centred inside `quad_size`, and the seam runs down that body's middle.
//
//   lowered  progress -> seam ignites            (0.00 .. 0.20)
//   mid      progress -> veins spread + wave     (0.08 .. 0.55)
//   high     progress -> glow cooled away        (0.60 .. 1.00)
//
// It is drawn as an overlay on top of the warped card face, so the alpha is
// fully transparent by the end of the burn and the resting card is untouched.
// ---------------------------------------------------------------------------

// Padded quad and the card body centred inside it (must match CardUI).
uniform vec2 quad_size = vec2(140.0, 185.0);
uniform vec2 card_size = vec2(100.0, 145.0);
uniform float corner_radius = 6.0;

// 0 -> seam ignites, then the veins and the shockwave bloom, then it cools away.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// A double merge fractures the face into gemstone facets and turns the seam
// dual tone (Prophecy cyan + Arcane gold) instead of pure gold.
uniform bool is_double_merge = false;
// Per-forge offset, so no two welds ever crack the same way.
uniform float seam_seed = 0.0;

// Width of the molten core line, in card pixels.
uniform float seam_width : hint_range(0.5, 8.0) = 2.4;
uniform float vein_strength : hint_range(0.0, 2.0) = 0.85;
uniform float shock_strength : hint_range(0.0, 2.0) = 0.75;

uniform vec4 gold_core : source_color = vec4(1.000, 0.960, 0.760, 1.0);
uniform vec4 gold_mid : source_color = vec4(0.965, 0.760, 0.240, 1.0);
uniform vec4 gold_deep : source_color = vec4(0.560, 0.290, 0.045, 1.0);
uniform vec4 cyan_hot : source_color = vec4(0.470, 0.900, 1.000, 1.0);

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float sd_rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

// Per-facet shade, echoing MoxieOrbRing's carved gemstone refraction.
float crystal_facet(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float md = 8.0;
	float cell = 0.5;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash21(n + g), hash21(n + g + vec2(19.7, 41.3)));
			vec2 r = g + (0.16 + 0.68 * o) - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				cell = hash21(n + g + vec2(7.3, 23.1));
			}
		}
	}
	return cell;
}

void fragment() {
	// Card-local pixels and the 0..1 coordinates that follow from them.
	vec2 p = (UV - 0.5) * quad_size;
	float sd = sd_rounded_box(p, card_size * 0.5, corner_radius);

	float body = 1.0 - smoothstep(-1.0, 1.0, sd);
	if (body <= 0.001) {
		discard;
	}

	vec2 card_uv = p / card_size + 0.5;
	float seed = seam_seed;

	float ignite = smoothstep(0.0, 0.20, progress);
	float spread = smoothstep(0.08, 0.55, progress);
	float cool = 1.0 - smoothstep(0.60, 1.0, progress);

	// Jagged molten fracture down the middle of the card body.
	float jitter = (value_noise(vec2(card_uv.y * 11.0 + seed, seed * 3.7)) - 0.5) * 0.075;
	float seam_px = abs(card_uv.x - 0.5 - jitter) * card_size.x;

	float seam = 1.0 - smoothstep(seam_width - 1.0, seam_width + 1.0, seam_px);
	float seam_hot = 1.0 - smoothstep(0.0, seam_width * 2.2, seam_px);

	// Hairline kintsugi veins blooming outward from the seam.
	float crack_field = value_noise(vec2(card_uv.x * 5.0 + seed, card_uv.y * 5.0 - seed));
	float crack_line = 1.0 - smoothstep(0.0, 0.055, abs(crack_field - 0.5));
	float reach = 1.0 - smoothstep(0.0, card_size.x * (0.16 + 0.34 * spread), seam_px);
	float vein = crack_line * reach * vein_strength * spread;

	// Forge shockwave rippling out from the weld.
	vec2 centered = (card_uv - 0.5) * vec2(1.0, card_size.y / card_size.x);
	float radial = length(centered) * 2.0;
	float ring = 1.0 - smoothstep(0.0, 0.055, abs(radial - progress * 1.25));
	float shock = ring * (1.0 - spread) * shock_strength * ignite;

	// Arcane gold fading to deep amber as it spreads away from the core.
	vec3 gold = mix(gold_core.rgb, gold_mid.rgb, clamp(seam_px / max(seam_width * 3.0, 0.001), 0.0, 1.0));
	gold = mix(gold, gold_deep.rgb, clamp(seam_px / max(seam_width * 6.0, 0.001), 0.0, 1.0) * 0.35);

	vec3 spark = cyan_hot.rgb;
	if (is_double_merge) {
		float facet = crystal_facet(card_uv * 6.5 + vec2(seed * 1.7, seed * 0.7));
		// Carved gemstone facets catch the forge light unevenly.
		gold = mix(gold, mix(gold_mid.rgb, cyan_hot.rgb, facet), facet * 0.45 * spread);
		spark = mix(cyan_hot.rgb, gold_core.rgb, facet);
	}

	float glow = (seam * (0.55 + 0.45 * ignite) + seam_hot * 0.85) * ignite + vein * 0.75 + shock;
	glow = clamp(glow, 0.0, 1.6) * cool;

	// White-hot core right on the seam line, cooling to gold and cyan outward.
	vec3 colour = mix(gold, spark, seam_hot * 0.7);
	colour = mix(colour, gold_core.rgb, seam_hot * 0.9);

	float alpha = clamp(glow, 0.0, 1.0) * body;
	if (alpha <= 0.001) {
		discard;
	}
	COLOR = vec4(colour * (0.8 + 0.6 * glow), alpha);
}
