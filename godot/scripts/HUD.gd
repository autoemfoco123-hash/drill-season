extends Node
# The heads-up display: weather and time, money, Buzz and Heat, wanted stars, health,
# weapon, street, minimap, name tags, prompts, toasts, banners, subtitles and menus.

var main
var layer
var root
var lbl_temp
var lbl_time
var lbl_cash
var bar_buzz
var bar_heat
var bar_hp
var lbl_stars
var lbl_weap
var lbl_street
var lbl_prompt
var lbl_banner
var lbl_banner_sub
var lbl_sub
var hit
var hurt
var minimap
var tags
var toasts
var menu_box = null
var menu_items = []
var banner_t = 0.0
var sub_t = 0.0
var hit_t = 0.0
var hurt_v = 0.0
var lake_cd = 0.0

class MiniMap extends Control:
	var main
	func _draw():
		var R = rect_size.x / 2
		var P = main.player
		var zoom = 1.25
		draw_circle(Vector2(R, R), R, Color(0.06, 0.08, 0.11, 0.85))
		var yaw = P.cam_yaw
		var c = cos(yaw)
		var s = sin(yaw)
		for x in G.D["XL"]:
			_road(Vector3(x, 0, -260), Vector3(x, 0, 260), P, c, s, R, zoom)
		for z in G.D["ZL"]:
			_road(Vector3(-260, 0, z), Vector3(G.D["ROAD_X_END"], 0, z), P, c, s, R, zoom)
		for v in main.vehicles.VEH:
			if v.dead: continue
			var col = Color(0.48, 0.88, 0.65) if v == main.vehicles.own_car else (Color(1, 0.25, 0.25) if v.cop and int(G.REAL_T * 4) % 2 == 0 else (Color(0.25, 0.45, 1) if v.cop else Color(0.55, 0.6, 0.66)))
			_dot(v.pos, col, 2.6 if not v.cop else 3.5, P, c, s, R, zoom)
		for e in main.crews.ENEMIES:
			if not e.is_down(): _dot(e.pos, Color(1, 0.3, 0.23), 3, P, c, s, R, zoom)
		for cp in main.police.COPS:
			if not cp.is_down(): _dot(cp.pos, Color(0.3, 0.5, 1), 3, P, c, s, R, zoom)
		for f in main.gang.FOL:
			if not f.riding: _dot(f.pos, main.gang.gang_color(), 2.6, P, c, s, R, zoom)
		draw_colored_polygon(PoolVector2Array([Vector2(R, R - 7), Vector2(R - 5, R + 5), Vector2(R + 5, R + 5)]), Color(1, 0.7, 0.28))
		draw_arc(Vector2(R, R), R - 1, 0, TAU, 48, Color(1, 1, 1, 0.25), 2)
	func _xf(p, P, c, s, R, zoom):
		var dx = (p.x - P.pos.x) * zoom
		var dz = (p.z - P.pos.z) * zoom
		# rotate so your facing points up
		return Vector2(R + (dx * c - dz * s), R + (dx * s + dz * c))
	func _road(a, b, P, c, s, R, zoom):
		var pa = _xf(a, P, c, s, R, zoom)
		var pb = _xf(b, P, c, s, R, zoom)
		# clip the segment to the round map
		var C = Vector2(R, R)
		var rr = R - 2 - 3.0 * zoom
		var d = pb - pa
		var f = pa - C
		var A = d.dot(d)
		if A < 0.0001: return
		var B = 2 * f.dot(d)
		var Cc = f.dot(f) - rr * rr
		var disc = B * B - 4 * A * Cc
		if disc <= 0: return
		var sq = sqrt(disc)
		var t0 = max(0.0, (-B - sq) / (2 * A))
		var t1 = min(1.0, (-B + sq) / (2 * A))
		if t1 <= t0: return
		draw_line(pa + d * t0, pa + d * t1, Color(0.32, 0.35, 0.4), 6.0 * zoom)
	func _dot(p, col, r, P, c, s, R, zoom):
		var q = _xf(p, P, c, s, R, zoom)
		if q.distance_to(Vector2(R, R)) < R - 3: draw_circle(q, r, col)

