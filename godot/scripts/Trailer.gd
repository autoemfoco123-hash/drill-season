extends Node
# Trailer shots for the store, rendered frame by frame. With --fixed-fps 30 every frame is 1/30 s
# of game time however slowly it renders, and the world clock (time of day, the trains) is held
# to the same pace. One shot per run:
#   DS_TRAILER=<shot> DS_FRAMES=<n> DS_SHOTS=<dir> godot3 --path . --audio-driver Dummy \
#     --resolution 1920x1080 --fixed-fps 30 --autotest
# Frames land in <dir>/<shot>/00000.png...; sounds worth putting in the edit (shots, punches,
# thunder) are listed with their frame in <dir>/<shot>/events.txt.

var main
var A                   # the AutoTest node, for its helpers
var dir = ""
var nframes = 60
var f = 0               # frames saved so far
var ws0 = 0.0           # the world clock when recording started
var events = []
var actors = []         # [human, emote, start time] posed every frame
var shot = ""
var actor_dt = 1.0 / 30.0
var every = 1           # DS_EVERY: save only every n-th frame (previews)
var grid_on = false     # the turf map: where the streets' crossings land on screen, every frame
var grid = []
var trk = null          # a camera riding with a car: { v, off, look } in the car's own frame
var walkers = []        # [human, velocity] walking every frame
var driver = null       # someone in the driver's seat of trk.v (third person hides you in a car)

func run(m, a):
	main = m; A = a
	shot = OS.get_environment("DS_TRAILER")
	nframes = int(OS.get_environment("DS_FRAMES")) if OS.get_environment("DS_FRAMES") != "" else 60
	every = int(OS.get_environment("DS_EVERY")) if OS.get_environment("DS_EVERY") != "" else 1
	dir = A.out.plus_file(shot)
	Directory.new().make_dir_recursive(dir)
	yield(A._wait(1.0), "completed")
	if shot != "console":
		main.title._close(); main.start_game(G.new_state("calder"))
		yield(A._wait(1.2), "completed")
		G.S["settings"]["quality"] = "high"; main.set_quality("high")
		G.S["settings"]["outlines"] = true; G.apply_outlines()
		G.S["settings"]["fp"] = false
		G.S["cash"] = 48250; G.S["buzz"] = 64
		for id in GUN.IDS:
			G.S["guns"][id].owned = true; G.S["guns"][id].res = 240
		G.D["VENTS"] = []
		# no job beacons in the shots, and a full moon (whole days later: same hour, same trains)
		for b in main.story.beacons.values():
			for ch in b.g.get_children(): ch.visible = false
		var mp = fposmod(G.world_seconds() / 1440.0 / 8.0, 1.0)
		G.time_offset += 1440.0 * round((0.5 - mp) * 8.0)
	var st = call("_" + shot)
	if st is GDScriptFunctionState: yield(st, "completed")
	var fl = File.new()
	fl.open(dir.plus_file("events.txt"), File.WRITE)
	for e in events: fl.store_line("%d %s %.2f %.2f" % e)
	fl.close()
	if grid_on:
		var gf = File.new()
		gf.open(dir.plus_file("grid.json"), File.WRITE); gf.store_string(JSON.print(grid)); gf.close()
	A._log("trailer %s: %d frames" % [shot, f])
	get_tree().quit()

# ---------------------------------------------------------------- helpers
# run the scene for n frames, calling step(i, n) before each one, saving every frame
func rec(n, step = ""):
	ws0 = G.world_seconds()
	for i in range(n):
		if step != "": call(step, i, n)
		for a in actors:
			a[0].animate(actor_dt, { "speed": 0.0, "emote": a[1], "et": a[2] + i * actor_dt, "mug": a[1] == "" and OS.get_environment("DS_NOMUG") == "" })
		# the world clock moves with the frames, not with the (slow) wall clock
		G.time_offset += (ws0 + i / 30.0) - G.world_seconds()
		main.cutscene.layer.visible = false
		yield(get_tree(), "idle_frame")
		if grid_on: _grid_frame()
		if every <= 1 or i % every == 0:
			var img = get_viewport().get_texture().get_data()
			img.flip_y()
			img.save_png(dir.plus_file("%05d.png" % f))
		f += 1

# let things settle without saving (cars get going, cameras catch up, cops arrive)
func warm(n, step = ""):
	for i in range(n):
		if step != "": call(step, i, n)
		main.cutscene.layer.visible = false
		yield(get_tree(), "idle_frame")

func ev(name, vol = 1.0, pitch = 1.0):
	events.append([f, name, vol, pitch])

func tod(h):
	if OS.get_environment("DS_TOD") != "": h = float(OS.get_environment("DS_TOD"))
	G.time_offset += (h * 60.0 - G.world_minutes())

func hud(on):
	main.hud.trailer_clean = true
	for c in main.hud.layer.get_children():
		if c is CanvasItem: c.visible = on
	for fo in main.gang.FOL:
		if fo.h: fo.h.visible = on

func cam(from, to, look, look_to, fov = 50.0):
	main.cutscene.play([{ "dur": (nframes + (3 if shot.begins_with("e_") else 0)) / 30.0, "from": from, "to": to, "look": look, "look_to": look_to, "fov": fov }])

func orbit(c, r, a0, a1, h0, h1, fov = 50.0):
	main.cutscene.play([{ "dur": (nframes + (3 if shot.begins_with("e_") else 0)) / 30.0, "orbit": { "c": c, "r": r, "a0": a0, "a1": a1, "h0": h0, "h1": h1 }, "fov": fov }])

