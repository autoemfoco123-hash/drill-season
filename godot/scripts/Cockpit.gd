extends Node
# The car interior for first-person driving, built per car model from its cabin shape: the
# hood in the car's paint, the dashboard with its defroster slots and air vents, a full
# instrument cluster (tach with its red line, speedo, gear, odometer, fuel and temperature,
# a boost gauge on the turbo car, warning lights, the traction light flickering when the
# tires let go), the radio, the steering wheel with its stalks and your hands on it, a
# gear lever and handbrake that move, pedals under your feet, door panels with armrests and
# speakers, sun visors, a rear-view mirror that shows the road behind (live on high
# quality) with fuzzy dice swinging under it, wipers that sweep the snow off, seats, the
# belt across your chest, and the dash glowing at night.

var main
var root = null
var key = ""
var eye = Vector3()
var spin = null
var hands = []
var arms = []
var flip_hand = null
var flip_k = 0.0
var gauge_vp = null
var gauge_view = null
var radio_vp = null
var radio_view = null
var shown_car = null
var _mats = {}
var shifter = null
var hb_lever = null
var pedals = []
var wipers = []
var wipe_t = 0.0
var wipe_ph = 0.0
var dice = null
var dice_a = Vector2()
var dice_v = Vector2()
var mirror_vp = null
var mirror_cam = null
var mirror_pos = Vector3()
var dash_light = null
var odo0 = 0.0

class Gauges extends Control:
	var ck
	func _draw():
		var P = ck.main.player
		var v = P.car
		if v == null: return
		var eng = ck.main.sfx.engine_state()
		var mph = abs(v.speed) * 2.237
		var rpm = eng.rpm
		var red = eng.red
		var night = ck.main.DN.night
		var lit = Color(1.0, 0.62, 0.26).linear_interpolate(Color(1.0, 0.5, 0.18), night)
		draw_rect(Rect2(Vector2(), rect_size), Color(0.015, 0.018, 0.022))
		var top = int(ceil(red / 1000.0)) + 1
		_dial(Vector2(108, 98), rpm / 1000.0, float(top), 1.0, "x1000 r/min", red / 1000.0, lit)
		_dial(Vector2(404, 98), mph, 160.0, 20.0, "MPH", 999.0, lit)
		# the middle: gear, digital speed, odometer, the clock
		var gear = "R" if v.speed < -0.3 else ("P" if eng.rpm < 1.0 else "D" + str(eng.gear + 1))
		draw_string(G.font_l, Vector2(256 - G.font_l.get_string_size(gear).x / 2, 52), gear, Color(0.86, 0.9, 0.94))
		var s = str(int(round(mph)))
		draw_string(G.font_cash, Vector2(256 - G.font_cash.get_string_size(s).x / 2, 100), s, lit)
		var odo = "%06d mi" % int(ck.odo0 + G.S["stats"].get("dist", 0.0) / 1609.0)
		draw_string(G.font_xs, Vector2(256 - G.font_xs.get_string_size(odo).x / 2, 124), odo, Color(0.5, 0.56, 0.6))
		var c = G.clock_str()
		draw_string(G.font_xs, Vector2(256 - G.font_xs.get_string_size(c).x / 2, 142), c, Color(0.48, 0.88, 0.65))
		# fuel and temperature
		_bar_gauge(Vector2(196, 168), 0.62 + 0.3 * sin(float(v.id) * 1.7), "E", "F", lit)
		var warm = clamp(0.25 + ck.main.sfx.E.get("rpm", 0.0) / 9000.0, 0.25, 0.55)
		_bar_gauge(Vector2(276, 168), warm, "C", "H", lit)
		# warning lights
		var x = 168
		var inp = ck.main.vehicles._player_input()
		if inp.hand:
			_lamp(Vector2(x, 182), "(P)", Color(1, 0.2, 0.15))
			x += 34
		if eng.rpm > 1.0 and ck.main.sfx.E.start_t > 0.0:
			_lamp(Vector2(x, 182), "CHK", Color(1, 0.65, 0.1))
			x += 36
		if v.slip > 0.3 and fmod(G.REAL_T, 0.25) < 0.14:
			_lamp(Vector2(x, 182), "TCS", Color(1, 0.65, 0.1))
			x += 36
		if ck.main.DN.lamps > 0.3:
			_lamp(Vector2(x, 182), "≡D", Color(0.3, 0.55, 1.0))
			x += 34
		if eng.get("boost", 0.0) > 0.0 or ck.main.sfx.engine_audio.pname == "i6t":
			var b = eng.get("boost", 0.0)
			draw_rect(Rect2(Vector2(214, 150), Vector2(84 * b, 4)), lit)
			draw_rect(Rect2(Vector2(214, 150), Vector2(84, 4)), Color(0.25, 0.27, 0.3), false)
	func _dial(c, val, mx, step, label, red_from, lit):
		var r = 80.0
		var a0 = PI * 0.75
		var a1 = PI * 2.25
		draw_arc(c, r + 2, a0, a1, 64, Color(0.2, 0.22, 0.25), 2)
		if red_from < mx:
			draw_arc(c, r - 3, a0 + (a1 - a0) * red_from / mx, a1, 24, Color(0.85, 0.12, 0.1), 6)
		var n = int(round(mx / step))
		for i in range(n * 2 + 1):
			var a = a0 + (a1 - a0) * i / float(n * 2)
			var major = i % 2 == 0
			var hot = i / float(n * 2) * mx >= red_from
			var inner = r - (16 if major else 9)
			draw_line(c + Vector2(cos(a), sin(a)) * (r - 2), c + Vector2(cos(a), sin(a)) * inner, Color(1, 0.3, 0.24) if hot else Color(0.82, 0.85, 0.88), 2.5 if major else 1.5)
			if major:
				var t = str(int(i / 2 * step))
				var p = c + Vector2(cos(a), sin(a)) * (r - 28) - G.font_xs.get_string_size(t) / 2 + Vector2(0, 9)
				draw_string(G.font_xs, p, t, Color(0.86, 0.88, 0.9))
		var an = a0 + (a1 - a0) * clamp(val / mx, 0, 1)
		var d = Vector2(cos(an), sin(an))
		draw_line(c - d * 12, c + d * (r - 8), lit.darkened(0.4), 7)
		draw_line(c - d * 12, c + d * (r - 8), lit, 3)
		draw_circle(c, 10, Color(0.08, 0.09, 0.1))
		draw_circle(c, 4, Color(0.3, 0.32, 0.35))
		draw_string(G.font_xs, c + Vector2(-G.font_xs.get_string_size(label).x / 2, 50), label, Color(0.54, 0.59, 0.64))
	func _bar_gauge(p, k, lo, hi, lit):
		for i in range(8):
			var on = i < int(round(k * 8))
			draw_rect(Rect2(p + Vector2(i * 6, 0), Vector2(4, 6)), lit if on else Color(0.18, 0.2, 0.22))
		draw_string(G.font_xs, p + Vector2(-12, 7), lo, Color(0.5, 0.55, 0.6))
		draw_string(G.font_xs, p + Vector2(50, 7), hi, Color(0.5, 0.55, 0.6))
	func _lamp(p, t, col):
		draw_string(G.font_xs, p, t, col)

