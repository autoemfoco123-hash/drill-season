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
	elif OS.get_environment("DS_ROOMTEST") != "": call_deferred("_room_test")
	elif OS.get_environment("DS_COLTEST") != "": call_deferred("_col_test")
	elif OS.get_environment("DS_ANIMTEST") != "": call_deferred("_anim_test")
	elif OS.get_environment("DS_DEATHTEST") != "": call_deferred("_death_test")
	elif OS.get_environment("DS_GUNTEST") != "": call_deferred("_gun_test")
	elif OS.get_environment("DS_CONSOLETEST") != "": call_deferred("_console_test")
	elif OS.get_environment("DS_PROMOTEST") != "": call_deferred("_promo_test")
	elif OS.get_environment("DS_TRAILER") != "": call_deferred("_trailer")
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
	main.hud.wheel_page = 0; main.hud.wheel_sel = 0
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
	# the eras crew: a shot of each, framed like a portrait
	var k2 = 0
	G.time_offset += (13 * 60 - G.world_minutes())
	for c in main.eras.CREW:
		# a camera spot in the open, with a clear view of them
		var fwd = Vector3(sin(c.yaw), 0, cos(c.yaw))
		for k3 in range(16):
			var a3 = c.yaw + k3 * TAU / 16.0 * (1 if k3 % 2 == 0 else -1) * 0.5
			var f3 = Vector3(sin(a3), 0, cos(a3))
			var cp = c.pos + f3 * 4.0
			if not W.is_blocked(cp.x, cp.z, 0.4) and W.seg_clear(cp + Vector3(0, 1.3, 0), c.pos + Vector3(0, 1.2, 0)):
				fwd = f3; break
		P.place(c.pos.x + fwd.x * 6, 0, c.pos.z + fwd.z * 6, 0)
		_frame(c.pos + fwd * 4.0 + Vector3(0, 1.35, 0), c.pos + Vector3(0, 0.95, 0), 40)
		yield(_wait(0.5), "completed")
		yield(_shot("e%d_%s" % [k2, c.name.replace(" ", "_")]), "completed")
		main.cutscene.end()
		k2 += 1
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
	main.wardrobe._set_cat(3)
	yield(_wait(0.5), "completed")
	yield(_shot("u01_wardrobe_hair"), "completed")
	main.wardrobe._set_cat(5)
	yield(_wait(0.4), "completed")
	yield(_shot("u02_wardrobe_top"), "completed")
	main.wardrobe._set_cat(1)
	yield(_wait(0.4), "completed")
	yield(_shot("u03_wardrobe_eras"), "completed")
	main.wardrobe._era(4)
	yield(_wait(0.4), "completed")
	yield(_shot("u03b_wardrobe_era2020"), "completed")
	main.wardrobe.cancel()
	yield(_wait(0.3), "completed")
	main.hud.menu("Calder Mini Mart · open late", "Mini Mart", "Coffee, hand warmers and snacks. Warm up before you head back out.", [
		{ "label": "Hot coffee", "hint": "$4", "desc": "Warms you up for a while." },
		{ "label": "Hand warmers", "hint": "$6", "desc": "Slow the cold for the next few minutes." },
		{ "label": "Energy drink", "hint": "$5", "desc": "More stamina for a sprint." },
		{ "label": "Lottery ticket", "hint": "Sold out", "disabled": true },
		{ "label": "Leave", "hint": "" }])
	yield(_wait(0.5), "completed")
	yield(_shot("u00_menu"), "completed")
	main.hud.close_menu()
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

