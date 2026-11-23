extends Node
# Sound: the web game's synthesized bank (assets/sfx) plus extra synthesized ambience
# (assets/sfx2, tools/make-sfx.py), mixed through buses:
#   Master  compressor + limiter
#   Out     everything heard from the street; low-passed and lowered when you sit in a
#           car (first person) or are indoors
#   World   footsteps, impacts, people, cars: a small reverb sized by how built-up it is
#   Guns    gunshots: urban slap-back echoes timed from the nearest walls, plus a big reverb
#   Amb     wind, the distant city, fire barrels, steam, far-off sirens, dogs, planes, ice
#   Car     your engine (synthesized live with gears), tyres, wind noise
#   Radio, UI
# Plus the quick visual effects: tracers, muzzle flashes, blood and dust.

var main
var files = {}          # name -> [paths]
var cache = {}
var p3 = []
var pg = []
var p2 = []
var i3 = 0
var ig = 0
var i2 = 0
var tracers = []
var ti = 0
var bits = []
var flash_light = null
var flash_t = 0.0
var radio = null
var radio_st = -1
var engine_car = null
var B = {}
var out_lp = -1
var world_rev = null
var gun_delay = null
var gun_rev = null
var env_t = 0.0
var muffle = 0.0
# your engine (scripts/EngineAudio.gd plays it; here the gearbox and the revs)
var engine_audio = null
var car_lp = null
var E = { "rpm": 800.0, "gear": 0, "shift_t": 0.0, "start_t": 0.0, "red": 6200.0, "idle": 750.0, "blip_t": 0.0, "limiter": false }
var tires = {}
# ambience
var amb = {}
var fire_snd = []
var steam_snd = []
var far_t = 4.0
var creak_t = 6.0
var pass_cd = {}
const STATIONS = ["", "wcld", "hawk", "northline", "lowend"]

func setup(m):
	main = m
	_index("res://assets/sfx")
	_index("res://assets/sfx2")
	_make_buses()
	for _i in range(18):
		var a = AudioStreamPlayer3D.new()
		a.unit_size = 6; a.max_distance = 150; a.attenuation_filter_cutoff_hz = 7000; a.attenuation_filter_db = -18; a.bus = "World"
		add_child(a); p3.append(a)
	for _i in range(8):
		var g = AudioStreamPlayer3D.new()
		g.unit_size = 22; g.max_distance = 420; g.attenuation_filter_cutoff_hz = 9000; g.attenuation_filter_db = -10; g.bus = "Guns"
		add_child(g); pg.append(g)
	for _i in range(8):
		var b = AudioStreamPlayer.new(); b.bus = "UI"
		add_child(b); p2.append(b)
	var tm = SpatialMaterial.new(); tm.flags_unshaded = true; tm.albedo_color = Color(1, 0.85, 0.55)
	for _i in range(12):
		var t = MeshInstance.new(); var cm = CubeMesh.new(); cm.size = Vector3(0.025, 0.025, 1); t.mesh = cm
		t.material_override = tm; t.visible = false; t.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		main.add_child(t); tracers.append([t, 0.0])
	var bm = SpatialMaterial.new(); bm.flags_unshaded = true; bm.albedo_color = Color(0.45, 0.02, 0.03)
	var dm = SpatialMaterial.new(); dm.flags_unshaded = true; dm.albedo_color = Color(0.85, 0.88, 0.92)
	for i in range(40):
		var b2 = MeshInstance.new(); var c2 = CubeMesh.new(); c2.size = Vector3.ONE * 0.06; b2.mesh = c2
		b2.material_override = bm if i < 28 else dm; b2.visible = false; b2.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		main.add_child(b2); bits.append({ "n": b2, "v": Vector3(), "t": 0.0, "blood": i < 28 })
	flash_light = OmniLight.new(); flash_light.omni_range = 7; flash_light.light_color = Color(1, 0.8, 0.5); flash_light.light_energy = 0; flash_light.visible = false
	main.add_child(flash_light)
	radio = AudioStreamPlayer.new(); radio.bus = "Radio"; add_child(radio)
	# engines: yours, and the cars around you
	engine_audio = load("res://scripts/EngineAudio.gd").new()
	engine_audio.name = "EngineAudio"
	add_child(engine_audio)
	engine_audio.setup(main)
	for k in ["roll", "slush", "skid", "wind"]:
		var t2 = AudioStreamPlayer.new(); t2.bus = "Car"; add_child(t2)
		var st = _loop(k)
		if st: t2.stream = st
		t2.volume_db = -80
		tires[k] = t2
	for k2 in ["wind", "city"]:
		var a2 = AudioStreamPlayer.new(); a2.bus = "Amb"; add_child(a2)
		var st2 = _loop(k2)
		if st2:
			a2.stream = st2; a2.volume_db = -80; a2.play(randf() * 10)
		amb[k2] = a2
	for _j in range(3):
		var f = AudioStreamPlayer3D.new(); f.bus = "Amb"; f.unit_size = 3; f.max_distance = 35; add_child(f)
		var cs = _loop("crackle")
		if cs: f.stream = cs
		fire_snd.append(f)
	for _j in range(2):
		var sm = AudioStreamPlayer3D.new(); sm.bus = "Amb"; sm.unit_size = 2.5; sm.max_distance = 30; add_child(sm)
		var ss = _loop("steam")
		if ss: sm.stream = ss
		steam_snd.append(sm)

