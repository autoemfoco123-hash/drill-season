extends Node
# The title screen, in the wardrobe's style: your character turning under the L on the right;
# on the left over a soft dark scrim, a letter-spaced eyebrow, a light title, a thin username
# field, a white pill for the main action and quiet text buttons for the rest.

var main
var layer
var box
var name_edit
var info
var spot = Vector3(62.4, 0, -29.4)
var human = null
var ang = 0.62

const DIM = Color(1, 1, 1, 0.56)

func setup(m):
	main = m
	layer = CanvasLayer.new(); layer.layer = 6; add_child(layer)
	box = Control.new(); box.anchor_right = 1; box.anchor_bottom = 1; box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)

func _sb(col, r, mx = 0, my = 0):
	var sb = StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(r); sb.anti_aliasing = true
	sb.content_margin_left = mx; sb.content_margin_right = mx; sb.content_margin_top = my; sb.content_margin_bottom = my
	return sb

func _label(parent, text, font, col):
	var l = Label.new(); l.text = text; l.add_font_override("font", font); l.add_color_override("font_color", col)
	parent.add_child(l)
	return l

func open():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for c in box.get_children(): c.queue_free()
	main.console.home_closed()
	if main.console.on:
		# console mode: the home screen with big tiles (Console.gd)
		main.console.home(box)
		box.visible = true
	else:
		_desktop_menu()
	if human: human.queue_free()
	var save0 = G.load_save()
	var sk = save0["skin"] if save0 else G.default_skin()
	human = load("res://scripts/Human.gd").new().build(G.skin_opts(sk))
	main.add_child(human)
	human.translation = spot
	G.MODE = "title"

func _desktop_menu():
	var scrim = TextureRect.new(); scrim.expand = true; scrim.anchor_right = 0.62; scrim.anchor_bottom = 1; scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gt = GradientTexture.new(); var gr = Gradient.new(); gr.set_color(0, Color(0.02, 0.02, 0.03, 0.9)); gr.set_color(1, Color(0.02, 0.02, 0.03, 0)); gr.add_point(0.55, Color(0.02, 0.02, 0.03, 0.62)); gt.gradient = gr
	scrim.texture = gt; box.add_child(scrim)
	var v = VBoxContainer.new(); v.rect_position = Vector2(64, 0); v.rect_size = Vector2(400, 0); v.add_constant_override("separation", 0)
	v.anchor_top = 0.5; v.anchor_bottom = 0.5; v.margin_top = -290; v.margin_bottom = 290; v.margin_left = 64; v.margin_right = 464
	v.alignment = BoxContainer.ALIGN_CENTER
	box.add_child(v)
	_label(v, "CALDER PARK · CHICAGO", G.ifont_sp(11, "m", 3), DIM)
	_label(v, "Drill\nSeason", G.ifont(62, "l"), Color(1, 1, 1))
	var d = _label(v, "Make your name in the snow. The story's characters, crews, brands and places are fictional.", G.ifont(13, "r"), DIM); d.autowrap = true; d.rect_min_size = Vector2(380, 0)
	_gap(v, 10)
	var ded = _label(v, "In memory of King Von (1994–2020) and XXXTentacion (1998–2018). Long live.", G.ifont(13, "m"), Color(1, 0.84, 0.55)); ded.autowrap = true; ded.rect_min_size = Vector2(380, 0)
	_gap(v, 26)
	var save = G.load_save()
	var first = null
	if save:
		first = _pill(v, "Continue  @%s" % save["name"], "_continue", [save])
		var cs = _label(v, "%s · Day %d" % [G.fmt_money(save["cash"]), int(save.get("day", 1))], G.ifont(12, "r"), DIM)
		cs.rect_min_size = Vector2(0, 26); cs.valign = Label.VALIGN_CENTER
		_gap(v, 14)
	_label(v, "NEW CHARACTER", G.ifont_sp(10, "m", 2), DIM)
	name_edit = LineEdit.new(); name_edit.placeholder_text = "@yourname"; name_edit.max_length = 16; name_edit.add_font_override("font", G.ifont(20, "l"))
	var ne = StyleBoxFlat.new(); ne.draw_center = false; ne.border_width_bottom = 1; ne.border_color = Color(1, 1, 1, 0.22); ne.content_margin_top = 8; ne.content_margin_bottom = 8
	var nf = ne.duplicate(); nf.border_color = Color(1, 0.62, 0.22)
	name_edit.add_stylebox_override("normal", ne); name_edit.add_stylebox_override("focus", nf)
	name_edit.add_color_override("font_color", Color(1, 1, 1)); name_edit.add_color_override("cursor_color", Color(1, 0.62, 0.22))
	name_edit.rect_min_size = Vector2(300, 0); name_edit.size_flags_horizontal = 0
	v.add_child(name_edit)
	name_edit.connect("text_entered", self, "_entered")
	_gap(v, 14)
	var play
	if save: play = _text_btn(v, "New game", "_new", [])
	else: play = _pill(v, "New game", "_new", [])
	if first == null: first = play
	var web = G.find_web_save()
	_text_btn(v, "Import progress from the web game" + (" · found" if web != "" else ""), "_import", [])
	if OS.get_name() != "Android": _text_btn(v, "Console mode · TV and controller", "_console", [])
	_text_btn(v, "Quit", "_quit", [])
	_gap(v, 18)
	var pads = Input.get_connected_joypads().size() > 0
	info = _label(v, ("Controller found: press %s for console mode. " % G.pad_label("MENU") if pads else "") + "Keyboard and mouse, or any controller. Tab opens your phone.", G.ifont(11, "r"), Color(1, 1, 1, 0.36))
	info.autowrap = true; info.rect_min_size = Vector2(380, 0)
	box.visible = true
	first.grab_focus()

