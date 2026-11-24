extends Node
# Online missions: jobs that anyone in the same online room or server starts from the phone
# (Online → Missions) and everyone else there can join. Offline you play them on your own.
#
#  - Street Race: everyone in the same fast car on a start grid, a 3-2-1, then checkpoints round
#    the city. Places by who's ahead (checkpoints, then distance to the next); prize money by place.
#  - Drop Run (co-op): a bag to pick up across town and deliver before the clock runs out. Rivals
#    and the police come after whoever carries it; if the carrier goes down the bag drops where
#    they fell and anyone can grab it. Everyone in gets paid when it lands.
#  - Turf Raid (co-op): take a rival block together. Each player fights the waves on their own
#    screen, but the takeover's progress is shared, so the crew fills the bar together; the block
#    goes to the gang of whoever started the raid.
#
# The one who starts it picks the details (route, pickup and drop, the block) and sends them; there
# is a lobby (25 s online) and the mission starts at the same moment on the shared clock
# (G.world_seconds), so every screen counts down together. Players are told apart by name.
# Messages: mis_new, mis_join, mis_leave, mis_go, mis_cp, mis_fin, mis_bag, mis_p, mis_end.

const KINDS = {
	"race": { "name": "Street Race", "desc": "Checkpoints round the city in the same car. Prize money by place.", "col": Color(1.0, 0.78, 0.2) },
	"drop": { "name": "Drop Run", "desc": "Pick up the bag, deliver it before the clock runs out. Rivals and the police come for the carrier.", "col": Color(0.35, 0.95, 0.55) },
	"raid": { "name": "Turf Raid", "desc": "Take a rival block together. The progress bar is shared; the block goes to the starter's gang.", "col": Color(0.95, 0.35, 0.3) },
}
const ROUTES = [
	{ "name": "Calder Loop", "pts": [[-95, 0], [0, 0], [0, -90], [-95, -90], [-95, 90], [0, 90], [0, 0]] },
	{ "name": "Lakeshore Run", "pts": [[-190, 0], [-190, -180], [160, -180], [160, 90], [0, 90], [0, 0]] },
]
const DROPS = ["reyes", "gas", "yard", "court", "lakefront", "dealer", "pavilion", "station"]
const LOBBY = 25.0
const RACE_PRIZE = [1200, 700, 400, 200]
const DROP_TIME = 240.0
const RAID_TIME = 300.0
const CP_R = 11.0

var main
var cur = null            # the mission on this screen (one at a time)
var beacons = []          # [root, material] x2: the next checkpoint / target, and the one after
var bag_node = null
var _send_t = 0.0
var _wave_t = 0.0
var _said = {}

func setup(m):
	main = m
	beacons.append(_beacon(Color(1, 0.8, 0.2)))
	beacons.append(_beacon(Color(1, 0.8, 0.2)))
	bag_node = _bag()

# ---------------------------------------------------------------- the look: beacons and the bag
func _beacon(col):
	var root = Spatial.new(); root.name = "MissionBeacon"
	var img = Image.new(); img.create(4, 64, false, Image.FORMAT_RGBA8)
	img.lock()
	for y in range(64):
		var a = pow(float(y) / 63.0, 1.6)
		for x in range(4): img.set_pixel(x, y, Color(1, 1, 1, a))
	img.unlock()
	var tex = ImageTexture.new(); tex.create_from_image(img)
	var m = SpatialMaterial.new(); m.flags_unshaded = true; m.flags_transparent = true
	m.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD; m.params_cull_mode = SpatialMaterial.CULL_DISABLED
	m.albedo_texture = tex; m.albedo_color = Color(col.r, col.g, col.b, 0.32)
	var cyl = CylinderMesh.new(); cyl.top_radius = 3.0; cyl.bottom_radius = 3.0; cyl.height = 36.0; cyl.radial_segments = 28; cyl.rings = 1
	var mi = MeshInstance.new(); mi.mesh = cyl; mi.material_override = m; mi.translation = Vector3(0, 18, 0)
	mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var ring = main.turf._ring_mesh(2.7, 3.2, 40) if main.turf else null
	if ring:
		var rm = SpatialMaterial.new(); rm.flags_unshaded = true; rm.flags_transparent = true; rm.params_cull_mode = SpatialMaterial.CULL_DISABLED
		rm.albedo_color = Color(col.r, col.g, col.b, 0.9)
		var r = MeshInstance.new(); r.mesh = ring; r.material_override = rm; r.translation = Vector3(0, 0.06, 0)
		r.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		root.add_child(r)
		root.set_meta("ring", rm)
	root.visible = false
	main.add_child(root)
	return [root, m]

