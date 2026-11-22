extends Node
# Global state shared by every system (autoload "G"): the map data exported from the
# web build, the save (same shape as the web game's, so progress moves between them),
# settings, input bindings and the shared world clock.

const SAVE_PATH = "user://save.json"
const WEB_SAVE_NAME = "drill-season-save.json"

var D = {}              # assets/data.json
var S = {}              # the current save
var MODE = "title"      # title, play, phone, pause, menu
var REAL_T = 0.0
var GAME_T = 0.0
var time_offset = 0.0
var rng = RandomNumberGenerator.new()
var main = null
var font_s = null
var font_m = null
var font_l = null
var font_xl = null
var font_xs = null
var font_cash = null     # HUD numbers: heavy with a dark outline, readable on snow
var font_big = null      # big centre messages
var font_hud = null      # HUD labels with an outline
var _unix0 = 0
var _ticks0 = 0
var _mats = {}

func _ready():
	rng.randomize()
	pause_mode = Node.PAUSE_MODE_PROCESS
	_unix0 = OS.get_unix_time()
	_ticks0 = OS.get_ticks_msec()
	var f = File.new()
	if f.open("res://assets/data.json", File.READ) == OK:
		D = parse_json(f.get_as_text())
		f.close()
		# glyphs the bundled font lacks
		if D.has("RTYPES") and D["RTYPES"].has("brawler"):
			D["RTYPES"]["brawler"]["icon"] = "◆"
		# beards: a style instead of on/off (1 = full beard, as before)
		if D.has("SKIN"):
			for fld in D["SKIN"]["SKIN_FIELDS"]:
				if fld[0] == "beard":
					fld[1] = "n"
					if fld.size() < 4:
						fld.append(0)
						fld.append(0)
					fld[2] = 0; fld[3] = 5
	else:
		push_error("assets/data.json is missing; run tools/export-godot.js")
	# the whole interface uses Inter now (slim, like the wardrobe and the phone)
	font_s = ifont(14, "r")
	font_m = ifont(17, "s")
	font_l = ifont(25, "s")
	font_xl = ifont(60, "l")
	font_xs = ifont(12, "m")
	font_cash = ifont_o(28, "m", 1)
	font_big = ifont(54, "l")
	font_hud = ifont_o(16, "s", 1)
	_setup_input()
	S = new_state("")

# Inter, for the phone and the wardrobe (thin, modern); DejaVu fills in symbols Inter lacks.
# w: "l" light, "r" regular, "m" medium, "s" semibold, "b" bold
var _ifonts = {}
func ifont(size, w = "r"):
	var k = w + str(size)
	if _ifonts.has(k): return _ifonts[k]
	var names = { "l": "Light", "r": "Regular", "m": "Medium", "s": "SemiBold", "b": "Bold" }
	var f = DynamicFont.new()
	f.font_data = load("res://fonts/Inter-%s.ttf" % names.get(w, "Regular"))
	f.size = size
	f.use_filter = true
	f.add_fallback(load("res://fonts/DejaVuSans-Bold.ttf" if w in ["s", "b"] else "res://fonts/DejaVuSans.ttf"))
	_ifonts[k] = f
	return f

# an Inter font with a soft dark outline, for text over the 3D world
func ifont_o(size, w, outline):
	var k = "o%d%s%d" % [outline, w, size]
	if _ifonts.has(k): return _ifonts[k]
	var f = ifont(size, w).duplicate()
	f.outline_size = outline; f.outline_color = Color(0, 0, 0, 0.55)
	_ifonts[k] = f
	return f

# letter-spaced small caps for eyebrows and labels
func ifont_sp(size, w, spacing):
	var k = "sp%d%s%d" % [spacing, w, size]
	if _ifonts.has(k): return _ifonts[k]
	var f = ifont(size, w).duplicate()
	f.extra_spacing_char = spacing
	_ifonts[k] = f
	return f

func _font(size, bold, outline = 0):
	var f = DynamicFont.new()
	f.font_data = load("res://fonts/DejaVuSans-Bold.ttf" if bold else "res://fonts/DejaVuSans.ttf")
	f.size = size
	f.use_filter = true
	if outline > 0:
		f.outline_size = outline; f.outline_color = Color(0, 0, 0, 0.85)
	return f

