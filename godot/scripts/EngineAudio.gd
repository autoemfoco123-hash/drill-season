extends Node
# Engines, the way racing sims do it: each engine is a ladder of short seamless loops recorded
# at rising RPMs, on throttle and off throttle, in two stems (exhaust, and intake plus
# mechanics). We play the two rungs either side of the engine's RPM, pitched to match it and
# crossfaded with equal power, and blend on/off throttle by the engine's load. Outside the car
# you hear mostly exhaust; in the driver's seat the cabin takes the edge off it and the intake,
# the valve train and the rumble through the floor come up. On top: a turbo spooling up and
# its blow-off valve, the gearbox whine (loudest in reverse), afterfire pops on the overrun and
# on fast upshifts, the rev limiter's stutter. The loops come from tools/make-engines.py.
#
# The cars around you get an engine too (a 3D voice each for the closest few, with Doppler).

var main
var M = {}
var cache = {}
var prof = null
var pname = ""
var rungs = []                  # per rung: { "on_ex", "on_in", "off_ex", "off_in": players, "r_on", "r_off" }
var turbo_p = null
var whine_p = null
var pop_p = []
var bov_p = null
var boost = 0.0
var load_s = 0.0
var last_load = 0.0
var lim_ph = 0.0
var pop_cd = 0.0
var interior = 0.0
var level = 0.0
var voices = []                 # traffic: { "p": AudioStreamPlayer3D, "car": car or null, "prof": name }
var _vt = 0.0
const MODEL_PROFILE = { "hatch": "i4", "taxi": "i4", "sedan": "v6", "suv": "v6", "van": "v6", "coupe": "i6t",
	"pickup": "v8", "police": "v8", "boulder": "v8", "bruiser": "v8s" }
const SPORTY = ["i6t", "v8s"]

func setup(m):
	main = m
	var f = File.new()
	if f.open("res://assets/engine/engines.json", File.READ) == OK:
		var r = JSON.parse(f.get_as_text()); f.close()
		if r.error == OK: M = r.result
	turbo_p = _player(_loop("turbo"))
	whine_p = _player(_loop("whine"))
	bov_p = _player(_clip("bov"))
	for k in range(4):
		pop_p.append(_player(_clip("pop%d" % k)))
	for _i in range(4):
		var p = AudioStreamPlayer3D.new()
		p.bus = "World"
		p.unit_size = 7.0
		p.max_distance = 80.0
		p.attenuation_filter_cutoff_hz = 5000
		p.attenuation_filter_db = -14
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
		add_child(p)
		voices.append({ "p": p, "car": null, "prof": "" })

func profile_for(model):
	return MODEL_PROFILE.get(model, "v6")

func spec(name):
	return M.get("profiles", {}).get(name, null)

func _stream(file):
	if cache.has(file): return cache[file]
	var s = load("res://assets/engine/%s.wav" % file)
	if s is AudioStreamSample:
		s = s.duplicate()
		s.loop_mode = AudioStreamSample.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	cache[file] = s
	return s

func _loop(name): return _stream(name)

func _clip(name):
	var s = load("res://assets/engine/%s.wav" % name)
	return s

func _player(st):
	var p = AudioStreamPlayer.new()
	p.bus = "Car"
	p.stream = st
	p.volume_db = -80
	add_child(p)
	return p

# ---------------------------------------------------------------- your engine
func start(model):
	stop()
	pname = profile_for(model)
	prof = spec(pname)
	if prof == null: return
	for r in prof.ladder:
		var row = { "r_on": float(r.rpm_on), "r_off": float(r.rpm_off) }
		for lt in ["on", "off"]:
			for st in ["ex", "in"]:
				var p = _player(_stream("%s_%s" % [r[lt], st]))
				p.play(randf() * 0.5)
				p.stream_paused = true
				row[lt + "_" + st] = p
		rungs.append(row)
	boost = 0.0
	load_s = 0.0
	level = 0.0

