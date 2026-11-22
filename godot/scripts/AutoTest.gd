extends Node
# Runs with --autotest: plays through the main features and saves screenshots to
# the folder in the DS_SHOTS environment variable (or user://shots), then quits.

var main
var out = ""
var log_lines = []

func run(m):
	main = m
	out = OS.get_environment("DS_SHOTS")
	if out == "": out = OS.get_user_data_dir().plus_file("shots")
	Directory.new().make_dir_recursive(out)
	if OS.get_environment("DS_JOIN") != "": call_deferred("_join_mode")
	elif OS.get_environment("DS_SKYTEST") != "": call_deferred("_sky_test")
	elif OS.get_environment("DS_MEMTEST") != "": call_deferred("_mem_test")
	elif OS.get_environment("DS_LOOKTEST") != "": call_deferred("_look_test")
	elif OS.get_environment("DS_SRVTEST") != "": call_deferred("_srv_test")
	elif OS.get_environment("DS_UITEST") != "": call_deferred("_ui_test")
	else: call_deferred("_go")

func _wait(s):
	yield(get_tree().create_timer(s), "timeout")

func _shot(name):
	# DS_NOHUD: clean frames (for the download page)
	var hidden = []
	if OS.get_environment("DS_NOHUD") != "" and main.hud:
		for c in main.hud.layer.get_children():
			if c is CanvasItem and c.visible:
				c.visible = false; hidden.append(c)
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var img = get_viewport().get_texture().get_data()
	img.flip_y()
	img.save_png(out.plus_file(name + ".png"))
	for c in hidden: c.visible = true
	_log("shot " + name)

func _count(n, acc):
	if n is MeshInstance:
		acc[0] += 1
		if acc[0] < 3: _log("mesh %s aabb %s vis %s surf %d" % [n.name, str(n.get_transformed_aabb()), str(n.is_visible_in_tree()), n.mesh.get_surface_count()])
	for c in n.get_children(): _count(c, acc)

func _diag():
	var acc = [0]
	if main.city: _count(main.city, acc)
	_log("city meshes %d  draw calls %d  objects %d  fps %d" % [acc[0], Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_OBJECTS_IN_FRAME), Engine.get_frames_per_second()])
	var cam = get_viewport().get_camera()
	_log("cam %s current=%s main_cam=%s xf %s" % [str(cam), str(cam.current) if cam else "-", str(main.camera), str(cam.global_transform) if cam else "-"])

# a second copy of the game that joins the first one and dances
func _join_mode():
	yield(_wait(1.0), "completed")
	var st = G.new_state("peer_two")
	st["skin"] = G.preset_skin(2)
	main.title._close()
	main.start_game(st)
	main.player.place(4, 0, -24, 0)
	var ip = OS.get_environment("DS_JOIN")
	var t0 = G.REAL_T
	var shot_at = 0.0
	while G.REAL_T - t0 < 90:
		if not main.net.online() and main.net.status == "offline":
			if ip == "relay": main.net.go_online("autotest")
			else: main.net.join(ip)
		if main.net.online() and main.net.R.size() > 0 and G.REAL_T - shot_at > 6:
			# shoot near the other player so they hear it, and try to hit them
			shot_at = G.REAL_T
			var r = main.net.R.values()[0]
			main.net.send_shot(main.player.pos + Vector3(0, 1.4, 0), r.pos + Vector3(0, 1.2, 0))
			main.net.hit_remote(r, 5, false, false)
		yield(_wait(2.0), "completed")
		if main.net.online():
			main.player.emote("dance2")
			_log("joined, peers %d" % main.net.R.size())
	get_tree().quit()

func _face_ped(P, dist):
	var f = Vector3(-sin(P.cam_yaw), 0, -cos(P.cam_yaw))
	var p = main.peds.make(P.pos.x + f.x * dist, P.pos.z + f.z * dist)
	p.state = "walk"; p.target = null
	return p

# every feature added after the first port, with screenshots
func _touch(idx, pos, pressed):
	var e = InputEventScreenTouch.new(); e.index = idx; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)

func _drag(idx, pos, rel):
	var e = InputEventScreenDrag.new(); e.index = idx; e.position = pos; e.relative = rel
	Input.parse_input_event(e)

# phones: drive the on-screen controls with fake fingers
func _touch_test():
	var P = main.player
	_log("touch controls on: %s" % str(main.touch.enabled))
	P.place(-2.5, 0, -30, 0); P.cam_yaw = 0
	yield(_wait(0.5), "completed")
	var p0 = P.pos
	_touch(0, Vector2(160, 560), true)
	for i in range(10):
		_drag(0, Vector2(160, 560 - i * 9), Vector2(0, -9))
		yield(get_tree(), "idle_frame")
	_touch(1, Vector2(800, 360), true)
	for i in range(10):
		_drag(1, Vector2(800 + i * 6, 360), Vector2(6, 0))
		yield(get_tree(), "idle_frame")
	yield(_wait(1.2), "completed")
	yield(_shot("27_touch"), "completed")
	var b = null
	for x in main.touch.buttons():
		if x.id == "fire": b = x
	var mag0 = G.S["guns"][G.S["cur"]].mag
	_touch(2, b.c, true)
	yield(_wait(0.25), "completed")
	_touch(2, b.c, false)
	_touch(1, Vector2(860, 360), false)
	_touch(0, Vector2(160, 470), false)
	yield(_wait(0.3), "completed")
	_log("touch: moved %.1f m, yaw %.2f, mag %d -> %d, sprint %s" % [P.pos.distance_to(p0), P.cam_yaw, mag0, G.S["guns"][G.S["cur"]].mag, str(Input.is_action_pressed("sprint"))])