# ---------- one clock for everyone, the same as the web game: 1 real second = 1 game minute ----------
func world_seconds():
	return _unix0 + (OS.get_ticks_msec() - _ticks0) / 1000.0 + time_offset
func world_minutes():
	return fposmod(world_seconds(), 1440.0)
func clock_str():
	var m = int(world_minutes())
	var h = int(m / 60) % 24
	var ap = "AM" if h < 12 else "PM"
	var h12 = h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m % 60, ap]

# ---------- small helpers ----------
func pick(a):
	return a[rng.randi_range(0, a.size() - 1)]
func rand(a, b):
	return rng.randf_range(a, b)
func ang_diff(a, b):
	return fposmod(b - a + PI, TAU) - PI
func hex_color(v):
	var i = int(v)
	return Color8((i >> 16) & 255, (i >> 8) & 255, i & 255)
func fmt_money(v):
	var n = int(round(v))
	var s = str(abs(n))
	var out = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if n < 0 else "$") + s + out
# a shared, cached material per colour: vertex colours on, so merged meshes keep their parts
func mat(color, unshaded = false):
	var key = str(color) + ("u" if unshaded else "")
	if _mats.has(key):
		return _mats[key]
	var m = SpatialMaterial.new()
	m.albedo_color = color
	m.flags_unshaded = unshaded
	m.roughness = 0.85
	toon(m, true)
	_mats[key] = m
	return m
var _vcmat = null
func vc_mat():
	if _vcmat == null:
		_vcmat = SpatialMaterial.new()
		_vcmat.vertex_color_use_as_albedo = true
		_vcmat.roughness = 0.85
		toon(_vcmat, true)
		# a soft rim of light around characters, part of the cel look
		_vcmat.rim_enabled = true; _vcmat.rim = 0.22; _vcmat.rim_tint = 0.35
	return _vcmat

# ---------- the cel-shaded look ----------
# Every lit material gets toon lighting: a crisp step from light to shade instead of a smooth
# fall-off, and highlights only on glossy things (car paint, metal). Characters, cars, guns and
# your hands also get an ink outline (scripts/outline.shader), which can be switched off in
# Settings for slow GPUs.
var _outline = null
var _inked = []
func outline_mat():
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = load("res://scripts/outline.shader")
	return _outline

func outlines_on():
	return bool(S.get("settings", {}).get("outlines", true)) if typeof(S) == TYPE_DICTIONARY else true

func toon(m, ink = false):
	if not (m is SpatialMaterial) or m.flags_unshaded or m.flags_transparent:
		return m
	if not m.has_meta("toon"):
		m.set_meta("toon", true)
		var glossy = m.metallic > 0.3 or m.roughness < 0.45
		m.params_diffuse_mode = SpatialMaterial.DIFFUSE_TOON
		m.params_specular_mode = SpatialMaterial.SPECULAR_TOON if glossy else SpatialMaterial.SPECULAR_DISABLED
		m.roughness = 0.3 if glossy else 0.16
	if ink and not m.has_meta("ink"):
		m.set_meta("ink", true)
		_inked.append(weakref(m))
		if outlines_on(): m.next_pass = outline_mat()
	return m

func toon_tree(n, ink = false):
	if n is GeometryInstance:
		if n.material_override: toon(n.material_override, ink)
		if n is MeshInstance and n.mesh:
			for i in range(n.mesh.get_surface_count()):
				var m = n.get_surface_material(i)
				if m == null: m = n.mesh.surface_get_material(i)
				if m: toon(m, ink)
	for c in n.get_children():
		toon_tree(c, ink)

func apply_outlines():
	var on = outlines_on()
	var keep = []
	for w in _inked:
		var m = w.get_ref()
		if m == null: continue
		keep.append(w)
		m.next_pass = outline_mat() if on else null
	_inked = keep

# ---------- the save ----------
func default_skin():
	return { "tone": 4, "hair": "short", "hairCol": 0x0f0d0c, "beard": 0, "head": "beanie", "headCol": 0xff8a2a, "pom": 1, "top": "puffer", "topCol": 0x262b33, "top2": 0x343a44, "pants": "jeans", "pantsCol": 0x1b2533, "pants2": 0xe8e8ea, "shoes": "sneaker", "shoesCol": 0xdedede, "chain": 0, "watch": 0, "glasses": 0, "bag": "none", "bagCol": 0x15171a, "build": 1 }

