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
	else: call_deferred("_go")

func _wait(s):
	yield(get_tree().create_timer(s), "timeout")

func _shot(name):
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var img = get_viewport().get_texture().get_data()
	img.flip_y()
	img.save_png(out.plus_file(name + ".png"))
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
	while G.REAL_T - t0 < 60:
		if not main.net.online() and main.net.status == "offline": main.net.join(ip)
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
func _tour():
	yield(get_tree(), "idle_frame")
	var P = main.player
	var S = G.S
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
	var ok = main.net.host()
	_log("net host: %s %s" % [str(ok), main.net.status])
	if OS.get_environment("DS_PEER") != "":
		var t1 = G.REAL_T
		while main.net.R.size() == 0 and G.REAL_T - t1 < 40: yield(get_tree(), "idle_frame")
		yield(_wait(2.0), "completed")
		var rr = main.net.R.values()
		_log("net peers: %d %s" % [rr.size(), ("@" + rr[0].name + " at " + str(rr[0].pos)) if rr.size() > 0 else ""])
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
	Input.action_press("move_f")
	yield(_wait(1.5), "completed")
	Input.action_release("move_f")
	_log("walked to %s" % str(P.pos))
	# shoot
	var mag0 = G.S["guns"]["k9"].mag
	P.fire_cd = 0; P.try_fire()
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
