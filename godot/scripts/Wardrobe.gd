extends Node
# The character creator, minimal: the character stands in a soft spotlight on the right; on the
# left, a slim list of sections and thin rows (a small label over the value, ‹ › to change),
# small colour dots, and a white Save pill. Turn the character by dragging or with Q / E.
# Mouse, touch, keyboard (arrows) and controller (D-pad / stick, A, B, LB / RB) all work.

var main
var layer
var root
var vp
var preview = null
var holder
var edit = {}
var before = {}
var cat = 1
var rows = []
var list
var cat_box
var title_l
var rot = 0.4
var drag = false
var from_new = false
var focus_row = 0

const DIM = Color(0.56, 0.56, 0.6)
const LINE = Color(1, 1, 1, 0.08)
const ACC = Color(1, 0.62, 0.22)

const CATS = [
	["Presets", []],
	["Heritage", ["tone", "build"]],
	["Hair", ["hair", "hairCol", "beard"]],
	["Headwear", ["head", "headCol", "pom"]],
	["Top", ["top", "topCol", "top2"]],
	["Bottoms", ["pants", "pantsCol", "pants2"]],
	["Shoes", ["shoes", "shoesCol"]],
	["Extras", ["chain", "watch", "glasses", "bag", "bagCol"]],
]
const NAMES = { "tone": "Skin tone", "build": "Build", "hair": "Hair", "hairCol": "Hair colour", "beard": "Beard", "head": "Headwear", "headCol": "Headwear colour", "pom": "Pom-pom",
	"top": "Top", "topCol": "Main colour", "top2": "Trim colour", "pants": "Bottoms", "pantsCol": "Colour", "pants2": "Stripe colour", "shoes": "Shoes", "shoesCol": "Colour",
	"chain": "Chain", "watch": "Watch", "glasses": "Glasses", "bag": "Bag", "bagCol": "Bag colour" }
const BUILDS = ["Slim", "Regular", "Big"]

class Row extends Button:
	var wd
	var key
	func _gui_input(e):
		if e.is_action_pressed("ui_left"):
			wd.step(key, -1); accept_event()
		elif e.is_action_pressed("ui_right"):
			wd.step(key, 1); accept_event()

class Chev extends Control:
	var dir = 1
	var col = Color(1, 1, 1, 0.55)
	func _draw():
		var c = rect_size / 2
		var w = rect_size.x * 0.25
		var h = rect_size.y * 0.32
		draw_polyline(PoolVector2Array([c + Vector2(-dir * w, -h), c + Vector2(dir * w, 0), c + Vector2(-dir * w, h)]), col, 1.6, true)

func _sb(col, r, ml = 0, mt = 0):
	var sb = StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(r); sb.anti_aliasing = true
	sb.content_margin_left = ml; sb.content_margin_right = ml; sb.content_margin_top = mt; sb.content_margin_bottom = mt
	return sb

func _text(parent, t, font, col, pos = null):
	var l = Label.new(); l.text = t; l.add_font_override("font", font); l.add_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pos != null: l.rect_position = pos
	parent.add_child(l)
	return l