func _paint_beacon(i, col, alpha = 0.32):
	var b = beacons[i]
	b[1].albedo_color = Color(col.r, col.g, col.b, alpha)
	if b[0].has_meta("ring"): b[0].get_meta("ring").albedo_color = Color(col.r, col.g, col.b, 0.9 * alpha / 0.32)

func _bag():
	var root = Spatial.new(); root.name = "MissionBag"
	var body = MeshInstance.new(); var bm = CubeMesh.new(); bm.size = Vector3(0.62, 0.3, 0.32); body.mesh = bm
	body.material_override = G.mat(Color(0.08, 0.09, 0.1)); body.translation = Vector3(0, 0.16, 0)
	root.add_child(body)
	for x in [-0.18, 0.18]:
		var st = MeshInstance.new(); var sm = CubeMesh.new(); sm.size = Vector3(0.04, 0.16, 0.34); st.mesh = sm
		st.material_override = G.mat(Color(0.35, 0.95, 0.55)); st.translation = Vector3(x, 0.24, 0)
		root.add_child(st)
	root.visible = false
	main.add_child(root)
	return root

# ---------------------------------------------------------------- who and when
func me(): return str(G.S.get("name", "me")).substr(0, 18)
func now(): return G.world_seconds()
func busy(): return cur != null and cur.phase != "done"
func in_it(): return busy() and cur["in"]
func online(): return main.net.online() and main.net.mode != "browse"

func _num(v, d = 0.0):
	return float(v) if typeof(v) in [TYPE_INT, TYPE_REAL] else d

func others():
	var out = []
	for r in main.net.R.values(): out.append(r)
	return out

func remote_by_name(n):
	for r in main.net.R.values():
		if r.name == n: return r
	return null

func pos_of(n):
	if n == me(): return main.player.pos
	var r = remote_by_name(n)
	return r.pos if r != null else null

func loc(k):
	var L = G.D["LOC"][k]
	return Vector3(float(L.x), 0, float(L.z))

# ---------------------------------------------------------------- starting, joining, leaving
func can_start(kind):
	if busy(): return "A mission is already on"
	if main.player.dead: return "Not while you're down"
	if kind == "raid":
		if typeof(G.S.get("gang")) != TYPE_DICTIONARY: return "Start a gang first (Phone → Gang)"
		if _raid_target() < 0: return "No rival block to raid"
	return ""

func _raid_target():
	var T = main.turf
	var best = -1
	var bd = INF
	var m = T.cur()
	for b in range(T.N):
		if not T.hostile(m[b]) or typeof(m[b]) == TYPE_ARRAY: continue
		var d = T._dist(main.player.pos, T.corners[b])
		if d < bd:
			bd = d; best = b
	return best

func start(kind):
	var why = can_start(kind)
	if why != "":
		main.hud.toast("Missions:  " + why); return why
	var d = {}
	if kind == "race":
		d["route"] = randi() % ROUTES.size()
	elif kind == "drop":
		var a = G.pick(DROPS)
		var b = a
		for _k in range(30):
			b = G.pick(DROPS)
			if b != a and loc(a).distance_to(loc(b)) > 170: break
		d["from"] = a; d["to"] = b
	elif kind == "raid":
		d["b"] = _raid_target()
		d["g"] = main.turf.my_gang()
	var solo = not online() or main.net.R.empty()
	var at = now() + (4.0 if solo else LOBBY)
	cur = { "mid": str(OS.get_unix_time()) + str(randi() % 1000), "kind": kind, "owner": me(), "own": true, "at": at, "d": d,
		"joined": [me()], "in": true, "phase": "lobby", "cp": {}, "fin": {}, "t0": 0.0, "res": "" }
	if online():
		main.net.send_mission({ "t": "mis_new", "mid": cur.mid, "k": kind, "d": d, "at": at, "o": me() })
	main.hud.banner(KINDS[kind].name, ("Starting in %d s" % int(at - now())) + ("" if solo else " · others can join from the phone"))
	main.sfx.play("notif", 0.5)
	return ""

