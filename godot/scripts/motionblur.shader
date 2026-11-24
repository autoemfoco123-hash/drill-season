// A little motion blur over the 3D view (scripts/MotionBlur.gd): the picture smeared along
// the way the camera is turning, and pulled out from the middle at speed in a car. Six
// samples; the HUD and the phone sit on layers above, so they stay sharp.
shader_type canvas_item;

uniform vec2 shift = vec2(0.0);     // the camera's turn this frame, in screen fractions
uniform float zoom = 0.0;           // the radial pull at speed

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - vec2(0.5);
	vec3 col = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float t = float(i) / 5.0 - 0.5;
		vec2 o = shift * t + c * zoom * (t + 0.5);
		col += textureLod(SCREEN_TEXTURE, clamp(uv - o, vec2(0.001), vec2(0.999)), 0.0).rgb;
	}
	COLOR = vec4(col / 6.0, 1.0);
}
