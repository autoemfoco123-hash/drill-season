extends Node
# Your gang: a name, tag and colour, recruits off the street or from the phone, up to three
# who roll with you and fight, and the rest working for you. Ported from 86_gangs.js.

var main
var FOL = []
var _t = 0.0
var pay_acc = 0.0
var paid = 0
var pay_toast_t = 300.0
var look_t = 0.0
var warned = {}
const MAX_RECRUITS = 8
const MAX_WITH = 3
const FIRST = ["Dre", "Moe", "Tay", "Nunu", "Lex", "Zay", "Kay", "Jojo", "Quan", "Mel", "Trey", "Bink", "Deuce", "Kiki", "Vonnie", "Shay", "Nia", "Bree", "Toya", "Dee", "Rico", "Manny", "Luis", "Petey", "Sal", "Gino", "Ty", "Bo", "Rae", "Jaz", "Mook", "Smoke", "Tink", "Ace", "Yaya", "Pooh"]
const PRE = ["Lil ", "Big ", "Young ", "", "", "", "", ""]
const REAL = ["gangsterdisciple", "blackdisciple", "vicelord", "latinking", "blackpstone", "fourcornerhustler", "crips", "bloods", "ms13", "marasalvatrucha", "latindisciple", "mickeycobra", "blackgangster", "satandisciple", "twotwoboys", "ambrose"]
var NOPE = []

class Follower:
	var main
	var rec
	var h
	var gun = null
	var pos = Vector3()
	var vel = Vector3()
	var radius = 0.34
	var height = 1.75
	var on_ground = true
	var air_y = 0.0
	var yaw = 0.0
	var hp = 100.0
	var state = "follow"
	var trail = []
	var tgt = null
	var tgt_t = 0.0
	var fire_cd = 1.0
	var atk_cd = 0.5
	var punch_t = 0.0
	var punch_side = 1
	var hit_t = 0.0
	var heal_t = 1.0
	var down_t = 0.0
	var riding = false
	var slot = 0
	var fighting = false
	var last_say = -99.0

func setup(m):
	main = m
	NOPE = Marshalls.base64_to_utf8("bmlnZyxuaWdhLGZhZ2dvdCxmYWdvdCxyZXRhcmQsa2lrZSxjaGluayx0cmFubnksd2V0YmFjayxiZWFuZXIsZ29vayxzcGljayxkeWtlLGNvb24=").split(",")

func types():
	return G.D["RTYPES"]

func text_ok(s):
	var low = String(s).to_lower().replace("0", "o").replace("1", "i").replace("!", "i").replace("|", "i").replace("3", "e").replace("4", "a").replace("@", "a").replace("5", "s").replace("$", "s").replace("7", "t")
	var tokens = []
	var cur = ""
	for i in range(low.length()):
		var ch = low[i]
		if ch >= "a" and ch <= "z": cur += ch
		elif cur != "":
			tokens.append(cur)
			cur = ""
	if cur != "": tokens.append(cur)
	var flat = PoolStringArray(tokens).join("")
	for w in NOPE:
		if w.length() >= 5 or w == "nigg":
			if flat.find(w) >= 0: return false
		elif w in tokens or (w + "s") in tokens: return false
	for w in REAL:
		if flat.find(w) >= 0: return false
	return true

func recruit_name(seed_v):
	var r = G.seeded_rng(int(seed_v) ^ 0x9e37)
	return PRE[r.randi_range(0, PRE.size() - 1)] + FIRST[r.randi_range(0, FIRST.size() - 1)]

func recruit_opts(seed_v, type):
	var s = G.random_skin(G.seeded_rng(seed_v))
	var r1 = G.seeded_rng(seed_v + 1)
	if type == "brawler":
		s.build = 2; s.top = "track" if r1.randf() < 0.5 else "hoodie"; s.head = "durag" if G.seeded_rng(seed_v + 2).randf() < 0.5 else "none"
	elif type == "shooter":
		s.top = "puffer"; s.topCol = 0x15171a; s.top2 = 0x262b33; s.head = "beanie"; s.headCol = 0x15171a; s.pom = 0
	elif type == "medic":
		s.top = "parka"; s.topCol = 0xe8e8ea; s.top2 = 0xc8202a; s.bag = "cross"; s.bagCol = 0xc8202a
	elif type == "lookout":
		s.head = "hood"; s.glasses = 1; s.top = "hoodie"
	elif type == "hustler":
		s.chain = 1; s.watch = 1; s.top = "leather"; s.topCol = 0x15171a
	elif type == "producer":
		s.head = "headphones"; s.headCol = 0xe8e8ea; s.bag = "cross"
	return G.skin_opts(s)

