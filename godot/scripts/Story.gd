extends Node
# The story, ported from the web game (80_systems.js, 90_ui.js): the cast and their texts,
# the Blok feed's block chatter, jobs (studio, diss deal, video shoot, merch drop, walking your
# sister home, laying low, the rec showcase, the detective, the pond), the cold and the wind,
# the places you can go into, and the four endings.

var main
var NPCS = {}
var beacons = {}
var video_rings = []
var _later = []
var tick_t = 1.0
var stream_t = 30.0
var last_min = -1
var ambient_feed_t = 50.0
var frost_warn_t = 0.0
var exposure_t = 0.0
var exposure = 1.0
var warm_label = null
var pending_ending = null
var ending_box = null
var WIND = { "gust": 0.1, "target": 0.1, "t": 6.0, "phase": "calm", "dx": -0.96, "dz": 0.28 }
const WIND_BASE = -1.2869

func setup(m):
	main = m

func D(k): return G.D[k]
func cast(k): return G.D["CAST"][k]
func n_(): return "@" + str(G.S["name"])
func S(): return G.S

# ---------- small helpers ----------
func later(sec, obj, method, args = []):
	_later.append({ "t": sec, "o": obj, "m": method, "a": args })

func _tick_later(dt):
	for L in _later.duplicate():
		L.t -= dt
		if L.t <= 0:
			_later.erase(L)
			if is_instance_valid(L.o) and G.MODE != "title": L.o.callv(L.m, L.a)

func add_heat(v):
	if v == 0: return
	G.S["heat"] = clamp(float(G.S["heat"]) + v, 0, 100)
	G.S["stats"]["heatPeak"] = max(float(G.S["stats"].get("heatPeak", 0)), G.S["heat"])
	if G.S["heat"] >= 100 and pending_ending == null and G.MODE == "play":
		trigger_ending("locked")

func add_buzz(v):
	G.S["buzz"] = clamp(float(G.S["buzz"]) + v, 0, 100)
	G.S["stats"]["buzzPeak"] = max(float(G.S["stats"].get("buzzPeak", 0)), G.S["buzz"])

func add_cash(v):
	G.S["cash"] = int(G.S["cash"]) + int(v)
	if v > 0:
		G.S["stats"]["cashEarned"] = int(G.S["stats"].get("cashEarned", 0)) + int(v)
		main.sfx.play("cash", 0.45)

func cd_left(key):
	return max(0.0, float(G.S["cd"].get(key, 0)) - float(G.S["playTime"]))

func set_cd(key, s):
	G.S["cd"][key] = float(G.S["playTime"]) + s

func send_msg(who, text, quiet = false):
	var th = G.S["threads"]
	if not th.has(who): th[who] = []
	th[who].append({ "t": G.S["playTime"], "text": text })
	if th[who].size() > 40: th[who].pop_front()
	var reading = main.phone.panel.visible and main.phone.app == "msgs" and main.phone.thread == who
	if not reading:
		G.S["unread"][who] = int(G.S["unread"].get(who, 0)) + 1
	if not quiet or G.MODE == "play":
		main.hud.toast(cast(who).name + ":  " + text)
		main.sfx.play("msg_in", 0.4)

func post_feed(handle, text):
	G.S["feed"].push_front({ "h": handle, "text": text, "at": OS.get_unix_time() * 1000, "likes": int(G.rand(3, 40) * (1 + float(G.S["buzz"]) / 12.0)) })
	while G.S["feed"].size() > 50: G.S["feed"].pop_back()

func say_cast(key, text):
	main.hud.say(cast(key).name, text)

func npc_lines(key):
	var S = G.S
	var P = main.player
	if key == "benny":
		if S.heat >= 60: return ["Cars been parked outside all night. Chill.", "I can't have detectives on my steps, man."]
		if S.heat >= 30: return ["People asking about you. Keep it in the music.", "Don't bring that energy downstairs."]
		if S.buzz >= 50: return ["Numbers looking crazy. Don't fumble it.", "Everybody wants a feature now."]
		return ["Booth is warm. Come lay something.", "I cooked a new 808. It slides crazy.", "Shovel the steps on your way in."]
	if key == "coach":
		if S.heat >= 40: return ["I hear your name in places I don't like.", "Walk away more. It's not weakness."]
		if S.buzz >= 60 and S.heat <= 25: return ["The showcase slot is yours if you want it."]
		if S.buzz >= 60: return ["Get your Heat down and the showcase is yours."]
		return ["Fire is going. Warm your hands.", "Rec closes at ten. Your sister is still inside.", "Kids been asking when you coming back to the court."]
	if main.crews.CREWS.size() > 0 and _in_fight(): return ["What is happening?!", "Get down!"]
	if S.heat >= 50: return ["Why are those guys staring?", "Can we just go home?"]
	return ["It's brick out here.", "Did you really make that song?", "Walk faster, my toes are numb.", "Mama made greens tonight.", "Everybody at the rec knows your songs."]

func _in_fight():
	for c in main.crews.CREWS:
		if c.state == "combat": return true
	return false

func vance_pay(): return 1200 + int(G.S["stats"].get("disses", 0)) * 300

# ---------- the cast on the street ----------
func _mk_npc(key, look, x, z, yaw):
	var h = load("res://scripts/Human.gd").new().build(look)
	main.add_child(h)
	h.translation = Vector3(x, 0, z); h.rotation = Vector3(0, yaw, 0)
	var n = { "key": key, "h": h, "home": Vector3(x, 0, z), "yaw": yaw, "pos": Vector3(x, 0, z), "vel": Vector3(), "radius": 0.3, "height": 1.4, "on_ground": true, "air_y": 0.0, "line_t": 0.0, "wave_t": 0.0, "trail": [] }
	NPCS[key] = n
	return n

func build_npcs():
	if NPCS.size() > 0: return
	var BP = G.D["BENNY_POS"]
	var CP = G.D["COACH_POS"]
	var L = G.D["LOC"]
	_mk_npc("benny", { "jacket": 0x3a2a1e, "jacket2": 0x4a3626, "pants": 0x2a2a2a, "skin": 0x8a5a3a, "hat": 0x222222, "scale": 1.05 }, BP.x, BP.z, 0.3)
	_mk_npc("coach", { "jacket": 0x1d4a32, "jacket2": 0x255c3e, "pants": 0x1d2a22, "skin": 0x5a3a26, "hat": 0x1d4a32 }, CP.x, CP.z, 2.4)
	_mk_npc("kiara", { "jacket": 0x6a3a9a, "jacket2": 0x7d4ab0, "pants": 0x22243a, "skin": 0x6b4630, "hat": 0xf0e6ff, "pom": 0xc79bff, "pack": 0x2a6a8a, "scale": 0.8 }, L.rec.x + 0.2, L.rec.z - 1.8, PI / 2)
	_mk_npc("reyes", { "jacket": 0x2a2e36, "jacket2": 0x30353e, "pants": 0x1a1c22, "skin": 0x9a6a48, "coat": true }, L.reyes.x, L.reyes.z, PI)
	NPCS.kiara.h.visible = false; NPCS.reyes.h.visible = false
	_build_beacons()