func setup(m):
	main = m
	layer = CanvasLayer.new(); layer.layer = 7; add_child(layer)
	root = Control.new(); root.anchor_right = 1; root.anchor_bottom = 1; root.visible = false
	layer.add_child(root)
	# backdrop: a soft spotlight on dark grey
	var bg = TextureRect.new(); bg.anchor_right = 1; bg.anchor_bottom = 1; bg.expand = true; bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture = load("res://assets/ui/wardrobe_bg.png")
	root.add_child(bg)
	# the 3D preview fills the right side
	var vc = ViewportContainer.new(); vc.stretch = true; vc.anchor_left = 0.3; vc.anchor_right = 1; vc.anchor_bottom = 1
	vc.connect("gui_input", self, "_preview_input")
	root.add_child(vc)
	vp = Viewport.new(); vp.own_world = true; vp.transparent_bg = true; vp.msaa = Viewport.MSAA_DISABLED; vp.size = Vector2(896, 720)
	vc.add_child(vp)
	var cam = Camera.new(); cam.fov = 30; cam.translation = Vector3(0, 1.05, 5.4); vp.add_child(cam); cam.look_at(Vector3(0, 0.92, 0), Vector3.UP); cam.current = true
	# soft enough for the cel lighting (each light adds a full band): a warm key, a cool fill, a rim
	for L in [[Vector3(2, 3, 3), Color(1, 0.95, 0.88), 0.62], [Vector3(-3, 1.5, 2), Color(0.72, 0.8, 1), 0.2], [Vector3(0, 2.5, -3), Color(1, 1, 1), 0.42]]:
		var dl = DirectionalLight.new(); dl.light_color = L[1]; dl.light_energy = L[2]; vp.add_child(dl); dl.look_at_from_position(L[0], Vector3(0, 1, 0), Vector3.UP)
	var env = Environment.new(); env.background_mode = Environment.BG_CLEAR_COLOR; env.ambient_light_color = Color(0.5, 0.52, 0.58); env.ambient_light_energy = 0.42
	var we = WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	# a soft round shadow on the floor instead of a stage
	var fl = MeshInstance.new(); var qm = QuadMesh.new(); qm.size = Vector2(1.9, 1.9); fl.mesh = qm
	var fm = SpatialMaterial.new(); fm.flags_unshaded = true; fm.flags_transparent = true; fm.albedo_texture = load("res://assets/ui/floor_shadow.png")
	fm.albedo_color = Color(0, 0, 0, 0.9); fl.material_override = fm
	fl.rotation_degrees = Vector3(-90, 0, 0); fl.translation.y = 0.004
	vp.add_child(fl)
	holder = Spatial.new(); vp.add_child(holder)
	# left: eyebrow, name, sections, rows
	var ui = Control.new(); ui.anchor_bottom = 1; ui.margin_left = 0; ui.margin_right = 560; ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ui)
	var eyebrow = G.ifont(11, "m").duplicate(); eyebrow.extra_spacing_char = 3
	_text(ui, "WARDROBE", eyebrow, DIM, Vector2(56, 52))
	title_l = _text(ui, "CHARACTER", G.ifont(34, "l"), Color(1, 1, 1), Vector2(54, 70))
	cat_box = VBoxContainer.new(); cat_box.rect_position = Vector2(56, 152); cat_box.rect_size = Vector2(130, 300); cat_box.add_constant_override("separation", 2)
	ui.add_child(cat_box)
	var sc = ScrollContainer.new(); sc.rect_position = Vector2(206, 146); sc.rect_size = Vector2(330, 0); sc.scroll_horizontal_enabled = false
	sc.anchor_bottom = 1; sc.margin_bottom = -118
	var sbg = StyleBoxEmpty.new(); sbg.content_margin_left = 1; sbg.content_margin_right = 1
	var vs = sc.get_v_scrollbar()
	vs.add_stylebox_override("scroll", sbg); vs.add_stylebox_override("scroll_focus", sbg)
	var gr = _sb(Color(1, 1, 1, 0.18), 2); gr.content_margin_left = 1; gr.content_margin_right = 1
	vs.add_stylebox_override("grabber", gr); vs.add_stylebox_override("grabber_highlight", gr); vs.add_stylebox_override("grabber_pressed", gr)
	ui.add_child(sc)
	list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_constant_override("separation", 0); sc.add_child(list)
	# bottom: Save (a white pill), Cancel, Randomize, and a one-line hint
	var foot = HBoxContainer.new(); foot.anchor_top = 1; foot.anchor_bottom = 1; foot.margin_left = 56; foot.margin_top = -98; foot.margin_bottom = -58; foot.margin_right = 520
	foot.add_constant_override("separation", 22)
	ui.add_child(foot)
	for b in [["Save", "save"], ["Cancel", "cancel"], ["Randomize", "randomize"]]:
		var bt = Button.new(); bt.text = b[0]; bt.connect("pressed", self, b[1]); foot.add_child(bt)
		_style_btn(bt, b[1] == "save")
	var hint = _text(ui, "‹ › change   ·   Q E or drag to turn   ·   Tab section   ·   Enter save   ·   Esc cancel", G.ifont(11, "r"), Color(1, 1, 1, 0.32))
	hint.anchor_top = 1; hint.anchor_bottom = 1; hint.margin_left = 56; hint.margin_top = -40; hint.margin_bottom = -24