class RadioView extends Control:
	var ck
	func _draw():
		draw_rect(Rect2(Vector2(), rect_size), Color(0.016, 0.027, 0.04))
		var st = int(G.S["settings"].get("radio", 1))
		var on = st > 0
		var a = G.D["STATIONS"][st].short if on else "RADIO OFF"
		draw_string(G.font_l, Vector2(128 - G.font_l.get_string_size(a).x / 2, 58), a, Color(1, 0.7, 0.28) if on else Color(0.34, 0.38, 0.42))
		var b = ""
		if on:
			var parts = G.D["STATIONS"][st].name.split("·")
			b = parts[1].strip_edges() if parts.size() > 1 else ""
		else: b = "R to tune"
		draw_string(G.font_s, Vector2(128 - G.font_s.get_string_size(b).x / 2, 92), b, Color(0.54, 0.59, 0.64))

func setup(m):
	main = m

func _mat(name, col, rough = 0.8, metal = 0.0, unshaded = false):
	if _mats.has(name): return _mats[name]
	var mt = SpatialMaterial.new()
	mt.albedo_color = col if typeof(col) == TYPE_COLOR else G.hex_color(col)
	mt.roughness = rough; mt.metallic = metal * 0.6; mt.flags_unshaded = unshaded
	_mats[name] = mt
	return mt

func _box(parent, w, h, d, x, y, z, mat, rx = 0.0, ry = 0.0, rz = 0.0):
	var mi = MeshInstance.new()
	var cm = CubeMesh.new(); cm.size = Vector3.ONE
	mi.mesh = cm; mi.material_override = mat; mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform(Basis(Vector3(1, 0, 0), rx) * Basis(Vector3(0, 1, 0), ry) * Basis(Vector3(0, 0, 1), rz) * Basis().scaled(Vector3(w, h, d)), Vector3(x, y, z))
	parent.add_child(mi)
	return mi

func _cyl_mesh():
	var cm = CylinderMesh.new(); cm.top_radius = 1; cm.bottom_radius = 1; cm.height = 1; cm.radial_segments = 10; cm.rings = 1
	return cm