func _face(n, target, dt, k):
	var want = atan2(target.x - n.h.translation.x, target.z - n.h.translation.z)
	n.h.rotation.y += G.ang_diff(n.h.rotation.y, want) * (1 - exp(-dt * k))

func _update_npcs(dt):
	var P = main.player
	for key in ["benny", "coach"]:
		var n = NPCS[key]
		var d = Vector2(n.h.translation.x - P.pos.x, n.h.translation.z - P.pos.z).length()
		n.line_t -= dt
		if d < 7 and n.line_t <= 0 and G.MODE == "play":
			n.line_t = 45; say_cast(key, G.pick(npc_lines(key)))
		if d < 9: _face(n, P.pos, dt, 3)
		n.wave_t = max(0, n.wave_t - dt)
		n.h.visible = d < 90
		if n.h.visible: n.h.animate(dt, { "speed": 0, "mug": key == "benny" and n.wave_t <= 0, "wave": n.wave_t > 0 })
	var R = NPCS.reyes
	R.h.visible = job_available("reyes")
	if R.h.visible:
		_face(R, P.pos, dt, 2); R.h.animate(dt, { "speed": 0 })
	var K = NPCS.kiara
	var escort = G.S["job"] != null and G.S["job"].id == "kiara"
	K.h.visible = escort or (G.S["flags"].get("kiaraAsk", false) and not escort)
	var L = G.D["LOC"]
	if not escort:
		if K.h.visible:
			K.pos = Vector3(L.rec.x + 0.2, 0, L.rec.z - 1.8); K.h.translation = K.pos
			K.h.animate(dt, { "speed": 0, "wave": Vector2(P.pos.x - K.pos.x, P.pos.z - K.pos.z).length() < 18 })
		return
	var tr = K.trail
	if tr.size() == 0 or Vector2(tr[-1].x - P.pos.x, tr[-1].z - P.pos.z).length() > 0.6: tr.append(P.pos)
	var dP = Vector2(P.pos.x - K.pos.x, P.pos.z - K.pos.z).length()
	while tr.size() > 1 and Vector2(tr[0].x - K.pos.x, tr[0].z - K.pos.z).length() < 0.8: tr.pop_front()
	if dP > 45 and tr.size() > 0:
		K.pos = tr[max(0, tr.size() - 6)]; tr.clear()
	var vx = 0.0
	var vz = 0.0
	if dP > 2.4 and tr.size() > 0:
		var t = tr[0]
		var dv = Vector2(t.x - K.pos.x, t.z - K.pos.z)
		var sp = 6.8 if dP > 9 else 4.4
		if dv.length() > 0.01:
			dv = dv.normalized() * sp; vx = dv.x; vz = dv.y
	var k = 1 - exp(-dt * 8)
	K.vel.x += (vx - K.vel.x) * k; K.vel.z += (vz - K.vel.z) * k
	W.move_body(K, K.vel.x * dt, K.vel.z * dt, dt)
	var spd = Vector2(K.vel.x, K.vel.z).length()
	K.h.translation = K.pos
	if spd > 0.3: K.h.rotation.y += G.ang_diff(K.h.rotation.y, atan2(K.vel.x, K.vel.z)) * (1 - exp(-dt * 10))
	K.h.animate(dt, { "speed": spd, "crouch": _in_fight() and spd < 0.5 })
	K.line_t -= dt
	if K.line_t <= 0:
		K.line_t = G.rand(16, 26); say_cast("kiara", G.pick(npc_lines("kiara")))

# ---------- jobs ----------
const JOB_IDS = ["studio", "diss", "video", "kiara", "merch", "laylow", "showcase", "reyes", "saint"]
const JOB_GIVER = { "studio": "benny", "diss": "vance", "video": "benny", "kiara": "kiara", "merch": "benny", "laylow": "reyes", "showcase": "coach", "reyes": "reyes", "saint": "saint" }
const JOB_TITLE = { "studio": "Studio session", "diss": "Diss deal", "video": "Video shoot", "kiara": "Walk sis home", "merch": "Merch drop", "laylow": "Lay low", "showcase": "Rec showcase", "reyes": "Meet the detective", "saint": "The pond" }
const JOB_CD = { "studio": "studio", "diss": "studio", "video": "video", "merch": "merch", "laylow": "laylow" }

func job_desc(id):
	var C = G.D["CAST"]
	match id:
		"studio": return "Booth is open at Basement 808. Pick a verse and lay it down."
		"diss": return "%s pays %s for a diss aimed at %s. Record it at Basement 808." % [C.vance.name, G.fmt_money(vance_pay()), C.saint.name]
		"video": return "Shoot on the Calder L platform. Hit 3 marks. A train in the shot is a bonus. Costs $150."
		"kiara": return "%s is at the rec center. Walk her home to Bishop St." % C.kiara.name
		"merch": return "Pick up hoodies at Basement 808. Drop them at 3 spots before the timer runs out."
		"laylow": return "Go home and stay in for a while. Heat drops."
		"showcase": return "%s saved you a slot. Perform clean." % C.coach.name
		"reyes": return "%s wants to talk under the L at Low End Rd. Come alone." % C.reyes.name
		"saint": return "%s is waiting at the Calder Park pond." % C.saint.name
	return ""

func job_reward(id):
	return { "studio": "Buzz + · Streams $", "diss": "Buzz ++ · Heat ++ · " + G.fmt_money(vance_pay()), "video": "Buzz + · cold up there", "kiara": "Heat −12", "merch": "Buzz + · $360+",
		"laylow": "Heat −20", "showcase": "Ending: Way Out", "reyes": "Ending: Witness", "saint": "Ending: Crown" }.get(id, "")

