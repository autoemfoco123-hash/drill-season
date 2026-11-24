extends Node
# Console mode: Drill Season on a TV with a controller, played like a console game. Turn it on in
# the phone's Settings (Console mode), with the console launchers in the PC zips (they pass
# --console), or by pressing START / OPTIONS on the title screen. It gives you:
#  - a console home screen: "press any button", then big tiles, a clock and the controller's name;
#  - full screen, no mouse pointer, the HUD inside the TV's safe area and the UI 11% bigger;
#  - the controller's own buttons on screen (Xbox letters or PlayStation shapes, from its name);
#  - an on-screen keyboard for every text box (A on the box), so nothing needs a keyboard;
#  - a pause menu on START (resume, phone, map, controls, settings, save and quit);
#  - a controls screen with the controller drawn out;
#  - the left stick and a held D-pad scroll every menu, the way consoles do.
# Aim assist and vibration work with any controller and can be switched off in Settings.

var main
var on = false
var layer                  # over everything: the keyboard and the controls screen
var home_root = null       # the console home screen, built into the title's box
var splash = true          # "press any button" before the tiles
var tiles = []
var clock_lbl = null
var pad_lbl = null
var press_lbl = null
var over = null            # the controls screen
var over_mode = ""         # the game mode to go back to when it closes
var osk = null             # the on-screen keyboard
var nav_dir = Vector2()
var nav_t = 0.0
var nav_src = ""
var mouse_t = 9.0
var t = 0.0

const PREFS = "user://prefs.cfg"
const BASE = Vector2(1152, 648)      # the console layout: everything 11% bigger than 1280 x 720
const ACCENT = Color(1, 0.62, 0.22)
const DIM = Color(1, 1, 1, 0.56)

func setup(m):
	main = m
	layer = CanvasLayer.new(); layer.layer = 14; add_child(layer)
	var cf = ConfigFile.new()
	if cf.load(PREFS) == OK: on = bool(cf.get_value("console", "on", false))
	var args = OS.get_cmdline_args()
	if "--console" in args or OS.get_environment("DS_CONSOLE") != "": on = true
	if "--no-console" in args: on = false
	Input.connect("joy_connection_changed", self, "_joy_changed")
	_joy_changed(0, true)
	apply()

func _joy_changed(_d, _c):
	G.pad_kind = G.detect_pad_kind()
	if home_root and is_instance_valid(home_root): _home_status()

func set_on(v):
	on = v
	var cf = ConfigFile.new()
	cf.load(PREFS)
	cf.set_value("console", "on", on)
	cf.save(PREFS)
	apply()
	main.hud.toast("Console mode on" if on else "Console mode off")
	if G.MODE == "title": main.title.open()

func apply():
	G.console_on = on
	if on and OS.get_name() != "Android" and OS.get_environment("DS_SHOTS") == "": OS.window_fullscreen = true
	get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_2D, SceneTree.STRETCH_ASPECT_EXPAND, BASE if on else Vector2(1280, 720))
	if main.hud: main.hud.safe_area(0.025 if on else 0.0)

# ---------------------------------------------------------------- input
func _input(e):
	if e is InputEventJoypadButton or (e is InputEventJoypadMotion and abs(e.axis_value) > 0.5):
		G.last_pad = true
	elif (e is InputEventKey and e.pressed) or e is InputEventMouseButton or (e is InputEventMouseMotion and e.relative.length() > 4):
		G.last_pad = false
	if e is InputEventMouseMotion and e.relative.length() > 2: mouse_t = 0.0
	if osk:
		_osk_input(e); get_tree().set_input_as_handled(); return
	if over:
		if e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause") or e.is_action_pressed("ui_accept"):
			close_controls(); get_tree().set_input_as_handled()
		return
	if home_root and G.MODE == "title" and is_instance_valid(home_root):
		_home_input(e); return
	# A on a text box with a controller: the on-screen keyboard instead of typing
	if G.last_pad and e is InputEventJoypadButton and e.pressed and e.button_index == JOY_XBOX_A:
		var f = get_viewport().gui_get_focus_owner()
		if f is LineEdit and f.is_visible_in_tree() and f.editable:
			open_keyboard(f, f.placeholder_text if f.placeholder_text != "" else "Type")
			get_tree().set_input_as_handled(); return
	# START on the desktop title screen: console mode
	if not on and G.MODE == "title" and e is InputEventJoypadButton and e.pressed and e.button_index == JOY_START:
		set_on(true); get_tree().set_input_as_handled()