# a cylinder of radius r from a to b (local coordinates)
func _limb(mi, a, b, r):
	var d = b - a
	var L = d.length()
	if L < 1e-4: return
	var y = d / L
	var x = y.cross(Vector3(0, 0, 1))
	if x.length() < 0.05: x = y.cross(Vector3(1, 0, 0))
	x = x.normalized()
	var z = x.cross(y)
	mi.transform = Transform(Basis(x * r, y * L, z * r), (a + b) / 2)

func _bar(parent, a, b, r, mat):
	var mi = MeshInstance.new(); mi.mesh = _cyl_mesh(); mi.material_override = mat; mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_limb(mi, a, b, r)
	return mi

func _torus(R, r, seg = 32, sides = 8):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(seg):
		for j in range(sides):
			var quad = []
			for k in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var u = k[0] * TAU / seg
				var w = k[1] * TAU / sides
				var c = Vector3(cos(u), sin(u), 0)
				var n = c * cos(w) + Vector3(0, 0, sin(w))
				quad.append([c * R + n * r, n])
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for q in tri:
					st.add_normal(quad[q][1]); st.add_vertex(quad[q][0])
	return st.commit()

func build(v):
	clear()
	var sp = v.sp
	var Gm = G.D["CAR_GEOM"][v.model]
	var W = float(sp.wid)
	var g = Spatial.new()
	main.add_child(g)
	root = g
	var o = G.skin_opts(G.S["skin"])
	var dash = _mat("dash", 0x17181b, 0.75)
	var trim = _mat("trim", 0x2a2c31, 0.6)
	var soft = _mat("soft", 0x3a3a3c, 0.95)
	var liner = _mat("liner", 0x8c8982, 1.0)
	var chrome = _mat("chrome", 0xb8bcc2, 0.25, 0.9)
	var paint = SpatialMaterial.new(); paint.albedo_color = G.hex_color(v.color); paint.roughness = 0.3; paint.metallic = 0.25; paint.metallic_specular = 0.7
	var glass = SpatialMaterial.new(); glass.albedo_color = Color(0.62, 0.7, 0.78, 0.06); glass.flags_transparent = true; glass.roughness = 0.04; glass.metallic_specular = 0.9
	var yWB = float(Gm.yWB)
	var zWB = float(Gm.zWB)
	var yWT = float(Gm.yWT)
	var zWT = float(Gm.zWT)
	var zRB = float(Gm.zRB)
	var roofY = float(Gm.roofY)
	var zMid = float(Gm.zMid)
	var yMid = float(Gm.yMid)
	var zNose = float(Gm.zNose)
	var yNose = float(Gm.yNose)
	var xD = W * 0.21
	var eyeY = yWB + (roofY - yWB) * 0.62           # over the dash, the roof a hand above your head
	var eyeZ = zWB - 0.95
	eye = Vector3(xD, eyeY, eyeZ)
	# the hood you look out over, in the car's own paint
	var hz0 = zWB + 0.02
	var hz1 = max(zMid, zWB + 0.6)
	_box(g, W - 0.1, 0.05, hz1 - hz0, 0, (yWB + yMid) / 2 - 0.02, (hz0 + hz1) / 2, paint, atan2(yWB - yMid, hz1 - hz0))
	var nz1 = max(zNose - 0.05, hz1 + 0.1)
	_box(g, W - 0.14, 0.05, nz1 - hz1, 0, (yMid + yNose) / 2 - 0.02, (hz1 + nz1) / 2, paint, atan2(yMid - yNose, nz1 - hz1))
	for s in [-1, 1]:
		_box(g, 0.06, 0.07, hz1 - hz0, s * (W / 2 - 0.05), (yWB + yMid) / 2 + 0.02, (hz0 + hz1) / 2, paint, atan2(yWB - yMid, hz1 - hz0))
	# dashboard, gauge hood, centre stack
	var dT = yWB - 0.06
	_box(g, W - 0.12, 0.3, 0.62, 0, dT - 0.15, zWB - 0.3, dash)
	_box(g, W - 0.12, 0.04, 0.3, 0, dT + 0.01, zWB - 0.14, dash, -0.18)
	var gY = eyeY - 0.215
	var gZ = eyeZ + 0.5
	var podTop = gY + 0.072
	var podH = max(0.06, podTop - (dT - 0.05))
	_box(g, 0.39, podH, 0.18, xD, podTop - podH / 2, gZ + 0.095, dash)
	_box(g, 0.41, 0.02, 0.09, xD, podTop + 0.008, gZ - 0.01, dash, 0.18)
	_box(g, 0.36, 0.42, 0.2, 0, dT - 0.36, zWB - 0.66, trim)
	_box(g, 0.24, 0.5, 0.55, 0, 0.62, eyeZ + 0.05, trim)
	for s2 in [-1, 1]:
		_box(g, 0.14, 0.04, 0.02, s2 * 0.62, dT - 0.05, zWB - 0.615, chrome)
	# gauges and radio: little 2D screens drawn into textures
	gauge_vp = _screen(Vector2(512, 192))
	gauge_view = Gauges.new(); gauge_view.ck = self; gauge_view.rect_size = Vector2(512, 192); gauge_vp.add_child(gauge_view)
	_screen_quad(g, gauge_vp, Vector2(0.36, 0.135), Vector3(xD, gY, gZ), Vector3(0.25, PI, 0))
	radio_vp = _screen(Vector2(256, 128))
	radio_view = RadioView.new(); radio_view.ck = self; radio_view.rect_size = Vector2(256, 128); radio_vp.add_child(radio_view)
	_screen_quad(g, radio_vp, Vector2(0.2, 0.1), Vector3(0, dT - 0.1, zWB - 0.62), Vector3(0.15, PI, 0))
	# steering wheel (spins with the steering) and your hands on it
	var wheel = Spatial.new(); wheel.transform = Transform(Basis(Vector3(1, 0, 0), 0.45) * Basis(Vector3(0, 1, 0), PI), Vector3(xD, eyeY - 0.42, eyeZ + 0.43)); g.add_child(wheel)
	spin = Spatial.new(); wheel.add_child(spin)
	var rim = MeshInstance.new(); rim.mesh = _torus(0.185, 0.022); rim.material_override = _mat("rim", 0x141416, 0.55); spin.add_child(rim)
	_box(spin, 0.12, 0.09, 0.05, 0, 0, 0, trim)
	for q in [[-0.1, 0, 0.17, 0.03], [0.1, 0, 0.17, 0.03], [0, -0.1, 0.03, 0.16]]:
		_box(spin, q[2], q[3], 0.025, q[0], q[1], 0, trim)
	_bar(g, Vector3(xD, eyeY - 0.48, eyeZ + 0.5), Vector3(xD, dT - 0.2, zWB - 0.55), 0.04, trim)
	var skin = SpatialMaterial.new(); skin.albedo_color = G.hex_color(o.skin); skin.roughness = 0.7
	var sleeve = SpatialMaterial.new(); sleeve.albedo_color = G.hex_color(o.jacket2 if o.top == "varsity" else o.jacket); sleeve.roughness = 0.9
	hands = []; arms = []
	for s3 in [-1, 1]:
		var h = MeshInstance.new(); var sm = SphereMesh.new(); sm.radius = 0.045; sm.height = 0.09; sm.radial_segments = 10; sm.rings = 6; h.mesh = sm
		h.material_override = skin; h.translation = Vector3(s3 * 0.185, 0, -0.025); h.scale = Vector3(0.95, 0.95, 1.2)
		spin.add_child(h); hands.append(h)
		var a = MeshInstance.new(); a.mesh = _cyl_mesh(); a.material_override = sleeve; g.add_child(a); arms.append(a)
	# the left hand leaves the wheel to give the finger
	flip_hand = Spatial.new(); flip_hand.visible = false; g.add_child(flip_hand)
	var fist = MeshInstance.new(); var fsm = SphereMesh.new(); fsm.radius = 0.045; fsm.height = 0.09; fsm.radial_segments = 10; fsm.rings = 6
	fist.mesh = fsm; fist.material_override = skin; fist.scale = Vector3(1.0, 1.15, 0.9); flip_hand.add_child(fist)
	var fing = MeshInstance.new(); var fcm = CapsuleMesh.new(); fcm.radius = 0.014; fcm.mid_height = 0.07; fcm.radial_segments = 8; fcm.rings = 1
	fing.mesh = fcm; fing.material_override = skin; fing.rotation = Vector3(PI / 2, 0, 0); fing.translation = Vector3(0, 0.085, 0.005); flip_hand.add_child(fing)
	# pillars, roof, doors, mirrors, seats
	var ax = W / 2 - 0.09
	var axT = W / 2 - 0.17
	for s4 in [-1, 1]:
		_bar(g, Vector3(s4 * ax, yWB - 0.02, zWB + 0.02), Vector3(s4 * axT, yWT - 0.03, zWT), 0.036, trim)
		var dl = max(0.6, zWB - zRB + 0.4)
		_box(g, 0.08, (yWB + 0.06) - 0.4, dl, s4 * (W / 2 - 0.05), (0.4 + yWB + 0.06) / 2, (zWB + zRB) / 2 - 0.2, dash)
		_box(g, 0.12, 0.05, dl, s4 * (W / 2 - 0.08), yWB + 0.07, (zWB + zRB) / 2 - 0.2, trim)
		_bar(g, Vector3(s4 * (W / 2 - 0.08), yWB + 0.08, eyeZ - 0.42), Vector3(s4 * (W / 2 - 0.15), roofY - 0.05, eyeZ - 0.5), 0.06, trim)
		_box(g, 0.09, 0.08, 0.16, s4 * (W / 2 + 0.07), yWB + 0.14, zWB - 0.08, paint)
		_box(g, 0.012, 0.07, 0.13, s4 * (W / 2 + 0.115), yWB + 0.14, zWB - 0.1, chrome)
		# door handle and window switch
		_box(g, 0.02, 0.03, 0.12, s4 * (W / 2 - 0.1), yWB - 0.12, eyeZ + 0.1, chrome)
	_box(g, W - 0.24, 0.07, 0.14, 0, yWT - 0.035, zWT - 0.06, trim)
	_box(g, W - 0.18, 0.04, max(0.5, zWT - zRB), 0, roofY - 0.04, (zWT + zRB) / 2, liner)
	_box(g, 0.5, 0.12, 0.55, -xD, 0.62, eyeZ, soft)
	# windshield and wipers
	var wl = Vector2(zWT - zWB, yWT - yWB).length()
	var wsh = MeshInstance.new(); var qm = QuadMesh.new(); qm.size = Vector2(W - 0.2, wl); wsh.mesh = qm; wsh.material_override = glass
	wsh.transform = Transform(Basis(Vector3(1, 0, 0), atan2(zWT - zWB, yWT - yWB)), Vector3(0, (yWB + yWT) / 2, (zWB + zWT) / 2))
	g.add_child(wsh)
	_build_more(v, g, W, xD, eyeY, eyeZ, yWB, zWB, yWT, zWT, zRB, roofY, dT, dash, trim, soft, liner, chrome, o)
	key = _key_for(v)