func job_lock(id):
	if id == "showcase":
		if G.S["flags"].get("showcaseDone", false): return "You already did the showcase"
		return "Needs Buzz 60+ and Heat 25 or less (now %d / %d)" % [int(G.S["buzz"]), int(G.S["heat"])]
	if id == "reyes": return "Shows up at Heat 80+"
	if id == "saint": return "Unlocks after two diss tracks"
	if id == "video" or id == "merch": return "Release a track first"
	if id == "diss": return "Get your Buzz to 15"
	if id == "kiara": return "She texts when she needs a ride"
	return ""

func _avail(id):
	var S = G.S
	var F = S["flags"]
	match id:
		"studio", "laylow": return true
		"diss": return F.get("vanceOffer", false)
		"video", "merch": return int(S["stats"].get("tracks", 0)) >= 1
		"kiara": return F.get("kiaraAsk", false) or (S["job"] != null and S["job"].id == "kiara")
		"showcase": return S.buzz >= 60 and S.heat <= 25 and not F.get("showcaseDone", false)
		"reyes": return S.heat >= 80 and F.get("reyesOffer", false)
		"saint": return F.get("saintChallenge", false) and not F.get("saintDown", false) and not F.get("saintChallengeLive", false)
	return false

func job_available(id):
	if G.S["job"] != null and G.S["job"].id == id: return true
	return _avail(id) and not (JOB_CD.has(id) and cd_left(JOB_CD[id]) > 0)

func job_where(id):
	var L = G.D["LOC"]
	var J = G.S["job"]
	match id:
		"studio", "diss": return Vector3(L.studio.x, 0, L.studio.z)
		"video":
			if J != null and J.id == "video" and J.has("marks"):
				var m = J.marks[min(J.stage, J.marks.size() - 1)]
				return Vector3(m.x, m.y, m.z)
			return Vector3(L.platform.x, G.D["PLAT_Y"], L.platform.z)
		"kiara":
			if J != null and J.id == "kiara": return Vector3(L.home.x, 0, L.home.z)
			return Vector3(L.rec.x, 0, L.rec.z)
		"merch":
			if J != null and J.id == "merch":
				for d in G.D["MERCH_DROPS"]:
					if not d.id in J.done: return Vector3(d.x, 0, d.z)
			return Vector3(L.studio.x, 0, L.studio.z)
		"laylow": return Vector3(L.home.x, 0, L.home.z)
		"showcase": return Vector3(L.rec.x, 0, L.rec.z)
		"reyes": return Vector3(L.reyes.x, 0, L.reyes.z)
		"saint": return Vector3(L.park.x, 0, L.park.z)
	return null

func track_job(id):
	G.S["tracked"] = null if G.S.get("tracked") == id else id

func start_job(id, data = {}):
	var j = { "id": id, "stage": 0, "t": 0.0 }
	for k in data.keys(): j[k] = data[k]
	G.S["job"] = j; G.S["tracked"] = id

func end_job():
	G.S["job"] = null

func _update_jobs(dt):
	var J = G.S["job"]
	if J == null: return
	J.t = float(J.t) + dt
	var P = main.player
	var L = G.D["LOC"]
	if J.id == "kiara":
		var K = NPCS.kiara
		if Vector2(P.pos.x - L.home.x, P.pos.z - L.home.z).length() < 6 and Vector2(K.pos.x - L.home.x, K.pos.z - L.home.z).length() < 7:
			var fought = J.get("fight", false)
			var dh = -5 if fought else -12
			add_heat(dh); G.S["stats"]["rides"] = int(G.S["stats"].get("rides", 0)) + 1; set_cd("kiara", 240); G.S["flags"]["kiaraAsk"] = false
			say_cast("kiara", "You said no drama. I mean it." if fought else "Thanks. Don't stay out late.")
			later(6, self, "send_msg", ["kiara", "u said no drama. mama saw the news" if fought else G.pick(["thanks for walking me", "mama says thank u", "next time bring hot chocolate"])])
			main.hud.banner("Home safe", "Heat %d" % dh)
			post_feed(G.pick(G.D["FEED_HANDLES"]), "%s walking little sis home in this cold. respect" % n_())
			K.trail.clear()
			end_job()
	elif J.id == "merch":
		var left = 200 - J.t
		for d in G.D["MERCH_DROPS"]:
			if d.id in J.done: continue
			if Vector2(P.pos.x - d.x, P.pos.z - d.z).length() < 3.2 and abs(P.pos.y - float(d.get("y", 0))) < 2.5:
				J.done.append(d.id); add_cash(120); add_buzz(2); main.hud.banner("Hoodies dropped", d.name + " · +$120")
				G.S["stats"]["merch"] = int(G.S["stats"].get("merch", 0)) + 1
		if J.done.size() == 3:
			add_buzz(4); main.hud.banner("Merch sold out", "Buzz +4")
			post_feed(G.pick(G.D["FEED_HANDLES"]), "copped the %s hoodie. warmest thing I own" % n_())
			set_cd("merch", 200); end_job()
		elif left <= 0:
			main.hud.banner("Merch drop over", "%d/3 spots" % J.done.size()); set_cd("merch", 200); end_job()
	elif J.id == "video":
		var m = J.marks[J.stage]
		var d2 = Vector2(P.pos.x - m.x, P.pos.z - m.z).length()
		J.markT += dt
		if d2 < 1.3 and abs(P.pos.y - float(G.D["PLAT_Y"])) < 0.6:
			J.hold += dt
			if main.train.train_near_calder(): J.train = true
			if J.hold >= 2.5:
				J.stage += 1; J.hold = 0; J.markT = 0; main.sfx.play("tap", 0.5)
				if J.stage >= J.marks.size():
					finish_video(true); return
		else:
			J.hold = max(0, J.hold - dt)
		if G.S["job"] != null and J.markT > 12: finish_video(false)

func start_video():
	if G.S["cash"] < 150:
		main.hud.toast(cast("benny").name + ":  Camera guy needs $150 up front."); return
	add_cash(-150)
	var zs = [-17, -12, 12, 17, -4, 3]
	zs.shuffle()
	var marks = []
	for z in zs.slice(0, 2): marks.append({ "x": 63.7, "y": G.D["PLAT_Y"], "z": z })
	start_job("video", { "marks": marks, "hold": 0.0, "markT": 0.0, "train": false })
	main.cutscene.play(main.cutscene.cut_video())
	main.hud.banner("Rolling", "Hit your marks")

