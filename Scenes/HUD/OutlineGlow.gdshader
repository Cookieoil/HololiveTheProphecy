// res://Scenes/HUD/OutlineGlow.gdshader
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D flow_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D silhouette_tex : repeat_disable, filter_linear_mipmap;
uniform bool use_silhouette = false;
uniform vec2 silhouette_uv_rect_size = vec2(1.0, 1.0);

uniform vec2 rect_size = vec2(140.0, 180.0);
uniform float glow_margin = 16.0;
uniform float corner_radius = 8.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float flow_speed = 0.20;
// Higher = rounder, softer aura on silhouettes; lower = hugs fine details tighter.
uniform float contour_smoothness : hint_range(0.6, 2.5) = 1.25;
// Subtle organic breath without spiky noise ridges. Set to 0.0 for glass-smooth edges.
uniform float edge_warp_strength : hint_range(0.0, 2.5) = 0.30;

uniform vec4 color_core : source_color = vec4(0.80, 0.97, 1.00, 1.0);
uniform vec4 color_mid  : source_color = vec4(0.18, 0.70, 1.00, 1.0);
uniform vec4 color_deep : source_color = vec4(0.06, 0.36, 0.92, 1.0);

float sd_rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float sample_sil_alpha(vec2 sample_px, vec2 inner_size, float lod) {
	vec2 uv = (sample_px - vec2(glow_margin)) / inner_size;
	if (uv.x <= 0.0 || uv.x >= 1.0 || uv.y <= 0.0 || uv.y >= 1.0) {
		return 0.0;
	}
	return clamp(textureLod(silhouette_tex, uv, lod).a, 0.0, 1.0);
}

float smooth_silhouette_distance_px(vec2 px, vec2 inner_size, float texel_scale, float max_dist) {
	const int DIRS = 12;
	const int RINGS = 5;

	float step_px = max_dist / float(RINGS);
	float base_lod = clamp(log2(max(1.0, step_px * 0.85 * texel_scale * contour_smoothness)), 0.0, 3.5);

	float center_a = sample_sil_alpha(px, inner_size, base_lod);
	float center_hit = smoothstep(0.15, 0.75, center_a);

	float k = 4.2 / max(glow_margin * contour_smoothness, 1.0);
	float total_energy = 0.0;

	for (int i = 0; i < DIRS; i++) {
		float ang = (float(i) / float(DIRS)) * 6.28318530718;
		vec2 dir = vec2(cos(ang), sin(ang));

		float trans = 1.0 - center_hit;
		float ray_energy = 0.38 * center_hit;

		for (int r = 1; r <= RINGS; r++) {
			float d_px = (float(r) - 0.5) * step_px;
			float arc_px = (6.28318530718 / float(DIRS)) * d_px;
			float filter_px = max(step_px * 0.85, arc_px * 1.25) * texel_scale * contour_smoothness;
			float lod = clamp(log2(max(1.0, filter_px)), 0.0, 3.5);

			float a = sample_sil_alpha(px + dir * d_px, inner_size, lod);
			float hit = smoothstep(0.15, 0.70, a);

			ray_energy += (trans * hit) * exp(-k * d_px);
			trans *= (1.0 - hit);
			if (trans < 0.005) {
				break;
			}
		}
		total_energy += ray_energy;
	}

	float avg_energy = total_energy / float(DIRS);
	if (avg_energy <= 1e-6) {
		return max_dist + 4.0;
	}
	return max(0.0, -(0.86 / k) * log(avg_energy / 0.36));
}

void fragment() {
	if (intensity <= 0.001) {
		discard;
	}

	vec2 px = UV * rect_size;
	vec2 center = rect_size * 0.5;
	vec2 half_inner = max(vec2(4.0), center - vec2(glow_margin));
	float r = clamp(corner_radius, 0.0, min(half_inner.x, half_inner.y));

	float d;
	float self_mask = 1.0;
	if (use_silhouette) {
		vec2 inner_size = max(rect_size - vec2(glow_margin * 2.0), vec2(1.0));
		float self_a = sample_sil_alpha(px, inner_size, 0.0);
		if (self_a >= 0.995) {
			discard;
		}
		self_mask = 1.0 - self_a;

		vec2 texels_per_px = silhouette_uv_rect_size / inner_size;
		float texel_scale = max(0.5 * (texels_per_px.x + texels_per_px.y), 0.25);
		d = smooth_silhouette_distance_px(px, inner_size, texel_scale, glow_margin + 4.0);
		if (d >= glow_margin) {
			discard;
		}
	} else {
		d = sd_rounded_box(px - center, half_inner, r);
		if (d < -2.2 || d >= glow_margin) {
			discard;
		}
	}

	vec2 world_uv = px / 135.0;
	float n1 = textureLod(flow_tex, world_uv * vec2(1.15, 0.90) + vec2(TIME * flow_speed * 0.65, -TIME * flow_speed), 0.0).r;
	vec2 warped_uv = world_uv * vec2(1.85, 1.55) + vec2(-TIME * flow_speed * 0.85, -TIME * flow_speed * 0.45) + vec2(n1 * 0.22);
	float n2 = textureLod(flow_tex, warped_uv, 0.0).r;

	float pattern = clamp(mix(n1, n2, 0.62), 0.0, 1.0);
	float veins = smoothstep(0.24, 0.82, pattern);

	float d_pos = max(d, 0.0);
	// Smoothly zero out both warp and alpha before d == glow_margin so the ColorRect quad never clips
	float outer_fade = 1.0 - smoothstep(glow_margin * 0.55, glow_margin, d_pos);
	float warp_env = smoothstep(0.0, 5.0, d_pos) * outer_fade;
	float edge_warp = (pattern - 0.5) * edge_warp_strength * warp_env;
	float dw = max(d_pos + edge_warp, 0.0);

	float inner_mask = use_silhouette ? self_mask : smoothstep(-2.2, -0.3, d);
	float hot_rim = exp(-d_pos * 0.72) * inner_mask * outer_fade;
	float body = (1.0 - smoothstep(0.0, glow_margin * 0.88, dw)) * inner_mask * outer_fade;
	float outer_haze = (1.0 - smoothstep(glow_margin * 0.22, glow_margin, dw)) * inner_mask * outer_fade;

	float textured_body = body * mix(0.54, 1.22, veins);

	vec3 col = mix(color_deep.rgb, color_mid.rgb, clamp(textured_body * 1.15, 0.0, 1.0));
	col = mix(col, color_core.rgb, clamp(hot_rim * (0.78 + 0.28 * veins), 0.0, 1.0));

	float alpha = clamp((outer_haze * 0.42 + textured_body * 0.68 + hot_rim * 0.65) * intensity, 0.0, 0.96);
	COLOR = vec4(col, alpha);
}