extends Node
# You: movement, camera, guns, fists, gestures and getting in cars. Ported from the web game.

var main
var human = null
var gun_model = null
var gun_key = ""
var pos = Vector3(-6, 0, -42)
var vel = Vector3()
var radius = 0.36
var height = 1.75
var on_ground = true
var air_y = 0.0
var body_yaw = PI
var cam_yaw = PI
var cam_pitch = -0.12
var cam_dist = 3.9
var pivot_y = 1.6
var speed = 0.0
var crouch = false
var aiming = false
var assist_f = 0.0     # aim assist: 0 nothing near the crosshair .. 1 right on someone
var _aim_prev = false
var aim_t = 0.0
var sprinting = false
var stamina = 100.0
var stamina_lock = false
var fire_cd = 0.0
var reload_t = 0.0
var reload_for = ""
var switch_t = 0.0
var bloom = 0.0
var last_shot = -99.0
var last_hurt = -99.0
var last_look = -99.0
var down_t = 0.0
var heal_t = 0.0
var dead = false
var car = null
var wave_t = 0.0
var flip_t = 0.0
var fire_note_t = 0.0
var death_t = 0.0          # seconds since you died (the death screen)
# first person: head bob, tilt, landing dip, weapon sway
var bob_ph = 0.0
var cam_roll = 0.0
var land_dip = 0.0
var was_ground = true
var air_vy = 0.0
var _look_yaw = 0.0
var _look_pitch = 0.0
var sway = Vector2()
# the gun's own animation: kick, the slide/bolt/pump cycle, the flash, the reload
var vm_kick = 0.0
var shot_t = 9.0
var flash_t = 0.0
var flash_frames = 0       # the flash shows for at least this many drawn frames
var flash_rot = 0.0
var flash_scale = 1.0
var reload_total = 1.0
var reload_shells = 1
var eject_at = -1.0
var lh = null              # first person: the other hand, for reloads
var respawning = false
var last_from = null       # where the last hit came from, for the fall
var hands_up = 0.0
var trigger_latch = false
var combo = 0
var punch_t = 0.0
var punch_dur = 0.3
var punch_side = 1
var punch_hook = false
var last_punch = -99.0
var pending_hit = null
var shake = 0.0
var recoil = 0.0
var step_acc = 0.0
var foot_seen = 0
var vm = null           # first-person hands and gun
var vm_flip = null      # first-person: the left hand giving the finger
var vm_flip_key = ""
var flip_vis = 0.0
var vm_gun = null
var vm_key = ""
var emote_name = ""     # a dance or gesture from the emote wheel
var emote_t = 0.0
var emote_dur = 0.0
var rag_t = 0.0         # time left on the ground as a ragdoll
var flopped = false
var slip_t = 0.0
var throw_t = 0.0
var snow_cd = 0.0
var clap_t = 0.0
const PUNCHES = [{ "dmg": 9, "cd": 0.3, "side": -1, "reach": 1.75 }, { "dmg": 12, "cd": 0.36, "side": 1, "reach": 1.8 }, { "dmg": 19, "cd": 0.62, "side": -1, "reach": 1.7, "hook": true }]

func setup(m):
	main = m

func stats():
	return GUN.stats(G.S["cur"])

func spawn():
	_build_body()
	var p = G.S.get("pos")
	if typeof(p) == TYPE_DICTIONARY and p.has("x"):
		place(p.x, p.get("y", 0), p.z, p.get("yaw", 0))
	else:
		place(-6.5, 0, -42, -0.8)
	cam_pitch = -0.08
	dead = false; down_t = 0

func _build_body():
	if human:
		human.queue_free()
	human = load("res://scripts/Human.gd").new()
	human.build(G.skin_opts(G.S["skin"]))
	main.add_child(human)
	gun_key = ""
	_refresh_gun()

func _refresh_gun():
	var key = G.S["cur"] + JSON.print(GUN.cfg_of(G.S["cur"]))
	if key == gun_key and gun_model:
		return
	if gun_model:
		gun_model.queue_free()
	gun_model = GUN.build(G.S["cur"])
	gun_model.rotation = Vector3(PI / 2, 0, 0)
	gun_model.translation = Vector3(0, -0.03, 0.02)
	gun_model.scale = Vector3.ONE * 1.35
	human.gun_slot.add_child(gun_model)
	gun_key = key

func place(x, y, z, yaw = null):
	pos = Vector3(x, y, z); vel = Vector3(); on_ground = true; air_y = y; pivot_y = y + 1.58
	if yaw != null:
		cam_yaw = yaw; body_yaw = yaw + PI

func targets():
	if crouch and not aiming:
		return [pos + Vector3(0, 0.98, 0), pos + Vector3(0, 0.62, 0)]
	return [pos + Vector3(0, 1.62, 0), pos + Vector3(0, 1.22, 0)]

func fp_on():
	return bool(G.S["settings"].get("fp", false))

# ---------- looking around ----------
func _input(e):
	if G.MODE != "play":
		return
	if e is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and not main.hud.wheel_open():
		look(e.relative.x, e.relative.y)
	if e is InputEventMouseButton and e.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED and not main.touch.enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if main.hud.wheel_kind == "emote" and (e.is_action_pressed("use") or e.is_action_pressed("next_weapon")):
		return   # those flip the emote wheel's pages
	if e.is_action_pressed("camera"):
		G.S["settings"]["fp"] = not fp_on()
		main.hud.banner("First person" if fp_on() else "Third person", "V to switch")
	elif e.is_action_pressed("car"):
		car_press()
	elif e.is_action_pressed("reload"):
		if car: main.sfx.next_station()
		else: start_reload()
	elif e.is_action_pressed("next_weapon") and not car:
		pass   # tap cycles, hold opens the weapon wheel (HUD)
	elif e.is_action_pressed("gun1"): switch_weapon("k9")
	elif e.is_action_pressed("gun2"): switch_weapon("draft")
	elif e.is_action_pressed("gun3"): switch_weapon("plow")
	elif e.is_action_pressed("gun4"): switch_weapon("dragon")
	elif e.is_action_pressed("gun5"): switch_weapon("buzz")
	elif e.is_action_pressed("fists"): set_fists(true)
	elif e.is_action_pressed("crouch") and not car:
		crouch = not crouch
	elif e.is_action_pressed("bandage"):
		use_bandage()
	elif e.is_action_pressed("wave") and not car:
		wave_t = 2.2
	elif e.is_action_pressed("flop") and not car:
		flop()
	elif e.is_action_pressed("snowball") and not car:
		throw_snowball()
	elif e.is_action_pressed("flip"):
		flip_t = max(flip_t, 2.4)
		main.peds.flip_react(pos)
	elif e.is_action_pressed("horn") and car:
		main.sfx.play3d("horn", car.pos, 0.8)
	elif e.is_action_pressed("use"):
		use_press()
	# (each of these opens the phone and stops the press here, or the phone would take the same
	# press as "close" a moment later)
	elif e.is_action_pressed("phone"):
		main.phone.open()
		get_tree().set_input_as_handled()
	elif e.is_action_pressed("map"):
		main.phone.open("map")
		get_tree().set_input_as_handled()
	elif e.is_action_pressed("pause"):
		if main.console.on: main.console.pause_menu()
		else: main.phone.open("settings")
		get_tree().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and e.scancode == KEY_Y and main.net.online():
		# Y: chat (the phone's Online app, with the chat box)
		main.phone.open("online")
		get_tree().set_input_as_handled()