func new_state(name):
	var dc = D.get("DEF_CFG", { "optic": "iron", "barrel": "standard", "mag": "std", "muzzle": "none", "finish": "gunmetal", "charm": "none" })
	var dp = ["optic:iron", "barrel:standard", "mag:std", "muzzle:none"]
	return {
		"v": 1, "name": name if name != "" else "Unknown", "cash": 150, "buzz": 4, "heat": 0, "health": 100, "warmth": 100, "bandages": 1,
		"night": 1, "clock": 21 * 60 + 30, "playTime": 0, "pos": null, "cur": "k9", "fists": false,
		"guns": {
			"k9": { "owned": true, "mag": 12, "res": 36, "cfg": dc.duplicate() },
			"draft": { "owned": false, "mag": 30, "res": 60, "cfg": dc.duplicate() },
			"plow": { "owned": false, "mag": 6, "res": 12, "cfg": dc.duplicate() },
		},
		"parts": { "k9": dp.duplicate(), "draft": dp.duplicate(), "plow": dp.duplicate() },
		"cos": ["finish:gunmetal", "charm:none"],
		"threads": { "benny": [], "kiara": [], "coach": [], "vance": [], "saint": [], "reyes": [] },
		"unread": { "benny": 0, "kiara": 0, "coach": 0, "vance": 0, "saint": 0, "reyes": 0 },
		"feed": [], "tracks": [], "flags": {}, "gang": null, "recruits": [], "cd": {}, "endings": {}, "tracked": null,
		"buffs": { "coffee": 0, "warmers": 0 }, "job": null,
		"stats": { "tracks": 0, "best": null, "buzzPeak": 4, "heatPeak": 0, "walkAways": 0, "fights": 0, "downs": 0, "cashEarned": 0, "rides": 0, "shots": 0,
			"coldTime": 0, "dist": 0, "disses": 0, "timesDowned": 0, "merch": 0, "videos": 0, "layLows": 0, "pvpDowns": 0, "busted": 0, "carsTaken": 0, "drive": 0, "photos": 0,
			"punches": 0, "knockouts": 0, "emotes": 0, "snowballs": 0 },
		"skin": default_skin(),
		"settings": { "sens": 1.0, "vol": 0.8, "music": 0.85, "invertY": false, "quality": "low", "radio": 1, "score": true, "voices": true, "fp": false, "fov": 70, "pad": { "sens": 1.0, "invertY": false } },
		"garage": [{ "model": "hatch", "color": 0x2a6a8a }],
		"social": { "followers": 214, "following": 96, "bio": "drill · Calder Park · Chicago", "posts": [] },
		"day": 1,
	}

func deep_merge(base, o):
	for k in o.keys():
		var v = o[k]
		if typeof(v) == TYPE_DICTIONARY and base.has(k) and typeof(base[k]) == TYPE_DICTIONARY:
			deep_merge(base[k], v)
		else:
			base[k] = v
	return base

func has_save():
	return File.new().file_exists(SAVE_PATH)

func load_save():
	var f = File.new()
	if f.open(SAVE_PATH, File.READ) != OK:
		return null
	var o = parse_json(f.get_as_text())
	f.close()
	if typeof(o) != TYPE_DICTIONARY or not o.has("name"):
		return null
	return deep_merge(new_state(o["name"]), o)

func save_game():
	if MODE == "title" or S.get("name", "") == "":
		return
	if main and main.player:
		var p = main.player.pos
		S["pos"] = { "x": p.x, "y": p.y, "z": p.z, "yaw": main.player.cam_yaw }
	var f = File.new()
	if f.open(SAVE_PATH, File.WRITE) == OK:
		f.store_string(to_json(S))
		f.close()

# progress from the web game: its Settings app saves drill-season-save.json (usually to Downloads)
func web_save_paths():
	var out = []
	var dl = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if dl != "":
		out.append(dl.plus_file(WEB_SAVE_NAME))
	var home = OS.get_environment("HOME")
	if home != "":
		for d in ["Downloads", "Transferências", "Descargas"]:
			out.append(home.plus_file(d).plus_file(WEB_SAVE_NAME))
		out.append(home.plus_file(WEB_SAVE_NAME))
	if not OS.has_feature("editor"):
		out.append(OS.get_executable_path().get_base_dir().plus_file(WEB_SAVE_NAME))
	out.append("user://" + WEB_SAVE_NAME)
	return out