func _process(dt):
	t += dt
	mouse_t += dt
	# no pointer on a TV unless the mouse is actually moving
	var mm = Input.get_mouse_mode()
	if on and mouse_t > 2.5 and mm == Input.MOUSE_MODE_VISIBLE: Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	elif mm == Input.MOUSE_MODE_HIDDEN and (mouse_t < 0.2 or not on): Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_stick_nav(dt)
	if home_root and is_instance_valid(home_root) and G.MODE == "title":
		if clock_lbl and int(t * 2) % 2 == 0: clock_lbl.text = _clock()
		if press_lbl: press_lbl.modulate.a = 0.55 + 0.45 * sin(t * 3.2)
	if osk: osk.update()

# the left stick (and a held D-pad) moves through menus, repeating while held, like a console
func _stick_nav(dt):
	var menus = osk != null or G.MODE in ["title", "phone", "menu", "ending"]
	var pads = Input.get_connected_joypads()
	if not menus or pads.empty():
		nav_dir = Vector2(); return
	var p = pads[0]
	var v = Vector2(Input.get_joy_axis(p, JOY_AXIS_0), Input.get_joy_axis(p, JOY_AXIS_1))
	var d = Vector2()
	var src = "stick"
	if abs(v.x) > 0.6 and abs(v.x) > abs(v.y): d.x = sign(v.x)
	elif abs(v.y) > 0.6: d.y = sign(v.y)
	else:
		src = "dpad"
		if Input.is_joy_button_pressed(p, JOY_DPAD_LEFT): d.x = -1
		elif Input.is_joy_button_pressed(p, JOY_DPAD_RIGHT): d.x = 1
		elif Input.is_joy_button_pressed(p, JOY_DPAD_UP): d.y = -1
		elif Input.is_joy_button_pressed(p, JOY_DPAD_DOWN): d.y = 1
	if d != nav_dir or src != nav_src:
		nav_dir = d; nav_src = src; nav_t = 0.0
		# a D-pad press already moves once by itself; the stick needs the first step from here
		if d != Vector2() and src == "stick": _nav(d)
	elif d != Vector2():
		nav_t += dt
		if nav_t > 0.42:
			nav_t -= 0.1
			_nav(d)

func _nav(d):
	if osk:
		osk.move(d); return
	var a = "ui_right" if d.x > 0 else ("ui_left" if d.x < 0 else ("ui_down" if d.y > 0 else "ui_up"))
	for pressed in [true, false]:
		var ev = InputEventAction.new(); ev.action = a; ev.pressed = pressed
		Input.parse_input_event(ev)

# ---------------------------------------------------------------- the console home screen
func home(box):
	home_root = Control.new(); home_root.anchor_right = 1; home_root.anchor_bottom = 1; home_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(home_root)
	var scrim = TextureRect.new(); scrim.expand = true; scrim.anchor_right = 1; scrim.anchor_bottom = 1; scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gt = GradientTexture.new(); var gr = Gradient.new()
	gr.set_color(0, Color(0.02, 0.02, 0.03, 0.86)); gr.set_color(1, Color(0.02, 0.02, 0.03, 0.05)); gr.add_point(0.6, Color(0.02, 0.02, 0.03, 0.5))
	gt.gradient = gr; scrim.texture = gt
	home_root.add_child(scrim)
	var bot = ColorRect.new(); bot.color = Color(0.02, 0.02, 0.03, 0.55); bot.anchor_top = 1; bot.anchor_right = 1; bot.anchor_bottom = 1; bot.margin_top = -300
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_root.add_child(bot)
	# top: the name on the left, the clock and the controller on the right
	var ey = _lbl(home_root, "CALDER PARK · CHICAGO", G.ifont_sp(13, "m", 3), DIM)
	ey.rect_position = Vector2(64, 54)
	var ti = _lbl(home_root, "Drill Season", G.ifont(64, "l"), Color(1, 1, 1))
	ti.rect_position = Vector2(60, 72)
	clock_lbl = _lbl(home_root, _clock(), G.ifont(30, "l"), Color(1, 1, 1))
	clock_lbl.anchor_left = 1; clock_lbl.anchor_right = 1; clock_lbl.margin_left = -260; clock_lbl.margin_right = -64; clock_lbl.margin_top = 50
	clock_lbl.align = Label.ALIGN_RIGHT
	pad_lbl = _lbl(home_root, "", G.ifont(14, "m"), DIM)
	pad_lbl.anchor_left = 1; pad_lbl.anchor_right = 1; pad_lbl.margin_left = -460; pad_lbl.margin_right = -64; pad_lbl.margin_top = 92
	pad_lbl.align = Label.ALIGN_RIGHT
	# the hint bar at the bottom
	var bar = HBoxContainer.new(); bar.name = "Bar"; bar.anchor_top = 1; bar.anchor_bottom = 1; bar.margin_left = 64; bar.margin_top = -66; bar.margin_bottom = -30
	bar.add_constant_override("separation", 26)
	home_root.add_child(bar)
	splash = true
	_home_splash()
	_home_status()

