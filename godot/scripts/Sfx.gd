extends Node
# Sound (the web game's synthesized bank, rendered to files) and quick visual effects:
# tracers, muzzle flashes, blood and dust. Also the car radio and the engine.

var main
var files = {}          # name -> [paths]
var cache = {}
var p3 = []
var p2 = []
var i3 = 0
var i2 = 0
var tracers = []
var ti = 0
var bits = []
var flash_light = null
var flash_t = 0.0
var radio = null
var radio_st = -1
var engine = null
var engine_car = null
const STATIONS = ["", "wcld", "hawk", "northline", "lowend"]

func setup(m):
	main = m
	var d = Directory.new()
	if d.open("res://assets/sfx") == OK:
		d.list_dir_begin(true, true)
		var f = d.get_next()
		while f != "":
			var fn = f.replace(".import", "")
			if fn.ends_with(".ogg"):
				var base = fn.get_basename()
				var nm = base
				if base.length() > 2 and base[base.length() - 2] == "_" and base[base.length() - 1] in ["0", "1", "2"]:
					nm = base.substr(0, base.length() - 2)
				if not files.has(nm): files[nm] = []
				var path = "res://assets/sfx/" + fn
				if not path in files[nm]: files[nm].append(path)
			f = d.get_next()
	for _i in range(16):
		var a = AudioStreamPlayer3D.new()
		a.unit_size = 6; a.max_distance = 140; a.attenuation_filter_cutoff_hz = 6000
		add_child(a); p3.append(a)
	for _i in range(8):
		var b = AudioStreamPlayer.new()
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
	radio = AudioStreamPlayer.new(); add_child(radio)
	engine = AudioStreamPlayer.new(); add_child(engine)

func stream(name):
	if not files.has(name): return null
	var path = G.pick(files[name])
	if not cache.has(path): cache[path] = load(path)
	return cache[path]

func _vol(v):
	return linear2db(max(0.0001, v * float(G.S["settings"].get("vol", 0.8))))

func play(name, vol = 0.6, pitch = 1.0):
	var s = stream(name)
	if s == null: return
	var a = p2[i2]; i2 = (i2 + 1) % p2.size()
	a.stream = s; a.volume_db = _vol(vol); a.pitch_scale = pitch * G.rand(0.95, 1.05); a.play()

func play3d(name, at, vol = 0.6, pitch = 1.0):
	var s = stream(name)
	if s == null: return
	var a = p3[i3]; i3 = (i3 + 1) % p3.size()
	a.stream = s; a.translation = at; a.unit_db = _vol(vol) + 6; a.pitch_scale = pitch * G.rand(0.93, 1.07); a.play()

func step(at, run):
	var y = at.y
	var surf = "step_snow"
	if y > 0.4: surf = "step_metal" if y > 6 else "step_hard"
	elif abs(at.x - round(at.x / 10) * 10) < 0: surf = "step_hard"
	play3d(surf, at + Vector3(0, 0.05, 0), 0.32 if run else 0.24)

func shot(kind, at, vol = 1.0):
	var k = kind if kind in ["k9", "draft", "plow"] else "k9"
	play3d("gun_" + k, at, vol * (1.25 if k == "plow" else (0.85 if k == "draft" else 1.0)))

func impact(at, metal = false):
	play3d("imp_metal" if metal else ("imp_snow" if at.y < 0.22 else "imp_brick"), at, 0.5)
	_spawn_bits(at, Vector3.UP, 4, false)

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

func flash(at):
	flash_light.translation = at; flash_light.light_energy = 4.0; flash_light.visible = true; flash_t = 0.05

# ---------- car radio and engine ----------
func next_station():
	var s = int(G.S["settings"].get("radio", 1))
	s = (s + 1) % STATIONS.size()
	G.S["settings"]["radio"] = s
	_radio_refresh(true)

func _radio_refresh(announce = false):
	var want = int(G.S["settings"].get("radio", 1)) if main.player.car else 0
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
	radio.volume_db = linear2db(max(0.0001, 0.55 * float(G.S["settings"].get("music", 0.85)) * float(G.S["settings"].get("vol", 0.8))))
	# every player hears the same moment of the song: start from the shared clock
	radio.play(fposmod(G.world_seconds(), st.get_length()))
	if announce or true: main.hud.toast(G.D["STATIONS"][want].name)

func engine_on(v):
	engine_car = v
	var s = stream("roll")
	if s:
		s.loop = true
		engine.stream = s; engine.play()
	radio_st = -1
	_radio_refresh(true)

func engine_off():
	engine_car = null; engine.stop()
	radio_st = -1; radio.stop()

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
	if engine_car and not engine_car.dead:
		var sp = abs(engine_car.speed)
		engine.pitch_scale = 0.55 + sp / 22.0
		engine.volume_db = _vol(0.25 + min(0.5, sp / 40.0))
	if main.player.car == null and radio_st > 0:
		radio_st = 0; radio.stop()
