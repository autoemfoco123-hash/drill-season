extends Node
# Your phone: a big modern flagship (a "Pro Max" style slab) that slides up from the bottom of
# the screen. Aluminium edge in the colour you pick in Settings, thin even border, the small
# camera island, a status bar with the game clock, signal, Wi-Fi and battery; a home screen
# with glass widgets (weather, the L), an icon grid and a dock; apps in a dark grouped-list
# style with large titles. Mouse, touch, keyboard (Tab closes, Esc goes back) or a controller
# (D-pad, A, B) all work.

var main
var layer
var panel                   # the whole phone overlay (others check panel.visible)
var dim
var device
var screen
var wall
var appbg
var home
var appv
var status
var indicator
var edge
var body
var scroll
var title_lbl
var back_btn
var back_lbl
var back_method = "_home"
var w_temp
var w_cond
var w_hl
var w_glyph
var w_train
var w_train_sub
var badge
var badge_lbl
var app = ""
var gang_tab = "crew"
var form = { "name": "", "tag": "", "color": 0 }
var srv_form = { "name": "", "motd": "", "pw": "", "max": 16, "pvp": true, "direct": true }
var join_sid = ""
var join_pw = ""
var chat_text = ""
var msg = ""
var thread = null
var blok_tab = "feed"
var ip_edit = null
var addr_pw_edit = null
var lan_edit = null
var anim = 0.0              # 0 put away .. 1 in your hand
var anim_to = 0.0
var fade = 1.0              # app / home cross-fade
var tick = 0.0
var pad_nav = false         # last input came from a controller or the arrow keys
var theme
var round_shader

# geometry in UI pixels (tools/make-ui.py paints the frame to match)
const DW = 334
const DH = 696
const PAD = 4
const MG = 36
const INSET = 10
const SW = 314
const SH = 676
const SR = 48

const ACCENT = Color(0.04, 0.52, 1.0)
const CELL = Color(0.11, 0.11, 0.118)
const CELL_HI = Color(0.15, 0.15, 0.16)
const CELL_PR = Color(0.2, 0.2, 0.21)
const SEP = Color(0.22, 0.22, 0.23)
const TXT2 = Color(0.56, 0.56, 0.6)
const RED = Color(1.0, 0.27, 0.23)
const GREEN = Color(0.19, 0.82, 0.35)

const APPS = [["map", "Maps"], ["msgs", "Messages"], ["jobs", "Jobs"], ["blok", "Blok"], ["camera", "Camera"], ["gang", "Gang"],
	["garage", "Garage"], ["style", "Wardrobe"], ["online", "Online"], ["settings", "Settings"], ["pad", "Controller"], ["stats", "Stats"], ["music", "Music"]]
const GRID = ["jobs", "gang", "garage", "style", "online", "stats", "pad", "settings", "camera"]
const DOCK = ["msgs", "map", "music", "blok"]
const PHONE_COLS = { "glacier": ["Glacier", Color(0.7, 0.82, 0.93)], "silver": ["Silver", Color(0.95, 0.95, 0.97)],
	"black": ["Black", Color(0.3, 0.31, 0.33)], "burgundy": ["Burgundy", Color(0.53, 0.15, 0.2)] }
const PHONE_ORDER = ["glacier", "silver", "black", "burgundy"]

# ---------------------------------------------------------------- small drawn pieces
class Chev extends Control:
	var col = Color(0.04, 0.52, 1.0)
	var dir = -1
	var wdt = 2.4
	func _draw():
		var c = rect_size / 2
		var w = rect_size.x * 0.32
		var h = rect_size.y * 0.36
		var pts = PoolVector2Array([c + Vector2(-dir * w, -h), c + Vector2(dir * w, 0), c + Vector2(-dir * w, h)])
		draw_polyline(pts, col, wdt, true)

class Switch extends Control:
	var on = false
	func _draw():
		var s = rect_size
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.19, 0.82, 0.35) if on else Color(0.24, 0.24, 0.26)
		sb.set_corner_radius_all(int(s.y / 2)); sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2(), s))
		var r = s.y / 2 - 2
		var cx = (s.x - s.y / 2) if on else s.y / 2
		var k = StyleBoxFlat.new(); k.bg_color = Color(1, 1, 1); k.set_corner_radius_all(int(r)); k.anti_aliasing = true
		k.shadow_color = Color(0, 0, 0, 0.25); k.shadow_size = 2
		draw_style_box(k, Rect2(cx - r, s.y / 2 - r, r * 2, r * 2))

class StatusBar extends Control:
	var ph
	func _pill(r, col, rad):
		var sb = StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(rad); sb.anti_aliasing = true
		draw_style_box(sb, r)
	func _draw():
		var white = Color(1, 1, 1)
		var cy = 21.0
		var f = G.ifont(15, "s")
		var t = ph.clock12()
		draw_string(f, Vector2(64 - f.get_string_size(t).x / 2, cy + 5.5), t, white)
		var x = 219.0
		var bars = 4 if ph.main.net.online() else 3
		for i in range(4):
			var h = 4.0 + i * 2.3
			_pill(Rect2(x + i * 4.4, cy + 5 - h, 3.0, h), Color(1, 1, 1, 1.0 if i < bars else 0.32), 1)
		x += 23
		var c = Vector2(x + 7.5, cy + 5)
		_pill(Rect2(c.x - 1.6, c.y - 3.4, 3.2, 3.2), white, 2)
		for k in range(2):
			draw_arc(c + Vector2(0, -0.5), 5.2 + k * 3.6, deg2rad(-137), deg2rad(-43), 12, white, 1.9, true)
		x += 21
		var lvl = ph.batt() / 100.0
		var chg = ph.charging()
		var r = Rect2(x, cy - 1.0, 25, 12)
		_pill(r, Color(1, 1, 1, 0.35), 4)
		var fc = Color(0.19, 0.82, 0.35) if chg else (Color(1, 0.27, 0.23) if lvl < 0.2 else white)
		if lvl > 0.02:
			_pill(Rect2(r.position, Vector2(max(5.0, r.size.x * lvl), r.size.y)), fc, 4)
		_pill(Rect2(x + 26, cy + 3, 1.8, 4.2), Color(1, 1, 1, 0.4), 1)
		var pf = G.ifont(9, "b")
		var ps = str(int(ph.batt()))
		draw_string(pf, Vector2(r.position.x + r.size.x / 2 - pf.get_string_size(ps).x / 2, cy + 8.3), ps, Color(0, 0, 0, 0.85) if lvl > 0.45 else white)

class HomeBar extends Button:
	func _draw():
		var sb = StyleBoxFlat.new(); sb.bg_color = Color(1, 1, 1, 0.92); sb.set_corner_radius_all(3); sb.anti_aliasing = true
		draw_style_box(sb, Rect2(rect_size.x / 2 - 56, rect_size.y - 9, 112, 5))

class Glyph extends Control:
	var kind = "sun"
	func _ball(c, r, col):
		var sb = StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(int(r)); sb.anti_aliasing = true
		draw_style_box(sb, Rect2(c - Vector2(r, r), Vector2(r, r) * 2))
	func _cloud(o, col):
		_ball(o + Vector2(7, 11), 5, col); _ball(o + Vector2(12, 8), 6.5, col); _ball(o + Vector2(17, 11), 5, col)
		var sb = StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(4); sb.anti_aliasing = true
		draw_style_box(sb, Rect2(o + Vector2(4, 10), Vector2(17, 6)))
	func _draw():
		var o = Vector2()
		if kind == "sun":
			_ball(o + Vector2(11, 11), 7, Color(1, 0.84, 0.2))
		elif kind == "moon":
			_ball(o + Vector2(11, 11), 7, Color(0.95, 0.93, 0.82))
			_ball(o + Vector2(14.5, 8), 6, Color(0.24, 0.3, 0.45))
		elif kind == "cloud":
			_cloud(o, Color(0.95, 0.96, 0.98))
		elif kind == "snow":
			_cloud(o + Vector2(0, -3), Color(0.95, 0.96, 0.98))
			for p in [Vector2(8, 18), Vector2(13, 20), Vector2(18, 18)]:
				_ball(o + p, 1.4, Color(1, 1, 1))
		else:
			_cloud(o + Vector2(0, -3), Color(0.82, 0.84, 0.88))
			draw_colored_polygon(PoolVector2Array([o + Vector2(13, 12), o + Vector2(9, 19), o + Vector2(12, 19), o + Vector2(10, 24), o + Vector2(16, 16), o + Vector2(13, 16), o + Vector2(15, 12)]), Color(1, 0.84, 0.2))

