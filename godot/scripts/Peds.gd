extends Node
# People on the sidewalks: walk the block corners, wait at the lights, flee gunfire,
# get punched or knocked out, sometimes swing back. Ported from 55_peds.js and the fists code.

var main
var PEDS = []
var N_PEDS = 8
var _spawn_t = 0.0
const SW = 8.0
const LINES = ["Same to you!", "Real mature.", "Keep it moving!", "Who you flipping?", "Get outta here.", "Wow. Okay.", "Love you too."]
const BRAWL_LINES = ["Oh, you want smoke?", "Bad idea.", "Run it then.", "You're done.", "Wrong one.", "Say less."]

class Ped:
	var main
	var h
	var pos = Vector3()
	var vel = Vector3()
	var radius = 0.3
	var height = 1.7
	var on_ground = true
	var air_y = 0.0
	var yaw = 0.0
	var state = "walk"
	var node = null
	var prev = null
	var target = null
	var speed = 1.3
	var flee_t = 0.0
	var from = Vector3()
	var down_t = 0.0
	var hp = 40.0
	var idle_t = 0.0
	var stuck_t = 0.0
	var last = Vector3()
	var temp = false
	var ko = false
	var tough = -1
	var brawl_t = 0.0
	var atk_cd = 0.5
	var punch_t = 0.0
	var punch_side = 1
	var hit_t = 0.0
	var flip_delay = 0.0
	var flip_back_t = 0.0
	var flip_say = false
	var rq = null
	var rq_seed = 0
	var rq_name = ""
	var plate = null
	var crouched = false
	var emote = ""
	var emote_t = 0.0
	var emote_left = 0.0
	func is_down(): return state == "down"
	func take_hit(dmg, head, dir, by_player, melee):
		if melee: main.peds.punched(self, dmg, dir, by_player)
		else: main.peds.shot(self, dmg, dir, by_player)

func setup(m):
	main = m

func corner(ix, iz, sx, sz):
	return Vector3(G.D["XL"][ix] + SW * sx, 0, G.D["ZL"][iz] + SW * sz)

func corner_next(c, prev):
	var XL = G.D["XL"]
	var ZL = G.D["ZL"]
	var opts = [{ "ix": c.ix, "iz": c.iz, "sx": -c.sx, "sz": c.sz, "cross": true }, { "ix": c.ix, "iz": c.iz, "sx": c.sx, "sz": -c.sz, "cross": true }]
	if c.ix + c.sx >= 0 and c.ix + c.sx < XL.size(): opts.append({ "ix": c.ix + c.sx, "iz": c.iz, "sx": -c.sx, "sz": c.sz, "cross": false })
	if c.iz + c.sz >= 0 and c.iz + c.sz < ZL.size(): opts.append({ "ix": c.ix, "iz": c.iz + c.sz, "sx": c.sx, "sz": -c.sz, "cross": false })
	var non = []
	for o in opts:
		if prev == null or not (o.ix == prev.ix and o.iz == prev.iz and o.sx == prev.sx and o.sz == prev.sz): non.append(o)
	var walks = []
	for o in non:
		if not o.cross: walks.append(o)
	if walks.size() > 0 and randf() < 0.75: return G.pick(walks)
	return G.pick(non if non.size() > 0 else opts)

func make(x, z, opts = null):
	var p = Ped.new()
	p.main = main
	var look = opts
	if look == null:
		var gl = main.gang.tag_ped(p)
		look = gl if gl != null else G.skin_opts(G.random_skin())
	p.h = load("res://scripts/Human.gd").new().build(look)
	main.add_child(p.h)
	p.pos = Vector3(x, 0, z); p.yaw = G.rand(0, TAU); p.speed = G.rand(1.15, 1.6)
	p.h.translation = p.pos
	PEDS.append(p)
	return p

func place_on_graph(p, near, min_d, max_d):
	var XL = G.D["XL"]
	var ZL = G.D["ZL"]
	for k in range(40):
		var c = { "ix": randi() % XL.size(), "iz": randi() % ZL.size(), "sx": -1 if randf() < 0.5 else 1, "sz": -1 if randf() < 0.5 else 1 }
		var n = corner_next(c, null)
		var a = corner(c.ix, c.iz, c.sx, c.sz)
		var b = corner(n.ix, n.iz, n.sx, n.sz)
		var t = randf()
		var x = lerp(a.x, b.x, t)
		var z = lerp(a.z, b.z, t)
		var d = Vector2(x - near.x, z - near.z).length()
		if d < min_d or d > max_d or W.is_blocked(x, z, 0.4): continue
		p.pos = Vector3(x, 0, z); p.vel = Vector3(); p.node = n; p.prev = c; p.target = b; p.state = "walk"; p.hp = 40; p.down_t = 0
		if p.h.is_ragdoll(): p.h.ragdoll_stop()
		p.h.getup = 0.0; p.emote_left = 0
		p.h.visible = true
		return true
	return false