func _index(dir):
	var d = Directory.new()
	if d.open(dir) != OK: return
	d.list_dir_begin(true, true)
	var f = d.get_next()
	while f != "":
		var fn = f.replace(".import", "")
		if fn.ends_with(".ogg"):
			var base = fn.get_basename()
			var nm = base
			if base.length() > 2 and base[base.length() - 2] == "_" and base[base.length() - 1] in ["0", "1", "2", "3", "4"] and not base.begins_with("creak"):
				nm = base.substr(0, base.length() - 2)
			if not files.has(nm): files[nm] = []
			var path = dir + "/" + fn
			if not path in files[nm]: files[nm].append(path)
		f = d.get_next()

func _loop(name):
	if not files.has(name): return null
	var st = load(files[name][0])
	if st == null: return null
	st = st.duplicate()
	st.loop = true
	return st

func _bus(name, send, effects):
	AudioServer.add_bus()
	var i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, send)
	for e in effects: AudioServer.add_bus_effect(i, e)
	B[name] = i
	return i

func _make_buses():
	if AudioServer.get_bus_index("Out") >= 0: return
	if OS.get_environment("DS_NOMASTERFX") == "":
		# gentle glue: the levels below already leave headroom, this only catches pile-ups
		var comp = AudioEffectCompressor.new(); comp.threshold = -9; comp.ratio = 2.0; comp.attack_us = 1500; comp.release_ms = 250; comp.gain = 0.0
		AudioServer.add_bus_effect(0, comp)
		var lim = AudioEffectLimiter.new(); lim.ceiling_db = -0.5; lim.threshold_db = -1.5
		AudioServer.add_bus_effect(0, lim)
	var lp = AudioEffectLowPassFilter.new(); lp.cutoff_hz = 1200; lp.resonance = 0.4
	var o = _bus("Out", "Master", [lp])
	AudioServer.set_bus_effect_enabled(o, 0, false)
	out_lp = lp
	world_rev = AudioEffectReverb.new(); world_rev.room_size = 0.45; world_rev.damping = 0.65; world_rev.spread = 0.8; world_rev.hipass = 0.25; world_rev.dry = 1.0; world_rev.wet = 0.1; world_rev.predelay_msec = 22
	_bus("World", "Out", [world_rev])
	gun_delay = AudioEffectDelay.new(); gun_delay.dry = 1.0
	gun_delay.set_tap1_active(true); gun_delay.set_tap1_delay_ms(140); gun_delay.set_tap1_level_db(-9); gun_delay.set_tap1_pan(-0.35)
	gun_delay.set_tap2_active(true); gun_delay.set_tap2_delay_ms(300); gun_delay.set_tap2_level_db(-14); gun_delay.set_tap2_pan(0.35)
	gun_delay.set_feedback_active(false)
	gun_rev = AudioEffectReverb.new(); gun_rev.room_size = 0.75; gun_rev.damping = 0.45; gun_rev.spread = 1.0; gun_rev.hipass = 0.3; gun_rev.dry = 1.0; gun_rev.wet = 0.2; gun_rev.predelay_msec = 40
	_bus("Guns", "Out", [gun_delay, gun_rev])
	_bus("Amb", "Out", [])
	# the cabin: in the driver's seat the car's own sounds lose their top end
	car_lp = AudioEffectLowPassFilter.new(); car_lp.cutoff_hz = 20000; car_lp.resonance = 0.55
	_bus("Car", "Master", [car_lp])
	var hp = AudioEffectHighPassFilter.new(); hp.cutoff_hz = 70
	_bus("Radio", "Master", [hp])
	_bus("UI", "Master", [])
	# gain staging: gunshots are the loudest thing, the city sits underneath
	for v in [["World", -3.0], ["Guns", -1.0], ["Amb", -3.0], ["Car", -5.0], ["Radio", -4.0], ["UI", -5.0]]:
		AudioServer.set_bus_volume_db(B[v[0]], v[1])

