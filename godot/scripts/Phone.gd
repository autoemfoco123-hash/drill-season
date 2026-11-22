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
var thread = null
var blok_tab = "feed"
var ip_edit = null
const APPS = [["map", "Map", "#3a7bd5"], ["msgs", "Messages", "#34c759"], ["jobs", "Jobs", "#ff9a3c"], ["blok", "Blok", "#ff4f81"], ["camera", "Camera", "#8e8e93"], ["gang", "Gang", "#ff4b3a"],
	["garage", "Garage", "#5ac8fa"], ["style", "Wardrobe", "#c79bff"], ["online", "Online", "#30d158"], ["settings", "Settings", "#636366"], ["pad", "Controller", "#ffd60a"], ["stats", "Stats", "#64d2ff"]]

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
	app = ""; thread = null
	title_lbl.text = G.clock_str() + " · Day " + str(int(G.S.get("day", 1)))
	_clear()
	var grid = GridContainer.new(); grid.columns = 3; grid.add_constant_override("hseparation", 10); grid.add_constant_override("vseparation", 10)
	body.add_child(grid)
	var first = null
	var unread = 0
	for k in G.S["unread"].keys(): unread += int(G.S["unread"][k])
	for a in APPS:
		var label = a[1]
		if a[0] == "msgs" and unread > 0: label += " (%d)" % unread
		var b = _btn(label, self, "show_app", [a[0]], false, grid)
		b.rect_min_size = Vector2(106, 74)
		var n = StyleBoxFlat.new(); n.bg_color = Color(a[2]).darkened(0.35); n.set_corner_radius_all(16)
		var f = n.duplicate(); f.bg_color = Color(a[2]); f.set_border_width_all(2); f.border_color = Color(1, 1, 1)
		b.add_stylebox_override("normal", n); b.add_stylebox_override("hover", f); b.add_stylebox_override("focus", f); b.add_stylebox_override("pressed", f)
		b.add_font_override("font", G.font_s)
		if first == null: first = b
	var tr = main.train.next_train_in()
	_lbl("Next L train at Calder in %d s" % int(tr), G.font_xs, Color(0.62, 0.68, 0.76))
	_btn("Close", self, "close")
	first.grab_focus()

func show_app(id):
	if id == "style":
		close(); main.wardrobe.open(); return
	app = id
	_clear()
	var names = {}
	for a in APPS: names[a[0]] = a[1]
	title_lbl.text = names.get(id, id)
	call("_app_" + id)
	for c in body.get_children():
		if c is Button and not c.disabled:
			c.grab_focus(); break
		if c is GridContainer or c is HBoxContainer:
			for cc in c.get_children():
				if cc is Button and not cc.disabled:
					cc.grab_focus(); return

# ---------- Messages ----------
func _app_msgs():
	var C = G.D["CAST"]
	if thread != null:
		var who = thread
		title_lbl.text = C[who].name
		G.S["unread"][who] = 0
		_btn("‹ All messages", self, "_msgs_back")
		var th = G.S["threads"].get(who, [])
		if th.size() == 0: _lbl("No messages yet.", G.font_s, Color(0.62, 0.68, 0.76))
		for m in th:
			var card = PanelContainer.new()
			var sb = StyleBoxFlat.new(); sb.bg_color = Color(C[who].color).darkened(0.55); sb.set_corner_radius_all(14)
			sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 8; sb.content_margin_bottom = 8
			card.add_stylebox_override("panel", sb)
			var l = Label.new(); l.text = m.text; l.autowrap = true; l.add_font_override("font", G.font_s); l.rect_min_size = Vector2(300, 0)
			card.add_child(l); body.add_child(card)
		return
	var any = false
	for who in ["benny", "kiara", "coach", "vance", "saint", "reyes"]:
		var th2 = G.S["threads"].get(who, [])
		if th2.size() == 0: continue
		any = true
		var last = th2[-1].text
		var u = int(G.S["unread"].get(who, 0))
		var b = _btn("%s%s" % [C[who].name, ("  ● %d new" % u) if u > 0 else ""], self, "_open_thread", [who])
		b.align = Button.ALIGN_LEFT; b.rect_min_size = Vector2(0, 40)
		_lbl("    " + last.substr(0, 60) + ("…" if last.length() > 60 else ""), G.font_xs, Color(0.7, 0.75, 0.82))
		b.add_color_override("font_color", Color(C[who].color).lightened(0.4))
	if not any: _lbl("No messages yet. People text you as the story moves.", G.font_s, Color(0.62, 0.68, 0.76))

func _open_thread(who):
	thread = who; show_app("msgs")
func _msgs_back():
	thread = null; show_app("msgs")

