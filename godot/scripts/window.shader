// City windows (scripts/CityBuild.gd): glass that shows the sky by day and the rooms behind
// it at night, some lit warm, some by a TV, some dark. COLOR.rgb is the room's light, COLOR.a
// how lit it is; UV runs 0..1 across the pane (v down); UV2.x picks what hangs in the window
// (0 bare, 1/3 curtains, 2/3 blinds, 1 a shade half down), UV2.y is a random seed.
shader_type spatial;
render_mode unshaded, cull_back;

uniform float night = 0.0;
uniform vec4 sky_hi : hint_color = vec4(0.72, 0.80, 0.90, 1.0);
uniform vec4 sky_lo : hint_color = vec4(0.17, 0.22, 0.30, 1.0);
uniform vec4 dark : hint_color = vec4(0.03, 0.04, 0.065, 1.0);

varying vec2 info;

void vertex() {
	info = UV2;
}

void fragment() {
	vec2 uv = UV;
	float kind = floor(info.x * 3.0 + 0.5);
	float seed = info.y;
	vec3 room = COLOR.rgb;
	float lit = COLOR.a;
	// what hangs in the window
	float cover = 0.0;
	if (kind > 0.5 && kind < 1.5) cover = step(uv.x, 0.22) + step(0.78, uv.x);
	else if (kind > 1.5 && kind < 2.5) cover = 0.6 * step(0.45, fract(uv.y * 11.0 + seed));
	else if (kind > 2.5) cover = step(uv.y, 0.42 + seed * 0.2);
	cover = clamp(cover, 0.0, 1.0);
	// by day: the sky in the glass, lighter at the top, a soft diagonal glint
	vec3 refl = mix(sky_hi.rgb, sky_lo.rgb, smoothstep(0.0, 1.0, uv.y));
	float glint = smoothstep(0.07, 0.0, abs(uv.x * 0.8 - uv.y * 0.55 + 0.05 - seed * 0.45)) * 0.32;
	vec3 day = refl + vec3(glint);
	day = mix(day, room * 0.45 + vec3(0.22), cover * 0.55);
	day = mix(day, room * 0.9, lit * 0.25 * (1.0 - cover));
	// at night: the room's light (brightest in the middle, curtains darker), or dark glass
	float glow = lit * (0.8 + 0.2 * (1.0 - abs(uv.x - 0.5) * 1.8)) * (1.0 - uv.y * 0.25);
	vec3 inside = room * glow * mix(1.0, 0.5, cover);
	vec3 nite = mix(dark.rgb + refl * 0.05, inside * 1.35, step(0.02, lit));
	ALBEDO = mix(day, nite, night);
}