func _tour():
	yield(get_tree(), "idle_frame")
	var P = main.player
	var S = G.S
	if main.touch.enabled: yield(_touch_test(), "completed")
	main.crews.clear(); main.police.clear()
	G.time_offset += (12 * 60 - G.world_minutes())
	P.place(-2.5, 0, -30, 0); P.cam_yaw = 0; P.cam_pitch = -0.1
	yield(_wait(1.0), "completed")
	# weapon wheel
	main.hud._open_wheel("weapon"); main.hud.wheel_sel = 0
	yield(_wait(0.3), "completed")
	yield(_shot("09_weapon_wheel"), "completed")
	main.hud._close_wheel(true)
	_log("weapon wheel picked fists: %s" % str(S.get("fists")))
	P.switch_weapon("k9")
	# emote wheel + a dance the street joins
	Input.action_press("emote")
	main.hud._open_wheel("emote"); main.hud.wheel_vec = Vector2(60, -60)
	yield(_wait(0.3), "completed")
	yield(_shot("10_emote_wheel"), "completed")
	main.hud.wheel_sel = 2
	Input.action_release("emote")
	yield(get_tree(), "idle_frame")
	_face_ped(P, 4)
	main.peds.react_to_emote(P.pos, "dance")
	P.cam_yaw = PI
	yield(_wait(1.6), "completed")
	_log("emote: %s" % P.emote_name)
	yield(_shot("11_dance"), "completed")
	P.emote_name = ""
	# ragdoll: flop, then get up
	P.cam_yaw = 0.6
	P.flop()
	yield(_wait(1.4), "completed")
	_log("ragdoll after flop: %s, pelvis y %.2f" % [str(P.is_ragdoll()), P.human.rag.p[0].y if P.human.rag else -1])
	yield(_shot("12_ragdoll"), "completed")
	P.flop()
	yield(_wait(1.2), "completed")
	_log("got up: %s" % str(not P.is_ragdoll()))
	# a pedestrian shot down falls as a ragdoll
	var pd = _face_ped(P, 6)
	pd.take_hit(200, false, Vector3(0, 0, -1), false, false)
	yield(_wait(0.8), "completed")
	_log("ped ragdoll: %s" % str(pd.h.is_ragdoll()))
	# snowball fight
	P.cam_yaw = 0; P.cam_pitch = 0.05
	var tgt = _face_ped(P, 5)
	yield(_wait(0.4), "completed")
	P.throw_snowball()
	yield(_wait(1.2), "completed")
	_log("snowballs landed: %d" % int(S["stats"].get("snowballs", 0)))
	# the studio: cutscene, verse select, the rhythm game, release
	S["flags"]["studioCut"] = false
	var L = G.D["LOC"]
	P.place(L.studio.x, 0, L.studio.z + 1.5, PI)
	main.story.studio_menu()
	yield(_wait(1.2), "completed")
	yield(_shot("13_cutscene"), "completed")
	main.cutscene.end()
	yield(_wait(0.3), "completed")
	yield(_shot("14_studio_menu"), "completed")
	main.hud.close_menu()
	main.studio.start_rhythm("tribute", { "style": "chi" })
	var t0 = G.REAL_T
	var hits = 0
	while G.REAL_T - t0 < 7.0:
		yield(get_tree(), "idle_frame")
		var now = main.studio.rh_now()
		for n in main.studio.RH.notes:
			if n.hit == "" and abs(n.t - now) < 0.03:
				main.studio._hit(n.lane); hits += 1
		if G.REAL_T - t0 > 5.0 and G.REAL_T - t0 < 5.05: yield(_shot("15_rhythm"), "completed")
	for n in main.studio.RH.notes:
		if n.hit == "":
			n.hit = "perfect"
			main.studio.RH.pts += 1.0
	main.studio._finish()
	yield(_wait(0.3), "completed")
	yield(_shot("16_results"), "completed")
	_log("rhythm hits while playing: %d, grade %s" % [hits, main.studio.RH.result.grade])
	var tracks0 = S["tracks"].size()
	main.studio._release()
	yield(_wait(0.3), "completed")
	main.hud.close_menu()
	_log("tracks %d -> %d, feed %d, blok posts %d" % [tracks0, S["tracks"].size(), S["feed"].size(), S["social"]["posts"].size()])
	# workbench
	S["cash"] = 9000
	main.studio.open_bench()
	main.studio._bench_part("optic", "holo")
	main.studio._bench_part("finish", "crimson")
	main.studio._bench_part("charm", "crown")
	yield(_wait(0.5), "completed")
	yield(_shot("17_bench"), "completed")
	_log("k9 cfg %s, zoom %.2f" % [JSON.print(GUN.cfg_of("k9")), float(GUN.stats("k9").zoom)])
	main.studio.close_bench(); main.hud.close_menu()
	# the character creator
	main.wardrobe.open()
	main.wardrobe.step("hair", 1); main.wardrobe._set_color("topCol", 13115434); main.wardrobe.step("head", 2)
	yield(_wait(0.6), "completed")
	yield(_shot("18_wardrobe"), "completed")
	main.wardrobe._set_cat(0)
	yield(_wait(0.2), "completed")
	main.wardrobe.save()
	_log("skin saved: top %s col %s head %s" % [S["skin"].top, str(S["skin"].topCol), S["skin"].head])
	# phone apps
	main.phone.open("msgs")
	yield(_wait(0.3), "completed")
	yield(_shot("19_msgs"), "completed")
	main.phone._open_thread("benny")
	yield(_wait(0.2), "completed")
	main.phone.show_app("jobs")
	yield(_wait(0.3), "completed")
	yield(_shot("20_jobs"), "completed")
	main.phone.close()
	yield(main.blok.take_photo("autotest snap"), "completed")
	main.phone.open("blok")
	yield(_wait(0.4), "completed")
	yield(_shot("21_blok"), "completed")
	main.phone.show_app("online")
	yield(_wait(0.3), "completed")
	main.phone.close()
	# the L at Calder: shift the clock until a train is in the station
	var T = main.train.TR[0]
	var ph = fposmod(G.world_seconds() + T.off, main.train.CYCLE)
	G.time_offset += fposmod(main.train.T1 + 2 - ph, main.train.CYCLE)
	P.place(64.2, float(G.D["PLAT_Y"]), 9, PI)
	P.cam_yaw = -PI / 2 - 0.4; P.cam_pitch = -0.05
	yield(_wait(1.5), "completed")
	_log("train 0: %s z %.1f" % [T.state, T.z])
	yield(_shot("22_train"), "completed")
	# an ending
	main.story.trigger_ending("wayout")
	yield(_wait(1.5), "completed")
	yield(_shot("23_ending_cut"), "completed")
	main.cutscene.end()
	yield(_wait(0.5), "completed")
	yield(_shot("24_ending"), "completed")
	main.story._ending_continue()
	_log("endings: %s, mode %s" % [JSON.print(S["endings"]), G.MODE])
	# busted
	P.place(2, 0, -20, 0)
	main.police.add_wanted(30, P.pos)
	main.police._busted()
	yield(_wait(1.0), "completed")
	main.cutscene.end()
	_log("busted count %d, mode %s" % [int(S["stats"].get("busted", 0)), G.MODE])
	# online: host a game
	var ok = true
	if OS.get_environment("DS_BROKERS") != "": main.net.go_online("autotest")
	else: ok = main.net.host()
	var tw = G.REAL_T
	while not main.net.online() and G.REAL_T - tw < 15: yield(get_tree(), "idle_frame")
	_log("net: %s %s %s (%s)" % [str(ok), main.net.mode, main.net.status, main.net.note])
	if OS.get_environment("DS_PEER") != "":
		var t1 = G.REAL_T
		while main.net.R.size() == 0 and G.REAL_T - t1 < 40: yield(get_tree(), "idle_frame")
		yield(_wait(2.0), "completed")
		var hp0 = G.S["health"]
		yield(_wait(7.0), "completed")
		var rr = main.net.R.values()
		_log("net peers: %d %s · health %d -> %d" % [rr.size(), ("@" + rr[0].name + " at " + str(rr[0].pos) + " emote " + str(rr[0].st.get("em"))) if rr.size() > 0 else "", hp0, G.S["health"]])
		if rr.size() > 0:
			P.place(rr[0].pos.x + 3, 0, rr[0].pos.z + 3, PI * 0.75)
			yield(_wait(1.0), "completed")
			yield(_shot("25_online"), "completed")
	main.net.leave()
	# HUD in daylight with a job tracked
	S["tracked"] = "studio"
	P.place(-2.5, 0, -30, 0); P.cam_yaw = 0
	yield(_wait(1.0), "completed")
	yield(_shot("26_hud"), "completed")