func _clock():
	var d = OS.get_time()
	return "%d:%02d" % [d.hour, d.minute]

func _home_status():
	if not pad_lbl or not is_instance_valid(pad_lbl): return
	pad_lbl.text = G.pad_name() if G.has_pad() else "No controller · keyboard works too"
	_home_bar()

func _home_bar():
	var bar = home_root.get_node_or_null("Bar")
	if bar == null: return
	for c in bar.get_children(): c.queue_free()
	if splash: return
	hint(bar, "A", "Select", "Enter")
	hint(bar, "MENU", "Controls", "Esc")

# a button hint: the controller's icon (or a key cap) and a word
func hint(parent, b, text, key = ""):
	var h = HBoxContainer.new(); h.add_constant_override("separation", 8)
	parent.add_child(h)
	var tex = G.pad_tex(b) if G.has_pad() else null
	if tex:
		var tr = TextureRect.new(); tr.texture = tex; tr.expand = true; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.rect_min_size = Vector2(30 * tex.get_width() / float(tex.get_height()), 30)
		h.add_child(tr)
	else:
		var k = _lbl(h, key if key != "" else b, G.ifont(12, "b"), Color(0.05, 0.05, 0.06))
		var ks = StyleBoxFlat.new(); ks.bg_color = Color(1, 1, 1, 0.92); ks.set_corner_radius_all(6); ks.content_margin_left = 8; ks.content_margin_right = 8; ks.content_margin_top = 3; ks.content_margin_bottom = 3
		k.add_stylebox_override("normal", ks); k.valign = Label.VALIGN_CENTER; k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l = _lbl(h, text, G.ifont(16, "m"), Color(1, 1, 1, 0.85)); l.valign = Label.VALIGN_CENTER; l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return h

func _home_splash():
	for c in tiles: if is_instance_valid(c): c.queue_free()
	tiles = []
	var sub = _lbl(home_root, "Make your name in the snow.", G.ifont(18, "r"), DIM)
	sub.name = "Sub"; sub.rect_position = Vector2(64, 156)
	press_lbl = _lbl(home_root, "", G.ifont(22, "m"), Color(1, 1, 1))
	press_lbl.anchor_top = 1; press_lbl.anchor_bottom = 1; press_lbl.margin_left = 64; press_lbl.margin_top = -150; press_lbl.margin_right = 700
	press_lbl.text = "Press any button" if G.has_pad() else "Press any key"
	_home_bar()

func _home_tiles():
	splash = false
	if press_lbl and is_instance_valid(press_lbl): press_lbl.queue_free()
	press_lbl = null
	var row = HBoxContainer.new(); row.name = "Tiles"; row.anchor_top = 1; row.anchor_bottom = 1; row.margin_left = 64; row.margin_top = -280; row.margin_bottom = -96
	row.add_constant_override("separation", 18)
	home_root.add_child(row)
	var save = G.load_save()
	tiles = []
	if save:
		tiles.append(_tile(row, "Continue", "@%s" % save["name"], "%s · Day %d" % [G.fmt_money(save["cash"]), int(save.get("day", 1))], "_t_continue", [save], 280, true))
	tiles.append(_tile(row, "New game", "Pick a name", "Start in Calder Park", "_t_new", [], 200, save == null))
	var web = G.find_web_save()
	if web != "": tiles.append(_tile(row, "Web progress", "Found", "Bring it over", "_t_import", [], 180))
	tiles.append(_tile(row, "Controls", "Your controller", "Every button", "controls", [], 180))
	tiles.append(_tile(row, "Desktop mode", "Mouse and keyboard", "Leave console mode", "_t_desktop", [], 180))
	tiles.append(_tile(row, "Quit", "", "", "_t_quit", [], 120))
	for i in range(tiles.size()):
		var b = tiles[i]
		b.focus_neighbour_left = b.get_path_to(tiles[(i - 1 + tiles.size()) % tiles.size()])
		b.focus_neighbour_right = b.get_path_to(tiles[(i + 1) % tiles.size()])
		b.focus_neighbour_top = b.get_path(); b.focus_neighbour_bottom = b.get_path()
	tiles[0].grab_focus()
	_home_bar()

