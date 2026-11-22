extends Node
# Your phone: Map, Gang, Garage, Style, Settings, Controller and Stats.
# Mouse, keyboard (Tab to close) or a controller (D-pad, A, B) all work.

var main
var layer
var panel
var body
var title_lbl
var app = ""
var gang_tab = "crew"
var form = { "name": "", "tag": "", "color": 0 }
var msg = ""

class BigMap extends Control:
	var main
	func _draw():
		var s = rect_size
		draw_rect(Rect2(Vector2(), s), Color(0.06, 0.08, 0.11))
		var H = float(G.D["MAP_HALF"])
		var k = min(s.x, s.y) / (H * 2.1)
		var o = s / 2
		draw_rect(Rect2(o + Vector2(G.D["LAKE_X"], -H) * k, Vector2(H - G.D["LAKE_X"], H * 2) * k), Color(0.45, 0.58, 0.68, 0.6))
		for x in G.D["XL"]: draw_line(o + Vector2(x, -H) * k, o + Vector2(x, H) * k, Color(0.32, 0.35, 0.4), 4)
		for z in G.D["ZL"]: draw_line(o + Vector2(-H, z) * k, o + Vector2(G.D["ROAD_X_END"], z) * k, Color(0.32, 0.35, 0.4), 4)
		# a dot for every place, a name only where it doesn't collide with another name
		var used = []
		for key in G.D["LOC"].keys():
			var L = G.D["LOC"][key]
			if not L.has("name") or key in ["storeFront", "stairs"]: continue
			var p = o + Vector2(L.x, L.z) * k
			draw_circle(p, 3, Color(1, 0.7, 0.28))
			var sz = G.font_s.get_string_size(L.name)
			var r = Rect2(p + Vector2(5, -sz.y * 0.6), sz)
			if r.end.x > s.x: r.position.x = p.x - 5 - sz.x
			var free = true
			for u in used:
				if u.intersects(r): free = false
			if free:
				used.append(r)
				draw_string(G.font_s, Vector2(r.position.x, p.y + 4), L.name, Color(0.85, 0.88, 0.92))
		var P = main.player
		draw_circle(o + Vector2(P.pos.x, P.pos.z) * k, 6, Color(0.48, 0.88, 0.65))
		for cp in main.police.COPS:
			draw_circle(o + Vector2(cp.pos.x, cp.pos.z) * k, 3, Color(0.3, 0.5, 1))

func setup(m):
	main = m
	layer = CanvasLayer.new(); layer.layer = 5; add_child(layer)
	panel = PanelContainer.new()
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.06, 0.09, 0.97); sb.set_corner_radius_all(28); sb.border_color = Color(0.2, 0.22, 0.26); sb.set_border_width_all(4)
	sb.content_margin_left = 18; sb.content_margin_right = 18; sb.content_margin_top = 16; sb.content_margin_bottom = 16
	panel.add_stylebox_override("panel", sb)
	panel.anchor_left = 1; panel.anchor_right = 1; panel.anchor_top = 0.5; panel.anchor_bottom = 0.5
	panel.margin_left = -430; panel.margin_right = -30; panel.margin_top = -330; panel.margin_bottom = 330
	layer.add_child(panel)
	var v = VBoxContainer.new(); panel.add_child(v)
	var head = HBoxContainer.new(); v.add_child(head)
	var back = Button.new(); back.text = "‹ Home"; back.flat = true; back.add_font_override("font", G.font_m); back.connect("pressed", self, "_home")
	head.add_child(back)
	title_lbl = Label.new(); title_lbl.add_font_override("font", G.font_m); title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title_lbl.align = Label.ALIGN_CENTER
	head.add_child(title_lbl)
	var sc = ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.scroll_horizontal_enabled = false
	v.add_child(sc)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	panel.visible = false

func open(which = ""):
	if G.MODE != "play" and G.MODE != "phone" and G.MODE != "menu": return
	main.hud.close_menu()
	G.MODE = "phone"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	panel.visible = true
	main.sfx.play("lock", 0.5)
	if which != "": show_app(which)
	else: _home()

func close():
	panel.visible = false
	if G.MODE == "phone": G.MODE = "play"
	main.sfx.play("lock", 0.5)

func _unhandled_input(e):
	if not panel.visible: return
	if e.is_action_pressed("phone") or e.is_action_pressed("pause") or (e.is_action_pressed("ui_cancel") and app == ""):
		close(); get_tree().set_input_as_handled()
	elif e.is_action_pressed("ui_cancel"):
		_home(); get_tree().set_input_as_handled()

