// Additive light for the memorial: the figure of light (mode 0, bright rim), a halo ring
// (mode 1), feathered angel wings (mode 2), the column of light from the sky (mode 3) and
// the rays pouring out of the open doors (mode 4).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : hint_color = vec4(0.86, 0.92, 1.0, 1.0);
uniform float alpha = 1.0;
uniform int mode = 0;
uniform float t = 0.0;

void fragment() {
	float a = 0.0;
	if (mode == 0) {
		float fr = 1.0 - abs(dot(NORMAL, VIEW));
		a = 0.18 + pow(fr, 2.2) * 1.5 + 0.06 * sin(t * 3.0 + UV.y * 20.0);
	} else if (mode == 1) {
		float r = length(UV - vec2(0.5)) * 2.0;
		a = smoothstep(0.1, 0.0, abs(r - 0.78)) * 1.6 + smoothstep(0.32, 0.0, abs(r - 0.78)) * 0.4;
	} else if (mode == 2) {
		// u: root (0) to tip (1); v: top (0) to bottom (1)
		float u = UV.x;
		float v = UV.y;
		float top = 0.12 + 0.22 * u * u - 0.12 * sin(u * 3.14159);
		float scallop = 0.05 * abs(sin(u * 22.0));
		float bottom = 0.42 + 0.5 * pow(u, 0.7) * (1.0 - u * 0.35) - scallop;
		float inside = smoothstep(top, top + 0.04, v) * smoothstep(bottom, bottom - 0.06, v) * smoothstep(1.0, 0.9, u);
		float feather = 0.65 + 0.35 * abs(sin(u * 22.0 + v * 2.0));
		float rim = smoothstep(0.1, 0.0, abs(v - top)) + smoothstep(0.08, 0.0, abs(v - bottom)) * 0.6;
		a = inside * (0.35 * feather + rim * 0.8);
	} else if (mode == 3) {
		float fr = 1.0 - abs(dot(NORMAL, VIEW));
		a = (1.0 - fr * 0.85) * 0.5 * smoothstep(0.0, 0.25, UV.y) * (0.75 + 0.25 * sin(t * 4.0 + UV.y * 30.0));
	} else {
		float edge = sin(UV.x * 3.14159);
		a = pow(1.0 - UV.y, 1.6) * edge * edge * (0.7 + 0.3 * sin(t * 2.0 + UV.x * 9.0 + UV.y * 4.0)) * 0.55;
	}
	ALBEDO = tint.rgb * (1.0 + a * 0.4);
	ALPHA = clamp(a * alpha, 0.0, 1.0);
}