# a big tile: dark glass, white with an orange edge when it has focus, a little bigger too
func _tile(parent, title, sub, line, method, args, w, big = false):
	var b = Button.new(); b.rect_min_size = Vector2(w, 184); b.focus_mode = Control.FOCUS_ALL
	var n = StyleBoxFlat.new(); n.bg_color = Color(0.1, 0.1, 0.12, 0.72); n.set_corner_radius_all(18); n.border_color = Color(1, 1, 1, 0.1); n.set_border_width_all(1)
	var f = StyleBoxFlat.new(); f.bg_color = Color(1, 1, 1, 0.96); f.set_corner_radius_all(18); f.border_color = ACCENT; f.set_border_width_all(3)
	f.shadow_color = Color(0, 0, 0, 0.45); f.shadow_size = 18
	b.add_stylebox_override("normal", n); b.add_stylebox_override("hover", n); b.add_stylebox_override("pressed", f); b.add_stylebox_override("focus", f)
	b.connect("pressed", self, method, args)
	b.connect("focus_entered", self, "_tile_focus", [b, true]); b.connect("focus_exited", self, "_tile_focus", [b, false])
	b.connect("mouse_entered", b, "grab_focus")
	parent.add_child(b)
	var v = VBoxContainer.new(); v.anchor_right = 1; v.anchor_bottom = 1; v.margin_left = 20; v.margin_right = -16; v.margin_top = 18; v.margin_bottom = -18
	v.alignment = BoxContainer.ALIGN_END; v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tl = _lbl(v, title, G.ifont(26 if big else 21, "s"), Color(1, 1, 1)); tl.name = "T"
	if sub != "":
		var sl = _lbl(v, sub, G.ifont(15, "m"), Color(1, 1, 1, 0.75)); sl.name = "S"; sl.clip_text = true
	if line != "":
		var ll = _lbl(v, line, G.ifont(13, "r"), Color(1, 1, 1, 0.5)); ll.name = "L"; ll.clip_text = true
	b.rect_pivot_offset = Vector2(w / 2.0, 92)
	return b

func _tile_focus(b, f):
	b.rect_scale = Vector2(1.05, 1.05) if f else Vector2(1, 1)
	# the row slides so the tile with focus is always on screen
	var row = b.get_parent()
	if f and home_root and is_instance_valid(row):
		var vw = home_root.rect_size.x
		var gx = row.rect_position.x + b.rect_position.x
		if gx + b.rect_size.x > vw - 64: row.rect_position.x -= gx + b.rect_size.x - (vw - 64)
		elif gx < 64: row.rect_position.x += 64 - gx
	for c in b.get_child(0).get_children():
		var col = Color(0.04, 0.04, 0.05) if f else Color(1, 1, 1)
		col.a = 1.0 if c.name == "T" else (0.75 if c.name == "S" else 0.55)
		c.add_color_override("font_color", col)
	if f: main.sfx.play("tap", 0.25)

func _home_input(e):
	var any = (e is InputEventJoypadButton and e.pressed) or (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed)
	if splash:
		if any:
			get_tree().set_input_as_handled()
			main.sfx.play("unlock", 0.5)
			_home_tiles()
		return
	if e.is_action_pressed("pause") and not osk:
		get_tree().set_input_as_handled(); controls()
	elif e.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		var tr = home_root.get_node_or_null("Tiles")
		if tr: tr.queue_free()
		tiles = []
		splash = true; _home_splash()

func home_closed():
	home_root = null; tiles = []; press_lbl = null; clock_lbl = null; pad_lbl = null

func _t_continue(save):
	main.title._continue(save)

func _t_new():
	open_keyboard(null, "Pick a username", funcref(self, "_new_name"), 16, "@")

func _new_name(txt):
	var nm = main.title._clean(txt.replace("@", ""))
	if nm.length() < 2:
		main.hud.toast("2 to 16 letters, numbers, dots or underscores")
		call_deferred("_t_new")
		return
	main.title._close(); main.start_game(G.new_state(nm))

