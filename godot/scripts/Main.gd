extends Spatial
# Builds the world and runs every system in the same order as the web game's frame loop.

var player
var vehicles
var peds
var police
var crews
var gang
var sfx
var hud
var phone
var title
var story
var cutscene
var studio
var blok
var train
var fx
var net
var wardrobe
var cockpit
var touch
var memorial
var sky
var eras
var interiors
var console
var camera
var env
var sun
var city
var facade_mats = []
var emis_mats = []
var glow_mats = []
var glow_nodes = []
var lamp_lights = []
var lamps = []
var DN = { "night": 0.0, "lamps": 0.0, "elev": 0.0, "dusk": 0.0, "sun_dir": Vector3(0.3, 0.8, 0.3) }
var autotest = false
var lamp_count = 2
var _save_t = 20.0

var server_mode = false

func _ready():
	G.main = self
	randomize()
	# a dedicated server: no world, no window contents beyond a log (see Server.gd)
	if "--server" in OS.get_cmdline_args():
		server_mode = true
		var srv = load("res://scripts/Server.gd").new()
		srv.name = "Server"
		add_child(srv)
		return
	W.setup(G.D)
	autotest = "--autotest" in OS.get_cmdline_args()
	_build_environment()
	_load_city()
	_build_lamps()
	camera = Camera.new()
	camera.fov = 62; camera.near = 0.08; camera.far = 190
	add_child(camera); camera.current = true
	sfx = _system("res://scripts/Sfx.gd", "Sfx")
	vehicles = _system("res://scripts/Vehicles.gd", "Vehicles")
	player = _system("res://scripts/Player.gd", "Player")
	peds = _system("res://scripts/Peds.gd", "Peds")
	police = _system("res://scripts/Police.gd", "Police")
	crews = _system("res://scripts/Crews.gd", "Crews")
	gang = _system("res://scripts/Gang.gd", "Gang")
	hud = _system("res://scripts/HUD.gd", "HUD")
	phone = _system("res://scripts/Phone.gd", "Phone")
	title = _system("res://scripts/Title.gd", "Title")
	story = _system("res://scripts/Story.gd", "Story")
	cutscene = _system("res://scripts/Cutscene.gd", "Cutscene")
	studio = _system("res://scripts/Studio.gd", "Studio")
	blok = _system("res://scripts/Blok.gd", "Blok")
	train = _system("res://scripts/Train.gd", "Train")
	fx = _system("res://scripts/FX.gd", "FX")
	net = _system("res://scripts/Net.gd", "Net")
	wardrobe = _system("res://scripts/Wardrobe.gd", "Wardrobe")
	cockpit = _system("res://scripts/Cockpit.gd", "Cockpit")
	touch = _system("res://scripts/Touch.gd", "Touch")
	memorial = _system("res://scripts/Memorial.gd", "Memorial")
	sky = _system("res://scripts/Sky.gd", "Sky")
	eras = _system("res://scripts/Eras.gd", "Eras")
	interiors = _system("res://scripts/Interiors.gd", "Interiors")
	console = _system("res://scripts/Console.gd", "Console")
	for s in [sfx, vehicles, player, peds, police, crews, gang, hud, phone, title, story, cutscene, studio, blok, train, fx, net, wardrobe, cockpit, touch, memorial, sky, eras, interiors, console]:
		s.setup(self)
	story.build_npcs()
	eras.build()
	# everything built so far (the garden, the train, props) gets the toon lighting too
	G.toon_tree(self)
	title.open()
	if autotest:
		var t = load("res://scripts/AutoTest.gd").new()
		t.name = "AutoTest"
		add_child(t)
		t.run(self)

func _system(path, nm):
	var n = load(path).new()
	n.name = nm
	add_child(n)
	return n

# ---------- the city, exported from the web build ----------
func _load_city():
	var ps = load("res://assets/world/city.glb")
	if ps == null:
		push_error("assets/world/city.glb missing")
		return
	city = ps.instance()
	add_child(city)
	_prep(city)

const CITY_TEX = { "road": "road", "walk": "walk",
	"facade_brick_0": "facade_brick_0", "facade_brick_1": "facade_brick_1", "facade_brown_0": "facade_brown_0", "facade_brown_1": "facade_brown_1",
	"facade_grey_0": "facade_grey_0", "facade_grey_1": "facade_grey_1", "facade_siding_0": "facade_siding_0", "facade_siding_1": "facade_siding_1",
	"facade_cream_0": "facade_cream_0", "facade_cream_1": "facade_cream_1", "facade_ware_0": "facade_ware_0", "facade_ware_1": "facade_ware_1" }