func _build_more(v, g, W, xD, eyeY, eyeZ, yWB, zWB, yWT, zWT, zRB, roofY, dT, dash, trim, soft, liner, chrome, o):
	var black = _mat("black", 0x0c0d0f, 0.6)
	var metal = _mat("metal", 0x6a6e74, 0.35, 0.8)
	var belt = _mat("belt", 0x1b1c1f, 0.9)
	var vent = _mat("vent", 0x08090a, 0.7)
	# defroster slots along the top of the dash, round vents at the ends, two in the middle
	for k in range(5):
		_box(g, 0.16, 0.006, 0.02, -0.5 + k * 0.25, dT + 0.035, zWB - 0.08, vent)
	for x in [-(W / 2 - 0.22), W / 2 - 0.22]:
		var vm = MeshInstance.new(); var cm = CylinderMesh.new(); cm.top_radius = 0.045; cm.bottom_radius = 0.045; cm.height = 0.03; cm.radial_segments = 14
		vm.mesh = cm; vm.material_override = vent; vm.rotation = Vector3(PI / 2, 0, 0); vm.translation = Vector3(x, dT - 0.08, zWB - 0.62); g.add_child(vm)
		for k in range(3): _box(g, 0.08, 0.006, 0.01, x, dT - 0.1 + k * 0.02, zWB - 0.635, metal)
	for x in [-0.08, 0.08]:
		_box(g, 0.12, 0.05, 0.02, x, dT - 0.02, zWB - 0.62, vent)
		for k in range(3): _box(g, 0.11, 0.004, 0.01, x, dT - 0.035 + k * 0.015, zWB - 0.635, metal)
	# climate knobs and the hazard button under the radio
	for x in [-0.09, 0.0, 0.09]:
		var kn = MeshInstance.new(); var km = CylinderMesh.new(); km.top_radius = 0.022; km.bottom_radius = 0.024; km.height = 0.03; km.radial_segments = 12
		kn.mesh = km; kn.material_override = metal if x == 0.0 else black; kn.rotation = Vector3(PI / 2, 0, 0); kn.translation = Vector3(x, dT - 0.28, zWB - 0.67); g.add_child(kn)
	_box(g, 0.035, 0.035, 0.02, 0, dT - 0.2, zWB - 0.675, _mat("hazard", 0xb3121a, 0.5))
	# the wheel's stalks and the column shroud
	for s in [-1, 1]:
		_bar(g, Vector3(xD + s * 0.05, eyeY - 0.43, eyeZ + 0.49), Vector3(xD + s * 0.2, eyeY - 0.42, eyeZ + 0.46), 0.008, black)
	_box(g, 0.13, 0.1, 0.2, xD, eyeY - 0.47, eyeZ + 0.55, black)
	# gear lever (P R N D) and the handbrake, between the seats
	var gate = _box(g, 0.1, 0.01, 0.2, 0.0, 0.875, eyeZ + 0.22, black)
	shifter = Spatial.new(); shifter.translation = Vector3(0, 0.88, eyeZ + 0.22); g.add_child(shifter)
	_bar(shifter, Vector3(), Vector3(0, 0.16, 0), 0.012, metal)
	var knob = MeshInstance.new(); var ks = SphereMesh.new(); ks.radius = 0.035; ks.height = 0.08; ks.radial_segments = 12; ks.rings = 6
	knob.mesh = ks; knob.material_override = black; knob.translation = Vector3(0, 0.18, 0); shifter.add_child(knob)
	hb_lever = Spatial.new(); hb_lever.translation = Vector3(0.0, 0.88, eyeZ - 0.12); g.add_child(hb_lever)
	_box(hb_lever, 0.04, 0.03, 0.26, 0, 0.0, -0.11, black)
	_box(hb_lever, 0.05, 0.04, 0.08, 0, 0.0, -0.22, soft)
	# cupholders
	for z in [eyeZ + 0.02, eyeZ + 0.1]:
		var cu = MeshInstance.new(); var cy = CylinderMesh.new(); cy.top_radius = 0.035; cy.bottom_radius = 0.035; cy.height = 0.012; cy.radial_segments = 12
		cu.mesh = cy; cu.material_override = vent; cu.translation = Vector3(0.0, 0.872, z); g.add_child(cu)
	# pedals under your feet
	pedals = []
	for pd in [[xD + 0.09, 0.08, 0.1], [xD - 0.1, 0.12, 0.08]]:
		var pv = Spatial.new(); pv.translation = Vector3(pd[0], 0.62, zWB - 0.42); g.add_child(pv)
		_bar(pv, Vector3(), Vector3(0, -0.24, -0.06), 0.01, metal)
		_box(pv, pd[1], pd[2], 0.015, 0, -0.27, -0.07, black, -0.4)
		pedals.append(pv)
	# door panels: armrest, speaker, window switches, the handle
	for s in [-1, 1]:
		var x = s * (W / 2 - 0.1)
		_box(g, 0.08, 0.06, 0.45, x, 0.78, eyeZ + 0.05, soft)
		var spk = MeshInstance.new(); var sc = CylinderMesh.new(); sc.top_radius = 0.07; sc.bottom_radius = 0.07; sc.height = 0.01; sc.radial_segments = 16
		spk.mesh = sc; spk.material_override = vent; spk.rotation = Vector3(0, 0, PI / 2); spk.translation = Vector3(x + s * -0.005, 0.52, eyeZ + 0.35); g.add_child(spk)
		for k in range(2): _box(g, 0.02, 0.012, 0.03, x - s * 0.04, 0.815, eyeZ + 0.12 + k * 0.05, black)
	# seats: the backs and headrests, the rear bench, the belt across your chest
	for x in [xD, -xD]:
		_box(g, 0.5, 0.65, 0.12, x, 0.95, eyeZ - 0.3, soft, -0.15)
		_box(g, 0.26, 0.2, 0.1, x, 1.38, eyeZ - 0.36, soft, -0.1)
	_box(g, W - 0.3, 0.14, 0.5, 0, 0.6, eyeZ - 0.85, soft)
	_box(g, W - 0.3, 0.6, 0.12, 0, 0.95, eyeZ - 1.12, soft, -0.2)
	_bar(g, Vector3(xD + 0.24, eyeY - 0.02, eyeZ - 0.28), Vector3(xD - 0.2, 0.7, eyeZ - 0.02), 0.03, belt)
	# wipers: they rest along the bottom of the windshield and sweep up across it
	wipers = []
	var tilt = atan2(zWT - zWB, yWT - yWB)
	for x in [xD - 0.05, -0.18]:
		var pv2 = Spatial.new()
		pv2.transform = Transform(Basis(Vector3(1, 0, 0), tilt), Vector3(x - 0.25, yWB + 0.04, zWB + 0.04))
		g.add_child(pv2)
		var arm = Spatial.new(); pv2.add_child(arm)
		_box(arm, 0.55, 0.012, 0.012, 0.27, 0.0, 0.012, black)
		_box(arm, 0.5, 0.02, 0.008, 0.3, 0.0, 0.02, black)
		wipers.append(arm)
	# the rear-view mirror shows the road behind (live on high quality); fuzzy dice under it
	# where the glass is at a given height, so the mirror hangs just behind it
	var my = min(eyeY + 0.07, yWT - 0.05)
	var glass_z = zWB + (zWT - zWB) * clamp((my - yWB) / max(0.01, yWT - yWB), 0.0, 1.0)
	mirror_pos = Vector3(0, my, min(eyeZ + 0.42, glass_z - 0.06))
	_box(g, 0.25, 0.075, 0.03, 0, mirror_pos.y, mirror_pos.z + 0.012, trim)
	_bar(g, mirror_pos + Vector3(0, 0.03, 0.02), Vector3(0, min(roofY - 0.04, yWT - 0.02), glass_z - 0.01), 0.012, trim)
	if G.S.get("settings", {}).get("quality", "high") == "high":
		mirror_vp = Viewport.new(); mirror_vp.size = Vector2(320, 96); mirror_vp.render_target_v_flip = true
		mirror_vp.render_target_update_mode = Viewport.UPDATE_ALWAYS; mirror_vp.shadow_atlas_size = 0
		mirror_vp.msaa = Viewport.MSAA_DISABLED
		g.add_child(mirror_vp)
		mirror_cam = Camera.new(); mirror_cam.fov = 38; mirror_cam.near = 0.3; mirror_cam.far = 140; mirror_cam.current = true
		mirror_vp.add_child(mirror_cam)
		var mq = MeshInstance.new(); var qm = QuadMesh.new(); qm.size = Vector2(0.22, 0.062); mq.mesh = qm
		var mm = SpatialMaterial.new(); mm.flags_unshaded = true; mm.albedo_texture = mirror_vp.get_texture()
		mm.uv1_scale = Vector3(-1, 1, 1); mm.uv1_offset = Vector3(1, 0, 0)
		mq.material_override = mm
		mq.transform = Transform(Basis(Vector3(0, 1, 0), PI), mirror_pos + Vector3(0, 0, -0.004))
		g.add_child(mq)
	else:
		var mg = _mat("mirrorglass", 0x6a7480, 0.05, 0.9)
		_box(g, 0.22, 0.062, 0.004, 0, mirror_pos.y, mirror_pos.z - 0.004, mg)
	dice = Spatial.new(); dice.translation = mirror_pos + Vector3(0, -0.035, 0.01); g.add_child(dice)
	var red = _mat("dice", 0xd8102a, 0.95)
	for k in [-1, 1]:
		var st = Spatial.new(); st.translation = Vector3(k * 0.03, 0, 0); dice.add_child(st)
		_bar(st, Vector3(), Vector3(0, -0.11 - (0.02 if k > 0 else 0.0), 0), 0.002, _mat("string", 0xf0f0f0, 0.9))
		var cube = _box(st, 0.05, 0.05, 0.05, 0, -0.14 - (0.02 if k > 0 else 0.0), 0, red, 0.4 * k, 0.6, 0.2)
		for pip in [Vector3(0, 0, 0.51), Vector3(0.51, 0.2, 0.2), Vector3(0.51, -0.2, -0.2), Vector3(-0.2, 0.51, 0.2), Vector3(0.2, 0.51, -0.2), Vector3(0, -0.51, 0)]:
			var pm = MeshInstance.new(); var cmm = CubeMesh.new(); cmm.size = Vector3(0.2, 0.2, 0.2); pm.mesh = cmm
			pm.material_override = _mat("pip", 0xf4f4f4, 0.9); pm.translation = pip; cube.add_child(pm)
	# the dash light at night
	dash_light = OmniLight.new(); dash_light.omni_range = 0.9; dash_light.light_color = Color(1.0, 0.62, 0.32); dash_light.light_energy = 0.0
	dash_light.translation = Vector3(xD, eyeY - 0.25, eyeZ + 0.35); dash_light.visible = false; g.add_child(dash_light)
	odo0 = 30000 + (hash(v.model + str(v.color)) % 90000)