# the rooms you walk into: Basement 808 and Ironside Arms, then quit
func _room_test():
	yield(_wait(1.0), "completed")
	main.title._close(); main.start_game(G.new_state("roomtest"))
	yield(_wait(1.5), "completed")
	G.time_offset += (14 * 60 - G.world_minutes())
	G.S["cash"] = 9000; G.S["buzz"] = 60; G.S["flags"]["studioCut"] = true
	var P = main.player
	var I = main.interiors
	# the shop front on Calder Ave
	P.place(-15.2, 0, -3.0, PI); P.cam_yaw = 0.0; P.cam_pitch = 0.08
	_frame(Vector3(-15.2, 2.2, 2.0), Vector3(-15.2, 2.0, -10.0), 50)
	yield(_wait(0.6), "completed")
	yield(_shot("r1_gunshop_front"), "completed")
	main.cutscene.end()
	P.place(-15.2, 0, -8.4, PI)
	yield(_wait(0.3), "completed")
	_log("at the shop door: %s" % str(main.hud._prompt()))
	I.enter("gunshop")
	yield(_wait(1.0), "completed")
	_log("inside: %s at %s" % [I.inside, str(P.pos)])
	yield(_shot("r2_gunshop_in"), "completed")
	var o = I.ROOMS.gunshop.o
	_frame(o + Vector3(4.5, 2.4, 3.8), o + Vector3(-1.0, 1.0, -2.0), 60)
	yield(_wait(0.5), "completed")
	yield(_shot("r3_gunshop_wide"), "completed")
	main.cutscene.end()
	P.place(o.x - 0.5, o.y, o.z + 0.3, 0.0)
	yield(_wait(0.3), "completed")
	_log("at the counter: %s" % str(main.hud._prompt()))
	I.counter_menu()
	yield(_wait(0.4), "completed")
	yield(_shot("r4_counter_menu"), "completed")
	main.hud.close_menu()
	# walk into the back wall for two seconds: still inside?
	Input.action_press("move_f")
	yield(_wait(2.0), "completed")
	Input.action_release("move_f")
	_log("after walking into the wall: %s (room z %.1f..%.1f)" % [str(P.pos), o.z - 5, o.z + 5])
	I.leave()
	yield(_wait(1.0), "completed")
	_log("left: inside '%s' at %s" % [I.inside, str(P.pos)])
	# the studio
	P.place(41, 0, -8.0, PI)
	yield(_wait(0.3), "completed")
	_log("at the studio door: %s" % str(main.hud._prompt()))
	I.enter("studio")
	yield(_wait(1.0), "completed")
	_log("inside: %s at %s" % [I.inside, str(P.pos)])
	yield(_shot("r5_studio_in"), "completed")
	var so = I.ROOMS.studio.o
	_frame(so + Vector3(3.8, 2.4, 3.0), so + Vector3(-1.5, 0.9, -3.5), 62)
	yield(_wait(0.5), "completed")
	yield(_shot("r6_studio_wide"), "completed")
	main.cutscene.end()
	_frame(so + Vector3(0.2, 1.7, -1.2), so + Vector3(-3.4, 1.3, -4.8), 55)
	yield(_wait(0.5), "completed")
	yield(_shot("r7_studio_booth"), "completed")
	main.cutscene.end()
	_frame(so + Vector3(1.0, 1.5, -2.2), so + Vector3(4.6, 1.4, 0.5), 60)
	yield(_wait(0.5), "completed")
	yield(_shot("r8_studio_couch"), "completed")
	main.cutscene.end()
	P.place(so.x - 3.3, so.y, so.z - 4.0, 0.0)
	yield(_wait(0.3), "completed")
	_log("in the booth: %s" % str(main.hud._prompt()))
	I.leave()
	yield(_wait(1.0), "completed")
	_log("left: inside '%s' at %s" % [I.inside, str(P.pos)])
	# home
	var L = G.D["LOC"]["home"]
	P.place(L.x + 0.6, 0, L.z, -PI / 2)
	yield(_wait(0.3), "completed")
	_log("at home's door: %s" % str(main.hud._prompt()))
	I.enter("home")
	yield(_wait(1.0), "completed")
	_log("inside: %s" % I.inside)
	yield(_shot("r9_home_in"), "completed")
	var ho = I.ROOMS.home.o
	_frame(ho + Vector3(4.8, 2.2, 4.2), ho + Vector3(0.5, 0.8, -1.5), 64)
	yield(_wait(0.5), "completed")
	yield(_shot("r10_home_living"), "completed")
	main.cutscene.end()
	_frame(ho + Vector3(-1.8, 1.9, -0.9), ho + Vector3(-4.4, 0.6, -3.8), 60)
	yield(_wait(0.5), "completed")
	yield(_shot("r11_home_bedroom"), "completed")
	main.cutscene.end()
	_frame(ho + Vector3(-0.8, 1.9, 4.4), ho + Vector3(-4.8, 0.9, 1.8), 60)
	yield(_wait(0.5), "completed")
	yield(_shot("r12_home_kitchen"), "completed")
	main.cutscene.end()
	P.place(ho.x - 3.2, ho.y, ho.z - 2.4, 0.0)
	yield(_wait(0.3), "completed")
	_log("by the bed: %s" % str(main.hud._prompt()))
	I.leave()
	yield(_wait(1.0), "completed")
	_log("left home: inside '%s' at %s" % [I.inside, str(P.pos)])
	# the Mini Mart
	P.place(16, 0, -7.2, PI)
	yield(_wait(0.3), "completed")
	_log("at the store's door: %s" % str(main.hud._prompt()))
	I.enter("store")
	yield(_wait(1.0), "completed")
	yield(_shot("r13_store_in"), "completed")
	var to = I.ROOMS.store.o
	_frame(to + Vector3(5.2, 2.4, 4.3), to + Vector3(-1.0, 0.9, -2.0), 64)
	yield(_wait(0.5), "completed")
	yield(_shot("r14_store_wide"), "completed")
	main.cutscene.end()
	P.place(to.x - 3.6, to.y, to.z + 3.6, PI)
	yield(_wait(0.3), "completed")
	_log("at the register: %s" % str(main.hud._prompt()))
	I.leave()
	yield(_wait(1.0), "completed")
	_log("left the store: inside '%s' at %s" % [I.inside, str(P.pos)])
	get_tree().quit()