func find_web_save():
	var f = File.new()
	for p in web_save_paths():
		if f.file_exists(p):
			return p
	return ""

func import_web_save():
	var p = find_web_save()
	if p == "":
		return "No %s found. In the web game, open the phone, then Settings, then Export my progress." % WEB_SAVE_NAME
	var f = File.new()
	if f.open(p, File.READ) != OK:
		return "Could not read " + p
	var o = parse_json(f.get_as_text())
	f.close()
	if typeof(o) != TYPE_DICTIONARY or not o.has("name"):
		return "That file is not a Drill Season save."
	# keep what the web save has; anything the Godot version needs gets a default
	var st = deep_merge(new_state(o["name"]), o)
	# graphics settings from a browser say nothing about this PC: start on the fast preset
	st["settings"]["quality"] = "low"
	S = st
	MODE = "play"
	save_game()
	MODE = "title"
	return ""

# ---------- controls: keyboard, mouse and any gamepad (Godot reads controllers directly) ----------
func _key(action, sc):
	var e = InputEventKey.new()
	e.scancode = sc
	InputMap.action_add_event(action, e)
func _mouse(action, b):
	var e = InputEventMouseButton.new()
	e.button_index = b
	InputMap.action_add_event(action, e)
func _pad(action, b):
	var e = InputEventJoypadButton.new()
	e.button_index = b
	InputMap.action_add_event(action, e)
func _axis(action, ax, v):
	var e = InputEventJoypadMotion.new()
	e.axis = ax
	e.axis_value = v
	InputMap.action_add_event(action, e)
func _act(name, dz = 0.25):
	if not InputMap.has_action(name):
		InputMap.add_action(name, dz)

func _setup_input():
	var A = {
		"move_f": [[KEY_W], [], [[JOY_AXIS_1, -1]]], "move_b": [[KEY_S], [], [[JOY_AXIS_1, 1]]],
		"move_l": [[KEY_A], [], [[JOY_AXIS_0, -1]]], "move_r": [[KEY_D], [], [[JOY_AXIS_0, 1]]],
		"look_l": [[KEY_LEFT], [], [[JOY_AXIS_2, -1]]], "look_r": [[KEY_RIGHT], [], [[JOY_AXIS_2, 1]]],
		"look_u": [[KEY_UP], [], [[JOY_AXIS_3, -1]]], "look_d": [[KEY_DOWN], [], [[JOY_AXIS_3, 1]]],
		"fire": [[], [BUTTON_LEFT], [[JOY_AXIS_7, 1]], [JOY_R2]], "aim": [[], [BUTTON_RIGHT], [[JOY_AXIS_6, 1]], [JOY_L2]],
		"jump": [[KEY_SPACE], [], [], [JOY_XBOX_A]], "crouch": [[KEY_C], [], [], [JOY_XBOX_B]],
		"reload": [[KEY_R], [], [], [JOY_XBOX_X]], "car": [[KEY_F], [], [], [JOY_XBOX_Y]],
		"use": [[KEY_E], [], [], [JOY_R]], "next_weapon": [[KEY_Q], [], [], [JOY_L]],
		"sprint": [[KEY_SHIFT], [], [], [JOY_L3]], "camera": [[KEY_V], [], [], [JOY_R3]],
		"phone": [[KEY_TAB, KEY_P], [], [], [JOY_DPAD_UP]], "bandage": [[KEY_B], [], [], [JOY_DPAD_DOWN]],
		"wave": [[KEY_G], [], [], []], "flip": [[KEY_T], [], [], [JOY_DPAD_RIGHT]],
		"emote": [[KEY_Z], [], [], [JOY_DPAD_LEFT]], "flop": [[KEY_J], [], [], []], "snowball": [[KEY_X], [], [], []],
		"horn": [[KEY_H], [], [], []], "pause": [[KEY_ESCAPE], [], [], [JOY_START]],
		"gun1": [[KEY_1], [], [], []], "gun2": [[KEY_2], [], [], []], "gun3": [[KEY_3], [], [], []], "fists": [[KEY_4], [], [], []],
		"map": [[KEY_M], [], [], [JOY_SELECT]],
	}
	for name in A.keys():
		_act(name, 0.3)
		var a = A[name]
		for sc in a[0]:
			_key(name, sc)
		for b in a[1]:
			_mouse(name, b)
		for ax in a[2]:
			_axis(name, ax[0], ax[1])
		if a.size() > 3:
			for b in a[3]:
				_pad(name, b)
	# menus: ui_* actions already include the arrows, Enter, Escape and the pad's A/B/D-pad