# records what the game's mixer outputs, for checking the sound offline
var recs = {}
var bus_logged = false
func _clean_view(on):
	for f in main.gang.FOL:
		if f.h: f.h.visible = not on
	for c in main.hud.layer.get_children():
		if c is CanvasItem: c.visible = not on
	G.S["settings"]["fp"] = on

# sky only: several times of day and weathers, no HUD, then quit
func _sky_test():
	yield(_wait(1.0), "completed")
	main.title._close(); main.start_game(G.new_state("skytest"))
	yield(_wait(1.5), "completed")
	_clean_view(true)
	if OS.get_environment("DS_SKYTEST") == "medium": main.set_quality("medium")
	var P = main.player
	var S = main.sky
	var shots = [["s1_noon_clear", 12 * 60 + 30, 0.35, 0.0, 0.0, 185, 0, PI, 0.35],
		["s2_noon_cloudy", 12 * 60 + 30, 0.75, 0.0, 0.0, 185, 0, PI, 0.35],
		["s3_dusk", 16 * 60 + 40, 0.45, 0.0, 0.0, 185, 0, -1, 0.12],
		["s4_night_north", 23 * 60, 0.3, 0.0, 1.0, 185, 0, 0.0, 0.08],
		["s5_night_up", 23 * 60, 0.25, 0.0, 0.0, 185, 0, -2.4, 0.75],
		["s6_storm", 22 * 60, 0.9, 1.0, 0.0, 185, 0, 0.6, 0.25],
		["s7_dawn", 7 * 60 + 20, 0.5, 0.0, 0.0, 185, 0, -1, 0.12]]
	for s in shots:
		G.time_offset += (s[1] - G.world_minutes())
		S.override = { "cover": s[2], "storm": s[3], "aurora": s[4] }
		S.cover = s[2]; S.storm = s[3]; S.aurora = s[4]
		var yaw = s[7]
		if yaw == -1: yaw = -deg2rad(main.sun_angles(G.world_minutes())[1])
		P.place(s[5], 0, s[6], yaw); P.cam_pitch = s[8]
		yield(_wait(0.8), "completed")
		if s[3] > 0.5:
			S.strike("")
			P.cam_yaw = -S.flash_az
			yield(_wait(0.06), "completed")
		yield(_shot(s[0]), "completed")
	get_tree().quit()