# ---------- Jobs ----------
func _app_jobs():
	var st = main.story
	_lbl("Track a job to put it on your map.", G.font_xs, Color(0.62, 0.68, 0.76))
	for id in st.JOB_IDS:
		var ok = st.job_available(id)
		var cast = G.D["CAST"][st.JOB_GIVER[id]]
		var tracked = G.S.get("tracked") == id
		_lbl(("● " if tracked else "") + st.JOB_TITLE[id] + "  ·  " + cast.name, G.font_m, Color(cast.color) if ok else Color(0.5, 0.54, 0.6))
		_lbl(st.job_desc(id) if ok else st.job_lock(id), G.font_xs, Color(0.85, 0.88, 0.92) if ok else Color(0.5, 0.54, 0.6))
		if ok:
			var cd = st.cd_left(st.JOB_CD[id]) if st.JOB_CD.has(id) else 0.0
			_btn(("Untrack" if tracked else "Track") + "  ·  " + st.job_reward(id), self, "_track", [id])

func _track(id):
	main.story.track_job(id); show_app("jobs")

# ---------- Blok ----------
func _app_blok():
	var row = HBoxContainer.new(); body.add_child(row)
	for t in [["feed", "Feed"], ["me", "Profile"]]:
		var b = _btn(("● " if blok_tab == t[0] else "") + t[1], self, "_blok_tab", [t[0]], false, row)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn("Post a photo", self, "show_app", ["camera"])
	if blok_tab == "me":
		var so = G.S["social"]
		_lbl("@" + str(G.S["name"]), G.font_l, Color(1, 0.7, 0.28))
		_lbl(str(so.get("bio", "")), G.font_s, Color(0.75, 0.8, 0.88))
		_lbl("%d posts   ·   %s followers   ·   %d following" % [so["posts"].size(), G.fmt_money(main.blok.followers()).substr(1), int(so.get("following", 96))], G.font_s)
		for p in so["posts"]: _post_card("@" + str(G.S["name"]), Color(1, 0.7, 0.28), p.caption, p.get("img"), p.likes, p.comments, p.at, p.kind)
		if so["posts"].size() == 0: _lbl("No posts yet. Record a track, shoot a video or take a photo.", G.font_s, Color(0.62, 0.68, 0.76))
		return
	var posts = []
	for p in G.S["social"]["posts"]: posts.append([float(p.at), "@" + str(G.S["name"]), Color(1, 0.7, 0.28), p.caption, p.get("img"), p.likes, p.comments, p.kind])
	for f in G.S["feed"]: posts.append([float(f.get("at", 0)), f.h, Color(0.55, 0.62, 0.7), f.text, null, int(f.get("likes", 0)), [], "text"])
	posts.sort_custom(self, "_by_time")
	for i in range(min(25, posts.size())):
		var q = posts[i]
		_post_card(q[1], q[2], q[3], q[4], q[5], q[6], q[0], q[7])

func _by_time(a, b): return a[0] > b[0]
func _blok_tab(t):
	blok_tab = t; show_app("blok")

func _ago(ms):
	var s2 = max(0, OS.get_unix_time() - ms / 1000.0)
	if s2 < 60: return "now"
	if s2 < 3600: return "%dm" % int(s2 / 60)
	if s2 < 86400: return "%dh" % int(s2 / 3600)
	return "%dd" % int(s2 / 86400)

func _post_card(handle, col, text, img, likes, comments, at, kind):
	var card = PanelContainer.new()
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.09, 0.12); sb.set_corner_radius_all(12)
	sb.content_margin_left = 10; sb.content_margin_right = 10; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	card.add_stylebox_override("panel", sb)
	var v = VBoxContainer.new(); card.add_child(v)
	var h = Label.new(); h.text = handle + "  ·  " + _ago(at); h.add_font_override("font", G.font_xs); h.add_color_override("font_color", col); v.add_child(h)
	var tex = main.blok.texture_for(img)
	if tex:
		var tr = TextureRect.new(); tr.texture = tex; tr.expand = true; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; tr.rect_min_size = Vector2(300, 168); v.add_child(tr)
	elif kind == "track":
		var cover = ColorRect.new(); cover.color = Color(0.45, 0.25, 0.08); cover.rect_min_size = Vector2(300, 60); v.add_child(cover)
		var ct = Label.new(); ct.text = "♪ " + str(text).to_upper(); ct.autowrap = true; ct.add_font_override("font", G.font_m); ct.rect_min_size = Vector2(290, 0); cover.add_child(ct)
	var t = Label.new(); t.text = str(text); t.autowrap = true; t.add_font_override("font", G.font_s); t.rect_min_size = Vector2(300, 0); v.add_child(t)
	var meta = Label.new(); meta.text = "♥ %d   ·   %d comments" % [int(likes), comments.size()]; meta.add_font_override("font", G.font_xs); meta.add_color_override("font_color", Color(0.62, 0.68, 0.76)); v.add_child(meta)
	var last = comments.slice(max(0, comments.size() - 2), comments.size() - 1) if comments.size() > 0 else []
	for c in last:
		var cl = Label.new(); cl.text = c.h + "  " + c.t; cl.autowrap = true; cl.add_font_override("font", G.font_xs); cl.rect_min_size = Vector2(300, 0); v.add_child(cl)
	body.add_child(card)