# collisions: a car into a wall at an angle, two cars head-on, a body against a turned car,
# a car pushing a body lying in the road, people packed into one spot
func _corner_depth(v, b):
	var A = main.vehicles._axes(v)
	var worst = 0.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var c = Vector2(v.pos.x, v.pos.z) + A[0] * A[2].x * sx + A[1] * A[2].y * sz
			if c.x > b[0] and c.x < b[2] and c.y > b[1] and c.y < b[3]:
				worst = max(worst, min(min(c.x - b[0], b[2] - c.x), min(c.y - b[1], b[3] - c.y)))
	return worst

func _col_test():
	yield(_wait(1.0), "completed")
	main.title._close(); main.start_game(G.new_state("coltest"))
	yield(_wait(1.5), "completed")
	G.time_offset += (13 * 60 - G.world_minutes())
	var P = main.player
	var V = main.vehicles
	# 1. into the Mini Mart wall at an angle, full throttle
	var car = V.spawn("sedan", 18, -2, atan2(0.55, -1.0), { "color": 0x8a1c24, "owned": true })
	V.enter(car)
	yield(_wait(0.5), "completed")
	Input.action_press("move_f")
	var worst = 0.0
	for _i in range(40):
		yield(_wait(0.05), "completed")
		worst = max(worst, _corner_depth(car, [10.5, -26, 26, -10.5]))
	Input.action_release("move_f")
	_log("wall: car at %s, deepest corner inside the building %.3f m" % [str(car.pos), worst])
	_frame(car.pos + Vector3(6, 4, 7), car.pos + Vector3(0, 0.5, -1), 50)
	yield(_wait(0.4), "completed")
	yield(_shot("c1_wall"), "completed")
	main.cutscene.end()
	P.exit_vehicle(true)
	yield(_wait(0.5), "completed")
	# 2. head-on into a parked car
	var a = V.spawn("sedan", 30, 3.2, PI / 2, { "color": 0x2a5aa8, "owned": true })
	var b = V.spawn("suv", 52, 3.2, -PI / 2, { "color": 0xe8e8ea, "owned": true })
	V.enter(a)
	yield(_wait(0.4), "completed")
	Input.action_press("move_f")
	var overlap = 0.0
	for _i2 in range(50):
		yield(_wait(0.05), "completed")
		var A = V._axes(a)
		var B = V._axes(b)
		var r = V._sat(Vector2(a.pos.x, a.pos.z), A[0], A[1], A[2], Vector2(b.pos.x, b.pos.z), B[0], B[1], B[2])
		if r != null: overlap = max(overlap, r[1])
	Input.action_release("move_f")
	_log("head-on: most overlap between the cars %.3f m, parked car moved to %s" % [overlap, str(b.pos)])
	P.exit_vehicle(true)
	yield(_wait(0.5), "completed")
	# 3. a body falling against a car turned 45 degrees
	var t = V.spawn("sedan", 0, -62, 0.785, { "color": 0x4f8a3a, "owned": true })
	V.place(t)
	P.place(6, 0, -56, 0)
	var ped = main.peds.make(1.7, -61.2)
	yield(_wait(0.3), "completed")
	ped.take_hit(300, false, Vector3(-1, 0, -0.3).normalized(), false, false)
	yield(_wait(3.0), "completed")
	var inside = 0
	var gap = INF
	for q in ped.h.rag.p:
		var l = W._local(t.box, q.x, q.z)
		if abs(l.x) < t.box.hw - 0.02 and abs(l.y) < t.box.hl - 0.02 and q.y < t.box.y1 - 0.02: inside += 1
		gap = min(gap, max(abs(l.x) - t.box.hw, abs(l.y) - t.box.hl))
	_log("body vs turned car: %d of %d points inside, closest point %.2f m from the car's side" % [inside, ped.h.rag.p.size(), gap])
	_frame(t.pos + Vector3(5, 3.5, 4), t.pos + Vector3(0.8, 0.4, 0.3), 50)
	yield(_wait(0.4), "completed")
	yield(_shot("c2_body_car"), "completed")
	main.cutscene.end()
	# 4. a car rolling into a body lying in the road
	var ped2 = main.peds.make(0, -82)
	yield(_wait(0.3), "completed")
	ped2.take_hit(300, false, Vector3(0, 0, -1), false, false)
	yield(_wait(3.0), "completed")
	var before = ped2.h.ragdoll_center()
	var c3 = V.spawn("sedan", 0, -70, PI, { "color": 0xc8a878, "owned": true })
	V.enter(c3)
	yield(_wait(0.4), "completed")
	Input.action_press("move_f")
	yield(_wait(1.4), "completed")
	Input.action_release("move_f")
	yield(_wait(1.0), "completed")
	_log("body in the road: from %s to %s (moved %.1f m)" % [str(before), str(ped2.h.ragdoll_center()), before.distance_to(ped2.h.ragdoll_center())])
	P.exit_vehicle(true)
	yield(_wait(0.5), "completed")
	# 5. people packed into one spot
	P.place(-20, 0, -60, 0)
	var crowd = []
	for k in range(4):
		crowd.append(main.peds.make(-20 + k * 0.05, -60 + k * 0.04))
	yield(_wait(0.6), "completed")
	var mind = INF
	var all = crowd + [P]
	for i in range(all.size()):
		for j in range(i + 1, all.size()):
			mind = min(mind, Vector2(all[i].pos.x - all[j].pos.x, all[i].pos.z - all[j].pos.z).length())
	_log("crowd: closest two people %.2f m apart (bodies are about 0.6 m wide)" % mind)
	get_tree().quit()

