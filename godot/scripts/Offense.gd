extends Node
# Going on the offense:
#  - Drive-bys: hold Q / right mouse / LB in a car to lean out of the window with a K9, Draft or
#    Buzzsaw, and left mouse / RB to shoot. The crew riding with you shoots too. At night rival
#    crews come by in a car of their own and shoot at you; drop the shooter or wreck the car.
#  - Throwables: grenades and fire bottles. Hold to see the arc, let go to throw. A grenade
#    bounces and goes off after a couple of seconds; a fire bottle breaks and leaves the ground
#    burning.
#  - Crew orders: aim at a rival and tap E to send your crew in, or hold E for the order wheel:
#    rush, flank, hold a spot (they crouch and open up on whoever walks in) or regroup.
#  - Ambushes: rival crews walk their streets at night. Hit them before they see you and they're
#    slow to answer, and the fight pays a bonus.
# Online: your arm out of the window, and grenades and fire bottles show up for everyone.

var main

# ---------------------------------------------------------------- drive-by (you)
const DB_GUNS = ["buzz", "draft", "k9"]
var db = false           # leaning out and aiming
var db_k = 0.0           # how far out (0..1)
var arm = null           # your arm and gun out of the window
var _arm_key = ""
var _db_note = 0.0
var remote_arms = {}     # remote id -> { node, key }
var db_left = true       # your gun is out of your own window (false: across to the passenger's)

# ---------------------------------------------------------------- rival drive-bys
var rivals = []          # cars that came for you
var riders = []          # the shooters in them (things you can shoot)
var rival_t = 150.0

class Rider:
	var main
	var h
	var gun
	var car
	var pos = Vector3()
	var hp = 55.0
	var state = "alive"
	var crouched = false
	var name = "@rival"
	var T = { "acc": 0.3, "dmg": 8, "gun": "buzz" }
	func is_down(): return state == "down"
	func take_hit(dmg, head, dir, by_player, melee):
		if state == "down": return
		hp -= dmg * (1.6 if head else 1.0)
		main.sfx.blood(pos + Vector3(0, 1.5, 0), dir)
		if hp <= 0:
			state = "down"
			main.offense.rider_down(self, by_player)

# ---------------------------------------------------------------- throwables
const THROWN = {
	"grenade": { "name": "Grenade", "spd": 15.0, "r": 7.0, "dmg": 120.0, "fuse": 2.4 },
	"molly": { "name": "Fire bottle", "spd": 14.0, "r": 3.2, "burn": 9.0 },
}
var th_aim = ""          # being aimed: "grenade" / "molly"
var th_by_fire = false   # aimed with the fire button (equipped) instead of the throw key
var arc = null
var arc_ring = null
var proj = []
var fires = []
var _arc_mat = null
var _fire_tick = 0.0

# ---------------------------------------------------------------- crew orders and ambushes
const ORDERS = [["rush", "Rush"], ["flank", "Flank"], ["hold", "Hold here"], ["regroup", "Regroup"]]
var order = ""           # "", "rush", "flank", "hold"
var order_crew = null    # the crew they go after
var order_at = Vector3() # where they hold
var order_t = 0.0
var _use_t = -1.0        # how long E has been held while aiming
var amb_t = 70.0         # next patrol

func setup(m):
	main = m

func reset():
	db = false; db_k = 0.0; th_aim = ""
	if arm and is_instance_valid(arm): arm.queue_free()
	arm = null; _arm_key = ""
	for k in remote_arms.keys(): remote_gone(k)
	for r in rivals.duplicate(): _rival_free(r)
	rivals.clear(); riders.clear()
	for p in proj:
		if is_instance_valid(p.n): p.n.queue_free()
	proj.clear()
	for f in fires: _fire_free(f)
	fires.clear()
	if arc:
		arc.visible = false
		arc_ring.visible = false
	order = ""; order_crew = null; _use_t = -1.0
	rival_t = 150.0; amb_t = 70.0

func update(dt):
	if G.MODE == "title": return
	_arm_update(dt)
	_rivals_update(dt)
	_throw_update(dt)
	_proj_update(dt)
	_fires_update(dt)
	_orders_update(dt)
	_patrols_update(dt)

# ================================================================= DRIVE-BY
# called from the player's update while in a car
func player_car(dt):
	var P = main.player
	var want = G.MODE == "play" and not P.dead and Input.is_action_pressed("db_aim")
	if want and not db and not _db_gun():
		want = false
		if _db_note <= 0:
			_db_note = 5.0
			main.hud.toast("No gun for a drive-by. A K9, a Draft or a Buzzsaw fits out of a window.")
	_db_note = max(0.0, _db_note - dt)
	if want and not db: main.sfx.play3d("swing", P.car.pos + Vector3(0, 1.2, 0), 0.3, 0.8)
	db = want
	db_k = move_toward(db_k, 1.0 if db else 0.0, dt * 5.0)
	if db:
		P.last_look = G.REAL_T
		var trig = Input.is_action_pressed("db_fire")
		if trig and db_k > 0.6:
			if P.stats().get("auto", false) or not P.trigger_latch: P.try_fire()
			P.trigger_latch = true
		elif not trig:
			P.trigger_latch = false

func db_on(): return db_k > 0.6

func _db_gun():
	var cur = G.S["cur"]
	if not G.S.get("fists", false) and cur in DB_GUNS and G.S["guns"][cur].owned: return true
	for id in DB_GUNS:
		if G.S["guns"][id].owned:
			var P = main.player
			G.S["cur"] = id; G.S["fists"] = false; G.S["hold"] = ""
			P.reload_t = 0; P.switch_t = 0.3
			P._refresh_gun()
			return true
	return false

func db_muzzle():
	if arm and arm.has_node("gun/Muzzle"): return arm.get_node("gun/Muzzle").global_transform.origin
	if arm: return arm.get_node("hand").global_transform.origin
	return main.player.pos + Vector3(0, 1.3, 0)