class BigMap extends Control:
	var main
	func _draw():
		var s = rect_size
		var bg = StyleBoxFlat.new(); bg.bg_color = Color(0.11, 0.11, 0.118); bg.set_corner_radius_all(14); bg.anti_aliasing = true
		draw_style_box(bg, Rect2(Vector2(), s))
		var H = float(G.D["MAP_HALF"])
		var k = min(s.x, s.y) / (H * 2.15)
		var o = s / 2
		draw_rect(Rect2(o + Vector2(G.D["LAKE_X"], -H) * k, Vector2(H - G.D["LAKE_X"], H * 2) * k), Color(0.2, 0.42, 0.62, 0.55))
		# turf: the blocks in their owners' colours, a dot on each corner
		var T = main.turf
		if T and not T.rings.empty():
			var tm = T.cur()
			for b in range(T.N):
				var ow = tm[b]
				var r = T.rect(b)
				var oc = T.o_col(ow)
				var nobody = typeof(ow) == TYPE_STRING and ow == ""
				draw_rect(Rect2(o + Vector2(r[0] + 7, r[1] + 7) * k, Vector2(r[2] - r[0] - 14, r[3] - r[1] - 14) * k), Color(oc.r, oc.g, oc.b, 0.04 if nobody else (0.3 if T.is_mine(ow) else 0.18)))
				if T.is_mine(ow):
					draw_rect(Rect2(o + Vector2(r[0] + 7, r[1] + 7) * k, Vector2(r[2] - r[0] - 14, r[3] - r[1] - 14) * k), Color(oc.r, oc.g, oc.b, 0.9), false, 1.5)
				var tg = T.o_tag(ow)
				if tg != "":
					var tf = G.ifont(10, "b")
					var mid = o + Vector2((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0) * k
					draw_string(tf, mid - Vector2(tf.get_string_size(tg).x / 2, -14), tg, Color(oc.r, oc.g, oc.b, 0.85))
		for x in G.D["XL"]: draw_line(o + Vector2(x, -H) * k, o + Vector2(x, H) * k, Color(0.3, 0.31, 0.34), 3)
		for z in G.D["ZL"]: draw_line(o + Vector2(-H, z) * k, o + Vector2(G.D["ROAD_X_END"], z) * k, Color(0.3, 0.31, 0.34), 3)
		var f = G.ifont(11, "m")
		var used = []
		for key in G.D["LOC"].keys():
			var L = G.D["LOC"][key]
			if not L.has("name") or key in ["storeFront", "stairs"]: continue
			var p = o + Vector2(L.x, L.z) * k
			draw_circle(p, 2.5, Color(1, 0.62, 0.04))
			var sz = f.get_string_size(L.name)
			var r = Rect2(p + Vector2(5, -sz.y * 0.6), sz)
			if r.end.x > s.x - 4: r.position.x = p.x - 5 - sz.x
			var free = true
			for u in used:
				if u.intersects(r): free = false
			if free:
				used.append(r)
				draw_string(f, Vector2(r.position.x, p.y + 4), L.name, Color(0.86, 0.87, 0.9))
		var P = main.player
		var pp = o + Vector2(P.pos.x, P.pos.z) * k
		draw_circle(pp, 8, Color(0.04, 0.52, 1.0, 0.25))
		draw_circle(pp, 5, Color(1, 1, 1))
		draw_circle(pp, 3.6, Color(0.04, 0.52, 1.0))
		for cp in main.police.COPS:
			draw_circle(o + Vector2(cp.pos.x, cp.pos.z) * k, 3, Color(1, 0.27, 0.23))
		var MI = main.missions
		var mt = MI.target() if MI else null
		if mt != null:
			var mp = o + Vector2(mt.x, mt.z) * k
			draw_circle(mp, 8 + 3 * (0.5 + 0.5 * sin(G.REAL_T * 5.0)), Color(1, 1, 1, 0.9))
			draw_circle(mp, 7, MI.target_col())
		if T and T.raid != null:
			var rc = T.corners[T.raid.b]
			var rp = o + Vector2(rc.x, rc.z) * k
			draw_circle(rp, 7 + 3 * (0.5 + 0.5 * sin(G.REAL_T * 6.0)), Color(1, 1, 1, 0.9))
			draw_circle(rp, 6, T.CREWS[T.raid.fac].col)

# ---------------------------------------------------------------- building the phone
func setup(m):
	main = m
	round_shader = load("res://scripts/round.shader")
	theme = _make_theme()
	layer = CanvasLayer.new(); layer.layer = 5; add_child(layer)
	panel = Control.new(); panel.anchor_right = 1; panel.anchor_bottom = 1; panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme = theme
	layer.add_child(panel)
	dim = ColorRect.new(); dim.anchor_right = 1; dim.anchor_bottom = 1; dim.color = Color(0, 0, 0, 0)
	dim.connect("gui_input", self, "_dim_input")
	panel.add_child(dim)
	device = Control.new(); device.rect_size = Vector2(DW, DH)    # stops clicks on the edge from closing the phone
	panel.add_child(device)
	screen = Control.new(); screen.rect_position = Vector2(INSET, INSET); screen.rect_size = Vector2(SW, SH); screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	device.add_child(screen)
	# the screen: wallpaper (rounded), or black for apps
	wall = TextureRect.new(); wall.texture = load("res://assets/ui/wallpaper.png"); wall.expand = true; wall.rect_size = Vector2(SW, SH)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.material = _round_mat(Vector2(SW, SH), SR)
	screen.add_child(wall)
	appbg = Panel.new(); appbg.rect_size = Vector2(SW, SH); appbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	appbg.add_stylebox_override("panel", _box(Color(0, 0, 0), SR))
	screen.add_child(appbg)
	home = Control.new(); home.rect_size = Vector2(SW, SH); home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(home)
	_build_home()
	appv = Control.new(); appv.rect_size = Vector2(SW, SH); appv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(appv)
	_build_app_view()
	status = StatusBar.new(); status.ph = self; status.rect_size = Vector2(SW, 44); status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(status)
	indicator = HomeBar.new(); indicator.rect_position = Vector2(SW / 2 - 80, SH - 22); indicator.rect_size = Vector2(160, 22)
	indicator.flat = true; indicator.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus", "disabled"]: indicator.add_stylebox_override(st, StyleBoxEmpty.new())
	indicator.connect("pressed", self, "_indicator")
	screen.add_child(indicator)
	# the device itself, over the screen: border, island and shadow, then the tinted edge
	var fr = Rect2(Vector2(-MG - PAD, -MG), Vector2(DW + 2 * PAD + 2 * MG, DH + 2 * MG))
	var front = TextureRect.new(); front.texture = load("res://assets/ui/phone_front.png"); front.expand = true
	front.rect_position = fr.position; front.rect_size = fr.size; front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	device.add_child(front)
	edge = TextureRect.new(); edge.texture = load("res://assets/ui/phone_edge.png"); edge.expand = true
	edge.rect_position = fr.position; edge.rect_size = fr.size; edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	device.add_child(edge)
	_tint()
	panel.visible = false

func _round_mat(size, radius):
	var mt = ShaderMaterial.new(); mt.shader = round_shader
	mt.set_shader_param("size", size); mt.set_shader_param("radius", radius)
	return mt

func _box(col, r = 12, ml = 14, mt = 10):
	var sb = StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(r); sb.anti_aliasing = true; sb.corner_detail = 10
	sb.content_margin_left = ml; sb.content_margin_right = ml; sb.content_margin_top = mt; sb.content_margin_bottom = mt
	return sb

func _ring(col, r = 12, w = 2):
	var sb = StyleBoxFlat.new(); sb.draw_center = false; sb.border_color = col; sb.set_border_width_all(w); sb.set_corner_radius_all(r)
	sb.anti_aliasing = true; sb.corner_detail = 10
	return sb

func _knob():
	var n = 24
	var img = Image.new(); img.create(n, n, false, Image.FORMAT_RGBA8); img.lock()
	for y in range(n):
		for x in range(n):
			var d = Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0 - 0.6).length()
			var a = clamp(10.0 - d, 0.0, 1.0)
			var sh = clamp(11.8 - d, 0.0, 1.0) * 0.22
			img.set_pixel(x, y, Color(a, a, a, a + sh * (1.0 - a)))
	img.unlock()
	var t = ImageTexture.new(); t.create_from_image(img)
	return t

func _make_theme():
	var th = Theme.new()
	th.default_font = G.ifont(15, "r")
	th.set_stylebox("normal", "Button", _box(CELL))
	th.set_stylebox("hover", "Button", _box(CELL_HI))
	th.set_stylebox("pressed", "Button", _box(CELL_PR))
	th.set_stylebox("disabled", "Button", _box(CELL))
	th.set_stylebox("focus", "Button", _ring(ACCENT))
	for c in ["font_color", "font_color_hover", "font_color_pressed", "font_color_focus"]:
		th.set_color(c, "Button", Color(1, 1, 1))
	th.set_color("font_color_disabled", "Button", Color(0.38, 0.38, 0.41))
	th.set_stylebox("normal", "LineEdit", _box(CELL, 10, 12, 10))
	var lf = _box(CELL_HI, 10, 12, 10); lf.border_color = ACCENT; lf.set_border_width_all(1)
	th.set_stylebox("focus", "LineEdit", lf)
	th.set_stylebox("read_only", "LineEdit", _box(CELL, 10, 12, 10))
	th.set_color("font_color", "LineEdit", Color(1, 1, 1))
	th.set_color("cursor_color", "LineEdit", ACCENT)
	th.set_color("selection_color", "LineEdit", Color(0.04, 0.52, 1.0, 0.4))
	var track = StyleBoxFlat.new(); track.bg_color = Color(0.23, 0.23, 0.25); track.set_corner_radius_all(2); track.content_margin_top = 2; track.content_margin_bottom = 2
	var fill = track.duplicate(); fill.bg_color = ACCENT
	th.set_stylebox("slider", "HSlider", track)
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	th.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())
	var kn = _knob()
	th.set_icon("grabber", "HSlider", kn)
	th.set_icon("grabber_highlight", "HSlider", kn)
	var sbg = StyleBoxEmpty.new(); sbg.content_margin_left = 1.5; sbg.content_margin_right = 1.5
	th.set_stylebox("scroll", "VScrollBar", sbg)
	th.set_stylebox("scroll_focus", "VScrollBar", sbg)
	var gr = StyleBoxFlat.new(); gr.bg_color = Color(1, 1, 1, 0.22); gr.set_corner_radius_all(2); gr.content_margin_left = 1.5; gr.content_margin_right = 1.5
	th.set_stylebox("grabber", "VScrollBar", gr)
	var gh = gr.duplicate(); gh.bg_color = Color(1, 1, 1, 0.4)
	th.set_stylebox("grabber_highlight", "VScrollBar", gh)
	th.set_stylebox("grabber_pressed", "VScrollBar", gh)
	th.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	th.set_stylebox("bg", "ScrollContainer", StyleBoxEmpty.new())
	th.set_color("font_color", "Label", Color(0.93, 0.93, 0.96))
	th.set_constant("separation", "VBoxContainer", 10)
	th.set_constant("separation", "HBoxContainer", 8)
	return th

func _tint():
	var k = str(G.S["settings"].get("phoneCol", "glacier"))
	edge.modulate = PHONE_COLS.get(k, PHONE_COLS["glacier"])[1]

func _label(parent, text, font, col, pos = null, size = null):
	var l = Label.new(); l.text = text; l.add_font_override("font", font); l.add_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pos != null: l.rect_position = pos
	if size != null: l.rect_size = size
	parent.add_child(l)
	return l

func _glass(parent, r, radius = 22):
	var p = Panel.new(); p.rect_position = r.position; p.rect_size = r.size; p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb = _box(Color(1, 1, 1, 0.13), radius); sb.border_color = Color(1, 1, 1, 0.17); sb.set_border_width_all(1)
	p.add_stylebox_override("panel", sb)
	parent.add_child(p)
	return p

func _build_home():
	# widgets: the weather in Calder Park, and the next L at Calder
	var ww = _glass(home, Rect2(18, 54, 132, 132))
	_label(ww, "Calder Park", G.ifont(12, "s"), Color(1, 1, 1), Vector2(14, 12))
	w_temp = _label(ww, "", G.ifont(40, "l"), Color(1, 1, 1), Vector2(11, 28))
	w_glyph = Glyph.new(); w_glyph.rect_position = Vector2(98, 10); w_glyph.rect_size = Vector2(24, 24); w_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ww.add_child(w_glyph)
	w_cond = _label(ww, "", G.ifont(12, "m"), Color(1, 1, 1), Vector2(14, 88))
	w_hl = _label(ww, "", G.ifont(11, "m"), Color(1, 1, 1, 0.72), Vector2(14, 105))
	var tw = _glass(home, Rect2(164, 54, 132, 132))
	var lb = Panel.new(); lb.rect_position = Vector2(14, 12); lb.rect_size = Vector2(18, 18); lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.add_stylebox_override("panel", _box(Color(1, 0.62, 0.04), 5, 0, 0)); tw.add_child(lb)
	var ll = _label(lb, "L", G.ifont(11, "b"), Color(1, 1, 1)); ll.rect_size = Vector2(18, 18); ll.align = Label.ALIGN_CENTER; ll.valign = Label.VALIGN_CENTER
	_label(tw, "Calder", G.ifont(12, "s"), Color(1, 1, 1), Vector2(38, 12))
	_label(tw, "Next train", G.ifont(12, "m"), Color(1, 1, 1, 0.72), Vector2(14, 46))
	w_train = _label(tw, "", G.ifont(30, "s"), Color(1, 1, 1), Vector2(13, 62))
	w_train_sub = _label(tw, "", G.ifont(11, "m"), Color(1, 1, 1, 0.72), Vector2(14, 105))
	# the grid
	var cw = (SW - 32) / 4.0
	for i in range(GRID.size()):
		var x = 16 + cw * (i % 4) + cw / 2
		var y = 210 + 88 * int(i / 4)
		_app_icon(GRID[i], Vector2(x, y), true)
	# the dock
	_glass(home, Rect2(12, SH - 106, SW - 24, 80), 32)
	for i in range(DOCK.size()):
		_app_icon(DOCK[i], Vector2(16 + cw * i + cw / 2, SH - 95), false)

