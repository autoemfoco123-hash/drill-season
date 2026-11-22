extends Node
# The sky and the weather: drives scripts/sky.shader (drawn behind the 3D world), picks the
# day's weather from the shared clock (so everyone online sees the same sky): clear, broken
# cloud, overcast, or thundersnow in the evening, with lightning bolts, cloud flashes and
# thunder that arrives late from far strikes. The moon goes through its phases, the stars
# turn through the night, and on rare clear nights the northern lights come out.
# During a storm, lightning sometimes hits the memorial wall (Memorial.gd lights it up).

var main
var layer
var rect
var mat
var q = 1.0
var last_t = 0.0
var cover = 0.45
var storm = 0.0
var aurora = 0.0
var flash = 0.0
var flash_az = 0.0
var flash_seq = []          # [[time from now, strength]]
var bolt_life = 0.0
var bolt = Vector3()        # az, top, seed
var next_strike = 6.0
var memorial_due = -1.0
var memorial_target = ""
var summon_until = -1.0
var ss_t = -1.0
var ss_a = Vector3()
var ss_b = Vector3()
var next_ss = 20.0
var forced_storm = false
var strikes = 0
var override = {}           # tests: {"cover": x, "storm": x, "aurora": x}

func setup(m):
	main = m
	forced_storm = OS.get_environment("DS_STORM") != ""
	mat = ShaderMaterial.new()
	mat.shader = load("res://scripts/sky.shader")
	var tex = load("res://assets/art/skynoise.png")
	tex.flags = Texture.FLAG_REPEAT | Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS
	mat.set_shader_param("noise", tex)
	layer = CanvasLayer.new(); layer.layer = -1; add_child(layer)
	rect = ColorRect.new(); rect.anchor_right = 1; rect.anchor_bottom = 1; rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat
	layer.add_child(rect)
	main.env.background_mode = Environment.BG_CANVAS
	main.env.background_canvas_max_layer = -1
	set_quality(G.S.get("settings", {}).get("quality", "low"))
	last_t = G.REAL_T

func set_quality(qs):
	q = 2.0 if qs == "high" else (1.0 if qs == "medium" else 0.0)
	if mat: mat.set_shader_param("quality", q)

func _h(x):
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)

# the day's weather from the shared clock
func weather_now():
	var ws = G.world_seconds()
	var day = floor(ws / 1440.0)
	var hr = G.world_minutes() / 60.0
	var base = [0.3, 0.45, 0.6, 0.8][int(_h(day + 0.3) * 4.0) % 4]
	var drift = sin(ws / 1440.0 * TAU * 3.0 + day) * 0.12
	var stormy_day = _h(day + 7.1) < 0.4
	var evening = hr > 18.5 or hr < 2.5
	var st = 1.0 if forced_storm or (stormy_day and evening) or G.REAL_T < summon_until else 0.0
	var au = 1.0 if (_h(day + 3.3) < 0.25 and base < 0.45 and not stormy_day) else 0.0
	var out = [clamp(base + drift, 0.05, 0.95), st, au, day]
	if override.has("cover"): out[0] = override.cover
	if override.has("storm"): out[1] = override.storm
	if override.has("aurora"): out[2] = override.aurora
	return out