func _arm_update(dt):
	var P = main.player
	if P.car == null or db_k <= 0.01 or P.dead:
		if arm: arm.visible = false
		if P.car == null:
			db = false
			db_k = 0.0
		return
	var so = G.skin_opts(G.S["skin"])
	var key = G.S["cur"] + JSON.print(GUN.cfg_of(G.S["cur"]))
	if arm == null or _arm_key != key:
		if arm: arm.queue_free()
		arm = _arm_make(GUN.build(G.S["cur"]), G.hex_color(so.skin), G.hex_color(so.jacket2 if so.top == "varsity" else so.jacket))
		_arm_key = key
	arm.visible = true
	db_left = _arm_place(arm, P.car, -main.camera.global_transform.basis.z, db_k)

# an arm holding a gun out of a car window (you, or another player online)
func _arm_make(gun, skin, sleeve):
	var a = Spatial.new()
	a.name = "DriveByArm"
	for p in [["upper", sleeve], ["fore", sleeve]]:
		var cm = CylinderMesh.new(); cm.top_radius = 1; cm.bottom_radius = 1; cm.height = 1; cm.radial_segments = 8; cm.rings = 1
		var mi = MeshInstance.new(); mi.name = p[0]; mi.mesh = cm; mi.material_override = G.mat(p[1])
		a.add_child(mi)
	var sm = SphereMesh.new(); sm.radius = 1; sm.height = 2; sm.radial_segments = 10; sm.rings = 6
	var f = MeshInstance.new(); f.name = "hand"; f.mesh = sm; f.material_override = G.mat(skin); f.scale = Vector3(0.055, 0.062, 0.06)
	a.add_child(f)
	gun.name = "gun"
	a.add_child(gun)
	main.add_child(a)
	return a

func _look_basis(z):
	z = z.normalized()
	var x = Vector3.UP.cross(z)
	if x.length() < 0.05: x = Vector3(1, 0, 0)
	x = x.normalized()
	return Basis(x, z.cross(x), z)

func _arm_place(a, car, dir, k):
	var xf = main.cockpit.car_frame(car)
	var cb = main.cockpit.cabin(car)
	var dl = (xf.basis.orthonormalized().inverse().xform(dir)).normalized()
	var W2 = float(cb.W) / 2.0
	var left = dl.x > -0.35      # out of your own window, or across to the passenger's
	var S = Vector3(cb.xD + (0.2 if left else -0.2), cb.eyeY - 0.3, cb.eyeZ - 0.02)
	var rest = Vector3(cb.xD + 0.12, cb.eyeY - 0.55, cb.eyeZ + 0.32)
	var out = Vector3(W2 + 0.14, cb.eyeY - 0.1, cb.eyeZ + 0.1) if left else Vector3(-W2 + 0.02, cb.eyeY - 0.06, cb.eyeZ + 0.2)
	var flat = Vector3(dl.x, dl.y * 0.6, dl.z)
	var H = rest.linear_interpolate(out + flat * 0.22, k)
	var E = (S + H) / 2.0 + Vector3(0.08 if left else -0.02, -0.13, 0.02)
	a.global_transform = xf
	main.vehicles._seg(a.get_node("upper"), S, E, 0.062)
	main.vehicles._seg(a.get_node("fore"), E, H, 0.054)
	a.get_node("hand").translation = H
	var g = a.get_node("gun")
	var dk = dl.linear_interpolate(Vector3(0.3, -0.6, 0.6), 1.0 - k)
	g.transform = Transform(_look_basis(dk).scaled(Vector3.ONE * 1.35), H + Vector3(0, 0.02, 0))
	return left

# cars out of the way of a shot fired from (or into) them: their own boxes would stop it
func boxes_off(cars):
	var st = []
	for v in cars:
		if v == null: continue
		st.append([v, v.box.on, v.cab.on])
		v.box.on = false; v.cab.on = false
	return st

func boxes_back(st):
	for s in st:
		s[0].box.on = s[1]; s[0].cab.on = s[2]

# another player's arm out of their window (from their state)
func remote_arm(r, dt, s):
	var on = r.car != null and float(s.get("db", 0.0)) > 0.05
	var e = remote_arms.get(r.id)
	if not on:
		if e and is_instance_valid(e.node): e.node.visible = false
		return
	var gid = str(s.get("gun", "k9"))
	if not gid in DB_GUNS: gid = "k9"
	if e == null or e.key != gid or not is_instance_valid(e.node):
		if e and is_instance_valid(e.node): e.node.queue_free()
		var so = G.skin_opts(r.skin)
		e = { "node": _arm_make(GUN.build(gid, GUN.def_cfg()), G.hex_color(so.skin), G.hex_color(so.jacket)), "key": gid }
		remote_arms[r.id] = e
	var a = s.get("dbd")
	var d = Vector3(0, 0, 1)
	if typeof(a) == TYPE_ARRAY and a.size() == 3:
		d = Vector3(clamp(float(a[0]) if typeof(a[0]) in [TYPE_INT, TYPE_REAL] else 0.0, -1, 1), clamp(float(a[1]) if typeof(a[1]) in [TYPE_INT, TYPE_REAL] else 0.0, -1, 1), clamp(float(a[2]) if typeof(a[2]) in [TYPE_INT, TYPE_REAL] else 1.0, -1, 1))
	if d.length() < 0.1: d = Vector3(0, 0, 1)
	e.node.visible = true
	_arm_place(e.node, r.car, d.normalized(), clamp(float(s.get("db", 0.0)), 0.0, 1.0))

func remote_gone(id):
	var e = remote_arms.get(id)
	if e and is_instance_valid(e.node): e.node.queue_free()
	remote_arms.erase(id)

# what goes in your network state
func net_state(s):
	if main.player.car and db_k > 0.05:
		var d = -main.camera.global_transform.basis.z
		s["db"] = stepify(db_k, 0.1)
		s["dbd"] = [stepify(d.x, 0.02), stepify(d.y, 0.02), stepify(d.z, 0.02)]

# ---------------------------------------------------------------- your crew shooting from the car
func car_target(from, rng):
	var best = null
	var bd = rng
	for e in main.crews.ENEMIES:
		if e.is_down() or e.crew.state != "combat": continue
		var d = e.pos.distance_to(from)
		if d < bd and W.seg_clear(from + Vector3(0, 1.2, 0), e.pos + Vector3(0, 1.3, 0)):
			bd = d; best = e
	for r in riders:
		if r.is_down(): continue
		var d2 = r.pos.distance_to(from)
		if d2 < bd:
			bd = d2; best = r
	return best