func finish_video(ok):
	var J = G.S["job"]
	if ok:
		var b = 6 + (5 if J.train else 0)
		add_buzz(b); add_heat(2); G.S["stats"]["videos"] = int(G.S["stats"].get("videos", 0)) + 1
		main.hud.banner("Train in the shot" if J.train else "Video wrapped", "Buzz +%d" % b)
		post_feed("@L_platform_lurker", ("%s shot a video on the Calder platform and the train came through mid-verse" if J.train else "%s filming on the Calder platform in -10 wind chill. dedication") % n_())
		main.blok.add_post("video", "new video: shot on the Calder L platform" + (" (with the train!)" if J.train else ""), null)
	else:
		add_buzz(2); main.hud.banner("Shoot wrapped", "You missed a mark")
	set_cd("video", 180); end_job()

# ---------- beacons over job spots ----------
func _build_beacons():
	for id in JOB_IDS:
		var col = Color(cast(JOB_GIVER[id]).color)
		var g = Spatial.new()
		var pm = CylinderMesh.new(); pm.top_radius = 0.7; pm.bottom_radius = 0.7; pm.height = 70; pm.radial_segments = 10; pm.rings = 1
		var pillar = MeshInstance.new(); pillar.mesh = pm; pillar.translation.y = 35
		# plain alpha, not additive: Godot 3 fogs unshaded materials too, and fog + additive turns white
		var mat = SpatialMaterial.new(); mat.flags_unshaded = true; mat.flags_transparent = true
		mat.params_cull_mode = SpatialMaterial.CULL_DISABLED; mat.flags_disable_ambient_light = true; mat.params_depth_draw_mode = SpatialMaterial.DEPTH_DRAW_DISABLED
		mat.albedo_color = Color(col.r, col.g, col.b, 0.3); mat.flags_do_not_receive_shadows = true
		pillar.material_override = mat; pillar.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		var rm = CylinderMesh.new(); rm.top_radius = 1.5; rm.bottom_radius = 1.5; rm.height = 0.04; rm.radial_segments = 20; rm.rings = 1
		var ring = MeshInstance.new(); ring.mesh = rm; ring.translation.y = 0.06
		var rmat = mat.duplicate(); rmat.albedo_color = Color(col.r, col.g, col.b, 0.5)
		ring.material_override = rmat
		g.add_child(pillar); g.add_child(ring); g.visible = false
		main.add_child(g)
		beacons[id] = { "g": g, "mat": mat, "ring": ring }
	for i in range(3):
		var m = CylinderMesh.new(); m.top_radius = 1.1; m.bottom_radius = 1.1; m.height = 0.03; m.radial_segments = 20; m.rings = 1
		var r = MeshInstance.new(); r.mesh = m
		var rm2 = SpatialMaterial.new(); rm2.flags_unshaded = true; rm2.flags_transparent = true; rm2.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
		rm2.albedo_color = Color(1, 0.6, 0.24, 0.8); r.material_override = rm2; r.visible = false
		main.add_child(r); video_rings.append(r)

func _update_beacons(dt):
	var P = main.player
	for id in JOB_IDS:
		var b = beacons[id]
		var on = job_available(id) and G.MODE != "title"
		var w = job_where(id) if on else null
		if w == null:
			b.g.visible = false; continue
		var tracked = G.S.get("tracked") == id
		var d = Vector2(w.x - P.pos.x, w.z - P.pos.z).length()
		b.g.visible = tracked or d < 45
		b.g.translation = w
		var a = (0.35 if tracked else 0.14) * clamp(d / 12.0, 0.15, 1.0)
		b.mat.albedo_color.a = a
		b.ring.scale = Vector3.ONE * (1 + sin(G.REAL_T * 3) * 0.06)
	var J = G.S["job"]
	for i in range(3):
		var r = video_rings[i]
		if J == null or J.id != "video" or i >= J.marks.size():
			r.visible = false; continue
		var m = J.marks[i]
		r.visible = i >= J.stage
		r.translation = Vector3(m.x, float(m.y) + 0.03, m.z)
		r.material_override.albedo_color.a = 0.9 if i == J.stage else 0.25

# ---------- the cold and the wind ----------
func _update_wind(dt):
	WIND.t -= dt
	if WIND.t <= 0:
		if WIND.phase == "calm":
			WIND.phase = "gust"; WIND.target = G.rand(0.6, 1); WIND.t = G.rand(2.5, 5)
		else:
			WIND.phase = "calm"; WIND.target = G.rand(0.04, 0.18); WIND.t = G.rand(9, 20)
	WIND.gust += (WIND.target - WIND.gust) * (1 - exp(-dt * (1.3 if WIND.phase == "gust" else 0.5)))
	var a = WIND_BASE + sin(G.REAL_T * 0.07) * 0.25
	WIND.dx = sin(a); WIND.dz = cos(a)

func _warm_sources():
	var P = main.player
	var warm = 0.0
	var label = null
	for B in G.D["BARRELS"]:
		var d = Vector2(B[0] - P.pos.x, B[1] - P.pos.z).length()
		if d < 3.2 and P.pos.y < 2:
			warm += 4 + 11 * (1 - d / 3.2); label = "Fire barrel"
	for V in G.D["VENTS"]:
		if Vector2(V[0] - P.pos.x, V[1] - P.pos.z).length() < 2.2 and P.pos.y < 1:
			warm += 6
			if label == null: label = "Steam vent"
	for H in G.D["HEATERS"]:
		if Vector2(H[0] - P.pos.x, H[2] - P.pos.z).length() < 3.0 and abs(P.pos.y - H[1]) < 1.5:
			warm += 10; label = "Heat lamp"
	return [warm, label]

func _update_vitals(dt):
	var P = main.player
	var indoor = G.MODE == "menu" or G.MODE == "studio" or G.MODE == "bench"
	exposure_t -= dt
	if exposure_t <= 0:
		exposure_t = 0.5
		# sheltered when something blocks the wind a few metres upwind
		var o = P.pos + Vector3(0, 1.2, 0)
		exposure = 0.3 if W.raycast(o, Vector3(WIND.dx, 0, WIND.dz), 7.0) != INF else 1.0
	var src = [24.0, "Inside"] if indoor else ([9.0, "Car heater"] if P.car else _warm_sources())
	var drain = 0.0
	if not indoor and not P.car:
		drain = (0.36 * (1.15 if main.DN.night > 0.5 else 0.8) + WIND.gust * 0.85 * exposure) * (0.85 if P.speed > 3 else 1.0)
	var B = G.S["buffs"]
	if float(B.get("warmers", 0)) > 0:
		drain *= 0.5; B["warmers"] = float(B["warmers"]) - dt
	if float(B.get("coffee", 0)) > 0:
		drain *= 0.6; B["coffee"] = float(B["coffee"]) - dt
	G.S["warmth"] = clamp(float(G.S.get("warmth", 100)) - drain * dt + src[0] * dt, 0, 100)
	warm_label = src[1] if src[0] > 0 else null
	if G.S["warmth"] <= 0 and not indoor:
		G.S["health"] = float(G.S["health"]) - dt * 1.3
		frost_warn_t -= dt
		if frost_warn_t <= 0:
			frost_warn_t = 12; main.hud.banner("Frostbite", "Get to a fire barrel or inside")
		if G.S["health"] <= 0:
			G.S["health"] = 0; P.hurt(1, null, true)
	if G.S["warmth"] < 30: G.S["stats"]["coldTime"] = float(G.S["stats"].get("coldTime", 0)) + dt