func look(dx, dy):
	var s = 0.0022 * float(G.S["settings"].get("sens", 1.0)) * (0.6 if aim_t > 0.5 else 1.0)
	cam_yaw -= dx * s
	cam_pitch = clamp(cam_pitch - dy * s * (-1 if G.S["settings"].get("invertY", false) else 1), -1.25, 1.0)
	if abs(dx) + abs(dy) > 1:
		last_look = G.REAL_T

# ---------- every frame ----------
func update(dt):
	if dead: _death(dt)
	hands_up = max(0, hands_up - dt)
	wave_t = max(0, wave_t - dt)
	if Input.is_action_pressed("flip") and G.MODE == "play":
		flip_t = max(flip_t, 0.25)
	flip_t = max(0, flip_t - dt)
	fire_note_t = max(0, fire_note_t - dt)
	if punch_t > 0:
		punch_t += dt
		if punch_t > punch_dur: punch_t = 0
	if pending_hit:
		pending_hit.t -= dt
		if pending_hit.t <= 0:
			var h = pending_hit
			pending_hit = null
			_land_punch(h)
	# right stick and arrow keys look
	_aim_assist(dt)
	var lx = Input.get_action_strength("look_r") - Input.get_action_strength("look_l")
	var ly = Input.get_action_strength("look_d") - Input.get_action_strength("look_u")
	if abs(lx) + abs(ly) > 0.05 and G.MODE == "play" and not main.hud.wheel_open():
		var k = 1100 * dt * float(G.S["settings"]["pad"].get("sens", 1.0)) / max(0.1, float(G.S["settings"].get("sens", 1.0)))
		k *= 1.0 - 0.45 * assist_f    # the stick slows down over a target
		look(sign(lx) * pow(abs(lx), 1.6) * k, sign(ly) * pow(abs(ly), 1.6) * k * 0.72)
	if car:
		pos = Vector3(car.pos.x, 0, car.pos.z); vel = Vector3(car.vel.x, 0, car.vel.y); speed = abs(car.speed); body_yaw = car.yaw
		human.visible = false; aim_t = 0; aiming = false; sprinting = false
		var so = G.skin_opts(G.S["skin"])
		main.vehicles.flip_arm(car, flipping() and not fp_on(), G.hex_color(so.skin), G.hex_color(so.jacket2 if so.top == "varsity" else so.jacket), dt)
		fire_cd -= dt; switch_t -= dt
		G.S["stats"]["drive"] = G.S["stats"].get("drive", 0) + speed * dt
		if G.GAME_T - last_hurt > 8 and G.S["health"] < 60:
			G.S["health"] = min(60, G.S["health"] + dt * 1.5)
		return
	human.visible = true
	if _ragdoll_update(dt): return
	var busy = G.MODE != "play"
	var ix = Input.get_action_strength("move_r") - Input.get_action_strength("move_l")
	var iz = Input.get_action_strength("move_f") - Input.get_action_strength("move_b")
	var il = Vector2(ix, iz).length()
	if il > 1:
		ix /= il
		iz /= il
	var down = down_t > 0
	if down:
		ix = 0; iz = 0; down_t -= dt
	if busy:
		ix = 0; iz = 0
	aiming = not busy and not down and Input.is_action_pressed("aim")
	var st = stats()
	aim_t = clamp(aim_t + (1 if aiming else -1) * dt * 7 * (1.8 if G.S.get("fists", false) else float(st.get("aimSpeed", 1))), 0, 1)
	var moving = Vector2(ix, iz).length() > 0.1
	# emotes play until you move (or run out)
	if emote_name != "":
		emote_t += dt
		if (moving and emote_t > 0.3) or aiming or (emote_dur > 0 and emote_t > emote_dur) or Input.is_action_pressed("fire"):
			emote_name = ""
		elif emote_name == "clap":
			clap_t -= dt
			if clap_t <= 0:
				clap_t = 0.45; main.sfx.play3d("clap", pos + Vector3(0, 1.3, 0), 0.35, G.rand(1.6, 1.9))
	throw_t = max(0, throw_t - dt); snow_cd = max(0, snow_cd - dt)
	var want_sprint = not busy and Input.is_action_pressed("sprint") and iz > 0.3 and not aiming and moving
	if want_sprint and crouch: crouch = false
	var cold_k = 0.4 if G.S.get("warmth", 100) < 35 else 1.0
	if want_sprint and not stamina_lock and stamina > 0:
		sprinting = true; stamina -= dt * 17
		if stamina <= 0:
			stamina = 0
			stamina_lock = true
	else:
		sprinting = false; stamina = min(100, stamina + dt * 15 * cold_k)
		if stamina > 25: stamina_lock = false
	var spd = 7.3 if sprinting else (2.1 if crouch else (2.7 if aiming else 4.3))
	if G.S["health"] < 30: spd *= 0.85
	var fx = -sin(cam_yaw)
	var fz = -cos(cam_yaw)
	var rx = cos(cam_yaw)
	var rz = -sin(cam_yaw)
	var mx = fx * iz + rx * ix
	var mz = fz * iz + rz * ix
	var ml = Vector2(mx, mz).length()
	if ml > 1e-3:
		mx /= ml
		mz /= ml
	var mag = min(1, Vector2(ix, iz).length())
	var ice = main.vehicles.on_ice(pos.x, pos.z, pos.y)
	if ice and sprinting and on_ground:
		slip_t += dt
		if slip_t > 0.4 and randf() < dt * 0.9:
			slip_t = 0
			knock(Vector3(vel.x * 0.9, 2.5, vel.z * 0.9), 0, 2.2)
			main.hud.banner("Slipped on the ice", "")
			main.story.post_feed("@ice.cold.ivy", "just watched somebody eat it on the ice on %s" % main.hud.street_name(pos))
			return
	else:
		slip_t = 0
	var acc = (1.8 if ice else 13.0) if on_ground else 2.5
	var k2 = 1 - exp(-acc * dt)
	vel.x += (mx * spd * mag - vel.x) * k2
	vel.z += (mz * spd * mag - vel.z) * k2
	var mv = W.move_body(self, vel.x * dt, vel.z * dt, dt)
	if Input.is_action_just_pressed("jump") and on_ground and not busy and not down and not crouch:
		vel.y = 6.4; on_ground = false; air_y = pos.y
	if mv.landed > 1.0: main.sfx.land(pos, mv.landed)
	if mv.landed > 4.2:
		hurt((mv.landed - 4.2) * 8, null, true); shake = 0.6
	speed = Vector2(vel.x, vel.z).length()
	if on_ground and speed > 0.6:
		step_acc += speed * dt
		if step_acc > (1.05 if sprinting else 0.8):
			step_acc = 0
		G.S["stats"]["dist"] = G.S["stats"].get("dist", 0) + speed * dt
	# face where you aim, or where you walk
	var face_aim = aim_t > 0.2 or G.GAME_T - last_shot < 0.6 or G.GAME_T - last_punch < 0.8 or fp_on()
	var target_yaw = body_yaw
	if face_aim: target_yaw = cam_yaw + PI
	elif speed > 0.4: target_yaw = atan2(vel.x, vel.z)
	body_yaw += G.ang_diff(body_yaw, target_yaw) * (1 - exp(-dt * (22 if face_aim else 10)))
	human.translation = pos
	human.rotation = Vector3(0, body_yaw, 0)
	var fists = G.S.get("fists", false)
	human.animate(dt, {
		"speed": speed, "crouch": (1.0 if not aiming else 0.6) if crouch else 0.0, "aim": 0.0 if fists else max(aim_t, 1.0 if G.GAME_T - last_shot < 0.5 else 0.0),
		"look": G.ang_diff(body_yaw, cam_yaw + PI) if not fp_on() else 0.0, "air": not on_ground and vel.y > -40.0,
		"pitch": cam_pitch, "down": (clamp(down_t, 0, 1) if down else 0.0) if emote_name != "snowangel" else min(1.0, emote_t * 3), "twoHand": not G.S["cur"] in ["k9", "buzz"], "shiver": G.S.get("warmth", 100) < 30,
		"hands": hands_up > 0, "wave": wave_t > 0 and not aiming, "flip": flipping(),
		"fists": fists, "guard": fists and aiming, "punch": punch_t / punch_dur if punch_t > 0 else 0.0, "punchSide": punch_side, "hook": punch_hook,
		"emote": emote_name, "et": emote_t,
		"reload": _reload_u() if not fists else -1.0, "kick": vm_kick if not fists else 0.0,
	})
	# one footstep per footfall of the walk cycle, softer when crouched
	if human.foot != foot_seen:
		foot_seen = human.foot
		if on_ground and speed > 0.6: main.sfx.step(pos, sprinting, crouch, foot_seen)
	if throw_t > 0:
		# overhand throw on the right arm
		var tk = throw_t / 0.45
		human._rot(human.AR.sh, lerp(-2.7, -0.6, 1 - tk), 0, 0.2); human._rot(human.AR.elbow, lerp(-1.6, -0.2, 1 - tk), 0, 0); human.sync_bones()
	if gun_model:
		gun_model.visible = not fists and hands_up <= 0 and emote_name == "" and throw_t <= 0
		if gun_model.visible and not fp_on():
			_apply_gun(gun_model, G.S["cur"], _gun_pose(G.S["cur"], _reload_u()))
	shot_t += dt
	flash_t -= dt
	flash_frames -= 1
	vm_kick *= exp(-dt * 14.0)
	if eject_at >= 0 and shot_t >= eject_at:
		eject_at = -1.0
		_eject_brass()
	# timers
	fire_cd -= dt; switch_t -= dt; bloom = max(0, bloom - dt * 2.2)
	if reload_t > 0:
		reload_t -= dt
		if reload_t <= 0: _finish_reload()
	if heal_t > 0:
		heal_t -= dt; G.S["health"] = min(100, G.S["health"] + dt * 26)
	var trig = not busy and not down and Input.is_action_pressed("fire")
	if trig:
		if (fists or st.get("auto", false)) or not trigger_latch:
			try_fire()
		trigger_latch = true
	else:
		trigger_latch = false
	if G.GAME_T - last_hurt > 8 and G.S["health"] < 60:
		G.S["health"] = min(60, G.S["health"] + dt * 1.5)

