extends Node
# The heads-up display, in the style of a modern open-world game (an original design):
#  - bottom left: a rounded, rotating map with buildings and blips, health / warmth / stamina
#    bars under it, and the notification feed above it
#  - top left: the help box ("[E] Enter Basement 808")
#  - top right: weapon and ammo, cash, wanted stars, Buzz and Heat
#  - bottom right: street and area, clock and temperature, speed and radio in a car
#  - centre: big messages, subtitles, the current objective, crosshair and hit marker
#  - weapon wheel (hold Q / LB) and emote wheel (hold Z / D-pad left)
#  - menus for the places you walk into, the endings screen, fades

var main
var layer
var root
var minimap
var tags
var wheel
var top_right
var lbl_cash
var lbl_cash_delta
var stars
var lbl_weapon
var lbl_ammo
var weapon_icon
var meter_buzz
var meter_heat
var bars
var help_box
var help_lbl
var feed
var lbl_street
var lbl_area
var lbl_clock
var lbl_speed
var lbl_radio
var big_title
var big_sub
var big_band
var sub_box
var sub_who
var sub_text
var objective
var cross
var hit
var vignette
var vig_mat
var fade
var fade_target = 0.0
var fade_speed = 2.0
var menu_box = null
var menu_items = []
var menu_desc = null
var banner_t = 0.0
var sub_t = 0.0
var hit_t = 0.0
var hurt_v = 0.0
var lake_cd = 0.0
var cash_shown = -1
var cash_delta_t = 0.0
var wheel_kind = ""
var wheel_hold = 0.0
var wheel_vec = Vector2()
var wheel_sel = -1
var last_emote = "dance1"

const C_BG = Color(0.03, 0.04, 0.07, 0.72)
const C_TEXT = Color(0.96, 0.97, 1.0)
const C_DIM = Color(0.72, 0.78, 0.86)
const C_ACCENT = Color(1.0, 0.62, 0.22)
const C_CASH = Color(0.45, 0.92, 0.55)
const EMOTES = [["wave", "Wave"], ["flip", "Finger"], ["dance1", "Two-step"], ["dance2", "Arm wave"], ["dance3", "Robot"], ["hype", "Hype"], ["clap", "Clap"], ["laugh", "Laugh"],
	["shrug", "Shrug"], ["salute", "Salute"], ["point", "Point"], ["facepalm", "Facepalm"], ["flex", "Flex"], ["sit", "Sit"], ["snowangel", "Snow angel"], ["flop", "Flop"]]
const WEAPONS = [["fists", "Fists"], ["k9", "K9"], ["draft", "Draft"], ["plow", "Snowplow"], ["snowball", "Snowball"]]

static func _sb(col, r = 10, pad = 10):
	var sb = StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(r)
	sb.content_margin_left = pad; sb.content_margin_right = pad; sb.content_margin_top = pad * 0.6; sb.content_margin_bottom = pad * 0.6
	return sb