# ================================================================= RIVAL DRIVE-BYS
func _night():
	var m = G.world_minutes()
	return m >= 19 * 60 or m < 5 * 60

func _rivals_update(dt):
	var P = main.player
	for r in rivals.duplicate():
		if r.car.dead or r.car.blown or not is_instance_valid(r.car.node):
			if r.car.blown and r.rider.state != "down":
				r.rider.state = "down"; rider_down(r.rider, r.car.by_player)
			if r.car.dead or r.car.pos.distance_to(P.pos) > 140 or r.t > 120:
				_rival_free(r); continue
		r.t += dt
		_rider_pose(r, dt)
		if r.car.blown: continue
		if r.phase == "attack" and r.rider.state != "down":
			r.fire_cd -= dt
			if r.fire_cd <= 0: _rival_fire(r)
		if (r.phase == "flee" or r.rider.state == "down") and r.car.pos.distance_to(P.pos) > 120:
			_rival_free(r)
	if G.MODE != "play" or P.dead or main.interiors.inside != "" or G.S.get("playTime", 0) < 60: return
	if rivals.size() > 0: return
	var mine = main.turf.my_blocks().size() if main.turf else 0
	if not _night() or (G.S["heat"] < 25 and mine == 0):
		rival_t = max(rival_t, 30.0); return
	rival_t -= dt
	if rival_t > 0: return
	rival_t = G.rand(150, 260) if G.S["heat"] < 60 else G.rand(90, 160)
	spawn_rival()

func spawn_rival(crew_id = ""):
	var P = main.player
	var V = main.vehicles
	if crew_id == "": crew_id = G.pick(main.turf.CREW_IDS)
	var C = main.turf.CREWS[crew_id]
	var col = C.col.darkened(0.55)
	var paint = (col.to_rgba32() >> 8) & 0xffffff
	var v = null
	for _k in range(40):
		var axis = "x" if randf() < 0.5 else "z"
		var line = G.pick(V.GZ if axis == "x" else V.GX)
		var dirn = 1 if randf() < 0.5 else -1
		var cs = V.GX if axis == "x" else V.GZ
		var along = G.rand(cs[0] + 12, cs[cs.size() - 1] - 12)
		var ai = { "axis": axis, "line": line, "dir": dirn, "speed": 14.0, "turn": null, "turnFor": null }
		var p = V.lane_xz(ai, along)
		var d = Vector2(p.x - P.pos.x, p.y - P.pos.z).length()
		if d < 60 or d > 110: continue
		var ok = true
		for o in V.VEH:
			if Vector2(o.pos.x - p.x, o.pos.z - p.y).length() < 9: ok = false
		for c in cs:
			if abs(c - along) < 12: ok = false
		if not ok: continue
		var yaw = (PI / 2 if dirn > 0 else -PI / 2) if axis == "x" else (0.0 if dirn > 0 else PI)
		v = V.spawn(G.pick(["sedan", "suv", "bruiser"]), p.x, p.y, yaw, { "color": paint, "locked": true })
		if v:
			v.ai = ai; v.driver = "ai"
		break
	if v == null: return null
	var rd = Rider.new()
	rd.main = main; rd.car = v; rd.name = C.pre + str(G.pick(main.gang.FIRST)).to_lower()
	var lk = C.look
	rd.h = load("res://scripts/Human.gd").new().build({ "jacket": lk[0], "jacket2": lk[1], "pants": 0x18191c, "skin": G.pick([0x5a3a26, 0x7a4a30, 0x4a2e1e, 0x8a5a3a]), "hat": lk[2], "head": "beanie", "hair": "none", "mask": 0x111214 })
	main.add_child(rd.h)
	rd.gun = GUN.build("buzz", GUN.def_cfg())
	rd.gun.rotation = Vector3(PI / 2, 0, 0); rd.gun.translation = Vector3(0, -0.03, 0.02); rd.gun.scale = Vector3.ONE * 1.35
	rd.h.gun_slot.add_child(rd.gun)
	var r = { "car": v, "rider": rd, "crew": crew_id, "phase": "cruise", "t": 0.0, "pt": 0.0, "fire_cd": 1.5, "burst": 0, "lean": 0.0, "said": false }
	v.rival = r
	rivals.append(r); riders.append(rd)
	return r

func _rival_free(r):
	rivals.erase(r); riders.erase(r.rider)
	if is_instance_valid(r.rider.h): r.rider.h.queue_free()
	if not r.car.dead:
		r.car.rival = null
		if r.car.blown: return
		main.vehicles.remove(r.car)

# the rival car's driving (Vehicles asks every frame)
func rival_drive(v, dt):
	var r = v.rival
	var V = main.vehicles
	var P = main.player
	var tgt = P.car.pos if P.car else P.pos
	var d = Vector2(tgt.x - v.pos.x, tgt.z - v.pos.z).length()
	r.pt += dt
	if r.phase == "cruise":
		v.ai.speed = 15.0
		if d < 40 and not P.dead:
			r.phase = "attack"; r.pt = 0.0
			if not r.said:
				r.said = true
				main.hud.toast("A %s car's coming up slow. Watch it." % main.turf.CREWS[r.crew].name)
				main.sfx.play("notif", 0.4)
		return V.ai_drive(v, dt)
	if r.phase == "attack":
		if r.pt > 16.0 or r.rider.state == "down" or P.dead or d > 75:
			_flee(r)
			return V.ai_drive(v, dt)
		# come up with you on the shooter's side (the right)
		var f = V.fwd(v)
		var left = V.side(v)
		var aim = tgt + left * 4.2
		if P.car: aim += Vector3(P.car.vel.x, 0, P.car.vel.y) * 0.45
		var desired = atan2(aim.x - v.pos.x, aim.z - v.pos.z)
		var ang = G.ang_diff(v.yaw, desired)
		var ahead = (tgt - v.pos).dot(f)
		var want = 7.5 if d < 16 else 14.0
		if P.car: want = max(want, abs(P.car.speed) + (3.0 if ahead > 0 else -1.0))
		if ahead < -6 and d > 14:
			# went past: swing round for another pass
			return { "thr": 1.0 if v.speed < 10 else 0.0, "steer": clamp(ang * 2.6, -1, 1), "hand": abs(ang) > 1.4 and v.speed > 8 }
		var thr = 1.0 if v.speed < want else (-0.6 if v.speed > want + 2.5 else 0.0)
		return { "thr": thr, "steer": clamp(ang * 2.4, -1, 1), "hand": false }
	# leaving: back on a lane, away from you
	v.ai.speed = 21.0
	return V.ai_drive(v, dt)

