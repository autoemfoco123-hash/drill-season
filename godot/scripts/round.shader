// Rounded corners for a texture (the phone wallpaper, photos in Blok): everything outside a
// rounded rectangle of the given size and radius turns transparent, with a soft 1 px edge.
shader_type canvas_item;

uniform vec2 size = vec2(314.0, 676.0);
uniform float radius = 48.0;

void fragment() {
	vec2 p = UV * size;
	vec2 q = abs(p - size * 0.5) - (size * 0.5 - vec2(radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.a *= clamp(0.5 - d, 0.0, 1.0);
	COLOR = c;
}