func _style_btn(b, primary):
	b.focus_mode = Control.FOCUS_ALL
	if primary:
		b.rect_min_size = Vector2(118, 40)
		b.add_stylebox_override("normal", _sb(Color(1, 1, 1), 20, 22, 8))
		b.add_stylebox_override("hover", _sb(Color(0.88, 0.88, 0.9), 20, 22, 8))
		b.add_stylebox_override("pressed", _sb(Color(0.78, 0.78, 0.8), 20, 22, 8))
		var f = _sb(Color(1, 1, 1), 20, 22, 8); f.border_color = ACC; f.set_border_width_all(2)
		b.add_stylebox_override("focus", f)
		b.add_font_override("font", G.ifont(14, "s"))
		for c in ["font_color", "font_color_hover", "font_color_pressed", "font_color_focus"]:
			b.add_color_override(c, Color(0.04, 0.04, 0.05))
	else:
		var e = StyleBoxEmpty.new(); e.content_margin_left = 2; e.content_margin_right = 2
		for st in ["normal", "hover", "pressed", "disabled"]: b.add_stylebox_override(st, e)
		var f2 = StyleBoxFlat.new(); f2.draw_center = false; f2.border_width_bottom = 1; f2.border_color = ACC
		f2.content_margin_left = 2; f2.content_margin_right = 2
		b.add_stylebox_override("focus", f2)
		b.add_font_override("font", G.ifont(14, "m"))
		b.add_color_override("font_color", Color(1, 1, 1, 0.6))
		for c in ["font_color_hover", "font_color_pressed", "font_color_focus"]:
			b.add_color_override(c, Color(1, 1, 1))

func open(is_new = false):
	if root.visible: return
	from_new = is_new
	main.phone.close(); main.hud.close_menu()
	G.MODE = "wardrobe"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	edit = G.clean_skin(G.S["skin"]).duplicate(true)
	before = edit.duplicate(true)
	title_l.text = "@" + str(G.S["name"])
	root.visible = true
	cat = 0 if is_new else 1
	_rebuild_preview()
	_render()

func close():
	root.visible = false
	if preview:
		preview.queue_free()
		preview = null
	if G.MODE == "wardrobe": G.MODE = "play"

func _rebuild_preview():
	if preview: preview.queue_free()
	preview = load("res://scripts/Human.gd").new().build(G.skin_opts(edit))
	holder.add_child(preview)

func _render():
	for c in cat_box.get_children():
		cat_box.remove_child(c); c.queue_free()
	for i in range(CATS.size()):
		var on = i == cat
		var b = Button.new(); b.text = CATS[i][0]; b.flat = true; b.align = Button.ALIGN_LEFT
		b.focus_mode = Control.FOCUS_NONE; b.rect_min_size = Vector2(0, 30)
		var e = StyleBoxEmpty.new(); e.content_margin_left = 18
		for st in ["normal", "hover", "pressed", "focus"]: b.add_stylebox_override(st, e)
		b.add_font_override("font", G.ifont(14, "m" if on else "r"))
		b.add_color_override("font_color", Color(1, 1, 1) if on else Color(1, 1, 1, 0.42))
		b.add_color_override("font_color_hover", Color(1, 1, 1))
		b.connect("pressed", self, "_set_cat", [i])
		if on:
			var mark = ColorRect.new(); mark.color = ACC; mark.rect_position = Vector2(0, 14); mark.rect_size = Vector2(10, 1.5)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(mark)
		cat_box.add_child(b)
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	rows = []
	if CATS[cat][0] == "Presets":
		var P = G.D["SKIN"]["PRESETS"]
		for i in range(P.size()):
			var b2 = _row_button("", P[i][0], null)
			b2.connect("pressed", self, "_preset", [i])
		var r = _row_button("", "Random look", null)
		r.connect("pressed", self, "randomize")
	else:
		for key in CATS[cat][1]:
			_field_row(key)
	if rows.size() > 0:
		rows[clamp(focus_row, 0, rows.size() - 1)].grab_focus()

