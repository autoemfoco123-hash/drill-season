extends Node
# Turf. Calder Park's streets cut it into 16 blocks, and every block belongs to somebody: one of
# three made-up crews (Halo, Low End, Sable Row), nobody, Area 7 (the police station's block,
# which can't be taken), or, once you start taking corners, your gang.
#
#  - Taking a block: walk up to its corner (where its two streets meet, a ring on the sidewalk
#    in the owner's colour; rival corners have people standing on them) and hold E. The owner's
#    people come at you in waves. The bar fills while you hold the corner with nobody left
#    standing near it; leave the corner for 25 seconds, or go down, and the takeover fails.
#    You get the stash on the corner the moment it's yours.
#  - Every block you hold pays out at sunrise (6:00 on the shared clock).
#  - At night rivals raid your blocks. You get a warning and 2:30 to get there: beat the
#    raiders and you keep it, with a bonus. Don't make it, and your recruits who stay home (not
#    rolling with you, "holding the block" in the Gang app) defend it on their own: the more of
#    them, the better the odds.
#  - Online, on a server, everyone plays on one map. The host (or the dedicated server, which
#    saves it) keeps it and sends it to everyone who joins; players' gangs take blocks from the
#    crews and from each other, and a gang hears about it when someone starts taking its corner.
# Owners are "" (nobody), "halo", "lowend", "sable", "cops", or a gang: [id, name, tag, colour].

const N = 16
const COPS = 11
const CREW_IDS = ["halo", "lowend", "sable"]
const CREWS = {
	"halo": { "name": "Halo", "tag": "HALO", "col": Color(0.9, 0.26, 0.24), "look": [0x2a2d33, 0x3a1c20, 0x8a1c24], "pre": "@halo." },
	"lowend": { "name": "Low End", "tag": "LOW", "col": Color(0.95, 0.66, 0.24), "look": [0x3b2d1d, 0x2b2117, 0xc98a2a], "pre": "@lowend." },
	"sable": { "name": "Sable Row", "tag": "SBL", "col": Color(0.36, 0.52, 1.0), "look": [0x1b2338, 0x252f4c, 0x2c4fd6], "pre": "@sablerow." },
}
# west to east, north (Ironside Rd) to south (Sable St)
const DEFAULT = ["lowend", "lowend", "lowend", "lowend",
	"lowend", "", "halo", "halo",
	"halo", "", "halo", "cops",
	"sable", "sable", "sable", "sable"]
# what each block pays a day: the store and the studio's block the most
const VAL = [160, 180, 200, 170,
	200, 160, 320, 240,
	180, 180, 280, 0,
	160, 220, 190, 170]
const LINES = {
	"halo": ["Halo block. Keep walking.", "You lost?", "This ain't your corner.", "Saint know you out here?"],
	"lowend": ["Low End. Turn around.", "Wrong side of Ironside.", "Nothing for you over here.", "Keep it moving."],
	"sable": ["Sable Row. You heard of us.", "Not this block.", "Keep walking, rapper.", "We see you."],
	"gang": ["Our corner. Back up.", "You know whose block this is?", "Keep walking."],
}
const TAKE_OUT = 25.0       # seconds you can be off the corner during a takeover
const RAID_WARN = 150.0     # seconds to get to a raid

var main
var corners = []
var rings = []
var srv_map = []            # the server's map while on a server
var guards = {}             # block -> the crew standing on its corner
var guard_cd = {}           # block -> play time when its corner is staffed again
var safe = {}               # block -> play time until which it can't be raided
var take = null
var raid = null
var raid_t = 120.0
var raids_night = {}
var hold_t = 0.0
var hold_ms = 0
var bcast_t = 5.0
var _tick = 0.0
var _painted = []

# ---------------------------------------------------------------- shared helpers (Server.gd uses these too)
static func default_map():
	return DEFAULT.duplicate()

