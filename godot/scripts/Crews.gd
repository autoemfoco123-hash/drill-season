extends Node
# The rival Halo crew: they come for you when your Heat is up, square up in a standoff
# you can walk away from, and fight if you aim at them or get too close. From 75_enemies.js.

var main
var ENEMIES = []
var CREWS = []
var ambush_t = 90.0
var walk_hold = 0.0
const HANDLES = ["@halo.dre", "@halo_kj", "@halo.moe", "@halo.tay", "@halo_bigs", "@halo.nunu", "@halo_lex", "@halo.zay", "@halo_ock", "@halo.rell", "@halo.sosa", "@halo_trey"]
const STANDOFF = ["You lost?", "Wrong block.", "@saint.halo said you been talking.", "Keep walking or don't.", "Ain't nothing for you out here.", "Heard the track. Say it again."]
const SAINT_STANDOFF = ["Look who it is. The rapper.", "Say my name again. Go ahead.", "Calder Ave ain't yours.", "You made a song. I made this block."]
const WALK = ["Yeah, keep walking.", "Smart.", "Next time.", "That's what I thought."]

class Enemy:
	var main
	var h
	var gun
	var type = "runner"
	var T = {}
	var crew
	var name = ""
	var pos = Vector3()
	var vel = Vector3()
	var radius = 0.36
	var height = 1.75
	var on_ground = true
	var air_y = 0.0
	var yaw = 0.0
	var hp = 60.0
	var state = "alive"
	var fire_cd = 1.0
	var burst = 0
	var can_see = null
	var see_t = 0.0
	var los_t = 0.0
	var strafe = 1
	var strafe_t = 1.0
	var knock_t = 0.0
	var down_t = 0.0
	var crouched = false
	var leave_to = null
	func is_down(): return state == "down"
	func take_hit(dmg, head, dir, by_player, melee):
		main.crews.damage(self, dmg, head, dir, melee)
		if melee and randf() < 0.3: knock_t = 0.9

func setup(m):
	main = m

func clear():
	for e in ENEMIES:
		if is_instance_valid(e.h): e.h.queue_free()
	ENEMIES.clear(); CREWS.clear()

func spawn_crew(at, n, shooters, o = {}):
	var c = { "members": [], "state": "approach", "t": 0.0, "so": 0.0, "aim_hold": 0.0, "fought": false, "over": false, "leave_t": 0.0, "saint": o.get("saint", false), "challenge": o.get("challenge", false),
		"turf": int(o.get("turf", -1)), "look": o.get("look"), "handles": o.get("handles"), "lines": o.get("lines", STANDOFF), "col": o.get("col", Color(1, 0.28, 0.22)), "said": false }
	# turf crews (Turf.gd): people standing on a corner, or a wave coming for you
	if o.get("guard", false): c.state = "guard"
	elif o.get("combat", false):
		c.state = "combat"; c.fought = true
	CREWS.append(c)
	var types = []
	if c.saint: types.append("saint")
	for i in range(n): types.append("shooter" if i < shooters else "runner")
	for i in range(types.size()):
		var type = types[i]
		var p = at
		for _k in range(12):
			var a = G.rand(0, TAU)
			var r = 0.0 if i == 0 else G.rand(1.5, 3.5)
			p = at + Vector3(cos(a) * r, 0, sin(a) * r)
			if not W.is_blocked(p.x, p.z): break
		_spawn(type, p, c)
	return c