# the sky through the day, the memorial wall, the mausoleum and the lightning tribute
func _frame(from, look, fov = 50):
	main.cutscene.play([{ "dur": 999, "from": from, "look": look, "fov": fov }])

func _wait_for(obj, prop, want, secs):
	var t0 = G.REAL_T
	while G.REAL_T - t0 < secs:
		if obj.get(prop) == want: return
		yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")

func _list_names():
	var out = []
	for sv in main.net.server_list(): out.append("%s %d/%d%s%s" % [sv.name, sv.p, sv.x, " 24h" if sv.d else "", " pw" if sv.k else ""])
	return out

# servers over a local broker (DS_BROKERS): client finds the dedicated server, is turned away
# with a wrong password, gets in with the right one, chats, then hosts its own; joiner joins it
func _srv_test():
	var role = OS.get_environment("DS_SRVTEST")
	yield(_wait(1.0), "completed")
	main.title._close(); main.start_game(G.new_state("srv" + role))
	yield(_wait(1.0), "completed")
	var net = main.net
	net.browse(true)
	var t0 = G.REAL_T
	var want = "Test Host" if role == "joiner" else "Test Dedicated"
	var found = null
	while G.REAL_T - t0 < 40 and found == null:
		for sv in net.server_list():
			if sv.name == want: found = sv
		yield(get_tree(), "idle_frame")
	_log("%s: servers %s" % [role, str(_list_names())])
	if found == null:
		_log("%s: did not find %s" % [role, want]); _quit_log(); return
	if role == "client":
		net.join_server(found.sid, "wrong")
		t0 = G.REAL_T
		while G.REAL_T - t0 < 20 and net.mode != "off" and not net.welcomed:
			yield(get_tree(), "idle_frame")
		_log("wrong password: mode %s welcomed %s" % [net.mode, str(net.welcomed)])
		net.browse(true)
		yield(_wait(2.0), "completed")
		net.join_server(found.sid, OS.get_environment("DS_PW"))
		t0 = G.REAL_T
		while G.REAL_T - t0 < 20 and not net.welcomed and net.mode != "off":
			yield(get_tree(), "idle_frame")
		_log("right password: welcomed %s on %s motd '%s' pvp %s" % [str(net.welcomed), net.server.name if net.server else "-", net.server.motd if net.server else "", str(net.server.pvp) if net.server else "-"])
		yield(_wait(1.5), "completed")
		_log("chat sent: %s" % str(net.send_chat("hello from the client")))
		yield(_wait(2.0), "completed")
		main.phone.open("online")
		yield(_wait(0.6), "completed")
		yield(_shot("srv1_on_dedicated"), "completed")
		main.phone.close()
		net.leave()
		yield(_wait(1.0), "completed")
		net.host_server({ "name": "Test Host", "motd": "hosted from the test", "pw": "", "max": 8, "pvp": false })
		t0 = G.REAL_T
		while G.REAL_T - t0 < 45 and net.R.size() == 0:
			yield(get_tree(), "idle_frame")
		_log("hosting: players %d" % net.R.size())
		yield(_wait(14.0), "completed")
		_log("hosting chat: %s" % str(net.chat))
		main.phone.open("online")
		yield(_wait(0.6), "completed")
		yield(_shot("srv2_hosting"), "completed")
		main.phone.close()
		net.leave()
	else:
		net.join_server(found.sid, "")
		t0 = G.REAL_T
		while G.REAL_T - t0 < 20 and not net.welcomed and net.mode != "off":
			yield(get_tree(), "idle_frame")
		_log("joiner: welcomed %s motd '%s' pvp %s" % [str(net.welcomed), net.server.motd if net.server else "", str(net.server.pvp) if net.server else "-"])
		yield(_wait(2.0), "completed")
		_log("chat sent: %s" % str(net.send_chat("hi host")))
		yield(_wait(5.0), "completed")
		_log("joiner sees players %d %s chat %s" % [net.R.size(), str(net.R.keys()), str(net.chat)])
		main.phone.open("online")
		yield(_wait(0.6), "completed")
		yield(_shot("srv3_joiner"), "completed")
		net.leave()
	_quit_log()

