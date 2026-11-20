// res://Scenes/HUD/MoxieOrbRing.gdshader
shader_type canvas_item;
render_mode unshaded;

uniform float rect_half_size = 27.0;
uniform float outer_radius = 25.5;
uniform float inner_radius = 18.0;
uniform int segments = 10;

uniform float fill_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float preview_start : hint_range(0.0, 1.0) = 0.0;
uniform float preview_end : hint_range(0.0, 1.0) = 0.0;
uniform float overcharge_ratio : hint_range(0.0, 1.0) = 0.0;

uniform float ready_blend : hint_range(0.0, 1.0) = 0.0;
uniform float hover_boost : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_mul : hint_range(0.0, 1.0) = 1.0;

// Crystalline & Hextech plasma tuning
uniform float facet_strength : hint_range(0.0, 1.0) = 0.50;
uniform float plasma_strength : hint_range(0.0, 1.0) = 0.55;
uniform float pillow_power : hint_range(0.5, 2.5) = 0.60;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.42;

// Recessed empty socket colors
uniform vec4 socket_groove_col : source_color = vec4(0.025, 0.032, 0.045, 1.0);
uniform vec4 socket_floor_col  : source_color = vec4(0.075, 0.105, 0.155, 1.0);

// 3-stop LoR crystal ramp (Rim -> Body -> Incandescent Core)
uniform vec4 fill_deep : source_color = vec4(0.04, 0.14, 0.39, 1.0);
uniform vec4 fill_mid  : source_color = vec4(0.11, 0.44, 0.91, 1.0);
uniform vec4 fill_core : source_color = vec4(0.54, 0.94, 1.00, 1.0);

// Preview / Overcharge crystal ramp
uniform vec4 preview_deep : source_color = vec4(0.12, 0.28, 0.54, 1.0);
uniform vec4 preview_mid  : source_color = vec4(0.56, 0.77, 0.96, 1.0);
uniform vec4 preview_core : source_color = vec4(0.93, 0.99, 1.00, 1.0);

mat2 rot2d(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
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

float fbm2(vec2 p) {
	float v = 0.62 * value_noise(p);
	p = rot2d(0.64) * (p * 2.07 + vec2(11.3, 7.1));
	v += 0.38 * value_noise(p);
	return v;
}

// Returns vec2(border_distance, per_facet_shade) for carved gemstone refraction
vec2 crystal_voronoi(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);

	vec2 mr = vec2(0.0);
	float md = 8.0;
	float cell_shade = 0.5;

	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			vec2 r = g + (0.18 + 0.64 * o) - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				cell_shade = hash21(n + g + vec2(19.7, 41.3));
			}
		}
	}

	float border_d = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			vec2 r = g + (0.18 + 0.64 * o) - f;
			vec2 diff = r - mr;
			if (dot(diff, diff) > 0.0001) {
				border_d = min(border_d, dot(0.5 * (mr + r), normalize(diff)));
			}
		}
	}
	return vec2(border_d, cell_shade);
}

