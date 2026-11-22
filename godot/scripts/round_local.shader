// Rounded corners for anything a Control draws itself (the minimap): the corners of its
// rectangle turn transparent, with a soft 1 px edge. Set size to the control's size.
shader_type canvas_item;

uniform vec2 size = vec2(240.0, 160.0);
uniform float radius = 18.0;
varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 q = abs(lp - size * 0.5) - (size * 0.5 - vec2(radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.a *= clamp(0.5 - d, 0.0, 1.0);
	COLOR = c;
}
