extends Node
# Cars: physics, collisions, traffic that follows lanes and signals, parked cars,
# your own car and carjacking. Ported from the web game's 45_vehicles.js.

var main
var VEH = []
var TRAFFIC = []
var PARKED = {}
var own_car = null
var _scenes = {}
var _traffic_t = 0.0
var _parked_t = 0.0
var headlight = null
var LANE = 2.1
var GX = []
var GZ = []
const SIG_CYCLE = 27.0

class Car:
	var id = 0
	var model = ""
	var sp = {}
	var color = 0
	var pos = Vector3()
	var yaw = 0.0
	var vel = Vector2()
	var speed = 0.0
	var steer = 0.0
	var driver = null      # null, "player", "ai", "police"
	var ai = null
	var parked = false
	var locked = false
	var owned = false
	var tag = null
	var hp = 100.0
	var dead = false
	var brake = false
	var stuck_t = 0.0
	var last_honk = -99.0
	var siren = false
	var cop = null
	var spot = -1
	var node = null
	var paint_mat = null
	var flip_arm = null
	var flip_k = 0.0
	var box = {}
	var cab = {}
	var yr = 0.0          # yaw rate (your car's tire model)
	var ax = 0.0          # forward acceleration last step (weight transfer)
	var ay = 0.0
	var pitch = 0.0       # the body leaning on its springs
	var roll = 0.0
	var slip = 0.0        # 0..1: how hard the tires are sliding or spinning (smoke, marks, sound)
	var spin = 0.0        # burnout
	var drift = 0.0       # 1 after a handbrake pull, while the tail is out (traction control steps aside)
	var drift_dir = 0.0   # which way the tail went out
	var fyr = 0.0         # last step's rear side force (traction control leaves grip for it)
	var burn_t = 0.0      # how long it's been on fire
	var blown = false     # exploded: a burnt-out wreck now
	var wreck_t = 0.0
	var blast = null      # the wreck thrown up by its own explosion: height, speeds, tilt
	var by_player = false # you did this (the police care)
	var warned = false
	var wheels = []       # [pivot, spin, front] per wheel (CarGen builds them as their own nodes)
	var wa_f = 0.0        # how far the front and rear wheels have rolled (radians)
	var wa_r = 0.0
	var wst = 0.0         # the front wheels' steering angle as drawn
	var prev_yaw = 0.0
	var prev_pos = Vector3()
	var hand = false      # handbrake on (your car): the rears stop turning
	var lamp_r = null     # the tail lamps and reverse lamps, lit by braking and backing up
	var lamp_r_m = null
	var lamp_rev = null
	var lamp_rev_m = null
	var lamps = -1
	var beam = null       # the pool of light in front of a moving car at night
	var tips = []

func setup(m):
	main = m
	LANE = float(G.D.get("LANE", 2.1))
	GX = G.D["XL"]; GZ = G.D["ZL"]
	headlight = SpotLight.new()
	headlight.spot_range = 55; headlight.spot_angle = 32; headlight.light_energy = 0; headlight.visible = false
	headlight.light_color = Color(1.0, 0.95, 0.85)
	main.add_child(headlight)

func on_ice(x, z, y):
	var P = G.D["POND"]
	return y < 0.3 and (Vector2(x - P.x, z - P.z).length() < P.r or x > G.D["LAKE_X"])

func _scene(model):
	if not _scenes.has(model):
		_scenes[model] = load("res://assets/cars/" + model + ".glb")
	return _scenes[model]

# ---------- the two cars built in code (original designs) ----------
const MB = preload("res://scripts/MeshBuild.gd")
var _proc = {}

func _car_node(model):
	# every car is built in code now (scripts/CarGen.gd), once per model, then copied
	if not _proc.has(model): _proc[model] = load("res://scripts/CarGen.gd").new().build(model, G.D["CAR_SPECS"][model])
	return _proc[model].duplicate()

func _cmat(col, unshaded = false, gloss = false):
	var m = SpatialMaterial.new(); m.albedo_color = col; m.roughness = 0.3 if gloss else 0.7
	if unshaded: m.flags_unshaded = true
	else: G.toon(m, true)
	return m

# a side profile (z, y points, closed) made solid between x0 and x1: the skin and both sides
func _slab(mb, k, prof, x0, x1):
	var c = Vector2()
	for p in prof: c += p
	c /= prof.size()
	var n = prof.size()
	for i in range(n):
		var a = prof[i]
		var b = prof[(i + 1) % n]
		var e = b - a
		var nrm = Vector2(e.y, -e.x).normalized()
		if nrm.dot((a + b) * 0.5 - c) < 0: nrm = -nrm
		mb.quad(k, Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x0, b.y, b.x), Vector3(0, nrm.y, nrm.x), Vector2(), Vector2(), Vector2(), Vector2())
	var poly = PoolVector2Array(prof)
	var tris = Geometry.triangulate_polygon(poly)
	for side in [[x0, -1.0], [x1, 1.0]]:
		for t in range(0, tris.size(), 3):
			var A = prof[tris[t]]
			var B = prof[tris[t + 1]]
			var Cc = prof[tris[t + 2]]
			mb.tri(k, Vector3(side[0], A.y, A.x), Vector3(side[0], B.y, B.x), Vector3(side[0], Cc.y, Cc.x), Vector3(side[1], 0, 0))

func _wheel(mb, x, z, r, w):
	var xf = Transform(Basis(Vector3(0, 0, 1), PI / 2), Vector3(x, r, z))
	mb.lathe("tire", xf, [[r * 0.62, -w / 2], [r, -w / 2], [r, w / 2], [r * 0.62, w / 2]], 14)
	var side = 1.0 if x > 0 else -1.0
	var hub = Transform(Basis(Vector3(0, 0, 1), PI / 2), Vector3(x + side * (w / 2 - 0.02), r, z))
	mb.lathe("rim", hub, [[0.0, -0.025], [r * 0.64, -0.025], [r * 0.64, 0.025], [0.0, 0.025]], 10)

