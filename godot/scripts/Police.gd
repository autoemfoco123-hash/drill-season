extends Node
# Wanted level, cruisers that chase you, officers on foot, arrests. Ported from 77_police.js.

var main
var COPS = []
var level = 0
var pts = 0.0
var last = Vector3()
var seen_t = 99.0
var hostile = false
var decay_t = 0.0
var spawn_t = 0.0
var see_t = 0.0
var bust_t = 0.0
var siren_t = 0.0
const STEPS = [8, 25, 45, 70, 90]

class Cop:
	var main
	var h
	var gun
	var car = null
	var pos = Vector3()
	var vel = Vector3()
	var radius = 0.34
	var height = 1.75
	var on_ground = true
	var air_y = 0.0
	var yaw = 0.0
	var state = "chase"
	var hp = 70.0
	var fire_cd = 1.0
	var can_see = null
	var down_t = 0.0
	var crouched = false
	func is_down(): return state == "down"
	func take_hit(dmg, head, dir, by_player, melee):
		main.police.cop_hit(self, dmg * (0.8 if melee else 1.0), dir, by_player, melee)

func setup(m):
	main = m

func level_for(p):
	var l = 0
	for s in STEPS:
		if p >= s: l += 1
	return l

func witnesses(at, r):
	var n = 0
	for p in main.peds.PEDS:
		if not p.is_down() and p.pos.distance_to(at) < r: n += 1
	for c in COPS:
		if not c.is_down() and c.pos.distance_to(at) < r * 1.4: n += 3
	return n

func add_wanted(p, where = null, force = false):
	if G.MODE == "title": return
	var w = where if where != null else main.player.pos
	if not force and witnesses(w, 48) == 0 and p < 20: return
	var before = level
	pts = min(100, pts + p)
	level = level_for(pts)
	last = main.player.pos; seen_t = 0
	if level > before:
		main.sfx.play("stab", 0.4)
		if before == 0: main.hud.toast("Police are on the way")

func clear():
	pts = 0; level = 0; hostile = false; bust_t = 0
	for c in COPS.duplicate(): remove_cop(c)
	for v in main.vehicles.VEH.duplicate():
		if v.cop:
			v.cop.mode = "leave"
			v.siren = false

func on_shot(at):
	var near = false
	for c in COPS:
		if not c.is_down() and c.pos.distance_to(at) < 35: near = true
	for v in main.vehicles.VEH:
		if v.cop and v.pos.distance_to(at) < 45: near = true
	add_wanted(10 if near else 3, at, near)
	if near: hostile = true

func cop_hit(c, dmg, dir, by_player, melee):
	if c.is_down(): return
	c.hp -= dmg
	if not melee: main.sfx.blood(c.pos + Vector3(0, 1.2, 0), dir)
	if by_player:
		hostile = true
		add_wanted(35 if c.hp <= 0 else 16, c.pos, true)
		G.S["heat"] = min(100, G.S["heat"] + (8 if c.hp <= 0 else 3))
	if c.hp <= 0:
		c.state = "down"; c.down_t = 0
		if c.gun: c.gun.visible = false
		c.h.ragdoll_start(Vector3(), Vector3(dir.x, 0, dir.z) * (3.0 if melee else 2.0) + Vector3(0, 0.8, 0), G.rand(-1, 1))
		main.sfx.play3d("bodyfall", c.pos, 0.8)

func spawn_cruiser():
	var P = main.player
	var V = main.vehicles
	for _k in range(30):
		var axis = "x" if randf() < 0.5 else "z"
		var line = G.pick(V.GZ if axis == "x" else V.GX)
		var dir = 1 if randf() < 0.5 else -1
		var along = G.rand(-140, 140)
		var ai = { "axis": axis, "line": line, "dir": dir, "speed": 17, "siren": true, "turn": null, "turnFor": null }
		var p = V.lane_xz(ai, along)
		var d = Vector2(p.x - P.pos.x, p.y - P.pos.z).length()
		if d < 60 or d > 130: continue
		var yaw = (PI / 2 if dir > 0 else -PI / 2) if axis == "x" else (0.0 if dir > 0 else PI)
		var v = V.spawn("police", p.x, p.y, yaw, { "color": 0x101216 })
		if v == null: return null
		v.driver = "police"; v.siren = true; v.ai = ai
		v.cop = { "mode": "respond", "deployed": false, "t": 0.0 }
		return v
	return null

