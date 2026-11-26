// res://Scenes/HUD/BattleResultBackdrop.gdshader
//
// Screen-space grade for the end-of-battle cutscene. It replaces the old flat
// grey ColorRect with something that reads like a big-budget result screen: the
// live battlefield behind it is drained of colour and softly vignetted, and a
// full-width cinema band (Elden Ring / NieR style) is feathered across the middle
// of the frame to seat the title.
//
// Deliberately restrained: everything here is plain SDR alpha blending. No bloom,
// no glow, no HDR (the project runs viewport/hdr_2d, so any channel above 1.0
// would flare), no hard edges - the band has no left/right border and its top and
// bottom falloff is a smoothstep, so it never reads as a rectangle.
//
// Reading the scene needs a BackBufferCopy node in front of this rect (see
// BattleScene._setup_result_overlay); without one the screen texture is empty and
// the backdrop degrades to the plain graded tone.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

group_uniforms SceneGrade;
// 0 = untouched scene, 1 = fully grey. The battlefield stays readable either way.
uniform float desaturation : hint_range(0.0, 1.0) = 0.72;
// Tint the drained scene leans towards: warm parchment for a win, cold ash for a loss.
uniform vec4 grade_tint : source_color = vec4(0.86, 0.80, 0.68, 1.0);
uniform float grade_mix : hint_range(0.0, 1.0) = 0.18;
uniform float dim : hint_range(0.0, 1.0) = 0.22;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.42;
uniform float vignette_start : hint_range(0.0, 1.5) = 0.55;
group_uniforms;

group_uniforms CinemaBand;
uniform float band_center : hint_range(0.0, 1.0) = 0.5;
// Half height of the band's solid core, in screen UV. 0 collapses it to a line,
// so animating this from 0 unfurls the band out of the middle of the frame.
uniform float band_half : hint_range(0.0, 0.6) = 0.170;
uniform float band_feather : hint_range(0.01, 0.6) = 0.090;
uniform float band_alpha : hint_range(0.0, 1.0) = 0.80;
uniform vec4 band_color : source_color = vec4(0.02, 0.022, 0.03, 1.0);
uniform float band_open : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

group_uniforms HorizonRules;
// Two whisper-thin rules inside the band, above and below the title block.
uniform vec4 rule_color : source_color = vec4(0.94, 0.88, 0.72, 1.0);
uniform float rule_offset : hint_range(0.0, 0.5) = 0.155;
uniform float rule_thickness : hint_range(0.0002, 0.01) = 0.0016;
uniform float rule_alpha : hint_range(0.0, 1.0) = 0.20;
// 0 = not drawn, 1 = wiped all the way out to both screen edges.
uniform float rule_wipe : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

// One soft rule: a thin horizontal line that fades out at the wipe's leading edge
// and at both screen edges, so it grows outward instead of popping in.
float horizon_rule(float y_uv, float dist, float wipe) {
	float reach = 0.5 * clamp(wipe, 0.0, 1.0);
	if (reach <= 0.0001) {
		return 0.0;
	}
	float line = 1.0 - smoothstep(0.0, rule_thickness, abs(y_uv - dist));
	float leading = 1.0 - smoothstep(reach - 0.10, reach, dist);
	float outer = 1.0 - smoothstep(reach - 0.02, reach + 0.02, dist);
	return line * min(leading, outer);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// 1. Drain the scene and lean it towards this result's tone.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), desaturation);
	col = mix(col, grade_tint.rgb, grade_mix);
	col *= 1.0 - dim;

	// 2. Soft corner vignette, so the eye is pulled to the middle of the frame.
	vec2 centred = SCREEN_UV - vec2(0.5);
	float radius = length(centred * vec2(1.0, 1.25)) * 1.55;
	col *= mix(1.0, 1.0 - vignette_strength, smoothstep(vignette_start, 1.15, radius));

	// 3. The cinema band: full width, feathered top and bottom, no side edges.
	float half_h = mix(0.0, band_half, clamp(band_open, 0.0, 1.0));
	float band_dist = abs(SCREEN_UV.y - band_center);
	float band = 1.0 - smoothstep(half_h, half_h + band_feather, band_dist);
	col = mix(col, band_color.rgb, band * band_alpha);

	// 4. The horizon rules, wiped outward from the centre.
	float rule_dist = abs(SCREEN_UV.x - 0.5);
	float rules = horizon_rule(SCREEN_UV.y, band_center - rule_offset, rule_wipe)
		+ horizon_rule(SCREEN_UV.y, band_center + rule_offset, rule_wipe);
	col = mix(col, rule_color.rgb, clamp(rules, 0.0, 1.0) * rule_alpha);

	COLOR = vec4(col, 1.0);
}