func join():
	if cur == null or cur.phase != "lobby" or cur["in"]: return
	cur["in"] = true
	if not me() in cur.joined: cur.joined.append(me())
	if online(): main.net.send_mission({ "t": "mis_join", "mid": cur.mid, "n": me() })
	main.hud.toast("Missions:  you're in · %s" % KINDS[cur.kind].name)

func leave():
	if not in_it(): return
	if online(): main.net.send_mission({ "t": "mis_leave", "mid": cur.mid, "n": me() })
	cur.joined.erase(me())
	cur["in"] = false
	_end_local("You left the mission", false)

# ---------------------------------------------------------------- the network
func net_event(t, r, e):
	var mid = str(e.get("mid", "")).substr(0, 24)
	var who = str(e.get("n", r.name if r != null else "")).substr(0, 18)
	if t == "mis_new":
		if busy() or r == null: return
		var k = str(e.get("k", ""))
		if not KINDS.has(k): return
		var d = _clean_data(k, e.get("d"))
		if d == null: return
		var at = clamp(_num(e.get("at"), now()), now() - 2.0, now() + LOBBY + 5.0)
		cur = { "mid": mid, "kind": k, "owner": r.name, "own": false, "at": at, "d": d, "joined": [r.name], "in": false, "phase": "lobby",
			"cp": {}, "fin": {}, "t0": 0.0, "res": "" }
		main.hud.toast("@%s:  started a %s. Phone → Online → Missions to join (%d s)" % [r.name, KINDS[k].name, int(max(0, at - now()))])
		main.sfx.play("notif", 0.5)
		return
	if cur == null or mid != cur.mid: return
	if t == "mis_join":
		if not who in cur.joined: cur.joined.append(who)
	elif t == "mis_leave":
		cur.joined.erase(who)
	elif t == "mis_go":
		var p = e.get("p")
		if typeof(p) == TYPE_ARRAY:
			var lst = []
			for n in p: lst.append(str(n).substr(0, 18))
			if me() in lst or not cur["in"]: cur.joined = lst
	elif t == "mis_cp":
		cur.cp[who] = int(clamp(_num(e.get("cp")), 0, 99))
	elif t == "mis_fin":
		cur.fin[who] = clamp(_num(e.get("tm"), 999.0), 0.0, 999.0)
		if cur["in"] and who != me(): main.hud.toast("Race:  @%s finished · %s" % [who, _clock(cur.fin[who])])
	elif t == "mis_bag":
		_bag_event(who, e)
	elif t == "mis_p":
		if cur.kind == "raid": cur["shared"] = max(float(cur.get("shared", 0.0)), clamp(_num(e.get("p")), 0.0, 1.0))
	elif t == "mis_end":
		if cur.phase == "done": return
		var ok = e.get("ok", false) == true
		_finish(ok, str(e.get("why", "")).substr(0, 60), who)

func _clean_data(k, d):
	if typeof(d) != TYPE_DICTIONARY: return null
	if k == "race":
		return { "route": int(clamp(_num(d.get("route")), 0, ROUTES.size() - 1)) }
	if k == "drop":
		var a = str(d.get("from", "")); var b = str(d.get("to", ""))
		if not a in DROPS or not b in DROPS or a == b: return null
		return { "from": a, "to": b }
	if k == "raid":
		var b2 = int(_num(d.get("b"), -1))
		var g = main.turf.clean_owner(d.get("g"))
		if b2 < 0 or b2 >= main.turf.N or b2 == main.turf.COPS or typeof(g) != TYPE_ARRAY: return null
		return { "b": b2, "g": g }
	return null