func _t_import():
	main.title._import()

func _t_desktop():
	set_on(false)

func _t_quit():
	get_tree().quit()

# ---------------------------------------------------------------- the pause menu (START)
func pause_menu():
	if G.MODE != "play": return
	var P = main.player
	var items = [
		{ "label": "Resume", "act": funcref(self, "_noop"), "desc": "Back to the street." },
		{ "label": "Phone", "act": funcref(self, "_phone"), "arg": "", "desc": "Your apps: jobs, gang, garage, wardrobe, online." },
		{ "label": "Map", "act": funcref(self, "_phone"), "arg": "map", "desc": "Calder Park and your waypoint." },
		{ "label": "Controls", "act": funcref(self, "controls"), "desc": "Every button on your controller." },
		{ "label": "Settings", "act": funcref(self, "_phone"), "arg": "settings", "desc": "Look speed, aim assist, vibration, sound, graphics." },
		{ "label": "Desktop mode", "act": funcref(self, "_t_desktop"), "desc": "Leave console mode: mouse, keyboard and the desktop layout." },
		{ "label": "Save and quit to title", "act": funcref(main, "exit_to_title"), "desc": "Saves first." },
	]
	var sub = "%s · Day %d · %s" % [G.fmt_money(G.S["cash"]), int(G.S.get("day", 1)), main.hud.street_name(P.pos)]
	main.hud.menu("Paused", "Drill Season", sub, items)
	main.sfx.play("tap", 0.5)

func _noop():
	pass

func _phone(app):
	main.phone.open(app)

# ---------------------------------------------------------------- the controls screen
func controls():
	if over: return
	over_mode = G.MODE
	if G.MODE == "play": G.MODE = "menu"
	over = ControlsView.new(); over.main = main
	over.anchor_right = 1; over.anchor_bottom = 1
	layer.add_child(over)
	main.sfx.play("tap", 0.5)

func close_controls():
	if over:
		over.queue_free(); over = null
		if G.MODE == "menu" and over_mode == "play": G.MODE = "play"
		main.sfx.play("tap", 0.35)