func remove(p):
	PEDS.erase(p)
	if is_instance_valid(p.h): p.h.queue_free()

func spawn_fleeing(at):
	var p = make(at.x, at.z)
	p.state = "flee"; p.flee_t = 9; p.from = main.player.pos; p.temp = true
	return p

func alert(at, r):
	for p in PEDS:
		if p.state != "down" and p.state != "brawl" and Vector2(p.pos.x - at.x, p.pos.z - at.z).length() < r:
			p.state = "flee"; p.flee_t = G.rand(7, 11); p.from = at

func shot(p, dmg, dir, by_player):
	if p.state == "down": return
	p.hp -= dmg
	main.sfx.blood(p.pos + Vector3(0, 1.2, 0), dir)
	if p.hp <= 0:
		p.state = "down"; p.down_t = 0
		var fling = p.vel.length() > 5
		p.h.ragdoll_start(Vector3(p.vel.x, 0, p.vel.z) * 0.4, Vector3(dir.x, 0, dir.z) * G.rand(1.5, 3) + p.vel * 0.7 + Vector3(0, 3.5 if fling else 0.6, 0), G.rand(-2, 2) if fling else 0.0)
		main.sfx.play3d("bodyfall", p.pos, 0.8)
		if by_player:
			main.police.add_wanted(22, p.pos); G.S["heat"] = min(100, G.S["heat"] + 5)
	else:
		p.state = "flee"; p.flee_t = 10; p.from = p.pos - dir
		if by_player: main.police.add_wanted(10, p.pos)
	alert(p.pos, 30)

func punched(p, dmg, dir, by_player):
	if p.state == "down": return
	p.hp -= dmg
	if p.hp <= 0:
		p.state = "down"; p.down_t = 0; p.ko = true
		p.h.ragdoll_start(Vector3(), Vector3(dir.x, 0, dir.z) * 3.2 + Vector3(0, 1.2, 0), G.rand(-1, 1))
		main.sfx.play3d("bodyfall", p.pos, 0.8)
		if by_player:
			main.police.add_wanted(14, p.pos); G.S["heat"] = min(100, G.S["heat"] + 2)
			G.S["stats"]["knockouts"] = G.S["stats"].get("knockouts", 0) + 1
		return
	if by_player: main.police.add_wanted(5, p.pos)
	if p.state != "brawl":
		if p.tough < 0: p.tough = 1 if randf() < 0.4 else 0
		if p.tough == 1:
			p.state = "brawl"; p.brawl_t = 14; p.atk_cd = 0.5
			if by_player: main.hud.say("Passerby", G.pick(BRAWL_LINES))
		else:
			p.state = "flee"; p.flee_t = 9; p.from = main.player.pos
	else:
		p.brawl_t = max(p.brawl_t, 8)
	for o in PEDS:
		if o != p and o.state == "walk" and o.pos.distance_to(p.pos) < 7:
			o.state = "flee"; o.flee_t = 6; o.from = p.pos

# the closest people turn round when you put your finger up
func flip_react(at):
	var near = []
	for p in PEDS:
		if p.state == "walk" and p.flip_back_t <= 0 and p.pos.distance_to(at) < 15: near.append(p)
	near.sort_custom(self, "_by_dist")
	for i in range(min(2, near.size())):
		var p = near[i]
		p.flip_delay = 0.45 + i * 0.5 + randf() * 0.3; p.flip_back_t = 2.4; p.flip_say = i == 0 and randf() < 0.75
func _by_dist(a, b):
	return a.pos.distance_to(main.player.pos) < b.pos.distance_to(main.player.pos)