func _quit_log():
	var fl = File.new()
	if fl.open(out.plus_file("autotest.log"), File.WRITE) == OK:
		fl.store_string(PoolStringArray(log_lines).join("\n")); fl.close()
	get_tree().quit()

# the look: faces and beards up close, the finger in every view, the cel-shaded street
func _look_test():
	yield(_wait(1.0), "completed")
	main.title._close(); main.start_game(G.new_state("looktest"))
	yield(_wait(1.5), "completed")
	_clean_view(true)
	G.S["settings"]["fp"] = false
	G.time_offset += (12 * 60 + 30 - G.world_minutes())
	var P = main.player
	var spawn = P.pos
	var spawn_yaw = P.cam_yaw
	# five faces in a row
	var base = Vector3(4, 0, -20)
	var people = []
	for i in range(6):
		var sk = G.default_skin()
		sk["beard"] = i; sk["head"] = ["none", "none", "cap", "none", "beanie", "none"][i]; sk["tone"] = [1, 4, 2, 5, 3, 0][i]
		sk["hair"] = ["short", "afro", "buzz", "locs", "short", "twists"][i]
		var h = load("res://scripts/Human.gd").new().build(G.skin_opts(sk))
		main.add_child(h)
		h.translation = base + Vector3(i * 0.7 - 1.75, 0, 0)
		h.rotation.y = 0.0
		h.animate(0.016, { "speed": 0.0 })
		people.append(h)
	P.place(base.x, 0, base.z - 8, 0)
	_frame(base + Vector3(-1.4, 1.62, 1.5), base + Vector3(-1.4, 1.58, 0), 22)
	yield(_wait(0.6), "completed")
	yield(_shot("l1_faces_a"), "completed")
	main.cutscene.end(); _frame(base + Vector3(1.05, 1.62, 1.5), base + Vector3(1.05, 1.58, 0), 22)
	yield(_wait(0.4), "completed")
	yield(_shot("l2_faces_b"), "completed")
	main.cutscene.end(); _frame(base + Vector3(0, 1.4, 4.5), base + Vector3(0, 1.0, 0), 40)
	yield(_wait(0.4), "completed")
	yield(_shot("l3_lineup"), "completed")
	main.cutscene.end()
	for h in people: h.queue_free()
	# the finger in third person while running, seen from behind
	P.place(4, 0, -30, 0); P.cam_yaw = 0; P.cam_pitch = -0.05
	Input.action_press("move_f"); Input.action_press("sprint")
	P.flip_t = 6.0
	yield(_wait(1.2), "completed")
	yield(_shot("l4_flip_run_tp"), "completed")
	Input.action_release("sprint")
	# first person, walking
	G.S["settings"]["fp"] = true
	P.flip_t = 6.0
	yield(_wait(0.8), "completed")
	yield(_shot("l5_flip_fp"), "completed")
	Input.action_release("move_f")
	# in a car: third person, then the cockpit
	G.S["settings"]["fp"] = false
	var v = main.vehicles.spawn("sedan", P.pos.x + 2.4, P.pos.z, 0, { "color": 0x8a1c24, "owned": true })
	main.vehicles.enter(v)
	yield(_wait(0.8), "completed")
	P.flip_t = 6.0
	P.cam_yaw = v.yaw + PI + 0.5
	yield(_wait(1.0), "completed")
	yield(_shot("l6_flip_car_tp"), "completed")
	G.S["settings"]["fp"] = true
	P.flip_t = 6.0
	yield(_wait(1.0), "completed")
	yield(_shot("l7_flip_cockpit"), "completed")
	G.S["settings"]["fp"] = false
	P.exit_vehicle(true)
	# the street, cel-shaded
	_clean_view(false)
	P.place(2.5, 0, -16, 0); P.cam_yaw = 0.4; P.cam_pitch = 0.05
	yield(_wait(1.0), "completed")
	yield(_shot("l8_street"), "completed")
	G.time_offset += (21 * 60 - G.world_minutes())
	yield(_wait(1.0), "completed")
	yield(_shot("l9_street_night"), "completed")
	# where a new game starts (the sidewalk ice is there)
	G.time_offset += (13 * 60 - G.world_minutes())
	P.place(spawn.x, 0, spawn.z, spawn_yaw); P.cam_yaw = spawn_yaw; P.cam_pitch = -0.12
	yield(_wait(1.0), "completed")
	yield(_shot("l10_spawn"), "completed")
	get_tree().quit()