func flipping():
	return flip_t > 0 and not aiming and not dead and hands_up <= 0

# ---------- camera ----------
func update_camera(dt):
	var cam = main.camera
	shake = max(0, shake - dt * 1.8)
	recoil *= exp(-dt * 9)
	var jit = Vector3(randf() - 0.5, randf() - 0.5, 0) * shake * 0.03
	if car:
		if G.REAL_T - last_look > 1.4:
			# in a slide the camera swings toward where the car is going, not where it points
			var vy = car.yaw
			if car.vel.length() > 4.0 and car.speed > 0:
				vy = car.yaw + G.ang_diff(car.yaw, atan2(car.vel.x, car.vel.y)) * 0.55
			cam_yaw += G.ang_diff(cam_yaw, vy + PI) * (1 - exp(-dt * 2.6))
			cam_pitch += (-0.16 - cam_pitch) * (1 - exp(-dt * 2))
		if fp_on():
			main.cockpit.update(car, cam, dt)
		else:
			main.cockpit.hide()
			var fwd = Vector3(-sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), -cos(cam_yaw) * cos(cam_pitch))
			var piv = car.pos + Vector3(0, 1.6, 0)
			var dist = 7.2 + clamp(abs(car.speed) * 0.06, 0, 2)
			var t = W.raycast(piv, -fwd, dist + 0.3)
			if t != INF: dist = max(1.2, t - 0.3)
			cam.translation = piv - fwd * dist + jit
			cam.rotation = Vector3(cam_pitch, cam_yaw, 0)
		cam.fov = lerp(cam.fov, 64 + clamp(abs(car.speed), 0, 34) * 0.25, 1 - exp(-dt * 3))
		_hide_vm()
		return
	main.cockpit.hide()
	if dead and human.is_ragdoll():
		# third person on your body, like after dying in a sandbox game: it drifts slowly
		# around and pulls back, and you can still turn it
		_hide_vm()
		if G.REAL_T - last_look > 1.0: cam_yaw += dt * 0.18
		cam_pitch += (-0.42 - cam_pitch) * (1 - exp(-dt * 1.5))
		var c = human.ragdoll_center() + Vector3(0, 0.35, 0)
		var dfw = Vector3(-sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), -cos(cam_yaw) * cos(cam_pitch))
		var dd = 3.2 + min(death_t, 6.0) * 0.35
		var tt = W.raycast(c, -dfw, dd + 0.3)
		if tt != INF: dd = max(1.0, tt - 0.3)
		cam.translation = c - dfw * dd
		cam.rotation = Vector3(cam_pitch, cam_yaw, 0)
		cam.fov = lerp(cam.fov, 58.0, 1 - exp(-dt * 2))
		return
	var eye = 1.06 if crouch else 1.62
	pivot_y += (pos.y + eye - pivot_y) * (1 - exp(-dt * 14))
	var a = aim_t
	var zoom = lerp(1.0, float(stats().get("zoom", 1.2)) if not G.S.get("fists", false) else 1.0, a)
	if fp_on():
		var fwd2 = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var rgt = Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		# head bob: a step's dip and a little side to side, less when aiming, none in the air
		var hb = 1.0 if G.S["settings"].get("headbob", true) else 0.0
		var ab = clamp(speed / 5.5, 0.0, 1.2) * (1.0 - aim_t * 0.75) * (1.0 if on_ground else 0.0) * hb
		bob_ph = human.phase   # the head dips as each foot lands, in step with the sound
		var by = -abs(sin(bob_ph)) * 0.042 * ab
		var bxl = sin(bob_ph) * 0.02 * ab
		# a dip when you land, deeper after a longer fall
		if on_ground and not was_ground: land_dip = min(0.16, 0.03 + abs(air_vy) * 0.012) * max(hb, 0.3)
		was_ground = on_ground
		if not on_ground: air_vy = vel.y
		land_dip *= exp(-dt * 7.0)
		# tilt: lean into a strafe and a turn, plus a touch with each step
		var strafe = (Input.get_action_strength("move_r") - Input.get_action_strength("move_l")) if G.MODE == "play" and not dead else 0.0
		var yr = G.ang_diff(_look_yaw, cam_yaw) / max(dt, 0.001)
		var roll_t = (-strafe * 0.068 - clamp(yr, -6.0, 6.0) * 0.0095) * hb + sin(bob_ph) * 0.015 * ab
		cam_roll += (roll_t - cam_roll) * (1 - exp(-dt * 8.0))
		cam.translation = Vector3(pos.x, pivot_y + by - land_dip, pos.z) + fwd2 * 0.14 + rgt * bxl + jit
		cam.rotation = Vector3(clamp(cam_pitch + recoil, -1.45, 1.45), cam_yaw, cam_roll)
		cam.fov = lerp(cam.fov, (float(G.S["settings"].get("fov", 70)) + (6 if sprinting else 0)) / zoom, 1 - exp(-dt * 12))
		human.visible = false
		_update_vm(dt, a)
		_update_flip_vm(dt)
		return
	_hide_vm()
	var fwd3 = Vector3(-sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), -cos(cam_yaw) * cos(cam_pitch))
	var right = Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var piv2 = Vector3(pos.x, pivot_y - 0.05, pos.z) + right * lerp(0.42, 0.62, a)
	var want = lerp(3.9, 1.9, a)
	var t2 = W.raycast(piv2, -fwd3, want + 0.3)
	var d = want
	if t2 != INF: d = max(0.35, t2 - 0.3)
	cam_dist += (d - cam_dist) * (1.0 if d < cam_dist else 1 - exp(-dt * 6))
	cam.translation = piv2 - fwd3 * cam_dist + jit
	if cam.translation.y < W.ground_at(cam.translation.x, cam.translation.z, cam.translation.y) + 0.25:
		cam.translation.y = W.ground_at(cam.translation.x, cam.translation.z, cam.translation.y) + 0.25
	cam.rotation = Vector3(cam_pitch + recoil, cam_yaw, 0)
	cam.fov = lerp(cam.fov, (67.0 if sprinting else 62.0) / zoom, 1 - exp(-dt * 10))
	human.visible = cam_dist > 0.9