static func _ct(v, n):
	var out = ""
	for ch in str(v):
		if ch.ord_at(0) >= 32 and ch != "\\": out += ch
	return out.strip_edges().substr(0, n)

static func clean_owner(o):
	if typeof(o) == TYPE_STRING:
		return o if o in ["", "halo", "lowend", "sable"] else null
	if typeof(o) == TYPE_ARRAY and o.size() >= 4:
		var gid = _ct(o[0], 24)
		if gid == "": return null
		var c = 0
		if typeof(o[3]) in [TYPE_INT, TYPE_REAL]: c = int(clamp(o[3], 0, 7))
		return [gid, _ct(o[1], 18), _ct(o[2], 4).to_upper(), c]
	return null

static func clean_map(m):
	if typeof(m) != TYPE_ARRAY or m.size() != N: return null
	var out = []
	for b in range(N):
		if b == COPS:
			out.append("cops")
			continue
		var o = clean_owner(m[b])
		out.append(o if o != null else "")
	return out

static func same(a, b):
	return JSON.print(a) == JSON.print(b)

# ---------------------------------------------------------------- setup
func setup(m):
	main = m
	for b in range(N):
		var r = rect(b)
		var c = Vector3(r[0] + 8.0, 0, r[1] + 8.0)
		if W.is_blocked(c.x, c.z, 0.8):
			var found = false
			for k in range(1, 14):
				for p in [Vector3(r[0] + 8.0 + k * 1.5, 0, r[1] + 8.0), Vector3(r[0] + 8.0, 0, r[1] + 8.0 + k * 1.5)]:
					if not found and not W.is_blocked(p.x, p.z, 0.8):
						c = p; found = true
				if found: break
		c.y = W.ground_at(c.x, c.z, 0.6)
		corners.append(c)
	_build_rings()

func rect(b):
	var XL = G.D["XL"]
	var ZL = G.D["ZL"]
	var i = b % 4
	var j = int(b / 4)
	return [float(XL[i]), float(ZL[j]), float(XL[i + 1]), float(ZL[j + 1])]

func _short(s):
	var p = str(s).split(" ")
	if p.size() > 1: p.remove(p.size() - 1)
	return p.join(" ")

func block_name(b):
	return _short(G.D["XN"][b % 4]) + " & " + _short(G.D["ZN"][int(b / 4)])

func block_at(p):
	for b in range(N):
		var r = rect(b)
		if p.x >= r[0] and p.x < r[2] and p.z >= r[1] and p.z < r[3]: return b
	return -1

func _dist(a, b):
	return Vector2(a.x - b.x, a.z - b.z).length()

# ---------------------------------------------------------------- whose map, whose block
func shared():
	return main.net.server != null and main.net.welcomed

func cur():
	if shared():
		if srv_map.size() != N: srv_map = default_map()
		return srv_map
	if typeof(G.S.get("turf")) != TYPE_ARRAY or G.S["turf"].size() != N: G.S["turf"] = default_map()
	return G.S["turf"]

func my_gang():
	var g = G.S.get("gang")
	if typeof(g) != TYPE_DICTIONARY: return null
	return [str(g.id), str(g.name), str(g.tag), int(g.get("color", 0))]

func is_mine(o):
	var g = G.S.get("gang")
	return typeof(o) == TYPE_ARRAY and typeof(g) == TYPE_DICTIONARY and str(o[0]) == str(g.id)

func hostile(o):
	if typeof(o) == TYPE_ARRAY: return not is_mine(o)
	return o in CREW_IDS

func o_name(o):
	if typeof(o) == TYPE_ARRAY: return str(o[1])
	if o == "cops": return "Area 7"
	if CREWS.has(o): return CREWS[o].name
	return "Nobody"

func o_tag(o):
	if typeof(o) == TYPE_ARRAY: return str(o[2])
	if CREWS.has(o): return CREWS[o].tag
	return ""