func _build_car(model):
	var mb = MB.new()
	var root = Spatial.new()
	mb.mat("paint", _cmat(Color(1, 1, 1), false, true))
	mb.mat("glass", _cmat(Color(0.08, 0.1, 0.13), false, true))
	mb.mat("trim", _cmat(Color(0.06, 0.06, 0.07)))
	mb.mat("chrome", _cmat(Color(0.75, 0.77, 0.8), false, true))
	mb.mat("tire", _cmat(Color(0.05, 0.05, 0.055)))
	mb.mat("rim", _cmat(Color(0.18, 0.19, 0.21), false, true))
	mb.mat("lightw", _cmat(Color(1, 0.97, 0.88), true))
	mb.mat("lightr", _cmat(Color(0.95, 0.08, 0.06), true))
	if model == "bruiser":
		# long and low: a flat deck, a long hood with a power bulge, a short greenhouse
		var body = [Vector2(-2.5, 0.3), Vector2(2.5, 0.3), Vector2(2.53, 0.62), Vector2(2.38, 0.84), Vector2(1.15, 0.92), Vector2(-1.3, 0.9), Vector2(-2.45, 0.88), Vector2(-2.53, 0.64)]
		_slab(mb, "paint", body, -0.96, 0.96)
		var cab = [Vector2(-1.3, 0.89), Vector2(1.15, 0.91), Vector2(0.36, 1.4), Vector2(-0.88, 1.38)]
		_slab(mb, "glass", cab, -0.8, 0.8)
		mb.box("paint", Transform(Basis(), Vector3(0, 1.405, -0.26)), Vector3(1.52, 0.05, 1.18), 0.5, false)
		for px in [-0.79, 0.79]:
			mb.box("paint", Transform(Basis(Vector3(1, 0, 0), -0.55), Vector3(px, 1.15, 0.77)), Vector3(0.05, 0.58, 0.06), 0.5, false)
			mb.box("paint", Transform(Basis(Vector3(1, 0, 0), 0.75), Vector3(px, 1.13, -1.1)), Vector3(0.05, 0.62, 0.08), 0.5, false)
			mb.box("paint", Transform(Basis(), Vector3(px, 1.15, -0.25)), Vector3(0.05, 0.5, 0.06), 0.5, false)
		mb.box("paint", Transform(Basis(), Vector3(0, 0.94, 1.75)), Vector3(0.7, 0.06, 1.1), 0.5, false)
		# front: a wide dark grille between slim headlights; rear: one light bar across the tail
		mb.box("trim", Transform(Basis(), Vector3(0, 0.55, 2.52)), Vector3(1.4, 0.24, 0.05), 0.5, false)
		for hx in [-0.72, 0.72]:
			mb.box("lightw", Transform(Basis(), Vector3(hx, 0.72, 2.47)), Vector3(0.36, 0.07, 0.05), 0.5, false)
		mb.box("lightr", Transform(Basis(), Vector3(0, 0.76, -2.49)), Vector3(1.7, 0.08, 0.04), 0.5, false)
		mb.box("trim", Transform(Basis(), Vector3(0, 0.4, -2.52)), Vector3(1.7, 0.16, 0.04), 0.5, false)
		mb.box("trim", Transform(Basis(), Vector3(0, 0.92, -2.35)), Vector3(1.5, 0.04, 0.2), 0.5, false)
		for ex in [-0.45, 0.45]:
			mb.box("chrome", Transform(Basis(), Vector3(ex, 0.32, -2.55)), Vector3(0.12, 0.07, 0.08), 0.5, false)
		for sx in [-0.97, 0.97]:
			mb.box("trim", Transform(Basis(), Vector3(sx, 0.34, 0)), Vector3(0.03, 0.06, 3.4), 0.5, false)
			mb.box("trim", Transform(Basis(), Vector3(sx * 1.03, 1.08, 0.72)), Vector3(0.12, 0.08, 0.16), 0.5, false)
			mb.box("trim", Transform(Basis(), Vector3(sx, 0.62, 0.05)), Vector3(0.01, 0.5, 0.012), 0.5, false)
		for w in [[-0.84, 1.55], [0.84, 1.55], [-0.84, -1.55], [0.84, -1.55]]:
			_wheel(mb, w[0], w[1], 0.37, 0.27)
	else:
		# tall and square: three rows of windows, roof rails, a big grille
		var body2 = [Vector2(-2.55, 0.38), Vector2(2.55, 0.38), Vector2(2.58, 0.8), Vector2(2.42, 1.04), Vector2(1.5, 1.08), Vector2(-2.48, 1.07), Vector2(-2.58, 0.82)]
		_slab(mb, "paint", body2, -1.0, 1.0)
		var cab2 = [Vector2(-2.47, 1.06), Vector2(1.5, 1.07), Vector2(0.92, 1.76), Vector2(-2.32, 1.74)]
		_slab(mb, "glass", cab2, -0.88, 0.88)
		mb.box("paint", Transform(Basis(), Vector3(0, 1.785, -0.7)), Vector3(1.78, 0.06, 3.25), 0.5, false)
		for px in [-0.87, 0.87]:
			mb.box("paint", Transform(Basis(Vector3(1, 0, 0), -0.7), Vector3(px, 1.42, 1.22)), Vector3(0.05, 0.85, 0.07), 0.5, false)
			for pz in [0.15, -1.1, -2.32]:
				mb.box("paint", Transform(Basis(), Vector3(px, 1.42, pz)), Vector3(0.05, 0.7, 0.1), 0.5, false)
			mb.box("trim", Transform(Basis(), Vector3(px * 0.8, 1.86, -0.7)), Vector3(0.05, 0.05, 2.9), 0.5, false)
		# front: a tall grille with bars, headlights; rear: the light bar and a dark tailgate band
		mb.box("trim", Transform(Basis(), Vector3(0, 0.7, 2.57)), Vector3(1.5, 0.36, 0.05), 0.5, false)
		for gy in [0.6, 0.7, 0.8]:
			mb.box("chrome", Transform(Basis(), Vector3(0, gy, 2.6)), Vector3(1.4, 0.02, 0.02), 0.5, false)
		for hx2 in [-0.78, 0.78]:
			mb.box("lightw", Transform(Basis(), Vector3(hx2, 0.92, 2.5)), Vector3(0.34, 0.08, 0.05), 0.5, false)
		mb.box("lightr", Transform(Basis(), Vector3(0, 1.0, -2.55)), Vector3(1.8, 0.09, 0.04), 0.5, false)
		mb.box("trim", Transform(Basis(), Vector3(0, 0.5, -2.58)), Vector3(1.8, 0.22, 0.04), 0.5, false)
		for sx2 in [-1.01, 1.01]:
			mb.box("trim", Transform(Basis(), Vector3(sx2, 0.42, 0)), Vector3(0.03, 0.1, 3.6), 0.5, false)
			mb.box("trim", Transform(Basis(), Vector3(sx2 * 1.03, 1.2, 1.1)), Vector3(0.12, 0.1, 0.18), 0.5, false)
		for w2 in [[-0.88, 1.6], [0.88, 1.6], [-0.88, -1.62], [0.88, -1.62]]:
			_wheel(mb, w2[0], w2[1], 0.41, 0.3)
	mb.commit(root)
	return root

func spawn(model, x, z, yaw, o = {}):
	if VEH.size() >= 56 and not o.get("owned", false):
		return null
	# parked cars stay a budget so traffic always has room (and old GPUs have fewer cars to draw)
	if o.get("parked", false) and PARKED.size() >= 24:
		return null
	var v = Car.new()
	v.id = randi(); v.model = model; v.sp = G.D["CAR_SPECS"][model]
	v.color = o.get("color", G.pick(G.D["CAR_PAINTS"]))
	v.pos = Vector3(x, 0, z); v.yaw = yaw
	v.parked = o.get("parked", false); v.locked = o.get("locked", false); v.owned = o.get("owned", false); v.tag = o.get("tag", null)
	v.box = { "x0": 0, "x1": 0, "y0": 0, "y1": 2.05 if v.sp.van else 1.05, "z0": 0, "z1": 0, "on": true, "q": 0, "tag": "car" }
	v.cab = { "x0": 0, "x1": 0, "y0": 1.0, "y1": v.sp.get("roofY", 1.4), "z0": 0, "z1": 0, "on": not v.sp.van, "q": 0, "tag": "cabin" }
	W.DYN.append(v.box); W.DYN.append(v.cab)
	var n = _car_node(model)
	main.add_child(n)
	v.node = n
	_paint(v)
	_rig(v, model)
	VEH.append(v)
	place(v)
	v.prev_yaw = v.yaw; v.prev_pos = v.pos
	return v