func _flee(r):
	if r.phase == "flee": return
	r.phase = "flee"
	var v = r.car
	var V = main.vehicles
	# snap the lane follower onto the street the car is pointing along
	var fx = sin(v.yaw)
	var fz = cos(v.yaw)
	var ai = v.ai
	if abs(fx) > abs(fz):
		ai.axis = "x"; ai.dir = 1 if fx > 0 else -1
		ai.line = _nearest(V.GZ, v.pos.z)
	else:
		ai.axis = "z"; ai.dir = 1 if fz > 0 else -1
		ai.line = _nearest(V.GX, v.pos.x)
	ai.turn = null; ai.turnFor = null

func _nearest(list, x):
	var best = list[0]
	for c in list:
		if abs(c - x) < abs(best - x): best = c
	return best

# the shooter: in the passenger seat, leaning out of the window when it's time
func _rider_pose(r, dt):
	var rd = r.rider
	var v = r.car
	var H = rd.h
	if not is_instance_valid(H) or v.node == null: return
	if rd.state == "down":
		H.visible = false
		return
	var P = main.player
	var xf = main.cockpit.car_frame(v)
	var seats = main.cockpit.seat_spots(v)
	var tp = (P.car.pos if P.car else P.pos) + Vector3(0, 1.1, 0)
	var dl = xf.basis.orthonormalized().inverse().xform(tp - xf.origin)
	# out of the passenger window for you on the right, the back left one for you on the left
	if r.lean < 0.05: r["side"] = -1 if dl.x < 0 else 1
	var side = int(r.get("side", -1))
	# (no back row: the driver's side, then)
	var seat = (seats[2] if seats.size() > 2 else Vector3(-seats[0].x, seats[0].y, seats[0].z)) if side > 0 else seats[0]
	var want = 1.0 if r.phase == "attack" and dl.x * side > -1.5 and Vector2(dl.x, dl.z).length() < 34 else 0.0
	r.lean = move_toward(r.lean, want, dt * 2.5)
	var turn = clamp(atan2(dl.x, dl.z), -2.4, 2.4) * r.lean
	var off = Vector3(0.32 * side * r.lean, 0.16 * r.lean, 0.05 * r.lean)
	H.transform = xf * Transform(Basis(Vector3.UP, turn), seat - Vector3(0, 0.92, 0) + off)
	H.animate(dt, { "seat": true, "sway": Vector2(0, 0) })
	if r.lean > 0.05:
		var pitch = atan2(dl.y - (seat.y + 0.5), max(1.0, Vector2(dl.x, dl.z).length()))
		H._rot(H.AR.sh, lerp(-0.4, -PI / 2 - pitch, r.lean), 0, 0.0)
		H._rot(H.AR.elbow, lerp(-1.2, -0.05, r.lean), 0, 0)
		H.sync_bones()
	H.visible = true
	rd.gun.visible = r.lean > 0.3
	rd.pos = H.global_transform.origin - Vector3(0, 0.02, 0)

func _rival_fire(r):
	var rd = r.rider
	var P = main.player
	if r.lean < 0.8 or P.dead:
		r.fire_cd = 0.3; return
	var mz = rd.h.gun_slot.global_transform.origin
	var tp = (P.car.pos + Vector3(0, 1.0, 0)) if P.car else P.pos + Vector3(0, 1.25, 0)
	var to = tp - mz
	var d = to.length()
	if d > 32:
		r.fire_cd = 0.4; return
	# the street in between (neither car counts)
	var bx = boxes_off([r.car, P.car])
	var clear = W.seg_clear(mz, tp)
	boxes_back(bx)
	if not clear:
		r.fire_cd = 0.35; return
	if r.burst <= 0: r.burst = 6
	r.burst -= 1
	r.fire_cd = 0.09 if r.burst > 0 else G.rand(0.8, 1.4)
	main.sfx.flash(mz)
	main.sfx.shot("buzz", mz, 0.95)
	main.peds.alert(mz, 50)
	if main.gang.divert_shot(rd): return
	var p = 0.3 * clamp(1.25 - d / 30.0, 0.3, 1.0) * (0.65 if P.speed > 3.5 else 1.0) * (0.7 if r.car.speed > 9 else 1.0)
	var hit = randf() < p
	var end = tp if hit else tp + Vector3(G.rand(-1.4, 1.4), G.rand(-0.5, 0.9), G.rand(-1.4, 1.4))
	main.sfx.tracer(mz, end)
	if not hit:
		if randf() < 0.3: main.sfx.impact(end, false)
		return
	if P.car:
		P.car.hp -= 4
		main.sfx.impact(end, true)
		if randf() < 0.3: P.hurt(7, mz)
	else:
		P.hurt(float(rd.T.dmg), mz)

# you put a round into the rival car: the one leaning out might take it
func rival_shot(v, hp, dmg):
	var r = v.rival
	if r == null or r.rider.is_down(): return
	if r.lean > 0.3 and hp.distance_to(r.rider.pos + Vector3(0, 1.3, 0)) < 1.1:
		r.rider.take_hit(dmg * 0.7, false, (r.rider.pos - main.player.pos).normalized(), true, false)

func rider_down(rd, by_player):
	main.sfx.play3d("bodyfall", rd.pos, 0.6)
	if is_instance_valid(rd.gun): rd.gun.visible = false
	var r = rd.car.rival
	if r: _flee(r)
	if by_player:
		G.S["stats"]["downs"] = G.S["stats"].get("downs", 0) + 1
		main.story.add_cash(150)
		main.gang.rep(2)
		main.hud.banner("Shooter down", "+$150 · they're pulling off")

# ================================================================= THROWABLES
func count(kind):
	var t = G.S.get("throw", {})
	return int(t.get(kind, 0)) if typeof(t) == TYPE_DICTIONARY else 0