func update(_dt):
	if panel.visible and app == "map":
		var m = body.get_node_or_null("BigMap")
		if m: m.update()

func _clear():
	for c in body.get_children():
		body.remove_child(c); c.queue_free()

func _lbl(text, font = null, col = Color(0.93, 0.96, 1)):
	var l = Label.new(); l.text = text; l.autowrap = true
	l.add_font_override("font", font if font else G.font_s); l.add_color_override("font_color", col)
	body.add_child(l)
	return l

func _btn(text, target, method, args = [], disabled = false, parent = null):
	var b = Button.new(); b.text = text; b.add_font_override("font", G.font_m); b.disabled = disabled
	b.clip_text = true   # long labels must not widen the phone
	b.connect("pressed", target, method, args)
	(parent if parent else body).add_child(b)
	return b

func _sec(text):
	_lbl(text.to_upper(), G.font_s, Color(1, 0.7, 0.28))

func _home():
	app = ""
	title_lbl.text = G.clock_str() + " · Day " + str(int(G.S.get("day", 1)))
	_clear()
	var grid = GridContainer.new(); grid.columns = 2
	body.add_child(grid)
	var first = null
	for a in [["map", "Map"], ["gang", "Gang"], ["garage", "Garage"], ["style", "Style"], ["settings", "Settings"], ["pad", "Controller"], ["stats", "Stats"]]:
		var b = _btn(a[1], self, "show_app", [a[0]], false, grid)
		b.rect_min_size = Vector2(164, 64)
		if first == null: first = b
	_btn("Close", self, "close")
	first.grab_focus()

func show_app(id):
	app = id
	_clear()
	var names = { "map": "Map", "gang": "Gang", "garage": "Garage", "style": "Style", "settings": "Settings", "pad": "Controller", "stats": "Stats" }
	title_lbl.text = names.get(id, id)
	call("_app_" + id)
	for c in body.get_children():
		if c is Button and not c.disabled:
			c.grab_focus(); break
		if c is GridContainer or c is HBoxContainer:
			for cc in c.get_children():
				if cc is Button and not cc.disabled:
					cc.grab_focus(); return

func _app_map():
	var m = BigMap.new(); m.name = "BigMap"; m.main = main; m.rect_min_size = Vector2(340, 470)
	body.add_child(m)
	_lbl("You: " + main.hud.street_name(main.player.pos), G.font_s, Color(0.48, 0.88, 0.65))

func _app_gang():
	var g = G.S.get("gang")
	var GA = main.gang
	if g == null:
		_lbl("Start a gang", G.font_l)
		_lbl("Pick a name, a tag and a colour, then recruit people off the street (they wear a RECRUIT tag; walk up and press E) or from this app. Keep it made up: no real gangs.", G.font_s, Color(0.66, 0.72, 0.78))
		_sec("Name")
		var n = LineEdit.new(); n.text = form.name; n.max_length = 18; n.placeholder_text = "e.g. Lakeshore Kings"; n.connect("text_changed", self, "_form", ["name"]); body.add_child(n)
		_sec("Tag")
		var t = LineEdit.new(); t.text = form.tag; t.max_length = 4; t.placeholder_text = "e.g. LSK"; t.connect("text_changed", self, "_form", ["tag"]); body.add_child(t)
		_sec("Colour")
		var row = HBoxContainer.new(); body.add_child(row)
		var cols = G.D["GANG_COLORS"]
		for i in range(cols.size()):
			var b = Button.new(); b.rect_min_size = Vector2(36, 36); b.text = "●" if form.color == i else ""
			var sbx = StyleBoxFlat.new(); sbx.bg_color = Color(cols[i]); sbx.set_corner_radius_all(18)
			b.add_stylebox_override("normal", sbx); b.add_stylebox_override("hover", sbx); b.add_stylebox_override("focus", sbx)
			b.connect("pressed", self, "_pick_color", [i]); row.add_child(b)
		if msg != "": _lbl(msg, G.font_s, Color(1, 0.6, 0.54))
		_btn("Start the gang", self, "_make_gang")
		return
	_lbl("[%s] %s" % [g.tag, g.name], G.font_l, GA.gang_color())
	_lbl("%s · Rep %d · %d/%d recruits" % ["You run it" if g.get("role", "leader") == "leader" else "Member", int(g.get("rep", 0)), G.S["recruits"].size(), GA.MAX_RECRUITS], G.font_s, Color(0.66, 0.72, 0.78))
	var tabs = HBoxContainer.new(); body.add_child(tabs)
	for t2 in [["crew", "Crew"], ["hire", "Recruit"], ["types", "Types"]]:
		var tb = _btn(t2[1], self, "_tab", [t2[0]], false, tabs)
		tb.flat = gang_tab != t2[0]
	if gang_tab == "crew":
		if G.S["recruits"].size() == 0: _lbl("Nobody yet. Walk up to people marked RECRUIT and press E, or use the Recruit tab.", G.font_s, Color(0.66, 0.72, 0.78))
		for r in G.S["recruits"]:
			var T = G.D["RTYPES"][r.type]
			var hurt = float(r.get("hurtUntil", 0)) > G.S.get("playTime", 0)
			_lbl("%s %s · %s · %s" % [T.icon, r.name, T.name, "At Calder General" if hurt else ("With you" if r.get("with", false) else "Holding the block")], G.font_m, Color(T.col))
			var row2 = HBoxContainer.new(); body.add_child(row2)
			if not hurt: _btn("Send home" if r.get("with", false) else "Call", self, "_with", [r], false, row2)
			_btn("Let go", self, "_drop", [r], false, row2)
		_btn("Leave the gang", self, "_leave")
	elif gang_tab == "hire":
		for c in GA.candidates():
			var T2 = G.D["RTYPES"][c.type]
			var why = GA.can_recruit(c.type)
			_lbl("%s %s · %s — %s" % [T2.icon, c.name, T2.name, T2.perk], G.font_s, Color(T2.col))
			_btn(why if why != "" else ("Hire for " + G.fmt_money(T2.cost)), self, "_hire", [c], why != "")
	else:
		for k in G.D["RTYPES"].keys():
			var T3 = G.D["RTYPES"][k]
			_lbl("%s %s · %s%s" % [T3.icon, T3.name, G.fmt_money(T3.cost), (" · Buzz %d" % T3.buzz) if T3.buzz > 0 else ""], G.font_m, Color(T3.col))
			_lbl(T3.perk, G.font_s, Color(0.66, 0.72, 0.78))