# only the tribute: night, pay respects, shots through the cutscene, then quit
func _mem_test():
	yield(_wait(1.0), "completed")
	main.title._close(); main.start_game(G.new_state("memtest"))
	yield(_wait(1.5), "completed")
	_clean_view(true)
	G.S["settings"]["fp"] = false
	var M = main.memorial
	G.time_offset += (22 * 60 - G.world_minutes())
	main.player.place(M.G_SPOT.x, 0, M.G_SPOT.z, 0)
	yield(_wait(0.5), "completed")
	M.pay_respects("garden")
	while M.fx.size() == 0:
		yield(get_tree(), "idle_frame")
	var e = M.fx[0]
	var k = 0
	for at in [0.3, 2.2, 3.6, 4.8, 6.0, 7.4, 8.8, 10.2, 11.6]:
		while e.t < at:
			yield(get_tree(), "idle_frame")
		var f = e.figure
		_log("t %.1f fig %s wing_a %.2f wing_rot %s piv %s vis %s cut %s" % [e.t, str(f.root.translation - M.MC), f.wing_mat.albedo_color.a, str(f.wings[0][0].rotation), str(f.wings[0][0].global_transform.origin - M.MC), str(f.wings[0][0].is_visible_in_tree()), str(main.cutscene.on)])
		yield(_shot("m%d_t%d" % [k, int(at * 10)]), "completed")
		k += 1
	var fl = File.new()
	if fl.open(out.plus_file("autotest.log"), File.WRITE) == OK:
		fl.store_string(PoolStringArray(log_lines).join("\n")); fl.close()
	get_tree().quit()

# the sky through the day, the memorial garden by day and night, and the lightning tribute
func _memorial_test():
	var P = main.player
	var M = main.memorial
	_clean_view(true)
	G.S["settings"]["fp"] = false
	G.time_offset += (13 * 60 - G.world_minutes())
	P.place(M.MC.x + 12.5, 0, M.MC.z + 6.5, 0)
	_frame(M.L(8.4, 1.75, 2.9), M.L(0.8, 2.1, 0.4), 56)
	yield(_wait(1.2), "completed")
	yield(_shot("28_garden_day"), "completed")
	main.cutscene.end(); _frame(M.L(5.6, 1.45, 0.9), M.L(1.6, 2.4, 0.0), 46)
	yield(_wait(0.5), "completed")
	yield(_shot("28b_facade"), "completed")
	main.cutscene.end(); _frame(M.L(4.6, 1.3, 1.2), M.L(0.45, 2.3, 3.95), 50)
	yield(_wait(0.5), "completed")
	yield(_shot("28c_poison_tree"), "completed")
	main.cutscene.end(); _frame(M.L(3.2, 0.9, -0.4), M.L(1.7, 0.8, -1.5), 48)
	yield(_wait(0.5), "completed")
	yield(_shot("28d_roses"), "completed")
	main.cutscene.end()
	P.place(M.MC.x + 9.0, 0, M.MC.z + 2.6, 0); P.cam_yaw = PI / 2 - 0.28; P.cam_pitch = 0.45
	yield(_wait(0.6), "completed")
	yield(_shot("29_sky_day"), "completed")
	G.time_offset += (16 * 60 + 38 - G.world_minutes())
	P.place(150, 0, 0, 0); P.cam_yaw = -deg2rad(main.sun_angles(G.world_minutes())[1]); P.cam_pitch = 0.18
	yield(_wait(1.0), "completed")
	yield(_shot("30_sky_dusk"), "completed")
	G.time_offset += (23 * 60 - G.world_minutes())
	P.cam_yaw = 0.2; P.cam_pitch = 0.55
	yield(_wait(1.0), "completed")
	yield(_shot("31_sky_night"), "completed")
	P.place(M.MC.x + 12.5, 0, M.MC.z + 6.5, 0)
	_frame(M.L(8.4, 1.75, 2.9), M.L(0.8, 2.1, 0.6), 56)
	yield(_wait(1.2), "completed")
	yield(_shot("32_garden_night"), "completed")
	main.cutscene.end(); _frame(M.L(4.4, 1.1, 1.6), M.L(0.45, 2.2, 3.95), 52)
	yield(_wait(0.6), "completed")
	yield(_shot("32b_poison_tree_night"), "completed")
	main.cutscene.end()
	# pay respects at the mausoleum: the storm gathers, lightning strikes, the camera takes over
	P.place(M.G_SPOT.x, 0, M.G_SPOT.z, 0)
	yield(_wait(0.3), "completed")
	M.pay_respects("garden")
	_log("respects: storm summoned, candles %d" % int(G.S["flags"].get("candles", 0)))
	var t0 = G.REAL_T
	while M.fx.size() == 0 and G.REAL_T - t0 < 15:
		yield(get_tree(), "idle_frame")
	_log("tribute after %.1f s, storm %.2f, strikes %d, cutscene %s" % [G.REAL_T - t0, main.sky.storm, main.sky.strikes, str(main.cutscene.on)])
	yield(_wait(0.15), "completed")
	yield(_shot("33_strike"), "completed")
	yield(_wait(1.9), "completed")
	yield(_shot("34_doors_open"), "completed")
	yield(_wait(1.6), "completed")
	yield(_shot("35_coming_out"), "completed")
	yield(_wait(2.0), "completed")
	yield(_shot("36_wings"), "completed")
	yield(_wait(2.6), "completed")
	yield(_shot("37_ascend"), "completed")
	yield(_wait(1.8), "completed")
	yield(_shot("38_doves"), "completed")
	yield(_wait(2.5), "completed")
	_log("after tribute: cutscene %s mode %s" % [str(main.cutscene.on), G.MODE])
	# a far strike over the city
	P.place(M.MC.x + 6.5, 0, M.MC.z - 1.8, 0)
	main.sky.strike("")
	P.cam_yaw = -main.sky.flash_az; P.cam_pitch = 0.3
	yield(_wait(0.05), "completed")
	yield(_shot("39_far_bolt"), "completed")
	main.sky.summon_until = -1
	yield(_wait(1.0), "completed")
	_clean_view(false)