# name tags drawn over people's heads
class Tags extends Control:
	var main
	func _draw():
		var cam = main.camera
		var P = main.player
		var items = []
		for p in main.peds.PEDS:
			if p.rq != null and p.state == "walk" and not P.car and p.pos.distance_to(P.pos) < 14:
				items.append([p.pos, p.rq_name, "RECRUIT · " + G.D["RTYPES"][p.rq].name.to_upper(), Color(G.D["RTYPES"][p.rq].col)])
		for f in main.gang.FOL:
			if not f.riding and f.state != "down": items.append([f.pos, f.rec.name, G.D["RTYPES"][f.rec.type].name.to_upper(), main.gang.gang_color()])
		for cp in main.police.COPS:
			if not cp.is_down(): items.append([cp.pos, "POLICE", "", Color(0.44, 0.78, 1)])
		for e in main.crews.ENEMIES:
			if not e.is_down() and e.crew.state != "leave": items.append([e.pos, e.name, "", Color(1, 0.3, 0.23)])
		for it in items:
			var w = it[0] + Vector3(0, 2.15, 0)
			if cam.is_position_behind(w): continue
			var d = cam.global_transform.origin.distance_to(w)
			if d > 40: continue
			var sp = cam.unproject_position(w)
			var f = G.font_s
			var tw = f.get_string_size(it[1]).x
			draw_rect(Rect2(sp.x - tw / 2 - 10, sp.y - 12, tw + 20, 20), Color(0.02, 0.04, 0.07, 0.72))
			draw_circle(Vector2(sp.x - tw / 2 - 4, sp.y - 2), 3, it[3])
			draw_string(f, Vector2(sp.x - tw / 2 + 2, sp.y + 3), it[1], Color(0.93, 0.96, 1))
			if it[2] != "":
				var sw = f.get_string_size(it[2]).x
				draw_string(f, Vector2(sp.x - sw / 2, sp.y + 22), it[2], it[3])

func setup(m):
	main = m
	layer = CanvasLayer.new(); add_child(layer)
	root = Control.new(); root.anchor_right = 1; root.anchor_bottom = 1; root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	tags = Tags.new(); tags.main = main; tags.anchor_right = 1; tags.anchor_bottom = 1; tags.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(tags)
	hurt = ColorRect.new(); hurt.anchor_right = 1; hurt.anchor_bottom = 1; hurt.color = Color(0.55, 0, 0, 0); hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hurt)
	lbl_temp = _label(G.font_l, Vector2(22, 14))
	lbl_time = _label(G.font_s, Vector2(24, 50), Color(0.66, 0.72, 0.78))
	lbl_cash = _label(G.font_l, Vector2(0, 14), Color(0.48, 0.88, 0.65), true)
	bar_buzz = _bar(Vector2(-230, 60), Color(1, 0.7, 0.28), "BUZZ")
	bar_heat = _bar(Vector2(-230, 80), Color(1, 0.3, 0.23), "HEAT")
	bar_hp = _bar(Vector2(-230, 100), Color(0.85, 0.9, 0.95), "HEALTH")
	lbl_stars = _label(G.font_m, Vector2(0, 122), Color(1, 0.85, 0.3), true)
	lbl_weap = _label(G.font_l, Vector2(0, -56), Color(0.93, 0.96, 1), true, true)
	lbl_street = _label(G.font_m, Vector2(206, -62), Color(0.93, 0.96, 1), false, true)
	minimap = MiniMap.new(); minimap.main = main
	minimap.anchor_top = 1; minimap.anchor_bottom = 1; minimap.margin_left = 18; minimap.margin_top = -198; minimap.margin_right = 198; minimap.margin_bottom = -18
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)
	lbl_prompt = _center_label(G.font_m, -120)
	lbl_sub = _center_label(G.font_m, -170)
	lbl_banner = _center_label(G.font_xl, 0); lbl_banner.anchor_top = 0; lbl_banner.anchor_bottom = 0; lbl_banner.margin_top = 120; lbl_banner.margin_bottom = 200
	lbl_banner_sub = _center_label(G.font_m, 0); lbl_banner_sub.anchor_top = 0; lbl_banner_sub.anchor_bottom = 0; lbl_banner_sub.margin_top = 200; lbl_banner_sub.margin_bottom = 230
	hit = _center_label(G.font_l, 0); hit.anchor_top = 0.5; hit.anchor_bottom = 0.5; hit.margin_top = -16; hit.margin_bottom = 16; hit.text = "✕"; hit.modulate.a = 0
	var cross = _center_label(G.font_m, 0); cross.anchor_top = 0.5; cross.anchor_bottom = 0.5; cross.margin_top = -12; cross.margin_bottom = 12; cross.text = "·"; cross.name = "Cross"
	toasts = VBoxContainer.new(); toasts.anchor_left = 0.5; toasts.anchor_right = 0.5; toasts.margin_left = -230; toasts.margin_right = 230; toasts.margin_top = 14
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)
	hide()