# the walk, the run and standing still, seen from the side: frames across one cycle each
func _anim_test():
	yield(_wait(1.0), "completed")
	main.title._close(); main.start_game(G.new_state("animtest"))
	yield(_wait(1.5), "completed")
	_clean_view(true); G.S["settings"]["fp"] = false
	G.time_offset += (13 * 60 - G.world_minutes())
	var P = main.player
	P.place(-30, 0, -60, 0)
	var h = load("res://scripts/Human.gd").new().build(G.skin_opts(G.default_skin()))
	main.add_child(h); G.toon_tree(h, true)
	var at = Vector3(0, 0, -66)
	h.translation = at; h.rotation.y = PI / 2
	_frame(at + Vector3(0, 1.0, 4.2), at + Vector3(0, 0.9, 0), 40)
	# footfalls per second at crouch, walk and sprint speed (the footstep sounds follow these)
	for sp in [2.1, 2.7, 4.3, 7.3]:
		for _j in range(100): h.animate(0.01, { "speed": sp })
		var f0 = h.foot
		for _j in range(300): h.animate(0.01, { "speed": sp })
		_log("footfalls at %.1f m/s: %.2f a second" % [sp, (h.foot - f0) / 3.0])
	h.animate(0.5, { "speed": 0.0 })
	if "dances" in OS.get_environment("DS_ANIMTEST"):
		h.rotation.y = 0.55
		_frame(at + Vector3(0, 1.0, 3.8), at + Vector3(0, 0.75, 0), 40)
		for dn in ["griddy", "shmoney", "woah", "hitfolks"]:
			h.animate(0.5, { "speed": 0.0 })
			var et = 0.0
			# griddy: the goggles come on beats 6-8, shmoney swaps arms after 8 beats
			var span = { "griddy": 8.0 / 2.6, "shmoney": 10.0 / 2.2, "woah": 4.0 / 2.2, "hitfolks": 2.0 / 2.3 }[dn]
			for k in range(6):
				var target = 0.3 + k * span / 5.0
				while et < target:
					et += 0.016
					h.animate(0.016, { "speed": 0.0, "emote": dn, "et": et })
				yield(get_tree(), "idle_frame")
				yield(_shot("a_%s_%d" % [dn, k]), "completed")
		get_tree().quit()
		return
	if "sturdy" in OS.get_environment("DS_ANIMTEST"):
		h.rotation.y = 0.55
		_frame(at + Vector3(0, 1.0, 3.8), at + Vector3(0, 0.75, 0), 40)
		var et = 0.0
		for k in range(10):
			# two beats per stomp pair: ten frames across four beats
			var target = 0.3 + k * (4.0 / 2.3) / 10.0
			while et < target:
				et += 0.016
				h.animate(0.016, { "speed": 0.0, "emote": "sturdy", "et": et })
			yield(get_tree(), "idle_frame")
			yield(_shot("a_sturdy_%d" % k), "completed")
		# the fist pump on beats 7-8
		et = 6.0 / 2.3 + 0.02
		h.animate(0.016, { "speed": 0.0, "emote": "sturdy", "et": et })
		yield(get_tree(), "idle_frame")
		yield(_shot("a_sturdy_pump"), "completed")
		get_tree().quit()
		return
	for spec in [["walk", 1.45, 8], ["run", 6.0, 8], ["idle", 0.0, 3]]:
		var n = spec[2]
		var cyc = 2.5 if spec[1] <= 0 else (1.45 if spec[1] < 3 else 3.1) / spec[1]
		for k in range(n):
			# run the animation in small steps to the next frame of the cycle
			var steps = int(ceil(cyc / n / 0.016))
			for _j in range(steps):
				h.animate(0.016, { "speed": spec[1] })
				yield(get_tree(), "idle_frame")
			yield(_shot("a_%s_%d" % [spec[0], k]), "completed")
	get_tree().quit()