func stream(name):
	if not files.has(name): return null
	var path = G.pick(files[name])
	if not cache.has(path):
		var st = load(path)
		# one-shots must never loop (Godot imports OGG with looping on by default)
		if st: st.loop = false
		cache[path] = st
	return cache[path]

func _vol(v):
	return linear2db(max(0.0001, v * float(G.S["settings"].get("vol", 0.8))))

func play(name, vol = 0.6, pitch = 1.0):
	var s = stream(name)
	if s == null: return
	var a = p2[i2]; i2 = (i2 + 1) % p2.size()
	a.stream = s; a.volume_db = _vol(vol); a.pitch_scale = pitch * G.rand(0.95, 1.05); a.play()

# a room clapping and whooping (the web game's sfx.cheer)
func cheer():
	for i in range(14):
		_cheer_clap(randf() * 1.6)
	play("whoosh", 0.2, 0.7)

func _cheer_clap(delay):
	yield(get_tree().create_timer(delay + 0.01), "timeout")
	play("clap", 0.14 + randf() * 0.1, 0.85 + randf() * 0.3)

func play3d(name, at, vol = 0.6, pitch = 1.0, bus = "World"):
	var st = stream(name)
	if st == null: return null
	var a
	if bus == "Guns":
		a = pg[ig]; ig = (ig + 1) % pg.size()
	else:
		a = p3[i3]; i3 = (i3 + 1) % p3.size()
		a.bus = bus
	a.stream = st; a.translation = at; a.unit_db = _vol(vol) + 6; a.pitch_scale = pitch * G.rand(0.93, 1.07); a.play()
	return a

func play3d_later(delay, name, at, vol = 0.6, pitch = 1.0, bus = "World"):
	yield(get_tree().create_timer(delay), "timeout")
	play3d(name, at, vol, pitch, bus)

# ---------- people ----------
func surface(at):
	if at.y > 200: return "step_floor"      # the walk-in rooms (they're built up in the sky)
	if at.y > 5.5: return "step_metal"
	if at.y > 0.35: return "step_hard"
	var hw = float(G.D["ROAD_HW"])
	for x in G.D["XL"]:
		if abs(at.x - x) < hw: return "step_slush"
	for z in G.D["ZL"]:
		if abs(at.z - z) < hw and at.x < float(G.D["ROAD_X_END"]): return "step_slush"
	return "step_snow"