func stop():
	for r in rungs:
		for k in ["on_ex", "on_in", "off_ex", "off_in"]:
			r[k].queue_free()
	rungs = []
	prof = null
	for p in [turbo_p, whine_p]:
		if p: p.stop()

func idle_rpm(): return float(prof.idle) if prof else 750.0
func red_rpm(): return float(prof.red) if prof else 6200.0

# rpm, eload 0..1 (throttle, as the engine feels it), running (starter done), speed (m/s,
# signed), inside (0 outside the car .. 1 in the driver's seat), dt
func update(rpm, eload, running, speed, inside, limiter, dt):
	if prof == null: return
	interior = lerp(interior, inside, min(1.0, dt * 6.0))
	level = lerp(level, 1.0 if running else 0.0, min(1.0, dt * (5.0 if running else 12.0)))
	load_s += (eload - load_s) * min(1.0, dt * (14.0 if eload > load_s else 9.0))
	var red = red_rpm()
	# the limiter: fuel cut, a fast stutter
	var gate = 1.0
	if limiter:
		lim_ph += dt * 17.0
		gate = 0.45 if fmod(lim_ph, 1.0) < 0.42 else 1.0
	# where on the ladder: the two rungs either side, equal-power by the log of the ratio
	var n = rungs.size()
	var lo = 0
	while lo < n - 2 and rungs[lo + 1].r_on <= rpm: lo += 1
	var r0 = rungs[lo].r_on
	var r1 = rungs[min(lo + 1, n - 1)].r_on
	var x = clamp(log(max(rpm, 1.0) / r0) / log(r1 / r0), 0.0, 1.0) if r1 > r0 else 0.0
	if rpm < r0: x = 0.0
	var on_w = sin(load_s * PI * 0.5)
	var off_w = cos(load_s * PI * 0.5)
	var ex_g = lerp(1.0, 0.42, interior)
	var in_g = lerp(0.3, 1.05, interior)
	var master = level * gate * 0.9
	for i in range(n):
		var w = 0.0
		if i == lo: w = cos(x * PI * 0.5)
		elif i == lo + 1: w = sin(x * PI * 0.5)
		var row = rungs[i]
		for lt in ["on", "off"]:
			var lw = on_w if lt == "on" else off_w
			var pitch = clamp(rpm / (row.r_on if lt == "on" else row.r_off), 0.25, 2.5)
			for st in ["ex", "in"]:
				var p = row[lt + "_" + st]
				var v = w * lw * (ex_g if st == "ex" else in_g) * master
				if v < 0.002:
					if not p.stream_paused:
						p.stream_paused = true
						p.volume_db = -80
				else:
					if p.stream_paused: p.stream_paused = false
					p.volume_db = linear2db(v)
					p.pitch_scale = pitch
	# a turbo: spools up under load past 2000 rpm, sighs out through the blow-off valve
	if prof.get("turbo", false):
		var target = load_s * clamp((rpm - 2000.0) / 2600.0, 0.0, 1.0)
		boost += (target - boost) * min(1.0, dt * (1.6 if target > boost else 5.0))
		if last_load > 0.6 and eload < 0.2 and boost > 0.4 and bov_p.stream:
			bov_p.volume_db = linear2db(0.55 * boost * level)
			bov_p.pitch_scale = rand_range(0.95, 1.1)
			bov_p.play()
			boost *= 0.3
		if turbo_p.stream:
			if not turbo_p.playing: turbo_p.play()
			turbo_p.volume_db = linear2db(max(0.0001, pow(boost, 1.6) * 0.32 * level * lerp(0.7, 1.0, interior)))
			turbo_p.pitch_scale = clamp(0.45 + 0.8 * boost * (0.6 + 0.4 * rpm / red), 0.3, 2.0)
	last_load = eload
	# the gearbox: a whine that rises with road speed, straight-cut and loud in reverse
	if whine_p.stream:
		if not whine_p.playing: whine_p.play()
		var sp = abs(speed)
		var rev = speed < -0.3
		var wv = (0.025 + 0.03 * load_s) * clamp(sp / 25.0, 0.0, 1.0) + (0.12 * clamp(sp / 5.0, 0.0, 1.0) if rev else 0.0)
		whine_p.volume_db = linear2db(max(0.0001, wv * level * lerp(0.5, 1.0, interior)))
		whine_p.pitch_scale = clamp(0.25 + sp / (9.0 if rev else 30.0), 0.2, 2.5)
	# afterfire on the overrun
	pop_cd -= dt
	if load_s < 0.12 and rpm > 2800 and pop_cd <= 0 and _poppy() and randf() < dt * (3.0 + rpm / 1500.0):
		pop(0.35 + randf() * 0.4)