# console mode (run with DS_CONSOLE=1 DS_FAKEPAD=xbox): the home screen, the on-screen keyboard,
# the HUD in the TV layout with button icons, the pause menu, the controls screen (Xbox and
# PlayStation), the emote wheel's two pages, the phone, and aim assist pulling onto a target
func _console_test():
	yield(_wait(1.5), "completed")
	var C = main.console
	_log("console %s · pad %s (%s) · ui %s" % [str(C.on), G.pad_kind, G.pad_name(), str(get_viewport().get_visible_rect().size)])
	yield(_shot("c01_splash"), "completed")
	C._home_tiles()
	yield(_wait(0.5), "completed")
	yield(_shot("c02_home"), "completed")
	C.tiles[1].grab_focus()
	yield(_wait(0.3), "completed")
	C._t_new()
	yield(_wait(0.2), "completed")
	var K = C.osk
	# type "ice" with the D-pad and A, then the rest
	K.row = 2; K.col = 0
	K.move(Vector2(0, -1)); K.move(Vector2(1, 0)); K.move(Vector2(1, 0)); K.move(Vector2(1, 0)); K.move(Vector2(1, 0)); K.move(Vector2(1, 0)); K.move(Vector2(1, 0)); K.move(Vector2(1, 0))
	_log("keyboard key: %s" % K.keys[K.row][K.col][0])
	K.press()
	K.type("ce.kold")
	K.shift = true
	yield(_wait(0.2), "completed")
	yield(_shot("c03_keyboard"), "completed")
	_log("typed: %s" % K.text)
	C.close_keyboard(true)
	yield(_wait(2.0), "completed")
	_log("started as @%s, mode %s" % [G.S["name"], G.MODE])
	G.time_offset += (13 * 60 - G.world_minutes())
	var P = main.player
	P.place(2, 0, -20, 0)
	var v = main.vehicles.spawn("sedan", P.pos.x + 2.4, P.pos.z, 0, { "owned": true, "color": 0x8a1c24 })
	yield(_wait(1.0), "completed")
	yield(_shot("c04_hud"), "completed")
	C.pause_menu()
	yield(_wait(0.3), "completed")
	yield(_shot("c05_pause"), "completed")
	main.hud.close_menu()
	C.controls()
	yield(_wait(0.3), "completed")
	yield(_shot("c06_controls"), "completed")
	G.pad_kind = "ps"
	C.over.update()
	yield(_wait(0.2), "completed")
	yield(_shot("c07_controls_ps"), "completed")
	C.close_controls()
	yield(_wait(0.4), "completed")
	yield(_shot("c08_hud_ps"), "completed")
	G.pad_kind = "xbox"
	main.vehicles.remove(v)
	# the emote wheel: dances, then gestures
	Input.action_press("emote")
	main.hud.wheel_page = 0
	main.hud._open_wheel("emote"); main.hud.wheel_vec = Vector2(70, -40)
	yield(_wait(0.3), "completed")
	yield(_shot("c09_wheel_dances"), "completed")
	main.hud.wheel_flip(1)
	main.hud.wheel_vec = Vector2(-60, -60)
	yield(_wait(0.3), "completed")
	yield(_shot("c10_wheel_emotes"), "completed")
	main.hud.wheel_flip(-1)
	main.hud.wheel_sel = 4
	Input.action_release("emote")
	yield(_wait(1.2), "completed")
	_log("wheel picked: %s" % P.emote_name)
	_clean_view(false)
	P.cam_yaw = PI
	yield(_shot("c11_griddy"), "completed")
	P.emote_name = ""
	# the phone in the TV layout
	main.phone.open("settings")
	yield(_wait(0.9), "completed")
	yield(_shot("c12_phone_settings"), "completed")
	main.phone.close(true)
	yield(_wait(0.5), "completed")
	# aim assist: a crew member a little off the crosshair, the controller aiming
	var fwd = -main.camera.global_transform.basis.z
	var side = Vector3(-fwd.z, 0, fwd.x).normalized()
	var at = P.pos + Vector3(fwd.x, 0, fwd.z).normalized() * 11 + side * 1.4
	var crew = main.crews.spawn_crew(at, 1, 0)
	var e = crew.members[0]
	crew.state = "standoff"
	G.last_pad = true
	Input.action_press("aim")
	var angs = []
	for i in range(40):
		yield(get_tree(), "idle_frame")
		e.pos = at
		var cam = main.camera
		var to = (e.pos + Vector3(0, 1.3, 0) - cam.global_transform.origin).normalized()
		if i % 8 == 0: angs.append(stepify(rad2deg((-cam.global_transform.basis.z).angle_to(to)), 0.1))
	Input.action_release("aim")
	_log("aim assist, degrees off target over time: %s (assist %.2f)" % [str(angs), P.assist_f])
	get_tree().quit()

