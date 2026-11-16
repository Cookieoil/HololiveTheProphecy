shader_type canvas_item;

uniform sampler2D portrait_tex : source_color, filter_linear_mipmap;
uniform vec4 atlas_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 tex_aspect = vec2(1.0, 1.0);
uniform float saturation : hint_range(0.0, 1.5) = 1.0;
uniform float brightness : hint_range(0.0, 1.5) = 1.0;
uniform vec4 bg_color : source_color = vec4(0.07, 0.09, 0.11, 1.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0;
	float circle_mask = 1.0 - smoothstep(0.94, 1.0, dist);
	if (circle_mask <= 0.001) {
		discard;
	}

	// Smart framing: if the sprite is tall (full-body unit art), bias upward toward the face
	vec2 local_uv = UV;
	if (tex_aspect.y > tex_aspect.x * 1.2) {
		float scale_y = tex_aspect.x / tex_aspect.y;
		local_uv.y = clamp(0.10 + UV.y * scale_y * 1.15, 0.0, 1.0);
	} else if (tex_aspect.x > tex_aspect.y * 1.2) {
		float scale_x = tex_aspect.y / tex_aspect.x;
		local_uv.x = 0.5 + (UV.x - 0.5) * scale_x;
	}

	vec2 sample_uv = atlas_uv_rect.xy + local_uv * atlas_uv_rect.zw;
	vec4 tex = texture(portrait_tex, sample_uv);

	vec3 col = mix(bg_color.rgb, tex.rgb, tex.a);
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation) * brightness;

	// Subtle Morimens inner edge vignette under the brass bezel
	float vignette = smoothstep(1.02, 0.62, dist);
	col *= mix(0.58, 1.0, vignette);

	COLOR = vec4(col, circle_mask * COLOR.a);
}