func _prep(n):
	if n is MeshInstance and n.mesh:
		n.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		for i in range(n.mesh.get_surface_count()):
			var m = n.mesh.surface_get_material(i)
			if m is SpatialMaterial:
				if n.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR:
					m.vertex_color_use_as_albedo = true
					m.vertex_color_is_srgb = true
				var nm = m.resource_name
				if nm == "glowDecal":
					# lamp light pools on the snow: additive, only at night
					m.flags_transparent = true
					m.flags_unshaded = true
					m.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
					m.params_depth_draw_mode = SpatialMaterial.DEPTH_DRAW_DISABLED
					if not m in glow_mats: glow_mats.append(m)
					if not n in glow_nodes:
						glow_nodes.append(n)
						n.translation.y += 0.03
					continue
				if nm.begins_with("facade_") and not m in facade_mats:
					facade_mats.append(m)
				elif (nm == "emis" or m.flags_unshaded) and not m in emis_mats:
					emis_mats.append(m)
				m.metallic = 0.0
				# old-GPU friendly: soft highlights instead of glare off the snow and asphalt
				m.metallic_specular = 0.35 if nm == "ice" else 0.2
				if nm == "ice" and not m.has_meta("toon"):
					# pale, glassy ice rather than a flat blue disc under the cel lighting
					m.albedo_color = m.albedo_color.linear_interpolate(Color(0.88, 0.92, 0.96), 0.45)
				if m.roughness < 0.4 and nm != "ice":
					m.roughness = 0.7
				# repainted textures for the cel-shaded look (tools/make-city.py)
				if CITY_TEX.has(nm):
					var t = load("res://assets/tex/" + CITY_TEX[nm] + ".png")
					if t:
						t.flags = Texture.FLAG_MIPMAPS | Texture.FLAG_FILTER | Texture.FLAG_REPEAT | Texture.FLAG_ANISOTROPIC_FILTER
						m.albedo_texture = t
				G.toon(m)
	for c in n.get_children():
		_prep(c)

func _build_environment():
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.64, 0.71, 0.8)
	env.ambient_light_color = Color(0.8, 0.86, 0.96)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_color = Color(0.64, 0.71, 0.8)
	env.fog_depth_enabled = true
	env.fog_depth_begin = 20
	env.fog_depth_end = 180
	env.fog_height_enabled = false
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight.new()
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 60
	add_child(sun)

# street lamps: a few real lights move to the lamps nearest you (old GPUs can't afford hundreds)
func _build_lamps():
	for l in G.D["LAMPS"]:
		lamps.append(Vector3(l[0], l[1], l[2]))
	for _i in range(4):
		var o = OmniLight.new()
		o.omni_range = 16
		o.light_color = Color(1.0, 0.78, 0.5)
		o.light_energy = 0
		o.visible = false          # an idle light still costs a render pass in GLES2
		o.shadow_enabled = false
		add_child(o)
		lamp_lights.append(o)

# low: no real lamp lights (the light pools on the snow still show), for Iron Lake-class GPUs
func set_quality(q):
	sun.shadow_enabled = q == "high"
	lamp_count = 4 if q == "high" else (2 if q == "medium" else 0)
	camera.far = 240 if q == "high" else (190 if q == "medium" else 160)
	if fx: fx.set_quality(q)
	if sky: sky.set_quality(q)

# ---------- day and night on the shared clock (same curve as the web game) ----------
func _smooth(a, b, x):
	var t = clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)

func sun_angles(m):
	var hr = m / 60.0
	var rise = 7.1
	var sset = 16.6
	if hr >= rise and hr <= sset:
		var k = (hr - rise) / (sset - rise)
		return [sin(k * PI) * 27, 118 + k * 124]
	var span = 24 - sset + rise
	var k2 = ((hr - sset) if hr > sset else (hr + 24 - sset)) / span
	return [-sin(k2 * PI) * 42, 242 + k2 * 236]

func _dir(elev, az):
	var e = deg2rad(elev)
	var a = deg2rad(az)
	return Vector3(cos(e) * sin(a), sin(e), -cos(e) * cos(a))