# the moving parts of a car: wheels, lamps, the headlight pool, the exhaust tips
var BRAKE_MAT = null
var REV_MAT = null
var BEAM_MAT = null
func _rig(v, model):
	var n = v.node
	var wn = n.get_node_or_null("Wheels")
	if wn:
		for nm in ["WFL", "WFR", "WRL", "WRR"]:
			var piv = wn.get_node_or_null(nm)
			if piv and piv.get_node_or_null("spin"): v.wheels.append([piv, piv.get_node("spin"), nm[1] == "F"])
	v.lamp_r = n.get_node_or_null("lightr")
	if v.lamp_r: v.lamp_r_m = v.lamp_r.material_override
	v.lamp_rev = n.get_node_or_null("rev")
	if v.lamp_rev: v.lamp_rev_m = v.lamp_rev.material_override
	if _proc.has(model) and _proc[model].has_meta("tips"): v.tips = _proc[model].get_meta("tips")
	if BRAKE_MAT == null:
		BRAKE_MAT = SpatialMaterial.new(); BRAKE_MAT.flags_unshaded = true; BRAKE_MAT.albedo_color = Color(1.0, 0.16, 0.1)
		REV_MAT = SpatialMaterial.new(); REV_MAT.flags_unshaded = true; REV_MAT.albedo_color = Color(1.0, 0.98, 0.92)
		BEAM_MAT = SpatialMaterial.new(); BEAM_MAT.flags_unshaded = true; BEAM_MAT.flags_transparent = true
		BEAM_MAT.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD; BEAM_MAT.albedo_texture = main.fx._soft_tex()
		BEAM_MAT.albedo_color = Color(1.0, 0.9, 0.72, 0.0)
	var q = QuadMesh.new(); q.size = Vector2(3.6, 8.0)
	var b = MeshInstance.new(); b.name = "beam"; b.mesh = q; b.material_override = BEAM_MAT
	b.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	b.transform = Transform(Basis(Vector3(1, 0, 0), -PI / 2), Vector3(0, 0.05, float(v.sp.len) / 2.0 + 4.2))
	b.visible = false
	n.add_child(b)
	v.beam = b

# wheels roll with the road, the fronts steer, the rears spin up in a burnout and stop on the
# handbrake; brake and reverse lamps; at night a pool of light ahead of every moving car
func _animate(dt):
	if dt <= 0: return
	var cam = G.cam_pos
	var night = main.DN.lamps if main else 0.0
	if BEAM_MAT: BEAM_MAT.albedo_color.a = 0.17 * night
	for v in VEH:
		if v.dead or v.node == null: continue
		var moved = v.pos - v.prev_pos
		var yr = G.ang_diff(v.prev_yaw, v.yaw) / dt
		v.prev_pos = v.pos; v.prev_yaw = v.yaw
		# (your own car has a real headlight; the pool is for everyone else's)
		if v.beam: v.beam.visible = night > 0.05 and not v.blown and not v.parked and v.driver != "player" and (v.driver != null or abs(v.speed) > 0.5)
		if v.blown or v.wheels.empty(): continue
		if v.pos.distance_squared_to(cam) > 110.0 * 110.0: continue
		var f = fwd(v)
		var spd = v.speed if v.driver != "remote" else moved.dot(f) / dt
		var r = max(0.2, float(v.sp.get("r", 0.36)))
		var wf = spd / r
		var wrr = wf
		if v.driver == "player":
			if v.spin > 0: wrr = wf + v.spin * 45.0 * (1.0 if spd >= -0.5 else -1.0)
			elif v.slip > 0.4 and v.drift <= 0: wrr = wf * (1.0 + v.slip)
			if v.hand and abs(spd) > 1.0: wrr = 0.0
		# no more than about a fifth of a turn a frame, or the spokes strobe backwards
		var cap = 1.2
		v.wa_f = fmod(v.wa_f + clamp(wf * dt, -cap, cap), TAU)
		v.wa_r = fmod(v.wa_r + clamp(wrr * dt, -cap, cap), TAU)
		var want = v.steer
		if v.driver == "remote" or v.driver == null:
			# someone else's car online (or one rolling free): steer from how fast it turns
			var wb = float(v.sp.get("wbLen", 2.8))
			want = atan(yr * wb / max(2.5, abs(spd))) * (1.0 if spd >= 0 else -1.0)
		want = clamp(want, -0.6, 0.6)
		v.wst += (want - v.wst) * min(1.0, dt * 9.0)
		for w in v.wheels:
			w[0].rotation = Vector3(0, v.wst if w[2] else 0.0, 0)
			w[1].rotation = Vector3(v.wa_f if w[2] else v.wa_r, 0, 0)
		# lamps: 1 braking, 2 reversing
		var st = (1 if v.brake else 0) + (2 if v.driver == "player" and spd < -0.3 else 0)
		if st != v.lamps:
			v.lamps = st
			if v.lamp_r: v.lamp_r.material_override = BRAKE_MAT if st & 1 else v.lamp_r_m
			if v.lamp_rev: v.lamp_rev.material_override = REV_MAT if st & 2 else v.lamp_rev_m

# a flame out of each tailpipe when the engine pops (scripts/EngineAudio.gd)
func backfire(vol):
	var v = main.player.car
	if v == null or v.node == null or v.tips.empty() or not v.node.visible: return
	main.fx.backfire(v.node.global_transform, v.tips, vol)

func _paint(v, n = null):
	if n == null: n = v.node
	for c in n.get_children():
		if c is MeshInstance:
			for i in range(c.mesh.get_surface_count()):
				var m = c.mesh.surface_get_material(i)
				if m is SpatialMaterial:
					if not m.has_meta("toon"):
						m.vertex_color_use_as_albedo = true; m.vertex_color_is_srgb = true; m.metallic = 0.0; m.metallic_specular = 0.35
					G.toon(m, true)
			if c.name.begins_with("paint"):
				var pm = SpatialMaterial.new()
				pm.vertex_color_use_as_albedo = true; pm.vertex_color_is_srgb = true
				pm.albedo_color = G.hex_color(v.color); pm.roughness = 0.5; pm.metallic = 0.0; pm.metallic_specular = 0.28
				G.toon(pm, true)
				c.material_override = pm
				v.paint_mat = pm
			c.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		_paint(v, c)

func remove(v):
	if v.dead: return
	v.dead = true
	main.fx.car_fx_clear(v)
	W.DYN.erase(v.box); W.DYN.erase(v.cab)
	VEH.erase(v); TRAFFIC.erase(v)
	if v.node: v.node.queue_free()
	if v == own_car: own_car = null

func place(v):
	v.node.translation = v.pos
	v.node.rotation = Vector3(v.pitch, v.yaw, v.roll)
	var c = abs(cos(v.yaw))
	var s = abs(sin(v.yaw))
	var W2 = v.sp.wid / 2.0
	var L2 = v.sp.len / 2.0
	var hx = c * W2 + s * L2
	var hz = s * W2 + c * L2
	v.box.x0 = v.pos.x - hx; v.box.x1 = v.pos.x + hx; v.box.z0 = v.pos.z - hz; v.box.z1 = v.pos.z + hz
	v.cab.x0 = v.pos.x - hx * 0.6; v.cab.x1 = v.pos.x + hx * 0.6; v.cab.z0 = v.pos.z - hz * 0.6; v.cab.z1 = v.pos.z + hz * 0.6
	# the real, turned outline (W uses it for people, ragdolls, bullets, standing on cars)
	var cy = cos(v.yaw)
	var sy = sin(v.yaw)
	for bx in [[v.box, W2, L2], [v.cab, W2 * 0.92, L2 * 0.5]]:
		var b = bx[0]
		b["obb"] = true; b["cx"] = v.pos.x; b["cz"] = v.pos.z; b["c"] = cy; b["s"] = sy; b["hw"] = bx[1]; b["hl"] = bx[2]

func fwd(v): return Vector3(sin(v.yaw), 0, cos(v.yaw))