func o_col(o):
	if typeof(o) == TYPE_ARRAY:
		var cols = G.D["GANG_COLORS"]
		return Color(cols[int(o[3]) % cols.size()])
	if o == "cops": return Color(0.4, 0.6, 1.0)
	if CREWS.has(o): return CREWS[o].col
	return Color(0.9, 0.92, 0.95)

func my_blocks():
	var out = []
	var m = cur()
	for b in range(N):
		if is_mine(m[b]): out.append(b)
	return out

func daily():
	var t = 0
	for b in my_blocks(): t += VAL[b]
	return t

func give(b, o, send = true):
	if b == COPS or b < 0 or b >= N or o == null: return
	var m = cur()
	m[b] = o
	_paint(b)
	if shared() and send: main.net.send_turf(b, o)

# ---------------------------------------------------------------- the rings on the corners
func _ring_mesh(r0, r1, n):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(n):
		var a0 = TAU * i / float(n)
		var a1 = TAU * (i + 1) / float(n)
		var p00 = Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p01 = Vector3(cos(a0) * r1, 0, sin(a0) * r1)
		var p10 = Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var p11 = Vector3(cos(a1) * r1, 0, sin(a1) * r1)
		for p in [p00, p10, p11, p00, p11, p01]:
			st.add_normal(Vector3.UP)
			st.add_vertex(p)
	return st.commit()

func _build_rings():
	var ring = _ring_mesh(2.0, 2.4, 40)
	var disc = CylinderMesh.new(); disc.top_radius = 2.0; disc.bottom_radius = 2.0; disc.height = 0.01; disc.radial_segments = 32; disc.rings = 1
	for b in range(N):
		var root = Spatial.new(); root.name = "Turf%d" % b
		root.translation = corners[b] + Vector3(0, 0.05, 0)
		var m1 = SpatialMaterial.new(); m1.flags_unshaded = true; m1.flags_transparent = true; m1.params_cull_mode = SpatialMaterial.CULL_DISABLED
		var m2 = m1.duplicate()
		var md = MeshInstance.new(); md.mesh = disc; md.material_override = m2; md.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		var mr = MeshInstance.new(); mr.mesh = ring; mr.material_override = m1; mr.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		root.add_child(md); root.add_child(mr)
		main.add_child(root)
		rings.append([root, m1, m2])
		_painted.append(null)
		_paint_as(b, DEFAULT[b])       # the title screen shows the crews' map

func _is(o, s):
	return typeof(o) == TYPE_STRING and o == s

func _paint(b):
	if rings.size() <= b: return
	_paint_as(b, cur()[b])

func _paint_as(b, o):
	var r = rings[b]
	r[0].visible = not _is(o, "cops")
	var c = o_col(o)
	var nobody = _is(o, "")
	r[1].albedo_color = Color(c.r, c.g, c.b, 0.4 if nobody else 0.85)
	r[2].albedo_color = Color(c.r, c.g, c.b, 0.05 if nobody else (0.22 if is_mine(o) else 0.13))
	_painted[b] = JSON.print(o)

# ---------------------------------------------------------------- the session
func reset():
	take = null; raid = null; hold_t = 0.0
	guards.clear(); guard_cd.clear(); safe.clear()
	raid_t = 120.0
	for b in range(N): _paint(b)

func new_server_map():
	srv_map = default_map()
	for b in range(N): _paint(b)

func load_map(m):
	var c = clean_map(m)
	srv_map = c if c != null else default_map()
	for b in range(N): _paint(b)