# some people on the street are open to joining
func tag_ped(p):
	if randf() > 0.2: return null
	p.rq_seed = randi() & 0x7fffffff
	p.rq = G.pick(types().keys())
	p.rq_name = recruit_name(p.rq_seed)
	return recruit_opts(p.rq_seed, p.rq)

func update_recruit_plate(_p):
	pass

func gang():
	return G.S.get("gang")

func gang_color(g = null):
	var gg = g if g != null else gang()
	var cols = G.D["GANG_COLORS"]
	return Color(cols[int(gg.get("color", 0)) % cols.size()] if gg else cols[0])

func create(name, tag, color):
	var n = ""
	for i in range(name.length()):
		var ch = name[i]
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch in [" ", "'", "&", ".", "-"]: n += ch
	n = n.strip_edges().substr(0, 18)
	var t = ""
	for i in range(tag.length()):
		var ch2 = tag.to_upper()[i]
		if (ch2 >= "A" and ch2 <= "Z") or (ch2 >= "0" and ch2 <= "9"): t += ch2
	t = t.substr(0, 4)
	if n.length() < 3: return "Give the gang a name, 3 to 18 letters."
	if t.length() < 2: return "Pick a tag: 2 to 4 letters or numbers."
	if not text_ok(n) or not text_ok(t): return "Pick a different name. Keep it made up and keep it clean."
	G.S["gang"] = { "id": str(OS.get_unix_time()) + str(randi() % 1000), "name": n, "tag": t, "color": int(color), "role": "leader", "leader": G.S["name"], "rep": 0, "created": OS.get_unix_time() }
	main.hud.banner("[%s] %s" % [t, n], "Your gang is on the map")
	G.save_game()
	return ""

func leave():
	var g = gang()
	if g == null: return
	G.S["gang"] = null
	main.hud.toast("You left [%s] %s" % [g.tag, g.name])
	clear()
	G.save_game()

func rep(n):
	if gang() != null:
		G.S["gang"]["rep"] = max(0, int(G.S["gang"].get("rep", 0)) + n)

func can_recruit(type):
	var T = types()[type]
	if gang() == null: return "Start a gang first"
	if G.S["recruits"].size() >= MAX_RECRUITS: return "Your gang is full (%d)" % MAX_RECRUITS
	if G.S["buzz"] < T.buzz: return "Needs Buzz %d" % T.buzz
	if G.S["cash"] < T.cost: return "Needs " + G.fmt_money(T.cost)
	return ""

func hire(type, seed_v, name, at = null):
	if can_recruit(type) != "": return null
	G.S["cash"] -= types()[type].cost
	var with_n = 0
	for r in G.S["recruits"]:
		if r.get("with", false): with_n += 1
	var rec = { "id": str(seed_v), "seed": seed_v, "type": type, "name": name, "with": with_n < MAX_WITH, "hurtUntil": 0, "joined": OS.get_unix_time() }
	G.S["recruits"].append(rec)
	rep(5)
	if rec.with: spawn_follower(rec, at)
	main.hud.toast("%s (%s) is down with [%s]" % [name, types()[type].name, gang().tag])
	main.sfx.play("cash", 0.5)
	G.save_game()
	return rec

func drop(rec):
	G.S["recruits"].erase(rec)
	for f in FOL.duplicate():
		if f.rec == rec: remove_follower(f)
	G.save_game()

func set_with(rec, on):
	if on:
		var n = 0
		for r in G.S["recruits"]:
			if r.get("with", false): n += 1
		if n >= MAX_WITH:
			main.hud.toast("Only %d can roll with you at once" % MAX_WITH); return
	rec["with"] = on
	if not on:
		for f in FOL.duplicate():
			if f.rec == rec: remove_follower(f)
	else:
		sync_followers()
	G.save_game()

func candidates():
	var base = int(G.S.get("day", 1)) * 7919 + (String(gang().id).length() * 131 if gang() else 0)
	var out = []
	for i in range(4):
		var seed_v = (base * 31 + i * 977 + 13) & 0x7fffffff
		var r = G.seeded_rng(seed_v)
		var keys = types().keys()
		var c = { "seed": seed_v, "type": keys[r.randi_range(0, keys.size() - 1)], "name": recruit_name(seed_v) }
		var taken = false
		for rr in G.S["recruits"]:
			if int(rr.seed) == seed_v: taken = true
		if not taken: out.append(c)
	return out