# start aiming one (the throw key, or the fire button with it in your hand)
func throw_begin(kind, by_fire = false):
	var P = main.player
	if th_aim != "" or P.dead or P.car or P.is_ragdoll(): return
	if main.interiors and main.interiors.inside != "":
		main.hud.toast("Not in here.")
		return
	if count(kind) <= 0:
		main.hud.toast("No %ss left. Ironside Arms has them." % THROWN[kind].name.to_lower())
		return
	th_aim = kind; th_by_fire = by_fire
	P.emote_name = ""

func _throw_update(dt):
	var P = main.player
	if th_aim == "":
		if arc:
			arc.visible = false
			arc_ring.visible = false
		return
	var held = Input.is_action_pressed("fire") if th_by_fire else Input.is_action_pressed("snowball")
	if P.dead or P.car or P.is_ragdoll() or G.MODE != "play":
		th_aim = ""; return
	var s = _throw_start()
	if not held:
		_throw_now(th_aim, s[0], s[1])
		th_aim = ""
		return
	_draw_arc(s[0], s[1], THROWN[th_aim])

func _throw_start():
	var P = main.player
	var f = -main.camera.global_transform.basis.z
	var flat = Vector3(f.x, 0, f.z).normalized()
	var from = P.pos + Vector3(0, 1.75, 0) + flat * 0.4 + Vector3(cos(P.cam_yaw), 0, -sin(P.cam_yaw)) * 0.15
	var spd = THROWN[th_aim].spd if th_aim != "" else 15.0
	var v = f.normalized() * spd + Vector3(0, 3.2, 0)
	return [from, v]

func _throw_now(kind, from, vel):
	var P = main.player
	G.S["throw"][kind] = max(0, count(kind) - 1)
	P.throw_t = 0.45; P.snow_cd = 0.6
	main.sfx.play3d("swing", from, 0.5, 0.8)
	_spawn_proj(kind, from, vel, true)
	G.S["stats"]["thrown"] = int(G.S["stats"].get("thrown", 0)) + 1
	if main.net.online():
		main.net.send_offense({ "t": "off_thr", "k": kind, "p": [stepify(from.x, 0.01), stepify(from.y, 0.01), stepify(from.z, 0.01)], "v": [stepify(vel.x, 0.01), stepify(vel.y, 0.01), stepify(vel.z, 0.01)] })
	if count(kind) == 0 and G.S.get("hold", "") == kind:
		main.player.set_fists(true)
		main.hud.toast("That was your last %s." % THROWN[kind].name.to_lower())

# the arc: where it goes and where it lands (simulated the same way it flies)
func _draw_arc(from, vel, T):
	if arc == null:
		arc = ImmediateGeometry.new()
		_arc_mat = SpatialMaterial.new(); _arc_mat.flags_unshaded = true; _arc_mat.flags_transparent = true
		_arc_mat.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD; _arc_mat.vertex_color_use_as_albedo = true
		_arc_mat.params_cull_mode = SpatialMaterial.CULL_DISABLED
		arc.material_override = _arc_mat; arc.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		main.add_child(arc)
		arc_ring = MeshInstance.new()
		var cm = CylinderMesh.new(); cm.top_radius = 1; cm.bottom_radius = 1; cm.height = 0.02; cm.radial_segments = 32; cm.rings = 1
		arc_ring.mesh = cm
		var rm = SpatialMaterial.new(); rm.flags_unshaded = true; rm.flags_transparent = true; rm.albedo_color = Color(1.0, 0.55, 0.2, 0.3)
		arc_ring.material_override = rm; arc_ring.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		main.add_child(arc_ring)
	var pts = [from]
	var p = from
	var v = vel
	var land = null
	for i in range(80):
		var step = 0.035
		v.y -= 14.0 * step
		var np = p + v * step
		var res = W.collide_point(np, 0.07)
		if res[1]:
			land = res[0]; pts.append(land); break
		p = np
		pts.append(p)
	if land == null: land = p
	var cam = main.camera.global_transform.origin
	arc.clear()
	arc.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(pts.size() - 1):
		if i % 2 == 1: continue    # dashes
		var a = pts[i]
		var b = pts[i + 1]
		var sd = (b - a).cross(cam - a).normalized() * 0.045
		var c = Color(1.0, 0.6, 0.22, 0.85 * (1.0 - float(i) / pts.size() * 0.5))
		for q in [a - sd, a + sd, b + sd, a - sd, b + sd, b - sd]:
			arc.set_color(c); arc.add_vertex(q)
	arc.end()
	arc.visible = true
	arc_ring.visible = true
	var r = float(T.r)
	arc_ring.transform = Transform(Basis().scaled(Vector3(r, 1, r)), Vector3(land.x, W.ground_at(land.x, land.z, land.y + 0.5) + 0.04, land.z))

func _spawn_proj(kind, from, vel, mine):
	var n = Spatial.new()
	if kind == "grenade":
		var mi = MeshInstance.new(); var sp = SphereMesh.new(); sp.radius = 0.065; sp.height = 0.15; sp.radial_segments = 10; sp.rings = 5
		mi.mesh = sp; mi.material_override = G.mat(Color(0.24, 0.28, 0.18)); n.add_child(mi)
		var lev = MeshInstance.new(); var bm = CubeMesh.new(); bm.size = Vector3(0.02, 0.1, 0.03)
		lev.mesh = bm; lev.material_override = G.mat(Color(0.55, 0.56, 0.58)); lev.translation = Vector3(0.05, 0.05, 0); n.add_child(lev)
	else:
		var bt = MeshInstance.new(); var cy = CylinderMesh.new(); cy.top_radius = 0.025; cy.bottom_radius = 0.045; cy.height = 0.24; cy.radial_segments = 8
		bt.mesh = cy; bt.material_override = G.mat(Color(0.22, 0.32, 0.16)); n.add_child(bt)
		var rag = MeshInstance.new(); var rq = CubeMesh.new(); rq.size = Vector3(0.04, 0.08, 0.04)
		rag.mesh = rq; rag.material_override = G.mat(Color(0.85, 0.82, 0.7)); rag.translation = Vector3(0, 0.15, 0); n.add_child(rag)
		var li = OmniLight.new(); li.light_color = Color(1.0, 0.55, 0.2); li.omni_range = 3.5; li.light_energy = 1.2; li.shadow_enabled = false
		li.translation = Vector3(0, 0.2, 0); n.add_child(li)
	n.translation = from
	main.add_child(n)
	proj.append({ "k": kind, "n": n, "p": from, "v": vel, "t": 0.0, "mine": mine, "spin": Vector3(randf() * 8 - 4, randf() * 8 - 4, randf() * 8 - 4) })