vec3 shade_crystal(
	float cushion,
	float plasma,
	vec2 vor,
	float top_spec,
	vec3 c_deep,
	vec3 c_mid,
	vec3 c_core,
	float core_boost
) {
	// Cushion rises from 0.0 at all 4 socket walls to 1.0 in the gem's center
	float base_pillow = pow(cushion, pillow_power);
	float plasma_mod = (plasma - 0.46) * plasma_strength * smoothstep(0.08, 0.75, cushion);
	float facet_tilt = (vor.y - 0.5) * facet_strength * 0.44 * smoothstep(0.05, 0.55, cushion);
	float facet_ridge = smoothstep(0.15, 0.015, vor.x) * smoothstep(0.16, 0.75, cushion);

	float energy = clamp(base_pillow + plasma_mod + facet_tilt + core_boost, 0.0, 1.0);

	// 3-stop LoR gemstone color ramp
	vec3 col = mix(c_deep, c_mid, smoothstep(0.02, 0.50, energy));
	col = mix(col, c_core, smoothstep(0.42, 0.92, energy));

	// Crisp refractive crystal ridges + subtle top-left glass bevel
	col = mix(col, c_core, facet_ridge * facet_strength * 0.52);
	col += c_core * top_spec * 0.16;
	return col;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * (rect_half_size * 2.0);
	float r = length(p);
	if (r < inner_radius - 0.8 || r > outer_radius + 0.8) {
		discard;
	}

	float ring_mask = smoothstep(inner_radius - 0.55, inner_radius + 0.15, r)
	                * (1.0 - smoothstep(outer_radius - 0.15, outer_radius + 0.55, r));

	// Clockwise progress [0, 1) starting at 12 o'clock (-PI * 0.5)
	float ang_cw = atan(p.x, -p.y);
	if (ang_cw < 0.0) {
		ang_cw += 6.28318530718;
	}
	float progress = ang_cw / 6.28318530718;

	// Exact pixel-space rounded-box SDF inside each curved segment chamber
	float seg_f = float(max(segments, 1));
	float seg_phase = fract(progress * seg_f);
	float seg_arc_px = (6.28318530718 * r) / seg_f;

	float dx = min(seg_phase, 1.0 - seg_phase) * seg_arc_px - 0.78;
	float dy = min(r - inner_radius, outer_radius - r) - 0.45;

	float corner_r = 1.30;
	vec2 q = vec2(corner_r - dx, corner_r - dy);
	float d_gem = -(min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - corner_r);

	float gem_mask = smoothstep(-0.45, 0.45, d_gem);
	float half_span = max(0.5 * (outer_radius - inner_radius) - 0.45, 1.0);
	float cushion = clamp(d_gem / half_span, 0.0, 1.0);

	// Stationary carved crystal facets + clockwise-orbiting Hextech plasma (zero seam!)
	vec2 vor = crystal_voronoi(p * 0.25);
	float spd = flow_speed * (1.0 + 0.45 * ready_blend);
	vec2 p_flow1 = rot2d(-TIME * spd * 0.55) * p;
	vec2 p_flow2 = rot2d( TIME * spd * 0.34) * p;
	float n1 = fbm2(p_flow1 * 0.17);
	float n2 = fbm2(p_flow2 * 0.24 + vec2(n1 * 1.35));
	float plasma = clamp(mix(n1, n2, 0.58), 0.0, 1.0);

	// Subtle top-left bevel catchlight across the crystal surface
	vec2 radial_dir = p / max(r, 0.001);
	float light_align = clamp(dot(radial_dir, normalize(vec2(-0.45, -0.89))) * 0.5 + 0.5, 0.0, 1.0);
	float rim_band = smoothstep(0.0, 1.2, d_gem) * (1.0 - smoothstep(1.2, 2.8, d_gem));
	float top_spec = light_align * rim_band;

	// 1. Recessed Obsidian Gem Socket (visible when empty)
	float socket_depth = pow(cushion, 0.85) * (0.85 + 0.30 * vor.y);
	vec3 socket_col = mix(socket_groove_col.rgb, socket_floor_col.rgb, socket_depth);
	socket_col += socket_floor_col.rgb * top_spec * 0.35;

	// 2. Owned Moxie Crystal Fill
	float circum_px = 6.28318530718 * r;
	float fill_edge_px = (fill_ratio - progress) * circum_px;
	float fill_mask = 0.0;
	if (fill_ratio >= 0.999) {
		fill_mask = 1.0;
	} else if (fill_ratio > 0.001) {
		fill_mask = smoothstep(-0.45, 0.45, fill_edge_px);
	}

	float core_boost = ready_blend * 0.16 + hover_boost * 0.10;
	vec3 owned_col = shade_crystal(
		cushion, plasma, vor, top_spec,
		fill_deep.rgb, fill_mid.rgb, fill_core.rgb, core_boost
	);

	// Liquid-mana meniscus glow at the advancing fill frontier (only when partially full)
	if (fill_ratio > 0.004 && fill_ratio < 0.994) {
		float meniscus = exp(-max(fill_edge_px, 0.0) * 0.75) * fill_mask;
		owned_col = mix(owned_col, fill_core.rgb, meniscus * 0.72);
	}

	// 3. Preview & Overcharge Shimmering Crystal
	float prev_mask = 0.0;
	if (preview_end > preview_start + 0.001) {
		float ps_px = (progress - preview_start) * circum_px;
		float pe_px = (preview_end - progress) * circum_px;
		prev_mask = smoothstep(-0.45, 0.45, ps_px) * smoothstep(-0.45, 0.45, pe_px);
	}
	float over_mask = 0.0;
	if (overcharge_ratio > 0.001) {
		float oe_px = (overcharge_ratio - progress) * circum_px;
		over_mask = smoothstep(-0.45, 0.45, oe_px);
	}

	float pulse = 0.74 + 0.26 * sin(TIME * 5.2);
	vec3 prev_col = shade_crystal(
		cushion, plasma, vor, top_spec,
		preview_deep.rgb, preview_mid.rgb, preview_core.rgb,
		0.14 * pulse + hover_boost * 0.08
	);

	// Compose inside the crystal socket, keeping the dark divider grooves crisp
	vec3 crystal_col = mix(socket_col, owned_col, fill_mask);
	crystal_col = mix(crystal_col, prev_col, clamp(prev_mask * (0.82 + 0.18 * pulse), 0.0, 1.0));
	if (over_mask > 0.001) {
		vec3 over_col = mix(prev_col, preview_core.rgb, 0.35 + 0.25 * pulse);
		crystal_col = mix(crystal_col, over_col, over_mask * (0.72 + 0.24 * pulse));
	}

	vec3 final_col = mix(socket_groove_col.rgb, crystal_col, gem_mask);
	COLOR = vec4(final_col, ring_mask * alpha_mul);
}