func _form(text, key):
	form[key] = text
func _pick_color(i):
	form.color = i; show_app("gang")
func _make_gang():
	msg = main.gang.create(form.name, form.tag, form.color)
	show_app("gang")
func _tab(t):
	gang_tab = t; show_app("gang")
func _with(r):
	main.gang.set_with(r, not r.get("with", false)); show_app("gang")
func _drop(r):
	main.gang.drop(r); show_app("gang")
func _hire(c):
	if main.gang.hire(c.type, c.seed, c.name): main.hud.toast(c.name + " is on the way to you")
	show_app("gang")
func _leave():
	main.gang.leave(); show_app("gang")

func _app_garage():
	_sec("Your cars")
	for i in range(G.S["garage"].size()):
		var c = G.S["garage"][i]
		_btn("%s · bring it here" % G.D["CAR_SPECS"][c.model].name, self, "_bring", [i])
	_sec("Marrow Motors")
	for model in ["sedan", "suv", "pickup", "van", "coupe"]:
		var sp = G.D["CAR_SPECS"][model]
		var ok = G.S["cash"] >= sp.price and G.S["buzz"] >= sp.buzz
		_btn("%s · %s%s" % [sp.name, G.fmt_money(sp.price), (" · Buzz %d" % sp.buzz) if sp.buzz > 0 else ""], self, "_buy_car", [model], not ok)

func _bring(i):
	var g = G.S["garage"][i]
	G.S["garage"].remove(i); G.S["garage"].push_front(g)
	main.vehicles.spawn_owned_car()
	main.hud.toast(G.D["CAR_SPECS"][g.model].name + " is parked nearby")
	close()

func _buy_car(model):
	var sp = G.D["CAR_SPECS"][model]
	if G.S["cash"] < sp.price: return
	G.S["cash"] -= sp.price
	G.S["garage"].push_front({ "model": model, "color": G.pick(G.D["CAR_PAINTS"]) })
	main.vehicles.spawn_owned_car()
	main.hud.banner(sp.name, "Yours. Parked nearby")
	G.save_game(); close()

func _app_style():
	_lbl("Your look is saved and comes with you.", G.font_s, Color(0.66, 0.72, 0.78))
	var grid = GridContainer.new(); grid.columns = 2; body.add_child(grid)
	var P = G.D["SKIN"]["PRESETS"]
	for i in range(P.size()):
		var b = _btn(P[i][0], self, "_preset", [i], false, grid)
		b.rect_min_size = Vector2(164, 44)
	_btn("Random look", self, "_random_look")

func _preset(i):
	G.S["skin"] = G.preset_skin(i)
	main.player._build_body(); main.player.vm_key = ""
	main.hud.toast(G.D["SKIN"]["PRESETS"][i][0])