class ControlsView extends Control:
	var main
	# [button, what it does on foot, in a car]
	const LEFT = [["LT", "Aim", "Brake · with RT: burnout"], ["LB", "Weapon (hold: wheel)", "Lean out the window"], ["LS", "Move (click: sprint)", "Steer"],
		["UP", "Phone", ""], ["LEFT", "Emotes and dances", ""], ["DOWN", "Bandage", ""], ["RIGHT", "Middle finger", ""], ["VIEW", "Map", ""]]
	const RIGHT = [["RT", "Shoot · punch", "Gas"], ["RB", "Use · talk · aiming: crew orders", "Shoot out the window"], ["Y", "Get in · out of a car", ""], ["X", "Reload", "Next station"],
		["B", "Crouch", ""], ["A", "Jump", "Handbrake"], ["RS", "Camera (click: first person)", "Look"], ["MENU", "Pause", ""]]
	func _ready():
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw():
		var sz = rect_size
		draw_rect(Rect2(Vector2(), sz), Color(0.02, 0.02, 0.03, 0.9))
		var ey = G.ifont_sp(13, "m", 3)
		draw_string(ey, Vector2(64, 70), "CONTROLS", Color(1, 1, 1, 0.56))
		draw_string(G.ifont(40, "l"), Vector2(62, 116), G.pad_name() if G.has_pad() else "Controller", Color(1, 1, 1))
		# the controller, drawn simply in the middle
		var c = Vector2(sz.x / 2, sz.y * 0.55)
		var k = 1.45
		var body = Color(0.16, 0.16, 0.19)
		var edge = Color(1, 1, 1, 0.14)
		draw_circle(c + Vector2(-118, 46) * k, 74 * k, body); draw_circle(c + Vector2(118, 46) * k, 74 * k, body)
		draw_rect(Rect2(c + Vector2(-140, -62) * k, Vector2(280, 128) * k), body)
		draw_circle(c + Vector2(-140, 0) * k, 62 * k, body); draw_circle(c + Vector2(140, 0) * k, 62 * k, body)
		draw_arc(c + Vector2(-118, 46) * k, 74 * k, PI * 0.45, PI * 1.05, 24, edge, 2.0, true)
		draw_arc(c + Vector2(118, 46) * k, 74 * k, -PI * 0.05, PI * 0.55, 24, edge, 2.0, true)
		var spots = { "LS": Vector2(-132, -6), "RS": Vector2(66, 50), "A": Vector2(132, 26), "B": Vector2(162, -4), "X": Vector2(102, -4), "Y": Vector2(132, -34),
			"VIEW": Vector2(-34, -20), "MENU": Vector2(34, -20), "LB": Vector2(-140, -84), "RB": Vector2(140, -84), "LT": Vector2(-140, -116), "RT": Vector2(140, -116) }
		for b in spots.keys():
			var tex = G.pad_tex(b)
			if tex == null: continue
			var h = (30.0 if b in ["A", "B", "X", "Y", "VIEW", "MENU"] else 36.0) * (1.2 if b in ["A", "B", "X", "Y", "LS", "RS"] else 1.0)
			var w = h * tex.get_width() / float(tex.get_height())
			draw_texture_rect(tex, Rect2(c + spots[b] * k - Vector2(w, h) / 2, Vector2(w, h)), false)
		var dp = G.pad_tex_file("dpad")
		draw_texture_rect(dp, Rect2(c + Vector2(-66, 50) * k - Vector2(40, 40), Vector2(80, 80)), false)
		# the two lists: left hand on the left, right hand on the right
		_list(LEFT, Vector2(64, 170), false)
		_list(RIGHT, Vector2(sz.x - 64, 170), true)
		var f = G.ifont(15, "m")
		var foot = "In a car the second line applies.   " + ("B or START to close" if G.has_pad() else "Esc to close")
		draw_string(f, Vector2(64, sz.y - 40), foot, Color(1, 1, 1, 0.5))
	func _list(items, at, right):
		var f = G.ifont(17, "m")
		var f2 = G.ifont(13, "r")
		var y = at.y
		for it in items:
			var tex = G.pad_tex(it[0])
			var h = 30.0
			var w = h * tex.get_width() / float(tex.get_height()) if tex else 0.0
			var tw = f.get_string_size(it[1]).x
			if right:
				draw_texture_rect(tex, Rect2(Vector2(at.x - w, y), Vector2(w, h)), false)
				draw_string(f, Vector2(at.x - w - 14 - tw, y + 21), it[1], Color(1, 1, 1))
				if it[2] != "":
					var t2 = f2.get_string_size(it[2]).x
					draw_string(f2, Vector2(at.x - w - 14 - t2, y + 40), it[2], Color(1, 0.62, 0.22, 0.85))
			else:
				draw_texture_rect(tex, Rect2(Vector2(at.x, y), Vector2(w, h)), false)
				draw_string(f, Vector2(at.x + w + 14, y + 21), it[1], Color(1, 1, 1))
				if it[2] != "":
					draw_string(f2, Vector2(at.x + w + 14, y + 40), it[2], Color(1, 0.62, 0.22, 0.85))
			y += 52 if it[2] != "" else 44

# ---------------------------------------------------------------- the on-screen keyboard
# open_keyboard(a LineEdit, title) types into that box; open_keyboard(null, title, funcref) hands
# the text to the funcref when you press Done.
func open_keyboard(target, title, cb = null, maxlen = 0, prefix = ""):
	if osk: return
	osk = Keyboard.new()
	osk.con = self; osk.target = target; osk.cb = cb; osk.title = title; osk.prefix = prefix
	osk.text = target.text if target else ""
	osk.maxlen = (target.max_length if target else maxlen)
	osk.secret = target.secret if target else false
	osk.anchor_right = 1; osk.anchor_bottom = 1
	layer.add_child(osk)
	main.sfx.play("tap", 0.4)

func close_keyboard(done):
	if not osk: return
	var k = osk
	osk = null
	k.queue_free()
	if k.target and is_instance_valid(k.target):
		k.target.text = k.text; k.target.caret_position = k.text.length()
		k.target.emit_signal("text_changed", k.text)
		k.target.grab_focus()
		if done: k.target.emit_signal("text_entered", k.text)
	elif done and k.cb:
		k.cb.call_func(k.text)
	main.sfx.play("tap", 0.35)