func nearest_recruit_ped():
	var P = main.player
	if P.car: return null
	var best = null
	var bd = 2.3
	for p in main.peds.PEDS:
		if p.rq == null or p.state != "walk": continue
		var d = p.pos.distance_to(P.pos)
		if d < bd:
			bd = d
			best = p
	return best

func talk_recruit(p):
	p.idle_t = max(p.idle_t, 10)
	var T = types()[p.rq]
	var why = can_recruit(p.rq)
	var items = []
	items.append({ "label": "Recruit for " + G.fmt_money(T.cost), "desc": "“" + T.line + "”", "hint": why, "disabled": why != "", "act": funcref(self, "_hire_ped"), "arg": p })
	if gang() == null:
		items.append({ "label": "Open the Gang app", "desc": "Start your own gang first", "act": funcref(main.phone, "open"), "arg": "gang" })
	items.append({ "label": "Not now", "act": null })
	main.hud.menu("On the street", p.rq_name, T.name + " · " + T.perk, items)

func _hire_ped(p):
	var at = { "pos": p.pos, "yaw": p.yaw }
	main.peds.remove(p)
	hire(p.rq, p.rq_seed, p.rq_name, at)

# ---------- the people rolling with you ----------
func _spot(near):
	var P = main.player
	for _k in range(24):
		var a = G.rand(0, TAU)
		var r = G.rand(1.5, 3.5) if near else G.rand(16, 26)
		var p = P.pos + Vector3(cos(a) * r, 0, sin(a) * r)
		if not W.is_blocked(p.x, p.z, 0.4) and abs(p.x) < W.BOUND and abs(p.z) < W.BOUND: return p
	return P.pos + Vector3(1.5, 0, 1.5)

func spawn_follower(rec, at = null):
	for f in FOL:
		if f.rec == rec: return
	var f = Follower.new()
	f.main = main; f.rec = rec; f.hp = float(types()[rec.type].hp); f.slot = FOL.size()
	f.pos = at.pos if at != null else _spot(false)
	f.yaw = at.yaw if at != null else 0.0
	f.h = load("res://scripts/Human.gd").new().build(recruit_opts(int(rec.seed), rec.type))
	main.add_child(f.h)
	if rec.type == "shooter":
		f.gun = load("res://assets/guns/k9.glb").instance()
		f.gun.rotation = Vector3(PI / 2, 0, 0); f.gun.translation = Vector3(0, -0.03, 0.02); f.gun.scale = Vector3.ONE * 1.35
		f.h.gun_slot.add_child(f.gun)
	FOL.append(f)

func remove_follower(f):
	FOL.erase(f)
	if is_instance_valid(f.h): f.h.queue_free()
	for i in range(FOL.size()): FOL[i].slot = i

func clear():
	for f in FOL.duplicate(): remove_follower(f)

func sync_followers():
	var want = []
	if gang() != null:
		for r in G.S["recruits"]:
			if r.get("with", false) and float(r.get("hurtUntil", 0)) <= G.S.get("playTime", 0): want.append(r)
	for f in FOL.duplicate():
		if not f.rec in want: remove_follower(f)
	if G.MODE == "title": return
	for r in want:
		var have = false
		for f in FOL:
			if f.rec == r: have = true
		if not have: spawn_follower(r)

func _target(f):
	var best = null
	var bd = 32.0 if f.rec.type == "shooter" else 22.0
	for e in main.crews.ENEMIES:
		if e.is_down() or e.crew.state != "combat": continue
		var d = e.pos.distance_to(f.pos)
		if d < bd:
			bd = d
			best = e
	if f.rec.type == "brawler":
		for p in main.peds.PEDS:
			if p.state != "brawl": continue
			var d2 = p.pos.distance_to(f.pos)
			if d2 < bd:
				bd = d2
				best = p
	return best

# rivals shoot at your people too
func divert_shot(e):
	if FOL.size() == 0 or randf() > 0.45: return false
	var dP = e.pos.distance_to(main.player.pos)
	var f = null
	var bd = min(24.0, dP + 4)
	for o in FOL:
		if o.state == "down" or o.riding: continue
		var d = o.pos.distance_to(e.pos)
		if d < bd and W.seg_clear(e.pos + Vector3(0, 1.4, 0), o.pos + Vector3(0, 1.3, 0)):
			bd = d
			f = o
	if f == null: return false
	var mz = e.h.gun_slot.global_transform.origin
	var hit = randf() < float(e.T.acc) * 1.1
	var end = f.pos + Vector3(0, 1.3, 0) + (Vector3() if hit else Vector3(G.rand(-1.2, 1.2), G.rand(-0.4, 0.8), G.rand(-1.2, 1.2)))
	main.sfx.tracer(mz, end)
	main.sfx.shot(e.T.gun, mz, 0.8)
	if hit: _hurt(f, float(e.T.dmg), e.pos)
	return true