func cop_drive(v, dt):
	var V = main.vehicles
	var P = main.player
	var C = v.cop
	C.t += dt
	var tgt = P.car.pos if P.car else (P.pos if seen_t < 6 else last)
	var d = Vector2(tgt.x - v.pos.x, tgt.z - v.pos.z).length()
	if C.mode == "leave" or level == 0:
		v.siren = false; v.ai.siren = false; v.ai.speed = 10
		if v.pos.distance_to(P.pos) > 110:
			V.remove(v); return { "thr": 0.0, "steer": 0.0, "hand": false }
		return V.ai_drive(v, dt)
	v.siren = true
	if C.deployed:
		if P.car and d > 25:
			var all_back = true
			for c in COPS:
				if c.car == v and not c.is_down() and c.pos.distance_to(v.pos) > 4: all_back = false
			if all_back or C.t > 14:
				for c in COPS.duplicate():
					if c.car == v: remove_cop(c)
				C.deployed = false; C.t = 0
		return { "thr": -1.0 if v.speed > 0.3 else 0.0, "steer": 0.0, "hand": true }
	var desired = atan2(tgt.x - v.pos.x, tgt.z - v.pos.z)
	if P.car and d < 60:
		var px = tgt.x + P.car.vel.x * 0.6
		var pz = tgt.z + P.car.vel.y * 0.6
		desired = atan2(px - v.pos.x, pz - v.pos.z)
		var ahead = abs(G.ang_diff(v.yaw, desired)) < 1.4
		return { "thr": 1.0 if ahead else (-1.0 if v.speed > 4 else 0.6), "steer": clamp(G.ang_diff(v.yaw, desired) * 2.8, -1, 1), "hand": abs(G.ang_diff(v.yaw, desired)) > 1.0 and v.speed > 12 }
	if d < 40:
		var steer = clamp(G.ang_diff(v.yaw, desired) * 2.4, -1, 1)
		if d < 15 and not P.car:
			if abs(v.speed) < 1.5 and level > 0: deploy(v)
			return { "thr": -1.0 if v.speed > 0.4 else 0.0, "steer": steer, "hand": v.speed > 6 }
		return { "thr": 1.0 if v.speed < 11 else 0.0, "steer": steer, "hand": false }
	v.ai.speed = 18
	return V.ai_drive(v, dt)

func deploy(v):
	v.cop.deployed = true; v.cop.t = 0
	var l = main.vehicles.side(v)
	for s in [1, -1]:
		var p = v.pos + l * s * (v.sp.wid / 2 + 0.7)
		if not W.is_blocked(p.x, p.z, 0.3): spawn_cop(p, v)
	if level >= 3 or hostile:
		main.hud.say("POLICE", G.pick(["Drop it! Now!", "Shots fired, engaging!", "Get on the ground!"]))
	else:
		main.hud.say("POLICE", G.pick(["Hands where I can see them!", "Stop right there!", "Get on the ground!"]))

func spawn_cop(p, car):
	var c = Cop.new()
	c.main = main; c.car = car; c.pos = p; c.yaw = car.yaw if car else 0.0; c.fire_cd = G.rand(0.8, 1.4)
	c.h = load("res://scripts/Human.gd").new().build({ "jacket": 0x1b2436, "jacket2": 0x232e44, "pants": 0x161b26, "skin": G.pick([0x5a3a26, 0x7a4a30, 0x4a2e1e, 0x8a5a3a, 0xa87a58, 0xc89a78]), "hat": 0x10141e, "cap": true, "head": "cap", "badge": true, "shoes": 0x0c0c0c })
	main.add_child(c.h)
	c.gun = GUN.build("k9", GUN.def_cfg())
	c.gun.rotation = Vector3(PI / 2, 0, 0); c.gun.translation = Vector3(0, -0.03, 0.02); c.gun.scale = Vector3.ONE * 1.35
	c.h.gun_slot.add_child(c.gun)
	COPS.append(c)
	return c

func remove_cop(c):
	COPS.erase(c)
	if is_instance_valid(c.h): c.h.queue_free()

func _sees(c):
	var P = main.player
	var eye = c.pos + Vector3(0, 1.55, 0)
	if c.pos.distance_to(P.pos) > 70 or P.dead: return null
	if P.car:
		var cp = P.car.pos + Vector3(0, 1, 0)
		return cp if W.seg_clear(eye, cp) else null
	for t in P.targets():
		if W.seg_clear(eye, t): return t
	return null

func _shoot(c):
	var P = main.player
	var tp = c.can_see
	if tp == null: return
	var mz = c.h.gun_slot.global_transform.origin
	var d = c.pos.distance_to(P.pos)
	var p = 0.34 * clamp(1.3 - d / 35.0, 0.25, 1)
	if P.crouch and not P.aiming: p *= 0.6
	if P.speed > 3.5: p *= 0.65
	if P.car: p *= 0.7
	var hit = randf() < p
	var end = tp if hit else tp + Vector3(G.rand(-1.2, 1.2), G.rand(-0.5, 0.8), G.rand(-1.2, 1.2))
	main.sfx.tracer(mz, end)
	main.sfx.shot("k9", mz, 0.8)
	main.peds.alert(c.pos, 35)
	if hit:
		if P.car:
			P.car.hp -= 4
			if randf() < 0.35: P.hurt(5, c.pos)
		else:
			P.hurt(8, c.pos)