# people keep their personal space: nobody walks through anybody (you, people on the street,
# police, rival crews and your own gang push each other apart; you get pushed the least)
func _crowd():
	var P = main.player
	var B = []
	if G.MODE != "title" and not P.car and not P.is_ragdoll(): B.append(P)
	for list in [PEDS, main.crews.ENEMIES, main.police.COPS, main.gang.FOL]:
		for p in list:
			if p.state == "down" or (p.h and p.h.is_ragdoll()): continue
			if list == main.gang.FOL and p.riding: continue
			if abs(p.pos.x - P.pos.x) > 30 or abs(p.pos.z - P.pos.z) > 30: continue
			B.append(p)
	for i in range(B.size()):
		var a = B[i]
		for j in range(i + 1, B.size()):
			var b = B[j]
			var dx = b.pos.x - a.pos.x
			var dz = b.pos.z - a.pos.z
			var r = a.radius + b.radius
			var d2 = dx * dx + dz * dz
			if d2 >= r * r or d2 < 1e-6 or abs(a.pos.y - b.pos.y) > 1.2: continue
			var d = sqrt(d2)
			var pen = r - d
			var ka = 0.3 if a == P else 0.5
			var kb = 0.3 if b == P else 0.5
			var t = ka + kb
			a.pos.x -= dx / d * pen * ka / t; a.pos.z -= dz / d * pen * ka / t
			b.pos.x += dx / d * pen * kb / t; b.pos.z += dz / d * pen * kb / t