# a thin row: a small grey label over the value, ‹ › on the right, a hairline under it
func _row_button(label, value, key):
	var b = Row.new(); b.wd = self; b.key = key
	b.rect_min_size = Vector2(0, 56 if label != "" else 46)
	var e = StyleBoxEmpty.new()
	var hi = _sb(Color(1, 1, 1, 0.055), 10)
	b.add_stylebox_override("normal", e); b.add_stylebox_override("disabled", e)
	for st in ["hover", "focus", "pressed"]: b.add_stylebox_override(st, hi)
	var y = 8
	if label != "":
		_text(b, label.to_upper(), G.ifont(10, "m"), DIM, Vector2(12, y))
		y += 16
	var vl = _text(b, value, G.ifont(17, "r") if label != "" else G.ifont(16, "r"), Color(1, 1, 1), Vector2(12, y if label != "" else 12))
	vl.name = "Value"
	if key != null:
		for d in [-1, 1]:
			var ch = Chev.new(); ch.dir = d; ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ch.anchor_left = 1; ch.anchor_right = 1; ch.anchor_top = 0.5; ch.anchor_bottom = 0.5
			ch.margin_left = -58 if d < 0 else -30; ch.margin_right = ch.margin_left + 18; ch.margin_top = -9; ch.margin_bottom = 9
			b.add_child(ch)
	var ln = ColorRect.new(); ln.color = LINE; ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ln.anchor_top = 1; ln.anchor_bottom = 1; ln.anchor_right = 1; ln.margin_top = -1; ln.margin_left = 12; ln.margin_right = -8
	b.add_child(ln)
	b.connect("focus_entered", self, "_focus", [rows.size()])
	list.add_child(b)
	rows.append(b)
	return b

func _focus(i): focus_row = i

func _field(key):
	for f in G.D["SKIN"]["SKIN_FIELDS"]:
		if f[0] == key: return f
	return null

func _value_text(key):
	var f = _field(key)
	var v = edit.get(key)
	if f[1] == "e": return G.D["SKIN"]["LABELS"].get(v, str(v))
	if f[1] == "b": return "On" if int(v) else "Off"
	if f[1] == "n":
		if key == "build": return BUILDS[clamp(int(v), 0, 2)]
		if key == "beard": return load("res://scripts/Human.gd").BEARDS[clamp(int(v), 0, 5)]
		return "%d / %d" % [int(v) + 1, int(f[3]) + 1]
	return ""

func _field_row(key):
	var f = _field(key)
	if f == null: return
	if f[1] == "c":
		var box = VBoxContainer.new(); box.add_constant_override("separation", 8)
		var pad = MarginContainer.new(); pad.add_constant_override("margin_left", 12); pad.add_constant_override("margin_top", 10); pad.add_constant_override("margin_bottom", 12)
		pad.add_child(box); list.add_child(pad)
		var lab = Label.new(); lab.text = NAMES.get(key, key).to_upper(); lab.add_font_override("font", G.ifont(10, "m")); lab.add_color_override("font_color", DIM); box.add_child(lab)
		var grid = GridContainer.new(); grid.columns = 9; grid.add_constant_override("hseparation", 9); grid.add_constant_override("vseparation", 9); box.add_child(grid)
		var cols = G.D["SKIN"]["HAIR_COLS"] if key == "hairCol" else G.D["SKIN"]["SWATCHES"]
		for c in cols:
			var b = Button.new(); b.rect_min_size = Vector2(24, 24)
			var on = int(edit.get(key, 0)) == int(c)
			var n = _sb(G.hex_color(c), 12)
			n.set_border_width_all(2 if on else 1); n.border_color = Color(1, 1, 1) if on else Color(1, 1, 1, 0.14)
			var fo = n.duplicate(); fo.set_border_width_all(2); fo.border_color = ACC
			b.add_stylebox_override("normal", n); b.add_stylebox_override("hover", fo); b.add_stylebox_override("focus", fo); b.add_stylebox_override("pressed", fo)
			b.connect("pressed", self, "_set_color", [key, c])
			grid.add_child(b)
		var ln = ColorRect.new(); ln.color = LINE; ln.rect_min_size = Vector2(0, 1); ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lm = MarginContainer.new(); lm.add_constant_override("margin_left", 12); lm.add_constant_override("margin_right", 8); lm.add_child(ln); list.add_child(lm)
		return
	var row = _row_button(NAMES.get(key, key), _value_text(key), key)
	row.connect("pressed", self, "step", [key, 1])