func _rec_start():
	if OS.get_environment("DS_AUDIO") == "": return
	if not bus_logged:
		bus_logged = true
		for i in range(AudioServer.bus_count):
			_log("bus %d %s -> %s vol %.1f mute %s effects %d" % [i, AudioServer.get_bus_name(i), AudioServer.get_bus_send(i), AudioServer.get_bus_volume_db(i), str(AudioServer.is_bus_mute(i)), AudioServer.get_bus_effect_count(i)])
	for b in ["Master", "Guns", "Car", "Amb", "World"]:
		var i = AudioServer.get_bus_index(b)
		if i < 0: continue
		if not recs.has(b):
			recs[b] = AudioEffectRecord.new()
			AudioServer.add_bus_effect(i, recs[b])
		recs[b].set_recording_active(true)

func _rec_stop(name):
	for b in recs.keys():
		var r = recs[b]
		if not r.is_recording_active(): continue
		r.set_recording_active(false)
		var smp = r.get_recording()
		if smp: smp.save_to_wav(out.plus_file(name + ("" if b == "Master" else "_" + b) + ".wav"))
	_log("recorded " + name)

func _log(t):
	log_lines.append(t)
	print("[autotest] ", t)

func _go():
	yield(_wait(1.5), "completed")
	yield(_shot("01_title"), "completed")
	_diag()
	# progress from the web game (tools put a real web export in $HOME/Downloads)
	var ierr = G.import_web_save()
	_log("import: '%s' name %s cash %s gang %s recruits %d" % [ierr, G.S.get("name"), str(G.S.get("cash")), str(G.S.get("gang")), G.S.get("recruits", []).size()])
	if ierr == "":
		main.title._close()
		main.start_game(G.S)
		yield(_wait(2.5), "completed")
		_log("imported followers: %d  skin jacket %s head %s" % [main.gang.FOL.size(), str(G.S["skin"].get("jacket")), str(G.S["skin"].get("head"))])
		main.player.cam_yaw = PI
		yield(_wait(0.6), "completed")
		yield(_shot("02a_imported"), "completed")
		for a in ["map", "garage", "style", "settings", "stats", "pad", ""]:
			main.phone.open(a)
			yield(_wait(0.35), "completed")
			if a in ["map", "settings", "style"]: yield(_shot("02b_phone_" + a), "completed")
			main.phone.close()
		for it in G.D["INTERACT"]:
			if it.id in ["store", "home", "lake", "rec", "court"]:
				main.hud.interact(it)
				yield(_wait(0.2), "completed")
				if it.id == "store": yield(_shot("02c_store"), "completed")
				_log("interact %s: menu %s" % [it.id, str(main.hud.menu_box != null)])
				main.hud.close_menu()
		main.exit_to_title()
		yield(_wait(0.5), "completed")
	var st = G.new_state("godottest")
	st["cash"] = 5000; st["buzz"] = 60
	main.title._close()
	main.start_game(st)
	G.time_offset = 13 * 60 - G.world_minutes()
	var P = main.player
	P.place(2, 0, -20, 0)
	yield(_wait(2.0), "completed")
	yield(_shot("02_street_day"), "completed")
	_diag()
	# walk forward
	_rec_start()
	Input.action_press("move_f")
	yield(_wait(3.0), "completed")
	Input.action_release("move_f")
	_rec_stop("snd_walk")
	_log("walked to %s" % str(P.pos))
	# shoot
	var mag0 = G.S["guns"]["k9"].mag
	_rec_start()
	P.fire_cd = 0; P.try_fire()
	yield(_wait(1.0), "completed")
	if OS.get_environment("DS_AUDIO") != "":
		var cam = main.camera.global_transform.origin
		for pl in main.sfx.p3:
			if pl.playing: _log("playing %s at %.1f m db %.1f" % [pl.stream.resource_path.get_file(), pl.translation.distance_to(cam), pl.unit_db])
		for nd in get_tree().get_nodes_in_group("_x"): pass
	yield(_wait(1.0), "completed")
	_rec_stop("snd_shot")
	_log("shot: mag %d -> %d" % [mag0, G.S["guns"]["k9"].mag])
	yield(_wait(0.3), "completed")
	# fists on a pedestrian
	P.set_fists(true)
	var p = main.peds.make(P.pos.x, P.pos.z - 1.2)
	p.tough = 0
	for i in range(4):
		p.pos = P.pos + Vector3(0, 0, -1.2)
		P.cam_yaw = 0
		P.fire_cd = 0; P.punch()
		yield(_wait(0.25), "completed")
	_log("ped after punches: hp %.0f state %s" % [p.hp, p.state])
	yield(_shot("03_fists"), "completed")
	P.set_fists(false)
	# gang
	var err = main.gang.create("Lakeshore Kings", "lsk", 3)
	_log("gang: %s %s" % [err, str(G.S.get("gang"))])
	_log("real name refused: " + main.gang.create("Vice Lords", "VL", 0))
	for t in ["shooter", "brawler", "medic"]:
		main.gang.hire(t, randi() & 0xffff, main.gang.recruit_name(randi() & 0xffff))
	yield(_wait(2.5), "completed")
	_log("followers: %d" % main.gang.FOL.size())
	P.cam_yaw = PI
	yield(_wait(1.0), "completed")
	yield(_shot("04_gang"), "completed")
	# first person
	G.S["settings"]["fp"] = true
	yield(_wait(0.8), "completed")
	yield(_shot("05_first_person"), "completed")
	G.S["settings"]["fp"] = false
	# drive
	var v = main.vehicles.spawn("sedan", P.pos.x + 2.4, P.pos.z, 0, { "owned": true, "color": 0x8a1c24 })
	main.vehicles.enter(v)
	Input.action_press("move_f")
	yield(_wait(2.5), "completed")
	Input.action_release("move_f")
	_log("car speed %.1f at %s" % [v.speed, str(v.pos)])
	yield(_shot("06_driving"), "completed")
	G.S["settings"]["fp"] = true
	Input.action_press("move_f"); Input.action_press("move_l")
	_rec_start()
	yield(_wait(3.0), "completed")
	_rec_stop("snd_drive")
	yield(_shot("06b_cockpit"), "completed")
	_log("engine rpm %d gear %d" % [int(main.sfx.E.rpm), main.sfx.E.gear + 1])
	Input.action_release("move_f"); Input.action_release("move_l")
	G.S["settings"]["fp"] = false
	P.exit_vehicle(true)
	# a rival crew
	main.crews.spawn_crew(P.pos + Vector3(0, 0, -14), 2, 1)
	yield(_wait(2.0), "completed")
	_log("crew state: " + main.crews.CREWS[0].state if main.crews.CREWS.size() > 0 else "no crew")
	# night
	G.time_offset += (22 * 60 - G.world_minutes())
	yield(_wait(1.5), "completed")
	yield(_shot("07_night"), "completed")
	_diag()
	yield(_memorial_test(), "completed")
	# phone
	main.phone.open("gang")
	yield(_wait(0.6), "completed")
	yield(_shot("08_phone_gang"), "completed")
	main.phone.close()
	yield(_tour(), "completed")
	_log("traffic %d peds %d cops %d" % [main.vehicles.TRAFFIC.size(), main.peds.PEDS.size(), main.police.COPS.size()])
	_log("fps %d" % Engine.get_frames_per_second())
	var f = File.new()
	if f.open(out.plus_file("autotest.log"), File.WRITE) == OK:
		f.store_string(PoolStringArray(log_lines).join("\n")); f.close()
	get_tree().quit()