func _proj_update(dt):
	if proj.empty(): return
	var people = main.fx._people()
	for b in proj.duplicate():
		b.t += dt
		var steps = int(ceil(dt / 0.02))
		var h = dt / steps
		var burst = false
		for _s in range(steps):
			b.v.y -= 14.0 * h
			var np = b.p + b.v * h
			if b.k == "molly":
				for who in people:
					if main.fx._seg_dist(b.p, np, who.pos + Vector3(0, 1.1, 0)) < 0.45:
						burst = true; break
			var res = W.collide_point(np, 0.07)
			if res[1]:
				if b.k == "molly":
					np = res[0]; burst = true
				else:
					var n = res[0] - np
					if n.length() < 0.0001: n = Vector3.UP
					n = n.normalized()
					var hit_sp = b.v.length()
					b.v = b.v.bounce(n) * 0.42
					if n.y > 0.6:
						b.v.x *= 0.72; b.v.z *= 0.72
					np = res[0]
					if hit_sp > 2.5: main.sfx.play3d("imp_metal" if randf() < 0.5 else "tap", np, 0.35, 1.6)
			b.p = np
			if burst: break
		b.n.translation = b.p
		b.n.rotation += b.spin * dt * (1.0 if b.v.length() > 1.0 else 0.1)
		if b.k == "grenade" and b.t >= THROWN.grenade.fuse:
			_blast(b.p, b.mine)
			b.n.queue_free(); proj.erase(b)
		elif b.k == "molly" and (burst or b.t > 5.0):
			_ignite(Vector3(b.p.x, W.ground_at(b.p.x, b.p.z, b.p.y + 0.3), b.p.z), b.mine)
			b.n.queue_free(); proj.erase(b)

# a grenade going off
func _blast(at, mine):
	var T = THROWN.grenade
	var R = float(T.r)
	main.fx.explosion(at + Vector3(0, 0.2, 0))
	main.sfx.play3d("car_explode", at, 0.85, 1.25, "Guns")
	main.sfx.play3d("boom", at, 1.0, 0.8)
	var P = main.player
	var dP = P.pos.distance_to(at)
	P.shake = max(P.shake, clamp(1.4 - dP / 20.0, 0.0, 1.2))
	G.rumble(0.9, 0.9, 0.4 if dP < 12 else 0.15)
	main.peds.alert(at, 85)
	if dP < R and not P.dead and not P.car and W.seg_clear(at + Vector3(0, 0.4, 0), P.pos + Vector3(0, 1.0, 0)):
		var k = 1.0 - dP / R
		P.hurt(k * 95.0, at)
		if not P.dead: P.knock((P.pos - at).normalized() * k * 8.0 + Vector3(0, 3.5 * k, 0), 0.0, 1.8)
	if not mine: return
	for list in [main.crews.ENEMIES, main.peds.PEDS, main.police.COPS, riders, main.net.targets()]:
		for e in list:
			if e.is_down(): continue
			var de = e.pos.distance_to(at)
			if de > R: continue
			if not W.seg_clear(at + Vector3(0, 0.4, 0), e.pos + Vector3(0, 1.0, 0)): continue
			var dir = (e.pos - at)
			dir.y = 0
			e.take_hit(float(T.dmg) * pow(1.0 - de / R, 0.7), false, dir.normalized() if dir.length() > 0.01 else Vector3(1, 0, 0), true, false)
	for f in main.gang.FOL:
		if f.state == "down" or f.riding: continue
		var df = f.pos.distance_to(at)
		if df < R: main.gang._hurt(f, 70.0 * (1.0 - df / R), at)
	for o in main.vehicles.VEH:
		if o.dead or o.blown: continue
		var dc = Vector2(o.pos.x - at.x, o.pos.z - at.z)
		var l = dc.length()
		if l < R + 1.5:
			var k2 = 1.0 - l / (R + 1.5)
			o.hp -= 70.0 * k2
			o.vel += dc.normalized() * k2 * 4.0
			o.by_player = true
	main.police.on_shot(at)
	main.police.add_wanted(14, at)
	main.crews.on_player_shot(at)
	G.S["heat"] = min(100, G.S["heat"] + 5)

# a fire bottle breaking: the ground burns for a while
func _ignite(at, mine):
	main.sfx.play3d("crash_small", at, 0.6, 1.5)
	main.sfx.play3d("whoosh", at, 0.8, 0.7)
	main.sfx.play3d("fire", at, 0.7)
	var fx = main.fx
	if fx._soft == null: fx._soft = fx._soft_tex()
	var R = float(THROWN.molly.r)
	var fi = fx._particles(70, 0.9, Color(1, 0.6, 0.2, 0.95), 0.9, true)
	fi.mesh.material.albedo_texture = fx._soft
	fi.emission_shape = CPUParticles.EMISSION_SHAPE_BOX; fi.emission_box_extents = Vector3(R * 0.62, 0.05, R * 0.62)
	fi.direction = Vector3(0, 1, 0); fi.spread = 14; fi.gravity = Vector3(0, 2.6, 0); fi.initial_velocity = 1.3; fi.initial_velocity_random = 0.5
	fi.scale_amount = 1.4; fi.scale_amount_random = 0.5
	fi.mesh.material.albedo_color = Color(1, 1, 1, 1)
	var g = Gradient.new(); g.set_color(0, Color(0.95, 0.6, 0.22, 0.6)); g.add_point(0.4, Color(0.85, 0.3, 0.05, 0.5)); g.set_color(g.get_point_count() - 1, Color(0.35, 0.05, 0.01, 0)); fi.color_ramp = g
	fi.translation = at + Vector3(0, 0.05, 0)
	fi.visible = true; fi.emitting = true
	var sm = fx._particles(24, 3.0, Color(1, 1, 1, 1), 1.6, false)
	sm.mesh.material.albedo_texture = fx._soft; sm.mesh.material.flags_unshaded = false
	sm.emission_shape = CPUParticles.EMISSION_SHAPE_BOX; sm.emission_box_extents = Vector3(R * 0.5, 0.2, R * 0.5)
	sm.direction = Vector3(0, 1, 0); sm.spread = 20; sm.gravity = Vector3(0.4, 1.4, 0); sm.initial_velocity = 1.2
	var g2 = Gradient.new(); g2.set_color(0, Color(0.15, 0.13, 0.12, 0.0)); g2.add_point(0.15, Color(0.13, 0.12, 0.11, 0.6)); g2.set_color(g2.get_point_count() - 1, Color(0.25, 0.25, 0.25, 0.0)); sm.color_ramp = g2
	sm.translation = at + Vector3(0, 0.6, 0)
	sm.visible = true; sm.emitting = true
	var li = OmniLight.new(); li.light_color = Color(1, 0.55, 0.2); li.omni_range = 10; li.light_energy = 2.0; li.shadow_enabled = false
	li.translation = at + Vector3(0, 1.0, 0)
	main.add_child(li)
	fires.append({ "at": at, "r": R, "t": 0.0, "life": float(THROWN.molly.burn), "fire": fi, "smoke": sm, "light": li, "mine": mine })
	if mine:
		main.peds.alert(at, 45)
		main.crews.on_player_shot(at)
		main.police.add_wanted(8, at)
		G.S["heat"] = min(100, G.S["heat"] + 3)

