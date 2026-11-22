// The sky over Calder, drawn behind the 3D world (Environment BG_CANVAS, CanvasLayer -1).
// Rebuilds each pixel's view direction from the camera and paints, back to front:
// gradient + dusk band + Belt of Venus, sun with Mie glow, moon with phases and halo,
// twinkling stars that turn with the night + the Milky Way, northern lights on rare
// nights, shooting stars, two-layer clouds lit by sun / moon / the city's orange glow,
// thundersnow bolts and flashes, and the downtown skyline to the north with lit windows
// and blinking red lights. Noise comes from a tileable texture (mediump-safe on phones).
shader_type canvas_item;

uniform vec3 cam_x;
uniform vec3 cam_y;
uniform vec3 cam_z;
uniform float tan_half = 0.6;
uniform float aspect = 1.7778;
uniform float quality = 1.0;           // 0 low, 1 medium, 2 high
uniform sampler2D noise;

uniform vec3 horizon = vec3(0.64, 0.71, 0.8);
uniform vec3 zenith = vec3(0.2, 0.4, 0.72);
uniform vec3 sun_dir = vec3(0.3, 0.5, -0.8);
uniform vec3 sun_col = vec3(1.0, 0.95, 0.88);
uniform float sun_vis = 1.0;
uniform vec3 moon_dir = vec3(-0.3, 0.5, 0.8);
uniform float moon_phase = 0.5;        // 0 new, 0.5 full
uniform float night = 0.0;
uniform float dusk = 0.0;
uniform float cover = 0.45;            // cloud cover 0..1
uniform float storm = 0.0;
uniform vec3 cloud_lit = vec3(1.0, 0.99, 0.96);
uniform vec3 cloud_dark = vec3(0.56, 0.61, 0.70);
uniform vec2 wind = vec2(0.0, 0.0);    // already wrapped to 0..1
uniform float t = 0.0;                 // seconds, wrapped
uniform vec2 star_rot = vec2(1.0, 0.0);
uniform float aurora = 0.0;
uniform vec4 bolt = vec4(0.0, 0.25, 0.3, 0.0);  // azimuth, top elevation, seed, intensity
uniform float flash = 0.0;
uniform float flash_az = 0.0;
uniform vec3 ss_a = vec3(0.0, 1.0, 0.0);
uniform vec3 ss_b = vec3(0.0, 1.0, 0.0);
uniform float ss_t = -1.0;