func _poppy():
	return pname in SPORTY or (pname == "v8" and main.player.car and main.player.car.model == "police")

# a pop out of the tailpipe (also on a fast upshift, called by Sfx)
func pop(vol):
	if pop_cd > 0 or pop_p.empty(): return
	pop_cd = 0.07
	var p = pop_p[randi() % pop_p.size()]
	if p.stream == null: return
	p.volume_db = linear2db(vol * level * lerp(1.0, 0.55, interior))
	p.pitch_scale = rand_range(0.85, 1.15)
	p.play()

func upshift(eload, rpm):
	if eload > 0.7 and rpm > red_rpm() * 0.7 and pname in SPORTY:
		pop(0.6)

# ---------------------------------------------------------------- the cars around you
func traffic(dt):
	_vt -= dt
	if _vt > 0:
		_voices_follow()
		return
	_vt = 0.2
	if M.empty(): return
	var cam = get_viewport().get_camera()
	if cam == null: return
	var cp = cam.global_transform.origin
	var near = []
	for v in main.vehicles.VEH:
		if v.dead or v == main.player.car or v.node == null: continue
		var d = Vector2(v.pos.x - cp.x, v.pos.z - cp.z).length()
		if d > 70.0: continue
		if abs(v.speed) < 0.5 and not v.ai and v.driver != "remote": continue
		near.append([d, v])
	near.sort_custom(self, "_by_d")
	var want = []
	for i in range(min(voices.size(), near.size())): want.append(near[i][1])
	# keep voices on cars that are still wanted, give free ones to the rest
	for vo in voices:
		if vo.car != null and not vo.car in want:
			vo.car = null
			vo.p.stop()
	for c in want:
		var has = false
		for vo in voices:
			if vo.car == c: has = true
		if has: continue
		for vo in voices:
			if vo.car == null:
				var pn = profile_for(c.model)
				var sp = spec(pn)
				if sp == null: break
				var rung = sp.ladder[2]
				vo.car = c
				vo.prof = pn
				vo["r"] = float(rung.rpm_on)
				vo.p.stream = _stream("%s_ex" % rung.on)
				vo.p.play(randf())
				break
	_voices_follow()

func _voices_follow():
	for vo in voices:
		var c = vo.car
		if c == null: continue
		if c.dead or c.node == null:
			vo.car = null; vo.p.stop(); continue
		vo.p.global_transform.origin = Vector3(c.pos.x, 0.6, c.pos.z)
		var sp = spec(vo.prof)
		var sp_ms = abs(c.speed)
		# a rough rpm from road speed through an imagined automatic
		var rpm = float(sp.idle) + fmod(sp_ms * 160.0, 2200.0) + sp_ms * 40.0
		vo.p.pitch_scale = clamp(rpm / vo.r, 0.4, 2.2)
		vo.p.unit_db = lerp(-10.0, -3.0, clamp(sp_ms / 20.0, 0.0, 1.0)) + (2.0 if vo.prof in ["v8", "v8s"] else 0.0)

func _by_d(a, b): return a[0] < b[0]