func _hide_vm():
	if vm: vm.visible = false
	if vm_flip: vm_flip.visible = false
	flip_vis = 0.0

# first person: the left hand comes up into view with the middle finger, walking or not
func _update_flip_vm(dt):
	flip_vis = move_toward(flip_vis, 1.0 if flipping() else 0.0, dt * 6.0)
	var skin = G.hex_color(G.skin_opts(G.S["skin"]).skin)
	var sleeve = G.hex_color(G.S["skin"].get("topCol", 0x262b33))
	var key = str(skin) + str(sleeve)
	if vm_flip == null or key != vm_flip_key:
		if vm_flip: vm_flip.queue_free()
		vm_flip = Spatial.new()
		main.camera.add_child(vm_flip)
		_vm_part(vm_flip, CylinderMesh.new(), sleeve, Vector3(0, -0.2, 0), Vector3(0.042, 0.3, 0.042))
		_vm_part(vm_flip, SphereMesh.new(), skin, Vector3(0, -0.02, 0), Vector3(0.048, 0.055, 0.04))
		# folded fingers, the thumb, and the middle finger standing up
		for i in range(4):
			if i == 2: continue
			_vm_part(vm_flip, SphereMesh.new(), skin, Vector3(-0.027 + i * 0.018, 0.022, 0.02), Vector3(0.011, 0.013, 0.012))
		_vm_part(vm_flip, SphereMesh.new(), skin, Vector3(-0.04, 0.0, 0.025), Vector3(0.012, 0.022, 0.011), Vector3(0, 0, 0.5))
		var f = _vm_part(vm_flip, CapsuleMesh.new(), skin, Vector3(0.006, 0.07, 0.012), Vector3(1, 1, 1), Vector3(PI / 2, 0, 0))
		f.mesh.radius = 0.0135; f.mesh.mid_height = 0.065; f.mesh.radial_segments = 8; f.mesh.rings = 1
		vm_flip_key = key
	vm_flip.visible = flip_vis > 0.01
	if not vm_flip.visible: return
	var e = flip_vis * flip_vis * (3.0 - 2.0 * flip_vis)
	var bob = min(1.0, speed / 5.0)
	vm_flip.translation = Vector3(-0.15 + cos(step_acc * 6) * 0.01 * bob, lerp(-0.46, -0.105, e) + sin(G.REAL_T * 9) * 0.004 + abs(sin(step_acc * 6)) * 0.008 * bob, -0.34)
	vm_flip.rotation = Vector3(0.12, 0.3, 0.1)

# first person: your hands and the gun (or both fists)
func _update_vm(dt, a):
	var key = G.S["cur"] + str(G.S.get("fists", false)) + JSON.print(GUN.cfg_of(G.S["cur"]))
	if vm == null or key != vm_key:
		if vm: vm.queue_free()
		lh = null
		vm = Spatial.new()
		main.camera.add_child(vm)
		var skin = G.hex_color(G.skin_opts(G.S["skin"]).skin)
		var sleeve = G.hex_color(G.S["skin"].get("topCol", 0x262b33))
		if G.S.get("fists", false):
			for s in [-1, 1]:
				var f = Spatial.new(); f.name = "L" if s < 0 else "R"; vm.add_child(f)
				_vm_part(f, SphereMesh.new(), skin, Vector3(), Vector3(0.05, 0.045, 0.055))
				_vm_part(f, CylinderMesh.new(), sleeve, Vector3(s * 0.04, -0.1, 0.2), Vector3(0.045, 0.22, 0.045), Vector3(1.2, 0, 0))
		else:
			vm_gun = GUN.build(G.S["cur"])
			vm_gun.rotation = Vector3(0, PI, 0)
			vm.add_child(vm_gun)
			_vm_part(vm, SphereMesh.new(), skin, Vector3(0.004, -0.032, 0.035), Vector3(0.04, 0.045, 0.05))
			_vm_part(vm, CylinderMesh.new(), sleeve, Vector3(0.06, -0.13, 0.22), Vector3(0.04, 0.2, 0.04), Vector3(1.0, 0, 0.3))
			# the other hand, in the gun's own space, for reloads and racking
			lh = Spatial.new(); lh.name = "LH"; vm_gun.add_child(lh)
			_vm_part(lh, SphereMesh.new(), skin, Vector3(), Vector3(0.042, 0.04, 0.05))
			_vm_part(lh, CylinderMesh.new(), sleeve, Vector3(-0.03, -0.12, -0.08), Vector3(0.04, 0.2, 0.04), Vector3(0.6, 0, -0.3))
			lh.visible = false
		vm_key = key
	vm.visible = hands_up <= 0
	var bob = min(1.0, speed / 5.0)
	var bx = cos(bob_ph) * 0.012 * bob
	# weapon sway: the gun lags a little behind where you look
	var dyaw = G.ang_diff(_look_yaw, cam_yaw)
	var dpit = cam_pitch - _look_pitch
	_look_yaw = cam_yaw; _look_pitch = cam_pitch
	sway = sway.linear_interpolate(Vector2(clamp(-dyaw * 1.6, -0.12, 0.12), clamp(dpit * 1.6, -0.1, 0.1)), 1 - exp(-dt * 10.0))
	if G.S.get("fists", false):
		for s in [-1, 1]:
			var f = vm.get_node("L" if s < 0 else "R")
			var x = s * lerp(0.15, 0.095, a)
			var y = lerp(-0.165, -0.11, a)
			var z = lerp(-0.36, -0.32, a)
			if punch_t > 0 and punch_side == s:
				var e = sin(clamp(punch_t / punch_dur, 0, 1) * PI)
				z -= 0.26 * e; y += 0.06 * e; x = lerp(x, s * 0.03, e)
			f.translation = Vector3(x + bx, y + abs(sin(bob_ph)) * 0.008 * bob, z)
		vm.translation = Vector3()
		vm.rotation = Vector3(sway.y, sway.x, 0)
	else:
		var id = G.S["cur"]
		var P = _gun_pose(id, _reload_u())
		var kk = vm_kick * clamp(float(stats().get("recoil", 1.0)), 0.5, 2.5)
		vm.translation = Vector3(lerp(0.13, 0.0, a) + bx + sway.x * 0.08, lerp(-0.15, -0.092, a) + abs(sin(bob_ph)) * 0.008 * bob, lerp(-0.42, -0.36, a)) + P.off + Vector3(0, 0.004, 0.045) * kk
		vm.rotation = Vector3(0.11 * kk + sway.y, lerp(0.04, 0.0, a) + sway.x + (randf() - 0.5) * 0.01 * kk, 0) + P.rot
		_apply_gun(vm_gun, id, P)
		if lh:
			lh.visible = P.hand != null
			if P.hand != null: lh.translation = P.hand