# key art for the store (DS_PROMOTEST=key|wide|tall, run at the size wanted with --resolution):
# a crew of four era characters on Calder Ave at night, a train sitting on the L overhead, the
# Kessler Bruiser behind them with its lights on, a cruiser further down, snow coming down
func _promo_test():
	var mode = OS.get_environment("DS_PROMOTEST")
	yield(_wait(1.0), "completed")
	main.title._close(); main.start_game(G.new_state("promo"))
	yield(_wait(1.5), "completed")
	G.S["settings"]["quality"] = "high"; main.set_quality("high")
	G.S["settings"]["outlines"] = true; G.apply_outlines()
	_clean_view(true)
	G.S["settings"]["fp"] = false
	main.sky.override = { "cover": 0.85, "storm": 0.0, "aurora": 0.0 }
	# night, with the first train dwelling at the platform over Calder Ave
	var tod = float(OS.get_environment("DS_PROMOTIME")) if OS.get_environment("DS_PROMOTIME") != "" else 21.6
	G.time_offset += (tod * 60 - G.world_minutes())
	var T = main.train.TR[0]
	var P = main.player
	var X = float(OS.get_environment("DS_PROMOX")) if OS.get_environment("DS_PROMOX") != "" else 33.0
	P.place(X - 24, 0, 0.5, 0)      # well behind every camera below
	# the crew, facing the camera (west), on the road
	var looks = [5, 7, 4, 2]
	var poses = [["shmoney", 0.35], ["", 0.0], ["point", 1.0], ["sturdy", 0.3]]
	var spots = [Vector3(X + 1.0, 0, 2.7), Vector3(X, 0, 0.95), Vector3(X + 0.3, 0, -0.95), Vector3(X + 1.2, 0, -2.6)]
	if mode == "tall":
		# portrait: the one pointing right up front, the others close behind him
		spots = [Vector3(X + 2.6, 0, 1.9), Vector3(X + 1.0, 0, 1.15), Vector3(X - 1.4, 0, 0.05), Vector3(X + 1.3, 0, -1.25)]
	var crew = []
	for i in range(4):
		var sk = G.era_skin(looks[i])
		sk["tone"] = [5, 2, 4, 1][i]
		var h = load("res://scripts/Human.gd").new().build(G.skin_opts(sk))
		main.add_child(h); G.toon_tree(h, true)
		h.translation = spots[i]
		h.rotation.y = -PI / 2 + [0.4, 0.08, -0.12, -0.45][i]
		crew.append(h)
	main.vehicles.spawn("bruiser", X + 6.5, 1.6, -PI / 2 + 0.55, { "color": 0x8a1c24, "owned": true })
	main.vehicles.spawn("police", X + 15.0, -2.6, -PI / 2 - 0.4, { "owned": true })
	# key-art lighting: a warm key from the front left, police red and blue rims from behind
	var lk = float(OS.get_environment("DS_PROMOLIGHT")) if OS.get_environment("DS_PROMOLIGHT") != "" else 1.0
	for L in [[Vector3(X - 2.5, 4.2, 3.0), Color(1.0, 0.75, 0.5), 0.55 * lk, 8.0], [Vector3(X + 3, 2.8, -3.2), Color(0.3, 0.5, 1.0), 1.1 * lk, 6.0],
			[Vector3(X + 3, 2.6, 3.4), Color(1.0, 0.22, 0.28), 1.0 * lk, 6.0], [Vector3(X + 15, 2.2, -2.6), Color(0.25, 0.45, 1.0), 1.6 * lk, 8.0], [Vector3(X + 15.5, 2.2, -1.2), Color(1.0, 0.15, 0.2), 1.4 * lk, 7.0]]:
		var o = OmniLight.new(); o.translation = L[0]; o.light_color = L[1]; o.light_energy = L[2]; o.omni_range = L[3]; o.omni_attenuation = 1.4
		main.add_child(o)
	# no steam vents in the shot
	G.D["VENTS"] = []
	_promo_clear(X)
	for _f in range(12):
		for i in range(4):
			crew[i].animate(0.016, { "speed": 0.0, "emote": poses[i][0], "et": poses[i][1], "mug": true })
		yield(get_tree(), "idle_frame")
	var cams = {
		"key": [Vector3(X - 6.2, 0.6, 0.45), Vector3(X + 1, 2.0, 0.0), 42],
		"wide": [Vector3(X - 9.0, 0.8, 0.35), Vector3(X + 1, 2.5, 0.0), 30],
		"tall": [Vector3(X - 6.4, 0.5, 0.15), Vector3(X, 2.55, 0.05), 56],
		"side": [Vector3(X - 8.6, 0.62, 0.5), Vector3(X + 1, 2.1, -2.6), 44],
	}
	var c = cams.get(mode, cams["key"])
	_frame(c[0], c[1], c[2])
	for _f in range(20):
		_promo_clear(X)
		yield(get_tree(), "idle_frame")
	# the train halfway through its stop at the platform
	var ph = fposmod(G.world_seconds() + T.off, main.train.CYCLE)
	G.time_offset += main.train.T1 + main.train.T2 * 0.5 - ph
	_promo_clear(X)
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	main.cutscene.layer.visible = false
	for i in range(4):
		crew[i].animate(0.016, { "speed": 0.0, "emote": poses[i][0], "et": poses[i][1], "mug": true })
	yield(_shot("p_%s" % mode), "completed")
	_log("promo %s: train %s at z %.1f, viewport %s" % [mode, T.state, T.z, str(get_viewport().size)])
	get_tree().quit()