# put the train closest to it at a point of its run (arrive u: 0 far .. 1 at the platform)
func train_phase(ph, dir = 0):
	var best = null
	var bd = 999.0
	for T in main.train.TR:
		if dir != 0 and T.dir != dir: continue
		var cur = fposmod(G.world_seconds() + main.train.t_shift + T.off, main.train.CYCLE)
		var d = fposmod(ph - cur + main.train.CYCLE * 0.5, main.train.CYCLE) - main.train.CYCLE * 0.5
		if abs(d) < bd:
			bd = abs(d)
			best = d
	main.train.t_shift += best        # the trains move, the time of day stays

func clear_street(at, r = 80.0):
	for v in main.vehicles.VEH.duplicate():
		if not v.owned and v.pos.distance_to(at) < r: main.vehicles.remove(v)
	for pd in main.peds.PEDS.duplicate():
		if pd.pos.distance_to(at) < r * 0.7: main.peds.remove(pd)
	for c in main.eras.CREW:
		if c.h and is_instance_valid(c.h): c.h.queue_free()
	main.eras.CREW = []
	for k in main.story.NPCS.keys():
		var n = main.story.NPCS[k]
		if n.h and is_instance_valid(n.h): n.h.translation = Vector3(0, -50, 0)

func light(at, col, e, r):
	var o = OmniLight.new(); o.translation = at; o.light_color = col; o.light_energy = e; o.omni_range = r; o.omni_attenuation = 1.4
	main.add_child(o)

func person(look, tone, at, yaw):
	var sk = G.era_skin(look); sk["tone"] = tone
	var h = load("res://scripts/Human.gd").new().build(G.skin_opts(sk))
	main.add_child(h); G.toon_tree(h, true)
	h.translation = at; h.rotation.y = yaw
	return h

# the crew of the key art on Calder Ave, with its police lights; poses play on
func crew(X, spots = null):
	var looks = [5, 7, 4, 2]
	var tones = [5, 2, 4, 1]
	var poses = [["shmoney", 0.35], ["", 0.0], ["point", 1.0], ["sturdy", 0.3]]
	if spots == null: spots = [Vector3(X + 1.0, 0, 2.7), Vector3(X, 0, 0.95), Vector3(X + 0.3, 0, -0.95), Vector3(X + 1.2, 0, -2.6)]
	for i in range(4):
		var h = person(looks[i], tones[i], spots[i], -PI / 2 + [0.4, 0.08, -0.12, -0.45][i])
		actors.append([h, poses[i][0], poses[i][1]])
	main.vehicles.spawn("bruiser", X + 6.5, 1.6, -PI / 2 + 0.55, { "color": 0x8a1c24, "owned": true })
	main.vehicles.spawn("police", X + 15.0, -2.6, -PI / 2 - 0.4, { "owned": true })
	for L in [[Vector3(X - 2.5, 4.2, 3.0), Color(1.0, 0.75, 0.5), 0.55, 8.0], [Vector3(X + 3, 2.8, -3.2), Color(0.3, 0.5, 1.0), 1.1, 6.0],
			[Vector3(X + 3, 2.6, 3.4), Color(1.0, 0.22, 0.28), 1.0, 6.0], [Vector3(X + 15, 2.2, -2.6), Color(0.25, 0.45, 1.0), 1.6, 8.0], [Vector3(X + 15.5, 2.2, -1.2), Color(1.0, 0.15, 0.2), 1.4, 7.0]]:
		light(L[0], L[1], L[2], L[3])

func keep_alive(_i, _n):
	G.S["health"] = 100

# dusk from the air, coming down over Calder Ave toward the L and the skyline
func _open():
	tod(16.65); hud(false)
	main.sky.override = { "cover": 0.85, "storm": 0.0, "aurora": 0.0 }
	main.player.place(10, 0, -30, 0)
	train_phase(main.train.T1 + 2.0)
	cam(Vector3(2, 32, 22), Vector3(18, 21, 12), Vector3(82, 6.0, -8.0), Vector3(82, 5.0, -3.0), 50)
	yield(rec(nframes), "completed")

# the crew under the L, the camera pushing in from the road
func _crew():
	tod(16.65); hud(false)
	main.sky.override = { "cover": 0.85, "storm": 0.0, "aurora": 0.0 }
	var X = 40.0
	main.player.place(X - 24, 0, 0.5, 0)
	clear_street(Vector3(X, 0, 0))
	crew(X)
	train_phase(main.train.T1 + 3.0)
	yield(warm(8), "completed")
	cam(Vector3(X - 9.5, 0.55, 0.5), Vector3(X - 6.0, 0.62, 0.4), Vector3(X + 1, 2.2, 0.0), Vector3(X + 1, 2.0, 0.0), 44)
	yield(rec(nframes), "completed")

# on foot: running down Bishop St in the afternoon snow, the HUD up
func _walk():
	tod(15.4); hud(true)
	G.S["skin"] = G.era_skin(7); main.player._build_body()
	var P = main.player
	P.place(2, 0, -8, 0); P.cam_yaw = 0; P.cam_pitch = -0.06
	Input.action_press("move_f"); Input.action_press("sprint")
	yield(warm(20), "completed")
	yield(rec(nframes), "completed")
	Input.action_release("move_f"); Input.action_release("sprint")

# driving the Kessler Bruiser down Calder Ave at night
func _drive():
	tod(20.3); hud(true)
	var P = main.player
	P.place(-78, 0, 1.8, 0)
	var v = main.vehicles.spawn("bruiser", -76, 1.8, PI / 2, { "color": 0x8a1c24, "owned": true })
	main.vehicles.enter(v)
	yield(warm(6), "completed")
	Input.action_press("move_f")
	yield(warm(40), "completed")
	yield(rec(nframes), "completed")
	Input.action_release("move_f")