func _spawn(type, p, crew):
	var e = Enemy.new()
	e.main = main; e.type = type; e.T = G.D["ETYPES"][type]; e.crew = crew; e.pos = p; e.hp = float(e.T.hp)
	e.name = G.D["CAST"]["saint"].name if type == "saint" else G.pick(HANDLES); e.fire_cd = G.rand(0.6, 1.2); e.strafe = 1 if randf() < 0.5 else -1
	var lk = crew.get("look")
	if typeof(lk) != TYPE_ARRAY or lk.size() < 3: lk = [e.T.jacket, e.T.jacket2, 0x8a1c24]
	if typeof(crew.get("handles")) == TYPE_ARRAY and type != "saint": e.name = G.pick(crew.handles)
	e.h = load("res://scripts/Human.gd").new().build({ "jacket": lk[0], "jacket2": lk[1], "pants": 0x18191c, "skin": G.pick([0x5a3a26, 0x7a4a30, 0x4a2e1e, 0x8a5a3a, 0x6b4630]), "hat": lk[2], "chain": type == "saint", "head": "hood" if type == "runner" else ("none" if type == "saint" else "beanie"), "hair": "braids" if type == "saint" else "none", "mask": 0x111214 if randf() < 0.6 and type != "saint" else null })
	main.add_child(e.h)
	e.gun = GUN.build(e.T.gun, GUN.def_cfg())
	e.gun.rotation = Vector3(PI / 2, 0, 0); e.gun.translation = Vector3(0, -0.03, 0.02); e.gun.scale = Vector3.ONE * 1.35
	e.h.gun_slot.add_child(e.gun)
	e.yaw = atan2(main.player.pos.x - p.x, main.player.pos.z - p.z)
	ENEMIES.append(e); crew.members.append(e)
	return e

func leader(c):
	for e in c.members:
		if e.type == "saint" and not e.is_down(): return e
	for e in c.members:
		if not e.is_down(): return e
	return null

func engage(c, why = ""):
	if c.state == "combat" or c.over: return
	if c.get("turf", -1) >= 0:
		c.state = "combat"; c.fought = true
		var TL = leader(c)
		if TL: main.hud.say(TL.name, G.pick(["Wrong corner.", "Now you did it.", "Get him.", "On sight."]))
		main.story.add_heat(2)
		main.story.on_crew_engaged()
		return
	var was = c.state == "standoff"
	c.state = "combat"; c.fought = true
	var L = leader(c)
	if L: main.hud.say(L.name, G.pick(["Your Heat talks for you.", "No talking tonight."] if why == "skip" else ["Bad move.", "Here we go.", "Now you did it."]))
	main.story.add_heat(5)
	main.story.on_crew_engaged()
	if why == "skip": main.hud.banner("No standoff", "Your Heat is too high to talk")
	elif was: main.hud.banner("Fight", "")

func damage(e, dmg, head, dir, melee):
	if e.is_down(): return
	e.hp -= dmg
	if not melee: main.sfx.blood(e.pos + Vector3(0, 1.6 if head else 1.15, 0), dir)
	if e.crew.state != "combat":
		# hit while walking their street or standing on their corner: an ambush
		if main.offense and (e.crew.state == "patrol" or (e.crew.state == "guard" and not crew_noticed(e.crew))): main.offense.first_strike(e.crew)
		engage(e.crew, "shot")
	e.see_t = max(e.see_t, 0.3)
	if e.hp <= 0:
		e.state = "down"; e.down_t = 0
		e.h.ragdoll_start(Vector3(e.vel.x, 0, e.vel.z) * 0.5, Vector3(dir.x, 0, dir.z) * (3.2 if melee else 2.2) + Vector3(0, 1.0, 0), G.rand(-1, 1))
		main.sfx.play3d("bodyfall", e.pos, 0.8)
		if e.type == "saint": main.story.on_saint_down()
		G.S["stats"]["downs"] = G.S["stats"].get("downs", 0) + 1
		G.S["heat"] = min(100, G.S["heat"] + (1 if e.crew.get("turf", -1) >= 0 else 3))

