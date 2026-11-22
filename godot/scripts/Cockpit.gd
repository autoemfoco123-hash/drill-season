extends Node
# The car interior for first-person driving, ported from the web game's buildCockpit:
# the hood in the car's paint, dashboard, instrument pod with live RPM and speed dials,
# the radio screen, a steering wheel that turns with your hands on it, pillars, roof,
# door panels, mirrors and the passenger seat. Built per car model from its cabin shape.

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

class Gauges extends Control:
	var ck
	func _draw():
		var P = ck.main.player
		var v = P.car
		if v == null: return
		var eng = ck.main.sfx.engine_state()
		var mph = int(round(abs(v.speed) * 2.237))
		var rpm = eng.rpm
		var red = eng.red
		draw_rect(Rect2(Vector2(), rect_size), Color(0.02, 0.024, 0.03))
		_dial(Vector2(110, 100), rpm, 8000.0, "RPM ×1000", red / 8000.0)
		_dial(Vector2(402, 100), mph, 140.0, "MPH", 2.0)
		var s = str(mph)
		draw_string(G.font_cash, Vector2(256 - G.font_cash.get_string_size(s).x / 2, 92), s, Color(1, 0.7, 0.28))
		var gear = "R" if v.speed < -0.3 else str(eng.gear + 1)
		draw_string(G.font_l, Vector2(256 - G.font_l.get_string_size(gear).x / 2, 138), gear, Color(0.78, 0.82, 0.86))
		var c = G.clock_str()
		draw_string(G.font_xs, Vector2(256 - G.font_xs.get_string_size(c).x / 2, 176), c, Color(0.48, 0.88, 0.65))
	func _dial(c, val, mx, label, red_from):
		var r = 78.0
		var a0 = PI * 0.75
		var a1 = PI * 2.25
		draw_arc(c, r, a0, a1, 48, Color(0.16, 0.19, 0.21), 3)
		for i in range(11):
			var a = a0 + (a1 - a0) * i / 10.0
			var hot = i / 10.0 >= red_from
			var inner = r - (11 if i % 2 else 16)
			draw_line(c + Vector2(cos(a), sin(a)) * (r - 4), c + Vector2(cos(a), sin(a)) * inner, Color(1, 0.29, 0.23) if hot else Color(0.78, 0.82, 0.86), 2 if i % 2 else 3)
		var an = a0 + (a1 - a0) * clamp(val / mx, 0, 1)
		draw_line(c, c + Vector2(cos(an), sin(an)) * (r - 12), Color(1, 0.48, 0.16), 4)
		draw_circle(c, 9, Color(0.1, 0.12, 0.13))
		draw_string(G.font_xs, c + Vector2(-G.font_xs.get_string_size(label).x / 2, 52), label, Color(0.54, 0.59, 0.64))

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
	var eyeY = max(yWB + 0.32, roofY - 0.26)
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
	_box(g, 0.25, 0.075, 0.03, 0, yWT - 0.15, zWT - 0.14, trim)
	_box(g, 0.23, 0.06, 0.005, 0, yWT - 0.15, zWT - 0.157, chrome)
	_bar(g, Vector3(0, yWT - 0.11, zWT - 0.14), Vector3(0, yWT - 0.03, zWT - 0.07), 0.012, trim)
	_box(g, 0.5, 0.12, 0.55, -xD, 0.62, eyeZ, soft)
	_box(g, 0.5, 0.65, 0.12, -xD, 0.95, eyeZ - 0.3, soft, -0.15)
	# windshield and wipers
	var wl = Vector2(zWT - zWB, yWT - yWB).length()
	var wsh = MeshInstance.new(); var qm = QuadMesh.new(); qm.size = Vector2(W - 0.2, wl); wsh.mesh = qm; wsh.material_override = glass
	wsh.transform = Transform(Basis(Vector3(1, 0, 0), atan2(zWT - zWB, yWT - yWB)), Vector3(0, (yWB + yWT) / 2, (zWB + zWT) / 2))
	g.add_child(wsh)
	for x in [xD - 0.05, -0.15]:
		_box(g, 0.55, 0.015, 0.02, x + 0.1, yWB + 0.03, zWB + 0.05, dash, 0, 0, 0.12)
	key = _key_for(v)

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
	if shown_car and is_instance_valid(shown_car.node): shown_car.node.visible = true
	shown_car = null

func hide():
	if root: root.visible = false
	if shown_car and is_instance_valid(shown_car.node): shown_car.node.visible = true
	shown_car = null

# places the camera at the driver's eye and poses the wheel, hands and arms
func update(v, cam, dt):
	if root == null or key != _key_for(v): build(v)
	root.visible = true
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