# ---------------------------------------------------------------- every frame
func update(dt):
	if G.MODE == "title" or beacons.empty(): return
	for b in beacons: b[0].visible = false
	bag_node.visible = false
	if cur == null: return
	var t = now()
	if cur.phase == "lobby":
		if t >= cur.at:
			if not cur["in"]:
				cur.phase = "done"; cur["res"] = ""
				return
			_go()
		return
	if cur.phase == "done":
		if t > float(cur.get("gone", t)): cur = null
		return
	if not cur["in"]: return
	if cur.kind == "race": _race(dt, t)
	elif cur.kind == "drop": _drop(dt, t)
	elif cur.kind == "raid": _raid(dt, t)

func _go():
	cur.phase = "run"
	cur.t0 = cur.at
	if cur.own and online(): main.net.send_mission({ "t": "mis_go", "mid": cur.mid, "p": cur.joined })
	if cur.kind == "race": _race_setup()
	elif cur.kind == "drop": _drop_setup()
	elif cur.kind == "raid": _raid_setup()

# ---------------------------------------------------------------- Street Race
func route(): return ROUTES[int(cur.d.route)]
func _pt(i):
	var p = route().pts[i]
	return Vector3(float(p[0]), 0, float(p[1]))

func _race_setup():
	var V = main.vehicles
	var P = main.player
	var slot = max(0, cur.joined.find(me()))
	var a = _pt(0)
	var b = _pt(1)
	var dir = (b - a).normalized()
	var side = Vector3(dir.z, 0, -dir.x)
	var at = a - dir * (8.0 + 6.0 * int(slot / 2)) + side * (2.2 if slot % 2 == 0 else -2.2)
	if P.car: P.exit_vehicle(true)
	if P.car: V.leave(P.car)
	P.car = null
	for v in V.VEH.duplicate():
		if not v.owned and v.pos.distance_to(at) < 14: V.remove(v)
	P.place(at.x, 0, at.z, atan2(-dir.x, -dir.z))
	var car = V.spawn("coupe", at.x, at.z, atan2(dir.x, dir.z), { "owned": true, "color": [0xd8a520, 0x2a6ad8, 0xc8202a, 0xe8e8ea, 0x2aa86a, 0x8a2ad8][slot % 6] })
	V.enter(car)
	cur["car"] = car
	cur["me_cp"] = 1
	cur.cp[me()] = 1
	cur["go"] = cur.t0 + 4.0
	main.hud.banner(route().name, "%d in the race · get ready" % cur.joined.size())

func frozen():
	return in_it() and cur.kind == "race" and now() < float(cur.get("go", 0.0))

func _race(dt, t):
	var P = main.player
	var go = float(cur.go)
	if t < go:
		_show(0, _pt(1), KINDS.race.col, 0.34)
		var n = int(ceil(go - t))
		if not _said.has(n):
			_said[n] = true
			main.hud.banner(str(n), route().name); main.sfx.play("tap", 0.8)
		return
	if not _said.has("go"):
		_said["go"] = true
		main.hud.banner("GO", ""); main.sfx.play("chime", 0.9)
	var i = int(cur.me_cp)
	var pts = route().pts
	if i < pts.size():
		var c = _pt(i)
		_show(0, c, KINDS.race.col, 0.34)
		if i + 1 < pts.size(): _show(1, _pt(i + 1), KINDS.race.col, 0.12)
		if P.car != null and Vector2(P.pos.x - c.x, P.pos.z - c.z).length() < CP_R:
			cur.me_cp = i + 1
			cur.cp[me()] = i + 1
			main.sfx.play("chime", 0.5, 1.0 + 0.05 * i)
			if online(): main.net.send_mission({ "t": "mis_cp", "mid": cur.mid, "n": me(), "cp": i + 1 })
			if i + 1 >= pts.size():
				var tm = t - go
				cur.fin[me()] = tm
				if online(): main.net.send_mission({ "t": "mis_fin", "mid": cur.mid, "n": me(), "tm": tm })
				main.hud.banner("Finished · %s" % _place_name(place()), _clock(tm))
				cur["my_fin_at"] = t
	# over when everyone's in, half a minute after you finish, or after four minutes
	var all_in = true
	for n in cur.joined:
		if not cur.fin.has(n) and (n == me() or remote_by_name(n) != null): all_in = false
	var done_t = float(cur.get("my_fin_at", INF))
	if all_in or t - done_t > 30.0 or t - go > 240.0:
		_race_results()