# ---------- the driver's arm out of the window, giving the finger (you, or someone online) ----------
func flip_arm(v, on, skin, sleeve, dt):
	if v == null or v.dead or v.node == null: return
	if v.flip_arm == null:
		if not on: return
		v.flip_arm = _make_flip_arm(skin, sleeve)
		v.node.add_child(v.flip_arm)
	v.flip_k = move_toward(v.flip_k, 1.0 if on else 0.0, dt * 5.0)
	var a = v.flip_arm
	a.visible = v.flip_k > 0.01
	if not a.visible: return
	var k = v.flip_k * v.flip_k * (3.0 - 2.0 * v.flip_k)
	var Gm = G.D["CAR_GEOM"].get(v.model, {})
	var W = float(v.sp.wid)
	var yWB = float(Gm.get("yWB", 1.0))
	var eyeY = max(yWB + 0.32, float(Gm.get("roofY", 1.5)) - 0.26)
	var eyeZ = float(Gm.get("zWB", 0.8)) - 0.95
	var xw = W / 2.0
	var wig = sin(G.REAL_T * 9.0) * 0.012
	# out of the window and up over the roof line, so it shows from behind the car too
	var S = Vector3(xw - 0.2, eyeY - 0.25, eyeZ + 0.05)
	var E = Vector3(xw - 0.1, eyeY - 0.45, eyeZ + 0.15).linear_interpolate(Vector3(xw + 0.17, eyeY - 0.06, eyeZ + 0.02), k)
	var H = Vector3(xw - 0.05, eyeY - 0.5, eyeZ + 0.35).linear_interpolate(Vector3(xw + 0.24, eyeY + 0.4 + wig, eyeZ + 0.04), k)
	_seg(a.get_node("upper"), S, E, 0.065)
	_seg(a.get_node("fore"), E, H, 0.056)
	a.get_node("fist").translation = H
	var dir = (H - E).normalized()
	_seg(a.get_node("finger"), H + dir * 0.03, H + dir * 0.17, 0.02)

func _make_flip_arm(skin, sleeve):
	var a = Spatial.new()
	a.name = "FlipArm"
	for p in [["upper", sleeve], ["fore", sleeve], ["finger", skin]]:
		var cm = CylinderMesh.new(); cm.top_radius = 1; cm.bottom_radius = 1; cm.height = 1; cm.radial_segments = 8; cm.rings = 1
		var mi = MeshInstance.new(); mi.name = p[0]; mi.mesh = cm; mi.material_override = G.mat(p[1])
		a.add_child(mi)
	var sm = SphereMesh.new(); sm.radius = 1; sm.height = 2; sm.radial_segments = 10; sm.rings = 6
	var f = MeshInstance.new(); f.name = "fist"; f.mesh = sm; f.material_override = G.mat(skin); f.scale = Vector3(0.062, 0.07, 0.055)
	a.add_child(f)
	return a

# a unit cylinder stretched from a to b
func _seg(mi, a, b, r):
	var d = b - a
	var L = d.length()
	if L < 0.001: return
	var y = d / L
	var x = y.cross(Vector3(0, 0, 1))
	if x.length() < 0.1: x = y.cross(Vector3(1, 0, 0))
	x = x.normalized()
	var z = x.cross(y)
	mi.transform = Transform(Basis(x * r, y * L, z * r), (a + b) / 2.0)
func side(v): return Vector3(cos(v.yaw), 0, -sin(v.yaw))

func physics(v, dt, inp):
	var sp = v.sp
	var f = fwd(v)
	var l = side(v)
	var vF = v.vel.x * f.x + v.vel.y * f.z
	var vL = v.vel.x * l.x + v.vel.y * l.z
	var ice = on_ice(v.pos.x, v.pos.z, 0)
	var dead = v.hp <= 0
	var thr = 0.0 if dead else inp.thr
	v.brake = false
	if thr > 0: vF += thr * (13.0 if vF < -0.5 else float(sp.acc)) * dt
	elif thr < 0:
		if vF > 0.6:
			vF += thr * 14 * dt
			v.brake = true
		else: vF += thr * 4.5 * dt
	var roll = 0.35 + 0.011 * vF * vF + (1.1 if thr == 0 else 0.0)
	vF -= sign(vF) * min(abs(vF), roll * dt)
	if inp.hand:
		vF -= sign(vF) * min(abs(vF), 5 * dt)
		v.brake = true
	vF = clamp(vF, -8, float(sp.top) * (0.0 if dead else 1.0))
	var grip = (0.9 if inp.hand else (9.0 if v.ai else 4.2)) * (0.22 if ice else 1.0)
	vL -= vL * min(1, grip * dt)
	var max_steer = lerp(0.6, 0.2, clamp(abs(vF) / 30.0, 0, 1))
	v.steer += (inp.steer * max_steer - v.steer) * min(1, dt * 7)
	v.yaw += vF / float(sp.wbLen) * tan(v.steer) * (1.3 if inp.hand else 1.0) * dt
	f = fwd(v); l = side(v)
	v.vel = Vector2(f.x * vF + l.x * vL, f.z * vF + l.z * vL)
	v.speed = vF
	v.pos.x = clamp(v.pos.x + v.vel.x * dt, -W.BOUND, W.BOUND)
	v.pos.z = clamp(v.pos.z + v.vel.y * dt, -W.BOUND, W.BOUND)