func _fire_free(f):
	for k in ["fire", "smoke", "light"]:
		if is_instance_valid(f[k]): f[k].queue_free()

func _fires_update(dt):
	if fires.empty(): return
	_fire_tick -= dt
	var tick = _fire_tick <= 0
	if tick: _fire_tick = 0.33
	var P = main.player
	for f in fires.duplicate():
		f.t += dt
		var fade = clamp((f.life - f.t) / 2.0, 0.0, 1.0)
		f.light.light_energy = (1.8 + sin(G.REAL_T * 21.0) * 0.35 + sin(G.REAL_T * 6.0) * 0.25) * fade
		if f.t > f.life - 1.5: f.fire.emitting = false
		if f.t > f.life + 1.2:
			f.smoke.emitting = false
		if f.t > f.life + 3.5:
			_fire_free(f); fires.erase(f); continue
		if not tick or f.t > f.life - 1.0: continue
		var R = float(f.r)
		if not P.dead and not P.car and Vector2(P.pos.x - f.at.x, P.pos.z - f.at.z).length() < R and P.pos.y < f.at.y + 1.2:
			P.hurt(6.0, f.at, true); main.hud.hurt_flash(6.0)
		for o in main.vehicles.VEH:
			if o.dead or o.blown: continue
			if Vector2(o.pos.x - f.at.x, o.pos.z - f.at.z).length() < R + 1.0:
				o.hp -= 9.0
				if f.mine: o.by_player = true
		if not f.mine: continue
		for list in [main.crews.ENEMIES, main.peds.PEDS, main.police.COPS, main.net.targets()]:
			for e in list:
				if e.is_down(): continue
				if Vector2(e.pos.x - f.at.x, e.pos.z - f.at.z).length() > R or e.pos.y > f.at.y + 1.2: continue
				var dir = Vector3(e.pos.x - f.at.x, 0, e.pos.z - f.at.z)
				dir = dir.normalized() if dir.length() > 0.01 else Vector3(1, 0, 0)
				if list == main.crews.ENEMIES: main.crews.damage(e, 9.0, false, dir, true)
				else: e.take_hit(9.0, false, dir, true, false)
		for fo in main.gang.FOL:
			if fo.state != "down" and not fo.riding and Vector2(fo.pos.x - f.at.x, fo.pos.z - f.at.z).length() < R:
				main.gang._hurt(fo, 5.0, f.at)

# from the network: someone else threw one
func net_event(t, r, e):
	if t == "off_thr":
		var k = str(e.get("k", ""))
		if not THROWN.has(k): return
		var p = e.get("p")
		var v = e.get("v")
		if typeof(p) != TYPE_ARRAY or typeof(v) != TYPE_ARRAY or p.size() != 3 or v.size() != 3: return
		for x in p + v:
			if not typeof(x) in [TYPE_INT, TYPE_REAL]: return
		var from = Vector3(clamp(p[0], -300, 300), clamp(p[1], -5, 60), clamp(p[2], -300, 300))
		if r != null and from.distance_to(r.pos) > 8: return
		var vel = Vector3(clamp(v[0], -30, 30), clamp(v[1], -30, 30), clamp(v[2], -30, 30))
		_spawn_proj(k, from, vel, false)

# ================================================================= CREW ORDERS
# E while aiming: tap sends them at who you're aiming at, hold opens the order wheel
func orders_input(dt):
	var P = main.player
	if main.gang.FOL.empty() or not P.aiming or P.car:
		if _use_t >= 0 and main.hud.wheel_kind == "order": main.hud._close_wheel(true)
		_use_t = -1.0
		return
	if Input.is_action_just_pressed("use"):
		_use_t = 0.0
	if _use_t >= 0:
		if Input.is_action_pressed("use"):
			_use_t += dt
			if _use_t > 0.25 and main.hud.wheel_kind == "": main.hud._open_wheel("order")
		else:
			if main.hud.wheel_kind == "order": main.hud._close_wheel(true)
			elif _use_t <= 0.25: give_order("rush")
			_use_t = -1.0

func ordering(): return _use_t >= 0

# who's under the crosshair: a rival crew
func _aimed_crew():
	var cam = main.camera.global_transform
	var o = cam.origin
	var f = -cam.basis.z
	var best = null
	var bs = 0.16
	for e in main.crews.ENEMIES:
		if e.is_down(): continue
		var to = e.pos + Vector3(0, 1.2, 0) - o
		var d = to.length()
		if d > 70 or d < 1.0: continue
		var s = f.angle_to(to / d)
		if s < bs and W.seg_clear(o, e.pos + Vector3(0, 1.2, 0)):
			bs = s; best = e.crew
	return best

func _aimed_spot():
	var cam = main.camera.global_transform
	var f = -cam.basis.z
	var t = W.raycast(cam.origin, f, 45.0)
	var p = cam.origin + f * (t if t != INF else 20.0)
	p -= Vector3(f.x, 0, f.z).normalized() * 0.8
	return Vector3(p.x, 0, p.z)