# a takedown from behind: down without a sound. The rest of the crew finds out only if they see it
func silent_down(e, dir):
	if e.is_down(): return false
	e.hp = 0.0; e.state = "down"; e.down_t = 0
	e.h.ragdoll_start(Vector3(), dir * 1.4 + Vector3(0, 0.4, 0), G.rand(-0.5, 0.5))
	main.sfx.play3d("bodyfall", e.pos, 0.45)
	G.S["stats"]["downs"] = G.S["stats"].get("downs", 0) + 1
	var c = e.crew
	c["silent"] = true
	var seen = false
	for o in c.members:
		if o == e or o.is_down(): continue
		var dv = e.pos - o.pos
		var d = dv.length()
		if d > 20: continue
		if not W.seg_clear(o.pos + Vector3(0, 1.5, 0), e.pos + Vector3(0, 0.9, 0)): continue
		if d < 3.5 or Vector3(sin(o.yaw), 0, cos(o.yaw)).dot(dv / max(d, 0.01)) > 0.2: seen = true
	if seen and c.state != "combat":
		if c.state in ["patrol", "guard"] and main.offense: main.offense.first_strike(c)
		engage(c, "shot")
	return seen

func on_player_shot(at):
	for c in CREWS:
		if c.state == "approach" or c.state == "standoff" or c.state == "guard" or c.state == "patrol":
			for e in c.members:
				if e.pos.distance_to(at) < 65:
					engage(c, "shot")
					break

func crew_noticed(c):
	var P = main.player
	for o in c.members:
		if not o.is_down() and noticed(o, o.pos.distance_to(P.pos)): return true
	return false

# has this one clocked you? In front of them and close enough (a lot closer if you're low and
# not aiming), or right on top of them
func noticed(e, d):
	var P = main.player
	if P.dead or e.can_see == null: return false
	if d < 1.2: return true
	if d > (6.0 if (P.crouch and not P.aiming) else 14.0): return false
	var to = Vector3(P.pos.x - e.pos.x, 0, P.pos.z - e.pos.z)
	return Vector3(sin(e.yaw), 0, cos(e.yaw)).dot(to.normalized()) > -0.25

func _sees(e):
	var P = main.player
	if P.dead: return null
	var eye = e.pos + Vector3(0, 1.0 if e.crouched else 1.55, 0)
	if P.car:
		var cp = P.car.pos + Vector3(0, 1, 0)
		return cp if W.seg_clear(eye, cp) else null
	for t in P.targets():
		if W.seg_clear(eye, t): return t
	return null

func _shoot(e):
	if main.gang.divert_shot(e): return
	var P = main.player
	var tp = e.can_see
	if tp == null: return
	var mz = e.h.gun_slot.global_transform.origin
	var d = e.pos.distance_to(P.pos)
	var p = float(e.T.acc) * clamp(1.25 - d / 38.0, 0.25, 1.05)
	if P.crouch and not P.aiming: p *= 0.6
	if P.speed > 3.5: p *= 0.65
	var hit = randf() < p
	var end = tp if hit else tp + Vector3(G.rand(-1.3, 1.3), G.rand(-0.6, 0.9), G.rand(-1.3, 1.3))
	main.sfx.tracer(mz, end)
	main.sfx.shot(e.T.gun, mz, 0.8)
	main.peds.alert(e.pos, 40)
	if hit:
		if P.car:
			P.car.hp -= 3
			if randf() < 0.35: P.hurt(float(e.T.dmg) * 0.6, e.pos)
		else:
			P.hurt(float(e.T.dmg), e.pos)

