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
	var box = {}
	var cab = {}

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
	var n = _scene(model).instance()
	main.add_child(n)
	v.node = n
	_paint(v)
	VEH.append(v)
	place(v)
	return v

func _paint(v, n = null):
	if n == null: n = v.node
	for c in n.get_children():
		if c is MeshInstance:
			for i in range(c.mesh.get_surface_count()):
				var m = c.mesh.surface_get_material(i)
				if m is SpatialMaterial:
					m.vertex_color_use_as_albedo = true; m.vertex_color_is_srgb = true; m.metallic = 0.0; m.metallic_specular = 0.35
			if c.name.begins_with("paint"):
				var pm = SpatialMaterial.new()
				pm.vertex_color_use_as_albedo = true; pm.vertex_color_is_srgb = true
				pm.albedo_color = G.hex_color(v.color); pm.roughness = 0.35; pm.metallic = 0.0; pm.metallic_specular = 0.6
				c.material_override = pm
				v.paint_mat = pm
			c.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		_paint(v, c)

func remove(v):
	if v.dead: return
	v.dead = true
	W.DYN.erase(v.box); W.DYN.erase(v.cab)
	VEH.erase(v); TRAFFIC.erase(v)
	if v.node: v.node.queue_free()
	if v == own_car: own_car = null

func place(v):
	v.node.translation = v.pos
	v.node.rotation = Vector3(0, v.yaw, 0)
	var c = abs(cos(v.yaw))
	var s = abs(sin(v.yaw))
	var W2 = v.sp.wid / 2.0
	var L2 = v.sp.len / 2.0
	var hx = c * W2 + s * L2
	var hz = s * W2 + c * L2
	v.box.x0 = v.pos.x - hx; v.box.x1 = v.pos.x + hx; v.box.z0 = v.pos.z - hz; v.box.z1 = v.pos.z + hz
	v.cab.x0 = v.pos.x - hx * 0.6; v.cab.x1 = v.pos.x + hx * 0.6; v.cab.z0 = v.pos.z - hz * 0.6; v.cab.z1 = v.pos.z + hz * 0.6

func fwd(v): return Vector3(sin(v.yaw), 0, cos(v.yaw))
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

func collide(v):
	var f = fwd(v)
	var L = v.sp.len
	var r = v.sp.wid / 2.0
	var impact = 0.0
	for o in [-(L / 2 - r), 0.0, L / 2 - r]:
		var cx = v.pos.x + f.x * o
		var cz = v.pos.z + f.z * o
		for b in W.query(cx - r, cz - r, cx + r, cz + r):
			if b.y1 < 0.4 or b.y0 > 1.3: continue
			var px = clamp(cx, b.x0, b.x1)
			var pz = clamp(cz, b.z0, b.z1)
			var dx = cx - px
			var dz = cz - pz
			var d = Vector2(dx, dz).length()
			if d >= r: continue
			if d < 1e-4:
				dx = cx - (b.x0 + b.x1) / 2; dz = cz - (b.z0 + b.z1) / 2; d = max(Vector2(dx, dz).length(), 1e-3)
			var nx = dx / d
			var nz = dz / d
			var pen = r - min(d, r)
			v.pos.x += nx * pen; v.pos.z += nz * pen
			var vn = v.vel.x * nx + v.vel.y * nz
			if vn < 0:
				v.vel.x -= 1.3 * vn * nx; v.vel.y -= 1.3 * vn * nz; impact = max(impact, -vn)
	for o2 in VEH:
		if o2 == v or o2.dead: continue
		if Vector2(o2.pos.x - v.pos.x, o2.pos.z - v.pos.z).length() > (L + o2.sp.len) / 2 + 0.5: continue
		var fo = fwd(o2)
		var ro = o2.sp.wid / 2.0
		for a in [-(L / 2 - r), 0.0, L / 2 - r]:
			for b2 in [-(o2.sp.len / 2 - ro), 0.0, o2.sp.len / 2 - ro]:
				var ax = v.pos.x + f.x * a
				var az = v.pos.z + f.z * a
				var bx = o2.pos.x + fo.x * b2
				var bz = o2.pos.z + fo.z * b2
				var dd = Vector2(ax - bx, az - bz)
				var d2 = dd.length()
				var mn = r + ro
				if d2 >= mn or d2 < 1e-4: continue
				var n = dd / d2
				var pen2 = (mn - d2) / 2
				v.pos.x += n.x * pen2; v.pos.z += n.y * pen2; o2.pos.x -= n.x * pen2; o2.pos.z -= n.y * pen2
				var rel = (v.vel.x - o2.vel.x) * n.x + (v.vel.y - o2.vel.y) * n.y
				if rel < 0:
					var j = -rel * 0.6
					v.vel += n * j; o2.vel -= n * j; impact = max(impact, -rel); o2.parked = false
					if -rel > 6: o2.hp -= -rel * 1.5
	if impact > 4:
		v.hp -= impact * 1.6
		main.sfx.play3d("crash_big" if impact > 10 else "crash_small", v.pos + Vector3(0, 0.7, 0), clamp(impact / 12.0, 0.35, 1.5))
		if v.driver == "player":
			main.player.shake = min(1, impact / 18.0)
			Input.start_joy_vibration(0, clamp(impact / 14.0, 0.2, 1), 0.8, 0.12 + impact * 0.012)
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
		if (d > 175 or v.stuck_t > 14 or v.hp <= 0) and (d > 40 or v.hp <= 0):
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
		var inp = { "thr": 0.0, "steer": 0.0, "hand": false }
		if v.driver == "remote":
			continue
		if v.driver == "player":
			inp = _player_input()
		elif v.cop:
			inp = main.police.cop_drive(v, dt)
		elif v.ai:
			inp = ai_drive(v, dt)
		elif abs(v.speed) < 0.05 and v.vel.length() < 0.05:
			continue
		physics(v, dt, inp)
		collide(v)
		hit_people(v)
		place(v)
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

func _player_input():
	if G.MODE != "play":
		return { "thr": 0.0, "steer": 0.0, "hand": false }
	var thr = Input.get_action_strength("move_f") - Input.get_action_strength("move_b") + Input.get_action_strength("fire") - Input.get_action_strength("aim")
	var steer = Input.get_action_strength("move_l") - Input.get_action_strength("move_r")
	return { "thr": clamp(thr, -1, 1), "steer": clamp(steer, -1, 1), "hand": Input.is_action_pressed("jump") }