func _label(font, pos, col = Color(0.93, 0.96, 1), right = false, bottom = false):
	var l = Label.new()
	l.add_font_override("font", font)
	l.add_color_override("font_color", col)
	l.add_color_override("font_color_shadow", Color(0, 0, 0, 0.6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if right:
		l.anchor_left = 1; l.anchor_right = 1; l.margin_left = -420; l.margin_right = -22; l.align = Label.ALIGN_RIGHT
	else:
		l.margin_left = pos.x; l.margin_right = pos.x + 420
	if bottom:
		l.anchor_top = 1; l.anchor_bottom = 1; l.margin_top = pos.y; l.margin_bottom = pos.y + 40
	else:
		l.margin_top = pos.y; l.margin_bottom = pos.y + 40
	root.add_child(l)
	return l

func _center_label(font, y):
	var l = Label.new()
	l.add_font_override("font", font)
	l.add_color_override("font_color", Color(0.93, 0.96, 1))
	l.add_color_override("font_color_shadow", Color(0, 0, 0, 0.7))
	l.align = Label.ALIGN_CENTER; l.autowrap = true
	l.anchor_left = 0; l.anchor_right = 1; l.anchor_top = 1; l.anchor_bottom = 1
	l.margin_top = y; l.margin_bottom = y + 40; l.margin_left = 120; l.margin_right = -120
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l

func _bar(pos, col, name):
	var bg = ColorRect.new(); bg.color = Color(1, 1, 1, 0.12)
	bg.anchor_left = 1; bg.anchor_right = 1; bg.margin_left = pos.x + 70; bg.margin_right = -22; bg.margin_top = pos.y + 6; bg.margin_bottom = pos.y + 10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var fg = ColorRect.new(); fg.color = col; fg.anchor_bottom = 1; fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fg)
	var l = Label.new(); l.text = name; l.add_font_override("font", G.font_s); l.add_color_override("font_color", col)
	l.margin_left = -70; l.margin_top = -8
	bg.add_child(l)
	return fg

func show():
	root.visible = true
func hide():
	root.visible = false

func update(dt):
	if not root.visible: return
	var S = G.S
	var P = main.player
	var temp = int(round(lerp(16, 6, main.DN.night)))
	lbl_temp.text = "%d°F" % temp
	lbl_time.text = "%s · Day %d · feels %d°" % [G.clock_str(), int(S.get("day", 1)), temp - 12]
	lbl_cash.text = G.fmt_money(S["cash"])
	bar_buzz.anchor_right = clamp(S["buzz"] / 100.0, 0, 1)
	bar_heat.anchor_right = clamp(S["heat"] / 100.0, 0, 1)
	bar_hp.anchor_right = clamp(S["health"] / 100.0, 0, 1)
	var lv = main.police.level
	var stars = ""
	if lv > 0:
		for i in range(5): stars += "★" if i < lv else "☆"
	lbl_stars.text = stars
	if S.get("fists", false):
		lbl_weap.text = "FISTS" + ("  · GUARD UP" if P.aiming else "")
	else:
		var g = S["guns"][S["cur"]]
		lbl_weap.text = "%s   %d / %d%s" % [G.D["WEAPONS"][S["cur"]].short, g.mag, g.res, "   RELOADING" if P.reload_t > 0 else ""]
	if P.car:
		lbl_weap.text = "%d MPH" % int(abs(P.car.speed) * 2.237)
	lbl_street.text = street_name(P.pos)
	lbl_prompt.text = _prompt()
	banner_t -= dt
	lbl_banner.modulate.a = clamp(banner_t * 2, 0, 1); lbl_banner_sub.modulate.a = lbl_banner.modulate.a
	sub_t -= dt
	lbl_sub.modulate.a = clamp(sub_t * 2, 0, 1)
	hit_t -= dt
	hit.modulate.a = clamp(hit_t * 4, 0, 1)
	hurt_v = max(hurt_v * exp(-dt * 1.8), 0.25 if S["health"] < 30 else 0.0)
	hurt.color.a = clamp(hurt_v * 0.5, 0, 0.6)
	lake_cd -= dt
	minimap.update()
	tags.update()

func _key(k, pad):
	if Input.get_connected_joypads().size() > 0: return "[" + pad + "]"
	return "[" + k + "]"

func _prompt():
	var P = main.player
	if G.MODE != "play" or P.car: return ""
	var so = main.crews.active_standoff()
	if so: return "Hold %s to walk away · aim to engage" % _key("E", "RB")
	var it = P.nearest_interact()
	if it: return "%s %s" % [_key("E", "RB"), _interact_label(it)]
	var rp = main.gang.nearest_recruit_ped()
	if rp: return "%s Talk to %s · %s" % [_key("E", "RB"), rp.rq_name, G.D["RTYPES"][rp.rq].name]
	var v = main.vehicles.nearest_car(P.pos, 3.2)
	if v:
		var what = "Get in your " if v.owned else ("Carjack the " if v.driver == "ai" else ("Locked · " if v.locked else "Break into the "))
		return "%s %s%s" % [_key("F", "Y"), what, v.sp.name]
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED and Input.get_connected_joypads().size() == 0 and fmod(G.REAL_T, 8) < 5:
		return "Click to control the camera"
	return ""

func street_name(p):
	var XL = G.D["XL"]
	var ZL = G.D["ZL"]
	var WE = G.D["WALK_EDGE"]
	for k in range(XL.size()):
		if abs(p.x - XL[k]) < WE + 1:
			for j in range(ZL.size()):
				if abs(p.z - ZL[j]) < WE + 1: return G.D["XN"][k] + " & " + G.D["ZN"][j]
			return G.D["XN"][k]
	for j in range(ZL.size()):
		if abs(p.z - ZL[j]) < WE + 1: return G.D["ZN"][j]
	if p.x > -85 and p.x < -10 and p.z > 10 and p.z < 80: return "Calder Park"
	if p.x > G.D["LAKE_X"]: return "Frozen lake"
	if p.x > G.D["SHORE_X"] + WE: return "Lakefront"
	if p.x < XL[0] - WE: return "Kessler rail yard"
	return "Alley"

func banner(t, sub = ""):
	lbl_banner.text = t; lbl_banner_sub.text = sub; banner_t = 2.3
	main.sfx.play("whoosh", 0.22, 1.2)

func say(who, text):
	lbl_sub.text = who + "   " + text; sub_t = 3.8

func toast(text):
	var l = Label.new()
	l.text = text; l.add_font_override("font", G.font_m); l.align = Label.ALIGN_CENTER; l.autowrap = true
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.04, 0.06, 0.09, 0.85); sb.set_corner_radius_all(12); sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	l.add_stylebox_override("normal", sb)
	toasts.add_child(l)
	while toasts.get_child_count() > 2:
		var old = toasts.get_child(0)
		toasts.remove_child(old); old.queue_free()
	main.sfx.play("notif", 0.4)
	yield(get_tree().create_timer(4.6), "timeout")
	if is_instance_valid(l): l.queue_free()

