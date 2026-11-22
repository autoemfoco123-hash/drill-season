extends Node
# The character creator: a full-screen wardrobe with categories on the left, a ◀ value ▶ row
# for each option, colour swatches, and a lit 3D preview that turns (drag, or Q / E).
# Mouse, keyboard (arrows) and controller (D-pad / stick, A, B) all work.

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
var cat_bar
var title_l
var rot = 0.4
var drag = false
var from_new = false
var focus_row = 0

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

func setup(m):
	main = m
	layer = CanvasLayer.new(); layer.layer = 7; add_child(layer)
	root = Control.new(); root.anchor_right = 1; root.anchor_bottom = 1; root.visible = false
	layer.add_child(root)
	# backdrop
	var bg = TextureRect.new(); bg.anchor_right = 1; bg.anchor_bottom = 1; bg.expand = true
	var gt = GradientTexture.new(); var g = Gradient.new()
	g.set_color(0, Color(0.03, 0.035, 0.05)); g.set_color(1, Color(0.16, 0.12, 0.1)); gt.gradient = g; bg.texture = gt
	root.add_child(bg)
	# the 3D preview fills the right side
	var vc = ViewportContainer.new(); vc.stretch = true; vc.anchor_left = 0.36; vc.anchor_right = 1; vc.anchor_bottom = 1
	vc.connect("gui_input", self, "_preview_input")
	root.add_child(vc)
	vp = Viewport.new(); vp.own_world = true; vp.transparent_bg = true; vp.msaa = Viewport.MSAA_DISABLED; vp.size = Vector2(820, 720)
	vc.add_child(vp)
	var cam = Camera.new(); cam.fov = 32; cam.translation = Vector3(0, 1.1, 5.2); vp.add_child(cam); cam.look_at(Vector3(0, 0.95, 0), Vector3.UP); cam.current = true
	for L in [[Vector3(2, 3, 3), Color(1, 0.86, 0.72), 1.3], [Vector3(-3, 1.5, 2), Color(0.6, 0.72, 1), 0.7], [Vector3(0, 2.5, -3), Color(1, 0.6, 0.3), 1.1]]:
		var dl = DirectionalLight.new(); dl.light_color = L[1]; dl.light_energy = L[2]; vp.add_child(dl); dl.look_at_from_position(L[0], Vector3(0, 1, 0), Vector3.UP)
	var env = Environment.new(); env.background_mode = Environment.BG_CLEAR_COLOR; env.ambient_light_color = Color(0.5, 0.55, 0.65); env.ambient_light_energy = 0.7
	var we = WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	var disc = MeshInstance.new(); var dm = CylinderMesh.new(); dm.top_radius = 1.1; dm.bottom_radius = 1.1; dm.height = 0.04; dm.radial_segments = 40; disc.mesh = dm
	var dmat = SpatialMaterial.new(); dmat.albedo_color = Color(0.1, 0.11, 0.14); dmat.roughness = 0.4; disc.material_override = dmat; disc.translation.y = -0.02
	vp.add_child(disc)
	var ring = MeshInstance.new(); var rm = CylinderMesh.new(); rm.top_radius = 1.16; rm.bottom_radius = 1.16; rm.height = 0.02; rm.radial_segments = 40; ring.mesh = rm
	var rmat = SpatialMaterial.new(); rmat.flags_unshaded = true; rmat.albedo_color = Color(1, 0.6, 0.22); ring.material_override = rmat; ring.translation.y = -0.03
	vp.add_child(ring)
	holder = Spatial.new(); vp.add_child(holder)
	# left panel
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.02, 0.025, 0.04, 0.88)
	sb.content_margin_left = 34; sb.content_margin_right = 28; sb.content_margin_top = 30; sb.content_margin_bottom = 24
	panel.add_stylebox_override("panel", sb)
	panel.anchor_right = 0.36; panel.anchor_bottom = 1
	root.add_child(panel)
	var v = VBoxContainer.new(); v.add_constant_override("separation", 8); panel.add_child(v)
	var eb = Label.new(); eb.text = "CALDER PARK · WARDROBE"; eb.add_font_override("font", G.font_xs); eb.add_color_override("font_color", Color(1, 0.62, 0.22)); v.add_child(eb)
	title_l = Label.new(); title_l.add_font_override("font", G.font_big); title_l.text = "CHARACTER"; v.add_child(title_l)
	cat_bar = HBoxContainer.new(); v.add_child(cat_bar)
	var sep = HSeparator.new(); v.add_child(sep)
	var sc = ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.scroll_horizontal_enabled = false; v.add_child(sc)
	list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_constant_override("separation", 6); sc.add_child(list)
	var foot = HBoxContainer.new(); v.add_child(foot)
	for b in [["Randomize", "randomize"], ["Cancel", "cancel"], ["Save", "save"]]:
		var bt = Button.new(); bt.text = b[0]; bt.add_font_override("font", G.font_m); bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.connect("pressed", self, b[1]); foot.add_child(bt)
		if b[1] == "save": _style_btn(bt, true)
		else: _style_btn(bt, false)
	var hint = Label.new(); hint.text = "◀ ▶ change  ·  Q / E or drag to turn  ·  Tab next section  ·  Enter save  ·  Esc cancel"
	hint.autowrap = true; hint.add_font_override("font", G.font_xs); hint.add_color_override("font_color", Color(0.62, 0.68, 0.76)); v.add_child(hint)