# ---------- your car: tires with slip angles, weight on the springs, and the friction circle ----------
# Rear-wheel drive. Each axle grips up to a limit set by the weight on it (braking puts weight
# on the nose, throttle on the tail) and by the road (slush, ice), and the push and the side
# grip share that limit. So: floor it mid-corner and the tail steps out, the handbrake locks the
# rears for a drift (counter-steer and feed the throttle to hold it), and gas plus brake at a
# standstill is a burnout: steer while doing it to spin donuts. Below jogging pace it blends into
# the simple model, so parking and reversing stay easy.
func physics_player(v, dt, inp):
	var sp = v.sp
	var m = 1450.0 * float(sp.len) / 4.6
	var L = float(sp.wbLen)
	var a = L * 0.47                 # nose-heavy, like a front-engined car
	var b = L - a
	var h = 0.55
	var wd = float(sp.wid)
	var Iz = m * a * b * 1.1                                    # yaw inertia of a real sedan (about m·a·b)
	var g = 9.8
	var f = fwd(v)
	var l = side(v)
	var vF = v.vel.x * f.x + v.vel.y * f.z
	var vL = v.vel.x * l.x + v.vel.y * l.z
	var yr0 = v.yr
	var dead = v.hp <= 0
	var gas = 0.0 if dead else float(inp.get("gas", max(0.0, inp.thr)))
	var brk = float(inp.get("brk", max(0.0, -inp.thr)))
	var hand = inp.hand and abs(vF) > 0.5
	var ice = on_ice(v.pos.x, v.pos.z, 0)
	var mu = (0.24 if ice else 0.95) * float(sp.get("grip", 1.0))
	var top = float(sp.top)
	var beta0 = atan2(vL, max(abs(vF), 1.0))
	# a drift: pull the handbrake at speed, then keep the tail out on the throttle
	if hand and abs(vF) > 7.0:
		v.drift = 1.0
		if abs(beta0) > 0.05: v.drift_dir = sign(beta0)
	elif v.drift > 0 and abs(beta0) > 0.08 and sign(beta0) != v.drift_dir: v.drift = 0.0     # it snapped the other way: grip back
	elif abs(beta0) < 0.16 or abs(vF) < 4.0 or (gas < 0.25 and abs(beta0) < 0.3): v.drift = max(0.0, v.drift - dt * 1.5)
	# the engine: full push off the line, then its power runs out as the speed climbs
	var v0 = float(sp.get("v0", 11.0))
	var pw = 0.75
	var awd = sp.get("awd", false)
	var Fdrive = float(sp.acc) * m * min(1.0, pow(v0 / max(abs(vF), 0.1), pw))
	var roll_k = 0.16
	var cd = max(0.0, float(sp.acc) * m * pow(v0 / top, pw) - m * roll_k) / (top * top)
	# weight on each axle, from last step's acceleration
	var Nf = m * g * b / L - m * v.ax * h / L
	var Nr = m * g * a / L + m * v.ax * h / L
	var Fmax_f = mu * max(Nf, 0.0)
	var Fmax_r = mu * max(Nr, 0.0) * 1.1                      # wider rear tires: it understeers before it oversteers
	var Fx_f = 0.0
	var Fx_r = 0.0
	var wheelspin = 0.0
	var abs_on = false
	var burnout = gas > 0.4 and brk > 0.4 and abs(vF) < 4.0 and not dead
	if burnout:
		v.spin = min(1.0, v.spin + dt * 3.0)
	else:
		v.spin = max(0.0, v.spin - dt * 2.5)
		if gas > 0:
			if vF < -0.6: Fx_f += min(m * g * 0.6 * gas, Fmax_f * 0.9)     # rolling back: gas brakes first
			else:
				var want_x = Fdrive * gas
				if awd and v.drift <= 0.05:
					# all-wheel drive: the fronts take 40 percent, as much as they can hold
					var fx = min(want_x * 0.4, Fmax_f * 0.9)
					Fx_f += fx
					want_x -= fx
				# traction control: never more push than the rear tires have left over from cornering,
				# except launching straight (muscle cars chirp their tires) or in a drift
				var launch = abs(vF) < 7.0 and abs(inp.steer) < 0.3 and gas > 0.9 and float(sp.acc) >= 7.5 and not awd
				var cap = Fmax_r
				if v.drift <= 0.05 and not launch:
					cap = sqrt(max(0.0, Fmax_r * Fmax_r - v.fyr * v.fyr)) * 0.9
					want_x = min(want_x, max(cap, Fmax_r * 0.25))
				if want_x > Fmax_r:
					wheelspin = clamp((want_x - Fmax_r) / max(Fmax_r, 1.0) * 2.0, 0.0, 1.0)
					want_x = Fmax_r * 0.92
				Fx_r = want_x
		if brk > 0:
			if vF > 0.8:
				# ABS: hard braking stops you without locking the wheels, so you can still steer
				var bf = m * g * 1.2 * brk
				Fx_f -= min(bf * 0.66, Fmax_f * 0.95)
				Fx_r -= min(bf * 0.34, Fmax_r * 0.88)
				abs_on = bf * 0.66 > Fmax_f * 0.95
			else:
				Fx_r -= min(float(sp.acc) * m * 0.55 * brk, Fmax_r * 0.9)   # reverse
	# the front wheels follow the slide when you let them (caster), so a drift is easy to catch
	var spd = max(abs(vF), 3.0)
	var max_steer = min(0.62, L * mu * g / (spd * spd) * 1.15 + 0.15)
	if v.drift > 0.05 or v.spin > 0: max_steer = max(max_steer, 0.45)       # full opposite lock to catch a slide
	var slide = atan2(vL, spd) if vF > 2.0 else 0.0
	var want = inp.steer * max_steer
	if abs(slide) > 0.12:
		want = clamp(want + slide * 0.85 * (1.0 - abs(inp.steer) * 0.5), -0.7, 0.7)
	v.steer += (want - v.steer) * min(1, dt * 8)
	# slip angles and side forces: grip builds to a peak near 7 degrees, then a sliding tire lets go a little
	var dirs = 1.0 if vF >= 0 else -1.0
	var af = atan2(vL + a * yr0, spd) - v.steer * dirs
	var ar = atan2(vL - b * yr0, spd)
	var lat_f = sqrt(max(0.0, Fmax_f * Fmax_f - Fx_f * Fx_f))
	var lat_r = sqrt(max(0.0, Fmax_r * Fmax_r - Fx_r * Fx_r))
	var Fyf = -lat_f * tanh(8.0 * af) * (1.0 - 0.15 * clamp((abs(af) - 0.14) / 0.4, 0.0, 1.0))
	var Fyr = -lat_r * tanh(9.0 * ar) * (1.0 - (0.08 + 0.12 * v.drift) * clamp((abs(ar) - 0.14) / 0.4, 0.0, 1.0))
	if v.drift > 0.05:
		Fyr *= 1.0 - 0.22 * v.drift * clamp((abs(ar) - 0.1) / 0.3, 0.0, 1.0)     # a sliding tire grips less
	var Fxr_lock = 0.0
	if hand:
		# the rear wheels lock: they just slide, against the way they're moving
		var vr = Vector2(vF, vL - b * yr0)
		var fr = -vr.normalized() * mu * max(Nr, 0.0) * 0.6
		Fxr_lock = fr.x; Fyr = fr.y; Fx_r = 0.0
	v.fyr = Fyr
	var Fres = -cd * vF * abs(vF) - sign(vF) * m * (roll_k + (0.9 if gas == 0 and brk == 0 else 0.0)) * min(1.0, abs(vF))
	var cs = cos(v.steer)
	var sn = sin(v.steer)
	var Fx = Fx_r + Fxr_lock + Fx_f * cs - Fyf * sn + Fres
	var Fy = Fyr + Fyf * cs + Fx_f * sn
	var torque = a * (Fyf * cs + Fx_f * sn) - b * Fyr
	var yr_dyn = yr0 + torque / Iz * dt
	yr_dyn -= yr_dyn * 0.4 * dt                               # a little stability, like a real chassis
	# a light hand on the wheel: past a big slide (and off the handbrake) the spin is reined in
	var lim = 0.75 if v.drift > 0.05 else 0.4
	if abs(beta0) > lim and yr_dyn * vL < 0:
		yr_dyn *= max(0.0, 1.0 - (abs(beta0) - lim) * (3.0 if hand else 7.0) * dt)
	var vF_new = vF + (Fx / m + vL * yr0) * dt
	var vL_dyn = vL + (Fy / m - vF * yr0) * dt
	# slow or reversing: the simple model (rolling wheels, no sliding)
	var k = 1.0 - clamp((abs(vF) - 2.0) / 3.0, 0.0, 1.0)
	if vF < -0.5: k = 1.0
	var yr_kin = vF_new / L * tan(v.steer)
	var vL_kin = vL - vL * min(1.0, 6.0 * dt)
	v.yr = lerp(yr_dyn, yr_kin, k)
	vL = lerp(vL_dyn, vL_kin, k)
	vF = vF_new
	if v.spin > 0:
		# burnout: the fronts hold the car, the rears spin; steer and the tail swings round the nose
		var turn = inp.steer * 2.4 if burnout else 0.0
		var yb = yr0 + (turn - yr0) * min(1.0, dt * (2.5 if burnout else 4.0))
		v.yr = lerp(v.yr, yb, v.spin)
		if burnout:
			vF *= max(0.0, 1.0 - 4.0 * dt)
			vL = -a * v.yr * 0.9
	vF = clamp(vF, -9.0, top * (0.0 if dead else 1.05))
	v.ax = lerp(v.ax, Fx / m, min(1.0, dt * 10.0))           # what the springs feel (not the frame turning)
	v.ay = lerp(v.ay, Fy / m, min(1.0, dt * 10.0))
	v.yaw += v.yr * dt
	f = fwd(v); l = side(v)
	v.vel = Vector2(f.x * vF + l.x * vL, f.z * vF + l.z * vL)
	v.speed = vF
	v.brake = brk > 0 and vF > 0.6 or hand
	v.pos.x = clamp(v.pos.x + v.vel.x * dt, -W.BOUND, W.BOUND)
	v.pos.z = clamp(v.pos.z + v.vel.y * dt, -W.BOUND, W.BOUND)
	# how much the tires are sliding: smoke, marks and the screech
	var side_slide = clamp((abs(ar) - 0.12) / 0.35, 0.0, 1.0) * clamp(abs(vF) / 6.0, 0.0, 1.0)
	var lock = (0.6 if hand and abs(vF) > 3.0 else 0.0) + (0.3 if abs_on and vF > 12.0 else 0.0)
	v.slip = clamp(max(max(side_slide, wheelspin * 0.9), max(v.spin, lock)), 0.0, 1.0)
	# the body on its springs: nose dips under braking, squats under power, leans out of turns
	var tp = clamp(v.ax * 0.007, -0.07, 0.07)
	var tr = clamp(-v.ay * 0.009, -0.075, 0.075)
	v.pitch += (tp - v.pitch) * min(1.0, dt * 7.0)
	v.roll += (tr - v.roll) * min(1.0, dt * 7.0)