func update(dt):
	var P = main.player
	# ambush director: more Heat, more often, bigger crews
	var busy = false
	for c in CREWS:
		if c.state != "leave" and c.state != "guard": busy = true
	if not busy:
		if G.S["heat"] < 30 or G.S.get("playTime", 0) < 40:
			ambush_t = max(ambush_t, 20)
		else:
			ambush_t -= dt
			if ambush_t <= 0:
				ambush_t = G.rand(40, 65) if G.S["heat"] >= 75 else (G.rand(70, 105) if G.S["heat"] >= 50 else G.rand(110, 160))
				var sp = _spawn_point(42, 75)
				if sp != null:
					var n = 4 if G.S["heat"] >= 75 else (3 if G.S["heat"] >= 50 else 2)
					spawn_crew(sp, n, 2 if G.S["heat"] >= 75 else (1 if G.S["heat"] >= 50 else 0))
				else:
					ambush_t = 8
	# crews
	for c in CREWS.duplicate():
		var alive = []
		for e in c.members:
			if not e.is_down(): alive.append(e)
		if alive.size() == 0:
			if not c.over:
				c.over = true
				if (c.get("ambushed", false) or c.get("silent", false)) and main.offense: main.offense.ambush_paid(c)
				if c.fought and c.get("turf", -1) >= 0:
					main.gang.rep(2)
				elif c.fought:
					main.story.add_heat(4)
					if not c.saint or not G.S["flags"].get("saintDown", false): main.hud.banner("Fight over", "Heat +4")
					main.gang.rep(3)
					main.story.on_crew_defeated(c)
		var dmin = INF
		for e in alive: dmin = min(dmin, e.pos.distance_to(P.pos))
		c.t += dt
		if c.state == "approach":
			if dmin < 18: _standoff(c, alive)
			if c.t > 100: c.state = "leave"
		elif c.state == "standoff":
			c.so += dt
			c.aim_hold = c.aim_hold + dt if P.aiming else max(0, c.aim_hold - dt * 2)
			if c.aim_hold > 0.35 or dmin < 5.2 or c.so > 20: engage(c, "aim")
			elif dmin > 42: _walk_away(c)
		elif c.state == "guard":
			# standing on their corner: a word when you walk up, a fight if you pull on them
			var nb = null
			for e in alive:
				if noticed(e, e.pos.distance_to(P.pos)): nb = e
			c.aim_hold = c.aim_hold + dt if P.aiming and dmin < 32 and nb != null else max(0, c.aim_hold - dt * 2)
			if nb != null and dmin < 13 and not c.said and not P.dead:
				c.said = true
				main.hud.say(nb.name, G.pick(c.lines))
			if c.aim_hold > 0.8: engage(c, "aim")
			if alive.size() == 0: c.state = "leave"
		elif c.state == "patrol":
			# walking their street: they notice you up close (less if you're low), or turn round at the end
			for e in alive:
				if noticed(e, e.pos.distance_to(P.pos)):
					c.state = "approach"; c.t = 0.0
					main.hud.say(e.name, G.pick(["Who's that?", "Yo. You lost?", "Hold up."]))
					break
			if c.state == "patrol" and c.ri >= c.route.size():
				c.state = "leave"; c.leave_t = 0
				for e in c.members: e.leave_to = c.route[-1]
			if alive.size() == 0: c.state = "leave"
		elif c.state == "combat":
			if dmin > 95 or P.dead:
				c.state = "leave"
				c.leave_t = 0
		elif c.state == "leave":
			c.leave_t += dt
			if dmin > 70 or c.leave_t > 25:
				# the ones still standing go; the ones down stay where they fell for a while
				for e in c.members:
					if e.is_down(): continue
					if is_instance_valid(e.h): e.h.queue_free()
					ENEMIES.erase(e)
				CREWS.erase(c)
	# hold E to walk away from a standoff
	var so = active_standoff()
	if so and Input.is_action_pressed("use") and G.MODE == "play" and not P.car:
		walk_hold += dt
		if walk_hold >= 1.4:
			walk_hold = 0; _walk_away(so)
	else:
		walk_hold = max(0, walk_hold - dt * 2)
	for e in ENEMIES.duplicate():
		if e.crew.state == "leave" and not is_instance_valid(e.h): continue
		_update_enemy(e, dt)

func active_standoff():
	for c in CREWS:
		if c.state == "standoff": return c
	return null