# ---------- Camera ----------
const CAPTIONS = ["Calder after dark", "the Hawk is out", "booth tonight", "Bishop St forever", "-10 and still outside", "lake effect", "who want smoke? (snowball)", "new fit", "my block", "the L at night"]
func _app_camera():
	_lbl("Point the camera, pick a caption, and the phone hides for the shot. It posts to Blok.", G.font_xs, Color(0.62, 0.68, 0.76))
	var grid = GridContainer.new(); grid.columns = 2; body.add_child(grid)
	for c in CAPTIONS:
		var b = _btn(c, self, "_snap", [c], false, grid); b.rect_min_size = Vector2(164, 40)

func _snap(caption):
	close()
	yield(get_tree().create_timer(0.25), "timeout")
	main.blok.take_photo(caption)
	main.hud.toast("Blok:  Posted \u201c%s\u201d" % caption)

# ---------- Online ----------
func _app_online():
	var net = main.net
	net.lan_listen(true)
	var st = { "offline": "Playing solo", "hosting": "Hosting · %d online" % (net.R.size() + 1), "joining": "Joining…", "online": "Online · %d players" % (net.R.size() + 1) }[net.status]
	_lbl(st, G.font_l, Color(0.48, 0.88, 0.65) if net.online() else Color(1, 0.7, 0.28))
	if net.msg != "": _lbl(net.msg, G.font_xs, Color(0.75, 0.8, 0.88))
	if net.status == "offline":
		_btn("Host a game", self, "_host")
		_sec("Join by IP")
		ip_edit = LineEdit.new(); ip_edit.placeholder_text = "192.168.0.10"; ip_edit.text = str(G.S["settings"].get("lastIp", "")); ip_edit.add_font_override("font", G.font_m)
		body.add_child(ip_edit)
		_btn("Join", self, "_join")
		_sec("Games nearby (same Wi-Fi)")
		if net.LAN.size() == 0: _lbl("None found yet. Ask a friend to host, then press Refresh.", G.font_xs, Color(0.62, 0.68, 0.76))
		for k in net.LAN.keys():
			var g = net.LAN[k]
			_btn("@%s · %d playing · %s" % [g.name, g.players, g.ip], self, "_join_lan", [g.ip, g.port])
		_btn("Refresh", self, "show_app", ["online"])
	else:
		if net.status == "hosting":
			_lbl("Your address: " + PoolStringArray(net.my_ips()).join(", ") + "  ·  port %d (UDP)" % net.PORT, G.font_xs, Color(0.85, 0.88, 0.92))
		_sec("Players")
		for r in net.R.values():
			var gt = (" [" + str(r.gang[2]) + "]") if typeof(r.gang) == TYPE_ARRAY else ""
			var can = typeof(G.S.get("gang")) == TYPE_DICTIONARY and not net._same_gang(r)
			_btn("@" + r.name + gt + ("  ·  Invite to gang" if can else ""), self, "_invite", [r.id], not can)
		if net.R.size() == 0: _lbl("Waiting for players…", G.font_xs, Color(0.62, 0.68, 0.76))
		_btn("Leave", self, "_leave_net")
	if net.invites.size() > 0:
		_sec("Gang invites")
		for i in range(net.invites.size()):
			var inv = net.invites[i]
			_btn("Join [%s] %s" % [inv.g[2], inv.g[1]], self, "_accept", [i])
	_lbl("Over the internet the host opens UDP port %d on their router. Online works between copies of this Godot version; the browser version has its own rooms." % net.PORT, G.font_xs, Color(0.5, 0.56, 0.64))

func _host():
	main.net.host(); show_app("online")
func _join():
	var ip = ip_edit.text if ip_edit else ""
	G.S["settings"]["lastIp"] = ip
	main.net.join(ip); show_app("online")
func _join_lan(ip, port):
	main.net.join(ip, port); show_app("online")
func _invite(id):
	main.net.invite(id)
func _accept(i):
	main.net.accept_invite(i); show_app("online")
func _leave_net():
	main.net.leave(); show_app("online")

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