func _app_icon(id, at, with_label):
	var b = Button.new(); b.rect_position = at - Vector2(29, 0); b.rect_size = Vector2(58, 58)
	b.icon = load("res://assets/ui/icon_%s.png" % id); b.expand_icon = true; b.flat = true
	for st in ["normal", "hover", "pressed", "disabled"]: b.add_stylebox_override(st, StyleBoxEmpty.new())
	var fo = _ring(Color(1, 1, 1, 0.95), 17, 2); fo.expand_margin_left = 3; fo.expand_margin_right = 3; fo.expand_margin_top = 3; fo.expand_margin_bottom = 3
	b.add_stylebox_override("focus", fo)
	b.connect("pressed", self, "show_app", [id])
	b.connect("button_down", b, "set_modulate", [Color(0.72, 0.72, 0.75)])
	b.connect("button_up", b, "set_modulate", [Color(1, 1, 1)])
	b.name = "icon_" + id
	home.add_child(b)
	if with_label:
		var nm = ""
		for a in APPS:
			if a[0] == id: nm = a[1]
		var l = _label(home, nm, G.ifont(11, "m"), Color(1, 1, 1), at + Vector2(-38, 62), Vector2(76, 16))
		l.align = Label.ALIGN_CENTER
		l.add_color_override("font_color_shadow", Color(0, 0, 0, 0.35)); l.add_constant_override("shadow_offset_y", 1)
	if id == "msgs":
		badge = Panel.new(); badge.rect_position = Vector2(42, -6); badge.rect_size = Vector2(22, 22); badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_stylebox_override("panel", _box(RED, 11, 0, 0))
		b.add_child(badge)
		badge_lbl = _label(badge, "", G.ifont(12, "s"), Color(1, 1, 1)); badge_lbl.rect_size = Vector2(22, 22)
		badge_lbl.align = Label.ALIGN_CENTER; badge_lbl.valign = Label.VALIGN_CENTER

func _build_app_view():
	back_btn = Button.new(); back_btn.rect_position = Vector2(6, 44); back_btn.rect_size = Vector2(150, 32); back_btn.flat = true
	for st in ["normal", "hover", "pressed", "disabled"]:
		var e = StyleBoxEmpty.new(); e.content_margin_left = 22
		back_btn.add_stylebox_override(st, e)
	back_btn.add_stylebox_override("focus", _ring(ACCENT, 10, 2))
	back_btn.align = Button.ALIGN_LEFT
	back_btn.add_font_override("font", G.ifont(16, "r"))
	for c in ["font_color", "font_color_hover", "font_color_pressed", "font_color_focus"]:
		back_btn.add_color_override(c, ACCENT)
	back_btn.connect("pressed", self, "_back")
	var ch = Chev.new(); ch.rect_position = Vector2(4, 7); ch.rect_size = Vector2(14, 18); ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_btn.add_child(ch)
	appv.add_child(back_btn)
	title_lbl = _label(appv, "", G.ifont(28, "b"), Color(1, 1, 1), Vector2(18, 76), Vector2(SW - 36, 36))
	title_lbl.clip_text = true
	scroll = ScrollContainer.new(); scroll.rect_position = Vector2(14, 120); scroll.rect_size = Vector2(SW - 28, SH - 120 - 26)
	scroll.scroll_horizontal_enabled = false
	appv.add_child(scroll)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

# ---------------------------------------------------------------- open, close, move
func open(which = ""):
	if G.MODE != "play" and G.MODE != "phone" and G.MODE != "menu": return
	main.hud.close_menu()
	G.MODE = "phone"
	opened_frame = Engine.get_idle_frames()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if not panel.visible: anim = 0.0
	panel.visible = true
	anim_to = 1.0
	_tint()
	_layout()
	main.sfx.play("lock", 0.5)
	if which != "": show_app(which)
	else: _home()

func close(now = false):
	anim_to = 0.0
	if now:
		anim = 0.0; panel.visible = false; _hud_fade(0.0)
	if main.net.mode == "browse": main.net.browse(false)
	if G.MODE == "phone": G.MODE = "play"
	main.sfx.play("lock", 0.5)

func _layout():
	var vs = panel.get_viewport_rect().size
	var e = 1.0 - pow(1.0 - anim, 3.0)
	# console mode's bigger layout is shorter than the phone: shrink it to fit
	var k = min(1.0, (vs.y - 16.0) / DH)
	device.rect_scale = Vector2(k, k)
	var x = round(vs.x - DW * k - PAD - 34)
	var y = round((vs.y - DH * k) / 2.0 + (1.0 - e) * (DH * 0.55 + vs.y * 0.5))
	device.rect_position = Vector2(x, y)
	dim.color = Color(0, 0, 0, 0.24 * e)

# the HUD's right column (cash, weapon, stars, street) sits behind the phone: fade it out
func _hud_fade(e):
	if not main.hud or not main.hud.root: return
	for c in main.hud.root.get_children():
		if c is Control and c.anchor_left >= 1.0:
			c.self_modulate.a = 1.0 - e