# ---------- shot to pieces: smoke, then fire, then it goes up ----------
# Under 45 hp the engine smokes, grey then black; at 12 it catches fire, and a few seconds
# later (sooner if you keep shooting) the tank goes: a fireball, a flash and a boom, the
# wreck thrown up and dropped burnt out, people and cars nearby hurt by the blast (and the
# next car along can catch too). The wreck burns a while, then smokes, then gets towed.
func _damage(v, dt):
	var f = fwd(v)
	var bay = v.pos + f * (float(v.sp.len) * 0.5 - 0.7) + Vector3(0, float(v.sp.get("roofY", 1.4)) * 0.62, 0)
	if v.blown:
		v.wreck_t += dt
		_wreck_motion(v, dt)
		var mid = v.pos + Vector3(0, 0.9 + (v.blast.y if v.blast else 0.0), 0)
		main.fx.car_fx(v, 1.0 if v.wreck_t < 60 else 0.6, v.wreck_t < 16, mid)
		return
	if v.hp >= 45:
		if v.burn_t > 0 or main.fx.carfx.has(v.id): main.fx.car_fx(v, 0.0, false, bay)
		return
	var fire = v.hp <= 12
	main.fx.car_fx(v, clamp((45.0 - v.hp) / 33.0, 0.15, 1.0), fire, bay)
	if fire:
		v.burn_t += dt
		if v.driver == "player" and not v.warned:
			v.warned = true
			main.hud.banner("Your car's on fire", "Get out!")
		if v.burn_t > 4.5 or v.hp < -35:
			explode(v)

func explode(v):
	if v.blown: return
	v.blown = true; v.hp = -100.0; v.siren = false
	var at = v.pos + Vector3(0, 0.8, 0)
	main.fx.explosion(at)
	main.sfx.play3d("car_explode", at, 1.0, rand_range(0.92, 1.05), "Guns")
	var P = main.player
	var d = P.pos.distance_to(at)
	P.shake = max(P.shake, clamp(1.6 - d / 22.0, 0.0, 1.4))
	G.rumble(1.0, 1.0, 0.5 if d < 15 else 0.2)
	# whoever is inside
	if P.car == v:
		leave(v); P.car = null
		P.pos = v.pos + side(v) * (float(v.sp.wid) / 2.0 + 0.6)
		P.hurt(999, null)
	elif d < 9.0 and not P.dead:
		P.hurt((1.0 - d / 9.0) * 110.0, null)
		var push = (P.pos - at).normalized() * (1.0 - d / 9.0) * 9.0 + Vector3(0, 4.0, 0)
		P.knock(push, 0.0, 2.5)
	# people around
	for list in [main.crews.ENEMIES, main.peds.PEDS, main.police.COPS]:
		for e in list:
			if e.is_down(): continue
			var de = e.pos.distance_to(at)
			if de < 9.0:
				e.take_hit((1.0 - de / 9.0) * 140.0, false, (e.pos - at).normalized(), v.by_player, false)
	# cars around: hurt, shoved, and the close ones catch
	for o in VEH:
		if o == v or o.dead or o.blown: continue
		var dc = Vector2(o.pos.x - v.pos.x, o.pos.z - v.pos.z)
		var l = dc.length()
		if l < 8.0:
			o.hp -= (1.0 - l / 8.0) * 75.0
			o.vel += dc.normalized() * (1.0 - l / 8.0) * 6.0
			o.by_player = o.by_player or v.by_player
	if v.by_player:
		main.police.add_wanted(18, v.pos)
		G.S["heat"] = min(100, G.S["heat"] + 6)
	# the wreck: thrown up, spinning a little, burnt black
	v.blast = { "y": 0.0, "vy": rand_range(5.0, 7.5), "ax": 0.0, "az": 0.0, "wx": rand_range(-2.2, 2.2), "wz": rand_range(-2.8, 2.8) }
	v.vel = Vector2(rand_range(-2, 2), rand_range(-2, 2))
	v.speed = 0.0
	_char(v.node)

var _burnt = null
func _char(n):
	if _burnt == null:
		_burnt = SpatialMaterial.new(); _burnt.albedo_color = Color(0.07, 0.065, 0.06); _burnt.roughness = 1.0
		G.toon(_burnt, true)
	for c in n.get_children():
		if c is MeshInstance: c.material_override = _burnt
		_char(c)

func _wreck_motion(v, dt):
	var b = v.blast
	if b == null: return
	if b.y > 0.0 or b.vy > 0.0:
		b.vy -= 22.0 * dt
		b.y = max(0.0, b.y + b.vy * dt)
		b.ax += b.wx * dt; b.az += b.wz * dt
		if b.y <= 0.0 and b.vy < 0.0:
			# it lands: a small bounce, then it settles on its wheels or its roof
			b.vy = -b.vy * 0.22 if abs(b.vy) > 3.0 else 0.0
			b.wx *= 0.3; b.wz *= 0.3
			if b.vy == 0.0:
				b.ax = 0.0 if abs(wrapf(b.ax, -PI, PI)) < PI / 2 else PI
				b.az = 0.0
	if v.node:
		v.node.translation = v.pos + Vector3(0, b.y + (0.9 if b.ax == PI else 0.0), 0)
		v.node.rotation = Vector3(b.ax, v.yaw, b.az)
	# it slides to a stop
	v.vel *= max(0.0, 1.0 - dt * 2.5)
	v.pos.x += v.vel.x * dt; v.pos.z += v.vel.y * dt

# separating axes between two rectangles on the ground: [normal from b to a, depth] or null
func _sat(ac, aax, aaz, ah, bc, bax, baz, bh):
	var d = ac - bc
	var best = INF
	var bn = Vector2()
	for ax in [aax, aaz, bax, baz]:
		var ra = ah.x * abs(aax.dot(ax)) + ah.y * abs(aaz.dot(ax))
		var rb = bh.x * abs(bax.dot(ax)) + bh.y * abs(baz.dot(ax))
		var dist = d.dot(ax)
		var o = ra + rb - abs(dist)
		if o <= 0: return null
		if o < best:
			best = o; bn = ax if dist >= 0 else -ax
	return [bn, best]

func _axes(v):
	var f = fwd(v)
	return [Vector2(cos(v.yaw), -sin(v.yaw)), Vector2(f.x, f.z), Vector2(v.sp.wid / 2.0, v.sp.len / 2.0)]

# the car against buildings, walls, poles and other cars, as real turned rectangles
func collide(v):
	var A = _axes(v)
	var impact = 0.0
	var R = A[2].length() + 0.2
	for b in W.query(v.pos.x - R, v.pos.z - R, v.pos.x + R, v.pos.z + R):
		if b.y1 < 0.4 or b.y0 > 1.3: continue
		var res = _sat(Vector2(v.pos.x, v.pos.z), A[0], A[1], A[2], Vector2((b.x0 + b.x1) * 0.5, (b.z0 + b.z1) * 0.5), Vector2(1, 0), Vector2(0, 1), Vector2((b.x1 - b.x0) * 0.5, (b.z1 - b.z0) * 0.5))
		if res == null: continue
		var n = res[0]
		v.pos.x += n.x * res[1]; v.pos.z += n.y * res[1]
		var vn = v.vel.dot(n)
		if vn < 0:
			v.vel -= n * vn * 1.3
			impact = max(impact, -vn)
			# a glancing hit at the front or back turns the car a little
			var ahead = A[1].dot(-n)
			v.yaw += clamp(A[0].dot(n) * ahead * -vn * 0.015, -0.12, 0.12)
	for o2 in VEH:
		if o2 == v or o2.dead: continue
		if Vector2(o2.pos.x - v.pos.x, o2.pos.z - v.pos.z).length() > (v.sp.len + o2.sp.len) / 2 + 0.5: continue
		var B = _axes(o2)
		var res2 = _sat(Vector2(v.pos.x, v.pos.z), A[0], A[1], A[2], Vector2(o2.pos.x, o2.pos.z), B[0], B[1], B[2])
		if res2 == null: continue
		var n2 = res2[0]
		var pen2 = res2[1] * 0.5
		v.pos.x += n2.x * pen2; v.pos.z += n2.y * pen2
		if o2.driver != "remote":
			o2.pos.x -= n2.x * pen2; o2.pos.z -= n2.y * pen2
			place(o2)
		var rel = (v.vel - o2.vel).dot(n2)
		if rel < 0:
			var j = -rel * 0.6
			v.vel += n2 * j
			if o2.driver != "remote": o2.vel -= n2 * j
			impact = max(impact, -rel); o2.parked = false
			v.yaw += clamp(A[0].dot(n2) * A[1].dot(-n2) * -rel * 0.012, -0.1, 0.1)
			if -rel > 6: o2.hp -= -rel * 1.5
	if impact > 4:
		v.hp -= impact * 1.6
		main.sfx.play3d("crash_big" if impact > 10 else "crash_small", v.pos + Vector3(0, 0.7, 0), clamp(impact / 12.0, 0.35, 1.5))
		if v.driver == "player":
			main.player.shake = min(1, impact / 18.0)
			G.rumble(clamp(impact / 14.0, 0.2, 1), 0.8, 0.12 + impact * 0.012)
			if impact > 12: main.player.hurt(impact * 0.6, null, true)
	return impact