func standings():
	var rows = []
	var pts = route().pts
	for n in cur.joined:
		var cp = int(cur.cp.get(n, 1))
		var p = pos_of(n)
		var dn = 999.0
		if cp < pts.size() and p != null:
			var c = _pt(cp)
			dn = Vector2(p.x - c.x, p.z - c.z).length()
		var fin = cur.fin.get(n, -1.0)
		var key = (fin if fin >= 0 else 10000.0 - cp * 1000.0 + dn)
		rows.append([key, n])
	rows.sort_custom(self, "_by_key")
	var out = []
	for r in rows: out.append(r[1])
	return out

func _by_key(a, b): return a[0] < b[0]

func place():
	return standings().find(me()) + 1

func _place_name(p):
	return ["1st", "2nd", "3rd"][p - 1] if p >= 1 and p <= 3 else "%dth" % p

func _race_results():
	var st = standings()
	var p = st.find(me()) + 1
	var finished = cur.fin.has(me())
	var prize = RACE_PRIZE[min(p - 1, RACE_PRIZE.size() - 1)] if finished else 0
	if st.size() == 1 and finished:
		prize = 600 if float(cur.fin[me()]) < route().pts.size() * 9.0 else 300
	_reward(prize, 3 if p == 1 else 1)
	var lines = []
	for k in range(min(4, st.size())):
		var n = st[k]
		lines.append("%s @%s %s" % [_place_name(k + 1), n, _clock(cur.fin[n]) if cur.fin.has(n) else "DNF"])
	cur["res"] = PoolStringArray(lines).join("   ")
	_end_local(("%s place" % _place_name(p)) if finished else "Did not finish", finished, prize)
	main.hud.toast("Race:  " + cur.res)

# ---------------------------------------------------------------- Drop Run
func _drop_setup():
	cur["bag"] = { "carrier": "", "at": loc(cur.d.from) }
	cur["end"] = cur.t0 + DROP_TIME
	main.hud.banner("Drop Run", "Pick up the bag at " + str(G.D["LOC"][cur.d.from].name))

func _bag_event(who, e):
	if cur.kind != "drop" or not cur.has("bag"): return
	var c = str(e.get("c", ""))
	if c == "":
		var x = clamp(_num(e.get("x")), -260, 260); var z = clamp(_num(e.get("z")), -260, 260)
		cur.bag = { "carrier": "", "at": Vector3(x, 0, z) }
		if cur["in"]: main.hud.toast("Drop Run:  the bag is on the ground. Go get it")
	else:
		cur.bag = { "carrier": c.substr(0, 18), "at": cur.bag.at }
		if cur["in"] and c != me(): main.hud.toast("Drop Run:  @%s has the bag. Cover them" % c)

