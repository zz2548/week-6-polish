shader_type canvas_item;

uniform vec4 top_color    : source_color = vec4(0.00, 0.00, 0.02, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.02, 0.01, 0.05, 1.0);
uniform float scanline_alpha : hint_range(0.0, 0.2) = 0.045;
uniform float scanline_freq  : hint_range(0.5, 6.0) = 2.5;

void fragment() {
	// Screen-space vertical gradient (always top-dark → bottom-slightly-lighter)
	vec4 bg = mix(top_color, bottom_color, SCREEN_UV.y);

	// Subtle horizontal scanlines — fixed to screen, gives CRT feel
	float scanline = sin(FRAGCOORD.y * scanline_freq) * 0.5 + 0.5;
	bg.rgb += scanline * scanline_alpha;

	bg.a = 1.0;
	COLOR = bg;
}