func _hurt(f, dmg, from):
	if f.state == "down": return
	f.hp -= dmg
	main.sfx.blood(f.pos + Vector3(0, 1.2, 0), f.pos - from)
	if f.hp <= 0:
		f.state = "down"; f.down_t = 0
		main.sfx.play3d("bodyfall", f.pos, 0.8)
		if f.gun: f.gun.visible = false

func lookout_boost():
	for f in FOL:
		if f.rec.type == "lookout" and f.state != "down": return 1.6
	return 1.0

func count(type):
	var n = 0
	if gang() == null: return 0
	for r in G.S["recruits"]:
		if r.type == type and float(r.get("hurtUntil", 0)) <= G.S.get("playTime", 0): n += 1
	return n

func update(dt):
	_t -= dt
	if _t <= 0:
		_t = 1.0
		sync_followers()
		_perks()
	for f in FOL.duplicate():
		_update_follower(f, dt)

func _perks():
	var hu = count("hustler")
	if hu > 0:
		pay_acc += 1.0
		if pay_acc >= 60:
			pay_acc = 0
			G.S["cash"] += 12 * hu; paid += 12 * hu
		pay_toast_t -= 1
		if pay_toast_t <= 0 and paid > 0:
			pay_toast_t = 300; main.hud.toast("Your hustlers brought in " + G.fmt_money(paid)); paid = 0
	look_t -= 1
	var lo = null
	for f in FOL:
		if f.rec.type == "lookout" and f.state != "down": lo = f
	if lo and look_t <= 0:
		for v in main.vehicles.VEH:
			if v.cop and not warned.has(v.id) and v.pos.distance_to(main.player.pos) < 80:
				warned[v.id] = true
				main.hud.say(lo.rec.name, G.pick(["Cop car. Heads down.", "12 on the block, be cool.", "Police coming up, keep it moving."]))
				look_t = 20
				break