# a night chase: the camera rides ahead of the car looking back, cruisers on its tail
func _chase():
	tod(20.8); hud(false)
	var P = main.player
	P.place(-92, 0, 1.8, 0)
	var v = main.vehicles.spawn("boulder", -90, 1.8, PI / 2, { "color": 0x1d1f24, "owned": true })
	main.vehicles.enter(v)
	yield(warm(6), "completed")
	main.vehicles.trailer_drive = true
	Input.action_press("move_f")
	yield(warm(30), "completed")
	main.police.add_wanted(70, P.pos, true)
	for k in range(2):
		var c = main.vehicles.spawn("police", v.pos.x - 15 - 11 * k, 1.8 - 2.6 * k, PI / 2, { "color": 0x101216 })
		if c == null: continue
		c.driver = "police"; c.siren = true
		c.ai = { "axis": "x", "line": 0, "dir": 1, "speed": 30, "siren": true, "turn": null, "turnFor": null }
		c.cop = { "mode": "respond", "deployed": false, "t": 0.0 }
		c.speed = v.speed
	cam(Vector3(), Vector3(), Vector3(0, 0, 1), Vector3(0, 0, 1), 50)
	yield(rec(nframes, "_chase_cam"), "completed")
	Input.action_release("move_f")
	main.vehicles.trailer_drive = false

func _chase_cam(_i, _n):
	var v = main.player.car
	if v == null: return
	var f = main.vehicles.fwd(v)
	var side = Vector3(f.z, 0, -f.x)
	var at = v.pos + f * 9.5 + side * 2.4 + Vector3(0, 1.5, 0)
	var look = v.pos - f * 7.0 + Vector3(0, 0.9, 0)
	var c = main.cutscene.cur
	if c:
		c.from = at; c.to = at; c.look = look; c.look_to = look

# first person with the Dragon from the hip: a crew across the street, bursts, the flash, a reload
func _shoot_fp():
	tod(17.5); hud(true)
	var P = main.player
	P.place(4, 0, -36, 0); P.cam_yaw = 0; P.cam_pitch = 0.03
	G.S["settings"]["fp"] = true
	P.switch_weapon("dragon")
	var fwd = Vector3(0, 0, -1)
	var c = main.crews.spawn_crew(P.pos + fwd * 13 + Vector3(0.8, 0, 0), 3, 3)
	c.state = "combat"
	yield(warm(24, "keep_alive"), "completed")
	yield(rec(nframes, "_shoot_step"), "completed")

func _shoot_step(i, n):
	G.S["health"] = 100
	var P = main.player
	if i < n - 30 and i % 4 == 0 and G.S["guns"][G.S["cur"]].mag > 0:
		P.fire_cd = 0; P.try_fire(); P.flash_frames = 2
		ev("gun_draft", 1.0, 0.78)
	if i == n - 26:
		G.S["guns"][G.S["cur"]].mag = 0; P.reload_t = 0; P.start_reload(); ev("reload", 0.8)

# third person with the Buzzsaw, trading shots with a crew
func _gunfight():
	tod(16.6); hud(true)
	var P = main.player
	P.place(-30, 0, 1.0, PI / 2); P.cam_yaw = -PI / 2; P.cam_pitch = 0.0
	P.switch_weapon("buzz")
	var c = main.crews.spawn_crew(P.pos + Vector3(13, 0, -1.5), 3, 3)
	c.state = "combat"
	G.last_pad = true
	Input.action_press("aim")
	yield(warm(24, "keep_alive"), "completed")
	yield(rec(nframes, "_gun_step"), "completed")
	Input.action_release("aim")

func _gun_step(i, _n):
	G.S["health"] = 100
	var P = main.player
	if i % 3 == 0 and i % 24 < 15 and G.S["guns"][G.S["cur"]].mag > 0:
		P.fire_cd = 0; P.try_fire(); P.flash_frames = 2
		ev("gun_draft", 0.8, 1.14)

# fists: two punches and somebody hits the snow, seen from the side
func _punch():
	tod(12.6); hud(false)
	var P = main.player
	P.place(4, 0, -22, 0); P.cam_yaw = 0.0; P.cam_pitch = -0.08
	P.set_fists(true)
	A._face_ped(P, 1.25)
	yield(warm(8), "completed")
	cam(Vector3(6.6, 1.55, -21.2), Vector3(6.2, 1.45, -21.7), Vector3(4.0, 1.25, -22.7), Vector3(4.0, 1.15, -22.9), 46)
	yield(rec(nframes, "_punch_step"), "completed")

func _punch_step(i, _n):
	var P = main.player
	if i == 6 or i == 22 or i == 36:
		P.punch(); ev("punch", 0.9)

# the sandbox-style death: ragdoll, the camera on the body, the screen going red
func _ragdoll():
	tod(13.2); hud(true)
	var P = main.player
	P.place(2.5, 0, -16, 0); P.cam_yaw = 0.2
	yield(warm(10), "completed")
	yield(rec(nframes, "_rag_step"), "completed")

func _rag_step(i, _n):
	if i == 4:
		main.player.hurt(500, main.player.pos + Vector3(0, 0, -3)); ev("gun_k9", 1.0)

# Basement 808: the rhythm game, played perfectly
func _studio():
	tod(19.0); hud(true)
	var L = G.D["LOC"]
	G.S["flags"]["studioCut"] = true
	main.player.place(L.studio.x, 0, L.studio.z + 1.5, PI)
	main.studio.trailer_clock = true
	main.studio.start_rhythm("tribute", { "style": "chi" })
	yield(warm(75, "_hit_notes"), "completed")
	yield(rec(nframes, "_hit_notes"), "completed")