func temp_f():
	var m = G.world_minutes()
	return int(round(10 + sin((m / 1440.0 - 0.3) * TAU) * 6))

func _update_economy(dt):
	stream_t -= dt
	if stream_t <= 0:
		stream_t = 30
		var pay = int(floor(float(G.S["buzz"]) * 0.55))
		if pay > 0:
			add_cash(pay); main.hud.toast("Streams paid " + G.fmt_money(pay))
		if G.S["buzz"] > 25 and float(G.S["playTime"]) - float(G.S["flags"].get("lastTrackAt", 0)) > 300: add_buzz(-1)
	var m = G.world_minutes()
	if last_min >= 0 and last_min < 360 and m >= 360:
		G.S["day"] = int(G.S.get("day", 1)) + 1; main.hud.banner("Day " + str(G.S["day"]), "Sun is coming up over the lake")
	if last_min >= 0 and last_min < 990 and m >= 990: main.hud.banner("Sundown", "The Hawk gets colder at night")
	last_min = m

# ---------- the cast texting you as the story moves ----------
func _cast_tick():
	var F = G.S["flags"]
	var S = G.S
	var C = G.D["CAST"]
	var FH = G.D["FEED_HANDLES"]
	if not F.get("intro", false):
		F["intro"] = true
		send_msg("benny", "yo %s. booth is warm. basement on Calder by the Mini Mart" % n_())
		later(14, self, "_kiara_first_ask")
		post_feed("@hawkwatcher", "wind chill -17 tonight. the Hawk is OUT")
	if not F.get("vanceOffer", false) and S.buzz >= 15:
		F["vanceOffer"] = true; send_msg("vance", "Northline Records. Your numbers are moving. Put %s in a track and I pay %s." % [C.saint.name, G.fmt_money(vance_pay())])
	if not F.get("vance50", false) and S.buzz >= 50:
		F["vance50"] = true; send_msg("vance", "Northline wants a meeting. Keep the heat on.")
	if not F.get("coach30", false) and S.buzz >= 30:
		F["coach30"] = true; send_msg("coach", "Kids at the rec been playing your songs on the speaker. Keep it clean and I can find you a stage.")
	if S.buzz >= 60 and S.heat <= 25 and not F.get("showcaseOffer", false) and not F.get("showcaseDone", false):
		F["showcaseOffer"] = true; send_msg("coach", "Buzz is up, Heat is down. Showcase at the rec. That slot is yours, come see me."); S["tracked"] = "showcase"
	if F.get("showcaseOffer", false) and not F.get("showcaseDone", false) and S.heat > 25 and not F.get("showcaseHold", false):
		F["showcaseHold"] = true; send_msg("coach", "Showcase is on hold. Cool down first.")
	if S.heat <= 25: F["showcaseHold"] = false
	if S.heat >= 50 and not F.get("coach50", false):
		F["coach50"] = true; send_msg("coach", "I hear things. Don't make me hear your name the wrong way.")
	if S.heat >= 40 and not F.get("reyes40", false):
		F["reyes40"] = true; send_msg("reyes", "This is the detective for this area. Your name came across my desk. Keep it on the record, not the street.")
	if S.heat >= 60 and not F.get("reyes60", false):
		F["reyes60"] = true; send_msg("reyes", "Shots on Calder. Diss tracks. I'm not stupid. Go home and lay low.")
		if S.get("tracked") == null: S["tracked"] = "laylow"
	if S.heat >= 80 and not F.get("reyesOffer", false):
		F["reyesOffer"] = true; send_msg("reyes", "I can help you or I can arrest you. Under the L at Low End Rd. Come alone."); S["tracked"] = "reyes"
	if S.heat >= 95 and not F.get("reyes95", false):
		F["reyes95"] = true; send_msg("reyes", "Last chance. After this I come to you.")
	if S.heat < 30: F["reyes95"] = false
	if S.heat >= 60 and not F.get("benny60", false):
		F["benny60"] = true; send_msg("benny", "cars been parked outside the studio all night. u good?")
	if S.heat >= 60 and not F.get("kiara60", false):
		F["kiara60"] = true; send_msg("kiara", "mama keeps asking where u at. she heard stuff")
	if not F.get("kiaraAsk", false) and F.get("intro", false) and not (S["job"] != null and S["job"].id == "kiara") and cd_left("kiara") <= 0 and int(S["stats"].get("rides", 0)) > 0:
		F["kiaraAsk"] = true; send_msg("kiara", G.pick(["come get me pls its brick", "im at the rec. dont be late again", "u picking me up or nah", "coach closing up. come get me"]))
	if not F.get("draftHint", false) and S.cash >= 1500 and S.buzz >= 30 and not S["guns"]["draft"].owned:
		F["draftHint"] = true; send_msg("benny", "a Graywater Draft showed up on the bench. its yours if u got the bread")
	if not F.get("plowHint", false) and S.cash >= 2500 and S.buzz >= 50 and not S["guns"]["plow"].owned:
		F["plowHint"] = true; send_msg("benny", "Ostrava Snowplow on the bench now. loud tho. real loud")
	if int(S["stats"].get("disses", 0)) >= 2 and not F.get("saintChallenge", false) and not F.get("saintDown", false):
		F["saintChallenge"] = true; send_msg("saint", "You keep saying my name. Calder Park pond. Come say it to my face.")
	var P = main.player
	var L = G.D["LOC"]
	if job_available("saint") and Vector2(P.pos.x - L.park.x, P.pos.z - L.park.z).length() < 26 and not F.get("saintChallengeLive", false) and G.MODE == "play":
		F["saintChallengeLive"] = true
		main.crews.spawn_crew(Vector3(L.park.x + 8, 0, L.park.z - 6), 4, 2, { "saint": true, "challenge": true })
		later(120, self, "_saint_reset")
	ambient_feed_t -= 1
	if ambient_feed_t <= 0:
		ambient_feed_t = G.rand(60, 100)
		var h = S.heat
		var pool
		if h >= 80: pool = ["detectives knocking on Bishop St asking about %s" % n_(), "%s name all over the block rn" % n_()]
		elif h >= 60: pool = ["@saint.halo people asking about %s" % n_(), "%s better stay in" % n_()]
		elif h >= 40: pool = ["lotta noise on Calder tonight", "cops posted by the L again"]
		else: pool = ["rec center got hot cocoa tonight", "the Hawk is disrespectful tonight fr", "L was 20 min late again", "Mini Mart coffee hits different at -10", "who left the snowman by the pond"]
		post_feed(G.pick(FH), G.pick(pool))

