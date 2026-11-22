extends Node
# The title screen: your character under the L, a username, Continue, import from the web game.

var main
var layer
var box
var name_edit
var info
var spot = Vector3(62.4, 0, -29.4)
var human = null
var ang = 0.62

func setup(m):
	main = m
	layer = CanvasLayer.new(); layer.layer = 6; add_child(layer)
	box = PanelContainer.new()
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.03, 0.04, 0.06, 0.82); sb.set_corner_radius_all(18)
	sb.content_margin_left = 30; sb.content_margin_right = 30; sb.content_margin_top = 26; sb.content_margin_bottom = 26
	box.add_stylebox_override("panel", sb)
	box.anchor_top = 0.5; box.anchor_bottom = 0.5; box.margin_left = 40; box.margin_right = 470; box.margin_top = -280; box.margin_bottom = 280
	layer.add_child(box)

func open():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for c in box.get_children(): c.queue_free()
	var v = VBoxContainer.new(); box.add_child(v)
	var eb = Label.new(); eb.text = "CALDER PARK · CHICAGO"; eb.add_font_override("font", G.font_s); eb.add_color_override("font_color", Color(1, 0.7, 0.28)); v.add_child(eb)
	var t = Label.new(); t.text = "DRILL\nSEASON"; t.add_font_override("font", G.font_xl); t.add_color_override("font_color", Color(1, 0.7, 0.28)); v.add_child(t)
	var d = Label.new(); d.text = "Make your name in the snow. The story's characters, crews, brands and places are fictional."; d.autowrap = true; d.add_font_override("font", G.font_s); d.add_color_override("font_color", Color(0.75, 0.8, 0.86)); v.add_child(d)
	var ded = Label.new(); ded.text = "In memory of King Von (1994–2020) and XXXTentacion (1998–2018). Long live."; ded.autowrap = true; ded.add_font_override("font", G.font_m); ded.add_color_override("font_color", Color(1, 0.86, 0.45)); v.add_child(ded)
	var save = G.load_save()
	var first = null
	if save:
		first = _btn(v, "Continue @%s · %s" % [save["name"], G.fmt_money(save["cash"])], "_continue", [save])
	name_edit = LineEdit.new(); name_edit.placeholder_text = "@yourname"; name_edit.max_length = 16; name_edit.add_font_override("font", G.font_m)
	v.add_child(name_edit)
	var play = _btn(v, "New game", "_new", [])
	if first == null: first = play
	var web = G.find_web_save()
	_btn(v, "Import progress from the web game" + (" (found)" if web != "" else ""), "_import", [])
	_btn(v, "Quit", "_quit", [])
	info = Label.new(); info.autowrap = true; info.add_font_override("font", G.font_s); info.add_color_override("font_color", Color(0.66, 0.72, 0.78))
	info.text = "Keyboard and mouse, or any controller. Tab opens your phone."
	v.add_child(info)
	box.visible = true
	first.grab_focus()
	if human: human.queue_free()
	var sk = save["skin"] if save else G.default_skin()
	human = load("res://scripts/Human.gd").new().build(G.skin_opts(sk))
	main.add_child(human)
	human.translation = spot
	G.MODE = "title"

func _btn(parent, text, method, args):
	var b = Button.new(); b.text = text; b.add_font_override("font", G.font_m)
	b.connect("pressed", self, method, args)
	parent.add_child(b)
	return b

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