# people in the way get knocked down
func hit_people(v):
	var sp = abs(v.speed)
	if sp < 3: return
	var f = fwd(v)
	for list in [main.peds.PEDS, main.crews.ENEMIES, main.police.COPS]:
		for p in list:
			if p.is_down(): continue
			var d = Vector3(p.pos.x - v.pos.x, 0, p.pos.z - v.pos.z)
			var fd = d.dot(f)
			var ld = abs(-d.x * f.z + d.z * f.x)
			if abs(fd) < v.sp.len / 2 + 0.4 and ld < v.sp.wid / 2 + 0.35:
				p.vel.x += v.vel.x * 0.8; p.vel.z += v.vel.y * 0.8
				p.take_hit(sp * 7, false, Vector3(v.vel.x, 0, v.vel.y).normalized(), v.driver == "player", false)
	# people already down (lying still) get shoved along instead of driven through
	for list2 in [main.peds.PEDS, main.crews.ENEMIES, main.police.COPS]:
		for p2 in list2:
			if not p2.h or not p2.h.is_ragdoll() or p2.h.ragdoll_active(): continue
			var c = p2.h.ragdoll_center()
			var d3 = Vector3(c.x - v.pos.x, 0, c.z - v.pos.z)
			if abs(d3.dot(f)) < v.sp.len / 2 + 0.5 and abs(-d3.x * f.z + d3.z * f.x) < v.sp.wid / 2 + 0.5:
				p2.h.ragdoll_start(Vector3(v.vel.x, 0, v.vel.y) * 0.6, Vector3(v.vel.x, 0, v.vel.y) * 0.5 + Vector3(0, 1.2, 0), G.rand(-1, 1))
	if v.driver != "player" and not main.player.car:
		var d2 = Vector3(main.player.pos.x - v.pos.x, 0, main.player.pos.z - v.pos.z)
		if abs(d2.dot(f)) < v.sp.len / 2 + 0.4 and abs(-d2.x * f.z + d2.z * f.x) < v.sp.wid / 2 + 0.35 and not main.player.is_ragdoll():
			main.player.knock(Vector3(v.vel.x, 0, v.vel.y) * 0.9 + Vector3(0, min(7.0, sp * 0.4), 0), sp * 4, 2.2)
			main.sfx.play3d("bodyfall", main.player.pos, 0.7)

# ---------- traffic ----------
func signal_state(ix, iz, axis):
	var t = fposmod(G.world_seconds() + ix * 7 + iz * 11, SIG_CYCLE)
	if axis == "x":
		return "g" if t < 10 else ("y" if t < 13 else "r")
	return "g" if t >= 14 and t < 24 else ("y" if t >= 24 and t < 26.5 else "r")

func lane_xz(ai, along):
	if ai.axis == "x": return Vector2(along, ai.line + LANE * ai.dir)
	return Vector2(ai.line - LANE * ai.dir, along)

func next_cross(ai, along):
	var cs = GX if ai.axis == "x" else GZ
	var best = null
	for c in cs:
		var d = (c - along) * ai.dir
		if d > -4 and (best == null or d < (best - along) * ai.dir):
			best = c
	return best

func ai_drive(v, dt):
	var ai = v.ai
	var along = v.pos.x if ai.axis == "x" else v.pos.z
	var ni = next_cross(ai, along)
	var target = ai.speed
	if ni != null:
		var dI = (ni - along) * ai.dir
		if ai.turnFor != ni and dI < 34:
			ai.turnFor = ni
			var opts = []
			var cs = GX if ai.axis == "x" else GZ
			for c in cs:
				if (c - ni) * ai.dir > 1:
					opts.append("s"); opts.append("s"); break
			var perp = GZ if ai.axis == "x" else GX
			for d2 in [-1, 1]:
				for c2 in perp:
					if (c2 - ai.line) * d2 > 1:
						opts.append(d2); break
			ai.turn = G.pick(opts) if opts.size() > 0 else "s"
		var turning = typeof(ai.turn) == TYPE_INT and ai.turnFor == ni
		if turning: target = min(target, 5.8)
		if not ai.get("siren", false):
			var ix = GX.find(ni) if ai.axis == "x" else GX.find(ai.line)
			var iz = GZ.find(ai.line) if ai.axis == "x" else GZ.find(ni)
			if ix >= 0 and iz >= 0:
				var st = signal_state(ix, iz, ai.axis)
				if st != "g" and dI > 8.5 and dI < 22 and not (st == "y" and dI < 12):
					target = min(target, max(0, (dI - 10) * 0.9))
		if turning:
			var right_dir = ai.dir if ai.axis == "x" else -ai.dir
			var is_right = ai.turn == right_dir
			if dI < ((LANE + 1.2) if is_right else (-LANE + 1.2)):
				ai.axis = "z" if ai.axis == "x" else "x"; ai.line = ni; ai.dir = ai.turn; ai.turnFor = null; ai.turn = null
	var along2 = v.pos.x if ai.axis == "x" else v.pos.z
	var look = lane_xz(ai, along2 + ai.dir * (6 + abs(v.speed) * 0.35))
	var desired = atan2(look.x - v.pos.x, look.y - v.pos.z)
	var f = fwd(v)
	var block = 99.0
	var pts = []
	for o in VEH:
		if o != v and not o.dead: pts.append([o.pos, 0.3])
	if not main.player.car: pts.append([main.player.pos, 0.0])
	for p in main.peds.PEDS:
		if not p.is_down(): pts.append([p.pos, 0.0])
	for q in pts:
		var dx = q[0].x - v.pos.x
		var dz = q[0].z - v.pos.z
		var fd = dx * f.x + dz * f.z
		var ld = abs(-dx * f.z + dz * f.x)
		if fd > 0 and fd < 16 and ld < 1.9 + q[1]: block = min(block, fd)
	if block < 99: target = min(target, max(0, (block - v.sp.len / 2 - 2.4) * 1.1))
	if block < 7 and not main.player.car and main.player.pos.distance_to(v.pos) < 8 and G.REAL_T - v.last_honk > 4:
		v.last_honk = G.REAL_T; main.sfx.play3d("horn", v.pos, 0.7)
	var sp = v.speed
	var thr = 1.0 if sp < target - 0.5 else (-1.0 if sp > target + 0.8 else 0.0)
	var steer = clamp(G.ang_diff(v.yaw, desired) * 2.4, -1, 1)
	if abs(sp) < 0.3 and target > 2: v.stuck_t += dt
	else: v.stuck_t = 0
	return { "thr": thr, "steer": steer, "hand": false }