func update(dt):
	if G.MODE == "title" or rings.empty(): return
	var m = cur()
	_tick -= dt
	if _tick <= 0:
		_tick = 0.5
		# your gang's blocks go back to nobody if you leave it (playing on your own)
		if not shared():
			for b in range(N):
				if typeof(m[b]) == TYPE_ARRAY and not is_mine(m[b]): m[b] = ""
		for b in range(N):
			if _painted[b] != JSON.print(m[b]): _paint(b)
		_guards()
	_hold(dt)
	if take != null: _take_update(dt)
	_raid_update(dt)
	# the raided corner pulses
	for b in range(N):
		var on = raid != null and raid.b == b
		var k = 0.5 + 0.5 * sin(G.REAL_T * 6.0) if on else 1.0
		rings[b][0].scale = Vector3.ONE * (1.0 + 0.12 * k if on else 1.0)
	if shared() and main.net.hosting:
		bcast_t -= dt
		if bcast_t <= 0:
			bcast_t = 30.0
			main.net.send_turfmap(m)

# ---------------------------------------------------------------- people on the corners
func _alive(c):
	var n = 0
	for e in c.members:
		if not e.is_down(): n += 1
	return n

func _look(o):
	if typeof(o) == TYPE_ARRAY:
		var c = o_col(o)
		var d = c.darkened(0.6)
		return [_hex(d), 0x15171a, _hex(c)]
	return CREWS[o].look if CREWS.has(o) else CREWS["halo"].look

func _hex(c):
	return (int(c.r8) << 16) | (int(c.g8) << 8) | int(c.b8)

func _handles(o):
	var out = []
	var names = main.gang.FIRST
	for _i in range(8):
		var nm = str(G.pick(names)).to_lower()
		if typeof(o) == TYPE_ARRAY: out.append("@%s.%s" % [str(o[2]).to_lower(), nm])
		else: out.append((CREWS[o].pre if CREWS.has(o) else "@") + nm)
	return out

func _spawn_crew(b, o, at, n, shooters, guard):
	var opts = { "turf": b, "guard": guard, "combat": not guard, "look": _look(o), "handles": _handles(o),
		"lines": LINES["gang"] if typeof(o) == TYPE_ARRAY else LINES.get(o, LINES["gang"]), "col": o_col(o) }
	return main.crews.spawn_crew(at, n, shooters, opts)

func _spot_near(c, r0, r1, keep = 14.0):
	var P = main.player
	for k in range(48):
		var a = G.rand(0, TAU)
		var r = G.rand(r0, r1)
		var p = c + Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = 0
		if abs(p.x) > W.BOUND - 7 or abs(p.z) > W.BOUND - 7 or p.x > G.D["SHORE_X"] + 8: continue
		if W.is_blocked(p.x, p.z, 0.6): continue
		if _dist(p, P.pos) < keep: continue
		# out of sight if we can
		if k < 30 and W.seg_clear(P.pos + Vector3(0, 1.5, 0), p + Vector3(0, 1.5, 0)): continue
		return p
	var sp = main.crews._spawn_point(18, 45)
	return sp if sp != null else Vector3(c.x, 0, c.z)

func _guards():
	var P = main.player
	var m = cur()
	var inside = main.interiors != null and main.interiors.inside != ""
	for b in range(N):
		var d = _dist(P.pos, corners[b])
		var g = guards.get(b)
		if g != null:
			if not g in main.crews.CREWS:
				guards.erase(b)
			elif _alive(g) == 0:
				guards.erase(b); guard_cd[b] = float(G.S["playTime"]) + 240.0
			elif g.state == "guard" and (d > 120 or not hostile(m[b]) or inside):
				main.crews.despawn(g); guards.erase(b)
			continue
		if not hostile(m[b]) or inside or G.MODE != "play": continue
		if d < 28 or d > 80: continue
		if P.car != null and abs(P.car.speed) > 9: continue
		if guards.size() >= 2: continue
		if float(guard_cd.get(b, 0)) > float(G.S["playTime"]): continue
		if take != null and take.b == b: continue
		if raid != null and raid.b == b: continue
		guards[b] = _spawn_crew(b, m[b], corners[b], 3 if VAL[b] >= 250 else 2, 0, true)