func _osk_input(e):
	var k = osk
	if e is InputEventJoypadButton and e.pressed:
		match e.button_index:
			JOY_XBOX_A: k.press()
			JOY_XBOX_B:
				if k.text == "": close_keyboard(false)
				else: k.backspace()
			JOY_XBOX_X: k.type(" ")
			JOY_XBOX_Y: k.shift = not k.shift
			JOY_L: k.caret = max(0, k.caret - 1)
			JOY_R: k.caret = min(k.text.length(), k.caret + 1)
			JOY_START: close_keyboard(true)
			JOY_DPAD_LEFT: k.move(Vector2(-1, 0))
			JOY_DPAD_RIGHT: k.move(Vector2(1, 0))
			JOY_DPAD_UP: k.move(Vector2(0, -1))
			JOY_DPAD_DOWN: k.move(Vector2(0, 1))
	elif e is InputEventKey and e.pressed:
		if e.scancode == KEY_ESCAPE: close_keyboard(false)
		elif e.scancode == KEY_ENTER or e.scancode == KEY_KP_ENTER: close_keyboard(true)
		elif e.scancode == KEY_BACKSPACE: k.backspace()
		elif e.scancode == KEY_LEFT: k.move(Vector2(-1, 0))
		elif e.scancode == KEY_RIGHT: k.move(Vector2(1, 0))
		elif e.scancode == KEY_UP: k.move(Vector2(0, -1))
		elif e.scancode == KEY_DOWN: k.move(Vector2(0, 1))
		elif e.unicode >= 32: k.type(char(e.unicode))
	elif e is InputEventMouseButton and e.pressed and e.button_index == BUTTON_LEFT:
		k.click(k.get_local_mouse_position())

