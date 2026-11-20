// res://Scenes/HUD/OutlineGlowGroup.gdshader
shader_type canvas_item;
render_mode unshaded;

// filter_linear_mipmap + CanvasGroup.use_mipmaps gives a Gaussian-smoothed silhouette pyramid
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D flow_tex : repeat_enable, filter_linear;

uniform float glow_margin = 15.0;
uniform float intensity : hint_range(0.0, 2.0) = 0.0;
uniform float flow_speed = 0.20;
// Higher = rounder, softer aura over hair/weapons; lower = hugs tiny details tighter.
uniform float contour_smoothness : hint_range(0.6, 2.5) = 1.25;
uniform float edge_warp_strength : hint_range(0.0, 2.5) = 0.35;

uniform vec4 color_core : source_color = vec4(0.80, 0.97, 1.00, 1.0);
uniform vec4 color_mid  : source_color = vec4(0.18, 0.70, 1.00, 1.0);
uniform vec4 color_deep : source_color = vec4(0.06, 0.36, 0.92, 1.0);

varying vec2 local_pos;
varying vec2 uv_per_local_px;

void vertex() {
	local_pos = VERTEX;
	mat4 clip_mat = SCREEN_MATRIX * CANVAS_MATRIX * MODEL_MATRIX;
	uv_per_local_px = 0.5 * vec2(length(clip_mat[0].xy), length(clip_mat[1].xy));
}

float smooth_silhouette_distance(vec2 screen_uv, vec2 step_uv, float px_scale, float max_dist) {
	const int DIRS = 24;
	const int RINGS = 9;

	float step_px = max_dist / float(RINGS);
	float base_lod = clamp(log2(max(1.0, step_px * 0.85 * px_scale * contour_smoothness)), 0.0, 3.5);

	float center_a = clamp(textureLod(screen_texture, screen_uv, base_lod).a, 0.0, 1.0);
	float center_hit = smoothstep(0.15, 0.75, center_a);

	float k = 4.2 / max(glow_margin * contour_smoothness, 1.0);
	float total_energy = 0.0;

	for (int i = 0; i < DIRS; i++) {
		float ang = (float(i) / float(DIRS)) * 6.28318530718;
		vec2 dir_uv = vec2(cos(ang), sin(ang)) * step_uv;

		float trans = 1.0 - center_hit;
		float ray_energy = 0.38 * center_hit;

		for (int r = 1; r <= RINGS; r++) {
			float d_px = (float(r) - 0.5) * step_px;
			float arc_px = 0.2617994 * d_px; // (2 * PI / 24) * d_px
			// Filter footprint always exceeds both radial step and angular gap -> zero spokes
			float filter_px = max(step_px * 0.85, arc_px * 1.25) * px_scale * contour_smoothness;
			float lod = clamp(log2(max(1.0, filter_px)), 0.0, 3.5);

			float a = clamp(textureLod(screen_texture, screen_uv + dir_uv * d_px, lod).a, 0.0, 1.0);
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
	vec4 mod_col = COLOR;
	// Sample character at LOD 0.0 so the sprite itself stays crisp and preserves HDR bloom
	vec4 raw = textureLod(screen_texture, SCREEN_UV, 0.0);
	float char_a = clamp(raw.a, 0.0, 1.0);

	if (intensity <= 0.001 || char_a >= 0.995) {
		vec3 char_rgb = char_a > 0.0001 ? (raw.rgb / char_a) : vec3(0.0);
		COLOR = vec4(char_rgb, char_a) * mod_col;
	} else {
		vec2 step_uv = max(uv_per_local_px, SCREEN_PIXEL_SIZE * 0.25);
		vec2 px_scale_2d = step_uv / max(SCREEN_PIXEL_SIZE, vec2(1e-6));
		float px_scale = max(0.5 * (px_scale_2d.x + px_scale_2d.y), 0.25);

		float search_dist = glow_margin + 4.0;
		float d = smooth_silhouette_distance(SCREEN_UV, step_uv, px_scale, search_dist);

		if (d >= glow_margin + 1.5) {
			vec3 char_rgb = char_a > 0.0001 ? (raw.rgb / char_a) : vec3(0.0);
			COLOR = vec4(char_rgb, char_a) * mod_col;
		} else {
			vec2 world_uv = local_pos / 135.0;
			float n1 = textureLod(flow_tex, world_uv * vec2(1.15, 0.90) + vec2(TIME * flow_speed * 0.65, -TIME * flow_speed), 0.0).r;
			vec2 warped_uv = world_uv * vec2(1.85, 1.55) + vec2(-TIME * flow_speed * 0.85, -TIME * flow_speed * 0.45) + vec2(n1 * 0.22);
			float n2 = textureLod(flow_tex, warped_uv, 0.0).r;

			float pattern = clamp(mix(n1, n2, 0.62), 0.0, 1.0);
			float veins = smoothstep(0.24, 0.82, pattern);

			float edge_warp = (pattern - 0.5) * edge_warp_strength * smoothstep(0.0, 6.0, d);
			float dw = max(d + edge_warp, 0.0);

			float outer_fade = 1.0 - smoothstep(glow_margin * 0.55, glow_margin, d);
			float hot_rim = exp(-d * 0.72) * outer_fade;
			float body = 1.0 - smoothstep(0.0, glow_margin * 0.88, dw);
			float outer_haze = 1.0 - smoothstep(glow_margin * 0.25, glow_margin, dw);

			float textured_body = body * mix(0.54, 1.22, veins);

			vec3 glow_col = mix(color_deep.rgb, color_mid.rgb, clamp(textured_body * 1.15, 0.0, 1.0));
			glow_col = mix(glow_col, color_core.rgb, clamp(hot_rim * (0.78 + 0.28 * veins), 0.0, 1.0));

			float glow_a = clamp((outer_haze * 0.42 + textured_body * 0.68 + hot_rim * 0.65) * intensity, 0.0, 0.96);

			// Premultiplied character OVER outer glow
			float out_a = char_a + glow_a * (1.0 - char_a);
			vec3 out_pm = raw.rgb + glow_col * (glow_a * (1.0 - char_a));
			vec3 out_rgb = out_a > 0.0001 ? (out_pm / out_a) : vec3(0.0);

			COLOR = vec4(out_rgb * mod_col.rgb, out_a * mod_col.a);
		}
	}
}