func hitmarker(head):
	hit_t = 0.25; hit.add_color_override("font_color", Color(1, 0.3, 0.23) if head else Color(1, 1, 1))

func hurt_flash(dmg):
	hurt_v = min(1.0, hurt_v + 0.25 + dmg * 0.03)

# ---------- menus (places, recruits): keyboard, mouse or controller ----------
func menu(eyebrow, title, sub, items):
	close_menu()
	G.MODE = "menu"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	menu_box = PanelContainer.new()
	var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.07, 0.1, 0.94); sb.set_corner_radius_all(16)
	sb.content_margin_left = 24; sb.content_margin_right = 24; sb.content_margin_top = 18; sb.content_margin_bottom = 18
	menu_box.add_stylebox_override("panel", sb)
	menu_box.anchor_left = 0.5; menu_box.anchor_right = 0.5; menu_box.anchor_top = 0.5; menu_box.anchor_bottom = 0.5
	menu_box.margin_left = -260; menu_box.margin_right = 260; menu_box.margin_top = -200; menu_box.margin_bottom = 200
	var v = VBoxContainer.new(); menu_box.add_child(v)
	for t in [[eyebrow, G.font_s, Color(1, 0.7, 0.28)], [title, G.font_l, Color(1, 1, 1)], [sub, G.font_s, Color(0.66, 0.72, 0.78)]]:
		var l = Label.new(); l.text = t[0]; l.add_font_override("font", t[1]); l.add_color_override("font_color", t[2]); l.autowrap = true
		v.add_child(l)
	menu_items = items
	var first = null
	for i in range(items.size()):
		var it = items[i]
		var b = Button.new()
		b.text = "%d   %s%s" % [i + 1, it.label, ("   · " + it.hint) if it.get("hint", "") != "" else ""]
		b.add_font_override("font", G.font_m)
		b.disabled = it.get("disabled", false)
		b.connect("pressed", self, "_menu_pick", [i])
		v.add_child(b)
		if it.get("desc", "") != "":
			var d = Label.new(); d.text = "      " + it.desc; d.add_font_override("font", G.font_s); d.add_color_override("font_color", Color(0.66, 0.72, 0.78)); d.autowrap = true
			v.add_child(d)
		if first == null and not b.disabled: first = b
	root.add_child(menu_box)
	if first: first.grab_focus()