func update_day_night(focus):
	var sa = sun_angles(G.world_minutes())
	var elev = sa[0]
	var az = sa[1]
	var n = _smooth(4, -8, elev)
	DN.elev = elev; DN.night = n; DN.lamps = _smooth(7, -1, elev); DN.dusk = clamp(1 - abs(elev - 1) / 12, 0, 1)
	DN.sun_dir = _dir(elev, az)
	var use_moon = elev < -3
	var ld = _dir(max(18, -elev * 0.9), az + 180) if use_moon else DN.sun_dir
	var day = _smooth(-3, 10, elev)
	sun.light_energy = 0.32 * n if use_moon else 1.05 * day
	if use_moon:
		sun.light_color = Color(0.62, 0.72, 0.95)
	else:
		sun.light_color = Color(1.0, 0.56, 0.32).linear_interpolate(Color(1.0, 0.95, 0.9), _smooth(2, 22, elev))
	sun.look_at_from_position(focus + ld * 100, focus, Vector3.UP if abs(ld.y) < 0.99 else Vector3(1, 0, 0))
	var fog = Color(0.64, 0.71, 0.8).linear_interpolate(Color(0.62, 0.52, 0.6), DN.dusk * 0.6).linear_interpolate(Color(0.035, 0.045, 0.085), n)
	env.background_color = fog
	env.fog_color = fog
	env.fog_depth_end = lerp(190, 95, n)
	env.fog_depth_begin = lerp(25, 8, n)
	env.ambient_light_color = Color(lerp(0.80, 0.36, n), lerp(0.86, 0.46, n), lerp(0.96, 0.68, n))
	env.ambient_light_energy = lerp(0.85, 0.55, n)
	for m in facade_mats:
		m.emission_energy = lerp(0.03, 1.15, n)
	var ek = lerp(0.32, 1.0, DN.lamps)
	for m in emis_mats:
		m.albedo_color = Color(ek, ek, ek)
	var ga = 0.55 * DN.lamps
	for m in glow_mats:
		m.albedo_color = Color(1.0, 0.54, 0.2, ga)
	for g in glow_nodes:
		g.visible = ga > 0.01
	# move the few real lamp lights to the lamps nearest the player
	if DN.lamps > 0.02:
		var best = []
		for l in lamps:
			var d = Vector2(l.x - focus.x, l.z - focus.z).length()
			if d < 45:
				best.append([d, l])
		best.sort_custom(self, "_by_first")
		for i in range(lamp_lights.size()):
			var o = lamp_lights[i]
			if i < best.size() and i < lamp_count:
				o.translation = best[i][1] - Vector3(0, 0.4, 0)
				o.light_energy = 1.4 * DN.lamps
				o.visible = true
			else:
				o.light_energy = 0
				o.visible = false
	else:
		for o in lamp_lights:
			o.light_energy = 0
			o.visible = false
	if sky: sky.frame()
	if interiors: interiors.light_inside(env, sun)

func _by_first(a, b):
	return a[0] < b[0]

# ---------- the frame ----------
func _process(dt):
	if server_mode: return
	dt = min(dt, 0.05)
	G.REAL_T += dt
	G.cam_pos = camera.global_transform.origin
	if G.MODE == "title":
		title.update(dt)
		vehicles.update(dt)
		peds.update(dt)
		story.update(dt)
		eras.update(dt)
		train.update(dt)
		fx.update(dt)
		memorial.update(dt)
		update_day_night(camera.global_transform.origin)
		net.update(dt)
		return
	if G.MODE != "pause":
		G.GAME_T += dt
		G.S["playTime"] = G.S.get("playTime", 0) + dt
	var live = G.MODE == "play" or G.MODE == "phone" or G.MODE == "cutscene"
	if live:
		player.update(dt)
		vehicles.update(dt)
		peds.update(dt)
		gang.update(dt)
		crews.update(dt)
		police.update(dt)
		if G.MODE != "cutscene": player.update_camera(dt)
	cutscene.update(dt)
	story.update(dt)
	eras.update(dt)
	train.update(dt)
	fx.update(dt)
	interiors.update(dt)
	blok.update(dt)
	studio.update(dt)
	wardrobe.update(dt)
	touch.update(dt)
	memorial.update(dt)
	net.update(dt)
	update_day_night(player.pos)
	sfx.update(dt)
	hud.update(dt)
	phone.update(dt)
	_save_t -= dt
	if _save_t <= 0:
		_save_t = 20
		G.save_game()

func start_game(state):
	G.S = G.migrate(state)
	G.MODE = "play"
	set_quality(G.S["settings"].get("quality", "low"))
	player.spawn()
	vehicles.spawn_owned_car()
	gang.sync_followers()
	hud.show()
	story.last_min = -1
	if not G.S["flags"].get("introSeen", false) and not autotest:
		G.S["flags"]["introSeen"] = true
		cutscene.play(cutscene.cut_intro(), wardrobe, "open", [true])
	else:
		hud.banner("@" + G.S["name"], "Calder Park · Day " + str(G.S.get("day", 1)))
	G.save_game()

func exit_to_title():
	G.save_game()
	cutscene.end(); studio.close_all(); wardrobe.close()
	if player.car:
		player.exit_vehicle(true)
	crews.clear()
	police.clear()
	gang.clear()
	hud.hide()
	G.MODE = "title"
	title.open()

func _notification(what):
	if server_mode: return
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		G.save_game()
	elif what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == MainLoop.NOTIFICATION_APP_PAUSED or what == MainLoop.NOTIFICATION_WM_FOCUS_OUT:
		if G.MODE != "title": G.save_game()

# Android's back button: close whatever is open, otherwise open the phone
func _back():
	if cutscene.on: cutscene.end()
	elif wardrobe.root.visible: wardrobe.cancel()
	elif studio.root.visible:
		if studio.bench: studio.close_bench()
		else: studio._abort()
	elif hud.menu_box: hud.close_menu()
	elif phone.panel.visible:
		if phone.app != "": phone._home()
		else: phone.close()
	elif G.MODE == "play": phone.open()
	elif G.MODE == "title": get_tree().quit()