func _screen(size):
	var vp = Viewport.new()
	vp.size = size; vp.usage = Viewport.USAGE_2D; vp.render_target_v_flip = true
	vp.render_target_update_mode = Viewport.UPDATE_ALWAYS; vp.transparent_bg = false
	root.add_child(vp)
	return vp

func _screen_quad(parent, vp, size, pos, rot):
	var mi = MeshInstance.new(); var qm = QuadMesh.new(); qm.size = size; mi.mesh = qm
	var mt = SpatialMaterial.new(); mt.flags_unshaded = true; mt.albedo_texture = vp.get_texture()
	mi.material_override = mt
	mi.transform = Transform(Basis(Vector3(1, 0, 0), rot.x) * Basis(Vector3(0, 1, 0), rot.y), pos)
	parent.add_child(mi)

func _key_for(v):
	return v.model + ":" + str(v.color) + ":" + JSON.print(G.S["skin"])

func clear():
	if root: root.queue_free()
	root = null; key = ""
	mirror_vp = null; mirror_cam = null; dice = null; shifter = null; hb_lever = null; pedals = []; wipers = []; dash_light = null
	if shown_car and is_instance_valid(shown_car.node): shown_car.node.visible = true
	shown_car = null

func hide():
	if root: root.visible = false
	if mirror_vp: mirror_vp.render_target_update_mode = Viewport.UPDATE_DISABLED
	if shown_car and is_instance_valid(shown_car.node): shown_car.node.visible = true
	shown_car = null