func _hit_notes(_i, _n):
	var now = main.studio.rh_now()
	for nt in main.studio.RH.notes:
		if nt.hit == "" and nt.t - now < 0.02 and nt.t - now > -0.06:
			main.studio._hit(nt.lane)

# the phone: home screen, then Blok
func _phone():
	tod(14.2); hud(true)
	var P = main.player
	P.place(16, 0, -2.5, PI); P.cam_yaw = PI + 0.5; P.cam_pitch = -0.04
	yield(warm(6), "completed")
	main.phone.open("")
	yield(rec(nframes, "_phone_step"), "completed")

func _phone_step(i, n):
	if i == int(n * 0.55): main.phone.show_app("blok")

# the wardrobe: the look changing piece by piece
func _wardrobe():
	tod(14.0); hud(true)
	main.wardrobe.open()
	yield(warm(20), "completed")
	yield(rec(nframes, "_ward_step"), "completed")

func _ward_step(i, _n):
	if i > 0 and i % 13 == 0:
		var keys = ["top", "hair", "head", "beard", "pants", "top"]
		main.wardrobe.step(keys[(i / 13) % keys.size()], 1)

# Ironside Arms from the inside
func _interior():
	tod(14.0); hud(false)
	main.interiors.enter("gunshop")
	yield(warm(30), "completed")
	var o = main.interiors.ROOMS["gunshop"].o
	cam(o + Vector3(4.5, 2.3, 3.8), o + Vector3(3.4, 2.0, 3.1), o + Vector3(-1.0, 1.1, -2.0), o + Vector3(-1.6, 1.1, -2.2), 58)
	yield(rec(nframes), "completed")

# console mode: the TV home screen with a controller
func _console():
	yield(A._wait(0.6), "completed")
	yield(rec(nframes, "_con_step"), "completed")

func _con_step(i, _n):
	var C = main.console
	if i == 8:
		C._home_tiles(); ev("tap", 0.6)
	elif i > 8 and (i - 8) % 14 == 0 and C.tiles.size() > 0:
		var k = int((i - 8) / 14) % C.tiles.size()
		C.tiles[k].grab_focus()

# the L from a side street: a train rolls across the frame on the elevated tracks at dusk
func _train():
	tod(16.75); hud(false)
	main.sky.override = { "cover": 0.8, "storm": 0.0, "aurora": 0.0 }
	main.player.place(20, 0, -130, 0)
	clear_street(Vector3(50, 0, -90), 30.0)
	train_phase(5.6, 1)          # the one coming up from the south
	cam(Vector3(41, 1.8, -89.5), Vector3(43, 1.9, -89.5), Vector3(70, 8.6, -103), Vector3(70, 8.4, -80), 50)
	yield(rec(nframes), "completed")
	ev("train_pass", 1.0)

# thundersnow from the air as night falls: lightning over the city lights and the L
func _storm():
	tod(17.1); hud(false)
	main.sky.override = { "cover": 0.95, "storm": 1.0, "aurora": 0.0 }
	main.player.place(-10, 0, 20, 0)
	yield(warm(10), "completed")
	cam(Vector3(-20, 30, 30), Vector3(-6, 25, 22), Vector3(70, 5, -10), Vector3(72, 5, -6), 54)
	yield(rec(nframes, "_storm_step"), "completed")

func _storm_step(i, n):
	if i == 4 or i == int(n * 0.38) or i == int(n * 0.72):
		main.sky.strike(); ev("thunder_near", 0.9)

# a row of dancers under a street lamp, the camera circling
func _dances():
	tod(21.0); hud(false)
	main.sky.override = { "cover": 0.6, "storm": 0.0, "aurora": 0.0 }
	var c = Vector3(12, 0, 0.5)
	main.player.place(c.x - 30, 0, -20, 0)
	clear_street(c)
	var moves = [["sturdy", 7], ["griddy", 2], ["shmoney", 5], ["woah", 4], ["hitfolks", 6]]
	for i in range(moves.size()):
		var h = person(moves[i][1], [1, 3, 5, 2, 4][i], c + Vector3(0, 0, (i - 2) * 1.35), -PI / 2)
		actors.append([h, moves[i][0], 0.2 * i])
	light(c + Vector3(-3, 4, 0), Color(1.0, 0.78, 0.55), 0.8, 10.0)
	light(c + Vector3(3, 3, -4), Color(0.35, 0.55, 1.0), 1.2, 8.0)
	light(c + Vector3(3, 3, 4), Color(1.0, 0.3, 0.55), 1.1, 8.0)
	yield(warm(6), "completed")
	orbit(c, 6.8, PI + 0.55, PI - 0.25, 1.2, 1.9, 48)
	yield(rec(nframes), "completed")

# the key art, the camera pulling back from the crew (the logo goes on in the edit)
func _hero():
	tod(16.65); hud(false)
	main.sky.override = { "cover": 0.85, "storm": 0.0, "aurora": 0.0 }
	var X = 40.0
	main.player.place(X - 30, 0, 0.5, 0)
	clear_street(Vector3(X, 0, 0))
	crew(X)
	train_phase(main.train.T1 + 3.0)
	yield(warm(8), "completed")
	cam(Vector3(X - 4.6, 0.6, 0.5), Vector3(X - 10.5, 0.85, 0.4), Vector3(X + 1, 1.9, 0.0), Vector3(X + 1, 2.6, 0.0), 44)
	yield(rec(nframes), "completed")


# ================================================================ the epic trailer (turf update)
# Night, fire and the turf war. Scenes are named e_*; trailer_epic.py cuts them to the score.