# ---------- the map ----------
class MiniMap extends Control:
	var main
	var zoom = 1.7
	func _w2m(p, P, c, s, ctr):
		var dx = (p.x - P.pos.x) * zoom
		var dz = (p.z - P.pos.z) * zoom
		return ctr + Vector2(dx * c - dz * s, dx * s + dz * c)
	func _draw():
		var sz = rect_size
		var ctr = Vector2(sz.x / 2, sz.y * 0.62)
		var P = main.player
		var want = 1.7 if not P.car else clamp(1.4 - abs(P.car.speed) * 0.02, 0.8, 1.4)
		zoom = lerp(zoom, want, 0.05)
		var yaw = P.cam_yaw
		var c = cos(yaw)
		var s = sin(yaw)
		draw_rect(Rect2(Vector2(), sz), Color(0.07, 0.09, 0.12, 0.9))
		var half = max(sz.x, sz.y) / zoom * 0.9
		# lake and pond
		var lx = float(G.D["LAKE_X"])
		if P.pos.x + half > lx:
			var pts = PoolVector2Array()
			for q in [Vector3(lx, 0, P.pos.z - half * 2), Vector3(lx + 400, 0, P.pos.z - half * 2), Vector3(lx + 400, 0, P.pos.z + half * 2), Vector3(lx, 0, P.pos.z + half * 2)]:
				pts.append(_w2m(q, P, c, s, ctr))
			draw_colored_polygon(pts, Color(0.16, 0.3, 0.42))
		var pond = G.D["POND"]
		draw_circle(_w2m(Vector3(pond.x, 0, pond.z), P, c, s, ctr), float(pond.r) * zoom, Color(0.2, 0.34, 0.46))
		# roads
		for x in G.D["XL"]:
			_line(Vector3(x, 0, -260), Vector3(x, 0, 260), P, c, s, ctr, 11.0)
		for z in G.D["ZL"]:
			_line(Vector3(-260, 0, z), Vector3(G.D["ROAD_X_END"], 0, z), P, c, s, ctr, 11.0)
		# buildings
		for b in W.query(P.pos.x - half, P.pos.z - half, P.pos.x + half, P.pos.z + half):
			if b.y1 < 2.5 or b.tag == "bound" or (b.x1 - b.x0) * (b.z1 - b.z0) < 6: continue
			var poly = PoolVector2Array([_w2m(Vector3(b.x0, 0, b.z0), P, c, s, ctr), _w2m(Vector3(b.x1, 0, b.z0), P, c, s, ctr), _w2m(Vector3(b.x1, 0, b.z1), P, c, s, ctr), _w2m(Vector3(b.x0, 0, b.z1), P, c, s, ctr)])
			draw_colored_polygon(poly, Color(0.2, 0.23, 0.28) if b.y1 < 9 else Color(0.24, 0.27, 0.33))
		# blips
		for v in main.vehicles.VEH:
			if v.dead or v == main.vehicles.own_car: continue
			if v.cop: _dot(v.pos, Color(1, 0.25, 0.25) if int(G.REAL_T * 4) % 2 == 0 else Color(0.3, 0.5, 1), 4.0, P, c, s, ctr)
		if main.vehicles.own_car and not main.vehicles.own_car.dead and P.car != main.vehicles.own_car:
			_car(main.vehicles.own_car.pos, Color(0.48, 0.88, 0.65), P, c, s, ctr)
		for e in main.crews.ENEMIES:
			if not e.is_down(): _dot(e.pos, Color(1, 0.28, 0.22), 4.0, P, c, s, ctr)
		for cp in main.police.COPS:
			if not cp.is_down(): _dot(cp.pos, Color(0.35, 0.55, 1), 4.0, P, c, s, ctr)
		for f in main.gang.FOL:
			if not f.riding: _dot(f.pos, main.gang.gang_color(), 3.5, P, c, s, ctr)
		for r in main.net.R.values():
			_dot(r.pos, Color(1, 1, 1), 4.5, P, c, s, ctr)
		# the tracked job, pinned to the edge when it is far away
		var tr = G.S.get("tracked")
		if tr != null and main.story.job_available(tr):
			var w = main.story.job_where(tr)
			if w != null:
				var col = Color(G.D["CAST"][main.story.JOB_GIVER[tr]].color)
				var q = _w2m(w, P, c, s, ctr)
				q.x = clamp(q.x, 9, sz.x - 9); q.y = clamp(q.y, 9, sz.y - 9)
				draw_colored_polygon(PoolVector2Array([q + Vector2(0, -8), q + Vector2(7, 0), q + Vector2(0, 8), q + Vector2(-7, 0)]), col)
				draw_polyline(PoolVector2Array([q + Vector2(0, -8), q + Vector2(7, 0), q + Vector2(0, 8), q + Vector2(-7, 0), q + Vector2(0, -8)]), Color(0, 0, 0, 0.7), 1.5)
		# north marker on the rim
		var nd = Vector2(-s, -c)
		var npt = ctr + nd * 1000
		var t = 1.0
		if abs(npt.x - ctr.x) > 0.01: t = min(t, ((sz.x - 12 if npt.x > ctr.x else 12) - ctr.x) / (npt.x - ctr.x))
		if abs(npt.y - ctr.y) > 0.01: t = min(t, ((sz.y - 12 if npt.y > ctr.y else 12) - ctr.y) / (npt.y - ctr.y))
		var np2 = ctr + (npt - ctr) * t
		draw_circle(np2, 9, Color(0.05, 0.06, 0.08, 0.9))
		draw_string(G.font_xs, np2 + Vector2(-4, 5), "N", Color(1, 1, 1))
		# you
		draw_colored_polygon(PoolVector2Array([ctr + Vector2(0, -9), ctr + Vector2(-6, 6), ctr + Vector2(0, 3), ctr + Vector2(6, 6)]), Color(1, 1, 1))
		draw_polyline(PoolVector2Array([ctr + Vector2(0, -9), ctr + Vector2(-6, 6), ctr + Vector2(0, 3), ctr + Vector2(6, 6), ctr + Vector2(0, -9)]), Color(0, 0, 0, 0.8), 1.2)
	func _line(a, b, P, c, s, ctr, w):
		draw_line(_w2m(a, P, c, s, ctr), _w2m(b, P, c, s, ctr), Color(0.42, 0.45, 0.5), w * zoom * 0.55)
	func _dot(p, col, r, P, c, s, ctr):
		var q = _w2m(p, P, c, s, ctr)
		if Rect2(Vector2(-6, -6), rect_size + Vector2(12, 12)).has_point(q):
			draw_circle(q, r + 1.2, Color(0, 0, 0, 0.7)); draw_circle(q, r, col)
	func _car(p, col, P, c, s, ctr):
		var q = _w2m(p, P, c, s, ctr)
		q.x = clamp(q.x, 8, rect_size.x - 8); q.y = clamp(q.y, 8, rect_size.y - 8)
		draw_rect(Rect2(q - Vector2(6, 4), Vector2(12, 8)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(q - Vector2(5, 3), Vector2(10, 6)), col)

class MapFrame extends Control:
	func _draw():
		var sb = StyleBoxFlat.new(); sb.draw_center = false; sb.set_corner_radius_all(12); sb.set_border_width_all(3); sb.border_color = Color(0.02, 0.03, 0.05, 0.95)
		sb.corner_detail = 6
		draw_style_box(sb, Rect2(Vector2(-1, -1), rect_size + Vector2(2, 2)))

# three thin bars under the map
class Bars extends Control:
	func _draw():
		var S = G.S
		var P = G.main.player
		var w = rect_size.x
		var gap = 4.0
		var vals = [[clamp(float(S["health"]) / 100.0, 0, 1), Color(0.36, 0.86, 0.45) if S["health"] >= 30 else Color(1, 0.3, 0.25)], [clamp(float(S.get("warmth", 100)) / 100.0, 0, 1), Color(0.45, 0.8, 1.0)], [clamp(P.stamina / 100.0, 0, 1), Color(1, 0.82, 0.3)]]
		var widths = [w * 0.5 - gap, w * 0.3 - gap, w * 0.2]
		var x = 0.0
		for i in range(3):
			var bw = widths[i]
			draw_rect(Rect2(x, 0, bw, rect_size.y), Color(0, 0, 0, 0.6))
			var col = vals[i][1]
			if i == 0 and S["health"] < 30 and int(G.REAL_T * 3) % 2 == 0: col = col.lightened(0.3)
			draw_rect(Rect2(x + 1, 1, (bw - 2) * vals[i][0], rect_size.y - 2), col)
			x += bw + gap

class Stars extends Control:
	func _draw():
		var lv = G.main.police.level
		var flash = G.main.police.hostile and int(G.REAL_T * 4) % 2 == 0
		for i in range(5):
			var c = Vector2(rect_size.x - 14 - i * 28, rect_size.y / 2)
			var pts = PoolVector2Array()
			for k in range(10):
				var a = -PI / 2 + k * PI / 5
				var r = 11.0 if k % 2 == 0 else 4.6
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			var on = (4 - i) < lv
			var outline = PoolVector2Array(pts); outline.append(pts[0])
			if on:
				draw_colored_polygon(pts, Color(1, 1, 1) if not flash else Color(0.7, 0.8, 1))
				draw_polyline(outline, Color(0, 0, 0, 0.8), 1.5)
			elif lv > 0:
				draw_polyline(outline, Color(1, 1, 1, 0.35), 1.5)

class Meter extends Control:
	var label = ""
	var col = Color(1, 1, 1)
	var value = 0.0
	var tier = ""
	func _draw():
		draw_string(G.font_xs, Vector2(rect_size.x - 210, 12), label, col)
		draw_rect(Rect2(rect_size.x - 150, 5, 150, 6), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(rect_size.x - 150, 5, 150 * clamp(value / 100.0, 0, 1), 6), col)
		draw_string(G.font_xs, Vector2(rect_size.x - 150, 26), tier, Color(1, 1, 1, 0.7))

class WeaponIcon extends Control:
	var kind = "k9"
	func _draw():
		var c = Color(1, 1, 1, 0.95)
		var o = rect_size / 2
		if kind == "fists":
			for dx in [-14, 4]:
				draw_rect(Rect2(o + Vector2(dx, -9), Vector2(16, 14)), c)
				for k in range(4): draw_rect(Rect2(o + Vector2(dx + k * 4, -13), Vector2(3.5, 5)), c)
			return
		if kind == "snowball":
			draw_circle(o, 11, c); draw_circle(o + Vector2(-3, -3), 4, Color(0.85, 0.9, 1)); return
		var L = { "k9": 52.0, "draft": 76.0, "plow": 96.0 }.get(kind, 60.0)
		var x0 = o.x - L / 2
		draw_rect(Rect2(x0, o.y - 8, L * 0.75, 9), c)
		draw_rect(Rect2(x0 + L * 0.75, o.y - 6, L * 0.25, 5), c)
		draw_colored_polygon(PoolVector2Array([Vector2(x0 + 4, o.y), Vector2(x0 + 14, o.y), Vector2(x0 + 10, o.y + 14), Vector2(x0 + 1, o.y + 14)]), c)
		if kind == "draft":
			draw_rect(Rect2(x0 + L * 0.42, o.y, 7, 14), c)
			draw_rect(Rect2(x0 - 14, o.y - 6, 14, 8), c)
		if kind == "plow":
			draw_rect(Rect2(x0 - 18, o.y - 6, 18, 10), c)
			draw_rect(Rect2(x0 + L * 0.5, o.y + 2, L * 0.3, 5), c)

# radial wheels: weapons and emotes
class Wheel extends Control:
	var hud
	func _draw():
		var kind = hud.wheel_kind
		if kind == "": return
		var items = hud.EMOTES if kind == "emote" else hud.WEAPONS
		var ctr = rect_size / 2
		var R = min(rect_size.x, rect_size.y) * (0.32 if kind == "emote" else 0.27)
		draw_circle(ctr, R + 70, Color(0, 0, 0, 0.35))
		var n = items.size()
		for i in range(n):
			var a0 = -PI / 2 + (i - 0.5) * TAU / n
			var a1 = a0 + TAU / n
			var sel = i == hud.wheel_sel
			var pts = PoolVector2Array()
			for k in range(9):
				var a = lerp(a0 + 0.02, a1 - 0.02, k / 8.0)
				pts.append(ctr + Vector2(cos(a), sin(a)) * (R + 60))
			for k in range(9):
				var a2 = lerp(a1 - 0.02, a0 + 0.02, k / 8.0)
				pts.append(ctr + Vector2(cos(a2), sin(a2)) * (R - 40))
			var ok = hud._wheel_ok(kind, items[i][0])
			draw_colored_polygon(pts, Color(1, 0.62, 0.22, 0.85) if sel else (Color(0.08, 0.1, 0.14, 0.86) if ok else Color(0.08, 0.1, 0.14, 0.45)))
			var am = (a0 + a1) / 2
			var p = ctr + Vector2(cos(am), sin(am)) * (R + 10)
			var f = G.font_xs if kind == "emote" else G.font_m
			var txt = items[i][1]
			var tw = f.get_string_size(txt).x
			draw_string(f, p - Vector2(tw / 2, -5), txt, Color(0.05, 0.05, 0.07) if sel else (Color(1, 1, 1) if ok else Color(1, 1, 1, 0.35)))
			if kind == "weapon":
				var sub = hud._weapon_sub(items[i][0])
				var sw = G.font_xs.get_string_size(sub).x
				draw_string(G.font_xs, p - Vector2(sw / 2, -24), sub, Color(0.05, 0.05, 0.07) if sel else Color(1, 1, 1, 0.6))
		var title = "EMOTES" if kind == "emote" else "WEAPONS"
		var name = items[hud.wheel_sel][1] if hud.wheel_sel >= 0 else title
		var nw = G.font_l.get_string_size(name).x
		draw_circle(ctr, R - 46, Color(0.03, 0.04, 0.06, 0.92))
		draw_string(G.font_l, ctr - Vector2(nw / 2, -8), name, Color(1, 1, 1))

# name tags over people's heads
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
		for k in main.story.NPCS.keys():
			var n = main.story.NPCS[k]
			if n.h.visible: items.append([n.h.translation + Vector3(0, 0.1, 0), G.D["CAST"][k].name, G.D["CAST"][k].role.split(" ·")[0].to_upper() if G.D["CAST"][k].has("role") else "", Color(G.D["CAST"][k].color)])
		for r in main.net.R.values():
			if r.h and r.h.visible:
				var gt = ("[" + str(r.gang[2]) + "] ") if typeof(r.gang) == TYPE_ARRAY else ""
				items.append([r.pos, gt + "@" + r.name, "ONLINE", Color(1, 1, 1)])
		for cp in main.police.COPS:
			if not cp.is_down(): items.append([cp.pos, "POLICE", "", Color(0.44, 0.7, 1)])
		for e in main.crews.ENEMIES:
			if not e.is_down() and e.crew.state != "leave": items.append([e.pos, e.name, "", Color(1, 0.3, 0.23)])
		for it in items:
			var w = it[0] + Vector3(0, 2.1, 0)
			if cam.is_position_behind(w): continue
			var d = cam.global_transform.origin.distance_to(w)
			if d > 34: continue
			var a = clamp((34 - d) / 8.0, 0, 1)
			var sp = cam.unproject_position(w)
			var f = G.font_hud
			var tw = f.get_string_size(it[1]).x
			draw_circle(Vector2(sp.x - tw / 2 - 9, sp.y - 5), 4, Color(it[3].r, it[3].g, it[3].b, a))
			draw_string(f, Vector2(sp.x - tw / 2, sp.y), it[1], Color(1, 1, 1, a))
			if it[2] != "":
				var sw = G.font_xs.get_string_size(it[2]).x
				draw_string(G.font_xs, Vector2(sp.x - sw / 2, sp.y + 16), it[2], Color(it[3].r, it[3].g, it[3].b, a))

# ---------- building the HUD ----------
func setup(m):
	main = m
	layer = CanvasLayer.new(); add_child(layer)
	root = Control.new(); root.anchor_right = 1; root.anchor_bottom = 1; root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	tags = Tags.new(); tags.main = main; _full(tags); root.add_child(tags)
	# vignette for hurt and frost
	vignette = ColorRect.new(); _full(vignette)
	var sh = Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 tint : hint_color = vec4(0.6, 0.0, 0.0, 1.0);
uniform float amount = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5));
	COLOR = vec4(tint.rgb, tint.a * amount * smoothstep(0.32, 0.78, d));
}"""
	vig_mat = ShaderMaterial.new(); vig_mat.shader = sh
	vignette.material = vig_mat
	root.add_child(vignette)
	# bottom left: map, bars, feed
	minimap = MiniMap.new(); minimap.main = main; minimap.rect_clip_content = true
	_anchor(minimap, 0, 1, 22, -196, 262, -36)
	root.add_child(minimap)
	var frame = MapFrame.new(); frame.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.anchor_right = 1; frame.anchor_bottom = 1
	minimap.add_child(frame)
	bars = Bars.new(); _anchor(bars, 0, 1, 22, -30, 262, -22); root.add_child(bars)
	feed = VBoxContainer.new(); feed.alignment = BoxContainer.ALIGN_END
	_anchor(feed, 0, 1, 22, -470, 372, -206); root.add_child(feed)
	# top left: help box
	help_box = PanelContainer.new(); help_box.add_stylebox_override("panel", _sb(Color(0.02, 0.03, 0.05, 0.82), 8, 14))
	help_box.margin_left = 22; help_box.margin_top = 22; help_box.rect_min_size = Vector2(260, 0)
	help_lbl = Label.new(); help_lbl.add_font_override("font", G.font_m); help_lbl.autowrap = true; help_lbl.rect_min_size = Vector2(240, 0)
	help_box.add_child(help_lbl); help_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(help_box)
	# top right: weapon, cash, stars, meters
	weapon_icon = WeaponIcon.new(); _anchor(weapon_icon, 1, 0, -150, 18, -22, 58); root.add_child(weapon_icon)
	lbl_weapon = _lab(G.font_xs, C_DIM, 1, 0, -330, 22, -160, 40, Label.ALIGN_RIGHT)
	lbl_ammo = _lab(G.font_hud, C_TEXT, 1, 0, -330, 36, -160, 60, Label.ALIGN_RIGHT)
	lbl_cash = _lab(G.font_cash, C_CASH, 1, 0, -420, 62, -22, 106, Label.ALIGN_RIGHT)
	lbl_cash_delta = _lab(G.font_hud, C_CASH, 1, 0, -420, 104, -22, 126, Label.ALIGN_RIGHT)
	stars = Stars.new(); _anchor(stars, 1, 0, -170, 128, -22, 154); root.add_child(stars)
	meter_buzz = Meter.new(); meter_buzz.label = "BUZZ"; meter_buzz.col = Color(1, 0.72, 0.3); _anchor(meter_buzz, 1, 0, -240, 160, -22, 190); root.add_child(meter_buzz)
	meter_heat = Meter.new(); meter_heat.label = "HEAT"; meter_heat.col = Color(1, 0.36, 0.3); _anchor(meter_heat, 1, 0, -240, 192, -22, 222); root.add_child(meter_heat)
	# bottom right: street, area, clock; speed and radio in a car
	lbl_speed = _lab(G.font_cash, C_TEXT, 1, 1, -420, -150, -24, -110, Label.ALIGN_RIGHT)
	lbl_radio = _lab(G.font_xs, C_ACCENT, 1, 1, -420, -112, -24, -96, Label.ALIGN_RIGHT)
	lbl_street = _lab(G.font_hud, C_TEXT, 1, 1, -520, -82, -24, -58, Label.ALIGN_RIGHT)
	lbl_area = _lab(G.font_xs, C_DIM, 1, 1, -520, -58, -24, -42, Label.ALIGN_RIGHT)
	lbl_clock = _lab(G.font_xs, C_DIM, 1, 1, -520, -40, -24, -24, Label.ALIGN_RIGHT)
	# centre
	big_band = TextureRect.new(); big_band.expand = true
	var gt = GradientTexture.new(); var gr = Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0)); gr.set_color(1, Color(0, 0, 0, 0)); gr.add_point(0.5, Color(0, 0, 0, 0.55)); gt.gradient = gr
	big_band.texture = gt
	_anchor(big_band, 0, 0, 0, 0, 0, 0); big_band.anchor_right = 1; big_band.anchor_top = 0.24; big_band.anchor_bottom = 0.24; big_band.margin_top = -10; big_band.margin_bottom = 110
	root.add_child(big_band)
	big_title = _lab(G.font_big, C_TEXT, 0, 0, 0, 0, 0, 0, Label.ALIGN_CENTER); big_title.anchor_right = 1; big_title.anchor_top = 0.24; big_title.anchor_bottom = 0.24; big_title.margin_bottom = 70
	big_sub = _lab(G.font_hud, C_ACCENT, 0, 0, 0, 0, 0, 0, Label.ALIGN_CENTER); big_sub.anchor_right = 1; big_sub.anchor_top = 0.24; big_sub.anchor_bottom = 0.24; big_sub.margin_top = 70; big_sub.margin_bottom = 100
	objective = _lab(G.font_hud, C_TEXT, 0, 1, 280, -130, -280, -104, Label.ALIGN_CENTER); objective.anchor_right = 1
	sub_box = PanelContainer.new(); sub_box.add_stylebox_override("panel", _sb(Color(0, 0, 0, 0.55), 6, 12))
	sub_box.anchor_left = 0.5; sub_box.anchor_right = 0.5; sub_box.anchor_top = 1; sub_box.anchor_bottom = 1; sub_box.margin_top = -96; sub_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb = HBoxContainer.new(); sub_box.add_child(hb)
	sub_who = Label.new(); sub_who.add_font_override("font", G.font_m); sub_who.add_color_override("font_color", C_ACCENT); hb.add_child(sub_who)
	sub_text = Label.new(); sub_text.add_font_override("font", G.font_m); hb.add_child(sub_text)
	root.add_child(sub_box)
	cross = _lab(G.font_m, Color(1, 1, 1, 0.9), 0, 0, 0, 0, 0, 0, Label.ALIGN_CENTER); cross.text = "·"
	cross.anchor_left = 0.5; cross.anchor_right = 0.5; cross.anchor_top = 0.5; cross.anchor_bottom = 0.5; cross.margin_left = -20; cross.margin_right = 20; cross.margin_top = -14; cross.margin_bottom = 12
	hit = _lab(G.font_l, Color(1, 1, 1), 0, 0, 0, 0, 0, 0, Label.ALIGN_CENTER); hit.text = "✕"
	hit.anchor_left = 0.5; hit.anchor_right = 0.5; hit.anchor_top = 0.5; hit.anchor_bottom = 0.5; hit.margin_left = -20; hit.margin_right = 20; hit.margin_top = -18; hit.margin_bottom = 18; hit.modulate.a = 0
	wheel = Wheel.new(); wheel.hud = self; _full(wheel); root.add_child(wheel)
	# fade (on its own layer so it covers menus too)
	var fl = CanvasLayer.new(); fl.layer = 20; add_child(fl)
	fade = ColorRect.new(); fade.color = Color(0, 0, 0, 0); _full(fade); fl.add_child(fade)
	hide()

func _full(c):
	c.anchor_right = 1; c.anchor_bottom = 1; c.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _anchor(c, ax, ay, l, t, r, b):
	c.anchor_left = ax; c.anchor_right = ax; c.anchor_top = ay; c.anchor_bottom = ay
	c.margin_left = l; c.margin_top = t; c.margin_right = r; c.margin_bottom = b
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _lab(font, col, ax, ay, l, t, r, b, align = Label.ALIGN_LEFT):
	var lb = Label.new()
	lb.add_font_override("font", font); lb.add_color_override("font_color", col)
	lb.add_color_override("font_color_shadow", Color(0, 0, 0, 0.55)); lb.add_constant_override("shadow_offset_y", 1)
	lb.align = align
	_anchor(lb, ax, ay, l, t, r, b)
	root.add_child(lb)
	return lb

var touch = false
# phones: the joystick lives bottom-left, so the map moves to the top-left corner
func set_touch_layout(on):
	touch = on
	if on:
		_anchor(minimap, 0, 0, 18, 18, 238, 158)
		_anchor(bars, 0, 0, 18, 164, 238, 172)
		_anchor(feed, 0, 0, 252, 70, 600, 330)
		feed.alignment = BoxContainer.ALIGN_BEGIN
		help_box.margin_left = 252; help_box.margin_top = 18
	else:
		_anchor(minimap, 0, 1, 22, -196, 262, -36)
		_anchor(bars, 0, 1, 22, -30, 262, -22)
		_anchor(feed, 0, 1, 22, -470, 372, -206)
		feed.alignment = BoxContainer.ALIGN_END
		help_box.margin_left = 22; help_box.margin_top = 22

func show():
	root.visible = true
func hide():
	root.visible = false

# ---------- every frame ----------
func update(dt):
	_wheel_input(dt)
	fade.color.a = move_toward(fade.color.a, fade_target, dt * fade_speed)
	if not root.visible: return
	var S = G.S
	var P = main.player
	var hud_on = G.MODE in ["play", "phone", "menu"]
	for c in [minimap, bars, feed, help_box, weapon_icon, lbl_weapon, lbl_ammo, lbl_cash, lbl_cash_delta, stars, meter_buzz, meter_heat, lbl_street, lbl_area, lbl_clock, lbl_speed, lbl_radio, objective, cross, tags]:
		c.visible = hud_on
	# cash, rolling up or down like a counter
	var cash = int(S["cash"])
	if cash_shown < 0: cash_shown = cash
	if cash != cash_shown:
		var diff = cash - cash_shown
		if abs(diff) > 0:
			lbl_cash_delta.text = ("+" if diff > 0 else "−") + G.fmt_money(abs(diff)).substr(0)
			lbl_cash_delta.add_color_override("font_color", C_CASH if diff > 0 else Color(1, 0.4, 0.35))
			cash_delta_t = 2.5
		cash_shown = cash
	cash_delta_t -= dt
	lbl_cash_delta.modulate.a = clamp(cash_delta_t, 0, 1)
	lbl_cash.text = G.fmt_money(cash)
	# weapon
	var kind = "fists" if S.get("fists", false) else S["cur"]
	weapon_icon.kind = kind
	if kind == "fists":
		lbl_weapon.text = "FISTS"
		lbl_ammo.text = "GUARD UP" if P.aiming else "JAB · CROSS · HOOK"
	else:
		var g = S["guns"][S["cur"]]
		lbl_weapon.text = G.D["WEAPONS"][S["cur"]].short.to_upper()
		lbl_ammo.text = ("RELOADING" if P.reload_t > 0 else "%d  |  %d" % [g.mag, g.res])
	weapon_icon.update()
	stars.update()
	meter_buzz.value = float(S["buzz"]); meter_buzz.tier = _buzz_tier(S["buzz"]); meter_buzz.update()
	meter_heat.value = float(S["heat"]); meter_heat.tier = _heat_tier(S["heat"]); meter_heat.update()
	bars.update()
	# where you are
	lbl_street.text = street_name(P.pos)
	lbl_area.text = _area(P.pos)
	var tf = main.story.temp_f()
	lbl_clock.text = "%s · Day %d · %d°F%s" % [G.clock_str(), int(S.get("day", 1)), tf, (" · " + main.story.warm_label) if main.story.warm_label else ""]
	if P.car:
		lbl_speed.text = "%d MPH" % int(abs(P.car.speed) * 2.237)
		var st = int(S["settings"].get("radio", 1))
		lbl_radio.text = G.D["STATIONS"][st].name.to_upper() if st > 0 else "RADIO OFF"
	else:
		lbl_speed.text = ""; lbl_radio.text = ""
	# help box
	var hp = _prompt()
	help_box.visible = hud_on and hp != ""
	help_lbl.text = hp
	objective.text = _objective()
	cross.visible = hud_on and not P.car and (P.aim_t > 0.3 or P.fp_on()) and wheel_kind == ""
	# big message and subtitles
	banner_t -= dt
	var ba = clamp(banner_t * 2, 0, 1)
	big_title.modulate.a = ba; big_sub.modulate.a = ba; big_band.modulate.a = ba
	sub_t -= dt
	sub_box.modulate.a = clamp(sub_t * 2, 0, 1)
	sub_box.visible = sub_t > 0
	hit_t -= dt
	hit.modulate.a = clamp(hit_t * 4, 0, 1)
	# hurt and cold at the screen edges
	hurt_v = max(hurt_v * exp(-dt * 1.8), 0.35 if S["health"] < 30 else 0.0)
	var frost = clamp((40 - float(S.get("warmth", 100))) / 40.0, 0, 1)
	if hurt_v > frost * 0.6:
		vig_mat.set_shader_param("tint", Color(0.55, 0, 0, 1)); vig_mat.set_shader_param("amount", clamp(hurt_v, 0, 0.9))
	else:
		vig_mat.set_shader_param("tint", Color(0.75, 0.88, 1, 1)); vig_mat.set_shader_param("amount", frost * 0.75)
	lake_cd -= dt
	minimap.update()
	tags.update()
	wheel.update()

func _buzz_tier(b): return "STAR" if b >= 80 else ("VIRAL" if b >= 60 else ("BUZZING" if b >= 35 else ("LOCAL" if b >= 15 else "UNDERGROUND")))
func _heat_tier(h): return "MAX" if h >= 90 else ("BLAZING" if h >= 75 else ("HOT" if h >= 50 else ("WARM" if h >= 25 else "COOL")))

func _area(p):
	var L = G.D["LOC"]
	var best = ""
	var bd = 40.0
	for k in L.keys():
		var o = L[k]
		if not o.has("name"): continue
		var d = Vector2(o.x - p.x, o.z - p.z).length()
		if d < bd:
			bd = d; best = o.name
	if best != "": return best.to_upper()
	return "CALDER PARK · CHICAGO"

func _key(k, pad):
	if Input.get_connected_joypads().size() > 0: return "[" + pad + "]"
	return "[" + k + "]"

func _prompt():
	var P = main.player
	if G.MODE != "play" or wheel_kind != "": return ""
	if P.is_ragdoll() and P.flopped: return "%s Get up" % _key("Space", "A")
	if P.car: return ""
	var so = main.crews.active_standoff()
	if so: return "Hold %s to walk away\nAim to fight" % _key("E", "RB")
	var it = P.nearest_interact()
	if it: return "%s %s" % [_key("E", "RB"), main.story.interact_label(it)]
	var rp = main.gang.nearest_recruit_ped()
	if rp: return "%s Talk to %s · %s" % [_key("E", "RB"), rp.rq_name, G.D["RTYPES"][rp.rq].name]
	var v = main.vehicles.nearest_car(P.pos, 3.2)
	if v:
		var what = "Get in your " if v.owned else ("Carjack the " if v.driver == "ai" else ("Locked · " if v.locked else "Break into the "))
		return "%s %s%s" % [_key("F", "Y"), what, v.sp.name]
	if P.emote_name != "": return "Move to stop the emote"
	if not touch and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED and Input.get_connected_joypads().size() == 0 and fmod(G.REAL_T, 8) < 5:
		return "Click to control the camera"
	return ""

func _objective():
	var J = G.S.get("job")
	var P = main.player
	var C = G.D["CAST"]
	if typeof(J) == TYPE_DICTIONARY:
		var w = main.story.job_where(J.id)
		var dist = "" if w == null else "  ·  %d m" % int(Vector2(w.x - P.pos.x, w.z - P.pos.z).length())
		if J.id == "kiara": return "Walk %s home to Bishop St.%s" % [C.kiara.name, dist]
		if J.id == "merch": return "Drop the hoodies: %d/3 spots · %ds left%s" % [J.done.size(), int(max(0, 200 - J.t)), dist]
		if J.id == "video": return "Stand on the mark and hold it (%d/%d)%s" % [J.stage + 1, J.marks.size(), dist]
	var tr = G.S.get("tracked")
	if tr != null and main.story.job_available(tr):
		var w2 = main.story.job_where(tr)
		if w2 != null: return "%s  ·  %d m" % [main.story.JOB_TITLE[tr], int(Vector2(w2.x - P.pos.x, w2.z - P.pos.z).length())]
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

# ---------- messages ----------
func banner(t, sub = ""):
	big_title.text = t.to_upper(); big_sub.text = sub; banner_t = 2.6
	main.sfx.play("whoosh", 0.22, 1.2)

func say(who, text):
	sub_who.text = who + "  "; sub_text.text = text; sub_t = 3.8
	sub_box.margin_left = 0; sub_box.margin_right = 0

# a notification card in the feed above the map
func toast(text):
	var who = ""
	var body = text
	var i = text.find(":  ")
	if i > 0 and i < 32:
		who = text.substr(0, i); body = text.substr(i + 3)
	var card = PanelContainer.new(); card.add_stylebox_override("panel", _sb(Color(0.03, 0.04, 0.07, 0.86), 10, 10))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb = HBoxContainer.new(); card.add_child(hb)
	var av = Label.new(); av.text = (who.substr(1, 1) if who.begins_with("@") else (who.substr(0, 1) if who != "" else "●")).to_upper()
	av.add_font_override("font", G.font_m); av.align = Label.ALIGN_CENTER; av.valign = Label.VALIGN_CENTER; av.rect_min_size = Vector2(30, 30)
	var col = C_ACCENT
	for k in G.D["CAST"].keys():
		if G.D["CAST"][k].name == who: col = Color(G.D["CAST"][k].color)
	var avs = _sb(col, 15, 0); av.add_stylebox_override("normal", avs); av.add_color_override("font_color", Color(0.05, 0.05, 0.07))
	hb.add_child(av)
	var v = VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(v)
	if who != "":
		var w = Label.new(); w.text = who; w.add_font_override("font", G.font_xs); w.add_color_override("font_color", col); v.add_child(w)
	var b = Label.new(); b.text = body; b.autowrap = true; b.add_font_override("font", G.font_s); b.rect_min_size = Vector2(290, 0); v.add_child(b)
	feed.add_child(card)
	while feed.get_child_count() > 3:
		var old = feed.get_child(0)
		feed.remove_child(old); old.queue_free()
	main.sfx.play("notif", 0.4)
	yield(get_tree().create_timer(5.5), "timeout")
	if is_instance_valid(card): card.queue_free()

func hitmarker(head):
	hit_t = 0.25; hit.add_color_override("font_color", Color(1, 0.3, 0.23) if head else Color(1, 1, 1))

func hurt_flash(dmg):
	hurt_v = min(1.0, hurt_v + 0.25 + dmg * 0.03)

func fade_to(a, secs = 0.5):
	fade_target = a; fade_speed = 1.0 / max(0.05, secs)

# ---------- wheels ----------
func _wheel_ok(kind, id):
	if kind == "emote": return true
	if id == "fists" or id == "snowball": return true
	return G.S["guns"][id].owned

func _weapon_sub(id):
	if id == "fists": return "melee"
	if id == "snowball": return "throw"
	var g = G.S["guns"][id]
	if not g.owned: return "locked"
	return "%d | %d" % [g.mag, g.res]

func wheel_open(): return wheel_kind != ""

func _wheel_input(dt):
	var P = main.player
	if G.MODE != "play" or P.car or P.dead:
		if wheel_kind != "": _close_wheel(false)
		wheel_hold = 0
		return
	# weapon: tap cycles, hold opens the wheel
	if Input.is_action_pressed("next_weapon"):
		wheel_hold += dt
		if wheel_hold > 0.22 and wheel_kind == "": _open_wheel("weapon")
	elif wheel_hold > 0:
		if wheel_kind == "weapon": _close_wheel(true)
		elif wheel_hold <= 0.22: P.cycle_weapon()
		wheel_hold = 0
	if Input.is_action_just_pressed("emote") and wheel_kind == "": _open_wheel("emote")
	if wheel_kind == "emote" and not Input.is_action_pressed("emote"): _close_wheel(true)
	if wheel_kind != "":
		var stick = Vector2(Input.get_action_strength("look_r") - Input.get_action_strength("look_l"), Input.get_action_strength("look_d") - Input.get_action_strength("look_u"))
		if stick.length() > 0.4: wheel_vec = stick * 100
		var items = EMOTES if wheel_kind == "emote" else WEAPONS
		if wheel_vec.length() > 30:
			var a = atan2(wheel_vec.y, wheel_vec.x) + PI / 2
			wheel_sel = int(round(fposmod(a, TAU) / (TAU / items.size()))) % items.size()

func _input(e):
	if wheel_kind != "" and e is InputEventMouseMotion and not touch:
		wheel_vec += e.relative
		if wheel_vec.length() > 120: wheel_vec = wheel_vec.normalized() * 120
		get_tree().set_input_as_handled()
	if menu_box and (e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause")):
		close_menu(); get_tree().set_input_as_handled()

func _open_wheel(kind):
	wheel_kind = kind; wheel_vec = Vector2(); wheel_sel = -1
	if kind == "weapon":
		Engine.time_scale = 0.3
		var cur = "fists" if G.S.get("fists", false) else G.S["cur"]
		for i in range(WEAPONS.size()):
			if WEAPONS[i][0] == cur: wheel_sel = i
	main.sfx.play("tap", 0.4)

func _close_wheel(pick):
	var kind = wheel_kind
	wheel_kind = ""
	Engine.time_scale = 1.0
	if not pick or wheel_sel < 0: return
	var P = main.player
	if kind == "weapon":
		var id = WEAPONS[wheel_sel][0]
		if id == "fists": P.set_fists(true)
		elif id == "snowball": P.throw_snowball()
		elif G.S["guns"][id].owned: P.switch_weapon(id)
	else:
		var em = EMOTES[wheel_sel][0]
		last_emote = em
		if em == "wave": P.wave_t = 2.2
		elif em == "flip":
			P.flip_t = max(P.flip_t, 2.4); main.peds.flip_react(P.pos)
		elif em == "flop": P.flop()
		elif em in ["salute", "point", "facepalm", "shrug"]: P.emote(em, 2.2)
		elif em == "laugh": P.emote(em, 3.0)
		else: P.emote(em)

# ---------- menus for places (keyboard, mouse or controller) ----------
func menu(eyebrow, title, sub, items):
	close_menu()
	G.MODE = "menu"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	menu_box = VBoxContainer.new()
	menu_box.margin_left = 56; menu_box.margin_top = 90; menu_box.margin_right = 486; menu_box.add_constant_override("separation", 0)
	var head = PanelContainer.new()
	var hs = _sb(C_ACCENT, 0, 16); hs.corner_radius_top_left = 10; hs.corner_radius_top_right = 10
	head.add_stylebox_override("panel", hs)
	var hv = VBoxContainer.new(); head.add_child(hv)
	var e = Label.new(); e.text = eyebrow.to_upper(); e.add_font_override("font", G.font_xs); e.add_color_override("font_color", Color(0.1, 0.06, 0.02)); hv.add_child(e)
	var t = Label.new(); t.text = title; t.add_font_override("font", G.font_l); t.add_color_override("font_color", Color(0.05, 0.03, 0.02)); hv.add_child(t)
	menu_box.add_child(head)
	var subp = PanelContainer.new(); subp.add_stylebox_override("panel", _sb(Color(0.02, 0.03, 0.05, 0.92), 0, 14))
	var sl = Label.new(); sl.text = sub; sl.autowrap = true; sl.add_font_override("font", G.font_s); sl.add_color_override("font_color", C_DIM); sl.rect_min_size = Vector2(400, 0)
	subp.add_child(sl); menu_box.add_child(subp)
	menu_items = items
	var first = null
	var first_i = 0
	var normal = _sb(Color(0.05, 0.06, 0.09, 0.9), 0, 14)
	var focus = _sb(Color(0.96, 0.97, 1.0, 0.95), 0, 14)
	var dis = _sb(Color(0.05, 0.06, 0.09, 0.7), 0, 14)
	for i in range(items.size()):
		var it = items[i]
		var b = Button.new()
		b.text = "%s%s" % [it.label, ("     " + it.hint) if it.get("hint", "") != "" else ""]
		b.align = Button.ALIGN_LEFT; b.clip_text = true
		b.add_font_override("font", G.font_m)
		b.add_stylebox_override("normal", normal); b.add_stylebox_override("hover", focus); b.add_stylebox_override("focus", focus); b.add_stylebox_override("pressed", focus); b.add_stylebox_override("disabled", dis)
		b.add_color_override("font_color", C_TEXT); b.add_color_override("font_color_hover", Color(0.05, 0.05, 0.07)); b.add_color_override("font_color_focus", Color(0.05, 0.05, 0.07)); b.add_color_override("font_color_disabled", Color(1, 1, 1, 0.35))
		b.disabled = it.get("disabled", false)
		b.connect("pressed", self, "_menu_pick", [i])
		b.connect("focus_entered", self, "_menu_desc", [i]); b.connect("mouse_entered", self, "_menu_desc", [i])
		menu_box.add_child(b)
		if first == null and not b.disabled:
			first = b; first_i = i
	var dp = PanelContainer.new()
	var ds = _sb(Color(0.02, 0.03, 0.05, 0.92), 0, 14); ds.corner_radius_bottom_left = 10; ds.corner_radius_bottom_right = 10
	dp.add_stylebox_override("panel", ds)
	menu_desc = Label.new(); menu_desc.autowrap = true; menu_desc.add_font_override("font", G.font_s); menu_desc.add_color_override("font_color", C_DIM); menu_desc.rect_min_size = Vector2(400, 0)
	dp.add_child(menu_desc); menu_box.add_child(dp)
	root.add_child(menu_box)
	if first:
		first.grab_focus(); _menu_desc(first_i)

func _menu_desc(i):
	if menu_desc and i >= 0 and i < menu_items.size():
		var d = menu_items[i].get("desc", "")
		menu_desc.text = d if d != "" else "Esc or B to leave"

func _menu_pick(i):
	var it = menu_items[i]
	close_menu()
	main.sfx.play("tap", 0.5)
	if it.get("act") != null:
		if it.has("arg"): it.act.call_func(it.arg)
		else: it.act.call_func()

func close_menu():
	if menu_box:
		menu_box.queue_free(); menu_box = null; menu_desc = null
		if G.MODE == "menu": G.MODE = "play"

func interact(it):
	main.story.interact(it)

# ---------- the endings screen ----------
func ending_panel(eyebrow, title, col, line, cells, obj, method):
	var shade = ColorRect.new(); shade.color = Color(0, 0, 0, 0.7); shade.anchor_right = 1; shade.anchor_bottom = 1
	var layer2 = CanvasLayer.new(); layer2.layer = 9; add_child(layer2)
	layer2.add_child(shade)
	var card = PanelContainer.new(); card.add_stylebox_override("panel", _sb(Color(0.03, 0.04, 0.07, 0.97), 18, 30))
	card.anchor_left = 0.5; card.anchor_right = 0.5; card.anchor_top = 0.5; card.anchor_bottom = 0.5
	card.margin_left = -380; card.margin_right = 380; card.margin_top = -270; card.margin_bottom = 270
	shade.add_child(card)
	var v = VBoxContainer.new(); card.add_child(v)
	var e = Label.new(); e.text = eyebrow.to_upper(); e.add_font_override("font", G.font_s); e.add_color_override("font_color", C_DIM); v.add_child(e)
	var t = Label.new(); t.text = title.to_upper(); t.add_font_override("font", G.font_big); t.add_color_override("font_color", col); v.add_child(t)
	var l = Label.new(); l.text = line; l.autowrap = true; l.add_font_override("font", G.font_m); v.add_child(l)
	var grid = GridContainer.new(); grid.columns = 4; v.add_child(grid)
	for c in cells:
		var cv = VBoxContainer.new(); cv.rect_min_size = Vector2(170, 52); grid.add_child(cv)
		var a = Label.new(); a.text = str(c[1]); a.add_font_override("font", G.font_l); cv.add_child(a)
		var b = Label.new(); b.text = c[0]; b.add_font_override("font", G.font_xs); b.add_color_override("font_color", C_DIM); cv.add_child(b)
	var found = []
	for k in G.D["ENDINGS"].keys(): found.append(("✓ " if G.S["endings"].get(k, 0) else "· ") + G.D["ENDINGS"][k].title)
	var f = Label.new(); f.text = "ENDINGS FOUND   " + PoolStringArray(found).join("    "); f.add_font_override("font", G.font_s); f.add_color_override("font_color", col); v.add_child(f)
	var btn = Button.new(); btn.text = "Keep playing"; btn.add_font_override("font", G.font_m); v.add_child(btn)
	btn.connect("pressed", obj, method)
	btn.grab_focus()
	return layer2
