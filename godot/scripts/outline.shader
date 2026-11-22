// Ink outline for the cel-shaded look: the mesh drawn again, pushed out along its normals
// and showing only its back faces, in a dark ink. The width grows with distance so the line
// stays about the same thickness on screen, from the hands in first person to a car down
// the street.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, skip_vertex_transform;

uniform float width = 0.022;
uniform vec4 ink : hint_color = vec4(0.045, 0.04, 0.055, 1.0);

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 vn = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = -vp.z;
	vp.xyz += vn * width * max(d * 0.11, 0.03);
	VERTEX = vp.xyz;
	NORMAL = vn;
}

void fragment() {
	ALBEDO = ink.rgb;
}