func _standoff(c, alive):
	if G.S["heat"] >= 75 and not c.saint:
		engage(c, "skip"); return
	c.state = "standoff"; c.so = 0
	var L = leader(c)
	main.hud.say(L.name, G.pick(SAINT_STANDOFF if L.type == "saint" else STANDOFF))
	main.player.shake = max(main.player.shake, 0.2)
	if c.challenge and L.type == "saint": main.cutscene.play(main.cutscene.cut_saint(L))

func _walk_away(c):
	if c.state != "standoff": return
	c.state = "leave"; c.leave_t = 0
	var P = main.player
	for e in c.members:
		var a = atan2(e.pos.x - P.pos.x, e.pos.z - P.pos.z)
		e.leave_to = Vector3(clamp(e.pos.x + sin(a) * 60, -W.BOUND + 7, W.BOUND - 7), 0, clamp(e.pos.z + cos(a) * 60, -W.BOUND + 7, W.BOUND - 7))
	var L = leader(c)
	if L: main.hud.say(L.name, "That's what you do. Walk." if L.type == "saint" else G.pick(WALK))
	var dh = -12 if c.saint else -9
	main.story.add_heat(dh)
	main.hud.banner("Walked away", "Heat %d" % dh)
	main.sfx.play("whoosh", 0.4)
	main.story.on_walk_away(c)

# a turf crew that lost (or won): they walk off
func send_home(c):
	if c.state == "leave": return
	c.state = "leave"; c.leave_t = 0
	var P = main.player
	for e in c.members:
		var a = atan2(e.pos.x - P.pos.x, e.pos.z - P.pos.z)
		e.leave_to = Vector3(clamp(e.pos.x + sin(a) * 60, -W.BOUND + 7, W.BOUND - 7), 0, clamp(e.pos.z + cos(a) * 60, -W.BOUND + 7, W.BOUND - 7))

# gone at once (people on a corner you walked away from)
func despawn(c):
	for e in c.members:
		if is_instance_valid(e.h): e.h.queue_free()
		ENEMIES.erase(e)
	CREWS.erase(c)

func _spawn_point(min_d, max_d):
	var P = main.player
	for i in range(50):
		var x
		var z
		if randf() < 0.5:
			x = G.pick(G.D["XL"]) + G.rand(-3, 3); z = P.pos.z + G.rand(-max_d, max_d)
		else:
			z = G.pick(G.D["ZL"]) + G.rand(-3, 3); x = P.pos.x + G.rand(-max_d, max_d)
		if abs(x) > W.BOUND - 7 or abs(z) > W.BOUND - 7 or x > G.D["SHORE_X"] + 8: continue
		var d = Vector2(x - P.pos.x, z - P.pos.z).length()
		if d < min_d or d > max_d or W.is_blocked(x, z): continue
		if i < 35 and W.seg_clear(P.pos + Vector3(0, 1.5, 0), Vector3(x, 1.5, z)): continue
		return Vector3(x, 0, z)
	return null