# light sneaker steps: quiet, bright and one per footfall (the player calls this when a foot of
# the walk cycle lands). Left and right are pitched a hair apart so a walk doesn't drone.
const STEP_VOL = { "step_hard": 0.9, "step_snow": 1.0, "step_slush": 0.85, "step_metal": 0.75, "step_floor": 0.8 }
func step(at, run, soft = false, foot = 0):
	var surf = surface(at)
	var v = (0.2 if run else 0.15) * (0.55 if soft else 1.0) * STEP_VOL.get(surf, 1.0)
	var p = (1.025 if foot % 2 == 0 else 0.975) * (1.04 if run else 1.0)
	play3d(surf, at + Vector3(0, 0.05, 0), v, p)
	if run and randf() < 0.15: play3d("rustle", at + Vector3(0, 1.1, 0), 0.06)

func land(at, fall):
	play3d("bodyfall", at, clamp(fall * 0.12, 0.15, 0.7), 1.25)
	play3d(surface(at), at, 0.28, 0.95)

func thump(at, v):
	play3d("bodyfall", at, clamp(v * 0.06, 0.1, 0.6), G.rand(0.9, 1.2))

# ---------- guns ----------
func shot(kind, at, vol = 1.0, suppressed = false):
	# the two newer guns borrow the closest sound, pitched: the AK pistol lower and louder,
	# the machine pistol higher and snappier
	var pitch = 1.0
	var k = kind
	if kind == "dragon":
		k = "draft"; pitch = 0.78; vol *= 1.35
	elif kind == "buzz":
		k = "draft"; pitch = 1.14; vol *= 0.9
	elif not kind in ["k9", "draft", "plow"]:
		k = "k9"
	var name = "gun_" + k + ("_s" if suppressed else "")
	play3d(name, at, vol * (1.25 if k == "plow" else (0.85 if k == "draft" else 1.0)) * (0.6 if suppressed else 1.0), pitch, "Guns")
	# brass on the ground, if it's close enough to hear
	var cam = main.camera.global_transform.origin
	if at.distance_to(cam) < 14:
		var floor_at = Vector3(at.x, W.ground_at(at.x, at.z, at.y) + 0.02, at.z)
		play3d_later(G.rand(0.35, 0.6), "shell" if kind == "plow" else "casing", floor_at, 0.22)

func impact(at, metal = false):
	play3d("imp_metal" if metal else ("imp_snow" if at.y < 0.22 else "imp_brick"), at, 0.5)
	if metal and randf() < 0.3: play3d("ricochet", at, 0.35)
	_spawn_bits(at, Vector3.UP, 4, false)

func dust(at, n = 5):
	_spawn_bits(at, Vector3.UP, n, false)

func blood(at, dir):
	_spawn_bits(at, dir, 6, true)

func _spawn_bits(at, dir, n, blood):
	var d = Vector3(dir.x, 0, dir.z)
	if d.length() > 0.01: d = d.normalized()
	for b in bits:
		if n <= 0: break
		if b.t > 0 or b.blood != blood: continue
		b.t = G.rand(0.35, 0.7); b.n.visible = true; b.n.translation = at
		b.v = d * G.rand(0.5, 2.5) + Vector3(G.rand(-1.2, 1.2), G.rand(0.4, 2.8), G.rand(-1.2, 1.2))
		n -= 1

func tracer(a, b):
	var t = tracers[ti]; ti = (ti + 1) % tracers.size()
	var L = a.distance_to(b)
	if L < 0.1: return
	var m = t[0]
	m.visible = true
	m.global_transform = Transform(Basis(), (a + b) / 2).looking_at(b, Vector3.UP if abs((b - a).normalized().y) < 0.99 else Vector3(1, 0, 0))
	m.scale = Vector3(1, 1, L)
	t[1] = 0.07
	# a round going past your head: the crack and whiz
	var cam = main.camera.global_transform.origin
	if a.distance_to(cam) > 6:
		var ab = b - a
		var k = clamp((cam - a).dot(ab) / ab.length_squared(), 0, 1)
		var c = a + ab * k
		if c.distance_to(cam) < 3.0 and k > 0.05 and k < 0.98: play3d("whiz", c, 0.55)

func flash(at):
	flash_light.translation = at; flash_light.light_energy = 4.0; flash_light.visible = true; flash_t = 0.05