func tags():
	var out = []
	if rings.empty(): return out
	var P = main.player
	var m = cur()
	for b in range(N):
		var o = m[b]
		if _is(o, "cops") or _dist(P.pos, corners[b]) > 34: continue
		var sub = "YOUR TURF" if is_mine(o) else ("NOBODY'S CORNER" if _is(o, "") else o_name(o).to_upper() + " TURF")
		out.append([corners[b] - Vector3(0, 0.4, 0), block_name(b), sub, o_col(o)])
	return out

# ---------------------------------------------------------------- taking a block
func corner_here():
	var P = main.player
	if P.car or P.dead or rings.empty(): return -1
	for b in range(N):
		if _dist(P.pos, corners[b]) < 3.4 and abs(P.pos.y - corners[b].y) < 2.0: return b
	return -1

func can_take(b):
	var o = cur()[b]
	if typeof(o) == TYPE_STRING and o == "cops": return "cops"
	if is_mine(o): return "yours"
	if my_gang() == null: return "nogang"
	if raid != null and raid.stage == "fight": return "raid"
	return ""

func prompt(key):
	if take != null or G.MODE != "play": return ""
	var b = corner_here()
	if b < 0: return ""
	var o = cur()[b]
	var why = can_take(b)
	if why == "cops": return "Area 7 · police turf"
	if why == "yours": return "Your turf · %s · pays %s a day" % [block_name(b), G.fmt_money(VAL[b])]
	if why == "nogang": return "%s · %s turf\nStart a gang (Phone → Gang) to take it" % [block_name(b), o_name(o)]
	if why != "": return ""
	return "%s Hold to take %s%s" % [key, block_name(b), ("  %d%%" % int(hold_t * 100)) if hold_t > 0 else ""]

# a one-second hold, in real time (slow phones run the game clock slower)
func _hold(_dt):
	var b = corner_here()
	if b >= 0 and G.MODE == "play" and take == null and can_take(b) == "" and Input.is_action_pressed("use"):
		if hold_ms == 0: hold_ms = OS.get_ticks_msec()
		hold_t = (OS.get_ticks_msec() - hold_ms) / 1000.0
		if hold_t >= 1.0:
			hold_t = 0.0; hold_ms = 0
			begin(b)
	else:
		hold_t = 0.0; hold_ms = 0

func _neighbor_crew(b):
	var m = cur()
	var count = {}
	var i = b % 4
	var j = int(b / 4)
	for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
		var ii = i + d[0]
		var jj = j + d[1]
		if ii < 0 or ii > 3 or jj < 0 or jj > 3: continue
		var o = m[jj * 4 + ii]
		if typeof(o) == TYPE_STRING and o in CREW_IDS: count[o] = int(count.get(o, 0)) + 1
	var best = ""
	var bn = 0
	for k in count.keys():
		if count[k] > bn:
			bn = count[k]; best = k
	return best if best != "" else G.pick(CREW_IDS)

func begin(b):
	var o = cur()[b]
	var att = o
	var waves = []
	var need = 50.0
	if typeof(o) == TYPE_STRING and o == "":
		att = _neighbor_crew(b)          # whoever is next door wants it too
		waves = [[0.3, 2, 0]]
		need = 30.0
	elif typeof(o) == TYPE_ARRAY:
		waves = [[0.0, 2, 0], [0.4, 3, 1], [0.75, 3, 1]]
		need = 60.0
	else:
		waves = [[0.0, 2, 0], [0.35, 3, 1], [0.7, 3, 1 if VAL[b] < 250 else 2]]
	take = { "b": b, "p": 0.0, "need": need, "o": o, "att": att, "waves": waves, "w": 0, "crews": [], "out": 0.0, "foes": 0 }
	var g = guards.get(b)
	if g != null and g in main.crews.CREWS and _alive(g) > 0:
		main.crews.engage(g, "turf")
		take.crews.append(g)
		if waves[0][0] == 0.0: take.w = 1      # the people on the corner are the first wave
	guards.erase(b)
	main.hud.banner("Taking " + block_name(b), ("Nobody's corner. Hold it." if att != o else o_name(o) + " turf. Hold the corner, clear the block."))
	main.sfx.play("whoosh", 0.4)
	main.story.add_heat(3)
	if shared() and typeof(o) == TYPE_ARRAY: main.net.send_turfhit(b, o)