func _grid_frame():
	var cam = main.camera
	var pts = []
	for z in G.D["ZL"]:
		for x in G.D["XL"]:
			var w = Vector3(x, 0.0, z)
			if cam.is_position_behind(w): pts.append(null)
			else:
				var q = cam.unproject_position(w)
				pts.append([stepify(q.x, 0.1), stepify(q.y, 0.1)])
	grid.append(pts)

func night(h = 21.6, cover = 0.85):
	tod(h)
	hud(false)
	main.sky.override = { "cover": cover, "storm": 0.0, "aurora": 0.0 }

func gang_up(n = 2, names = ["Ace", "Bo", "Kiki"]):
	var GA = main.gang
	if GA.gang() == null: GA.create("Frostline", "FRL", 4)
	G.S["cash"] = 999999; G.S["buzz"] = 999
	for i in range(n):
		GA.hire("shooter" if i < 2 else "brawler", 700 + i * 13, names[i % names.size()])
	G.S["cash"] = 48250

func own(b):
	main.turf.give(b, main.turf.my_gang())

func guards(b, o, n, at = null, shooters = 0):
	var T = main.turf
	return T._spawn_crew(b, o, at if at != null else T.corners[b], n, shooters, true)

func wave(b, o, at, n, shooters):
	return main.turf._spawn_crew(b, o, at, n, shooters, false)

func kill_one(near, from):
	var best = null
	var bd = 999.0
	for e in main.crews.ENEMIES:
		if e.is_down(): continue
		var d = e.pos.distance_to(near)
		if d < bd:
			bd = d; best = e
	if best: best.take_hit(999, false, (best.pos - from).normalized(), true, false)

func gun_on(h, id = "draft"):
	var g = GUN.build(id, GUN.def_cfg())
	g.rotation = Vector3(PI / 2, 0, 0); g.translation = Vector3(0, -0.03, 0.02); g.scale = Vector3.ONE * 1.35
	h.gun_slot.add_child(g)

func face_cam(p):
	var P = main.player
	P.cam_yaw = atan2(P.pos.x - p.x, P.pos.z - p.z); P.last_look = G.REAL_T

func calm():
	# a clean street: no ambushes, no cops wandering in
	G.S["heat"] = 0
	main.crews.ambush_t = 9999
	main.vehicles.trailer_drive = true

func wreck(model, x, z, yaw):
	var v = main.vehicles.spawn(model, x, z, yaw, { "owned": true, "color": 0x2a2d33 })
	main.vehicles.explode(v)
	return v

func _track(_i, _n):
	if trk == null: return
	var v = trk.v
	var f = main.vehicles.fwd(v)
	var sd = main.vehicles.side(v)
	var at = v.pos + sd * trk.off.x + Vector3(0, trk.off.y, 0) + f * trk.off.z
	var lk = v.pos + sd * trk.look.x + Vector3(0, trk.look.y, 0) + f * trk.look.z
	var c = main.cutscene.cur
	if c:
		c.from = at; c.to = at; c.look = lk; c.look_to = lk
	if driver != null:
		var cb = main.cockpit.cabin(v)
		driver.transform = main.cockpit.car_frame(v) * Transform(Basis(), Vector3(cb.xD, cb.hy, cb.eyeZ - 0.1) - Vector3(0, 0.92, 0))
		driver.animate(1.0 / 30.0, { "seat": true, "sway": Vector2(v.ay if "ay" in v else 0.0, v.ax if "ax" in v else 0.0) })

func _walk_step(_i, _n):
	var dt = actor_dt
	for w in walkers:
		w[0].translation += w[1] * dt
		w[0].animate(dt, { "speed": w[1].length(), "mug": true })

# 1. the city at night from the air, the L crossing it
func _e_open():
	night(21.4); calm()
	main.trailer_fog = 330.0
	main.camera.far = 900.0
	main.player.place(-20, 0, 10, 0)
	train_phase(main.train.T1 + 1.5)
	yield(warm(6), "completed")
	cam(Vector3(-95, 58, 70), Vector3(-62, 47, 48), Vector3(70, 4, -30), Vector3(75, 4, -18), 48)
	yield(rec(nframes), "completed")

# 2-4. three corners, three crews
func _corner(b, o, n, from, to, look, look_to, col, fov = 42.0):
	night(21.6); calm()
	var c = main.turf.corners[b]
	clear_street(c, 60.0)
	var away = (from - c); away.y = 0
	main.player.place(c.x + away.normalized().x * 18.0, 0, c.z + away.normalized().z * 18.0, 0)
	yield(warm(4), "completed")
	guards(b, o, n)
	light(c + Vector3(0, 3.2, 0), col, 1.25, 9.0)
	light(c + Vector3(-2.5, 1.2, -2.5), col, 0.8, 5.0)
	yield(warm(8), "completed")
	cam(from, to, look, look_to, fov)
	yield(rec(nframes), "completed")

func _e_halo():
	var c = main.turf.corners[6]
	yield(_corner(6, "halo", 3, c + Vector3(-7.6, 0.45, -7.2), c + Vector3(-5.4, 0.55, -5.3), c + Vector3(0, 1.4, 0), c + Vector3(0, 1.5, 0), Color(1.0, 0.18, 0.15), 40.0), "completed")

func _e_low():
	var c = main.turf.corners[2]
	yield(_corner(2, "lowend", 3, c + Vector3(-7.5, 1.1, -3.0), c + Vector3(-5.2, 1.0, -6.6), c + Vector3(0, 1.3, 0), c + Vector3(0.4, 1.3, 0), Color(1.0, 0.6, 0.15), 42.0), "completed")