# ---------- looks (the same skin format as the web wardrobe) ----------
func clean_skin(s):
	var d = default_skin()
	if typeof(s) == TYPE_DICTIONARY:
		for k in s.keys():
			d[k] = s[k]
	return d

func skin_opts(s):
	s = clean_skin(s)
	var tones = D["SKIN"]["SKIN_TONES"]
	return {
		"skin": tones[clamp(int(s.tone), 0, tones.size() - 1)], "hair": s.hair, "hairCol": s.hairCol, "beard": s.beard, "head": s.head, "hat": s.headCol, "pom": s.pom,
		"top": s.top, "jacket": s.topCol, "jacket2": s.top2, "pantsStyle": s.pants, "pants": s.pantsCol, "pants2": s.pants2, "shoe": s.shoes, "shoes": s.shoesCol,
		"chain": bool(s.chain), "watch": bool(s.watch), "glasses": bool(s.glasses), "bag": null if s.bag == "none" else s.bag, "bagCol": s.bagCol, "build": s.build,
	}

func random_skin(r = null):
	if r == null:
		r = rng
	var O = D["SKIN"]["SKIN_OPTS"]
	var muted = [0x15171a, 0x262b33, 0x3a3f46, 0x8a9098, 0x1e2f4a, 0x2a3a2a, 0x4a3a2a, 0x5a1a1a, 0x6b4a30, 0xc8a878, 0xe8e8ea]
	var pop = [0xc8202a, 0xff8a2a, 0xffc832, 0x2a5aa8, 0x6ab0ff, 0x4f8a3a, 0xff6ab0, 0x5a2a6a]
	var hc = D["SKIN"]["HAIR_COLS"]
	return clean_skin({
		"tone": r.randi_range(0, 5), "hair": _rp(r, O.hair), "hairCol": _rp(r, hc.slice(0, 3)) if r.randf() < 0.8 else _rp(r, hc), "beard": (r.randi_range(1, 5) if r.randf() < 0.5 else 1) if r.randf() < 0.35 else 0,
		"head": _rp(r, ["none", "beanie", "beanie", "cap", "hood", "bucket", "durag", "headphones", "beanie"]), "headCol": _col(r, muted, pop), "pom": 1 if r.randf() < 0.4 else 0,
		"top": _rp(r, ["puffer", "puffer", "parka", "parka", "hoodie", "track", "leather", "varsity"]), "topCol": _col(r, muted, pop), "top2": _col(r, muted, pop),
		"pants": _rp(r, ["jeans", "jeans", "cargo", "joggers", "ski"]), "pantsCol": _rp(r, muted), "pants2": 0xe8e8ea,
		"shoes": _rp(r, O.shoes), "shoesCol": _rp(r, [0xe8e8ea, 0x15171a, 0x6b4a30, 0x3a3f46]), "chain": 1 if r.randf() < 0.1 else 0, "watch": 1 if r.randf() < 0.15 else 0,
		"glasses": 1 if r.randf() < 0.08 else 0, "bag": _rp(r, ["none", "none", "none", "back", "cross"]), "bagCol": _rp(r, muted), "build": r.randi_range(0, 2),
	})
func _rp(r, a):
	return a[r.randi_range(0, a.size() - 1)]
func _col(r, muted, pop):
	return _rp(r, muted) if r.randf() < 0.75 else _rp(r, pop)

func preset_skin(i):
	var p = D["SKIN"]["PRESETS"][i % D["SKIN"]["PRESETS"].size()]
	var s = default_skin()
	for k in p[1].keys():
		s[k] = p[1][k]
	return s

func seeded_rng(seed_v):
	var r = RandomNumberGenerator.new()
	r.seed = int(seed_v)
	return r