float hash13(highp vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float hash11(highp float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float wrap_pi(float a) {
	return mod(a + 3.14159265, 6.2831853) - 3.14159265;
}

void fragment() {
	vec2 ndc = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	vec3 dir = normalize(cam_x * (ndc.x * tan_half * aspect) + cam_y * (ndc.y * tan_half) - cam_z);
	float h = dir.y;
	float hp = max(h, 0.0);
	float az = atan(dir.x, -dir.z);       // 0 = north (-z), +pi/2 = east (the lake)

	// ---- gradient ----
	vec3 zen = mix(zenith, horizon * vec3(0.86, 0.88, 0.92), cover * cover * 0.65 + storm * 0.3);
	vec3 col = mix(horizon, zen, pow(hp, 0.42));
	vec2 sxz = normalize(sun_dir.xz + vec2(0.0001, 0.0));
	vec2 dxz = normalize(dir.xz + vec2(0.0001, 0.0));
	float toward = dot(dxz, sxz);
	// warm band where the sun sets, Belt of Venus opposite
	col += dusk * exp(-abs(h) * 7.0) * (0.25 + 0.75 * pow(max(toward, 0.0), 3.0)) * vec3(0.62, 0.27, 0.12) * (1.0 - storm * 0.7);
	col += dusk * exp(-abs(h - 0.1) * 12.0) * max(-toward, 0.0) * vec3(0.32, 0.17, 0.30) * (1.0 - storm);
	// the city's orange light glow at night, strongest over downtown
	float dtn = exp(-pow((az + 0.15) / 0.55, 2.0));
	col += night * exp(-hp * 9.0) * (0.55 + 0.45 * dtn) * vec3(0.24, 0.11, 0.045) * (1.0 + cover * 0.8);

	// ---- sun ----
	float mu = dot(dir, sun_dir);
	float mu0 = max(mu, 0.0);
	float above = smoothstep(-0.01, 0.01, h);
	vec3 sun_glow = sun_col * (pow(mu0, 5.0) * 0.2 + pow(mu0, 48.0) * 0.4) * sun_vis;
	float disc = smoothstep(0.99955, 0.99975, mu) * sun_vis * above;

	// ---- clouds ----
	float dens = 0.0;
	float thick = 0.0;
	if (h > 0.0) {
		vec2 cuv = dir.xz / (h + 0.09) * 0.075 + wind;
		vec4 n1 = texture(noise, cuv);
		vec4 n0 = texture(noise, cuv * 0.23 + vec2(0.31, 0.71));
		float d = n1.r * 0.5 + n1.b * 0.32 + n1.g * 0.18;
		if (quality > 0.5) {
			vec4 n2 = texture(noise, cuv * 3.1 + wind * 1.7 + vec2(0.5, 0.2));
			d = d * 0.76 + n2.g * 0.24;
		}
		float cv = clamp(cover + (n0.a - 0.5) * 0.5, 0.0, 1.0);
		float lo = 0.7 - cv * 0.5;
		dens = smoothstep(lo, lo + 0.16 + storm * 0.2, d);
		dens *= smoothstep(0.0, 0.1, h) * (0.88 + 0.12 * cover);
		thick = smoothstep(lo + 0.05, lo + 0.4, d);
	}

	// ---- night sky: stars, Milky Way, aurora, shooting star (all behind the clouds) ----
	if (night > 0.01 && h > -0.02) {
		float clear = (1.0 - dens) * smoothstep(0.0, 0.18, h) * night * (1.0 - storm);
		vec3 sd = vec3(dir.x * star_rot.x - dir.z * star_rot.y, dir.y, dir.x * star_rot.y + dir.z * star_rot.x);
		float mw = 0.0;
		if (quality > 0.5) {
			mw = exp(-pow(dot(sd, normalize(vec3(0.35, 0.55, 0.76))), 2.0) * 16.0);
			float dust = texture(noise, vec2(atan(sd.z, sd.x) * 0.6, sd.y * 0.9) + vec2(0.2, 0.4)).r;
			col += clear * mw * (0.03 + 0.1 * dust * dust) * vec3(0.72, 0.76, 0.95) * (1.0 - 0.6 * exp(-hp * 6.0));
		}
		highp vec3 sp = sd * 118.0;
		highp vec3 cell = floor(sp);
		vec3 f = fract(sp) - 0.5;
		float hs = hash13(cell);
		float th = 0.986 - mw * 0.012;
		if (hs > th) {
			vec3 off = vec3(hash13(cell + 3.1), hash13(cell + 7.7), hash13(cell + 1.3)) - 0.5;
			float b = (hs - th) / (1.0 - th);
			float dd = length(f - off * 0.55);
			float tw = 0.72 + 0.28 * sin(t * (2.0 + hs * 6.0) + hs * 91.0);
			vec3 sc = mix(vec3(0.72, 0.82, 1.0), vec3(1.0, 0.86, 0.68), hash13(cell + 5.5));
			col += sc * smoothstep(0.2 + b * 0.18, 0.0, dd) * (0.3 + b * 1.5) * tw * clear * (1.0 - 0.75 * exp(-hp * 7.0));
		}
		if (aurora > 0.01) {
			float north = exp(-pow((az + 0.25) / 0.9, 2.0));
			float curtain = texture(noise, vec2(az * 0.45 + t * 0.004, 0.37)).r;
			float fold = texture(noise, vec2(az * 1.7 - t * 0.003, 0.61)).g;
			float base = 0.06 + curtain * 0.12 + fold * 0.04;
			float prof = smoothstep(base - 0.01, base + 0.025, h) * exp(-max(h - base, 0.0) * (9.0 - fold * 3.0));
			float rays = texture(noise, vec2(az * 2.6 + fold * 0.9 + t * 0.002, 0.13)).g;
			float rr = 0.72 + 0.28 * smoothstep(0.3, 0.8, rays);
			float bright = smoothstep(0.3, 0.75, curtain * 0.55 + fold * 0.65);
			vec3 ac = mix(vec3(0.12, 1.0, 0.5), vec3(0.6, 0.2, 0.95), smoothstep(0.03, 0.3, h - base));
			col += aurora * north * prof * rr * (0.15 + bright) * ac * 0.6 * clear;
		}
		if (ss_t > 0.0) {
			vec3 ab = ss_b - ss_a;
			float tt = clamp(dot(dir - ss_a, ab) / dot(ab, ab), 0.0, ss_t);
			float dd2 = length(dir - (ss_a + ab * tt));
			float tail = smoothstep(ss_t - 0.4, ss_t, tt);
			col += vec3(0.9, 0.95, 1.0) * smoothstep(0.003, 0.0, dd2) * tail * (1.2 - ss_t) * clear * 1.6;
		}
	}

	// ---- moon ----
	float md = dot(dir, moon_dir);
	if (md > 0.995) {
		vec3 mt = normalize(cross(moon_dir, vec3(0.0, 1.0, 0.0)));
		vec3 mb = cross(mt, moon_dir);
		vec2 mc = vec2(dot(dir, mt), dot(dir, mb)) / 0.032;
		float r2 = dot(mc, mc);
		if (r2 < 1.0) {
			vec3 nrm = vec3(mc, sqrt(1.0 - r2));
			float a = moon_phase * 6.2831853;
			float lit = smoothstep(-0.06, 0.1, dot(nrm, vec3(sin(a), 0.0, -cos(a))));
			float maria = texture(noise, mc * 0.22 + vec2(0.61, 0.13)).r;
			vec3 mcol = vec3(0.93, 0.94, 0.99) * (0.62 + 0.45 * smoothstep(0.3, 0.75, maria)) * lit + vec3(0.03, 0.035, 0.05);
			float edge = smoothstep(1.0, 0.86, r2);
			col = mix(col, mcol * (0.4 + 0.6 * night), edge * above * (1.0 - dens * 0.85));
		}
	}
	float illum = 0.5 - 0.5 * cos(moon_phase * 6.2831853);
	float mglow = (pow(max(md, 0.0), 900.0) * 0.32 + pow(max(md, 0.0), 30.0) * 0.07) * illum * night;
	col += vec3(0.75, 0.82, 1.0) * mglow * (1.0 - dens * 0.5) * above;

	// sun behind clouds
	col += sun_glow * (1.0 - dens * 0.85) * above;
	col = mix(col, sun_col * 2.2, disc * (1.0 - dens * 0.92));

	// cloud colour: lit side, shadowed underside, silver lining, city glow at night, lightning
	vec3 cc = mix(cloud_lit, cloud_dark, clamp(thick * 0.85 + storm * 0.45, 0.0, 1.0));
	cc += sun_col * pow(mu0, 7.0) * (1.0 - thick) * 0.5 * sun_vis * (1.0 - cover * 0.6);
	cc += vec3(0.75, 0.82, 1.0) * pow(max(md, 0.0), 14.0) * (1.0 - thick) * 0.18 * night * illum;
	cc += night * vec3(0.12, 0.055, 0.022) * (0.5 + 0.5 * dtn) * (1.0 - hp) * (0.6 + thick * 0.4);
	cc += night * storm * vec3(0.07, 0.05, 0.045) * (1.0 - hp * 0.6) * (0.5 + thick);
	cc = mix(cc, horizon, exp(-hp * 10.0) * 0.7);
	col = mix(col, cc, dens);

	// ---- lightning ----
	float fa = exp(-abs(wrap_pi(az - flash_az)) * 1.3);
	col += flash * vec3(0.55, 0.6, 0.82) * (0.18 + dens * 0.9 + thick * 0.4) * (0.35 + 0.65 * fa) * (0.5 + 0.5 * exp(-hp * 3.0));
	if (bolt.w > 0.0) {
		float da = wrap_pi(az - bolt.x);
		if (abs(da) < 0.2 && h < bolt.y && h > -0.03) {
			float bh = clamp(h / bolt.y, 0.0, 1.0);
			float off = (texture(noise, vec2(bolt.z, bh * 0.4)).r - 0.5) * 0.11 + (texture(noise, vec2(bolt.z + 0.5, bh * 1.7)).g - 0.5) * 0.035;
			float dx = abs(da - off);
			float off2 = off + (bh - 0.45) * 0.22 * step(0.45, bh) * (bolt.z > 0.5 ? 1.0 : -1.0) + (texture(noise, vec2(bolt.z + 0.25, bh * 2.3)).b - 0.5) * 0.02;
			float dx2 = abs(da - off2) + step(bh, 0.45);
			float core = smoothstep(0.0024, 0.0, dx) + smoothstep(0.0016, 0.0, dx2) * 0.7;
			float glow = exp(-dx * 85.0) * 0.55 + exp(-dx2 * 120.0) * 0.25;
			col += bolt.w * (vec3(0.9, 0.93, 1.0) * core * 2.5 + vec3(0.45, 0.52, 1.0) * glow);
		}
	}

	// ---- downtown to the north: two rows of towers in the haze ----
	if (h < 0.13 && abs(az + 0.15) < 0.95) {
		float env = exp(-pow((az + 0.15) / 0.36, 2.0));
		float edge_fade = smoothstep(0.95, 0.75, abs(az + 0.15));
		highp float ci = floor(az / 0.0105);
		float hb = hash11(ci + 17.0);
		float hgt = (0.004 + pow(hb, 2.6) * 0.075 * env + 0.006 * env) * edge_fade;
		highp float cj = floor((az + 0.004) / 0.0067);
		float hb2 = hash11(cj + 71.0);
		float hgt2 = (0.003 + pow(hb2, 2.0) * 0.03 * (0.4 + env)) * edge_fade;
		float fx_ = fract(az / 0.0105);
		// spires on the tallest towers
		float spire = step(0.9, hb) * env * step(abs(fx_ - 0.5), 0.07) * step(h, hgt + 0.022);
		float b1 = max(step(h, hgt) * step(0.08, fx_) * step(fx_, 0.94), spire);
		float b2 = step(h, hgt2);
		if (b1 + b2 > 0.0) {
			float far_ = b1 > 0.0 ? 1.0 : 0.0;
			vec3 day_b = mix(horizon, vec3(0.32, 0.37, 0.47), far_ > 0.0 ? 0.32 : 0.45);
			vec3 night_b = mix(horizon, vec3(0.012, 0.015, 0.028), 0.55);
			vec3 bc = mix(day_b, night_b, night);
			// windows: a grid per tower, some lit warm, a few cool
			highp vec2 wc = vec2(floor(az / 0.0035), floor(h / 0.0032));
			float wh = hash13(vec3(wc, far_ * 13.0 + ci));
			vec2 wf = vec2(fract(az / 0.0035), fract(h / 0.0032));
			float wmask = smoothstep(0.15, 0.35, wf.x) * smoothstep(0.85, 0.65, wf.x) * smoothstep(0.2, 0.4, wf.y) * smoothstep(0.9, 0.7, wf.y);
			float lit = step(0.58, wh) * wmask * (1.0 - spire);
			vec3 wcol = mix(vec3(1.0, 0.78, 0.45), vec3(0.75, 0.85, 1.0), step(0.93, wh));
			bc += wcol * lit * (0.12 + 0.55 * night) * (far_ > 0.0 ? 0.7 : 1.0) * (0.45 + 0.55 * night);
			// red aircraft lights on the spires
			float tip = spire * step(hgt + 0.017, h);
			bc = mix(bc, vec3(1.0, 0.12, 0.08), tip * step(0.5, fract(t * 0.45 + hb * 7.0)) * (0.3 + 0.7 * night));
			bc += flash * vec3(0.35, 0.38, 0.5) * fa;
			col = bc;
		}
	}

	// below the horizon: haze, then dark ground (mostly hidden by the world)
	if (h < 0.0) {
		col = mix(col, horizon * 0.82, smoothstep(0.0, 0.05, -h) * 0.9);
	}
	// dither to hide banding in the dark
	col += (hash13(vec3(FRAGCOORD.xy, t * 10.0)) - 0.5) / 255.0;
	COLOR = vec4(col, 1.0);
}