func _e_sable():
	var c = main.turf.corners[14]
	yield(_corner(14, "sable", 3, c + Vector3(-8.5, 5.0, -8.0), c + Vector3(-6.2, 1.3, -6.0), c + Vector3(0, 1.1, 0), c + Vector3(0, 1.45, 0), Color(0.3, 0.5, 1.0), 42.0), "completed")

# 5. the map from above (the colours go on in the edit, on grid.json)
func _e_map():
	night(21.4); calm()
	main.env.fog_enabled = false
	main.camera.far = 1600.0
	main.player.place(-15, 0, 0, 0)
	grid_on = true
	yield(warm(4), "completed")
	main.fx.snow.visible = false
	cam(Vector3(-32, 330, 215), Vector3(-6, 300, 190), Vector3(-15, 0, -8), Vector3(-15, 0, -4), 46)
	yield(rec(nframes), "completed")

func _e_map2():
	night(21.4); calm()
	main.env.fog_enabled = false
	main.camera.far = 1600.0
	main.player.place(-15, 0, 0, 0)
	grid_on = true
	yield(warm(4), "completed")
	main.fx.snow.visible = false
	cam(Vector3(5, 300, 180), Vector3(-25, 285, 175), Vector3(-15, 0, -6), Vector3(-15, 0, -2), 48)
	yield(rec(nframes), "completed")

# 6. taking a corner at sundown: a wave down Calder Ave, your shooters with you
func _e_takeover():
	tod(16.85); hud(false); calm()
	main.sky.override = { "cover": 0.7, "storm": 0.0, "aurora": 0.0 }
	gang_up(2)
	var T = main.turf
	var b = 10
	var c = T.corners[b]
	clear_street(c, 70.0)
	var P = main.player
	P.place(c.x - 1.6, 0, c.z - 2.2, 0)
	P.switch_weapon("dragon")
	yield(warm(20), "completed")
	T.begin(b)
	T.take.p = 0.36
	T.take.w = T.take.waves.size()
	wave(b, "halo", c + Vector3(-30, 0, -6), 3, 1)
	wave(b, "halo", c + Vector3(-36, 0, -12), 2, 1)
	hud(true); main.hud.trailer_clean = true
	for k in range(main.gang.FOL.size()):
		var fo = main.gang.FOL[k]
		fo.h.visible = true
		fo.pos = c + [Vector3(-3.2, 0, 0.6), Vector3(0.6, 0, -4.8)][k % 2]
	face_cam(c + Vector3(-30, 0, -8))
	P.cam_pitch = -0.02
	G.last_pad = true
	Input.action_press("aim")
	yield(warm(16, "keep_alive"), "completed")
	yield(rec(nframes, "_take_step"), "completed")
	Input.action_release("aim")

func _take_step(i, _n):
	G.S["health"] = 100
	var P = main.player
	var c = main.turf.corners[10]
	face_cam(c + Vector3(-30, 0, -8 + sin(i * 0.05) * 2.0))
	if i % 3 == 0 and i % 21 < 13 and G.S["guns"][G.S["cur"]].mag > 0:
		P.fire_cd = 0; P.try_fire(); P.flash_frames = 2
		ev("gun_draft", 0.8, 1.05)
	if i in [18, 33, 49, 66, 84]:
		kill_one(P.pos + Vector3(-22, 0, -6), P.pos)

# 7. first person under the L at night
func _e_fp():
	night(21.0); calm()
	var P = main.player
	P.place(64, 0, -30, 0); P.cam_yaw = 0; P.cam_pitch = 0.03
	clear_street(P.pos, 50.0)
	G.S["settings"]["fp"] = true
	P.switch_weapon("dragon")
	wave(7, "lowend", P.pos + Vector3(1.2, 0, -9.5), 3, 3)
	hud(true); main.hud.trailer_clean = true
	yield(warm(24, "keep_alive"), "completed")
	yield(rec(nframes, "_fp_step"), "completed")

func _fp_step(i, n):
	G.S["health"] = 100
	var P = main.player
	if i % 4 == 0 and G.S["guns"][G.S["cur"]].mag > 0:
		P.fire_cd = 0; P.try_fire(); P.flash_frames = 2
		ev("gun_draft", 1.0, 0.8)
	if i == 20 or i == 38: kill_one(P.pos + Vector3(0, 0, -9.5), P.pos)

# 8. the Bruiser flat out down Calder Ave, the camera low by the front wheel
func _e_cars():
	night(20.9); calm()
	var P = main.player
	P.place(-160, 0, 1.8, 0)
	clear_street(Vector3(-60, 0, 0), 140.0)
	var v = main.vehicles.spawn("bruiser", -158, 1.8, PI / 2, { "color": 0x8a1c24, "owned": true })
	main.vehicles.enter(v)
	yield(warm(4), "completed")
	Input.action_press("move_f")
	yield(warm(55), "completed")
	trk = { "v": v, "off": Vector3(-1.7, 0.42, 3.4), "look": Vector3(0.2, 0.55, -2.2) }
	cam(Vector3(), Vector3(), Vector3(0, 0, 1), Vector3(0, 0, 1), 40)
	yield(rec(nframes, "_track"), "completed")
	Input.action_release("move_f")

# 9. your crew in the back seat, from the driver's seat looking back, the city going by
func _e_ride():
	night(21.2); calm()
	gang_up(3)
	var P = main.player
	P.place(-150, 0, -1.8, 0)
	clear_street(Vector3(-60, 0, 0), 140.0)
	var v = main.vehicles.spawn("boulder", -148, -1.8, PI / 2, { "color": 0x1d1f24, "owned": true })
	main.vehicles.enter(v)
	G.S["settings"]["fp"] = true
	main.hud.root.visible = false
	for fo in main.gang.FOL: fo.h.visible = true
	yield(warm(4), "completed")
	Input.action_press("move_f")
	yield(warm(30), "completed")
	Input.action_release("move_f")
	yield(rec(nframes, "_ride_step"), "completed")
	Input.action_release("move_f")