func _update_enemy(e, dt):
	var P = main.player
	var H = e.h
	if e.is_down():
		e.down_t += dt
		e.vel *= exp(-dt * 3)
		if H.is_ragdoll(): e.pos = H.ragdoll_center()
		else:
			if e.vel.length() > 0.1: W.move_body(e, e.vel.x * dt, e.vel.z * dt, dt)
			H.translation = e.pos
		H.animate(dt, { "down": min(1.0, e.down_t / 0.55) })
		e.gun.visible = false
		if e.down_t > 26:
			if is_instance_valid(H): H.queue_free()
			ENEMIES.erase(e)
		return
	if e.knock_t > 0:
		e.knock_t -= dt; e.vel *= exp(-dt * 2)
		W.move_body(e, e.vel.x * dt, e.vel.z * dt, dt)
		H.translation = e.pos
		H.animate(dt, { "down": min(1.0, e.knock_t * 1.5) })
		return
	var c = e.crew
	var dv = P.pos - e.pos
	var d = Vector2(dv.x, dv.z).length()
	e.los_t -= dt
	if e.los_t <= 0:
		e.los_t = 0.16 + randf() * 0.12; e.can_see = _sees(e)
	e.see_t = e.see_t + dt if e.can_see != null else max(0, e.see_t - dt * 2)
	var goal = null
	var spd = 0.0
	var aim = 0.0
	var face = atan2(dv.x, dv.z)
	var strafe = 0
	if c.state == "guard":
		# on their corner: they turn to you once they've clocked you (sneak up low from behind)
		if not noticed(e, d): face = null
	elif c.state == "patrol":
		face = null
		if c.ri < c.route.size():
			var wp = c.route[c.ri]
			var k = c.members.find(e)
			goal = wp + Vector3((k % 2) * 1.3 - 0.65, 0, (k / 2) * 1.3)
			spd = 1.6
			var L = leader(c)
			if L == e and Vector2(wp.x - e.pos.x, wp.z - e.pos.z).length() < 4.0: c.ri += 1
	elif c.state == "approach":
		goal = P.pos; spd = float(e.T.speed) * 0.75
	elif c.state == "standoff":
		aim = 0.35
		if d > 15:
			goal = P.pos
			spd = 2.0
		elif d < 8.5:
			goal = e.pos - dv.normalized() * 3
			spd = 1.2
	elif c.state == "combat":
		aim = 1.0 if e.can_see != null else 0.6
		var far = 13.0 if e.type == "runner" else 17.0
		var close = 5.0 if e.type == "runner" else 11.0
		if e.can_see == null or d > far:
			goal = P.pos
			spd = float(e.T.speed)
		elif d < close:
			goal = e.pos - dv
			spd = 2.0
		else:
			e.strafe_t -= dt
			if e.strafe_t <= 0:
				e.strafe_t = G.rand(0.9, 2)
				e.strafe *= -1
			strafe = e.strafe; spd = 2.6
		e.fire_cd -= dt
		if e.can_see != null and e.see_t > 0.35 and e.fire_cd <= 0:
			_shoot(e)
			if e.burst > 0:
				e.burst -= 1; e.fire_cd = float(e.T.rate) if e.burst > 0 else G.rand(0.9, 1.5)
			else:
				e.burst = int(e.T.burst) - 1; e.fire_cd = float(e.T.rate) if e.burst > 0 else G.rand(0.55, 1.05)
	elif c.state == "leave":
		if e.leave_to != null:
			goal = e.leave_to
			spd = 3.2
			face = null
	var vx = 0.0
	var vz = 0.0
	if goal != null:
		var g = Vector2(goal.x - e.pos.x, goal.z - e.pos.z)
		if g.length() > 0.3:
			g = g.normalized() * spd
			vx = g.x
			vz = g.y
	if strafe != 0 and d > 0.1:
		vx += -dv.z / d * strafe * spd; vz += dv.x / d * strafe * spd
	for o in ENEMIES:
		if o == e or o.is_down(): continue
		var od = Vector2(e.pos.x - o.pos.x, e.pos.z - o.pos.z)
		var ol = od.length()
		if ol < 1.3 and ol > 0.01:
			vx += od.x / ol * 2
			vz += od.y / ol * 2
	var k = 1 - exp(-dt * 8)
	e.vel.x += (vx - e.vel.x) * k; e.vel.z += (vz - e.vel.z) * k
	W.move_body(e, e.vel.x * dt, e.vel.z * dt, dt)
	var sp = Vector2(e.vel.x, e.vel.z).length()
	if face == null and sp > 0.5: face = atan2(e.vel.x, e.vel.z)
	if face != null: e.yaw += G.ang_diff(e.yaw, face) * (1 - exp(-dt * 9))
	H.translation = e.pos; H.rotation = Vector3(0, e.yaw, 0)
	var pitch = atan2((P.pos.y + 1.2) - (e.pos.y + 1.4), max(1.0, d))
	H.animate(dt, { "speed": sp, "aim": aim, "pitch": pitch, "twoHand": e.T.gun != "k9" })