func _style_btn(b, primary):
	var n = StyleBoxFlat.new(); n.bg_color = Color(1, 0.62, 0.22) if primary else Color(0.1, 0.12, 0.16); n.set_corner_radius_all(6)
	n.content_margin_top = 8; n.content_margin_bottom = 8; n.content_margin_left = 12; n.content_margin_right = 12
	var f = n.duplicate(); f.bg_color = Color(1, 1, 1); f.border_color = Color(1, 0.62, 0.22); f.set_border_width_all(2)
	for st in ["normal", "disabled"]: b.add_stylebox_override(st, n)
	for st in ["hover", "focus", "pressed"]: b.add_stylebox_override(st, f)
	b.add_color_override("font_color", Color(0.05, 0.05, 0.07) if primary else Color(1, 1, 1))
	b.add_color_override("font_color_hover", Color(0.05, 0.05, 0.07)); b.add_color_override("font_color_focus", Color(0.05, 0.05, 0.07))

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
	if preview: preview.queue_free(); preview = null
	if G.MODE == "wardrobe": G.MODE = "play"

func _rebuild_preview():
	if preview: preview.queue_free()
	preview = load("res://scripts/Human.gd").new().build(G.skin_opts(edit))
	holder.add_child(preview)

func _render():
	for c in cat_bar.get_children(): c.queue_free()
	for i in range(CATS.size()):
		var b = Button.new(); b.text = CATS[i][0]; b.flat = i != cat; b.add_font_override("font", G.font_xs)
		b.focus_mode = Control.FOCUS_NONE
		b.add_color_override("font_color", Color(1, 0.62, 0.22) if i == cat else Color(0.75, 0.8, 0.88))
		b.connect("pressed", self, "_set_cat", [i])
		cat_bar.add_child(b)
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	rows = []
	if CATS[cat][0] == "Presets":
		var P = G.D["SKIN"]["PRESETS"]
		for i in range(P.size()):
			var b2 = _row_button(P[i][0], "", null)
			b2.connect("pressed", self, "_preset", [i])
		var r = _row_button("Random look", "", null)
		r.connect("pressed", self, "randomize")
	else:
		for key in CATS[cat][1]:
			_field_row(key)
	if rows.size() > 0:
		rows[clamp(focus_row, 0, rows.size() - 1)].grab_focus()

func _row_button(label, value, key):
	var b = Row.new(); b.wd = self; b.key = key
	b.text = label
	b.align = Button.ALIGN_LEFT; b.add_font_override("font", G.font_m); b.clip_text = true
	if value != "":
		# the value sits on the right of the row: ◀ value ▶
		var vl = Label.new(); vl.text = "◀   %s   ▶" % value; vl.add_font_override("font", G.font_m); vl.align = Label.ALIGN_RIGHT
		vl.anchor_right = 1; vl.anchor_bottom = 1; vl.margin_right = -14; vl.valign = Label.VALIGN_CENTER; vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vl.add_color_override("font_color", Color(1, 0.62, 0.22))
		b.add_child(vl)
	var n = StyleBoxFlat.new(); n.bg_color = Color(0.07, 0.08, 0.11); n.set_corner_radius_all(4)
	n.content_margin_left = 14; n.content_margin_right = 14; n.content_margin_top = 9; n.content_margin_bottom = 9
	var f = n.duplicate(); f.bg_color = Color(0.96, 0.97, 1.0)
	b.add_stylebox_override("normal", n)
	for st in ["hover", "focus", "pressed"]:
		b.add_stylebox_override(st, f)
	b.add_color_override("font_color", Color(1, 1, 1)); b.add_color_override("font_color_hover", Color(0.05, 0.05, 0.07)); b.add_color_override("font_color_focus", Color(0.05, 0.05, 0.07))
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
		return "%d / %d" % [int(v) + 1, int(f[3]) + 1]
	return ""

func _field_row(key):
	var f = _field(key)
	if f == null: return
	if f[1] == "c":
		var lab = Label.new(); lab.text = NAMES.get(key, key); lab.add_font_override("font", G.font_s); lab.add_color_override("font_color", Color(0.75, 0.8, 0.88)); list.add_child(lab)
		var grid = GridContainer.new(); grid.columns = 9; list.add_child(grid)
		var cols = G.D["SKIN"]["HAIR_COLS"] if key == "hairCol" else G.D["SKIN"]["SWATCHES"]
		for c in cols:
			var b = Button.new(); b.rect_min_size = Vector2(36, 30)
			var on = int(edit.get(key, 0)) == int(c)
			var n = StyleBoxFlat.new(); n.bg_color = G.hex_color(c); n.set_corner_radius_all(15)
			n.set_border_width_all(3 if on else 1); n.border_color = Color(1, 0.62, 0.22) if on else Color(0, 0, 0, 0.5)
			var fo = n.duplicate(); fo.set_border_width_all(3); fo.border_color = Color(1, 1, 1)
			b.add_stylebox_override("normal", n); b.add_stylebox_override("hover", fo); b.add_stylebox_override("focus", fo); b.add_stylebox_override("pressed", fo)
			b.connect("pressed", self, "_set_color", [key, c])
			grid.add_child(b)
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