func _foes_near(c, r):
	var n = 0
	for cr in take.crews:
		if not cr in main.crews.CREWS or cr.state == "leave": continue
		for e in cr.members:
			if not e.is_down() and _dist(e.pos, c) < r: n += 1
	return n

func _take_update(dt):
	var P = main.player
	var b = take.b
	var c = corners[b]
	if is_mine(cur()[b]):         # a gang mate got it first
		take = null; return
	if P.dead:
		_fail("You went down"); return
	var inz = _dist(P.pos, c) < 16.0 and P.car == null
	var foes = _foes_near(c, 40.0)
	take.foes = foes
	if inz:
		take.out = 0.0
		if foes == 0: take.p = min(1.0, take.p + dt / take.need)
	else:
		take.out += dt
		if take.out > TAKE_OUT:
			_fail("You left the corner"); return
	while take.w < take.waves.size() and take.p >= take.waves[take.w][0]:
		var wv = take.waves[take.w]
		take.w += 1
		if wv[1] <= 0: continue
		var cr = _spawn_crew(b, take.att, _spot_near(c, 24, 42), wv[1], wv[2], false)
		take.crews.append(cr)
		var L = main.crews.leader(cr)
		if L and take.w > 1: main.hud.say(L.name, G.pick(["Get off our corner.", "Y'all thought.", "Run it back.", "Who said you could stand there?"]))
	if take.p >= 1.0 and foes == 0: _win()

func _win():
	var b = take.b
	var old = take.o
	var g = my_gang()
	if g == null:
		take = null; return
	give(b, g)
	for cr in take.crews:
		if cr in main.crews.CREWS: main.crews.send_home(cr)
	take = null
	var stash = int(VAL[b] * 0.6)
	main.story.add_cash(stash)
	main.story.add_heat(5)
	main.gang.rep(8)
	G.S["stats"]["turfTaken"] = int(G.S["stats"].get("turfTaken", 0)) + 1
	safe[b] = float(G.S["playTime"]) + 300.0
	main.hud.banner("Took " + block_name(b), "[%s] · %s off the corner · %s a day" % [g[2], G.fmt_money(stash), G.fmt_money(VAL[b])])
	main.sfx.play("cash", 0.5)
	var S = main.story
	if typeof(old) == TYPE_STRING and old == "halo":
		S.later(6, S, "send_msg", ["saint", G.pick(["%s? Enjoy it while it lasts." % block_name(b), "You took a corner. Now you gotta hold it.", "That block was mine before you could spell drill.", "We'll be by tonight."])])
	S.later(4, S, "post_feed", [G.pick(G.D["FEED_HANDLES"]), G.pick(["new colours on %s this morning" % block_name(b), "%s got a new owner?? [%s]" % [block_name(b), g[2]], "y'all see who's standing on %s now" % block_name(b)])])
	G.save_game()

func _fail(why):
	var b = take.b
	take = null
	main.hud.banner("Lost the corner", why + " · " + block_name(b))

# ---------------------------------------------------------------- raids at night
func _night_key():
	var m = G.world_minutes()
	if m >= 18 * 60 or m < 5 * 60: return int(G.S.get("day", 1))
	return -1