func _menu_pick(i):
	var it = menu_items[i]
	close_menu()
	main.sfx.play("tap", 0.5)
	if it.get("act") != null:
		if it.has("arg"): it.act.call_func(it.arg)
		else: it.act.call_func()

func close_menu():
	if menu_box:
		menu_box.queue_free(); menu_box = null
		if G.MODE == "menu": G.MODE = "play"

func _unhandled_input(e):
	if menu_box and (e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause")):
		close_menu(); get_tree().set_input_as_handled()

func _interact_label(it):
	var m = { "studio": "Basement 808 studio", "store": "Calder Mini Mart", "gas": "Ironside Fuel", "court": "Shoot around at Garnet Courts", "lake": "Look out over the lake · Heat −4", "rec": "Warm up in the rec center", "home": "Go inside (home)", "video": "Video shoot", "reyes": "Talk to the detective", "coach": "Talk to " + G.D["CAST"]["coach"].name, "benny": "Talk to " + G.D["CAST"]["benny"].name }
	return m.get(it.id, it.id)

func interact(it):
	var id = it.id
	if id == "store" or id == "gas":
		var cur = G.S["cur"]
		var A = G.D["WEAPONS"][cur].get("ammo", { "n": 24, "price": 30 })
		menu("Open 24 hours", "Calder Mini Mart" if id == "store" else "Ironside Fuel", "Snacks, ammo and things for the cold.", [
			{ "label": "%s ammo ×%d" % [G.D["WEAPONS"][cur].short, A.n], "hint": G.fmt_money(A.price), "disabled": G.S["cash"] < A.price or G.S.get("fists", false), "act": funcref(self, "_buy"), "arg": ["ammo", A.price, A.n] },
			{ "label": "Bandage", "desc": "Press B to patch up (+40 health)", "hint": "$25", "disabled": G.S["cash"] < 25, "act": funcref(self, "_buy"), "arg": ["bandage", 25, 1] },
			{ "label": "Hot coffee", "desc": "Warms you up", "hint": "$5", "disabled": G.S["cash"] < 5, "act": funcref(self, "_buy"), "arg": ["coffee", 5, 1] },
			{ "label": "Leave", "act": null }])
	elif id == "home":
		menu("6127 S Bishop St", "Home", "Warm, quiet, safe.", [
			{ "label": "Rest", "desc": "Heal up, warm up and save", "act": funcref(self, "_rest") },
			{ "label": "Change your fit", "desc": "Open the Style app", "act": funcref(main.phone, "open"), "arg": "style" },
			{ "label": "Leave", "act": null }])
	elif id == "lake":
		if lake_cd > 0: toast("The lake is quiet")
		else:
			lake_cd = 120; G.S["heat"] = max(0, G.S["heat"] - 4); banner("The lake", "Heat −4")
	elif id == "rec":
		G.S["warmth"] = 100; G.S["heat"] = max(0, G.S["heat"] - 2); banner("Warmed up", "Calder Park Rec Center")
	elif id == "court":
		G.S["buzz"] = min(100, G.S["buzz"] + 0.5); banner("Nothing but net", "Buzz +0.5")
	elif id == "coach" or id == "benny":
		say(G.D["CAST"][id].name, G.pick(["Fire is going. Warm your hands.", "Booth's warm. Come down.", "Walk away more. It's not weakness.", "Kids been asking when you coming back to the court."]))
	else:
		toast("The studio, video shoots and story jobs are still web-only. They come to the Godot version next.")

func _buy(a):
	var kind = a[0]
	var price = a[1]
	if G.S["cash"] < price: return
	G.S["cash"] -= price
	main.sfx.play("cash", 0.5)
	if kind == "ammo": G.S["guns"][G.S["cur"]].res += a[2]
	elif kind == "bandage": G.S["bandages"] = G.S.get("bandages", 0) + 1
	elif kind == "coffee": G.S["warmth"] = min(100, G.S.get("warmth", 100) + 30)
	toast("Bought")

func _rest():
	G.S["health"] = 100; G.S["warmth"] = 100
	G.save_game()
	banner("Rested", "Saved")
