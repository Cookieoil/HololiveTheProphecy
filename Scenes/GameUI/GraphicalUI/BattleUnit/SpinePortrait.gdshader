shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(0.055, 0.045, 0.085, 0.90);
uniform float outline_width = 0.85;
uniform float shading_strength = 0.10;
uniform float hit_flash = 0.0;
uniform float death_mix = 0.0;

group_uniforms Bloom;
// A data mask, so no source_color (no sRGB conversion).
uniform sampler2D bloom_texture : hint_default_black, filter_linear, repeat_disable;
uniform float bloom_intensity : hint_range(0.0, 4.0) = 1.0;
// Mask values below this count as "no glow". Your navy fill is about 0.27.
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.35;
uniform float bloom_softness : hint_range(0.01, 1.0) = 0.35;
// 0 = glow uses the art's own color (natural). 1 = glow uses the mask's hue (blue/cyan).
uniform float bloom_tint : hint_range(0.0, 1.0) = 0.0;
// true: output values above 1.0 for WorldEnvironment glow (real bloom).
// false: soft "screen" blend that never blows out to white.
uniform bool hdr_bloom = false;
// 0 = normal, 1 = R, 2 = G, 3 = B, 4 = final mask
uniform int debug_view : hint_range(0, 4) = 0;
group_uniforms;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;

	// --- Decode the bloom mask ----------------------------------------------
	vec4 m = texture(bloom_texture, UV);
	float m_max = max(m.r, max(m.g, m.b));
	float mask = smoothstep(bloom_threshold, bloom_threshold + bloom_softness, m_max * m.a);

	if (debug_view > 0) {
		float v = debug_view == 1 ? m.r
				: debug_view == 2 ? m.g
				: debug_view == 3 ? m.b
				: mask;
		COLOR = vec4(vec3(v), base.a);
	}

	// --- Restrained shading (applied before bloom so glow isn't dimmed) -----
	float brightness = mix(1.0 + shading_strength * 0.35, 1.0 - shading_strength, UV.y);
	base.rgb *= brightness;

	// --- Bloom: the art's own color glows where the mask is strong ----------
	vec3 mask_hue = m.rgb / max(m_max, 1e-4);
	vec3 glow_col = mix(base.rgb, mask_hue, bloom_tint);
	vec3 glow = glow_col * mask * bloom_intensity * base.a * (1.0 - death_mix);

	if (hdr_bloom) {
		base.rgb += glow; // can exceed 1.0, so the post-process glow picks it up
	} else {
		base.rgb = 1.0 - (1.0 - base.rgb) * (1.0 - clamp(glow, 0.0, 1.0)); // screen blend
	}

	// --- Death / hit flash ---------------------------------------------------
	float gray = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	base.rgb = mix(base.rgb, vec3(gray), death_mix);
	base.rgb = mix(base.rgb, vec3(1.0, 0.82, 0.76), hit_flash);
	base.a *= 1.0 - death_mix * 0.35;

	// --- Outline (unchanged) -------------------------------------------------
	vec2 offset = TEXTURE_PIXEL_SIZE * outline_width;
	float surrounding_alpha = 0.0;
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(offset.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(offset.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(0.0, offset.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(0.0, offset.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + offset).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - offset).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(offset.x, -offset.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(-offset.x, offset.y)).a);

	float outline_alpha = surrounding_alpha * outline_color.a * (1.0 - base.a);
	float final_alpha = max(base.a, outline_alpha);

	if (final_alpha < 0.0001) {
		COLOR = vec4(0.0);
	} else {
		vec3 final_rgb = (
			base.rgb * base.a
			+ outline_color.rgb * outline_alpha * (1.0 - base.a)
		) / final_alpha;
		COLOR = vec4(final_rgb, final_alpha);
	}
}