func _raid_update(dt):
	if G.MODE == "cutscene" or G.MODE == "title": return
	if raid != null:
		_raid_tick(dt); return
	var nk = _night_key()
	if nk < 0 or take != null: return
	var mine = my_blocks()
	if mine.empty(): return
	raid_t -= dt
	if raid_t > 0: return
	raid_t = G.rand(160, 280)
	if int(raids_night.get(nk, 0)) >= (2 if mine.size() >= 3 else 1): return
	if randf() > clamp(0.45 + 0.08 * mine.size(), 0.45, 0.85): return
	var pool = []
	for b in mine:
		if float(safe.get(b, 0)) <= float(G.S["playTime"]): pool.append(b)
	if pool.empty(): return
	raids_night[nk] = int(raids_night.get(nk, 0)) + 1
	start_raid(G.pick(pool))

func start_raid(b, fac = ""):
	if fac == "": fac = _neighbor_crew(b)
	raid = { "b": b, "fac": fac, "left": RAID_WARN, "stage": "warn", "crews": [], "n": 0 }
	var g = guards.get(b)
	if g != null:
		main.crews.despawn(g); guards.erase(b)
	main.hud.banner("%s are rolling on %s" % [CREWS[fac].name, block_name(b)], "Get there in 2:30 or your people hold it alone")
	main.hud.toast("Lookout:  %s on the way to %s. Pull up." % [CREWS[fac].name, block_name(b)])

func home_recruits():
	var n = 0
	for r in G.S.get("recruits", []):
		if not r.get("with", false) and float(r.get("hurtUntil", 0)) <= float(G.S.get("playTime", 0)): n += 1
	return n

func _raid_tick(dt):
	var P = main.player
	var b = raid.b
	var c = corners[b]
	if not is_mine(cur()[b]):
		raid = null; return
	var d = _dist(P.pos, c)
	var inside = main.interiors != null and main.interiors.inside != ""
	if raid.stage == "warn":
		raid.left -= dt
		if d < 60 and not inside and not P.dead:
			raid.stage = "fight"
			var nb = my_blocks().size()
			var n = 3 + (1 if nb >= 3 else 0) + (1 if nb >= 6 else 0)
			var cr = _spawn_crew(b, raid.fac, _spot_near(c, 6, 18, 12.0), n, 1 if n <= 3 else 2, false)
			raid.crews.append(cr); raid.n = n
			main.hud.banner("Defend " + block_name(b), "%d from %s on your corner" % [n, CREWS[raid.fac].name])
		elif raid.left <= 0:
			_raid_auto(0.0)
	else:
		var alive = 0
		for cr in raid.crews:
			if cr in main.crews.CREWS: alive += _alive(cr)
		raid["alive"] = alive
		if alive == 0: _raid_held()
		elif P.dead: _raid_lost("You went down")
		elif d > 150: _raid_auto(-0.1)

func _raid_held():
	var b = raid.b
	raid = null
	var bonus = int(VAL[b] * 0.4)
	main.story.add_cash(bonus)
	main.gang.rep(5)
	G.S["stats"]["raidsHeld"] = int(G.S["stats"].get("raidsHeld", 0)) + 1
	safe[b] = float(G.S["playTime"]) + 240.0
	main.hud.banner("Held " + block_name(b), "+" + G.fmt_money(bonus) + " · they won't try that again tonight")

func _raid_lost(why):
	var b = raid.b
	var fac = raid.fac
	for cr in raid.crews:
		if cr in main.crews.CREWS: main.crews.send_home(cr)
	raid = null
	give(b, fac)
	main.hud.banner("Lost " + block_name(b), "%s took it · %s" % [CREWS[fac].name, why])
	G.save_game()

func _raid_auto(bonus):
	var b = raid.b
	var home = home_recruits()
	var p = clamp(0.2 + 0.15 * home + bonus, 0.1, 0.8)
	if randf() < p:
		for cr in raid.crews:
			if cr in main.crews.CREWS: main.crews.send_home(cr)
		raid = null
		main.gang.rep(2)
		safe[b] = float(G.S["playTime"]) + 240.0
		main.hud.toast("Turf:  your people held %s (%d on the block)" % [block_name(b), home])
	else:
		_raid_lost("nobody got there in time" if home == 0 else "%d of yours couldn't hold it" % home)