func spawn_traffic(near, min_d, max_d):
	for _k in range(30):
		var axis = "x" if randf() < 0.5 else "z"
		var line = G.pick(GZ if axis == "x" else GX)
		var dir = 1 if randf() < 0.5 else -1
		var cs = GX if axis == "x" else GZ
		var along = G.rand(cs[0] + 12, cs[cs.size() - 1] - 12)
		var ai = { "axis": axis, "line": line, "dir": dir, "speed": G.rand(8.5, 11), "turn": null, "turnFor": null }
		var p = lane_xz(ai, along)
		var d = Vector2(p.x - near.x, p.y - near.z).length()
		if d < min_d or d > max_d: continue
		var clear = true
		for o in VEH:
			if Vector2(o.pos.x - p.x, o.pos.z - p.y).length() < 9: clear = false
		for c in cs:
			if abs(c - along) < 12: clear = false
		if not clear: continue
		var yaw = (PI / 2 if dir > 0 else -PI / 2) if axis == "x" else (0.0 if dir > 0 else PI)
		var v = spawn(G.pick(G.D["CIVIL_MODELS"]), p.x, p.y, yaw)
		if v == null: return null
		v.ai = ai; v.driver = "ai"
		TRAFFIC.append(v)
		return v
	return null

func _traffic_director(dt, focus):
	_traffic_t -= dt
	if _traffic_t > 0: return
	_traffic_t = 1.5
	for v in TRAFFIC.duplicate():
		if v.dead or v.driver != "ai":
			TRAFFIC.erase(v); continue
		var d = v.pos.distance_to(focus)
		if v.hp <= 12 and not v.blown: continue          # burning: it goes up first
		if (d > 175 or v.stuck_t > 14) and d > 40:
			remove(v)
		elif v.blown and v.wreck_t > 90 and d > 30:
			remove(v)
	var want = 6 if OS.get_processor_count() <= 4 else 9
	if TRAFFIC.size() < want:
		spawn_traffic(focus, 55, 140)

func _parked_director(focus):
	var spots = G.D["PARK_SPOTS"]
	for i in range(spots.size()):
		var s = spots[i]
		var d = Vector2(s.x - focus.x, s.z - focus.z).length()
		var v = PARKED.get(i)
		if v:
			if v.dead or v.driver or v.owned or Vector2(v.pos.x - s.x, v.pos.z - s.z).length() > 2:
				PARKED.erase(i); continue
			if not s.get("keep", false) and d > 175:
				remove(v)
				PARKED.erase(i)
		elif d < 95 and not s.get("keep", false):
			var nv = spawn(s.get("model", G.pick(G.D["CIVIL_MODELS"])), s.x, s.z, s.get("yaw", 0), { "parked": true, "locked": s.get("locked", false), "color": s.get("color", G.pick(G.D["CAR_PAINTS"])), "tag": s.get("tag", null) })
			if nv:
				nv.spot = i; PARKED[i] = nv

func spawn_owned_car():
	var g = G.S["garage"][0] if G.S["garage"].size() > 0 else { "model": "hatch", "color": 0x2a6a8a }
	if own_car and not own_car.dead:
		remove(own_car)
	var p = main.player.pos
	# the nearest curb lane, clear of other cars
	var best = null
	var bd = INF
	for xl in GX:
		for sd in [-1, 1]:
			var c = Vector3(xl + sd * 4.6, 0, clamp(p.z, -140, 140))
			var d = c.distance_to(p)
			if d < bd and not W.is_blocked(c.x, c.z, 1.2):
				bd = d
				best = [c, 0.0 if sd > 0 else PI]
	if best == null: return
	own_car = spawn(g.model, best[0].x, best[0].z, best[1], { "owned": true, "color": g.color })

func nearest_car(p, r):
	var best = null
	var bd = r
	for v in VEH:
		if v.dead or v.driver == "police": continue
		var d = Vector2(v.pos.x - p.x, v.pos.z - p.z).length() - v.sp.len * 0.3
		if d < bd:
			bd = d
			best = v
	return best

func enter(v):
	var P = main.player
	if v.locked and not v.owned:
		main.hud.toast("Locked"); return
	if v.driver == "ai":
		TRAFFIC.erase(v); v.ai = null
		var l = side(v)
		main.peds.spawn_fleeing(v.pos + l * (v.sp.wid / 2 + 0.8))
		main.police.add_wanted(10, v.pos); G.S["heat"] = min(100, G.S["heat"] + 3)
		G.S["stats"]["carsTaken"] = G.S["stats"].get("carsTaken", 0) + 1
		main.hud.banner("Carjacked", v.sp.name)
	elif not v.owned:
		main.police.add_wanted(4, v.pos)
	v.driver = "player"; v.parked = false
	P.car = v; P.crouch = false; P.aim_t = 0
	main.sfx.play3d("door_open", v.pos, 0.6)
	main.sfx.engine_on(v)

func leave(v):
	v.driver = null
	main.sfx.play3d("door_close", v.pos, 0.7)
	main.sfx.engine_off()

func update(dt):
	var focus = main.player.pos if G.MODE != "title" else main.title.spot
	_traffic_director(dt, focus)
	_parked_t -= dt
	if _parked_t <= 0:
		_parked_t = 0.8
		_parked_director(focus)
	for v in VEH.duplicate():
		if v.dead: continue
		_damage(v, dt)
		if v.blown: continue
		var inp = { "thr": 0.0, "steer": 0.0, "hand": false }
		if v.driver == "remote":
			continue
		if v.driver == "player":
			inp = _player_input()
			v.hand = inp.get("hand", false)
		elif v.cop:
			inp = main.police.cop_drive(v, dt)
		elif v.ai:
			inp = ai_drive(v, dt)
		elif abs(v.speed) < 0.05 and v.vel.length() < 0.05:
			continue
		# fast cars move in short steps so they can't pass through a wall or another car
		var n = int(clamp(ceil(v.vel.length() * dt / 0.45), 1, 4))
		if v.driver == "player": n = int(max(n, ceil(dt / 0.0125)))
		for _k in range(n):
			if v.driver == "player": physics_player(v, dt / n, inp)
			else: physics(v, dt / n, inp)
			collide(v)
		if v.driver == "player": main.fx.tires(v, dt)
		elif v.slip > 0: v.slip = 0.0
		hit_people(v)
		place(v)
	_animate(dt)
	# headlight for your car after dark
	var P = main.player
	if P.car and main.DN.lamps > 0.1:
		var f = fwd(P.car)
		headlight.global_transform = Transform(Basis(), P.car.pos + Vector3(0, 0.9, 0) + f * (P.car.sp.len / 2))
		headlight.look_at(P.car.pos + f * 20 + Vector3(0, -0.5, 0), Vector3.UP)
		headlight.light_energy = 2.2 * main.DN.lamps
		headlight.visible = true
	else:
		headlight.light_energy = 0
		headlight.visible = false

var trailer_drive = false   # trailer shots: keep driving while a cutscene camera films the car

func _player_input():
	if (G.MODE != "play" and not trailer_drive) or (main.missions and main.missions.frozen()):
		return { "thr": 0.0, "gas": 0.0, "brk": 0.0, "steer": 0.0, "hand": false }
	var gas = Input.get_action_strength("move_f") + Input.get_action_strength("fire")
	var brk = Input.get_action_strength("move_b") + Input.get_action_strength("aim")
	var steer = Input.get_action_strength("move_l") - Input.get_action_strength("move_r")
	return { "thr": clamp(gas - brk, -1, 1), "gas": clamp(gas, 0, 1), "brk": clamp(brk, 0, 1), "steer": clamp(steer, -1, 1), "hand": Input.is_action_pressed("jump") }