func _kiara_first_ask():
	G.S["flags"]["kiaraAsk"] = true
	send_msg("kiara", "can u get me from the rec later? its brick out")

func _saint_reset():
	G.S["flags"]["saintChallengeLive"] = false

func on_walk_away(c):
	G.S["stats"]["walkAways"] = int(G.S["stats"].get("walkAways", 0)) + 1
	post_feed(G.pick(G.D["FEED_HANDLES"]), G.pick(["seen %s walk away from @halo crew. grown man move" % n_(), "%s walked off. some calling it soft, I call it smart" % n_()]))
	if not G.S["flags"].get("walkMsg", false):
		G.S["flags"]["walkMsg"] = true
		later(7, self, "send_msg", ["coach", "Heard you walked away tonight. That is the hardest thing to do."])
		later(15, self, "send_msg", ["kiara", "saw that post. proud of u for walking away"])
	if c.get("saint", false): later(9, self, "send_msg", ["saint", "Keep walking. That is what you do."])

func on_crew_defeated(c):
	var where = main.hud.street_name(main.player.pos)
	later(4, self, "post_feed", [G.pick(G.D["FEED_HANDLES"]), G.pick(["shots on %s again. everybody ok?" % where, "%s was loud tonight. stay inside" % where, "heard @halo crew got sent home on %s" % where])])
	if c.get("challenge", false): G.S["flags"]["saintChallengeDone"] = true

func on_saint_down():
	G.S["flags"]["saintDown"] = true
	main.hud.banner("@saint.halo is down", "")
	later(2.6, self, "trigger_ending", ["crown"])

func on_crew_engaged():
	G.S["stats"]["fights"] = int(G.S["stats"].get("fights", 0)) + 1
	if G.S["job"] != null and G.S["job"].id == "kiara": G.S["job"]["fight"] = true

func on_track_released(tr):
	G.S["flags"]["lastTrackAt"] = G.S["playTime"]
	_feed_for_track(tr)
	if tr.type == "diss":
		later(8, self, "send_msg", ["saint", G.pick(["Heard the track. Cute.", "You rap about me more than you rap about yourself.", "Stay inside. The Hawk is not the only thing out here.", "Keep my name out your mouth."])])
		if G.S["heat"] > 40: later(16, self, "send_msg", ["coach", "Heard that track. That's not you."])
	elif G.S["flags"].get("vanceOffer", false) and randf() < 0.5:
		later(9, self, "send_msg", ["vance", "Nice song. Nice does not pay. You know what does."])
	if int(G.S["stats"].get("tracks", 0)) == 1:
		later(5, self, "send_msg", ["benny", "that one's crazy. also there's a workbench downstairs now, for your gear. Kestrel parts, all legal, all loud"])

func _feed_for_track(tr):
	var t = tr.title
	var good = tr.grade in ["S", "A", "B"]
	var pool = []
	if good: pool += ["%s by %s is hard" % [t, n_()], "%s snapped on %s" % [n_(), t], "who is %s?? %s on repeat" % [n_(), t], "%s sounds like 4am on the Calder platform" % t]
	else: pool += ["%s kinda mid ngl" % t, "%s rushed %s. flow was off" % [n_(), t], "%s got potential tho" % t]
	if tr.type == "tribute": pool += ["%s made %s for the rec kids" % [n_(), t], "%s got me calling my sister" % t]
	if tr.type == "wayout": pool += ["%s going places. %s is a ticket out" % [n_(), t], "%s sounds like the Loop at night" % t]
	if tr.type == "diss": pool += ["%s really went at @saint.halo on %s" % [n_(), t], "%s is crazy but Calder bout to be hot" % t, "@saint.halo not letting %s slide" % t]
	post_feed(G.pick(G.D["FEED_HANDLES"]), G.pick(pool))
	later(5, self, "post_feed", [G.pick(G.D["FEED_HANDLES"]), G.pick(pool)])

# ---------- places (E) ----------
func interact_label(it):
	var C = G.D["CAST"]
	match it.id:
		"studio": return "Enter Basement 808"
		"store": return "Enter Calder Mini Mart"
		"gas": return "Enter Ironside Fuel"
		"court": return "Catch your breath · %ds" % int(ceil(cd_left("hoops"))) if cd_left("hoops") > 0 else "Shoot around · warms you up"
		"lake": return "The lake is quiet" if cd_left("lake") > 0 else "Look out over the lake · Heat −4"
		"rec": return "Enter the rec center"
		"home": return "Go inside (home)"
		"video": return "Start the video shoot · $150" if job_available("video") and G.S["job"] == null else null
		"reyes": return "Talk to " + C.reyes.name if job_available("reyes") else null
		"coach": return "Talk to " + C.coach.name
		"benny": return "Talk to " + C.benny.name
		"garden": return main.memorial.label("garden")
	return null

func interact(it):
	match it.id:
		"studio": studio_menu()
		"store": store_menu("store")
		"gas": store_menu("gas")
		"court": shoot_around()
		"lake": lake_view()
		"rec": rec_menu()
		"home": home_menu()
		"video": start_video()
		"reyes": reyes_menu()
		"garden": main.memorial.pay_respects("garden")
		"coach", "benny":
			say_cast(it.id, G.pick(npc_lines(it.id)))
			if it.id == "benny": NPCS.benny.wave_t = 2.5

func can_go_inside():
	for c in main.crews.CREWS:
		if c.state != "combat": continue
		for e in c.members:
			if not e.is_down() and e.pos.distance_to(main.player.pos) < 35: return false
	return true

func _blocked_inside():
	if not can_go_inside():
		main.hud.banner("Can't go in", "Lose them first"); return true
	if main.police.level >= 2:
		main.hud.banner("Can't go in", "Police are on you"); return true
	return false