func update(dt):
	_crowd()
	var P = main.player
	var focus = P.pos if G.MODE != "title" else main.title.spot
	_spawn_t -= dt
	if _spawn_t <= 0:
		_spawn_t = 1.0
		var n = 0
		for p in PEDS:
			if not p.temp: n += 1
		if n < N_PEDS:
			var p = make(0, 0)
			if not place_on_graph(p, focus, 25, 95): remove(p)
	for p in PEDS.duplicate():
		var H = p.h
		var dP = Vector2(p.pos.x - focus.x, p.pos.z - focus.z).length()
		if p.state == "down":
			p.down_t += dt
			p.vel *= exp(-dt * 3)
			if H.is_ragdoll():
				p.pos = H.ragdoll_center()
			elif p.vel.length() > 0.1: W.move_body(p, p.vel.x * dt, p.vel.z * dt, dt)
			if not H.is_ragdoll(): H.translation = p.pos
			H.visible = dP < 80
			if H.visible: H.animate(dt, { "down": min(1.0, p.down_t / 0.5) })
			if p.ko and p.down_t > 11 and G.MODE == "play":
				p.ko = false; p.state = "flee"; p.flee_t = 8; p.hp = 25; p.from = P.pos
				if H.is_ragdoll():
					p.pos = H.ragdoll_stop(); p.yaw = H.rotation.y
				continue
			if p.down_t > 40:
				if p.temp or not place_on_graph(p, focus, 45, 95): remove(p)
			continue
		if dP > 100:
			if p.temp or not place_on_graph(p, focus, 45, 90): remove(p)
			continue
		var tgt = null
		var spd = 0.0
		var brawl = false
		if p.state == "brawl":
			brawl = _brawl(p, dt, dP)
			if brawl:
				if Vector2(P.pos.x - p.pos.x, P.pos.z - p.pos.z).length() > 1.05:
					tgt = P.pos
					spd = 4.6
		elif p.state == "flee":
			p.flee_t -= dt
			var aw = Vector3(p.pos.x - p.from.x, 0, p.pos.z - p.from.z)
			if aw.length() < 0.01: aw = Vector3(1, 0, 0)
			tgt = p.pos + aw.normalized() * 6; spd = 5.4
			if p.flee_t <= 0:
				p.state = "walk"
				var best = null
				var bd = INF
				for ix in range(G.D["XL"].size()):
					for iz in range(G.D["ZL"].size()):
						for sx in [-1, 1]:
							for sz in [-1, 1]:
								var c = corner(ix, iz, sx, sz)
								var d = c.distance_to(p.pos)
								if d < bd:
									bd = d
									best = { "ix": ix, "iz": iz, "sx": sx, "sz": sz }
				p.node = best; p.prev = null; p.target = corner(best.ix, best.iz, best.sx, best.sz)
		else:
			if p.idle_t > 0: p.idle_t -= dt
			elif p.target != null:
				tgt = p.target; spd = p.speed
				if Vector2(p.target.x - p.pos.x, p.target.z - p.pos.z).length() < 0.9:
					var n2 = corner_next(p.node, p.prev)
					if n2.cross:
						var axis = "z" if n2.sx != p.node.sx else "x"
						if main.vehicles.signal_state(n2.ix, n2.iz, axis) == "g" and randf() < 0.85: p.idle_t = G.rand(1.5, 4)
					elif randf() < 0.15: p.idle_t = G.rand(2, 6)
					p.prev = p.node; p.node = n2; p.target = corner(n2.ix, n2.iz, n2.sx, n2.sz)
			if P.aim_t > 0.6 and not P.car and dP < 12 and not G.S.get("fists", false):
				var to_p = atan2(p.pos.x - P.pos.x, p.pos.z - P.pos.z)
				if abs(G.ang_diff(P.cam_yaw + PI, to_p)) < 0.25:
					p.state = "flee"; p.flee_t = 8; p.from = P.pos
		var answering = false
		if p.emote_left > 0 and p.state == "walk":
			p.emote_left -= dt; p.emote_t += dt; tgt = null
			p.yaw += G.ang_diff(p.yaw, atan2(P.pos.x - p.pos.x, P.pos.z - p.pos.z)) * (1 - exp(-dt * 6))
			answering = true
		if p.state == "walk" and p.flip_back_t > 0:
			if p.flip_delay > 0: p.flip_delay -= dt
			else:
				answering = true; p.flip_back_t -= dt; tgt = null
				p.yaw += G.ang_diff(p.yaw, atan2(P.pos.x - p.pos.x, P.pos.z - p.pos.z)) * (1 - exp(-dt * 8))
				if p.flip_say:
					p.flip_say = false; main.hud.say("Passerby", G.pick(LINES))
		var vx = 0.0
		var vz = 0.0
		if tgt != null:
			var dv = Vector2(tgt.x - p.pos.x, tgt.z - p.pos.z)
			if dv.length() > 0.05:
				dv = dv.normalized() * spd
				vx = dv.x
				vz = dv.y
		for o in PEDS:
			if o == p or o.state == "down": continue
			var od = Vector2(p.pos.x - o.pos.x, p.pos.z - o.pos.z)
			var ol = od.length()
			if ol < 0.8 and ol > 0.01:
				vx += od.x / ol * 1.2
				vz += od.y / ol * 1.2
		var k = 1 - exp(-dt * 6)
		p.vel.x += (vx - p.vel.x) * k; p.vel.z += (vz - p.vel.z) * k
		W.move_body(p, p.vel.x * dt, p.vel.z * dt, dt)
		p.stuck_t += dt
		if p.stuck_t > 2:
			if spd > 0.5 and p.pos.distance_to(p.last) < 0.4 and p.state == "walk" and p.node != null:
				var n3 = corner_next(p.node, null)
				p.prev = p.node; p.node = n3; p.target = corner(n3.ix, n3.iz, n3.sx, n3.sz)
			p.stuck_t = 0; p.last = p.pos
		var sp = Vector2(p.vel.x, p.vel.z).length()
		if brawl:
			p.yaw += G.ang_diff(p.yaw, atan2(P.pos.x - p.pos.x, P.pos.z - p.pos.z)) * (1 - exp(-dt * 10))
		elif sp > 0.2 and not answering:
			p.yaw += G.ang_diff(p.yaw, atan2(p.vel.x, p.vel.z)) * (1 - exp(-dt * 8))
		H.translation = p.pos; H.rotation = Vector3(0, p.yaw, 0)
		if dP < 70:
			H.visible = true
			var em = p.emote if p.emote_left > 0 else ""
			H.animate(dt, { "speed": sp, "crouch": p.state == "flee" and sp < 0.6, "mug": p.state == "walk" and not answering and fmod(G.REAL_T + p.rq_seed % 20, 20) < 6, "flip": answering and em == "" and p.flip_back_t > 0, "fists": brawl, "guard": brawl, "punch": p.punch_t / 0.3 if brawl and p.punch_t > 0 else 0.0, "punchSide": p.punch_side, "emote": em, "et": p.emote_t })
		else:
			H.visible = false
		main.gang.update_recruit_plate(p)