func _random_look():
	G.S["skin"] = G.random_skin()
	main.player._build_body(); main.player.vm_key = ""

func _app_settings():
	var st = G.S["settings"]
	_slider("Look speed", st.get("sens", 1.0), 0.3, 2.5, 0.05, "sens")
	_slider("Volume", st.get("vol", 0.8), 0, 1, 0.05, "vol")
	_slider("Music", st.get("music", 0.85), 0, 1, 0.05, "music")
	_slider("Field of view (first person)", st.get("fov", 70), 60, 95, 1, "fov")
	_btn("Invert look Y: " + ("on" if st.get("invertY", false) else "off"), self, "_toggle", ["invertY"])
	_btn("Camera: " + ("first person" if st.get("fp", false) else "third person"), self, "_toggle", ["fp"])
	var qn = { "high": "High (shadows, 4 lamp lights)", "medium": "Medium (2 lamp lights)" }
	_btn("Graphics: " + qn.get(st.get("quality", "low"), "Fast (for old GPUs)"), self, "_quality")
	_btn("Full screen: " + ("on" if OS.window_fullscreen else "off"), self, "_fullscreen")
	_sec("Progress")
	_lbl("Bring your progress from the web game: on the web, open the phone, then Settings, then Export my progress. The file lands in Downloads.", G.font_s, Color(0.66, 0.72, 0.78))
	_btn("Import web progress", self, "_import")
	if msg != "": _lbl(msg, G.font_s, Color(1, 0.7, 0.28))
	_btn("Save & exit to title", self, "_exit")

func _slider(label, v, a, b, step, key):
	_lbl(label)
	var s = HSlider.new(); s.min_value = a; s.max_value = b; s.step = step; s.value = v; s.rect_min_size = Vector2(200, 24); s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.connect("value_changed", self, "_set", [key])
	body.add_child(s)
func _set(v, key):
	if key == "padsens": G.S["settings"]["pad"]["sens"] = v
	else: G.S["settings"][key] = v
func _toggle(key):
	G.S["settings"][key] = not G.S["settings"].get(key, false); show_app("settings")
func _quality():
	var order = ["low", "medium", "high"]
	var q = order[(order.find(G.S["settings"].get("quality", "low")) + 1) % 3]
	G.S["settings"]["quality"] = q; main.set_quality(q); show_app("settings")
func _fullscreen():
	OS.window_fullscreen = not OS.window_fullscreen; show_app("settings")
func _import():
	var err = G.import_web_save()
	if err == "":
		close()
		main.start_game(G.S)
		main.hud.banner("Progress imported", "@" + G.S["name"])
		msg = ""
	else:
		msg = err; show_app("settings")
func _exit():
	close(); main.exit_to_title()

func _app_pad():
	var pads = Input.get_connected_joypads()
	if pads.size() == 0:
		_lbl("No controller found. Plug one in or pair it over Bluetooth; Xbox, PlayStation and most others work.", G.font_s, Color(1, 0.7, 0.28))
	for i in pads:
		_lbl(Input.get_joy_name(i), G.font_m, Color(0.48, 0.88, 0.65))
	_slider("Stick look speed", G.S["settings"]["pad"].get("sens", 1.0), 0.4, 2.5, 0.05, "padsens")
	for row in [["Move · look", "Left stick · right stick"], ["Shoot or punch · aim or block", "RT · LT"], ["Jump · crouch · reload", "A · B · X"], ["Car · use · next weapon", "Y · RB · LB"], ["Sprint · first person", "L3 · R3"], ["Phone · bandage · wave · middle finger", "D-pad up · down · left · right"], ["Settings · map", "Menu · View"], ["Drive: gas · brake · handbrake", "RT · LT · A"]]:
		_lbl(row[0] + ":  " + row[1], G.font_s)

func _app_stats():
	var S = G.S
	for r in [["Cash", G.fmt_money(S["cash"])], ["Buzz", str(int(S["buzz"]))], ["Heat", str(int(S["heat"]))], ["Shots fired", str(S["stats"].get("shots", 0))], ["Punches", str(S["stats"].get("punches", 0))], ["Knockouts", str(S["stats"].get("knockouts", 0))], ["Cars taken", str(S["stats"].get("carsTaken", 0))], ["Times busted", str(S["stats"].get("busted", 0))], ["Distance walked", "%.1f km" % (S["stats"].get("dist", 0) / 1000.0)], ["Tracks (web)", str(S["stats"].get("tracks", 0))]]:
		_lbl(r[0] + ":  " + r[1], G.font_m)