func _item(label, desc, hint, method, args = [], disabled = false):
	var it = { "label": label, "desc": desc, "hint": hint, "disabled": disabled, "act": funcref(self, method) if method != "" else null }
	if args.size() > 0: it["arg"] = args
	return it

func _leave():
	return { "label": "Leave", "act": null }

func studio_menu(_a = null):
	if _blocked_inside(): return
	var F = G.S["flags"]
	if not F.get("studioCut", false):
		F["studioCut"] = true
		main.cutscene.play(main.cutscene.cut_studio(), self, "studio_menu")
		return
	var cd = cd_left("studio")
	var items = [
		_item("Record a session", "Pick a verse and a beat style." + (" Diss pays %s." % G.fmt_money(vance_pay()) if F.get("vanceOffer", false) else ""), "booth busy %ds" % int(ceil(cd)) if cd > 0 else "free", "_open_studio", [], cd > 0),
		_item("Workbench", "Parts, finishes, charms and new guns.", G.fmt_money(G.S["cash"]), "_open_bench"),
	]
	if job_available("merch") and G.S["job"] == null:
		items.append(_item("Pick up the merch", "Hoodies for 3 drop spots. 200 seconds.", "+$360", "_start_merch"))
	items.append(_leave())
	main.hud.menu(G.D["LOC"]["studio"].get("addr", "Calder Ave"), "Basement 808", '%s: "%s"' % [cast("benny").name, G.pick(npc_lines("benny"))], items)

func _open_studio(_a = null): main.studio.open_select()
func _open_bench(_a = null): main.studio.open_bench()
func _start_merch(_a = null):
	start_job("merch", { "done": [] }); main.hud.banner("Merch drop", "3 spots · 200s")

func store_menu(kind):
	if _blocked_inside(): return
	var items = [
		_item("Hot coffee", "Warmth +35 now, slower chill for 60s.", "$8", "_buy", ["coffee", 8]),
		_item("Hand warmers", "Warmth drains half as fast for 2 minutes.", "$15", "_buy", ["warmers", 15]),
		_item("Bandage", "Press B to heal 40 health.", "$25", "_buy", ["bandage", 25]),
	]
	for id in ["k9", "draft", "plow"]:
		if G.S["guns"][id].owned:
			var A = G.D["WEAPONS"][id].ammo
			items.append(_item("%s ammo" % G.D["WEAPONS"][id].short, "%d rounds." % A.n, G.fmt_money(A.price), "_buy", ["ammo:" + id, A.price]))
	items.append(_leave())
	main.hud.menu("Ironside Rd · open 24 hours" if kind == "gas" else G.D["LOC"]["store"].get("addr", ""), "Ironside Fuel" if kind == "gas" else "Calder Mini Mart", "Hot coffee, hand warmers, first aid. Ammo behind the counter.", items)
	main.sfx.play("shopbell", 0.4)

func _buy(a):
	var what = a[0]
	var price = a[1]
	if G.S["cash"] < price:
		main.hud.toast("Not enough cash."); return
	add_cash(-price)
	if what == "coffee":
		G.S["warmth"] = min(100, float(G.S["warmth"]) + 35); G.S["buffs"]["coffee"] = 60; main.hud.toast("Coffee. Black, still hot.")
	elif what == "warmers":
		G.S["buffs"]["warmers"] = 120; main.hud.toast("Hand warmers cracked and in your pockets.")
	elif what == "bandage":
		G.S["bandages"] = int(G.S.get("bandages", 0)) + 1; main.hud.toast("Bandage in your pocket.")
	elif what.begins_with("ammo:"):
		var id = what.substr(5)
		G.S["guns"][id].res += G.D["WEAPONS"][id].ammo.n; main.hud.toast("%d rounds for the %s." % [G.D["WEAPONS"][id].ammo.n, G.D["WEAPONS"][id].short])
	store_menu("store")

func rec_menu(_a = null):
	if _blocked_inside(): return
	var items = []
	if G.S["flags"].get("kiaraAsk", false) and G.S["job"] == null:
		items.append(_item("Walk %s home" % cast("kiara").name, "She follows you to Bishop St. Family time lowers Heat.", "Heat −12", "_start_kiara"))
	var ok = job_available("showcase")
	items.append(_item("Perform at the showcase", "One take in front of the whole rec. Hit 60% to land it." if ok else job_lock("showcase"), "Way Out", "_showcase", [], not ok))
	items.append(_item("Warm up by the radiator", "Stay inside a minute.", "%d%%" % int(G.S["warmth"]), "_radiator"))
	items.append(_leave())
	main.hud.menu(G.D["LOC"]["rec"].get("addr", ""), "Calder Park Rec", '%s: "%s"' % [cast("coach").name, G.pick(npc_lines("coach"))], items)

func _start_kiara(_a = null):
	start_job("kiara", { "fight": false })
	var K = NPCS.kiara
	K.pos = Vector3(G.D["LOC"]["rec"].x + 1, 0, G.D["LOC"]["rec"].z); K.trail = []; K.line_t = 4

func _showcase(_a = null): main.studio.start_rhythm("wayout", { "showcase": true, "style": "chi" })
func _radiator(_a = null):
	G.S["warmth"] = min(100, float(G.S["warmth"]) + 40); rec_menu()

func home_menu(_a = null):
	if _blocked_inside(): return
	var cd = cd_left("laylow")
	main.hud.menu(G.D["LOC"]["home"].get("addr", ""), "Home", "Radiator clanking. Mama asleep on the couch with the TV on.", [
		_item("Lay low", "Stay in a while. Heat −20, health and warmth back up, Buzz −2.", "%ds" % int(ceil(cd)) if cd > 0 else "Heat −20", "lay_low", [], cd > 0),
		_item("Wardrobe", "Change your fit in the Style app.", "Skins", "_wardrobe"),
		_item("Save progress", "Saved on this computer.", "", "_save_now"),
		_leave()])

func _wardrobe(_a = null): main.phone.open("style")
func _save_now(_a = null):
	G.save_game(); main.hud.toast("Saved.")

func lay_low(_a = null):
	if main.police.level > 0:
		main.hud.toast("Police are watching the block. Lose them first."); return
	main.hud.fade_to(1.0, 0.6)
	G.MODE = "cut"
	yield(get_tree().create_timer(1.4), "timeout")
	add_heat(-20); G.S["health"] = min(100, float(G.S["health"]) + 40); G.S["warmth"] = 100
	if G.S["buzz"] > 10: add_buzz(-2)
	G.S["stats"]["layLows"] = int(G.S["stats"].get("layLows", 0)) + 1
	main.crews.clear(); set_cd("laylow", 150)
	if G.S["job"] != null and G.S["job"].id != "kiara": end_job()
	var L = G.D["LOC"]["home"]
	main.player.place(L.x + 1.6, 0, L.z, PI * 0.5)
	main.hud.fade_to(0.0, 0.6)
	G.MODE = "play"
	main.hud.banner("Stayed in", "Heat −20 · " + G.clock_str())
	if G.S["heat"] >= 40: send_msg("reyes", "Good. Stay in more often.")
	G.save_game()

