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
	call_deferred("_go")

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
	_log("traffic %d peds %d cops %d" % [main.vehicles.TRAFFIC.size(), main.peds.PEDS.size(), main.police.COPS.size()])
	_log("fps %d" % Engine.get_frames_per_second())
	var f = File.new()
	if f.open(out.plus_file("autotest.log"), File.WRITE) == OK:
		f.store_string(PoolStringArray(log_lines).join("\n")); f.close()
	get_tree().quit()