func _drop(dt, t):
	var P = main.player
	var bag = cur.bag
	var to = loc(cur.d.to)
	if t > float(cur.end):
		_end_all(false, "Out of time"); return
	if bag.carrier == "":
		var at = bag.at
		_show(0, at, Color(1.0, 0.6, 0.2), 0.34)
		bag_node.visible = true
		bag_node.translation = at + Vector3(0, 0.3 + 0.12 * sin(G.REAL_T * 3.0), 0)
		bag_node.rotation.y = G.REAL_T * 1.2
		if not P.dead and Vector2(P.pos.x - at.x, P.pos.z - at.z).length() < 3.2:
			cur.bag = { "carrier": me(), "at": at }
			if online(): main.net.send_mission({ "t": "mis_bag", "mid": cur.mid, "n": me(), "c": me() })
			main.hud.banner("You've got the bag", "Get it to " + str(G.D["LOC"][cur.d.to].name))
			main.police.add_wanted(25, P.pos, true)
			_wave_t = 6.0
		return
	# someone carries it: the drop zone lights up
	_show(0, to, KINDS.drop.col, 0.34)
	var cp = pos_of(bag.carrier)
	if cp == null:
		# the carrier is gone: a few seconds later the bag falls where they were last seen
		if not cur.has("lost"): cur["lost"] = t
		if t - float(cur.lost) > 5.0:
			cur.bag = { "carrier": "", "at": bag.at }
			cur.erase("lost")
		return
	cur.erase("lost")
	cur.bag.at = cp
	if bag.carrier != me(): _show(1, cp, Color(1.0, 0.6, 0.2), 0.2)
	bag_node.visible = true
	bag_node.translation = cp + Vector3(0, 2.35, 0)
	bag_node.rotation.y = G.REAL_T * 2.0
	if bag.carrier == me():
		if P.dead:
			var at2 = P.pos
			cur.bag = { "carrier": "", "at": at2 }
			if online(): main.net.send_mission({ "t": "mis_bag", "mid": cur.mid, "n": me(), "c": "", "x": at2.x, "z": at2.z })
			main.hud.banner("You dropped the bag", "")
			return
		# rivals come for whoever has it
		_wave_t -= dt
		if _wave_t <= 0:
			_wave_t = 28.0
			var sp = main.crews._spawn_point(30, 60)
			if sp != null:
				var c = main.turf._spawn_crew(-1, "lowend", sp, 3, 2, false)
				c.turf = -1
		if Vector2(P.pos.x - to.x, P.pos.z - to.z).length() < 7.0:
			_end_all(true, "@%s made the drop" % me())

# ---------------------------------------------------------------- Turf Raid
func _raid_setup():
	cur["end"] = cur.t0 + RAID_TIME
	cur["shared"] = 0.0
	main.hud.banner("Turf Raid", main.turf.block_name(int(cur.d.b)) + " · get to the corner")

func raid_block():
	return int(cur.d.b) if in_it() and cur.kind == "raid" and cur.phase == "run" else -1

func raid_owner():
	return cur.d.g if raid_block() >= 0 else null

func shared_progress():
	return float(cur.get("shared", 0.0)) if raid_block() >= 0 else 0.0

func _raid(dt, t):
	var T = main.turf
	var b = int(cur.d.b)
	var c = T.corners[b]
	if t > float(cur.end):
		_end_all(false, "Out of time"); return
	if T.is_mine(T.cur()[b]) or T.same(T.cur()[b], cur.d.g):
		_end_all(true, T.block_name(b) + " is ours"); return
	_show(0, c, KINDS.raid.col, 0.3)
	var P = main.player
	if T.take == null and not P.dead and T._dist(P.pos, c) < 12.0 and P.car == null:
		T.begin(b)
	if T.take != null and T.take.b == b:
		_send_t -= dt
		if _send_t <= 0:
			_send_t = 0.5
			cur.shared = max(float(cur.shared), T.take.p)
			if online(): main.net.send_mission({ "t": "mis_p", "mid": cur.mid, "p": stepify(T.take.p, 0.01) })

# the takeover finished on this screen (Turf.gd calls this)
func raid_won(b):
	if raid_block() == b: _end_all(true, main.turf.block_name(b) + " is ours")

# ---------------------------------------------------------------- the end
func _end_all(ok, why):
	if cur == null or cur.phase == "done": return
	if online(): main.net.send_mission({ "t": "mis_end", "mid": cur.mid, "n": me(), "ok": ok, "why": why })
	_finish(ok, why, me())

func _finish(ok, why, by):
	if cur == null or cur.phase == "done": return
	if not cur["in"]:
		cur.phase = "done"; cur["gone"] = now() + 1.0
		return
	if cur.kind == "race":
		if cur.phase != "done": _race_results()
		return
	var pay = 0
	if ok:
		pay = 900 if cur.kind == "drop" else 500
		if cur.kind == "raid":
			var T = main.turf
			var b = int(cur.d.b)
			if not T.same(T.cur()[b], cur.d.g): T.give(b, cur.d.g, T.shared() and cur.own)
			if T.take != null and T.take.b == b:
				for cr in T.take.crews:
					if cr in main.crews.CREWS: main.crews.send_home(cr)
				T.take = null
	_reward(pay, 3 if ok else 0)
	_end_local(why, ok, pay)