# ---------- the gun moving: what fires, what reloads ----------
# where the mag sits and which way it drops (gun space: barrel +Z, up +Y), and where the
# other hand grabs to rack it
const MAGW = { "k9": Vector3(0, -0.04, -0.02), "draft": Vector3(0, -0.06, 0.11), "dragon": Vector3(0, -0.08, 0.15), "buzz": Vector3(0, -0.07, 0.0) }
const MAGD = { "k9": Vector3(0, -0.28, -0.07), "draft": Vector3(0, -0.3, 0.03), "dragon": Vector3(0, -0.3, 0.1), "buzz": Vector3(0, -0.32, 0.03) }
const RACK = { "k9": Vector3(0, 0.09, -0.03), "draft": Vector3(0.05, 0.08, 0.13), "dragon": Vector3(0.05, 0.07, 0.14), "buzz": Vector3(0, 0.15, 0.12), "plow": Vector3(0, 0.02, 0.31) }

func _ease(x):
	x = clamp(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _reload_u():
	return (1.0 - reload_t / max(0.2, reload_total)) if reload_t > 0 else -1.0

# the pose of the gun's parts at reload progress u (-1 when not reloading)
func _gun_pose(id, u):
	var kind = GUN.KIND.get(id, "pistol")
	var g = G.S["guns"].get(id, { "mag": 1 })
	var out = { "rot": Vector3(), "off": Vector3(), "slide": 0.0, "mag": Vector3(), "mag_vis": kind != "shotgun", "hand": null }
	if u < 0:
		if kind == "shotgun":
			# pump: back and forward a moment after the shot
			var t = shot_t - 0.16
			if t > 0 and t < 0.28:
				out.slide = clamp(t / 0.14, 0.0, 1.0) if t < 0.14 else clamp(1.0 - (t - 0.14) / 0.14, 0.0, 1.0)
				out.off = Vector3(0, -0.012, 0.02) * sin(t / 0.28 * PI)
				out.hand = RACK.plow + Vector3(0, 0, -GUN.TRAVEL.plow * out.slide)
		else:
			out.slide = clamp(shot_t / 0.012, 0.0, 1.0) if shot_t < 0.012 else clamp(1.0 - (shot_t - 0.012) / 0.05, 0.0, 1.0)
			if kind == "pistol" and int(g.mag) <= 0: out.slide = 1.0
		return out
	var tilt = min(_ease(u / 0.15), _ease((1.0 - u) / 0.12))
	if kind == "shotgun":
		# roll it over and push shells into the loading port one by one, then pump
		out.rot = Vector3(0.12, 0, -0.45) * tilt
		out.off = Vector3(0.03, 0.03, 0) * tilt
		var n = max(1, reload_shells)
		if u >= 0.12 and u < 0.86:
			var seg = 0.74 / n
			var k = int((u - 0.12) / seg)
			var sp = (u - 0.12 - k * seg) / seg
			out.mag = Vector3(0.01, -0.22, -0.02).linear_interpolate(Vector3(), _ease((sp - 0.15) / 0.6))
			out.mag_vis = sp < 0.85
			out.hand = out.mag + Vector3(0, -0.035, 0.08)
		elif u >= 0.86:
			var pp = (u - 0.86) / 0.14
			out.slide = clamp(pp / 0.5, 0.0, 1.0) if pp < 0.5 else clamp(1.0 - (pp - 0.5) / 0.5, 0.0, 1.0)
			out.hand = RACK.plow + Vector3(0, 0, -GUN.TRAVEL.plow * out.slide)
		return out
	# mag guns: tilt, drop the mag, fetch a new one, seat it, rack, back to ready
	out.rot = Vector3(0.22, 0, 0.5) * tilt
	out.off = Vector3(-0.04, 0.02, 0) * tilt
	var D = MAGD.get(id, Vector3(0, -0.3, 0))
	var Wl = MAGW.get(id, Vector3())
	var pouch = Vector3(-0.08, -0.55, 0.05)
	var rack = RACK.get(id, Vector3(0, 0.09, -0.04))
	if u >= 0.15 and u < 0.34:
		out.mag = D * _ease((u - 0.15) / 0.19); out.mag_vis = u < 0.32
	elif u >= 0.34 and u < 0.55:
		out.mag_vis = false
	elif u >= 0.55 and u < 0.72:
		out.mag = D * 0.75 * (1.0 - _ease((u - 0.55) / 0.17))
	if u >= 0.22 and u < 0.45:
		out.hand = (Wl + Vector3(0, -0.09, 0)).linear_interpolate(pouch, _ease((u - 0.22) / 0.23))
	elif u >= 0.45 and u < 0.55:
		out.hand = pouch.linear_interpolate(Wl + D * 0.75 + Vector3(0, -0.1, 0), _ease((u - 0.45) / 0.1))
	elif u >= 0.55 and u < 0.72:
		out.hand = Wl + out.mag + Vector3(0, -0.1, 0)
	elif u >= 0.72 and u < 0.78:
		out.hand = (Wl + Vector3(0, -0.1, 0)).linear_interpolate(rack, _ease((u - 0.72) / 0.06))
	elif u >= 0.78 and u < 0.86:
		out.slide = 1.0
		out.hand = rack + Vector3(0, 0, -GUN.TRAVEL.get(id, 0.05))
	elif u >= 0.86 and u < 1.0:
		out.hand = rack.linear_interpolate(pouch, _ease((u - 0.86) / 0.14))
	if kind == "pistol" and int(g.mag) <= 0 and u < 0.78: out.slide = 1.0
	return out

func _apply_gun(gn, id, P):
	if gn == null: return
	var sl = gn.get_node_or_null("Slide")
	if sl: sl.translation = Vector3(0, 0, -GUN.TRAVEL.get(id, 0.05) * P.slide)
	var mg = gn.get_node_or_null("Mag")
	if mg:
		mg.translation = P.mag
		mg.visible = P.mag_vis
	var fl = gn.get_node_or_null("Flash")
	if fl:
		fl.visible = flash_t > 0 or flash_frames > 0
		if fl.visible:
			fl.rotation = Vector3(0, 0, flash_rot); fl.scale = Vector3.ONE * flash_scale

# a casing (or the shotgun's hull) out of the ejection port, to the right and up
func _eject_brass():
	var gn = vm_gun if fp_on() and vm_gun else gun_model
	if gn == null or not gn.is_inside_tree() or not gn.has_node("Eject"): return
	var at = gn.get_node("Eject").global_transform.origin
	var rgt = Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var v = rgt * G.rand(1.6, 2.4) + Vector3(0, G.rand(1.6, 2.4), 0) + Vector3(-sin(cam_yaw), 0, -cos(cam_yaw)) * G.rand(-0.4, 0.2)
	main.fx.brass(at, v, G.S["cur"] == "plow")

func _vm_part(parent, m, col, p, s, r = Vector3()):
	if m is SphereMesh:
		m.radius = 1; m.height = 2; m.radial_segments = 10; m.rings = 6
	elif m is CylinderMesh:
		m.top_radius = 1; m.bottom_radius = 1; m.height = 1; m.radial_segments = 8
	elif m is CapsuleMesh:
		m.radius = 0.0135; m.mid_height = 0.065
	var mi = MeshInstance.new(); mi.mesh = m; mi.material_override = G.mat(col)
	mi.translation = p; mi.scale = s; mi.rotation = r
	parent.add_child(mi)
	return mi

# ---------- weapons ----------
func switch_weapon(id):
	var g = G.S["guns"].get(id)
	if g == null or not g.owned or (G.S["cur"] == id and not G.S.get("fists", false)) or down_t > 0:
		return
	G.S["cur"] = id; G.S["fists"] = false; reload_t = 0; switch_t = 0.4
	_refresh_gun(); main.sfx.play("reload", 0.5)

func set_fists(on):
	if bool(G.S.get("fists", false)) == on or down_t > 0:
		return
	G.S["fists"] = on; reload_t = 0; switch_t = 0.22; combo = 0; punch_t = 0
	main.sfx.play("swing", 0.4)

func cycle_weapon():
	var ids = []
	for id in GUN.IDS:
		if G.S["guns"].has(id) and G.S["guns"][id].owned: ids.append(id)
	ids.append("fists")
	var cur = "fists" if G.S.get("fists", false) else G.S["cur"]
	var nxt = ids[(ids.find(cur) + 1) % ids.size()]
	if nxt == "fists": set_fists(true)
	else: switch_weapon(nxt)

func start_reload():
	if G.S.get("fists", false):
		return
	var g = G.S["guns"][G.S["cur"]]
	var st = stats()
	if reload_t > 0 or g.mag >= st.mag or g.res <= 0:
		return
	reload_t = float(st.reload); reload_for = G.S["cur"]; reload_total = reload_t
	reload_shells = int(min(st.mag - g.mag, g.res))
	main.sfx.play("pump" if G.S["cur"] == "plow" else "reload", 0.55)

func _finish_reload():
	if reload_for != G.S["cur"]:
		return
	var g = G.S["guns"][G.S["cur"]]
	var take = min(stats().mag - g.mag, g.res)
	g.mag += take; g.res -= take

func _cone(base, deg):
	var r = deg2rad(deg) * sqrt(randf()) * 0.5
	var a = randf() * TAU
	var side = base.cross(Vector3.UP if abs(base.y) < 0.95 else Vector3(1, 0, 0)).normalized()
	var up = side.cross(base).normalized()
	return (base + side * cos(a) * tan(r) + up * sin(a) * tan(r)).normalized()

func try_fire():
	if main.interiors and main.interiors.inside != "" and not G.S.get("fists", false):
		if fire_note_t <= 0:
			fire_note_t = 4.0; main.hud.toast("Not in here. Keep it holstered.")
		return
	if G.S.get("fists", false):
		punch()
		return
	var g = G.S["guns"][G.S["cur"]]
	var st = stats()
	if reload_t > 0 or switch_t > 0 or fire_cd > 0:
		return
	if g.mag <= 0:
		main.sfx.play("dry", 0.5); fire_cd = 0.3
		if g.res > 0: start_reload()
		return
	fire_cd = 60.0 / float(st.rpm); g.mag -= 1
	G.S["stats"]["shots"] = G.S["stats"].get("shots", 0) + 1
	last_shot = G.GAME_T
	var cam = main.camera
	var org = cam.global_transform.origin
	var fwd = -cam.global_transform.basis.z
	var chest = Vector3(pos.x, pivot_y - 0.15, pos.z)
	org += fwd * max(0.3, (chest - org).dot(fwd))
	var muzzle = human.gun_slot.global_transform.origin + fwd * 0.3
	if fp_on() and vm_gun and vm_gun.has_node("Muzzle"): muzzle = vm_gun.get_node("Muzzle").global_transform.origin
	elif gun_model and gun_model.has_node("Muzzle"): muzzle = gun_model.get_node("Muzzle").global_transform.origin
	var spread = lerp(float(st.spread), float(st.aimSpread), aim_t) * (1.35 if speed > 1 else 1.0) * (0.8 if crouch else 1.0) * (1 + bloom)
	var hit_any = false
	var head_any = false
	for i in range(int(st.pellets)):
		var d = _cone(fwd, spread)
		var res = shoot_ray(org, d, float(st.range) * 2.2)
		var hp = org + d * (float(st.range) * 2 if res.t == INF else res.t)
		if i < 3:
			main.sfx.tracer(muzzle, hp)
			if i == 0: main.net.send_shot(muzzle, hp)
		if res.who != null:
			var dmg = float(st.dmg) * (1.8 if res.head else 1.0) * (0.5 if res.t > float(st.range) else 1.0)
			var dir = Vector3(d.x, 0, d.z)
			res.who.take_hit(dmg, res.head, dir, true, false)
			hit_any = true; head_any = head_any or res.head
		elif res.t != INF:
			main.sfx.impact(hp, res.car != null)
			if res.car: res.car.hp -= float(st.dmg) * 0.3
	if hit_any:
		main.hud.hitmarker(head_any); main.sfx.play("imp_flesh", 0.3)
	main.sfx.shot(G.S["cur"], muzzle, 1.0, GUN.cfg_of(G.S["cur"]).get("muzzle") == "supp")
	G.rumble({ "plow": 0.7, "dragon": 0.5 }.get(G.S["cur"], 0.25), { "plow": 0.9, "dragon": 0.6 }.get(G.S["cur"], 0.3), 0.07)
	main.sfx.flash(muzzle)
	# the gun kicks, the slide or bolt cycles, the flash shows, the brass flies (the shotgun's
	# hull comes out when you pump it)
	vm_kick = min(1.8, vm_kick + 1.0)
	shot_t = 0.0
	if GUN.cfg_of(G.S["cur"]).get("muzzle") != "supp":
		flash_t = 0.045; flash_frames = 2; flash_rot = randf() * TAU; flash_scale = G.rand(0.8, 1.15)
	eject_at = 0.24 if G.S["cur"] == "plow" else 0.01
	var rec = float(st.recoil) * (0.8 if crouch else 1.0)
	recoil += rec * 0.018; cam_pitch = clamp(cam_pitch + rec * 0.0035, -1.3, 1.1); cam_yaw += (randf() - 0.5) * rec * 0.006
	bloom = min(1.6, bloom + 0.22 * float(st.recoil))
	G.S["heat"] = clamp(G.S["heat"] + float(st.get("noise", 2)) * 0.4, 0, 100)
	main.peds.alert(pos, 48)
	main.crews.on_player_shot(pos)
	main.police.on_shot(pos)
	if g.mag == 0 and g.res > 0:
		start_reload()

# ray vs the world, people and cars; who = anything with take_hit()
func shoot_ray(o, d, max_t):
	var best = W.raycast(o, d, max_t)
	var who = null
	var head = false
	var hit_car = null
	for list in [main.crews.ENEMIES, main.peds.PEDS, main.police.COPS, main.net.targets()]:
		for e in list:
			if e.is_down(): continue
			var r = ray_body(o, d, e.pos, e.crouched if "crouched" in e else false)
			if r and r.t < best:
				best = r.t; who = e; head = r.head
	for v in main.vehicles.VEH:
		if v.dead: continue
		var t = W._ray_box(o, Vector3(1.0 / (d.x if abs(d.x) > 1e-9 else 1e-9), 1.0 / (d.y if abs(d.y) > 1e-9 else 1e-9), 1.0 / (d.z if abs(d.z) > 1e-9 else 1e-9)), v.box)
		if t < best:
			best = t; who = null; hit_car = v
	return { "t": best if best < max_t else INF, "who": who, "head": head, "car": hit_car }

# aim assist, for controllers only (Settings → Aim assist): the stick slows down when the
# crosshair is over someone, and while you aim it drifts onto crew members and cops near the
# crosshair, with a small snap toward them the moment you start aiming. Walls block it.
func _aim_assist(dt):
	assist_f = 0.0
	var start = aiming and not _aim_prev
	_aim_prev = aiming
	if not G.last_pad or not G.S["settings"].get("aimAssist", true) or car or G.MODE != "play" or G.S.get("fists", false) or dead:
		return
	if aim_t < 0.15 and G.GAME_T - last_shot > 0.4 and not start: return
	var cam = main.camera
	var o = cam.global_transform.origin
	var fwd = -cam.global_transform.basis.z
	var rng = float(stats().range) * 1.6
	var best_to = Vector3()
	var best_s = 1.0
	var hostile = false
	for li in [[main.crews.ENEMIES, true], [main.police.COPS, true], [main.net.targets(), false], [main.peds.PEDS, false]]:
		for e in li[0]:
			if e.is_down(): continue
			var p = e.pos + Vector3(0, 1.0 if ("crouched" in e and e.crouched) else 1.3, 0)
			var to = p - o
			var dist = to.length()
			if dist > rng or dist < 1.2: continue
			to /= dist
			# the cone is wider up close, where a body fills more of the screen
			var cone = min(0.3, 0.1 + 0.6 / dist) * (1.6 if start else 1.0)
			var sc = fwd.angle_to(to) / cone
			if sc >= best_s: continue
			if W.raycast(o, to, dist) < dist - 0.6: continue
			best_s = sc; best_to = to; hostile = li[1]
	if best_s >= 1.0: return
	assist_f = 1.0 - best_s
	if not hostile: return
	var dyaw = G.ang_diff(atan2(-fwd.x, -fwd.z), atan2(-best_to.x, -best_to.z))
	var dpit = asin(clamp(best_to.y, -1, 1)) - asin(clamp(fwd.y, -1, 1))
	var k = 0.55 if start else (1.0 - exp(-dt * 4.5 * assist_f)) * 0.7
	cam_yaw += dyaw * k
	cam_pitch = clamp(cam_pitch + dpit * k, -1.25, 1.0)

func ray_body(o, d, p, crouched):
	var top = 0.92 if crouched else 1.42
	var head_y = p.y + (1.02 if crouched else 1.6)
	var res = null
	var h = o - Vector3(p.x, head_y, p.z)
	var b = h.dot(d)
	var c = h.dot(h) - 0.04
	var disc = b * b - c
	if disc > 0:
		var t = -b - sqrt(disc)
		if t > 0: res = { "t": t, "head": true }
	var ox = o.x - p.x
	var oz = o.z - p.z
	var A = d.x * d.x + d.z * d.z
	var B = 2 * (ox * d.x + oz * d.z)
	var C = ox * ox + oz * oz - 0.34 * 0.34
	var D2 = B * B - 4 * A * C
	if D2 > 0 and A > 1e-6:
		var t2 = (-B - sqrt(D2)) / (2 * A)
		if t2 > 0:
			var y = o.y + d.y * t2
			if y > p.y and y < p.y + top and (res == null or t2 < res.t):
				res = { "t": t2, "head": false }
	return res

# ---------- fists ----------
func punch():
	if fire_cd > 0 or switch_t > 0 or car or down_t > 0:
		return
	if G.REAL_T - last_punch > 0.9:
		combo = 0
	var pu = PUNCHES[combo % 3]
	combo = (combo + 1) % 3
	fire_cd = pu.cd; punch_t = 0.0001; punch_dur = min(0.3, pu.cd * 0.85); punch_side = pu.side; punch_hook = pu.get("hook", false)
	last_punch = G.GAME_T
	G.S["stats"]["punches"] = G.S["stats"].get("punches", 0) + 1
	main.sfx.play3d("swing", pos + Vector3(0, 1.4, 0), 0.4)
	var f = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var t = melee_target(pos, f, pu.reach)
	if t:
		pending_hit = { "who": t, "pu": pu, "t": 0.08, "f": f }

func melee_target(p, f, reach):
	var best = null
	var bs = INF
	for list in [main.crews.ENEMIES, main.peds.PEDS, main.police.COPS, main.net.targets()]:
		for e in list:
			if e.is_down(): continue
			var dv = Vector3(e.pos.x - p.x, 0, e.pos.z - p.z)
			var d = dv.length()
			if d < 0.05 or d > reach + 0.35 or abs(e.pos.y - p.y) > 1.3: continue
			var cs = dv.dot(f) / d
			if cs < 0.5: continue
			var s = d - cs * 0.6
			if s < bs:
				bs = s
				best = e
	return best

func _land_punch(h):
	var e = h.who
	if e.is_down() or Vector2(e.pos.x - pos.x, e.pos.z - pos.z).length() > h.pu.reach + 0.6:
		return
	var hook = h.pu.get("hook", false)
	main.sfx.play3d("punch", e.pos + Vector3(0, 1.45, 0), 1.0 if hook else 0.75)
	main.hud.hitmarker(hook)
	shake = max(shake, 0.2 if hook else 0.1)
	G.rumble(0.6 if hook else 0.3, 0.6, 0.14 if hook else 0.08)
	e.take_hit(h.pu.dmg, false, h.f, true, true)
	if "vel" in e:
		e.vel.x += h.f.x * (4 if hook else 2.2); e.vel.z += h.f.z * (4 if hook else 2.2)

# incoming punch: your guard blocks most of it when you face it
func take_punch(dmg, from):
	if dead or car: return
	var f = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var dv = Vector3(from.x - pos.x, 0, from.z - pos.z)
	var blocked = G.S.get("fists", false) and aiming and dv.length() > 0 and dv.normalized().dot(f) > 0.2
	main.sfx.play3d("punch", pos + Vector3(0, 1.5, 0), 0.4 if blocked else 0.8)
	shake = max(shake, 0.08 if blocked else 0.3)
	if blocked: stamina = max(0, stamina - 8)
	hurt(dmg * (0.25 if blocked else 1.0), from, true)

# ---------- health ----------
func hurt(dmg, from, silent = false):
	if dead or G.MODE == "title": return
	if typeof(from) == TYPE_VECTOR3: last_from = from
	G.S["health"] -= dmg; last_hurt = G.GAME_T; shake = min(1, shake + dmg * 0.04)
	main.hud.hurt_flash(dmg)
	G.rumble(min(1, 0.25 + dmg / 30.0), 0.4, 0.16)
	if not silent:
		main.sfx.play("hurt", 0.7)
	if G.S["health"] <= 0:
		G.S["health"] = 0
		_downed()

func _downed():
	if dead: return
	dead = true; down_t = 4; emote_name = ""
	G.S["stats"]["timesDowned"] = G.S["stats"].get("timesDowned", 0) + 1
	if car: exit_vehicle(true)
	# the body goes limp and falls away from whatever hit it
	var push = Vector3(randf() - 0.5, 0, randf() - 0.5)
	if typeof(last_from) == TYPE_VECTOR3:
		var dv = Vector3(pos.x - last_from.x, 0, pos.z - last_from.z)
		if dv.length() > 0.01: push = dv.normalized() * 2.6
	if not human.is_ragdoll():
		human.ragdoll_start(Vector3(vel.x, 0, vel.z), push + Vector3(0, 0.6, 0), G.rand(-1.5, 1.5))
	else:
		human.ragdoll_start(Vector3(), push * 0.6)
	rag_t = 99
	death_t = 0.0; respawning = false
	aiming = false; aim_t = 0.0
	main.hud.close_menu()
	if main.phone.panel.visible: main.phone.close(true)
	main.sfx.play("boom", 0.6)

# the death screen: the camera stays on your body; after a few seconds any button respawns you
func _death(dt):
	death_t += dt
	if respawning: return
	var want = death_t > 4.0 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("use") or Input.is_action_just_pressed("fire"))
	if want or death_t > 12.0:
		respawning = true
		main.hud.fade_to(1.0, 0.45)
		yield(get_tree().create_timer(0.55), "timeout")
		_hospital()
		main.hud.fade_to(0.0, 0.8)
		respawning = false