# ---------------------------------------------------------------- sunrise
func payday():
	var mine = my_blocks()
	if mine.empty(): return
	var total = daily()
	main.story.add_cash(total)
	main.gang.rep(mine.size())
	G.S["stats"]["turfPaid"] = int(G.S["stats"].get("turfPaid", 0)) + total
	main.hud.toast("Turf:  %d %s paid %s" % [mine.size(), "block" if mine.size() == 1 else "blocks", G.fmt_money(total)])

func payday_in():
	var m = G.world_minutes()
	return fposmod(360.0 - m, 1440.0)

# ---------------------------------------------------------------- the HUD card
func card():
	if take != null:
		var sub = "Hold the corner"
		if take.out > 0: sub = "Back to the corner · %d s" % int(ceil(TAKE_OUT - take.out))
		elif take.foes > 0: sub = "Clear the block · %d left" % take.foes
		var g = my_gang()
		return ["TAKING " + block_name(take.b).to_upper(), sub, take.p, o_col(g) if g != null else Color(1, 1, 1)]
	if raid != null:
		var col = CREWS[raid.fac].col
		if raid.stage == "warn":
			var d = int(_dist(main.player.pos, corners[raid.b]))
			return ["%s RAID · %s" % [CREWS[raid.fac].name.to_upper(), block_name(raid.b).to_upper()], "%d:%02d to get there · %d m" % [int(raid.left) / 60, int(raid.left) % 60, d], raid.left / RAID_WARN, col]
		var alive = int(raid.get("alive", raid.n))
		return ["DEFEND " + block_name(raid.b).to_upper(), "%d left" % alive, 1.0 - alive / float(max(1, raid.n)), col]
	return null

# ---------------------------------------------------------------- online
func _num(v):
	return float(v) if typeof(v) in [TYPE_INT, TYPE_REAL] else -1.0

func net_event(t, r, from_host, e):
	if not shared() or rings.empty(): return
	if t == "turfmap":
		if not from_host: return
		var m = clean_map(e.get("m"))
		if m == null: return
		if srv_map.size() != N: srv_map = default_map()
		for b in range(N):
			if not same(srv_map[b], m[b]):
				var was = srv_map[b]
				srv_map[b] = m[b]
				_paint(b)
				_notify(b, was, m[b], null)
	elif t == "turf":
		if r == null and not from_host: return
		var b = int(_num(e.get("b")))
		if b < 0 or b >= N or b == COPS: return
		var o = clean_owner(e.get("o"))
		if o == null: return
		var m2 = cur()
		if same(m2[b], o): return
		var was2 = m2[b]
		m2[b] = o
		_paint(b)
		_notify(b, was2, o, r)
	elif t == "turfhit":
		var b3 = int(_num(e.get("b")))
		var o3 = clean_owner(e.get("o"))
		if b3 < 0 or b3 >= N or o3 == null or not is_mine(o3): return
		var who = ("@" + r.name) if r != null else "Somebody"
		var g3 = clean_owner(e.get("g"))
		main.hud.banner("%s is on your corner" % who, "%s%s · %s" % [("[" + g3[2] + "] ") if g3 != null else "", block_name(b3), "get there"])
		main.hud.toast("Lookout:  %s is taking %s" % [who, block_name(b3)])

func _notify(b, was, now, r):
	var by = ("@" + r.name + " · ") if r != null else ""
	if is_mine(was) and not is_mine(now):
		if raid != null and raid.b == b: raid = null
		main.hud.banner("Lost " + block_name(b), by + o_name(now) + " took it")
	elif is_mine(now) and not is_mine(was):
		main.hud.toast("Turf:  %syour gang took %s" % [by, block_name(b)])
	elif typeof(now) == TYPE_ARRAY:
		main.hud.toast("Turf:  %s[%s] %s took %s" % [by, now[2], now[1], block_name(b)])