# ---------- car radio ----------
func next_station():
	if main.music.active(): main.music.stop()     # back to the radio from the Music app
	var s2 = int(G.S["settings"].get("radio", 1))
	s2 = (s2 + 1) % STATIONS.size()
	G.S["settings"]["radio"] = s2
	play("static", 0.25)
	_radio_refresh(true)

func _radio_refresh(announce = false):
	# no radio while the phone's Music app is playing
	var want = int(G.S["settings"].get("radio", 1)) if main.player.car and not main.music.active() else 0
	if want == radio_st: return
	radio_st = want
	if want <= 0:
		radio.stop()
		if announce: main.hud.toast("Radio off")
		return
	var st = load("res://assets/music/" + STATIONS[want] + ".ogg")
	if st == null: return
	st.loop = true
	radio.stream = st
	# every player hears the same moment of the song: start from the shared clock
	radio.play(fposmod(G.world_seconds(), st.get_length()))
	main.hud.toast(G.D["STATIONS"][want].name)

# ---------- your engine ----------
func engine_on(v):
	engine_car = v
	engine_audio.start(v.model)
	E.idle = engine_audio.idle_rpm(); E.red = engine_audio.red_rpm()
	E.rpm = 0.0; E.gear = 0; E.shift_t = 0.0; E.start_t = 0.9; E.blip_t = 0.0
	play("starter", 0.55)
	for k in tires.keys():
		if tires[k].stream:
			tires[k].volume_db = -80; tires[k].play(randf() * 2)
	radio_st = -1
	_radio_refresh(true)

func engine_off():
	engine_car = null
	engine_audio.stop()
	for k in tires.keys(): tires[k].stop()
	radio_st = -1; radio.stop()

func engine_state():
	return { "rpm": E.rpm, "red": E.red, "gear": E.gear, "idle": E.idle, "boost": engine_audio.boost if engine_audio else 0.0 }

func _engine(dt):
	var v = engine_car
	if v == null or v.dead or engine_audio == null or engine_audio.prof == null: return
	var inp = main.vehicles._player_input()
	var sp = abs(v.speed)
	var thr = clamp(abs(inp.thr), 0, 1)
	if v.spin > 0.2: thr = max(thr, float(inp.get("gas", 0.0)))    # a burnout: foot down on both pedals
	var rev = v.speed < -0.3
	var wheel_rps = sp / (TAU * float(v.sp.get("r", 0.33)))
	var GEARS = G.D["GEARS"]
	var FINAL = float(G.D["FINAL"])
	var old_gear = E.gear
	if rev: E.gear = 0
	elif E.shift_t <= 0:
		if E.gear < GEARS.size() - 1 and wheel_rps * 60 * GEARS[E.gear] * FINAL > (E.red * 0.92 if thr > 0.5 else 2700.0 + thr * 1800.0):
			E.gear += 1; E.shift_t = 0.2
			engine_audio.upshift(thr, E.rpm)
		elif E.gear > 0 and wheel_rps * 60 * GEARS[E.gear - 1] * FINAL < (E.red * 0.7 if thr > 0.5 else 2000.0):
			E.gear -= 1; E.shift_t = 0.12
			# a throttle blip to match the revs on the way down
			if sp > 6: E.blip_t = 0.22
	if E.gear > old_gear: play("shift", 0.22)
	var rpm = max(E.idle, wheel_rps * 60 * GEARS[E.gear] * FINAL)
	if sp < 5 and thr > 0.05: rpm = max(rpm, E.idle + thr * 2600 * (1 - sp / 6.0))
	# wheelspin and burnouts: the wheels spin far faster than the car moves
	if v.slip > 0.2 and thr > 0.3: rpm = max(rpm, E.red * (0.55 + 0.35 * v.slip))
	var eload = thr
	if E.shift_t > 0:
		E.shift_t -= dt; rpm *= 0.86; eload = 0.12
	if E.blip_t > 0:
		E.blip_t -= dt; rpm *= 1.0 + 0.16 * sin(E.blip_t / 0.22 * PI); eload = max(eload, 0.75)
	# the idle holds itself up: a little throttle the driver doesn't give
	var idle_k = clamp(1.0 - (rpm - E.idle) / 700.0, 0.0, 1.0)
	eload = max(eload, idle_k * 0.32)
	E.limiter = false
	if E.start_t > 0:
		E.start_t -= dt
		rpm = 0.0 if E.start_t > 0.6 else E.idle + (1 - E.start_t / 0.6) * 1000
	if rpm >= E.red:
		rpm = E.red - randf() * 260
		E.limiter = thr > 0.3
	# the crank has weight: it spins up fast under power and winds down slower
	var k = 12.0 if rpm > E.rpm else 7.0
	E.rpm = lerp(E.rpm, rpm, min(1.0, dt * k))
	var inside = 1.0 if (main.player.car == v and main.player.fp_on()) else 0.0
	engine_audio.update(E.rpm, eload, E.start_t <= 0.6, v.speed, inside, E.limiter, dt)
	if car_lp: car_lp.cutoff_hz = lerp(20000.0, 3200.0, engine_audio.interior)
	# tyres, slush and wind on the body
	var l = Vector3(cos(v.yaw), 0, -sin(v.yaw))
	var lat = abs(v.vel.x * l.x + v.vel.y * l.z)
	_set_vol(tires.roll, clamp(sp / 22.0, 0, 1) * 0.32, 0.7 + sp / 45.0)
	_set_vol(tires.slush, clamp(sp / 18.0, 0, 1) * 0.16, 1.0)
	var skid = max(clamp((lat - 2.6) / 5.0, 0, 1) + (0.35 if v.brake and sp > 9 else 0.0), v.slip)
	_set_vol(tires.skid, min(1.0, skid) * 0.3, 0.9 + sp / 80.0)
	_set_vol(tires.wind, pow(sp / 35.0, 2) * (0.16 if inside < 0.5 else 0.1), 1.2)