func _reward(cash, buzz):
	if cash > 0: main.story.add_cash(cash)
	if buzz > 0: main.story.add_buzz(buzz)
	G.S["stats"]["missions"] = int(G.S["stats"].get("missions", 0)) + 1
	if typeof(G.S.get("gang")) == TYPE_DICTIONARY and cash > 0: main.gang.rep(3)

func _end_local(why, ok, pay = 0):
	if cur == null: return
	cur.phase = "done"
	cur["gone"] = now() + 6.0
	cur["ok"] = ok
	_said.clear()
	var title = (KINDS[cur.kind].name + (" · done" if ok else " · failed"))
	main.hud.banner(title, why + ((" · +" + G.fmt_money(pay)) if pay > 0 else ""))
	main.sfx.play("cash" if ok else "notif", 0.6)
	G.save_game()

func reset():
	cur = null
	_said.clear()

# ---------------------------------------------------------------- what the HUD, the maps and the phone show
func _show(i, p, col, alpha):
	var b = beacons[i]
	b[0].visible = true
	b[0].translation = Vector3(p.x, W.ground_at(p.x, p.z, 0.6), p.z)
	_paint_beacon(i, col, alpha)

func target():
	if not in_it() or cur.phase != "run": return null
	if cur.kind == "race":
		var i = int(cur.get("me_cp", 1))
		return _pt(i) if i < route().pts.size() else null
	if cur.kind == "drop":
		return cur.bag.at if cur.bag.carrier == "" else loc(cur.d.to)
	if cur.kind == "raid": return main.turf.corners[int(cur.d.b)]
	return null

func target_col():
	if cur == null: return Color(1, 1, 1)
	if cur.kind == "drop" and cur.has("bag") and cur.bag.carrier == "": return Color(1.0, 0.6, 0.2)
	return KINDS[cur.kind].col

func _clock(s):
	s = max(0.0, float(s))
	return "%d:%04.1f" % [int(s) / 60, fmod(s, 60.0)]

func card():
	if cur == null or cur.phase == "done": return null
	var K = KINDS[cur.kind]
	var t = now()
	if cur.phase == "lobby":
		if not cur["in"]: return null
		return [K.name.to_upper() + " · LOBBY", "Starts in %d s · %d in" % [int(max(0, cur.at - t)), cur.joined.size()], 1.0 - (cur.at - t) / LOBBY, K.col]
	if not cur["in"]: return null
	if cur.kind == "race":
		var n = route().pts.size() - 1
		var cp = int(cur.get("me_cp", 1)) - 1
		var go = float(cur.go)
		var tm = max(0.0, t - go)
		var pl = place()
		return [route().name.to_upper(), "%s of %d · checkpoint %d/%d · %s" % [_place_name(pl), cur.joined.size(), min(cp, n), n, _clock(tm)], float(cp) / n, K.col]
	if cur.kind == "drop":
		var left = max(0.0, float(cur.end) - t)
		var who = cur.bag.carrier
		var sub = ("Get the bag · " if who == "" else ("You have the bag · " if who == me() else "@%s has the bag · " % who)) + "%d:%02d left" % [int(left) / 60, int(left) % 60]
		var tg = target()
		if tg != null: sub += " · %d m" % int(Vector2(main.player.pos.x - tg.x, main.player.pos.z - tg.z).length())
		return ["DROP RUN", sub, left / DROP_TIME, K.col if who != "" else Color(1.0, 0.6, 0.2)]
	if cur.kind == "raid":
		var left2 = max(0.0, float(cur.end) - t)
		var T = main.turf
		var pp = max(float(cur.shared), T.take.p if T.take != null else 0.0)
		return ["TURF RAID · " + T.block_name(int(cur.d.b)).to_upper(), "%d in the crew · %d:%02d left" % [cur.joined.size(), int(left2) / 60, int(left2) % 60], pp, K.col]
	return null