# the wardrobe and every phone screen, then quit
func _ui_test():
	yield(_wait(1.0), "completed")
	main.title._close(); main.start_game(G.new_state("uitest"))
	yield(_wait(1.5), "completed")
	G.time_offset += (16 * 60 + 20 - G.world_minutes())
	var P = main.player
	P.place(2.5, 0, -16, 0); P.cam_yaw = 0.4; P.cam_pitch = 0.02
	G.S["threads"]["benny"] = [{ "text": "yo the booth is open tonight" }, { "text": "Ostrava Snowplow on the bench now. loud tho. real loud" }]
	G.S["threads"]["kiara"] = [{ "text": "saw that post. proud of u for walking away" }]
	G.S["threads"]["coach"] = [{ "text": "Heard you walked away tonight. That is the hardest thing to do." }]
	G.S["unread"]["benny"] = 2; G.S["unread"]["kiara"] = 1
	main.wardrobe.open()
	yield(_wait(0.8), "completed")
	main.wardrobe._set_cat(2)
	yield(_wait(0.5), "completed")
	yield(_shot("u01_wardrobe_hair"), "completed")
	main.wardrobe._set_cat(4)
	yield(_wait(0.4), "completed")
	yield(_shot("u02_wardrobe_top"), "completed")
	main.wardrobe._set_cat(0)
	yield(_wait(0.4), "completed")
	yield(_shot("u03_wardrobe_presets"), "completed")
	main.wardrobe.cancel()
	yield(_wait(0.3), "completed")
	main.phone.open()
	yield(_wait(0.15), "completed")
	yield(_shot("u04_phone_opening"), "completed")
	yield(_wait(0.6), "completed")
	yield(_shot("u05_home"), "completed")
	var i = 6
	for a in ["msgs", "jobs", "blok", "map", "camera", "online", "gang", "garage", "settings", "pad", "stats"]:
		main.phone.show_app(a)
		yield(_wait(0.45), "completed")
		yield(_shot("u%02d_%s" % [i, a]), "completed")
		i += 1
	main.phone.show_app("msgs")
	main.phone._open_thread("benny")
	yield(_wait(0.45), "completed")
	yield(_shot("u%02d_thread" % i), "completed")
	i += 1
	for k in ["silver", "black", "burgundy", "glacier"]:
		G.S["settings"]["phoneCol"] = k
		main.phone._tint(); main.phone._home()
		yield(_wait(0.35), "completed")
		yield(_shot("u%02d_home_%s" % [i, k]), "completed")
		i += 1
	main.phone.close()
	yield(_wait(0.5), "completed")
	_log("phone visible after close: %s" % str(main.phone.panel.visible))
	get_tree().quit()
