// res://Scenes/HUD/BattleResultEmblem.gdshader
//
// Turns a placeholder emblem into a cohesive etched seal, so the result screen
// reads as designed art instead of a stock icon dropped on top of the title.
//
// Two problems it solves:
//   1. The placeholder textures carry their own background (icon.svg ships a baked
//      slate rounded square). A radial mask plus a luminance floor strips that
//      away, leaving just the mark itself.
//   2. The emblem has to sit BEHIND the title without fighting it for contrast.
//      So it is rendered as a single low-contrast ink at a fixed opacity, and its
//      lower third fades out exactly where the title laps over it.
//
// Strictly SDR: one flat colour, one alpha. No glow, no bloom, no gradient noise.
// Set raw_mode to draw finished hand-drawn art untouched instead.
shader_type canvas_item;
render_mode unshaded;

// Ink colour of the seal: burnished antique gold for a win, weathered iron for a loss.
uniform vec4 seal_color : source_color = vec4(0.76, 0.64, 0.38, 1.0);
uniform float seal_opacity : hint_range(0.0, 1.0) = 0.42;
// Luminance below this counts as background and is dropped entirely; above
// `ink_high` it is fully opaque ink. Tuned so icon.svg's slate square disappears
// while its pale mark survives.
uniform float ink_low : hint_range(0.0, 1.0) = 0.34;
uniform float ink_high : hint_range(0.0, 1.0) = 0.86;
// Circular crop, as a fraction of the half-diagonal, so the seal is round even
// when the source texture is square.
uniform float mask_feather : hint_range(0.0, 0.5) = 0.10;
// Vertical fade: 1.0 keeps the whole emblem, lower values dissolve more of its
// bottom (where the title crosses it).
uniform float fade_from : hint_range(0.0, 1.0) = 0.60;
uniform float fade_softness : hint_range(0.01, 1.0) = 0.34;
// True: draw the texture as authored (for real hand-drawn crests later).
uniform bool raw_mode = false;

void fragment() {
	vec4 src = texture(TEXTURE, UV);

	float dist = length(UV - vec2(0.5)) * 2.0;
	float circle = 1.0 - smoothstep(1.0 - mask_feather, 1.0, dist);

	float luma = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	float ink = smoothstep(ink_low, ink_high, luma) * src.a;

	float vertical = 1.0 - smoothstep(fade_from, fade_from + fade_softness, UV.y);

	float seal_alpha = ink * circle * vertical * seal_opacity * COLOR.a;
	// No `return` in a fragment processor, so both paths are blended by the branch.
	COLOR = raw_mode ? src * COLOR : vec4(seal_color.rgb, seal_alpha);
}