func _dim_input(e):
	if (e is InputEventMouseButton and e.pressed and e.button_index == BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		close()

func _indicator():
	if app != "": _home()
	else: close()

func _back():
	call(back_method)

func _input(e):
	if e is InputEventJoypadButton or e is InputEventJoypadMotion:
		if e is InputEventJoypadButton or abs(e.axis_value) > 0.5: pad_nav = true
	elif e is InputEventKey and e.pressed and e.scancode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		pad_nav = true
	elif e is InputEventMouseButton or e is InputEventScreenTouch:
		pad_nav = false

var opened_frame = -1
func _unhandled_input(e):
	if not panel.visible or anim_to <= 0.0: return
	if Engine.get_idle_frames() == opened_frame: return     # the press that opened it
	if e.is_action_pressed("phone") or e.is_action_pressed("pause") or (e.is_action_pressed("ui_cancel") and app == ""):
		close(); get_tree().set_input_as_handled()
	elif e.is_action_pressed("ui_cancel"):
		_back(); get_tree().set_input_as_handled()
	elif (e.is_action_pressed("ui_down") or e.is_action_pressed("ui_up")) and panel.get_focus_owner() == null:
		_focus_first(); get_tree().set_input_as_handled()

var online_t = 0.0
func update(dt):
	if not panel.visible: return
	anim = move_toward(anim, anim_to, dt / 0.26)
	_layout()
	_hud_fade(1.0 - pow(1.0 - anim, 3.0))
	if anim <= 0.0 and anim_to <= 0.0:
		panel.visible = false; return
	fade = move_toward(fade, 1.0, dt / 0.16)
	var f = 1.0 - pow(1.0 - fade, 2.0)
	(appv if app != "" else home).modulate = Color(1, 1, 1, f)
	tick -= dt
	if tick <= 0:
		tick = 1.0
		status.update()
		if app == "": _home_live()
	if app == "online" and main.net.mode != "off":
		online_t -= dt
		# don't rebuild while someone is typing (a password, a chat line, a server name)
		if online_t <= 0 and not (panel.get_focus_owner() is LineEdit):
			online_t = 2.0; show_app("online", true)
	if app == "map":
		var m = body.get_node_or_null("BigMap")
		if m: m.update()
	if app == "music": _music_live()

func clock12():
	var m = int(G.world_minutes())
	var h = int(m / 60) % 24
	var h12 = h % 12
	if h12 == 0: h12 = 12
	return "%d:%02d" % [h12, m % 60]

func batt():
	var p = OS.get_power_percent_left()
	return 87 if p < 0 else p

func charging():
	return OS.get_power_state() == OS.POWERSTATE_CHARGING

# ---------------------------------------------------------------- home
func _home():
	app = ""; thread = null
	home.visible = true; wall.visible = true
	appv.visible = false; appbg.visible = false
	fade = 0.0; home.modulate = Color(1, 1, 1, 0)
	_home_live()
	if pad_nav: _focus_first()

func _home_live():
	var tf = int(main.story.temp_f())
	w_temp.text = "%d°" % tf
	var wn = main.sky.weather_now()
	var hr = G.world_minutes() / 60.0
	var night = hr < 6.5 or hr > 18.0
	var cond = "Clear"
	var gk = "moon" if night else "sun"
	if wn[1] > 0.5:
		cond = "Thundersnow"; gk = "storm"
	elif wn[0] > 0.72:
		cond = "Snow showers"; gk = "snow"
	elif wn[0] > 0.45:
		cond = "Mostly cloudy"; gk = "cloud"
	elif not night:
		cond = "Sunny"
	w_cond.text = cond
	w_glyph.kind = gk; w_glyph.update()
	w_hl.text = "H:%d°  L:%d°" % [tf + 4, tf - 7]
	var tr = int(main.train.next_train_in())
	if tr <= 0:
		w_train.text = "Now"; w_train_sub.text = "Boarding at Calder"
	else:
		w_train.text = ("%d s" % tr) if tr < 120 else ("%d min" % int(ceil(tr / 60.0)))
		w_train_sub.text = "Day %d" % int(G.S.get("day", 1))
	var unread = 0
	for k in G.S["unread"].keys(): unread += int(G.S["unread"][k])
	badge.visible = unread > 0
	badge_lbl.text = str(unread) if unread < 100 else "99+"

func _focus_first():
	var n = home.get_node_or_null("icon_" + GRID[0]) if app == "" else _first_button(body)
	if n: n.grab_focus()

func _first_button(n):
	for c in n.get_children():
		if (c is Button or c is LineEdit) and c.focus_mode != Control.FOCUS_NONE and not (c is Button and c.disabled) and c.is_visible_in_tree():
			return c
		var r = _first_button(c)
		if r: return r
	return null

# ---------------------------------------------------------------- apps
func show_app(id, keep = false):
	if id == "style":
		close(true); main.wardrobe.open(); return
	if id != app:
		fade = 0.0; appv.modulate = Color(1, 1, 1, 0)
	var sc = scroll.scroll_vertical if keep else 0
	app = id
	home.visible = false; wall.visible = false
	appv.visible = true; appbg.visible = true
	_clear()
	back_method = "_home"; back_btn.text = "Home"
	var names = {}
	for a in APPS: names[a[0]] = a[1]
	title_lbl.text = names.get(id, id)
	call("_app_" + id)
	_polish()
	if keep:
		yield(get_tree(), "idle_frame")
		scroll.scroll_vertical = sc
	else:
		scroll.scroll_vertical = 0
		if pad_nav: _focus_first()

func _clear():
	for c in body.get_children():
		body.remove_child(c); c.queue_free()
	ip_edit = null; lan_edit = null

# --- building blocks
func _fmap(font):
	if font == G.font_xs: return G.ifont(12, "r")
	if font == G.font_m: return G.ifont(15, "s")
	if font == G.font_l: return G.ifont(21, "b")
	if font == G.font_xl: return G.ifont(40, "b")
	return G.ifont(14, "r")

func _lbl(text, font = null, col = Color(0.93, 0.93, 0.96)):
	var l = Label.new(); l.text = text; l.autowrap = true
	l.add_font_override("font", _fmap(font)); l.add_color_override("font_color", col)
	body.add_child(l)
	return l

func _indent(ctrl, left = 14, top = 0, right = 14):
	var mc = MarginContainer.new()
	mc.add_constant_override("margin_left", left); mc.add_constant_override("margin_right", right)
	mc.add_constant_override("margin_top", top); mc.add_constant_override("margin_bottom", 0)
	mc.add_child(ctrl)
	body.add_child(mc)
	return ctrl

func _foot(text, col = TXT2):
	var l = Label.new(); l.text = text; l.autowrap = true
	l.add_font_override("font", G.ifont(12, "r")); l.add_color_override("font_color", col)
	return _indent(l)

func _sec(text):
	var l = Label.new(); l.text = text.to_upper()
	l.add_font_override("font", G.ifont(12, "m")); l.add_color_override("font_color", TXT2)
	return _indent(l, 14, 10)

func _btn(text, target, method, args = [], disabled = false, parent = null):
	var b = Button.new(); b.text = text; b.disabled = disabled
	b.clip_text = true   # long labels must not widen the phone
	b.connect("pressed", target, method, args)
	(parent if parent else body).add_child(b)
	return b

func _cell(text, value, method, args = [], disabled = false, kind = ""):
	var b = _btn(text, self, method, args, disabled)
	b.set_meta("v", value)
	if kind != "": b.set_meta("k", kind)
	return b

func _action(text, method, args = [], disabled = false):
	var b = _btn(text, self, method, args, disabled); b.set_meta("k", "action"); return b

func _danger(text, method, args = [], disabled = false):
	var b = _btn(text, self, method, args, disabled); b.set_meta("k", "danger"); return b

func _primary(text, method, args = [], disabled = false):
	var b = _btn(text, self, method, args, disabled)
	b.set_meta("k", "primary"); b.set_meta("solo", true)
	b.align = Button.ALIGN_CENTER; b.rect_min_size = Vector2(0, 46)
	var n = _box(ACCENT, 12, 14, 12)
	b.add_stylebox_override("normal", n)
	b.add_stylebox_override("hover", _box(ACCENT.lightened(0.12), 12, 14, 12))
	b.add_stylebox_override("pressed", _box(ACCENT.darkened(0.15), 12, 14, 12))
	b.add_stylebox_override("disabled", _box(Color(0.2, 0.2, 0.21), 12, 14, 12))
	b.add_stylebox_override("focus", _ring(Color(1, 1, 1), 12, 2))
	b.add_font_override("font", G.ifont(15, "s"))
	return b

func _switch(text, on, method, args = []):
	var b = _btn(text, self, method, args); b.set_meta("sw", on); return b

func _edit(text, ph, key, dict_name, secret = false, maxlen = 32):
	var le = LineEdit.new(); le.text = text; le.placeholder_text = ph; le.secret = secret; le.max_length = maxlen
	le.connect("text_changed", self, "_typed", [dict_name, key])
	body.add_child(le)
	return le

func _card(parent = null, pad = 14):
	var c = PanelContainer.new()
	c.add_stylebox_override("panel", _box(CELL, 14, pad, 12))
	(parent if parent else body).add_child(c)
	var v = VBoxContainer.new(); v.add_constant_override("separation", 4); c.add_child(v)
	return v

func _kv(rows):
	var v = _card(null, 0)
	v.add_constant_override("separation", 0)
	for i in range(rows.size()):
		var h = HBoxContainer.new(); h.rect_min_size = Vector2(0, 40)
		var m = MarginContainer.new(); m.add_constant_override("margin_left", 14); m.add_constant_override("margin_right", 14)
		m.add_child(h); v.add_child(m)
		var a = Label.new(); a.text = rows[i][0]; a.size_flags_horizontal = Control.SIZE_EXPAND_FILL; a.valign = Label.VALIGN_CENTER
		a.add_font_override("font", G.ifont(14, "r")); a.clip_text = true; h.add_child(a)
		var b = Label.new(); b.text = rows[i][1]; b.valign = Label.VALIGN_CENTER; b.align = Label.ALIGN_RIGHT
		b.add_font_override("font", G.ifont(14, "r")); b.add_color_override("font_color", TXT2); h.add_child(b)
		b.rect_min_size = Vector2(0, 40); a.rect_min_size = Vector2(0, 40)
		if i < rows.size() - 1:
			var s = ColorRect.new(); s.color = SEP; s.rect_min_size = Vector2(0, 1); s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sm = MarginContainer.new(); sm.add_constant_override("margin_left", 14); sm.add_child(s); v.add_child(sm)
	return v

func _segmented(opts, current, method):
	var track = PanelContainer.new()
	track.add_stylebox_override("panel", _box(Color(0.46, 0.46, 0.5, 0.24), 9, 2, 2))
	body.add_child(track)
	var row = HBoxContainer.new(); row.add_constant_override("separation", 2); track.add_child(row)
	for o in opts:
		var b = Button.new(); b.text = o[1]; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.rect_min_size = Vector2(0, 30)
		var on = o[0] == current
		var n = _box(Color(0.39, 0.39, 0.4) if on else Color(0, 0, 0, 0), 7, 6, 4)
		b.add_stylebox_override("normal", n); b.add_stylebox_override("hover", _box(Color(0.39, 0.39, 0.4) if on else Color(1, 1, 1, 0.06), 7, 6, 4))
		b.add_stylebox_override("pressed", n); b.add_stylebox_override("focus", _ring(ACCENT, 7, 2))
		b.add_font_override("font", G.ifont(13, "s" if on else "m"))
		b.connect("pressed", self, method, [o[0]])
		row.add_child(b)
	return track

func _avatar(parent, at, d, col, letter):
	var p = Panel.new(); p.rect_position = at; p.rect_size = Vector2(d, d); p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_stylebox_override("panel", _box(col, int(d / 2), 0, 0))
	parent.add_child(p)
	var l = _label(p, letter, G.ifont(int(d * 0.42), "s"), Color(1, 1, 1)); l.rect_size = Vector2(d, d)
	l.align = Label.ALIGN_CENTER; l.valign = Label.VALIGN_CENTER
	return p

# --- the grouped-list look: consecutive rows become one rounded group with hairlines between
func _is_cell(c):
	return (c is Button or c is LineEdit) and not c.has_meta("solo")

func _polish():
	var run = []
	for c in body.get_children():
		if _is_cell(c):
			run.append(c)
		else:
			_group(run); run = []
	_group(run)

func _group(run):
	if run.empty(): return
	if run.size() > 1:
		var box = VBoxContainer.new(); box.add_constant_override("separation", 0)
		var idx = run[0].get_index()
		body.add_child(box); body.move_child(box, idx)
		for c in run:
			body.remove_child(c); box.add_child(c)
	for i in range(run.size()):
		var pos = 0 if run.size() == 1 else (1 if i == 0 else (3 if i == run.size() - 1 else 2))
		_style_cell(run[i], pos, i < run.size() - 1)

func _cbox(col, pos, mr = 14, ring = false):
	var sb = _ring(ACCENT, 12, 2) if ring else _box(col, 12)
	if not ring:
		sb.content_margin_right = mr; sb.content_margin_top = 11; sb.content_margin_bottom = 11
	var top = pos in [0, 1]
	var bot = pos in [0, 3]
	sb.corner_radius_top_left = 12 if top else 0; sb.corner_radius_top_right = 12 if top else 0
	sb.corner_radius_bottom_left = 12 if bot else 0; sb.corner_radius_bottom_right = 12 if bot else 0
	return sb

func _style_cell(c, pos, sep):
	if c is LineEdit:
		var n = _cbox(CELL, pos); n.content_margin_left = 14
		c.add_stylebox_override("normal", n)
		var fo = _cbox(CELL_HI, pos); fo.content_margin_left = 14; fo.border_color = ACCENT; fo.set_border_width_all(1)
		c.add_stylebox_override("focus", fo)
		c.rect_min_size.y = max(c.rect_min_size.y, 44)
	else:
		var kind = str(c.get_meta("k")) if c.has_meta("k") else ""
		var val = str(c.get_meta("v")) if c.has_meta("v") else ""
		if not c.has_meta("v") and not c.has_meta("sw") and c.text.find(": ") > 0:
			var i = c.text.find(": ")
			val = c.text.substr(i + 2); c.text = c.text.substr(0, i)
		var vf = G.ifont(15, "r")
		var mr = 14
		if c.has_meta("sw"): mr = 70
		elif val != "": mr = int(min(vf.get_string_size(val).x, 150)) + 40
		elif kind == "": mr = 34
		c.add_stylebox_override("normal", _cbox(CELL, pos, mr))
		c.add_stylebox_override("hover", _cbox(CELL_HI, pos, mr))
		c.add_stylebox_override("pressed", _cbox(CELL_PR, pos, mr))
		c.add_stylebox_override("disabled", _cbox(CELL, pos, mr))
		c.add_stylebox_override("focus", _cbox(CELL, pos, mr, true))
		c.align = Button.ALIGN_LEFT
		c.rect_min_size.y = max(c.rect_min_size.y, 44)
		var tc = ACCENT if kind == "action" else (RED if kind == "danger" else Color(1, 1, 1))
		for cn in ["font_color", "font_color_hover", "font_color_pressed", "font_color_focus"]:
			c.add_color_override(cn, tc)
		if c.has_meta("sw"):
			var s = Switch.new(); s.on = bool(c.get_meta("sw")); s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s.anchor_left = 1; s.anchor_right = 1; s.anchor_top = 0.5; s.anchor_bottom = 0.5
			s.margin_left = -62; s.margin_right = -14; s.margin_top = -14; s.margin_bottom = 14
			c.add_child(s)
		elif kind == "":
			var ch = Chev.new(); ch.dir = 1; ch.col = Color(0.36, 0.36, 0.38); ch.wdt = 2.0; ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ch.anchor_left = 1; ch.anchor_right = 1; ch.anchor_top = 0.5; ch.anchor_bottom = 0.5
			ch.margin_left = -24; ch.margin_right = -14; ch.margin_top = -8; ch.margin_bottom = 8
			c.add_child(ch)
		if val != "" and not c.has_meta("sw"):
			var vl = Label.new(); vl.text = val; vl.clip_text = true; vl.align = Label.ALIGN_RIGHT; vl.valign = Label.VALIGN_CENTER
			vl.add_font_override("font", vf); vl.add_color_override("font_color", TXT2); vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vl.anchor_left = 1; vl.anchor_right = 1; vl.anchor_bottom = 1
			vl.margin_left = -(mr - 6); vl.margin_right = -30 if kind == "" else -14
			c.add_child(vl)
	if sep:
		var ln = ColorRect.new(); ln.color = SEP; ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ln.anchor_top = 1; ln.anchor_bottom = 1; ln.anchor_right = 1; ln.margin_top = -1; ln.margin_left = 14
		c.add_child(ln)

# ---------- Messages ----------
func _app_msgs():
	var C = G.D["CAST"]
	if thread != null:
		var who = thread
		title_lbl.text = C[who].name
		back_btn.text = "Messages"; back_method = "_msgs_back"
		G.S["unread"][who] = 0
		var th = G.S["threads"].get(who, [])
		if th.size() == 0: _foot("No messages yet.")
		var f = G.ifont(15, "r")
		for m in th:
			var row = HBoxContainer.new(); body.add_child(row)
			var bub = PanelContainer.new()
			bub.add_stylebox_override("panel", _box(Color(0.15, 0.15, 0.16), 18, 13, 8))
			var l = Label.new(); l.text = m.text; l.autowrap = true; l.add_font_override("font", f)
			l.rect_min_size = Vector2(min(f.get_string_size(m.text).x + 2, 206), 0)
			bub.add_child(l); row.add_child(bub)
			var sp = Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(sp)
		return
	var any = false
	for who in ["benny", "kiara", "coach", "vance", "saint", "reyes"]:
		var th2 = G.S["threads"].get(who, [])
		if th2.size() == 0: continue
		any = true
		var last = str(th2[-1].text)
		var u = int(G.S["unread"].get(who, 0))
		var b = _btn("", self, "_open_thread", [who])
		b.rect_min_size = Vector2(0, 66); b.set_meta("v", "")
		var nm = str(C[who].name)
		_avatar(b, Vector2(12, 13), 40, Color(C[who].color).darkened(0.15), nm.trim_prefix("@").substr(0, 1).to_upper())
		var n = _label(b, nm, G.ifont(15, "s"), Color(1, 1, 1), Vector2(62, 13)); n.clip_text = true; n.rect_size = Vector2(150, 20)
		var pv = _label(b, last, G.ifont(13, "r"), TXT2, Vector2(62, 35)); pv.clip_text = true; pv.rect_size = Vector2(176, 18)
		if u > 0:
			var d = Panel.new(); d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			d.anchor_left = 1; d.anchor_right = 1; d.margin_left = -50; d.margin_right = -30; d.margin_top = 13; d.margin_bottom = 31
			d.add_stylebox_override("panel", _box(ACCENT, 9, 0, 0)); b.add_child(d)
			var dl = _label(d, str(u), G.ifont(11, "s"), Color(1, 1, 1)); dl.rect_size = Vector2(20, 18); dl.align = Label.ALIGN_CENTER; dl.valign = Label.VALIGN_CENTER
	if not any: _foot("No messages yet. People text you as the story moves.")

func _open_thread(who):
	thread = who; show_app("msgs")
func _msgs_back():
	thread = null; show_app("msgs")

# ---------- Jobs ----------
func _app_jobs():
	var st = main.story
	_foot("Track a job to put it on your map.")
	for id in st.JOB_IDS:
		var ok = st.job_available(id)
		var cast = G.D["CAST"][st.JOB_GIVER[id]]
		var tracked = G.S.get("tracked") == id
		var v = _card()
		var h = HBoxContainer.new(); v.add_child(h)
		var t = Label.new(); t.text = st.JOB_TITLE[id]; t.add_font_override("font", G.ifont(16, "s")); t.clip_text = true
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_color_override("font_color", Color(1, 1, 1) if ok else Color(0.45, 0.45, 0.48)); h.add_child(t)
		if tracked:
			var tl = Label.new(); tl.text = "● Tracking"; tl.add_font_override("font", G.ifont(12, "s")); tl.add_color_override("font_color", GREEN); h.add_child(tl)
		var g = Label.new(); g.text = str(cast.name); g.add_font_override("font", G.ifont(12, "m"))
		g.add_color_override("font_color", Color(cast.color).lightened(0.2) if ok else Color(0.4, 0.4, 0.43)); v.add_child(g)
		var d = Label.new(); d.text = st.job_desc(id) if ok else st.job_lock(id); d.autowrap = true; d.add_font_override("font", G.ifont(13, "r"))
		d.add_color_override("font_color", Color(0.78, 0.78, 0.82) if ok else Color(0.4, 0.4, 0.43)); v.add_child(d)
		if ok:
			var row = HBoxContainer.new(); v.add_child(row)
			var b = _btn(("Untrack" if tracked else "Track") + "  ·  " + st.job_reward(id), self, "_track", [id], false, row)
			b.rect_min_size = Vector2(0, 32); b.clip_text = false
			var bc = Color(0.2, 0.2, 0.21) if tracked else ACCENT
			b.add_stylebox_override("normal", _box(bc, 16, 14, 6)); b.add_stylebox_override("hover", _box(bc.lightened(0.1), 16, 14, 6))
			b.add_stylebox_override("pressed", _box(bc.darkened(0.15), 16, 14, 6)); b.add_stylebox_override("focus", _ring(Color(1, 1, 1), 16, 2))
			b.add_font_override("font", G.ifont(13, "s"))
			if tracked:
				for cn in ["font_color", "font_color_hover", "font_color_focus"]: b.add_color_override(cn, ACCENT)

func _track(id):
	main.story.track_job(id); show_app("jobs", true)

# ---------- Blok ----------
func _app_blok():
	_segmented([["feed", "Feed"], ["me", "Profile"]], blok_tab, "_blok_tab")
	_action("Post a photo", "show_app", ["camera"])
	if blok_tab == "me":
		var so = G.S["social"]
		var v = _card()
		var top = HBoxContainer.new(); v.add_child(top)
		var avc = Control.new(); avc.rect_min_size = Vector2(56, 56); top.add_child(avc)
		_avatar(avc, Vector2(), 56, Color(1, 0.62, 0.04), str(G.S["name"]).substr(0, 1).to_upper())
		var nv = VBoxContainer.new(); nv.add_constant_override("separation", 2); top.add_child(nv)
		var hn = Label.new(); hn.text = "@" + str(G.S["name"]); hn.add_font_override("font", G.ifont(17, "s")); nv.add_child(hn)
		var cnt = Label.new(); cnt.text = "%d posts · %s followers · %d following" % [so["posts"].size(), G.fmt_money(main.blok.followers()).substr(1), int(so.get("following", 96))]
		cnt.add_font_override("font", G.ifont(12, "r")); cnt.add_color_override("font_color", TXT2); nv.add_child(cnt)
		var bio = Label.new(); bio.text = str(so.get("bio", "")); bio.autowrap = true; bio.add_font_override("font", G.ifont(13, "r")); v.add_child(bio)
		for p in so["posts"]: _post_card("@" + str(G.S["name"]), Color(1, 0.62, 0.04), p.caption, p.get("img"), p.likes, p.comments, p.at, p.kind)
		if so["posts"].size() == 0: _foot("No posts yet. Record a track, shoot a video or take a photo.")
		return
	var posts = []
	for p in G.S["social"]["posts"]: posts.append([float(p.at), "@" + str(G.S["name"]), Color(1, 0.62, 0.04), p.caption, p.get("img"), p.likes, p.comments, p.kind])
	for f in G.S["feed"]: posts.append([float(f.get("at", 0)), f.h, Color(0.45, 0.5, 0.58), f.text, null, int(f.get("likes", 0)), [], "text"])
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
	var v = _card(null, 12)
	v.add_constant_override("separation", 6)
	var h = HBoxContainer.new(); v.add_child(h)
	var avc = Control.new(); avc.rect_min_size = Vector2(24, 24); h.add_child(avc)
	_avatar(avc, Vector2(), 24, col, str(handle).trim_prefix("@").substr(0, 1).to_upper())
	var hl = Label.new(); hl.text = handle; hl.add_font_override("font", G.ifont(13, "s")); hl.clip_text = true; hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.valign = Label.VALIGN_CENTER; h.add_child(hl)
	var tl = Label.new(); tl.text = _ago(at); tl.add_font_override("font", G.ifont(12, "r")); tl.add_color_override("font_color", TXT2); tl.valign = Label.VALIGN_CENTER; h.add_child(tl)
	var tex = main.blok.texture_for(img)
	if tex:
		var tr = TextureRect.new(); tr.texture = tex; tr.expand = true; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.rect_min_size = Vector2(254, 143); tr.size_flags_horizontal = 0
		tr.material = _round_mat(Vector2(254, 143), 10)
		v.add_child(tr)
	elif kind == "track":
		var cover = PanelContainer.new(); cover.add_stylebox_override("panel", _box(Color(0.42, 0.2, 0.05), 10, 12, 12)); v.add_child(cover)
		var ct = Label.new(); ct.text = "♪  " + str(text).to_upper(); ct.autowrap = true; ct.add_font_override("font", G.ifont(15, "b")); cover.add_child(ct)
	var t = Label.new(); t.text = str(text); t.autowrap = true; t.add_font_override("font", G.ifont(14, "r")); v.add_child(t)
	var meta = Label.new(); meta.text = "♥ %d   ·   %d comments" % [int(likes), comments.size()]; meta.add_font_override("font", G.ifont(12, "r")); meta.add_color_override("font_color", TXT2); v.add_child(meta)
	var last = comments.slice(max(0, comments.size() - 2), comments.size() - 1) if comments.size() > 0 else []
	for c in last:
		var cl = Label.new(); cl.text = c.h + "  " + c.t; cl.autowrap = true; cl.add_font_override("font", G.ifont(12, "r")); v.add_child(cl)

# ---------- Camera ----------
const CAPTIONS = ["Calder after dark", "the Hawk is out", "booth tonight", "Bishop St forever", "-10 and still outside", "lake effect", "who want smoke? (snowball)", "new fit", "my block", "the L at night"]
func _app_camera():
	_foot("Pick a caption. The phone hides for the shot and it posts to Blok.")
	for c in CAPTIONS:
		_cell(c, "", "_snap", [c])

func _snap(caption):
	close(true)
	yield(get_tree().create_timer(0.25), "timeout")
	main.blok.take_photo(caption)
	main.hud.toast("Blok:  Posted “%s”" % caption)

# ---------- Online ----------
func _typed(t, dict_name, key):
	if dict_name == "srv": srv_form[key] = t
	elif dict_name == "join": join_pw = t
	elif dict_name == "chat": chat_text = t

func _app_online():
	_missions_section()
	var net = main.net
	net.lan_listen(net.mode in ["off", "browse", "lan_client"])
	if net.mode == "off" and not net.browsing: net.browse(true)
	var n = net.R.size() + 1
	var head = "Playing solo"
	if net.mode == "relay" and net.server != null:
		head = ("%s · %d/%d" % [net.server.name, n, net.server.max]) if net.online() else "Connecting to " + net.server.name + "…"
		if net.online() and not net.hosting and not net.welcomed: head = "Joining " + net.server.name + "…"
	elif net.mode == "relay": head = ("Room %s · %d here" % [net.room_label(), n]) if net.online() else "Connecting…"
	elif net.mode == "lan_host" and net.server != null: head = "%s · %d/%d · direct" % [net.server.name, n, net.server.max]
	elif net.mode == "lan_host": head = "Hosting on this network · %d here" % n
	elif net.mode == "lan_client" and net.server != null:
		head = ("%s · %d/%d" % [net.server.name, n, net.server.max]) if net.welcomed else ("Joining " + net.server.name + "…")
	elif net.mode == "lan_client": head = ("Joined · %d here" % n) if net.online() else "Joining…"
	if net.mode != "off" and net.mode != "browse":
		var hv = _card()
		var hl = Label.new(); hl.text = head; hl.autowrap = true; hl.add_font_override("font", G.ifont(17, "s"))
		hl.add_color_override("font_color", GREEN if net.online() else Color(1, 0.62, 0.04)); hv.add_child(hl)
		if net.note != "":
			var nl = Label.new(); nl.text = net.note; nl.autowrap = true; nl.add_font_override("font", G.ifont(12, "r")); nl.add_color_override("font_color", TXT2); hv.add_child(nl)
		if net.server != null:
			if net.server.motd != "":
				var ml = Label.new(); ml.text = net.server.motd; ml.autowrap = true; ml.add_font_override("font", G.ifont(14, "r")); hv.add_child(ml)
			var pl = Label.new(); pl.text = "PvP " + ("on" if net.server.pvp else "off") + ("  ·  password" if net.server.pw else "")
			pl.add_font_override("font", G.ifont(12, "r")); pl.add_color_override("font_color", TXT2); hv.add_child(pl)
	if net.mode == "off" or net.mode == "browse":
		_sec("Servers")
		var list = net.server_list()
		for sv in list.slice(0, 11) if list.size() > 12 else list:
			var tags = ["%d/%d" % [sv.p, sv.x]]
			if sv.r != "": tags.append(sv.r)
			if sv.d: tags.append("24h")
			if sv.get("a", "") != "": tags.append("direct")
			if sv.k: tags.append("pw")
			if not sv.pvp: tags.append("no PvP")
			_cell(sv.name, PoolStringArray(tags).join(" · "), "_pick_server", [sv.sid], sv.p >= sv.x)
			if join_sid == sv.sid:
				if sv.motd != "": _foot(sv.motd, Color(0.85, 0.85, 0.9))
				if sv.k: _edit(join_pw, "Server password", "pw", "join", true)
				_primary("Join " + sv.name, "_join_server", [sv.sid])
		_foot(("Looking for servers…" if net.status != "online" else "No servers right now. Create one below.") if list.empty() else "Servers anyone in the world can join, on Android, Linux, Windows and Mac. No ports to open.")
		_sec("Create a server")
		if srv_form.name == "": srv_form.name = "@%s's server" % str(G.S.get("name", "player"))
		_edit(srv_form.name, "Server name", "name", "srv", false, 32)
		_edit(srv_form.motd, "Message of the day (optional)", "motd", "srv", false, 120)
		_edit(srv_form.pw, "Password (optional)", "pw", "srv", true, 32)
		_cell("Players", str(int(srv_form.max)), "_srv_max")
		_switch("PvP", srv_form.pvp, "_srv_pvp")
		_switch("Direct connection (faster)", srv_form.direct, "_srv_direct")
		_primary("Create server", "_create_server")
		_foot("Your game hosts the server while it is open. For one that stays up day and night, run the dedicated server (servidor.sh / servidor.bat).")
		_sec("Quick play")
		_action("Public room", "_go_public")
		_action("Create a private room", "_go_private")
		ip_edit = _edit(str(G.S["settings"].get("lastRoom", "")), "Room code from a friend", "code", "none", false, 12)
		_action("Join private room", "_go_code")
		_sec("Join by address")
		lan_edit = _edit(str(G.S["settings"].get("lastIp", "")), "Server address, e.g. 203.0.113.5:24680", "ip", "none", false, 60)
		addr_pw_edit = _edit("", "Password (if it has one)", "pw", "none", true, 32)
		_action("Join", "_join")
		_foot("Any server by its address: a friend's, a dedicated server, one on this Wi-Fi. No server list or relay needed.")
		_sec("Same Wi-Fi")
		_action("Host on this network", "_host")
		if net.LAN.size() > 0:
			for k in net.LAN.keys():
				var g = net.LAN[k]
				_cell("@" + str(g.name), "%d playing" % g.players, "_join_lan", [g.ip, g.port])
	else:
		if net.server != null:
			_sec("Chat")
			var cv = _card()
			var start = max(0, net.chat.size() - 8)
			for i in range(start, net.chat.size()):
				var c = net.chat[i]
				var cl = Label.new(); cl.autowrap = true; cl.text = "@%s  %s" % [c.n, c.m]; cl.add_font_override("font", G.ifont(13, "r")); cv.add_child(cl)
			if net.chat.size() == 0:
				var e = Label.new(); e.text = "No messages yet."; e.add_font_override("font", G.ifont(13, "r")); e.add_color_override("font_color", TXT2); cv.add_child(e)
			var ce = _edit(chat_text, "Message", "m", "chat", false, 120)
			ce.connect("text_entered", self, "_send_chat_enter")
			_primary("Send", "_send_chat")
			if net.hosting: _foot("You are hosting. Players anywhere see your server in Online → Servers. Leaving closes it.", Color(1, 0.62, 0.04))
		elif net.mode == "relay" and net.room != net.PUBLIC_ROOM:
			var rv = _card()
			var rc = Label.new(); rc.text = net.room.to_upper(); rc.align = Label.ALIGN_CENTER; rc.add_font_override("font", G.ifont(40, "b") if net.room.length() <= 6 else G.ifont(24, "b"))
			rc.add_color_override("font_color", Color(1, 0.62, 0.04)); rv.add_child(rc)
			var rt = Label.new(); rt.text = "Send this code to your friends. They open Online, type it and press Join."; rt.autowrap = true; rt.align = Label.ALIGN_CENTER
			rt.add_font_override("font", G.ifont(12, "r")); rt.add_color_override("font_color", TXT2); rv.add_child(rt)
		if net.mode == "lan_host" and net.server != null:
			var addr = net.pub_addr if net.pub_addr != "" else (net.lan_addr + " (this network)")
			_foot("Address: %s   ·   %s" % [addr, { "checking": "opening the port…", "open": "port open", "closed": "port closed" }.get(net.port_state, "")])
		elif net.mode == "lan_host":
			_foot("Your address: " + PoolStringArray(net.my_ips()).join(", ") + "  ·  port %d (UDP)" % net.PORT)
		_sec("Players")
		for r in net.R.values():
			var gt = (" [" + str(r.gang[2]) + "]") if typeof(r.gang) == TYPE_ARRAY else ""
			var can = typeof(G.S.get("gang")) == TYPE_DICTIONARY and not net._same_gang(r)
			_cell("@" + r.name + gt, "Invite" if can else "", "_invite", [r.id], not can)
			if net.hosting: _danger("Kick @" + r.name, "_kick", [r.id])
		if net.R.size() == 0: _foot("Nobody else here yet.")
		_action("Refresh", "show_app", ["online"])
		_danger("Close server and leave" if net.hosting else "Leave", "_leave_net")
	if net.invites.size() > 0:
		_sec("Gang invites")
		for i in range(net.invites.size()):
			var inv = net.invites[i]
			_cell("[%s] %s" % [str(inv.g[2]).substr(0, 4), str(inv.g[1]).substr(0, 18)], "Join", "_accept", [i])

func _pick_server(sid):
	join_sid = sid; join_pw = ""
	var sv = main.net.servers.get(sid)
	if sv != null and not sv.k:
		_join_server(sid); return
	show_app("online", true)

func _join_server(sid):
	if not main.net.join_server(sid, join_pw):
		main.hud.toast("That server is gone"); show_app("online"); return
	join_sid = ""
	show_app("online")

func _srv_max():
	var order = [4, 8, 16, 24, 32, 64]
	srv_form.max = order[(order.find(int(srv_form.max)) + 1) % order.size()]
	show_app("online", true)

func _srv_direct():
	srv_form.direct = not srv_form.direct
	show_app("online", true)

func _srv_pvp():
	srv_form.pvp = not srv_form.pvp
	show_app("online", true)

func _create_server():
	var nm = main.net.clean_text(srv_form.name, 32)
	if nm.length() < 3:
		main.hud.toast("Give the server a name"); return
	if not main.gang.text_ok(nm):
		main.hud.toast("Pick a different name"); return
	main.net.host_server({ "name": nm, "motd": srv_form.motd, "pw": srv_form.pw, "max": srv_form.max, "pvp": srv_form.pvp, "direct": srv_form.direct })
	show_app("online")

func _send_chat_enter(_t):
	_send_chat()

func _send_chat():
	if main.net.send_chat(chat_text):
		chat_text = ""
	show_app("online", true)

func _kick(id):
	main.net.kick(id); show_app("online", true)

func _go_public():
	main.net.go_online(main.net.PUBLIC_ROOM); show_app("online")
func _go_private():
	main.net.go_online(main.net.new_room_code()); show_app("online")
func _go_code():
	var code = main.net.clean_room(ip_edit.text if ip_edit else "")
	if code == "":
		main.hud.toast("Type the room code first"); return
	G.S["settings"]["lastRoom"] = code
	main.net.go_online(code); show_app("online")

func _host():
	main.net.host(); show_app("online")
func _join():
	var ip = lan_edit.text if lan_edit else ""
	G.S["settings"]["lastIp"] = ip
	main.net.join_addr(ip, addr_pw_edit.text if addr_pw_edit else ""); show_app("online")
func _join_lan(ip, port):
	main.net.join(ip, port); show_app("online")
func _invite(id):
	main.net.invite(id)
func _accept(i):
	main.net.accept_invite(i); show_app("online")
func _leave_net():
	main.net.leave(); show_app("online")

# ---------- Missions (in the Online app) ----------
func _missions_section():
	var M = main.missions
	if M == null: return
	_sec("Missions")
	var c = M.cur
	if c != null and c.phase != "done":
		var K = M.KINDS[c.kind]
		var mv = _card()
		var ml = Label.new(); ml.text = K.name; ml.add_font_override("font", G.ifont(17, "s")); ml.add_color_override("font_color", K.col); mv.add_child(ml)
		var info = ""
		if c.phase == "lobby": info = "Started by @%s · starts in %d s" % [c.owner, int(max(0, c.at - M.now()))]
		else: info = "On now · started by @%s" % c.owner
		if c.kind == "race": info += " · " + M.ROUTES[int(c.d.route)].name
		elif c.kind == "drop": info += " · %s to %s" % [G.D["LOC"][c.d.from].name, G.D["LOC"][c.d.to].name]
		elif c.kind == "raid": info += " · " + main.turf.block_name(int(c.d.b))
		var il = Label.new(); il.text = info; il.autowrap = true; il.add_font_override("font", G.ifont(12, "r")); il.add_color_override("font_color", TXT2); mv.add_child(il)
		var names = []
		for n in c.joined: names.append("@" + n)
		var jl = Label.new(); jl.text = "In: " + PoolStringArray(names).join(", "); jl.autowrap = true; jl.add_font_override("font", G.ifont(12, "r")); mv.add_child(jl)
		if c.phase == "lobby" and not c["in"]: _primary("Join", "_mis_join")
		elif c["in"]: _danger("Leave the mission", "_mis_leave")
		return
	var on = main.net.online() and main.net.mode != "browse"
	_foot(("Start one and everyone here can join for %d seconds." % int(M.LOBBY)) if on else "Playing solo: missions start right away. Go online to play them with others.")
	for k in ["race", "drop", "raid"]:
		var K2 = M.KINDS[k]
		var why = M.can_start(k)
		_cell(K2.name, "Start" if why == "" else why, "_mis_start", [k], why != "", "action")
		_foot(K2.desc)

func _mis_start(k):
	main.missions.start(k); show_app("online", true)
func _mis_join():
	main.missions.join(); show_app("online", true)
func _mis_leave():
	main.missions.leave(); show_app("online", true)

# ---------- Maps ----------
func _app_map():
	var m = BigMap.new(); m.name = "BigMap"; m.main = main; m.rect_min_size = Vector2(SW - 34, 400)
	body.add_child(m)
	_foot("You are on " + main.hud.street_name(main.player.pos), Color(0.85, 0.85, 0.9))

# ---------- Gang ----------
func _app_gang():
	var g = G.S.get("gang")
	var GA = main.gang
	if g == null:
		var iv = _card()
		var it = Label.new(); it.text = "Start a gang"; it.add_font_override("font", G.ifont(17, "s")); iv.add_child(it)
		var id = Label.new(); id.autowrap = true; id.add_font_override("font", G.ifont(13, "r")); id.add_color_override("font_color", TXT2)
		id.text = "Pick a name, a tag and a colour, then recruit people off the street (they wear a RECRUIT tag; walk up and press E) or from this app. Keep it made up: no real gangs."
		iv.add_child(id)
		_sec("Name and tag")
		var n = LineEdit.new(); n.text = form.name; n.max_length = 18; n.placeholder_text = "Name, e.g. Lakeshore Kings"; n.connect("text_changed", self, "_form", ["name"]); body.add_child(n)
		var t = LineEdit.new(); t.text = form.tag; t.max_length = 4; t.placeholder_text = "Tag, e.g. LSK"; t.connect("text_changed", self, "_form", ["tag"]); body.add_child(t)
		_sec("Colour")
		var row = HBoxContainer.new(); row.add_constant_override("separation", 7); body.add_child(row)
		var cols = G.D["GANG_COLORS"]
		for i in range(cols.size()):
			var b = Button.new(); b.rect_min_size = Vector2(28, 28)
			var sbx = _box(Color(cols[i]), 14, 0, 0)
			if form.color == i:
				sbx.border_color = Color(1, 1, 1); sbx.set_border_width_all(3)
			b.add_stylebox_override("normal", sbx); b.add_stylebox_override("hover", sbx); b.add_stylebox_override("pressed", sbx)
			b.add_stylebox_override("focus", _ring(ACCENT, 14, 2))
			b.connect("pressed", self, "_pick_color", [i]); row.add_child(b)
		if msg != "": _foot(msg, RED)
		_primary("Start the gang", "_make_gang")
		return
	var hv = _card()
	var gl = Label.new(); gl.text = "[%s] %s" % [g.tag, g.name]; gl.add_font_override("font", G.ifont(19, "b")); gl.add_color_override("font_color", GA.gang_color()); hv.add_child(gl)
	var gs = Label.new(); gs.text = "%s · Rep %d · %d/%d recruits" % ["You run it" if g.get("role", "leader") == "leader" else "Member", int(g.get("rep", 0)), G.S["recruits"].size(), GA.MAX_RECRUITS]
	gs.add_font_override("font", G.ifont(12, "r")); gs.add_color_override("font_color", TXT2); hv.add_child(gs)
	_segmented([["crew", "Crew"], ["turf", "Turf"], ["hire", "Recruit"], ["types", "Types"]], gang_tab, "_tab")
	if gang_tab == "turf":
		_turf_tab()
	elif gang_tab == "crew":
		if G.S["recruits"].size() == 0: _foot("Nobody yet. Walk up to people marked RECRUIT and press E, or use the Recruit tab.")
		for r in G.S["recruits"]:
			var T = G.D["RTYPES"][r.type]
			var hurt = float(r.get("hurtUntil", 0)) > G.S.get("playTime", 0)
			_sec("%s %s · %s" % [T.icon, r.name, T.name])
			var where = "At Calder General" if hurt else ("With you" if r.get("with", false) else "Holding the block")
			if not hurt: _cell("Send home" if r.get("with", false) else "Call", where, "_with", [r], false, "action")
			else: _cell("Status", where, "_with", [r], true, "action")
			_danger("Let go", "_drop", [r])
		_danger("Leave the gang", "_leave")
	elif gang_tab == "hire":
		for c in GA.candidates():
			var T2 = G.D["RTYPES"][c.type]
			var why = GA.can_recruit(c.type)
			_sec("%s %s · %s" % [T2.icon, c.name, T2.name])
			_foot(T2.perk)
			_cell(why if why != "" else "Hire", "" if why != "" else G.fmt_money(T2.cost), "_hire", [c], why != "", "action")
	else:
		for k in G.D["RTYPES"].keys():
			var T3 = G.D["RTYPES"][k]
			_sec("%s %s" % [T3.icon, T3.name])
			_kv([["Cost", G.fmt_money(T3.cost)], ["Buzz needed", str(T3.buzz)]])
			_foot(T3.perk)

func _turf_tab():
	var T = main.turf
	var mine = T.my_blocks()
	var tv = _card()
	var tl = Label.new(); tl.text = "%d of 15 blocks" % mine.size(); tl.add_font_override("font", G.ifont(19, "b")); tv.add_child(tl)
	var left = T.payday_in()
	var td = Label.new(); td.autowrap = true; td.add_font_override("font", G.ifont(12, "r")); td.add_color_override("font_color", TXT2)
	td.text = ("%s a day · payday at 6:00 AM, in %dh %02dm" % [G.fmt_money(T.daily()), int(left) / 60, int(left) % 60]) if mine.size() > 0 else "Take a corner and it pays you every morning."
	tv.add_child(td)
	if T.shared(): _foot("Online: this server's map. Every gang here plays on it.", Color(0.85, 0.85, 0.9))
	if T.raid != null:
		var R = T.raid
		var what = ("%d:%02d to get there" % [int(R.left) / 60, int(R.left) % 60]) if R.stage == "warn" else "Fighting now"
		_sec("Raid")
		_kv([[T.CREWS[R.fac].name + " on " + T.block_name(R.b), what]])
	var m = BigMap.new(); m.name = "BigMap"; m.main = main; m.rect_min_size = Vector2(SW - 34, 300)
	body.add_child(m)
	if mine.size() > 0:
		_sec("Yours")
		var rows = []
		for b in mine: rows.append([T.block_name(b), G.fmt_money(T.VAL[b]) + " a day"])
		_kv(rows)
		_foot("%d of your people hold your blocks when you're not there (everyone not rolling with you). The more, the better the odds when rivals raid at night." % T.home_recruits())
	_sec("The map")
	var cm = T.cur()
	var all = []
	for b in range(T.N):
		if b == T.COPS: continue
		if T.is_mine(cm[b]): continue
		var on = T.o_name(cm[b])
		if typeof(cm[b]) == TYPE_ARRAY: on = "[%s] %s" % [cm[b][2], cm[b][1]]
		all.append([T.block_name(b), on])
	_kv(all)
	_foot("To take a block, go to its corner (the ring on the sidewalk where its two streets meet) and hold E. Their people come in waves: hold the corner and clear the block. Area 7, the police station's block, can't be taken.")

func _form(text, key):
	form[key] = text
func _pick_color(i):
	form.color = i; show_app("gang", true)
func _make_gang():
	msg = main.gang.create(form.name, form.tag, form.color)
	show_app("gang")
func _tab(t):
	gang_tab = t; show_app("gang")
func _with(r):
	main.gang.set_with(r, not r.get("with", false)); show_app("gang", true)
func _drop(r):
	main.gang.drop(r); show_app("gang", true)
func _hire(c):
	if main.gang.hire(c.type, c.seed, c.name): main.hud.toast(c.name + " is on the way to you")
	show_app("gang", true)
func _leave():
	main.gang.leave(); show_app("gang")

# ---------- Garage ----------
func _app_garage():
	_sec("Your cars")
	for i in range(G.S["garage"].size()):
		var c = G.S["garage"][i]
		_cell(G.D["CAR_SPECS"][c.model].name, "Bring here", "_bring", [i])
	if G.S["garage"].size() == 0: _foot("No cars yet.")
	_sec("Marrow Motors")
	for model in ["sedan", "suv", "pickup", "van", "coupe", "bruiser", "boulder"]:
		var sp = G.D["CAR_SPECS"][model]
		var ok = G.S["cash"] >= sp.price and G.S["buzz"] >= sp.buzz
		_cell(sp.name, G.fmt_money(sp.price) + ((" · Buzz %d" % sp.buzz) if sp.buzz > 0 else ""), "_buy_car", [model], not ok)
	_foot("Buying parks the car nearby. Some need Buzz first.")

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

# the old in-phone style app (the Wardrobe icon now opens the full wardrobe)
func _app_style():
	var P = G.D["SKIN"]["PRESETS"]
	for i in range(P.size()):
		_cell(P[i][0], "", "_preset", [i])
	_action("Random look", "_random_look")

func _preset(i):
	G.S["skin"] = G.preset_skin(i)
	main.player._build_body(); main.player.vm_key = ""
	main.hud.toast(G.D["SKIN"]["PRESETS"][i][0])
func _random_look():
	G.S["skin"] = G.random_skin()
	main.player._build_body(); main.player.vm_key = ""

# ---------- Settings ----------
func _app_settings():
	var st = G.S["settings"]
	_sec("Controls")
	_slider("Look speed", st.get("sens", 1.0), 0.3, 2.5, 0.05, "sens")
	if main.touch.enabled: _slider("Touch look speed", st.get("touchSens", 1.0), 0.3, 3.0, 0.05, "touchSens")
	_switch("Invert look Y", st.get("invertY", false), "_toggle", ["invertY"])
	_cell("Camera", "First person" if st.get("fp", false) else "Third person", "_toggle", ["fp"])
	_switch("Head bob and tilt (first person)", st.get("headbob", true), "_headbob")
	_switch("Motion blur", st.get("motionblur", true), "_motionblur")
	var tm = str(st.get("touch", "auto"))
	_cell("On-screen controls", { "auto": "Auto", "on": "On", "off": "Off" }.get(tm, "Auto"), "_touch_mode")
	_sec("Controller and TV")
	_switch("Console mode", main.console.on, "_console_mode")
	_switch("Aim assist (controller)", st.get("aimAssist", true), "_toggle_on", ["aimAssist"])
	_switch("Vibration", st.get("rumble", true), "_toggle_on", ["rumble"])
	_foot("Console mode is for a TV and a controller: full screen, bigger text, the controller's own buttons on screen, an on-screen keyboard and a pause menu on %s." % G.pad_label("MENU"))
	_sec("Sound")
	_slider("Volume", st.get("vol", 0.8), 0, 1, 0.05, "vol")
	_slider("Music", st.get("music", 0.85), 0, 1, 0.05, "music")
	_sec("Display")
	_slider("Field of view (first person)", st.get("fov", 70), 60, 95, 1, "fov")
	var qn = { "high": "High", "medium": "Medium" }
	_cell("Graphics", qn.get(st.get("quality", "low"), "Fast"), "_quality")
	_switch("Ink outlines", st.get("outlines", true), "_outlines")
	if not OS.get_name() in ["Android", "iOS"]: _switch("Full screen", OS.window_fullscreen, "_fullscreen")
	_cell("Phone colour", PHONE_COLS.get(str(st.get("phoneCol", "glacier")), PHONE_COLS["glacier"])[0], "_phone_col")
	_foot("Fast is made for old graphics cards. High adds shadows and four street-lamp lights.")
	_sec("Progress")
	_action("Import web progress", "_import")
	_foot("On the web, open the phone, then Settings, then Export my progress. The file lands in Downloads.")
	if msg != "": _foot(msg, Color(1, 0.62, 0.04))
	_danger("Save & exit to title", "_exit")

func _slider(label, v, a, b, step, key):
	var c = _card(null, 14)
	c.add_constant_override("separation", 6)
	var h = HBoxContainer.new(); c.add_child(h)
	var l = Label.new(); l.text = label; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; l.add_font_override("font", G.ifont(15, "r")); h.add_child(l)
	var vl = Label.new(); vl.add_font_override("font", G.ifont(15, "r")); vl.add_color_override("font_color", TXT2); h.add_child(vl)
	vl.text = _slider_text(v, b, step)
	var s = HSlider.new(); s.min_value = a; s.max_value = b; s.step = step; s.value = v; s.rect_min_size = Vector2(200, 24); s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.connect("value_changed", self, "_set", [key, vl, b, step])
	c.add_child(s)

func _slider_text(v, top, step):
	if top <= 1.0: return "%d%%" % int(round(v * 100))
	if step >= 1: return str(int(v))
	return "%.2f×" % v

func _set(v, key, vl = null, top = 1.0, step = 0.05):
	if key == "padsens": G.S["settings"]["pad"]["sens"] = v
	else: G.S["settings"][key] = v
	if vl: vl.text = _slider_text(v, top, step)
func _toggle(key):
	G.S["settings"][key] = not G.S["settings"].get(key, false); show_app("settings", true)
func _toggle_on(key):
	G.S["settings"][key] = not G.S["settings"].get(key, true); show_app("settings", true)
	if key == "rumble" and G.S["settings"][key]: G.rumble(0.4, 0.4, 0.15)
func _console_mode():
	main.console.set_on(not main.console.on); show_app("settings", true)
func _motionblur():
	G.S["settings"]["motionblur"] = not G.S["settings"].get("motionblur", true); show_app("settings", true)

func _headbob():
	G.S["settings"]["headbob"] = not G.S["settings"].get("headbob", true); show_app("settings", true)
func _outlines():
	G.S["settings"]["outlines"] = not G.S["settings"].get("outlines", true)
	G.apply_outlines(); show_app("settings", true)
func _phone_col():
	var k = str(G.S["settings"].get("phoneCol", "glacier"))
	G.S["settings"]["phoneCol"] = PHONE_ORDER[(PHONE_ORDER.find(k) + 1) % PHONE_ORDER.size()]
	_tint(); show_app("settings", true)
func _touch_mode():
	var order = ["auto", "on", "off"]
	var m = order[(order.find(str(G.S["settings"].get("touch", "auto"))) + 1) % 3]
	main.touch.set_mode(m); show_app("settings", true)

func _quality():
	var order = ["low", "medium", "high"]
	var q = order[(order.find(G.S["settings"].get("quality", "low")) + 1) % 3]
	G.S["settings"]["quality"] = q; main.set_quality(q); show_app("settings", true)
func _fullscreen():
	OS.window_fullscreen = not OS.window_fullscreen; show_app("settings", true)
func _import():
	var err = G.import_web_save()
	if err == "":
		close(true)
		main.start_game(G.S)
		main.hud.banner("Progress imported", "@" + G.S["name"])
		msg = ""
	else:
		msg = err; show_app("settings", true)
func _exit():
	close(true); main.exit_to_title()

# ---------- Music ----------
# the player's controls, drawn: shuffle, previous, play / pause, next, repeat
class MediaBtn extends Button:
	var kind = "play"
	var lit = false
	var one = false
	func _ready():
		for st in ["normal", "hover", "pressed", "disabled"]: add_stylebox_override(st, StyleBoxEmpty.new())
		var f = StyleBoxFlat.new(); f.draw_center = false; f.border_color = Color(0.04, 0.52, 1.0); f.set_border_width_all(2)
		f.set_corner_radius_all(int(rect_min_size.x / 2)); f.anti_aliasing = true
		add_stylebox_override("focus", f)
	func _tri(c, w, h, dir, col):
		draw_colored_polygon(PoolVector2Array([c + Vector2(-w * dir, -h), c + Vector2(w * dir, 0), c + Vector2(-w * dir, h)]), col)
	func _draw():
		var c = rect_size / 2
		var col = Color(1, 1, 1)
		var dim = Color(1, 1, 1, 0.45)
		var acc = Color(0.04, 0.52, 1.0)
		if kind == "play" or kind == "pause":
			draw_circle(c, rect_size.x / 2 - 2, col)
			if kind == "play": _tri(c + Vector2(2, 0), 8, 10, 1, Color(0.05, 0.05, 0.06))
			else:
				draw_rect(Rect2(c + Vector2(-8, -10), Vector2(6, 20)), Color(0.05, 0.05, 0.06))
				draw_rect(Rect2(c + Vector2(2, -10), Vector2(6, 20)), Color(0.05, 0.05, 0.06))
		elif kind == "next" or kind == "prev":
			var d = 1 if kind == "next" else -1
			_tri(c + Vector2(-4 * d, 0), 7, 9, d, col)
			draw_rect(Rect2(c + Vector2(6 * d - (2 if d > 0 else 1), -9), Vector2(3, 18)), col)
		elif kind == "shuffle":
			var k = acc if lit else dim
			draw_line(c + Vector2(-10, -6), c + Vector2(10, 6), k, 2.5, true)
			draw_line(c + Vector2(-10, 6), c + Vector2(10, -6), k, 2.5, true)
			_tri(c + Vector2(10, 6), 3, 3.5, 1, k); _tri(c + Vector2(10, -6), 3, 3.5, 1, k)
		elif kind == "repeat":
			var k = acc if lit else dim
			draw_arc(c, 9, -PI * 0.15, PI * 1.6, 20, k, 2.5, true)
			_tri(c + Vector2(8, -5), 3.5, 3.5, 1, k)
			if one: draw_string(G.ifont(10, "b"), c + Vector2(-3, 4), "1", k)

var mus_title = null
var mus_artist = null
var mus_bar = null
var mus_t0 = null
var mus_t1 = null
var mus_btns = {}
var mus_lock = false

func _app_music():
	var M = main.music
	if not M.is_connected("changed", self, "_music_changed"): M.connect("changed", self, "_music_changed")
	# now playing
	var card = _card(null, 16)
	card.add_constant_override("separation", 6)
	mus_title = Label.new(); mus_title.clip_text = true; mus_title.add_font_override("font", G.ifont(19, "b")); card.add_child(mus_title)
	mus_artist = Label.new(); mus_artist.clip_text = true; mus_artist.add_font_override("font", G.ifont(14, "r")); mus_artist.add_color_override("font_color", TXT2); card.add_child(mus_artist)
	mus_bar = HSlider.new(); mus_bar.min_value = 0; mus_bar.max_value = 1; mus_bar.step = 0.1; mus_bar.rect_min_size = Vector2(0, 22)
	mus_bar.focus_mode = Control.FOCUS_NONE
	mus_bar.connect("value_changed", self, "_mus_seek")
	card.add_child(mus_bar)
	var tr = HBoxContainer.new(); card.add_child(tr)
	mus_t0 = Label.new(); mus_t0.add_font_override("font", G.ifont(11, "m")); mus_t0.add_color_override("font_color", TXT2); mus_t0.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tr.add_child(mus_t0)
	mus_t1 = Label.new(); mus_t1.add_font_override("font", G.ifont(11, "m")); mus_t1.add_color_override("font_color", TXT2); tr.add_child(mus_t1)
	var row = HBoxContainer.new(); row.alignment = BoxContainer.ALIGN_CENTER; row.add_constant_override("separation", 14); card.add_child(row)
	mus_btns = {}
	for k in ["shuffle", "prev", "play", "next", "repeat"]:
		var b = MediaBtn.new(); b.kind = k
		b.rect_min_size = Vector2(54, 54) if k == "play" else Vector2(40, 40)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.connect("pressed", self, "_mus_btn", [k])
		row.add_child(b); mus_btns[k] = b
	_music_live()
	# Spotify, for your own playlists over the game
	_sec("Spotify")
	_action("Open King Von on Spotify", "_mus_spotify", ["King Von"])
	_action("Open Spotify", "_mus_spotify", [""])
	_switch("Game music", G.S["settings"].get("gameMusic", true), "_toggle_on", ["gameMusic"])
	_foot("Spotify opens in its own app and keeps playing while you're in the game. Turn Game music off to hear only Spotify.")
	# your own songs
	_sec("My music")
	var own = M.album("My music")
	for j in range(own.size()):
		var t = M.lib[own[j]]
		_cell(("▶ " if M.cur == t else "") + t.title, t.artist, "_mus_pick", ["My music", j])
	_foot("%sAdd songs you own: put MP3, OGG or WAV files in\n%s\nName them \"Artist - Title\" to show the artist." % ["" if own.empty() else "", M.folder()])
	if not OS.get_name() in ["Android", "iOS"]: _action("Open the folder", "_mus_folder")
	_action("Refresh", "_mus_scan")
	if M.skipped.size() > 0:
		var names = []
		for sk in M.skipped: names.append("%s (%s)" % [sk[0], sk[1]])
		_foot("Skipped: " + PoolStringArray(names).join(", "), Color(1, 0.62, 0.04))
	# the game's own music
	for al in [["Radio", "Radio sets"], ["Beats", "Basement 808 beats"]]:
		_sec(al[1])
		var ids = M.album(al[0])
		for j in range(ids.size()):
			var t = M.lib[ids[j]]
			_cell(("▶ " if M.cur == t else "") + t.title, t.artist, "_mus_pick", [al[0], j])

func _fmt_t(t):
	t = int(max(0, t))
	return "%d:%02d" % [t / 60, t % 60]

func _music_live():
	if mus_title == null or not is_instance_valid(mus_title): return
	var M = main.music
	var t = M.cur
	mus_title.text = t.title if t else "Nothing playing"
	mus_artist.text = (t.artist if t.artist != "" else t.album) if t else "Pick a song below, or press play"
	mus_lock = true
	mus_bar.max_value = max(1.0, M.length)
	mus_bar.value = M.position()
	mus_lock = false
	mus_t0.text = _fmt_t(M.position())
	mus_t1.text = "-" + _fmt_t(M.length - M.position()) if t else "0:00"
	var pb = mus_btns.get("play")
	if pb:
		var k = "pause" if M.playing() else "play"
		if pb.kind != k:
			pb.kind = k; pb.update()
	var sh = mus_btns.get("shuffle")
	if sh and sh.lit != M.shuffle_on():
		sh.lit = M.shuffle_on(); sh.update()
	var rp = mus_btns.get("repeat")
	if rp:
		var lit = M.repeat_mode() != "off"
		var one = M.repeat_mode() == "one"
		if rp.lit != lit or rp.one != one:
			rp.lit = lit; rp.one = one; rp.update()

func _music_changed():
	if panel.visible and app == "music": show_app("music", true)

func _mus_btn(k):
	var M = main.music
	if k == "play": M.toggle()
	elif k == "next": M.next()
	elif k == "prev": M.prev()
	elif k == "shuffle": M.set_shuffle(not M.shuffle_on())
	elif k == "repeat": M.cycle_repeat()
	_music_live()

func _mus_seek(v):
	if not mus_lock: main.music.seek(v)

func _mus_pick(al, j):
	var M = main.music
	M.play_from(M.album(al), j)

func _mus_spotify(q):
	if q == "": OS.shell_open("https://open.spotify.com")
	else: main.music.open_spotify(q)

func _mus_folder():
	main.music.open_folder()

func _mus_scan():
	main.music.scan()
	show_app("music", true)

# ---------- Controller ----------
func _app_pad():
	var pads = Input.get_connected_joypads()
	if pads.size() == 0:
		_foot("No controller found. Plug one in or pair it over Bluetooth; Xbox, PlayStation and most others work.", Color(1, 0.62, 0.04))
	for i in pads:
		_kv([["Connected", Input.get_joy_name(i)]])
	_slider("Stick look speed", G.S["settings"]["pad"].get("sens", 1.0), 0.4, 2.5, 0.05, "padsens")
	_action("Show the controls", "_show_controls")
	_sec("Buttons")
	var L = funcref(G, "pad_label")
	_kv([["Move · look", "Left stick · right stick"], ["Shoot · aim", "%s · %s" % [L.call_func("RT"), L.call_func("LT")]], ["Jump · crouch · reload", "%s · %s · %s" % [L.call_func("A"), L.call_func("B"), L.call_func("X")]],
		["Car · use · weapon", "%s · %s · %s" % [L.call_func("Y"), L.call_func("RB"), L.call_func("LB")]], ["Sprint · view", "%s · %s" % [L.call_func("LS"), L.call_func("RS")]],
		["Phone · bandage", "D-pad ↑ · ↓"], ["Emotes · finger", "D-pad ← · →"], ["Pause · map", "%s · %s" % [L.call_func("MENU"), L.call_func("VIEW")]], ["Gas · brake · handbrake", "%s · %s · %s" % [L.call_func("RT"), L.call_func("LT"), L.call_func("A")]],
		["Burnout · donuts", "%s + %s standing still, steer to spin" % [L.call_func("RT"), L.call_func("LT")]]])

func _show_controls():
	close(true); main.console.controls()

# ---------- Stats ----------
func _app_stats():
	var S = G.S
	_kv([["Cash", G.fmt_money(S["cash"])], ["Buzz", str(int(S["buzz"]))], ["Heat", str(int(S["heat"]))]])
	_sec("Career")
	_kv([["Shots fired", str(S["stats"].get("shots", 0))], ["Punches", str(S["stats"].get("punches", 0))], ["Knockouts", str(S["stats"].get("knockouts", 0))], ["Cars taken", str(S["stats"].get("carsTaken", 0))],
		["Times busted", str(S["stats"].get("busted", 0))], ["Distance walked", "%.1f km" % (S["stats"].get("dist", 0) / 1000.0)], ["Tracks (web)", str(S["stats"].get("tracks", 0))]])