func _console():
	main.console.set_on(true)

func _gap(v, h):
	var g = Control.new(); g.rect_min_size = Vector2(0, h); g.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_child(g)

# the main action: a white pill
func _pill(parent, text, method, args):
	var b = Button.new(); b.text = text; b.size_flags_horizontal = 0; b.rect_min_size = Vector2(200, 44)
	b.add_font_override("font", G.ifont(15, "s"))
	b.add_stylebox_override("normal", _sb(Color(1, 1, 1), 22, 26, 10))
	b.add_stylebox_override("hover", _sb(Color(0.88, 0.88, 0.9), 22, 26, 10))
	b.add_stylebox_override("pressed", _sb(Color(0.78, 0.78, 0.8), 22, 26, 10))
	var f = _sb(Color(1, 1, 1), 22, 26, 10); f.border_color = Color(1, 0.62, 0.22); f.set_border_width_all(2)
	b.add_stylebox_override("focus", f)
	for c in ["font_color", "font_color_hover", "font_color_pressed", "font_color_focus"]: b.add_color_override(c, Color(0.04, 0.04, 0.05))
	b.connect("pressed", self, method, args)
	parent.add_child(b)
	return b

# everything else: quiet text that lights up
func _text_btn(parent, text, method, args):
	var b = Button.new(); b.text = text; b.size_flags_horizontal = 0; b.align = Button.ALIGN_LEFT; b.rect_min_size = Vector2(0, 38)
	b.add_font_override("font", G.ifont(15, "m"))
	var e = StyleBoxEmpty.new(); e.content_margin_left = 2; e.content_margin_right = 2
	for st in ["normal", "hover", "pressed", "disabled"]: b.add_stylebox_override(st, e)
	var f = StyleBoxFlat.new(); f.draw_center = false; f.border_width_bottom = 1; f.border_color = Color(1, 0.62, 0.22); f.content_margin_left = 2; f.content_margin_right = 2
	b.add_stylebox_override("focus", f)
	b.add_color_override("font_color", Color(1, 1, 1, 0.62))
	for c in ["font_color_hover", "font_color_pressed", "font_color_focus"]: b.add_color_override(c, Color(1, 1, 1))
	b.connect("pressed", self, method, args)
	parent.add_child(b)
	return b

func _entered(_t):
	_new()

func _clean(s):
	var out = ""
	for i in range(s.length()):
		var ch = s[i]
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch in ["_", ".", "-"]: out += ch
	return out.substr(0, 16)

func _continue(save):
	_close(); main.start_game(save)

func _new():
	var nm = _clean(name_edit.text.replace("@", ""))
	if nm.length() < 2:
		info.text = "Pick a username: 2 to 16 letters, numbers, dots or underscores."
		name_edit.grab_focus()
		return
	_close(); main.start_game(G.new_state(nm))

func _import():
	var err = G.import_web_save()
	if err != "":
		info.text = err; return
	_close(); main.start_game(G.S)
	main.hud.banner("Progress imported", "@" + G.S["name"])

func _quit():
	get_tree().quit()

func _close():
	box.visible = false
	main.console.home_closed()
	if human:
		human.queue_free()
		human = null

func update(dt):
	if human == null: return
	ang += dt * 0.12
	var cam = main.camera
	cam.translation = spot + Vector3(sin(ang) * 4.3, 1.5, cos(ang) * 4.3)
	cam.look_at(spot + Vector3(0, 1.1, 0), Vector3.UP)
	cam.translate_object_local(Vector3(-0.9, 0, 0))
	human.rotation.y = ang
	human.animate(dt, { "speed": 0.0, "wave": fmod(G.REAL_T, 9) < 1.5 })