func _update_follower(f, dt):
	var P = main.player
	var H = f.h
	var T = types()[f.rec.type]
	if f.state == "down":
		f.down_t += dt
		H.animate(dt, { "down": min(1.0, f.down_t / 0.5) })
		if f.down_t > 5:
			f.rec["hurtUntil"] = G.S.get("playTime", 0) + 150
			main.hud.toast("%s is at Calder General. Back in a few minutes." % f.rec.name)
			remove_follower(f); G.save_game()
		return
	if P.car:
		if not f.riding:
			f.riding = true
			H.visible = false
		f.pos = P.pos; f.trail.clear()
		return
	if f.riding:
		f.riding = false; f.pos = _spot(true); f.vel = Vector3(); H.visible = true
	var dP = f.pos.distance_to(P.pos)
	if dP > 45:
		f.pos = _spot(true); f.trail.clear(); f.vel = Vector3()
	f.tgt_t -= dt
	if f.tgt_t <= 0:
		f.tgt_t = 0.4; f.tgt = _target(f)
	var tg = f.tgt if f.tgt != null and not f.tgt.is_down() else null
	var goal = null
	var spd = 0.0
	var face = null
	var aim = 0.0
	var fighting = false
	if f.punch_t > 0:
		f.punch_t += dt
		if f.punch_t > 0.3: f.punch_t = 0
	if tg and f.rec.type == "shooter" and dP < 16:
		var d = tg.pos.distance_to(f.pos)
		face = atan2(tg.pos.x - f.pos.x, tg.pos.z - f.pos.z); aim = 1.0; fighting = true
		if d > 20:
			goal = tg.pos
			spd = 3.2
		f.fire_cd -= dt
		if f.fire_cd <= 0:
			f.fire_cd = G.rand(0.45, 0.85); _shoot(f, tg)
	elif tg and f.rec.type == "brawler" and dP < 22:
		var d2 = tg.pos.distance_to(f.pos)
		face = atan2(tg.pos.x - f.pos.x, tg.pos.z - f.pos.z); fighting = true
		if d2 > 1.1:
			goal = tg.pos
			spd = 5.4
		f.atk_cd -= dt
		if d2 < 1.3 and f.atk_cd <= 0:
			f.atk_cd = G.rand(0.6, 0.9); f.punch_t = 0.0001; f.punch_side = -f.punch_side; f.hit_t = 0.12
			main.sfx.play3d("swing", f.pos + Vector3(0, 1.4, 0), 0.4)
		if f.hit_t > 0:
			f.hit_t -= dt
			if f.hit_t <= 0 and d2 < 1.6:
				var dir = (tg.pos - f.pos).normalized()
				main.sfx.play3d("punch", tg.pos + Vector3(0, 1.45, 0), 0.75)
				tg.take_hit(11, false, dir, false, true)
	if goal == null and not fighting:
		var last = f.trail.back() if f.trail.size() > 0 else null
		if last == null or Vector2(last.x - P.pos.x, last.z - P.pos.z).length() > 0.6: f.trail.append(P.pos)
		while f.trail.size() > 1 and Vector2(f.trail[0].x - f.pos.x, f.trail[0].z - f.pos.z).length() < 0.8: f.trail.pop_front()
		while f.trail.size() > 40: f.trail.pop_front()
		var keep = 2.0 + f.slot * 1.1
		if dP > keep and f.trail.size() > 0:
			goal = f.trail[0]; spd = 6.6 if dP > 10 else (4.6 if dP > keep + 2 else 2.4)
	if f.rec.type == "medic" and G.S["health"] < 70 and dP < 5 and not P.dead:
		f.heal_t -= dt
		if f.heal_t <= 0:
			f.heal_t = 1; G.S["health"] = min(100, G.S["health"] + 6)
			if G.GAME_T - f.last_say > 25:
				f.last_say = G.GAME_T; main.hud.say(f.rec.name, G.pick(["Hold still.", "You good. Breathe.", "That's gonna bruise.", "Stay behind me."]))
	var vx = 0.0
	var vz = 0.0
	if goal != null:
		var g = Vector2(goal.x - f.pos.x, goal.z - f.pos.z)
		if g.length() > 0.3:
			g = g.normalized() * spd
			vx = g.x
			vz = g.y
	if dP < 1.0 and dP > 0.01:
		vx += (f.pos.x - P.pos.x) / dP * 2; vz += (f.pos.z - P.pos.z) / dP * 2
	for o in FOL:
		if o == f or o.riding: continue
		var od = Vector2(f.pos.x - o.pos.x, f.pos.z - o.pos.z)
		var ol = od.length()
		if ol < 0.9 and ol > 0.01:
			vx += od.x / ol * 1.6
			vz += od.y / ol * 1.6
	var k = 1 - exp(-dt * 8)
	f.vel.x += (vx - f.vel.x) * k; f.vel.z += (vz - f.vel.z) * k
	W.move_body(f, f.vel.x * dt, f.vel.z * dt, dt)
	var sp = Vector2(f.vel.x, f.vel.z).length()
	if face == null and sp > 0.4: face = atan2(f.vel.x, f.vel.z)
	if face == null and dP < 4: face = atan2(P.pos.x - f.pos.x, P.pos.z - f.pos.z)
	if face != null: f.yaw += G.ang_diff(f.yaw, face) * (1 - exp(-dt * 9))
	H.translation = f.pos; H.rotation = Vector3(0, f.yaw, 0)
	var box = f.rec.type == "brawler" and fighting
	H.animate(dt, { "speed": sp, "aim": aim, "pitch": 0.0, "fists": box, "guard": box, "punch": f.punch_t / 0.3 if f.punch_t > 0 else 0.0, "punchSide": f.punch_side, "shiver": G.S.get("warmth", 100) < 25 })
	f.fighting = fighting

func _shoot(f, e):
	var mz = f.h.gun_slot.global_transform.origin
	var tp = e.pos + Vector3(0, 0.9 if e.crouched else 1.3, 0)
	if not W.seg_clear(mz, tp): return
	var hit = randf() < 0.42
	var end = tp if hit else tp + Vector3(G.rand(-1.2, 1.2), G.rand(-0.4, 0.8), G.rand(-1.2, 1.2))
	main.sfx.tracer(mz, end)
	main.sfx.shot("k9", mz, 0.75)
	main.peds.alert(f.pos, 35)
	G.S["heat"] = min(100, G.S["heat"] + 0.3)
	if hit: e.take_hit(9, false, (e.pos - f.pos).normalized(), false, false)