func _ride_step(i, n):
	var P = main.player
	var v = P.car
	if v == null: return
	if i % 10 < 3: Input.action_press("move_f")
	else: Input.action_release("move_f")
	var look = lerp(-2.15, -2.55, float(i) / n)
	P.cam_yaw = v.yaw + PI + look; P.cam_pitch = -0.1; P.last_look = G.REAL_T

# 10. a car riddled with bullets goes up, in slow motion, with the crew around it
func clear_cars(at, r, keep = []):
	for v in main.vehicles.VEH.duplicate():
		if not v in keep and v.pos.distance_to(at) < r: main.vehicles.remove(v)

func _e_boom():
	night(21.3); calm()
	var at = Vector3(-48, 0, 1.8)
	main.player.place(at.x - 24, 0, at.z + 3, 0)
	clear_street(at, 50.0)
	var v = main.vehicles.spawn("sedan", at.x, at.z, PI / 2 + 0.25, { "owned": true, "color": 0x6b0d16 })
	clear_cars(at, 60.0, [v])
	yield(warm(4), "completed")
	guards(10, "halo", 3, at + Vector3(-1.5, 0, 3.0))
	light(at + Vector3(-4, 3, 5), Color(1.0, 0.7, 0.45), 0.9, 12.0)
	yield(warm(10), "completed")
	cam(at + Vector3(-13.5, 0.42, 3.6), at + Vector3(-11.4, 0.5, 3.2), at + Vector3(0, 1.0, 0.4), at + Vector3(0, 1.4, 0.4), 44)
	boom_v = v
	yield(rec(nframes, "_boom_step"), "completed")
	Engine.time_scale = 1.0

var boom_v = null
func _boom_step(i, n):
	var at = boom_v.pos
	if i < 13 and i % 3 == 0:
		var from = main.camera.global_transform.origin + Vector3(-1, 0.5, 2)
		main.sfx.tracer(from, at + Vector3(G.rand(-1, 1), G.rand(0.4, 1.2), G.rand(-0.6, 0.6)))
		ev("gun_draft", 0.7, 1.0)
	if i == 13:
		boom_v.by_player = false
		main.vehicles.explode(boom_v); ev("car_explode", 1.0)
		main.fx.explosion(at + Vector3(1.2, 1.1, 0.4))
		# softer flashes: in slow motion they would wash the street out for seconds
		for fl in main.fx._flashes:
			fl[2] = 2.4; fl[0].light_energy = 2.4
		Engine.time_scale = 0.24
	if i == 30:
		main.fx.explosion(at + Vector3(0.4, 2.2, 0.2))
		for fl in main.fx._flashes:
			fl[2] = min(fl[2], 2.4); fl[0].light_energy = min(fl[0].light_energy, 2.4)
	if i > 80:
		Engine.time_scale = min(1.0, 0.24 + (i - 80) * 0.035)
	actor_dt = Engine.time_scale / 30.0

# 11. a raid at night: they come down Low End Rd for your corner, your people hold it
func _e_raid():
	night(21.8); calm()
	gang_up(3)
	var T = main.turf
	var b = 6
	own(b)
	var c = T.corners[b]
	clear_street(c, 80.0)
	clear_cars(c, 70.0)
	var P = main.player
	P.place(c.x - 0.6, 0, c.z - 1.2, -PI / 2)
	P.switch_weapon("buzz")
	yield(warm(16), "completed")
	for k in range(main.gang.FOL.size()):
		var fo = main.gang.FOL[k]
		fo.pos = c + [Vector3(-1.6, 0, 1.4), Vector3(-0.2, 0, -3.4), Vector3(-2.4, 0, -1.6)][k % 3]
	wave(b, "halo", c + Vector3(-36, 0, -9), 4, 2)
	light(c + Vector3(-18, 4.0, -8), Color(1.0, 0.2, 0.15), 1.2, 14.0)
	yield(warm(14, "keep_alive"), "completed")
	cam(c + Vector3(2.4, 1.25, -1.6), c + Vector3(1.6, 1.0, -2.6), c + Vector3(-24, 1.2, -8), c + Vector3(-20, 1.1, -8), 40)
	yield(rec(nframes, "_raid_step"), "completed")

func _raid_step(i, _n):
	G.S["health"] = 100
	if i in [34, 58, 80]: kill_one(main.player.pos + Vector3(-20, 0, -8), main.player.pos)

# 12. the corner is yours: the banner, the ring turns your colour, the crew dances
func _e_win():
	tod(17.05); hud(false); calm()
	main.sky.override = { "cover": 0.7, "storm": 0.0, "aurora": 0.0 }
	gang_up(3)
	var T = main.turf
	var b = 10
	var c = T.corners[b]
	clear_street(c, 60.0)
	var P = main.player
	P.place(c.x + 0.4, 0, c.z + 0.3, 0)
	yield(warm(20), "completed")
	for k in range(main.gang.FOL.size()):
		var fo = main.gang.FOL[k]
		fo.pos = c + Vector3(cos(k * 2.1 + 0.6) * 2.2, 0, sin(k * 2.1 + 0.6) * 2.2)
	main.hud.trailer_banner = true
	T.begin(b)
	T.take.p = 1.0; T.take.w = T.take.waves.size()
	for cr in main.crews.CREWS.duplicate(): main.crews.despawn(cr)
	hud(true); main.hud.trailer_clean = true
	for fo in main.gang.FOL: fo.h.visible = true
	yield(warm(3), "completed")
	main.gang.dance_along("shmoney")
	P.emote("griddy", 6.0)
	orbit(c, 6.2, -2.2, -1.2, 0.7, 1.5, 46)
	yield(rec(nframes), "completed")