# called by Main.update_day_night every frame, after it set fog and light
func frame():
	var dt = clamp(G.REAL_T - last_t, 0.0, 0.1)
	last_t = G.REAL_T
	var DN = main.DN
	var env = main.env
	var w = weather_now()
	var summoned = G.REAL_T < summon_until
	storm = move_toward(storm, w[1], dt * (0.3 if summoned else 0.08))
	var want_cover = lerp(w[0], 0.93, storm)
	cover = move_toward(cover, want_cover, dt * (0.2 if summoned else 0.02))
	aurora = move_toward(aurora, w[2], dt * 0.05)
	var n = DN.night
	# storm darkens the world; lightning lights it up
	_lightning(dt)
	var fog = env.fog_color
	fog = fog.linear_interpolate(Color(fog.r * 0.55, fog.g * 0.58, fog.b * 0.66), storm * 0.8)
	fog = fog.linear_interpolate(Color(0.62, 0.66, 0.8), min(1.0, flash * 0.55))
	env.fog_color = fog
	env.background_color = fog
	env.ambient_light_energy = env.ambient_light_energy * (1.0 - storm * 0.25) + flash * 1.4
	main.sun.light_energy *= (1.0 - storm * 0.55)
	# toon lighting puts the full light on every lit face (no cosine fall-off): tone it down
	main.sun.light_energy *= 0.58
	env.ambient_light_energy *= 0.8
	# keep the far plane inside the fog so nothing pops against the sky
	env.fog_depth_end = min(env.fog_depth_end, main.camera.far * 0.92) * (1.0 - storm * 0.25)
	# colours
	var zen = Color(0.2, 0.4, 0.72).linear_interpolate(Color(0.16, 0.2, 0.42), DN.dusk * 0.8).linear_interpolate(Color(0.006, 0.01, 0.028), n)
	var e = DN.elev
	var sc = Color(1.0, 0.42, 0.18).linear_interpolate(Color(1.0, 0.95, 0.86), main._smooth(-1, 22, e))
	var lit_day = Color(1.0, 0.99, 0.96)
	var dark_day = Color(0.56, 0.61, 0.7)
	var lit_dusk = Color(1.0, 0.6, 0.38)
	var dark_dusk = Color(0.37, 0.29, 0.38)
	var lit_night = Color(0.12, 0.14, 0.2)
	var dark_night = Color(0.04, 0.042, 0.058)
	var cl = lit_day.linear_interpolate(lit_dusk, DN.dusk).linear_interpolate(lit_night, n)
	var cd = dark_day.linear_interpolate(dark_dusk, DN.dusk).linear_interpolate(dark_night, n)
	cl = cl.linear_interpolate(cd, storm * 0.5)
	# heavy cover is greyer, not whiter
	var ov = cover * cover
	cl = Color(cl.r * (1.0 - 0.32 * ov), cl.g * (1.0 - 0.3 * ov), cl.b * (1.0 - 0.27 * ov))
	cd = Color(cd.r * (1.0 - 0.22 * ov), cd.g * (1.0 - 0.2 * ov), cd.b * (1.0 - 0.18 * ov))
	# moon: opposite the sun, through a 8-day cycle of the shared clock
	var mp = fposmod(G.world_seconds() / 1440.0 / 8.0, 1.0)
	var md = main._dir(-e * 0.9 + 6.0, DN_az() + 180.0)
	# stars turn with the night
	var sr = G.world_minutes() / 1440.0 * TAU
	var cam = get_viewport().get_camera()
	if cam == null: return
	var b = cam.global_transform.basis
	var vs = get_viewport().size
	mat.set_shader_param("cam_x", b.x)
	mat.set_shader_param("cam_y", b.y)
	mat.set_shader_param("cam_z", b.z)
	mat.set_shader_param("tan_half", tan(deg2rad(cam.fov) * 0.5))
	mat.set_shader_param("aspect", vs.x / max(1.0, vs.y))
	mat.set_shader_param("horizon", _v(fog))
	mat.set_shader_param("zenith", _v(zen.linear_interpolate(Color(zen.r * 0.4, zen.g * 0.42, zen.b * 0.5), storm * 0.7)))
	mat.set_shader_param("sun_dir", DN.sun_dir)
	mat.set_shader_param("sun_col", _v(sc))
	mat.set_shader_param("sun_vis", main._smooth(-4, 2, e) * (1.0 - storm * 0.8))
	mat.set_shader_param("moon_dir", md)
	mat.set_shader_param("moon_phase", mp)
	mat.set_shader_param("night", n)
	mat.set_shader_param("dusk", DN.dusk)
	mat.set_shader_param("cover", cover)
	mat.set_shader_param("storm", storm)
	mat.set_shader_param("cloud_lit", _v(cl))
	mat.set_shader_param("cloud_dark", _v(cd))
	var ws = G.world_seconds()
	mat.set_shader_param("wind", Vector2(fposmod(ws * 0.0011, 1.0), fposmod(ws * 0.0004, 1.0)))
	mat.set_shader_param("t", fposmod(G.REAL_T, 600.0))
	mat.set_shader_param("star_rot", Vector2(cos(sr), sin(sr)))
	mat.set_shader_param("aurora", aurora * n)
	mat.set_shader_param("flash", flash)
	mat.set_shader_param("flash_az", flash_az)
	mat.set_shader_param("bolt", Plane(bolt.x, bolt.y, bolt.z, clamp(bolt_life / 0.12, 0.0, 1.0) if bolt_life > 0 else 0.0))
	_shooting(dt, n)
	mat.set_shader_param("ss_a", ss_a)
	mat.set_shader_param("ss_b", ss_b)
	mat.set_shader_param("ss_t", ss_t)