func _hospital():
	main.crews.clear(); main.police.clear()
	G.S["health"] = 60; G.S["warmth"] = 75
	var lost = round(G.S["cash"] * 0.2)
	G.S["cash"] -= lost
	G.S["heat"] = max(0, G.S["heat"] - 25)
	if human.is_ragdoll(): human.ragdoll_stop()
	human.getup = 0.0
	rag_t = 0; flopped = false
	place(G.D["LOC"]["hospital"].x, 0, G.D["LOC"]["hospital"].z, PI / 2)
	dead = false; down_t = 0; death_t = 0.0; last_from = null
	main.hud.banner("Calder General", "Hospital bill " + G.fmt_money(lost))
	G.save_game()

# ---------- ragdoll, emotes and snowballs ----------
func is_ragdoll():
	return human != null and human.is_ragdoll()

# knocked off your feet: v is the push, dmg the damage, t how long you stay down
func knock(v, dmg, t = 2.0):
	if car or dead: return
	emote_name = ""
	human.ragdoll_start(Vector3(vel.x, 0, vel.z), v, G.rand(-1.5, 1.5))
	rag_t = max(rag_t, t); flopped = false
	shake = 1.0
	if dmg > 0: hurt(dmg, null, true)

func flop():
	if dead or car: return
	if is_ragdoll():
		if flopped: rag_t = 0.0
		return
	var f = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	human.ragdoll_start(Vector3(vel.x, 0, vel.z), f * 2.5 + Vector3(0, 1.0, 0), G.rand(-1, 1))
	rag_t = 30; flopped = true; emote_name = ""
	G.S["stats"]["emotes"] = int(G.S["stats"].get("emotes", 0)) + 1
	main.sfx.play3d("bodyfall", pos, 0.6)
	main.peds.react_to_emote(pos, "flop")