func give_order(id):
	var F = main.gang.FOL
	if F.empty(): return
	var P = main.player
	var who = null
	for f in F:
		if f.state != "down":
			who = f
			break
	if id == "regroup":
		order = ""; order_crew = null
		main.hud.toast("Crew:  on me")
		if who: main.hud.say(who.rec.name, G.pick(["Right behind you.", "Coming.", "On you."]))
		return
	if id == "hold":
		order = "hold"; order_at = _aimed_spot(); order_crew = null; order_t = 0.0
		main.hud.toast("Crew:  hold that spot. They open up on anyone who walks in.")
		if who: main.hud.say(who.rec.name, G.pick(["We'll sit on it.", "Say less. We wait.", "Posted."]))
		return
	var c = _aimed_crew()
	if c == null:
		main.hud.toast("Aim at a rival to send your crew")
		return
	order = id; order_crew = c; order_t = 0.0
	main.hud.toast("Crew:  %s" % ("go get them" if id == "rush" else "flank them, two sides"))
	if who: main.hud.say(who.rec.name, G.pick(["Say less.", "On it.", "Moving.", "Bet."]))
	main.sfx.play("tap", 0.4)

func _orders_update(dt):
	if order == "": return
	order_t += dt
	var P = main.player
	if order == "hold":
		if P.pos.distance_to(order_at) > 80: order = ""
		return
	if order_crew == null or not order_crew in main.crews.CREWS:
		order = ""; order_crew = null; return
	var alive = false
	for e in order_crew.members:
		if not e.is_down(): alive = true
	if not alive or order_crew.state == "leave":
		order = ""; order_crew = null
		for f in main.gang.FOL:
			if f.state != "down":
				main.hud.say(f.rec.name, G.pick(["Clear.", "That's handled.", "They done."]))
				break

# where a follower should be and who they should hit, under the current order (Gang asks)
func follower_plan(f):
	if order == "" or f.riding: return null
	if order == "hold":
		var a = f.slot * 1.9
		var spot = order_at + Vector3(cos(a) * 1.6, 0, sin(a) * 1.6)
		var tg = null
		var bd = 30.0
		for e in main.crews.ENEMIES:
			if e.is_down() or e.crew.state == "leave": continue
			var d = e.pos.distance_to(f.pos)
			if d < bd and W.seg_clear(f.pos + Vector3(0, 1.0, 0), e.pos + Vector3(0, 1.2, 0)):
				bd = d; tg = e
		return { "goal": spot, "tg": tg, "crouch": true, "range": 30.0 }
	var tg2 = null
	var bd2 = INF
	for e in order_crew.members:
		if e.is_down(): continue
		var d2 = e.pos.distance_to(f.pos)
		if d2 < bd2:
			bd2 = d2
			tg2 = e
	if tg2 == null: return null
	var goal = tg2.pos
	if order == "flank" and f.slot % 2 == 1:
		var P = main.player
		var ax = (tg2.pos - P.pos)
		ax.y = 0
		ax = ax.normalized() if ax.length() > 0.1 else Vector3(1, 0, 0)
		var side = Vector3(-ax.z, 0, ax.x) * (1 if f.slot % 4 == 1 else -1)
		var fp = tg2.pos + side * 11.0
		if f.pos.distance_to(fp) > 3.0 and order_t < 12.0: goal = fp
	return { "goal": goal, "tg": tg2, "crouch": false, "range": 40.0 }

# ================================================================= AMBUSHES
# rival crews walking their streets at night, not looking for you (yet)
func _patrols_update(dt):
	var P = main.player
	if G.MODE != "play" or P.dead or main.interiors.inside != "" or not _night(): return
	if main.gang.gang() == null and G.S["buzz"] < 15: return
	for c in main.crews.CREWS:
		if c.state == "patrol": return
	amb_t -= dt
	if amb_t > 0: return
	amb_t = G.rand(110, 170)
	spawn_patrol()

func spawn_patrol(crew_id = ""):
	var P = main.player
	var XL = G.D["XL"]
	var ZL = G.D["ZL"]
	if crew_id == "": crew_id = G.pick(main.turf.CREW_IDS)
	for _k in range(30):
		var along_x = randf() < 0.5
		var line = G.pick(ZL if along_x else XL)
		var lat = (line - P.pos.z) if along_x else (line - P.pos.x)
		if abs(lat) < 8 or abs(lat) > 60: continue
		var side = 4.2 if randf() < 0.5 else -4.2
		var dirn = 1 if randf() < 0.5 else -1
		var a = (P.pos.x if along_x else P.pos.z) - dirn * G.rand(70, 95)
		var b = (P.pos.x if along_x else P.pos.z) + dirn * G.rand(60, 90)
		a = clamp(a, -W.BOUND + 10, W.BOUND - 10); b = clamp(b, -W.BOUND + 10, W.BOUND - 10)
		var p0 = Vector3(a, 0, line + side) if along_x else Vector3(line + side, 0, a)
		var p1 = Vector3(b, 0, line + side) if along_x else Vector3(line + side, 0, b)
		if p0.x > G.D["SHORE_X"] + 6 or W.is_blocked(p0.x, p0.z, 0.6): continue
		if p0.distance_to(P.pos) < 45: continue
		var c = main.turf._spawn_crew(-1, crew_id, p0, 3 + (1 if randf() < 0.4 else 0), 2, true)
		c.state = "patrol"; c["route"] = [p0, p1]; c["ri"] = 1
		for e in c.members: e.yaw = atan2(p1.x - p0.x, p1.z - p0.z)
		if main.gang.gang() != null:
			main.hud.toast("Lookout:  %s crew walking %s. They haven't seen you." % [main.turf.CREWS[crew_id].name, main.hud.street_name(p0)])
		return c
	return null

# hit before they knew you were there (Crews calls this)
func first_strike(c):
	if c.get("ambushed", false) or c.get("fought", false): return
	c["ambushed"] = true
	for e in c.members:
		e.see_t = -1.4          # a beat before they can answer
	main.hud.banner("Ambush", "Hit them first")
	main.sfx.play("chime", 0.5, 0.8)

func ambush_paid(c):
	var pay = 120 + 60 * c.members.size()
	main.story.add_cash(pay)
	main.gang.rep(3)
	G.S["stats"]["ambushes"] = int(G.S["stats"].get("ambushes", 0)) + 1
	main.hud.banner("Ambush", "+%s · rep +3" % G.fmt_money(pay))