func _set_vol(p, v, pitch):
	if p.stream == null: return
	p.volume_db = _vol(max(0.0001, v))
	p.pitch_scale = clamp(pitch, 0.3, 3.0)

# ---------- ambience ----------
func _env(dt):
	var P = main.player
	var cam = main.camera.global_transform.origin
	# muffle the street when you are inside a car (first person) or indoors
	var want = 0.0
	if P.car and P.fp_on(): want = 1.0
	if G.MODE in ["menu", "studio", "bench", "wardrobe", "cut"]: want = 1.0
	muffle = move_toward(muffle, want, dt * 3)
	var o = B.get("Out", -1)
	if o >= 0:
		AudioServer.set_bus_effect_enabled(o, 0, muffle > 0.05)
		out_lp.cutoff_hz = lerp(20000.0, 900.0, muffle)
		AudioServer.set_bus_volume_db(o, -7.0 * muffle)
	env_t -= dt
	if env_t <= 0:
		env_t = 0.5
		# how built-up it is around you: more walls, more reverb and closer echoes
		var near = INF
		var walls = 0
		for a in range(8):
			var d = Vector3(cos(a * TAU / 8), 0, sin(a * TAU / 8))
			var t = W.raycast(cam, d, 60.0)
			if t != INF:
				walls += 1
				near = min(near, t)
		world_rev.wet = 0.05 + walls * 0.015
		world_rev.room_size = 0.3 + walls * 0.05
		if near == INF: near = 60.0
		var d1 = clamp(2 * near / 343.0 * 1000, 40, 340)
		gun_delay.set_tap1_delay_ms(d1)
		gun_delay.set_tap1_level_db(-8 - near * 0.12)
		gun_delay.set_tap2_delay_ms(clamp(d1 * 2.1 + 40, 90, 900))
		gun_delay.set_tap2_level_db(-13 - near * 0.1)
		gun_rev.wet = 0.12 + walls * 0.012
	var st = main.story
	var night = main.DN.night
	var title = G.MODE == "title"
	var gust = st.WIND.gust if st else 0.2
	var expo = st.exposure if st else 1.0
	if amb.wind.stream:
		_set_vol(amb.wind, (0.1 + gust * 0.5 * expo) * (0.8 if title else 1.0), 0.92 + gust * 0.16)
	if amb.city.stream:
		_set_vol(amb.city, lerp(0.3, 0.17, night), 1.0)
	# fire barrels and steam vents where the particles are
	var fires = main.fx.fires
	for i in range(fire_snd.size()):
		var f = fire_snd[i]
		if i < fires.size() and fires[i].visible and f.stream:
			f.translation = fires[i].translation
			if not f.playing: f.play(randf() * 8)
			f.unit_db = _vol(0.5) + 4
		elif f.playing: f.stop()
	var steams = main.fx.steams
	for j in range(steam_snd.size()):
		var sm = steam_snd[j]
		if j < steams.size() and steams[j].visible and sm.stream:
			sm.translation = steams[j].translation
			if not sm.playing: sm.play(randf() * 2)
			sm.unit_db = _vol(0.3) + 2
		elif sm.playing: sm.stop()
	# the city far away: sirens, dogs, the L, planes, helicopters, horns
	far_t -= dt
	if far_t <= 0:
		far_t = G.rand(3.5, 9.0)
		var pool = ["siren_far", "plane", "horn", "carpass", "train_horn", "heli"]
		if night > 0.5: pool += ["dog", "dog", "siren_far"]
		var nm = G.pick(pool)
		var a2 = randf() * TAU
		var d2 = G.rand(55, 140)
		var at = cam + Vector3(cos(a2) * d2, G.rand(2, 30) if nm in ["plane", "heli"] else 2.0, sin(a2) * d2)
		var pl = play3d(nm, at, G.rand(0.25, 0.5), G.rand(0.9, 1.05), "Amb")
		if pl: pl.unit_db += 14
	# lake ice
	if cam.x > float(G.D["LAKE_X"]) - 60:
		creak_t -= dt
		if creak_t <= 0:
			creak_t = G.rand(5, 13)
			play3d("creak_%d" % (randi() % 3), Vector3(G.rand(float(G.D["LAKE_X"]) + 5, float(G.D["LAKE_X"]) + 70), 0.1, cam.z + G.rand(-60, 60)), G.rand(0.4, 0.8), 1.0, "Amb")
	# traffic passing close
	for v in main.vehicles.VEH:
		if v.dead or v == main.player.car or abs(v.speed) < 7: continue
		var d3 = Vector2(v.pos.x - cam.x, v.pos.z - cam.z).length()
		if d3 < 7 and G.REAL_T - pass_cd.get(v.id, -99.0) > 4:
			pass_cd[v.id] = G.REAL_T
			play3d("car_pass", v.pos + Vector3(0, 0.6, 0), clamp(abs(v.speed) / 20.0, 0.3, 0.8))

func update(dt):
	for t in tracers:
		if t[1] > 0:
			t[1] -= dt
			if t[1] <= 0: t[0].visible = false
	for b in bits:
		if b.t > 0:
			b.t -= dt; b.v.y -= 9.8 * dt; b.n.translation += b.v * dt
			if b.t <= 0 or b.n.translation.y < 0.02:
				b.t = 0
				b.n.visible = false
	if flash_t > 0:
		flash_t -= dt
		if flash_t <= 0:
			flash_light.light_energy = 0
			flash_light.visible = false
	_engine(dt)
	if engine_audio: engine_audio.traffic(dt)
	_env(dt)
	if main.player.car == null and radio_st > 0:
		radio_st = 0; radio.stop()
	elif main.player.car and radio_st == -1 and not main.music.active():
		_radio_refresh()
	radio.volume_db = linear2db(max(0.0001, 0.55 * float(G.S["settings"].get("music", 0.85)) * float(G.S["settings"].get("vol", 0.8)) * (1.0 if main.player.fp_on() else 0.75)))