class Keyboard extends Control:
	var con
	var target
	var cb
	var title = ""
	var prefix = ""
	var text = ""
	var caret = 0
	var maxlen = 0
	var secret = false
	var shift = false
	var row = 1
	var col = 0
	var keys = []          # [row][i] = [label, value, width in key units]
	var rects = []         # [row][i] = Rect2, filled when drawn
	const ROWS = ["1234567890", "qwertyuiop", "asdfghjkl'", "zxcvbnm,.?"]
	func _ready():
		mouse_filter = Control.MOUSE_FILTER_STOP
		caret = text.length()
		for r in ROWS:
			var line = []
			for ch in r: line.append([ch, ch, 1.0])
			keys.append(line)
		keys.append([["Shift", "#shift", 1.5], ["@", "@", 1.0], ["_", "_", 1.0], ["-", "-", 1.0], ["Space", " ", 2.5], ["⌫", "#back", 1.5], ["Done", "#done", 1.5]])
	func move(d):
		if d.y != 0:
			var cx = _center(row, col)
			row = int(clamp(row + d.y, 0, keys.size() - 1))
			col = _nearest(row, cx)
		else:
			col = int(fposmod(col + d.x, keys[row].size()))
		con.main.sfx.play("tap", 0.15)
	func _center(r, c):
		var x = 0.0
		for i in range(c): x += keys[r][i][2]
		return x + keys[r][c][2] / 2.0
	func _nearest(r, cx):
		var best = 0
		var bd = 99.0
		for i in range(keys[r].size()):
			var d = abs(_center(r, i) - cx)
			if d < bd:
				bd = d
				best = i
		return best
	func press():
		var v = keys[row][col][1]
		if v == "#shift": shift = not shift
		elif v == "#back": backspace()
		elif v == "#done": con.close_keyboard(true)
		else: type(v.to_upper() if shift else v)
	func type(s):
		if maxlen > 0 and text.length() >= maxlen: return
		text = text.substr(0, caret) + s + text.substr(caret)
		caret += s.length()
		if shift and s != " ": shift = false
		_sync()
	func backspace():
		if caret <= 0: return
		text = text.substr(0, caret - 1) + text.substr(caret)
		caret -= 1
		_sync()
	func _sync():
		if target and is_instance_valid(target):
			target.text = text
	func click(p):
		for r in range(rects.size()):
			for i in range(rects[r].size()):
				if rects[r][i].has_point(p):
					row = r; col = i; press(); return
	func _draw():
		var sz = rect_size
		draw_rect(Rect2(Vector2(), sz), Color(0, 0, 0, 0.55))
		var unit = 64.0
		var gap = 8.0
		var kw = unit * 10 + gap * 9
		var panel = Rect2(Vector2((sz.x - kw) / 2 - 28, sz.y - 470), Vector2(kw + 56, 450))
		draw_style_box(_box(Color(0.09, 0.09, 0.11, 0.97), 22), panel)
		var x0 = panel.position.x + 28
		var y = panel.position.y + 26
		draw_string(G.ifont_sp(12, "m", 3), Vector2(x0, y + 12), title.to_upper(), Color(1, 1, 1, 0.56))
		# the text so far, with a blinking caret
		var shown = text
		if secret:
			shown = ""
			for _i in range(text.length()): shown += "•"
		var f = G.ifont(26, "r")
		var tb = Rect2(Vector2(x0, y + 26), Vector2(kw, 50))
		draw_style_box(_box(Color(1, 1, 1, 0.07), 12), tb)
		var pre = prefix if text != "" or prefix != "" else ""
		var px = x0 + 16
		if pre != "":
			draw_string(f, Vector2(px, y + 61), pre, Color(1, 1, 1, 0.4)); px += f.get_string_size(pre).x
		draw_string(f, Vector2(px, y + 61), shown, Color(1, 1, 1))
		var cxp = px + f.get_string_size(shown.substr(0, caret)).x
		if int(OS.get_ticks_msec() / 500) % 2 == 0: draw_rect(Rect2(Vector2(cxp + 1, y + 38), Vector2(2, 28)), Color(1, 0.62, 0.22))
		if maxlen > 0:
			var cnt = "%d/%d" % [text.length(), maxlen]
			var fc = G.ifont(13, "r")
			draw_string(fc, Vector2(x0 + kw - 14 - fc.get_string_size(cnt).x, y + 58), cnt, Color(1, 1, 1, 0.4))
		# the keys
		y += 92
		rects = []
		var kf = G.ifont(22, "m")
		var sf = G.ifont(15, "s")
		for r in range(keys.size()):
			var x = x0
			var line = []
			for i in range(keys[r].size()):
				var k = keys[r][i]
				var w = unit * k[2] + gap * (k[2] - 1)
				var rc = Rect2(Vector2(x, y), Vector2(w, 52))
				line.append(rc)
				var sel = r == row and i == col
				var special = k[1].begins_with("#") or k[1] == " "
				var bg = Color(1, 1, 1, 0.96) if sel else (Color(1, 1, 1, 0.14) if special else Color(1, 1, 1, 0.08))
				if k[1] == "#shift" and shift and not sel: bg = Color(1, 0.62, 0.22, 0.6)
				if k[1] == "#done" and not sel: bg = Color(1, 0.62, 0.22, 0.9)
				draw_style_box(_box(bg, 10), rc)
				if sel: draw_style_box(_ring(Color(1, 0.62, 0.22), 10), rc.grow(2))
				var lab = k[0]
				if not special and shift: lab = lab.to_upper()
				var ff = kf if lab.length() == 1 else sf
				var tw = ff.get_string_size(lab).x
				var col2 = Color(0.05, 0.05, 0.06) if sel else Color(1, 1, 1)
				if k[1] == "#done" and not sel: col2 = Color(0.05, 0.05, 0.06)
				draw_string(ff, Vector2(rc.position.x + (w - tw) / 2, rc.position.y + (34 if lab.length() == 1 else 32)), lab, col2)
				x += w + gap
			rects.append(line)
			y += 60
		# hints
		var hy = panel.end.y - 34
		var hx = x0
		for h in [["A", "Type"], ["B", "Delete"], ["X", "Space"], ["Y", "Shift"], ["LB", "◀"], ["RB", "▶"], ["MENU", "Done"]]:
			var tex = G.pad_tex(h[0]) if G.has_pad() else null
			if tex == null: continue
			var hh = 24.0
			var ww = hh * tex.get_width() / float(tex.get_height())
			draw_texture_rect(tex, Rect2(Vector2(hx, hy), Vector2(ww, hh)), false)
			var hf = G.ifont(14, "m")
			draw_string(hf, Vector2(hx + ww + 6, hy + 17), h[1], Color(1, 1, 1, 0.7))
			hx += ww + 6 + hf.get_string_size(h[1]).x + 20
	func _box(col, r):
		var sb = StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(r); sb.anti_aliasing = true
		return sb
	func _ring(col, r):
		var sb = StyleBoxFlat.new(); sb.draw_center = false; sb.border_color = col; sb.set_border_width_all(2); sb.set_corner_radius_all(r + 2)
		return sb

func _lbl(parent, text, font, col):
	var l = Label.new(); l.text = text; l.add_font_override("font", font); l.add_color_override("font_color", col); l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