func reyes_menu(_a = null):
	main.hud.menu("Under the L · Low End Rd", cast("reyes").name, '"You came. Good. Tell me about %s and this ends tonight."' % cast("saint").name, [
		_item("Talk", "Tell the detective everything. Your Heat is cleared. Ending: Witness.", "Witness", "trigger_ending", ["witness"]),
		_item("Walk away", "Say nothing and leave.", "", "_reyes_walk")])

func _reyes_walk(_a = null): say_cast("reyes", "Then I will see you when it is too late.")

func shoot_around():
	if cd_left("hoops") > 0: return
	set_cd("hoops", 45)
	var made = int(round(clamp(2 + randf() * 7 + (1 if G.S["buzz"] > 60 else 0), 1, 10)))
	main.player.emote("hype", 1.4)
	G.S["warmth"] = min(100, float(G.S["warmth"]) + 18)
	G.S["stats"]["hoops"] = int(G.S["stats"].get("hoops", 0)) + 1
	add_buzz(3 if made >= 7 else 1)
	main.hud.banner("%d/10 at Garnet Courts" % made, "Buzz +3 · warmed up" if made >= 7 else "Buzz +1 · warmed up")
	if made >= 8: post_feed("@garnet.courts", "@%s hit %d/10 at Garnet Courts in this cold" % [G.S["name"], made])

func lake_view():
	if cd_left("lake") > 0: return
	set_cd("lake", 120); add_heat(-4); main.player.emote("sit", 3.0)
	main.hud.banner("Lake effect", "Heat −4 · the city goes quiet out here")

# ---------- endings ----------
func trigger_ending(id):
	if G.MODE == "ending" or pending_ending != null: return
	pending_ending = id
	var P = main.player
	if P.car: P.exit_vehicle(true)
	main.hud.close_menu(); main.phone.close(); main.studio.close_all()
	G.MODE = "play"
	main.cutscene.play(main.cutscene.cut_ending(id), self, "show_ending", [id])

func show_ending(id):
	var E = G.D["ENDINGS"][id]
	G.S["endings"][id] = int(G.S["endings"].get(id, 0)) + 1
	G.MODE = "ending"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var st = G.S["stats"]
	var best = st.get("best")
	var cells = [
		["Buzz peak", int(st.get("buzzPeak", 0))], ["Heat peak", int(st.get("heatPeak", 0))], ["Tracks", int(st.get("tracks", 0))],
		["Best track", ("%s (%s)" % [best.title, best.grade]) if typeof(best) == TYPE_DICTIONARY else "none"],
		["Followers", main.blok.followers()], ["Walk-aways", int(st.get("walkAways", 0))], ["Rides for sis", int(st.get("rides", 0))], ["Cash earned", G.fmt_money(st.get("cashEarned", 0))],
		["Fights", int(st.get("fights", 0))], ["Busted", int(st.get("busted", 0))], ["Miles driven", "%.1f" % (float(st.get("drive", 0)) / 1609.0)], ["Cold time", "%d min" % int(float(st.get("coldTime", 0)) / 60)]]
	var line = E.line
	var C = G.D["CAST"]
	if id == "witness": line = "You sat in %s's car under the L and talked. Your Heat is cleared. The block remembers." % C.reyes.name
	elif id == "crown": line = "%s went down in the snow. Calder Ave is yours, and so is everything that comes with it." % C.saint.name
	elif id == "locked": line = "Heat hit the ceiling. %s came for you." % C.reyes.name
	ending_box = main.hud.ending_panel("Ending · @%s · day %d" % [G.S["name"], int(G.S.get("day", 1))], E.title, Color(E.color), line, cells, self, "_ending_continue")
	post_feed(G.pick(G.D["FEED_HANDLES"]), { "wayout": "%s shut down the rec showcase. that's a way out" % n_(), "witness": "heard %s been talking to detectives... block is quiet tonight" % n_(), "crown": "%s vs @saint.halo is OVER. new name on Calder" % n_(), "locked": "%s got picked up under the L. free %s" % [n_(), n_()] }[id])
	G.save_game()

func _ending_continue():
	var id = pending_ending
	pending_ending = null
	if ending_box:
		ending_box.queue_free()
		ending_box = null
	main.crews.clear(); main.police.clear()
	if id == "wayout":
		add_buzz(10); add_cash(1500); G.S["social"]["followers"] = int(G.S["social"].get("followers", 214)) + 2500
	elif id == "witness":
		G.S["heat"] = 0; G.S["flags"]["reyesOffer"] = false; G.S["flags"]["calmUntil"] = float(G.S["playTime"]) + 300; add_buzz(-8)
		later(12, self, "send_msg", ["saint", "Heard you been talking to detectives. Block heard too."])
	elif id == "crown":
		add_heat(5); add_buzz(15); G.S["social"]["followers"] = int(G.S["social"].get("followers", 214)) + 1500
	elif id == "locked":
		G.S["heat"] = 15; G.S["cash"] = int(floor(G.S["cash"] * 0.6)); add_buzz(-10); G.S["day"] = int(G.S.get("day", 1)) + 30
		for f in ["reyesOffer", "reyes40", "reyes60", "reyes95"]: G.S["flags"][f] = false
		var st = G.D["LOC"]["station"]
		main.player.place(st.x, 0, st.z + 1.5, 0)
		main.hud.banner("Released", "30 days later")
	G.S["health"] = max(float(G.S["health"]), 60); G.S["warmth"] = max(float(G.S["warmth"]), 60)
	if G.S["job"] != null: end_job()
	G.MODE = "play"
	G.save_game()

# ---------- every frame ----------
func update(dt):
	if NPCS.size() == 0: return
	_tick_later(dt)
	_update_npcs(dt)
	_update_beacons(dt)
	if G.MODE == "title": return
	_update_wind(dt)
	if G.MODE == "play" or G.MODE == "phone" or G.MODE == "menu":
		_update_jobs(dt)
		_update_vitals(dt)
		_update_economy(dt)
		tick_t -= dt
		if tick_t <= 0:
			tick_t = 1.0
			_cast_tick()