# 13. a donut in the snow at Bishop & Calder
func _e_drift():
	night(21.0); calm()
	var P = main.player
	var at = Vector3(-3, 0, -3)
	P.place(at.x, 0, at.z + 4, 0)
	clear_street(at, 70.0)
	var v = main.vehicles.spawn("bruiser", at.x, at.z, 0.0, { "color": 0xd8d8dc, "owned": true })
	main.vehicles.enter(v)
	yield(warm(4), "completed")
	Input.action_press("move_f"); Input.action_press("move_b"); Input.action_press("move_l")
	yield(warm(70), "completed")
	orbit(at, 8.5, 0.4, 1.5, 0.5, 1.3, 50)
	yield(rec(nframes), "completed")
	Input.action_release("move_f"); Input.action_release("move_b"); Input.action_release("move_l")

# 14. the crew walking at the camera in slow motion, a wreck burning behind them
func _e_walk():
	night(21.5); calm()
	var X = -40.0
	main.player.place(X - 26, 0, -6, 0)
	clear_street(Vector3(X, 0, 0), 70.0)
	wreck("sedan", X + 13, -1.0, PI / 2 + 0.4)
	var looks = [7, 5, 4, 2, 1]
	var tones = [2, 5, 4, 1, 3]
	var zs = [-0.2, 1.6, -1.9, 3.1, -3.4]
	var xs = [0.0, 1.0, 1.1, 2.2, 2.3]
	for i in range(5):
		var h = person(looks[i], tones[i], Vector3(X + xs[i], 0, zs[i]), -PI / 2)
		if i in [1, 2]: gun_on(h, "draft")
		walkers.append([h, Vector3(-1.45, 0, 0)])
	light(Vector3(X + 13, 2.5, -1.0), Color(1.0, 0.45, 0.15), 2.2, 18.0)
	light(Vector3(X - 4, 4, 4), Color(0.35, 0.55, 1.0), 0.9, 12.0)
	yield(warm(60), "completed")
	Engine.time_scale = 0.5
	actor_dt = 0.5 / 30.0
	cam(Vector3(X - 7.5, 0.55, -0.3), Vector3(X - 10.6, 0.6, -0.2), Vector3(X, 1.35, -0.2), Vector3(X - 3.0, 1.45, -0.2), 40)
	yield(rec(nframes, "_walk_step"), "completed")
	Engine.time_scale = 1.0

# 15. the finale: your crew in the middle of Calder Ave, a wreck burning behind them, the L
#     overhead with a train going over
func _e_finale():
	night(21.6); calm()
	var X = 52.0
	main.player.place(X - 22, 0, 6.0, 0)
	clear_street(Vector3(X, 0, 0), 80.0)
	clear_cars(Vector3(X, 0, 0), 80.0)
	wreck("sedan", X + 8.5, -3.2, 0.5)
	var looks = [7, 5, 4, 2, 1]
	var tones = [2, 5, 4, 1, 3]
	var spots = [Vector3(0, 0, 0.2), Vector3(1.2, 0, 1.8), Vector3(1.0, 0, -1.6), Vector3(2.3, 0, 3.3), Vector3(2.2, 0, -3.1)]
	var poses = ["", "", "", "point", ""]
	if OS.get_environment("DS_NOMUG") != "": poses = ["point", "", "", "", ""]
	for i in range(5):
		var h = person(looks[i], tones[i], Vector3(X, 0, 0) + spots[i], -PI / 2 + [0.0, 0.12, -0.1, 0.25, -0.2][i])
		if i in [1, 2]: gun_on(h, "draft")
		actors.append([h, poses[i], 0.3 * i])
	light(Vector3(X + 8.5, 2.0, -3.2), Color(1.0, 0.45, 0.15), 1.8, 18.0)
	light(Vector3(X - 3, 3.5, 4.5), Color(0.3, 0.55, 1.0), 1.1, 10.0)
	light(Vector3(X - 3, 3.0, -4.5), Color(1.0, 0.2, 0.25), 0.8, 9.0)
	if OS.get_environment("DS_FACEOFF") != "":
		# the key art for the turf update: Halo across the street, in their red light
		main.player.place(X + 30, 0, 6.0, 0)
		yield(warm(2), "completed")
		var hc = main.turf._spawn_crew(6, "halo", Vector3(X - 8.5, 0, 0.3), 4, 2, true)
		light(Vector3(X - 9.5, 3.2, 0.5), Color(1.0, 0.16, 0.12), 1.6, 11.0)
		light(Vector3(X - 6.5, 1.2, 3.5), Color(1.0, 0.25, 0.2), 0.7, 7.0)
	var tr = OS.get_environment("DS_TRAINAT")
	train_phase(main.train.T1 + (float(tr) if tr != "" else 3.0))
	yield(warm(40), "completed")
	var kc = OS.get_environment("DS_KEYCAM")
	if kc != "":
		var q = kc.split(",")
		var kp = Vector3(X + float(q[0]), float(q[1]), float(q[2]))
		var kl = Vector3(X + float(q[3]), float(q[4]), float(q[5]))
		cam(kp, kp, kl, kl, float(q[6]))
	else:
		cam(Vector3(X - 4.2, 0.45, 0.5), Vector3(X - 13.0, 1.5, 0.3), Vector3(X + 1, 1.5, 0.0), Vector3(X + 1, 3.2, 0.0), 44)
	yield(rec(nframes), "completed")