# places the camera at the driver's eye and poses the wheel, hands and arms
func update(v, cam, dt):
	if root == null or key != _key_for(v): build(v)
	root.visible = true
	if mirror_vp: mirror_vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
	if shown_car != v:
		hide(); root.visible = true
		shown_car = v
	v.node.visible = false
	root.translation = v.pos
	root.rotation = Vector3(0, v.yaw, 0)
	var sp = abs(v.speed)
	var lat = v.steer * sp
	var P = main.player
	var e = eye + Vector3(clamp(lat * 0.002, -0.05, 0.05), sin(G.REAL_T * 17) * min(sp, 25) * 0.0004 + (randf() - 0.5) * P.shake * 0.03, 0)
	cam.translation = root.global_transform.xform(e)
	var look = clamp(G.ang_diff(v.yaw + PI, P.cam_yaw), -2.0, 2.0)
	cam.rotation = Vector3(clamp(P.cam_pitch + 0.06, -0.6, 0.5), v.yaw + PI + look, -clamp(lat * 0.0015, -0.03, 0.03))
	spin.rotation.z = -v.steer * 2.4
	var sx = [eye.x + 0.2, eye.x - 0.2]
	flip_k = move_toward(flip_k, 1.0 if P.flipping() else 0.0, dt * 6.0)
	var fe = flip_k * flip_k * (3.0 - 2.0 * flip_k)
	hands[0].visible = fe < 0.35
	flip_hand.visible = fe > 0.01
	for i in range(2):
		var hp = root.global_transform.affine_inverse().xform(hands[i].global_transform.origin)
		if i == 0 and flip_hand.visible:
			var up = Vector3(eye.x + 0.2, eye.y - 0.1 + sin(G.REAL_T * 9) * 0.006, eye.z + 0.34)
			flip_hand.translation = hp.linear_interpolate(up, fe)
			flip_hand.rotation = Vector3(-0.15 * fe, 0, -0.2 * fe)
			hp = flip_hand.translation
		_limb(arms[i], hp + Vector3(0, -0.02, -0.04), Vector3(sx[i], eye.y - 0.3, eye.z - 0.02), 0.04)
	gauge_view.update(); radio_view.update()
	_animate(v, dt)