# a pedestrian who swings back
func _brawl(p, dt, dP):
	var P = main.player
	p.brawl_t -= dt
	if p.brawl_t <= 0 or dP > 18 or P.dead or P.car or G.MODE != "play":
		p.state = "flee"; p.flee_t = 0.01; p.from = P.pos
		return false
	if p.punch_t > 0:
		p.punch_t += dt
		if p.punch_t > 0.3: p.punch_t = 0
	var d = Vector2(P.pos.x - p.pos.x, P.pos.z - p.pos.z).length()
	if p.hit_t > 0:
		p.hit_t -= dt
		if p.hit_t <= 0 and d < 1.45: P.take_punch(G.rand(5, 9), p.pos)
	if d <= 1.05:
		p.atk_cd -= dt
		if p.atk_cd <= 0:
			p.atk_cd = G.rand(0.75, 1.2); p.punch_t = 0.0001; p.punch_side = -1 if randf() < 0.5 else 1; p.hit_t = 0.13
			main.sfx.play3d("swing", p.pos + Vector3(0, 1.4, 0), 0.4)
	return true


# ---------- fun reactions ----------
# when you dance, flop, laugh or flex, the people nearby react
func react_to_emote(at, kind):
	var near = []
	for p in PEDS:
		if p.state == "walk" and p.pos.distance_to(at) < 13: near.append(p)
	near.sort_custom(self, "_by_dist")
	for i in range(min(3, near.size())):
		var p = near[i]
		var r = randf()
		var em = ""
		if kind == "dance": em = G.pick(["dance1", "dance2", "dance3", "clap"]) if r < 0.75 else "laugh"
		elif kind == "flop": em = "laugh" if r < 0.6 else ("point" if r < 0.85 else "facepalm")
		elif kind == "flex": em = "clap" if r < 0.5 else "shrug"
		elif kind == "laugh": em = "laugh"
		elif kind == "point": em = "shrug"
		if em == "": continue
		p.emote = em; p.emote_t = G.rand(0, 1); p.emote_left = G.rand(3.5, 8.0)
		if i == 0 and randf() < 0.7:
			var line = { "dance": ["Okay, I see you!", "Ayy, Calder!", "Don't stop!"], "flop": ["You good?!", "Bro fell for no reason.", "Somebody record that."],
				"flex": ["Okay, strong man.", "Put your coat back on."], "laugh": ["What's funny?", "Ha!"], "point": ["What you pointing at?"] }.get(kind, ["Ha."])
			main.hud.say("Passerby", G.pick(line))

# a snowball landed on someone
func snowball_hit(who, v):
	var P = main.player
	if who is Ped:
		var r = randf()
		if r < 0.12:
			who.h.ragdoll_start(Vector3(), Vector3(v.x, 0, v.z).normalized() * 2.5 + Vector3(0, 1, 0), G.rand(-1, 1))
			who.state = "down"; who.down_t = 0; who.ko = true; who.hp = max(who.hp, 1)
			main.hud.say("Passerby", "Whoa-!")
		elif r < 0.55:
			who.emote = "laugh"; who.emote_left = 1.2; who.emote_t = 0
			main.hud.say("Passerby", G.pick(["Oh, it's ON.", "Snow war!", "You asked for this!"]))
			_throw_back(who, 0.9)
		elif r < 0.8:
			main.hud.say("Passerby", G.pick(["Really?!", "In this cold?!", "My face!"]))
			who.state = "flee"; who.flee_t = 5; who.from = P.pos
		else:
			punched(who, 0.1, Vector3(v.x, 0, v.z).normalized(), false)
			main.hud.say("Passerby", "You got jokes?")
	elif "rec" in who:
		# your own gang throws one back
		main.hud.say(who.rec.name, G.pick(["Ha! Bet.", "Watch your back.", "Snow fight!"]))
		_throw_back(who, 0.7)
	elif "crew" in who:
		main.crews.engage(who.crew, "snow")
	else:
		main.hud.say("POLICE", G.pick(["A snowball? At an officer?", "Real funny. Keep walking."]))
		main.police.add_wanted(8, who.pos)

func _throw_back(who, delay):
	yield(get_tree().create_timer(delay), "timeout")
	if not is_instance_valid(who.h): return
	if who.is_down() if who.has_method("is_down") else who.state == "down": return
	var P = main.player
	var from = who.pos + Vector3(0, 1.7, 0)
	var to = P.pos + Vector3(0, 1.3, 0)
	var flat = Vector2(to.x - from.x, to.z - from.z)
	var d = flat.length()
	var tt = clamp(d / 15.0, 0.2, 1.2)
	var v = Vector3(flat.x / tt, (to.y - from.y) / tt + 7.0 * tt, flat.y / tt)
	main.fx.throw_snowball(from, v, who)