func _set_cat(i):
	cat = i; focus_row = 0; _render()

func step(key, d):
	if key == null: return
	var f = _field(key)
	var v = edit.get(key)
	if f[1] == "e":
		var opts = G.D["SKIN"]["SKIN_OPTS"][f[2]]
		var i = opts.find(v)
		edit[key] = opts[posmod(i + d, opts.size())]
	elif f[1] == "b":
		edit[key] = 0 if int(v) else 1
	elif f[1] == "n":
		var lo = int(f[2])
		var hi = int(f[3])
		edit[key] = lo + posmod(int(v) - lo + d, hi - lo + 1)
	main.sfx.play("tap", 0.35)
	_rebuild_preview()
	_render()

func _set_color(key, c):
	edit[key] = int(c)
	main.sfx.play("tap", 0.35)
	_rebuild_preview(); _render()

func _preset(i):
	edit = G.preset_skin(i).duplicate(true)
	_rebuild_preview(); _render()

func randomize():
	edit = G.random_skin().duplicate(true)
	main.sfx.play("whoosh", 0.3)
	_rebuild_preview(); _render()

func cancel():
	close()
	if from_new: main.hud.banner("@" + str(G.S["name"]), "Calder Park · Day " + str(G.S.get("day", 1)))

func save():
	G.S["skin"] = edit.duplicate(true)
	main.player._build_body(); main.player.vm_key = ""
	main.net.profile_changed()
	G.save_game()
	close()
	main.hud.banner("New fit", "Saved")

func _preview_input(e):
	if e is InputEventMouseButton and e.button_index == BUTTON_LEFT:
		drag = e.pressed
	elif e is InputEventMouseMotion and drag:
		rot += e.relative.x * 0.01

func _unhandled_input(e):
	if not root.visible: return
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause"):
		cancel(); get_tree().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.scancode == KEY_TAB:
			_set_cat((cat + 1) % CATS.size()); get_tree().set_input_as_handled()
		elif e.scancode == KEY_ENTER or e.scancode == KEY_KP_ENTER:
			save(); get_tree().set_input_as_handled()
		elif e.scancode == KEY_R:
			randomize(); get_tree().set_input_as_handled()
	elif e is InputEventJoypadButton and e.pressed:
		if e.button_index == JOY_R:
			_set_cat((cat + 1) % CATS.size()); get_tree().set_input_as_handled()
		elif e.button_index == JOY_L:
			_set_cat(posmod(cat - 1, CATS.size())); get_tree().set_input_as_handled()
		elif e.button_index == JOY_START:
			save(); get_tree().set_input_as_handled()

func update(dt):
	if not root.visible or preview == null: return
	if Input.is_key_pressed(KEY_Q): rot -= dt * 2.2
	if Input.is_key_pressed(KEY_E): rot += dt * 2.2
	var rs = Input.get_action_strength("look_r") - Input.get_action_strength("look_l")
	if abs(rs) > 0.2: rot += rs * dt * 2.5
	if not drag and abs(rs) < 0.2 and not Input.is_key_pressed(KEY_Q) and not Input.is_key_pressed(KEY_E): rot += dt * 0.25
	holder.rotation.y = rot
	preview.animate(dt, { "speed": 0.0, "pose": fmod(G.REAL_T, 9.0) > 6.5 })
