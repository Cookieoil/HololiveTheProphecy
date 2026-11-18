// res://Shaders/CardArtParallax.gdshader
shader_type canvas_item;
render_mode unshaded;

// ---------------------------------------------------------------------------
// Depth parallax for the illustration inside a card.
//
// A tiny zoom plus a shift opposite the card tilt makes the art sit visibly
// behind the frame: the border moves with the card, the illustration lags
// behind it. The zoom always leaves more margin than the shift can consume, so
// the art is never sampled outside its own texture.
// ---------------------------------------------------------------------------

// Normalised (-1..1) card tilt: x = yaw, y = pitch.
uniform vec2 tilt = vec2(0.0, 0.0);
uniform float parallax_amount : hint_range(0.0, 0.2) = 0.040;
uniform float parallax_zoom : hint_range(0.0, 0.4) = 0.100;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	// The frame moves with the card, the illustration lags behind it: the sample
	// point slides the same way as the tilt, which reads as the art being deeper.
	vec2 uv = 0.5 + (UV - 0.5) * (1.0 - parallax_zoom) + tilt * parallax_amount;
	COLOR = texture(TEXTURE, uv) * v_modulate;
}