func update(dt):
	var P = main.player
	see_t -= dt
	if see_t <= 0:
		see_t = 0.3
		var seen = false
		for c in COPS:
			if not c.is_down():
				c.can_see = _sees(c)
				if c.can_see != null: seen = true
		for v in main.vehicles.VEH:
			if v.cop and v.cop.mode != "leave" and not v.cop.deployed and v.pos.distance_to(P.pos) < 55 and W.seg_clear(v.pos + Vector3(0, 1.5, 0), P.pos + Vector3(0, 1.2, 0)):
				seen = true
		if seen and level > 0:
			last = P.pos; seen_t = 0
	seen_t += dt
	if level > 0 and seen_t > 12:
		decay_t += dt * main.gang.lookout_boost()
		if decay_t > 8:
			decay_t = 0; level -= 1; pts = STEPS[level - 1] if level > 0 else 0
			if level == 0:
				clear(); main.hud.toast("You lost the police")
	else:
		decay_t = 0
	spawn_t -= dt
	var want = [0, 1, 2, 2, 3, 4][level]
	var active = 0
	for v in main.vehicles.VEH:
		if v.cop and v.cop.mode != "leave": active += 1
	if active < want and spawn_t <= 0:
		spawn_t = 6; spawn_cruiser()
	if active > 0 and level > 0:
		siren_t -= dt
		if siren_t <= 0:
			siren_t = 4.0; main.sfx.play("siren_far", 0.35)
	var host = hostile or level >= 3
	var near = false
	for c in COPS.duplicate():
		var H = c.h
		if c.is_down():
			c.down_t += dt
			if H.is_ragdoll(): c.pos = H.ragdoll_center()
			else: H.translation = c.pos
			H.animate(dt, { "down": min(1.0, c.down_t / 0.5) })
			if c.down_t > 30: remove_cop(c)
			continue
		var d = c.pos.distance_to(P.pos)
		if d < 9: near = true
		var goal = null
		var spd = 0.0
		var aim = 0.0
		if level == 0:
			if c.car and not c.car.dead:
				goal = c.car.pos
				spd = 3.5
			if c.car == null or c.pos.distance_to(c.car.pos) < 2.5:
				remove_cop(c); continue
		elif host:
			aim = 1.0 if c.can_see != null else 0.4
			if c.can_see == null or d > 18:
				goal = P.pos
				spd = 4.6
			elif d < 6:
				goal = c.pos + (c.pos - P.pos).normalized() * 3
				spd = 2.0
			c.fire_cd -= dt
			if c.can_see != null and c.fire_cd <= 0:
				c.fire_cd = G.rand(0.6, 1.2); _shoot(c)
		else:
			aim = 0.6
			if d > 2.2:
				goal = P.pos
				spd = 4.4
		var vx = 0.0
		var vz = 0.0
		if goal != null:
			var g = Vector2(goal.x - c.pos.x, goal.z - c.pos.z)
			if g.length() > 0.3:
				g = g.normalized() * spd
				vx = g.x
				vz = g.y
		var k = 1 - exp(-dt * 8)
		c.vel.x += (vx - c.vel.x) * k; c.vel.z += (vz - c.vel.z) * k
		W.move_body(c, c.vel.x * dt, c.vel.z * dt, dt)
		c.yaw += G.ang_diff(c.yaw, atan2(P.pos.x - c.pos.x, P.pos.z - c.pos.z)) * (1 - exp(-dt * 8))
		H.translation = c.pos; H.rotation = Vector3(0, c.yaw, 0)
		H.animate(dt, { "speed": Vector2(c.vel.x, c.vel.z).length(), "aim": aim, "pitch": 0.0 })
	# a calm arrest: stand still near an officer while the level is low
	if near and not host and level > 0 and not P.car and not P.dead:
		bust_t += dt
		P.hands_up = 0.3
		if bust_t > 3.2: _busted()
	else:
		bust_t = max(0, bust_t - dt)

func _busted():
	var P = main.player
	bust_t = 0
	if G.MODE != "play": return
	G.S["stats"]["busted"] = G.S["stats"].get("busted", 0) + 1
	main.cutscene.play(main.cutscene.cut_busted(), self, "_after_bust")

func _after_bust():
	var P = main.player
	var fine = round(min(G.S["cash"], 150 + level * 120))
	G.S["cash"] -= fine
	clear()
	var st = G.D["LOC"]["station"]
	P.place(st.x, 0, st.z + 6, PI)
	main.hud.banner("Busted", "Fine " + G.fmt_money(fine))
	G.save_game()