func DN_az():
	return main.sun_angles(G.world_minutes())[1]

func _v(c):
	return Vector3(c.r, c.g, c.b)

func _shooting(dt, n):
	if ss_t >= 0:
		ss_t += dt / 0.7
		if ss_t > 1.2: ss_t = -1.0
		return
	next_ss -= dt
	if next_ss <= 0 and n > 0.6 and storm < 0.2:
		next_ss = rand_range(12, 40)
		var a = rand_range(-PI, PI)
		var e = rand_range(0.35, 0.8)
		ss_a = Vector3(cos(e) * sin(a), sin(e), -cos(e) * cos(a))
		var a2 = a + rand_range(-0.35, 0.35)
		var e2 = e - rand_range(0.12, 0.25)
		ss_b = Vector3(cos(e2) * sin(a2), sin(e2), -cos(e2) * cos(a2))
		ss_t = 0.0

# ---------- lightning ----------
func _lightning(dt):
	# the flash sequence: a strike flickers two or three times
	var f = 0.0
	for s in flash_seq:
		s[0] -= dt
		if s[0] <= 0 and s[0] > -0.09: f = max(f, s[1] * (1.0 + s[0] / 0.09))
	while flash_seq.size() > 0 and flash_seq[0][0] < -0.1: flash_seq.pop_front()
	flash = f
	bolt_life = max(0.0, bolt_life - dt)
	if storm < 0.5: return
	if memorial_due >= 0:
		memorial_due -= dt
		if memorial_due < 0: strike(memorial_target)
		return
	next_strike -= dt
	if next_strike <= 0:
		next_strike = rand_range(5.0, 16.0) / max(0.6, storm)
		var tgt = main.memorial.target_near(85.0)
		strike(tgt if randf() < 0.45 else "")

# a lightning strike, far away in the sky, or on a memorial ("wall" or "garden")
func strike(target = ""):
	strikes += 1
	var cam = main.camera.global_transform.origin
	var az
	var dist
	var on_memorial = target != ""
	if on_memorial:
		var to = main.memorial.target_pos(target) - cam
		az = atan2(to.x, -to.z)
		dist = Vector2(to.x, to.z).length()
		main.memorial.lightning(target)
	else:
		az = rand_range(-PI, PI)
		dist = rand_range(350.0, 2600.0)
		bolt = Vector3(az, rand_range(0.12, 0.3) * (900.0 / max(400.0, dist)) + 0.08, randf())
		bolt_life = 0.42
	flash_az = az
	var k = 1.0 if on_memorial else clamp(1200.0 / dist, 0.35, 1.0)
	flash_seq = [[0.0, k], [0.11, k * 0.45], [0.2, k * 0.85]]
	if randf() < 0.5: flash_seq.append([0.34, k * 0.4])
	# thunder: sound travels 343 m/s
	var delay = min(dist / 343.0, 7.0)
	if on_memorial: return          # the memorial plays its own crack right away
	var near = dist < 500
	_thunder(delay, "thunder_near" if near else "thunder_far", clamp(1.1 - dist / 3000.0, 0.35, 1.0))

func _thunder(delay, nm, vol):
	if delay > 0.05:
		yield(get_tree().create_timer(delay), "timeout")
	main.sfx.play(nm, vol * 0.9, rand_range(0.85, 1.08))

# the memorial asks for a strike soon (paying respects during a storm)
func strike_soon(target, after):
	memorial_target = target; memorial_due = after

# paying respects at the mausoleum: the storm gathers in seconds and lightning answers
func summon(secs, target, after):
	summon_until = G.REAL_T + secs
	next_strike = 1.5
	strike_soon(target, after)