# trailer shots, frame by frame (Trailer.gd)
func _trailer():
	var t = load("res://scripts/Trailer.gd").new()
	t.name = "Trailer"
	add_child(t)
	t.run(main, self)

# an empty street for the key art: no traffic, nobody walking through the shot
func _promo_clear(X):
	for v in main.vehicles.VEH.duplicate():
		if not v.owned and v.pos.distance_to(Vector3(X, 0, 0)) < 90: main.vehicles.remove(v)
	for pd in main.peds.PEDS.duplicate():
		if pd.pos.distance_to(Vector3(X, 0, 0)) < 60: main.peds.remove(pd)
	# the street's regulars (the eras crew, the story cast) step out of frame too
	for c in main.eras.CREW:
		if c.h and is_instance_valid(c.h): c.h.queue_free()
	main.eras.CREW = []
	for k in main.story.NPCS.keys():
		var n = main.story.NPCS[k]
		if n.h and is_instance_valid(n.h): n.h.translation = Vector3(0, -50, 0)

# dying: the ragdoll, the camera on it, the red screen, then waking up at the hospital
func _death_test():
	yield(_wait(1.0), "completed")
	main.title._close(); main.start_game(G.new_state("deathtest"))
	yield(_wait(1.5), "completed")
	G.time_offset += (13 * 60 - G.world_minutes())
	var P = main.player
	P.place(2.5, 0, -16, 0)
	yield(_wait(0.5), "completed")
	P.hurt(500, P.pos + Vector3(0, 0, -3))
	yield(_wait(0.5), "completed")
	yield(_shot("d1_falling"), "completed")
	yield(_wait(1.5), "completed")
	yield(_shot("d2_dead"), "completed")
	yield(_wait(2.5), "completed")
	yield(_wait(1.0), "completed")
	yield(_shot("d3_press"), "completed")
	_log("dead %s, death_t %.1f, mode %s" % [str(P.dead), P.death_t, G.MODE])
	Input.action_press("jump")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	Input.action_release("jump")
	yield(_wait(2.0), "completed")
	_log("after respawn: dead %s at %s, health %d" % [str(P.dead), str(P.pos), int(G.S["health"])])
	yield(_shot("d4_hospital"), "completed")
	get_tree().quit()