func _ragdoll_update(dt):
	if not is_ragdoll(): return false
	human.ragdoll_update(dt)
	var c = human.ragdoll_center()
	pos = c; vel = Vector3(); speed = 0; aim_t = 0; aiming = false
	rag_t -= dt
	var still = human.rag != null and human.rag.rest
	var push = Input.get_action_strength("move_f") + Input.get_action_strength("move_b") + Input.get_action_strength("move_l") + Input.get_action_strength("move_r")
	var want_up = flopped and G.MODE == "play" and (Input.is_action_just_pressed("jump") or push > 0.5) and human.rag.t > 0.8
	if not dead and ((rag_t <= 0 and (still or human.rag.t > 6)) or want_up):
		human.ragdoll_stop()
		place(c.x, c.y, c.z)
		body_yaw = human.rotation.y
		rag_t = 0; flopped = false
	return true

func emote(name, dur = 0.0):
	if car or dead or is_ragdoll(): return
	emote_name = name; emote_t = 0.0; emote_dur = dur; clap_t = 0
	G.S["stats"]["emotes"] = int(G.S["stats"].get("emotes", 0)) + 1
	if name in G.DANCES or name == "hype":
		main.peds.react_to_emote(pos, "dance")
		main.gang.dance_along(name)
	elif name == "laugh" or name == "flex" or name == "point":
		main.peds.react_to_emote(pos, name)