func _animate(v, dt):
	var inp = main.vehicles._player_input()
	# gear lever: P while starting, R reversing, D otherwise
	var eng = main.sfx.engine_state()
	var pos = -0.28 if eng.rpm < 1.0 else (-0.1 if v.speed < -0.3 else 0.14)
	if shifter: shifter.rotation.x = lerp(shifter.rotation.x, pos, min(1.0, dt * 14.0))
	if hb_lever: hb_lever.rotation.x = lerp(hb_lever.rotation.x, 0.5 if inp.hand else 0.0, min(1.0, dt * 16.0))
	if pedals.size() == 2:
		pedals[0].rotation.x = lerp(pedals[0].rotation.x, -0.35 * float(inp.get("gas", 0.0)), min(1.0, dt * 18.0))
		pedals[1].rotation.x = lerp(pedals[1].rotation.x, -0.3 * float(inp.get("brk", 0.0)), min(1.0, dt * 18.0))
	# wipers: every few seconds while it snows, steady in a storm
	var storm = main.sky.storm if main.sky else 0.0
	var snowing = main.fx and main.fx.snow and main.fx.snow.emitting
	wipe_t -= dt
	if wipe_ph <= 0.0 and snowing and wipe_t <= 0.0:
		wipe_ph = 0.001
		wipe_t = lerp(4.5, 0.2, clamp(storm, 0.0, 1.0))
	if wipe_ph > 0.0:
		wipe_ph += dt / 1.1
		if wipe_ph >= 1.0: wipe_ph = 0.0
	var a = sin(wipe_ph * PI) * 1.55
	for w in wipers: w.rotation.z = a
	# the dice swing with the car: braking throws them forward, corners to the side
	if dice:
		var acc = Vector2(-v.ax if "ax" in v else 0.0, v.ay if "ay" in v else 0.0)
		var L = 0.14
		for k in range(2):
			var th = Vector2(dice_a.x, dice_a.y)
			var f = Vector2(-9.8 / L * sin(th.x) - acc.x / L * cos(th.x), -9.8 / L * sin(th.y) - acc.y / L * cos(th.y)) - dice_v * 2.2
			dice_v += f * dt * 0.5
			dice_a += dice_v * dt * 0.5
		dice_a.x = clamp(dice_a.x, -1.1, 1.1); dice_a.y = clamp(dice_a.y, -1.1, 1.1)
		dice.rotation = Vector3(dice_a.x, 0, dice_a.y)
	# the mirror's camera, looking back from the mirror
	if mirror_cam and root:
		var xf = root.global_transform
		mirror_cam.global_transform = Transform(xf.basis * Basis(Vector3(0, 1, 0), 0.0) * Basis(Vector3(1, 0, 0), -0.05), xf.xform(Vector3(0, eye.y - 0.02, eye.z - 0.55)))
	if dash_light:
		var n = main.DN.night
		dash_light.visible = n > 0.2
		dash_light.light_energy = 0.35 * n