# every gun in first person: a shot (with its flash) and four moments of the reload; one in
# third person; then the two new cars
func _gun_test():
	yield(_wait(1.0), "completed")
	main.title._close(); main.start_game(G.new_state("guntest"))
	yield(_wait(1.5), "completed")
	_clean_view(true)
	G.time_offset += (17 * 60 + 30 - G.world_minutes())
	var P = main.player
	P.place(0, 0, -70, PI)
	for id in GUN.IDS:
		G.S["guns"][id].owned = true; G.S["guns"][id].res = 200
	G.S["settings"]["fp"] = true
	for id in GUN.IDS:
		P.switch_weapon(id)
		yield(_wait(0.6), "completed")
		var g = G.S["guns"][id]
		# fire one, catch the flash
		P.fire_cd = 0; P.try_fire()
		P.flash_frames = 8     # hold the flash long enough for the screenshot
		yield(get_tree(), "idle_frame")
		yield(_shot("g_%s_0fire" % id), "completed")
		P.flash_frames = 0
		yield(_wait(0.5), "completed")
		g.mag = 0 if id != "plow" else 3
		P.reload_t = 0; P.start_reload()
		var T = P.reload_total
		var marks = [0.24, 0.42, 0.62, 0.8]
		var tprev = 0.0
		for i in range(marks.size()):
			yield(_wait(T * (marks[i] - tprev)), "completed")
			tprev = marks[i]
			yield(_shot("g_%s_%dreload" % [id, i + 1]), "completed")
		var t0 = G.REAL_T
		while P.reload_t > 0 and G.REAL_T - t0 < 8.0:
			yield(get_tree(), "idle_frame")
		yield(_wait(0.2), "completed")
		_log("%s: mag %d after reload (reload_t %.2f, reload_for %s, cur %s, res %d), kind %s" % [id, g.mag, P.reload_t, str(P.reload_for), G.S["cur"], g.res, GUN.KIND[id]])
	# third person reload
	G.S["settings"]["fp"] = false
	P.switch_weapon("dragon")
	yield(_wait(0.5), "completed")
	G.S["guns"]["dragon"].mag = 0; P.start_reload()
	while P._reload_u() < 0.18:
		yield(get_tree(), "idle_frame")
	_frame(P.pos + Vector3(1.6, 1.6, -1.6), P.pos + Vector3(0, 1.2, 0), 45)
	yield(_wait(0.2), "completed")
	yield(_shot("g_tp_reload"), "completed")
	main.cutscene.end()
	# head bob: walking forward in first person, two frames half a step apart
	G.S["settings"]["fp"] = true
	Input.action_press("move_f"); Input.action_press("move_r")
	yield(_wait(1.0), "completed")
	yield(_shot("g_bob_a"), "completed")
	yield(_wait(0.17), "completed")
	yield(_shot("g_bob_b"), "completed")
	Input.action_release("move_f"); Input.action_release("move_r")
	_log("roll while strafing: %.3f" % P.cam_roll)
	# the two new cars
	G.S["settings"]["fp"] = false
	var a = main.vehicles.spawn("bruiser", -4, -84, 0.6, { "color": 0x8a1c24, "owned": true })
	var b = main.vehicles.spawn("boulder", 4, -84, -0.6, { "color": 0x262b33, "owned": true })
	P.place(0, 0, -76, PI)
	_frame(Vector3(0, 2.2, -77), Vector3(0, 0.8, -84), 55)
	yield(_wait(0.6), "completed")
	yield(_shot("g_cars_front"), "completed")
	main.cutscene.end()
	_frame(Vector3(0, 2.4, -92), Vector3(0, 0.8, -84), 55)
	yield(_wait(0.6), "completed")
	yield(_shot("g_cars_back"), "completed")
	main.cutscene.end()
	_log("cars: %s %s" % [str(a != null), str(b != null)])
	get_tree().quit()