func hands_up_for(t):
	hands_up = max(hands_up, t)

func throw_snowball():
	if snow_cd > 0 or dead or car or is_ragdoll(): return
	snow_cd = 0.7; throw_t = 0.45; emote_name = ""
	# aim at whatever the crosshair is on, with an arc
	var cam = main.camera.global_transform
	var f = -cam.basis.z
	var res = shoot_ray(cam.origin, f, 45.0)
	var target = cam.origin + f * (res.t if res.t != INF else 18.0)
	if res.who != null: target = res.who.pos + Vector3(0, 1.3, 0)
	else:
		# a little aim assist: the person closest to the crosshair within a narrow cone
		var best = 0.97
		for list in [main.peds.PEDS, main.crews.ENEMIES, main.police.COPS, main.gang.FOL, main.net.targets()]:
			for e in list:
				if e.is_down() if e.has_method("is_down") else e.state == "down": continue
				var to = e.pos + Vector3(0, 1.3, 0) - cam.origin
				var dl = to.length()
				if dl < 2 or dl > 30: continue
				var c = to.normalized().dot(f)
				if c > best:
					best = c; target = e.pos + Vector3(0, 1.3, 0)
	yield(get_tree().create_timer(0.16), "timeout")
	var from = pos + Vector3(0, 1.75, 0) + Vector3(f.x, 0, f.z).normalized() * 0.4
	var d = target - from
	var t = clamp(d.length() / 18.0, 0.12, 1.6)
	var v = d / t + Vector3(0, 0.5 * 14.0 * t, 0)
	main.fx.throw_snowball(from, v, self)

func use_bandage():
	if G.S.get("bandages", 0) > 0 and G.S["health"] < 100 and heal_t <= 0:
		G.S["bandages"] -= 1; heal_t = 1.6
		main.hud.banner("Bandaged up", "+40 health")

# ---------- cars and doors ----------
func car_press():
	if car:
		if abs(car.speed) > 9:
			main.hud.toast("Slow down first")
			return
		exit_vehicle()
	else:
		var v = main.vehicles.nearest_car(pos, 3.2)
		if v: main.vehicles.enter(v)

func exit_vehicle(force = false):
	if not car: return
	var v = car
	if v.flip_arm:
		v.flip_arm.visible = false; v.flip_k = 0.0
	var l = Vector3(cos(v.yaw), 0, -sin(v.yaw))
	var ex = v.pos + l * (v.sp.wid / 2 + 0.7)
	if W.is_blocked(ex.x, ex.z, 0.3) and not force:
		ex = v.pos - l * (v.sp.wid / 2 + 0.7)
	main.vehicles.leave(v)
	car = null
	place(ex.x, 0, ex.z)
	body_yaw = v.yaw

func use_press():
	if car: return
	var it = nearest_interact()
	if it: main.hud.interact(it)
	else:
		var rp = main.gang.nearest_recruit_ped()
		if rp: main.gang.talk_recruit(rp)

func nearest_interact():
	var best = null
	var bd = INF
	for it in G.D["INTERACT"]:
		if abs(float(it.y) - pos.y) > 1.6: continue
		var d = Vector2(it.x - pos.x, it.z - pos.z).length()
		if d < float(it.r) and d < bd:
			bd = d
			best = it
	return best
