extends Node
# Weather and small effects: falling snow that drifts with the wind, flames in the fire
# barrels near you, steam from the street vents, and snowballs (which people take personally).

var main
var snow
var fires = []
var steams = []
var balls = []
var _near_t = 0.0
# tires: smoke when they spin or slide, and the black marks they leave on the road
var smoke = []
var spray = []
var spray_on = true
var carfx = {}          # burning cars: car id -> { smoke, fire, light }
var _timed = []         # [node, seconds left]
var _flashes = []       # [OmniLight, seconds left, energy]
var _soft = null
var skid_mm = null
var skid_i = 0
var skid_last = [null, null]
const SKIDS = 900

func setup(m):
	main = m
	snow = CPUParticles.new()
	snow.amount = 500
	snow.lifetime = 6.0
	snow.local_coords = false
	snow.emission_shape = CPUParticles.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(22, 0.5, 22)
	snow.direction = Vector3(0, -1, 0)
	snow.spread = 12
	snow.gravity = Vector3(0, -0.6, 0)
	snow.initial_velocity = 1.4
	snow.initial_velocity_random = 0.4
	snow.scale_amount = 1.0
	snow.scale_amount_random = 0.6
	var q = QuadMesh.new(); q.size = Vector2(0.05, 0.05)
	var sm = SpatialMaterial.new(); sm.flags_unshaded = true; sm.flags_transparent = true; sm.albedo_color = Color(1, 1, 1, 0.85)
	sm.params_billboard_mode = SpatialMaterial.BILLBOARD_PARTICLES; sm.flags_disable_ambient_light = true
	q.material = sm
	snow.mesh = q
	main.add_child(snow)
	for i in range(3):
		fires.append(_fire())
	for i in range(2):
		steams.append(_steam())
	_tire_setup()

func _particles(amount, life, col, size, add):
	var p = CPUParticles.new()
	p.amount = amount; p.lifetime = life; p.local_coords = false
	var q = QuadMesh.new(); q.size = Vector2(size, size)
	var m = SpatialMaterial.new(); m.flags_unshaded = true; m.flags_transparent = true; m.albedo_color = col
	m.params_billboard_mode = SpatialMaterial.BILLBOARD_PARTICLES; m.vertex_color_use_as_albedo = true
	if add: m.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	q.material = m; p.mesh = q
	p.visible = false
	main.add_child(p)
	return p

func _fire():
	var p = _particles(28, 0.7, Color(1, 0.55, 0.15, 0.9), 0.32, true)
	p.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.22
	p.direction = Vector3(0, 1, 0); p.spread = 15; p.gravity = Vector3(0, 1.5, 0); p.initial_velocity = 1.0; p.initial_velocity_random = 0.5
	p.scale_amount = 1.0; p.scale_amount_random = 0.5
	var g = Gradient.new(); g.set_color(0, Color(1, 0.85, 0.4, 1)); g.set_color(1, Color(0.8, 0.15, 0.02, 0)); p.color_ramp = g
	return p

func _steam():
	var p = _particles(22, 3.0, Color(0.92, 0.95, 1, 0.3), 1.2, false)
	p.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.35
	p.direction = Vector3(0, 1, 0); p.spread = 20; p.gravity = Vector3(0, 0.3, 0); p.initial_velocity = 0.9; p.initial_velocity_random = 0.4
	var g = Gradient.new(); g.set_color(0, Color(1, 1, 1, 0.35)); g.set_color(1, Color(1, 1, 1, 0)); p.color_ramp = g
	return p

func _soft_tex():
	var n = 32
	var img = Image.new(); img.create(n, n, false, Image.FORMAT_RGBA8)
	img.lock()
	for y in range(n):
		for x in range(n):
			var d = Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length() / (n / 2.0)
			var a = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	img.unlock()
	var t = ImageTexture.new(); t.create_from_image(img)
	return t

func _tire_setup():
	var soft = _soft_tex()
	for i in range(2):
		# lit by the sun and the street lights (not glowing), grey enough to read on snow
		var p = _particles(64, 2.2, Color(0.74, 0.75, 0.78, 0.8), 1.0, false)
		p.mesh.material.albedo_texture = soft
		p.mesh.material.flags_unshaded = false
		p.mesh.material.params_diffuse_mode = SpatialMaterial.DIFFUSE_LAMBERT_WRAP
		p.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.3
		p.direction = Vector3(0, 1, 0); p.spread = 80; p.gravity = Vector3(0, 0.45, 0)
		p.initial_velocity = 1.6; p.initial_velocity_random = 0.6; p.damping = 1.1
		p.scale_amount = 3.0; p.scale_amount_random = 0.45
		var cv = Curve.new(); cv.add_point(Vector2(0, 0.3)); cv.add_point(Vector2(0.5, 0.85)); cv.add_point(Vector2(1, 1.25)); p.scale_amount_curve = cv
		var g = Gradient.new(); g.set_color(0, Color(0.9, 0.9, 0.92, 0.85)); g.set_color(1, Color(0.8, 0.8, 0.84, 0.0))
		g.add_point(0.35, Color(0.86, 0.86, 0.9, 0.6)); p.color_ramp = g
		p.emitting = false; p.visible = true
		smoke.append(p)
	# snow kicked up behind the rear wheels when you're moving (not on the Fast setting)
	for i in range(2):
		var q = _particles(36, 0.55, Color(0.95, 0.97, 1.0, 0.55), 0.4, false)
		q.mesh.material.albedo_texture = soft
		q.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE; q.emission_sphere_radius = 0.12
		q.spread = 22; q.gravity = Vector3(0, -6.0, 0); q.initial_velocity_random = 0.4; q.damping = 2.0
		q.scale_amount = 1.0; q.scale_amount_random = 0.5
		var g2 = Gradient.new(); g2.set_color(0, Color(1, 1, 1, 0.55)); g2.set_color(1, Color(1, 1, 1, 0.0)); q.color_ramp = g2
		q.emitting = false; q.visible = true
		spray.append(q)
	# skid marks: short dark strips on the road, oldest replaced first
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]:
		st.add_normal(Vector3.UP); st.add_vertex(q)
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = SKIDS
	for i in range(SKIDS):
		mm.set_instance_transform(i, Transform(Basis().scaled(Vector3(0.001, 0.001, 0.001)), Vector3(0, -50, 0)))
	var mat = SpatialMaterial.new(); mat.flags_unshaded = true; mat.flags_transparent = true
	mat.albedo_color = Color(0.03, 0.03, 0.04, 0.42); mat.params_cull_mode = SpatialMaterial.CULL_DISABLED
	var mi = MultiMeshInstance.new(); mi.multimesh = mm; mi.material_override = mat
	mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	main.add_child(mi)
	skid_mm = mm

func _skid_strip(a, b, w):
	var d = b - a
	var n = Vector3(-d.z, 0, d.x).normalized() * w
	skid_mm.set_instance_transform(skid_i, Transform(Basis(d, Vector3.UP, n), (a + b) * 0.5))
	skid_i = (skid_i + 1) % SKIDS

# called every frame for your car: smoke from the rear wheels and marks on the road
func tires(v, dt):
	var V = main.vehicles
	var f = V.fwd(v)
	var l = V.side(v)
	var back = -f * (float(v.sp.wbLen) * 0.5)
	var half = float(v.sp.wid) * 0.5 - 0.24
	var wheels = [v.pos + back + l * half, v.pos + back - l * half]
	var s = v.slip
	for i in range(2):
		var p = smoke[i]
		p.translation = wheels[i] + Vector3(0, 0.3, 0)
		p.emitting = s > 0.28
		if i < spray.size():
			var q = spray[i]
			var sp = abs(v.speed)
			q.translation = wheels[i] + Vector3(0, 0.12, 0) - f * 0.35 * sign(v.speed)
			q.direction = Vector3(-f.x * sign(v.speed), 0.45, -f.z * sign(v.speed))
			q.initial_velocity = 1.2 + sp * 0.1
			q.emitting = spray_on and sp > 7.0 and s < 0.28 and not v.blown
		var w = wheels[i] + Vector3(0, 0.028, 0)
		if s > 0.22:
			var last = skid_last[i]
			if last == null or last.distance_to(w) > 3.0:
				skid_last[i] = w
			elif last.distance_to(w) > 0.3:
				_skid_strip(last, w, 0.23)
				skid_last[i] = w
		else:
			skid_last[i] = null

func _filter_live(a):
	var out = []
	for t in a:
		if t[1] > 0: out.append(t)
	return out

func set_quality(q):
	snow.amount = 900 if q == "high" else (650 if q == "medium" else 420)
	spray_on = q != "low"

# ---------- a car shot to pieces: engine smoke, fire, the explosion ----------
func car_fx(v, smoke_k, fire, at):
	var e = carfx.get(v.id)
	if e == null:
		if smoke_k <= 0.0 and not fire: return
		if _soft == null: _soft = _soft_tex()
		var sm = _particles(36, 2.6, Color(1, 1, 1, 1), 1.0, false)
		sm.mesh.material.albedo_texture = _soft
		sm.mesh.material.flags_unshaded = false
		sm.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE; sm.emission_sphere_radius = 0.3
		sm.direction = Vector3(0, 1, 0); sm.spread = 25; sm.gravity = Vector3(0.6, 1.6, 0)
		sm.initial_velocity = 1.2; sm.initial_velocity_random = 0.5; sm.damping = 0.4
		sm.scale_amount = 2.2; sm.scale_amount_random = 0.4
		var cv = Curve.new(); cv.add_point(Vector2(0, 0.3)); cv.add_point(Vector2(1, 1.6)); sm.scale_amount_curve = cv
		sm.visible = true
		var fi = _particles(34, 0.75, Color(1, 0.6, 0.2, 0.95), 0.75, true)
		fi.mesh.material.albedo_texture = _soft
		fi.emission_shape = CPUParticles.EMISSION_SHAPE_BOX; fi.emission_box_extents = Vector3(0.5, 0.1, 0.5)
		fi.direction = Vector3(0, 1, 0); fi.spread = 15; fi.gravity = Vector3(0, 2.5, 0); fi.initial_velocity = 1.4; fi.initial_velocity_random = 0.5
		fi.scale_amount = 1.3; fi.scale_amount_random = 0.5
		# (kept red and not too bright: many flames added together would clip to yellow-green)
		fi.mesh.material.albedo_color = Color(1, 1, 1, 1)
		var g = Gradient.new(); g.set_color(0, Color(0.9, 0.55, 0.2, 0.55)); g.set_color(1, Color(0.4, 0.05, 0.01, 0)); g.add_point(0.4, Color(0.85, 0.28, 0.04, 0.5)); fi.color_ramp = g
		fi.visible = true
		var li = OmniLight.new(); li.light_color = Color(1, 0.55, 0.2); li.omni_range = 9; li.light_energy = 0.0; li.shadow_enabled = false
		main.add_child(li)
		e = { "smoke": sm, "fire": fi, "light": li }
		carfx[v.id] = e
	e.smoke.translation = at
	e.smoke.emitting = smoke_k > 0.0
	var grey = lerp(0.62, 0.09, clamp(smoke_k, 0.0, 1.0))
	var g2 = Gradient.new(); g2.set_color(0, Color(grey, grey, grey, 0.9)); g2.add_point(0.3, Color(grey, grey, grey, 0.8)); g2.set_color(g2.get_point_count() - 1, Color(grey * 0.8, grey * 0.8, grey * 0.8, 0.0))
	e.smoke.color_ramp = g2
	e.fire.translation = at + Vector3(0, 0.05, 0)
	e.fire.emitting = fire
	e.light.translation = at + Vector3(0, 0.6, 0)
	e.light.visible = fire
	e.light.light_energy = (1.6 + sin(G.REAL_T * 23.0) * 0.3 + sin(G.REAL_T * 7.0) * 0.25) if fire else 0.0

func car_fx_clear(v):
	var e = carfx.get(v.id)
	if e == null: return
	for k in ["smoke", "fire", "light"]:
		if is_instance_valid(e[k]): e[k].queue_free()
	carfx.erase(v.id)

func explosion(at):
	if _soft == null: _soft = _soft_tex()
	# the fireball
	var fb = _particles(46, 1.0, Color(1, 0.7, 0.3, 1), 2.2, true)
	fb.mesh.material.albedo_texture = _soft
	fb.one_shot = true; fb.explosiveness = 0.92
	fb.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE; fb.emission_sphere_radius = 0.9
	fb.direction = Vector3(0, 1, 0); fb.spread = 180; fb.initial_velocity = 6.5; fb.initial_velocity_random = 0.5
	fb.damping = 7.0; fb.gravity = Vector3(0, 3.0, 0); fb.scale_amount = 2.4; fb.scale_amount_random = 0.5
	var cv = Curve.new(); cv.add_point(Vector2(0, 0.5)); cv.add_point(Vector2(1, 1.5)); fb.scale_amount_curve = cv
	fb.mesh.material.albedo_color = Color(1, 1, 1, 1)
	var g = Gradient.new(); g.set_color(0, Color(1, 0.85, 0.55, 0.9)); g.add_point(0.25, Color(0.95, 0.42, 0.08, 0.75)); g.add_point(0.6, Color(0.5, 0.1, 0.02, 0.5)); g.set_color(g.get_point_count() - 1, Color(0.1, 0.05, 0.03, 0))
	fb.color_ramp = g
	# the black cloud rolling up after it
	var sm = _particles(30, 4.0, Color(1, 1, 1, 1), 3.0, false)
	sm.mesh.material.albedo_texture = _soft
	sm.mesh.material.flags_unshaded = false
	sm.one_shot = true; sm.explosiveness = 0.6
	sm.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE; sm.emission_sphere_radius = 1.0
	sm.direction = Vector3(0, 1, 0); sm.spread = 60; sm.initial_velocity = 3.5; sm.initial_velocity_random = 0.5; sm.damping = 1.2
	sm.gravity = Vector3(0.5, 1.2, 0); sm.scale_amount = 2.5; sm.scale_amount_random = 0.4
	var cv2 = Curve.new(); cv2.add_point(Vector2(0, 0.6)); cv2.add_point(Vector2(1, 2.4)); sm.scale_amount_curve = cv2
	var g2 = Gradient.new(); g2.set_color(0, Color(0.12, 0.1, 0.09, 0.0)); g2.add_point(0.12, Color(0.1, 0.09, 0.08, 0.85)); g2.set_color(g2.get_point_count() - 1, Color(0.2, 0.2, 0.2, 0.0))
	sm.color_ramp = g2
	# debris and sparks
	var db = _particles(26, 2.4, Color(0.06, 0.06, 0.07, 1), 0.16, false)
	db.one_shot = true; db.explosiveness = 1.0
	db.direction = Vector3(0, 1, 0); db.spread = 70; db.initial_velocity = 11.0; db.initial_velocity_random = 0.6
	db.gravity = Vector3(0, -18, 0); db.scale_amount_random = 0.8
	var sp = _particles(40, 1.1, Color(1, 0.8, 0.4, 1), 0.07, true)
	sp.one_shot = true; sp.explosiveness = 1.0
	sp.direction = Vector3(0, 1, 0); sp.spread = 100; sp.initial_velocity = 14.0; sp.initial_velocity_random = 0.6; sp.gravity = Vector3(0, -12, 0)
	for n in [fb, sm, db, sp]:
		n.translation = at
		n.visible = true
		n.emitting = true
		_timed.append([n, 6.0])
	# the flash
	var li = OmniLight.new(); li.light_color = Color(1, 0.65, 0.3); li.omni_range = 28; li.light_energy = 7.0; li.shadow_enabled = false
	li.translation = at + Vector3(0, 1.5, 0)
	main.add_child(li)
	_flashes.append([li, 0.7, 7.0])
	# a scorch mark on the road
	var mi = MeshInstance.new(); var q = QuadMesh.new(); q.size = Vector2(6.5, 6.5); mi.mesh = q
	var m = SpatialMaterial.new(); m.flags_transparent = true; m.flags_unshaded = true; m.albedo_texture = _soft; m.albedo_color = Color(0.03, 0.025, 0.02, 0.85)
	mi.material_override = m; mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform(Basis(Vector3(1, 0, 0), -PI / 2), Vector3(at.x, 0.035, at.z))
	main.add_child(mi)
	_timed.append([mi, 150.0])

# afterfire: a short flame and a flash out of each tip (tips in the car's frame)
var _bf_mat = null
func backfire(xf, tips, vol):
	if _soft == null: _soft = _soft_tex()
	if _bf_mat == null:
		_bf_mat = SpatialMaterial.new(); _bf_mat.flags_unshaded = true; _bf_mat.flags_transparent = true
		_bf_mat.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD; _bf_mat.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED
		_bf_mat.albedo_texture = _soft; _bf_mat.albedo_color = Color(1.0, 0.55, 0.18, 1.0)
	var back = -xf.basis.z.normalized()
	for t in tips:
		var mi = MeshInstance.new()
		var q = QuadMesh.new(); var sz = 0.22 + vol * 0.35 + randf() * 0.12; q.size = Vector2(sz, sz)
		mi.mesh = q; mi.material_override = _bf_mat; mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		mi.translation = xf.xform(t) + back * (0.1 + sz * 0.35)
		main.add_child(mi)
		_timed.append([mi, 0.07 + randf() * 0.05])
	var li = OmniLight.new(); li.light_color = Color(1.0, 0.5, 0.18); li.omni_range = 4.0; li.shadow_enabled = false
	li.translation = xf.xform(tips[0]) + back * 0.3
	main.add_child(li)
	var life = 0.09
	_flashes.append([li, life, (1.2 + vol * 1.5) * 0.7 / life])

func update(dt):
	for t in _timed:
		t[1] -= dt
		if t[1] <= 0 and is_instance_valid(t[0]): t[0].queue_free()
	_timed = _filter_live(_timed)
	for f in _flashes:
		f[1] -= dt
		if is_instance_valid(f[0]):
			f[0].light_energy = max(0.0, f[2] * f[1] / 0.7)
			if f[1] <= 0: f[0].queue_free()
	_flashes = _filter_live(_flashes)
	_brass_update(dt)
	if main.player.car == null:
		for p in smoke: p.emitting = false
		for p in spray: p.emitting = false
	var cam = main.camera.global_transform.origin
	var st = main.story
	var w = Vector3(st.WIND.dx, 0, st.WIND.dz) * (0.6 + st.WIND.gust * 2.2)
	snow.translation = cam + Vector3(0, 9, 0) - w * 3.0
	snow.gravity = Vector3(w.x * 0.6, -0.6, w.z * 0.6)
	_near_t -= dt
	if _near_t <= 0:
		_near_t = 0.5
		_place(fires, G.D["BARRELS"], cam, 40, 1.0)
		_place(steams, G.D["VENTS"], cam, 35, 0.15)
	_update_balls(dt)

func _place(list, spots, cam, r, y):
	var near = []
	for s in spots:
		var d = Vector2(s[0] - cam.x, s[1] - cam.z).length()
		if d < r: near.append([d, s])
	near.sort_custom(self, "_by_d")
	for i in range(list.size()):
		var p = list[i]
		if i < near.size():
			var s = near[i][1]
			p.translation = Vector3(s[0], y, s[1]); p.visible = true; p.emitting = true
		else:
			p.visible = false; p.emitting = false

func _by_d(a, b): return a[0] < b[0]

# ---------- brass: casings out of the ejection port, bouncing on the ground ----------
var BRASS = []
var _brass_mats = []
func brass(at, v, shell = false):
	if at.distance_to(main.camera.global_transform.origin) > 14: return
	if _brass_mats.empty():
		for c in [Color(0.85, 0.66, 0.28), Color(0.72, 0.16, 0.12)]:
			var m = SpatialMaterial.new(); m.albedo_color = c; m.metallic = 0.5; m.roughness = 0.35
			G.toon(m)
			_brass_mats.append(m)
	var b = null
	for o in BRASS:
		if o.t <= 0:
			b = o; break
	if b == null:
		if BRASS.size() >= 24: b = BRASS[0]
		else:
			var mi = MeshInstance.new(); var cm = CylinderMesh.new(); cm.radial_segments = 6; cm.rings = 1
			mi.mesh = cm; mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
			main.add_child(mi)
			b = { "n": mi, "t": 0.0, "v": Vector3(), "w": Vector3() }
			BRASS.append(b)
	var cm2 = b.n.mesh
	cm2.top_radius = 0.0105 if shell else 0.0045; cm2.bottom_radius = cm2.top_radius; cm2.height = 0.06 if shell else 0.02
	b.n.material_override = _brass_mats[1 if shell else 0]
	b.n.visible = true
	b.n.translation = at
	b.v = v; b.t = 1.6
	b.w = Vector3(G.rand(-18, 18), G.rand(-18, 18), G.rand(-18, 18))

func _brass_update(dt):
	for b in BRASS:
		if b.t <= 0: continue
		b.t -= dt
		if b.t <= 0:
			b.n.visible = false; continue
		b.v.y -= 9.8 * dt
		var p = b.n.translation + b.v * dt
		var g = W.ground_at(p.x, p.z, p.y + 0.2)
		if p.y < g + 0.01:
			p.y = g + 0.01
			if abs(b.v.y) > 0.6:
				b.v = Vector3(b.v.x * 0.45, -b.v.y * 0.35, b.v.z * 0.45); b.w *= 0.5
			else:
				b.v = Vector3(); b.w = Vector3()
		b.n.translation = p
		b.n.rotation += b.w * dt

# ---------- snowballs ----------
func throw_snowball(from, vel, by):
	var m = MeshInstance.new()
	var sp = SphereMesh.new(); sp.radius = 0.08; sp.height = 0.16; sp.radial_segments = 8; sp.rings = 4
	m.mesh = sp; m.material_override = G.mat(Color(0.95, 0.97, 1))
	m.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	main.add_child(m); m.translation = from
	balls.append({ "n": m, "p": from, "v": vel, "by": by, "t": 0.0 })
	main.sfx.play3d("swing", from, 0.3, 1.3)

func _people():
	var out = []
	for p in main.peds.PEDS:
		if not p.is_down(): out.append(p)
	for e in main.crews.ENEMIES:
		if not e.is_down(): out.append(e)
	for c in main.police.COPS:
		if not c.is_down(): out.append(c)
	for f in main.gang.FOL:
		if f.state != "down" and not f.riding: out.append(f)
	return out

func _update_balls(dt):
	if balls.size() == 0: return
	var people = _people()
	for b in balls.duplicate():
		b.t += dt
		b.v.y -= 14.0 * dt
		var np = b.p + b.v * dt
		var hit = null
		# swept: at low frame rates a fast snowball moves a metre per frame
		for who in people:
			if who == b.by: continue
			if _seg_dist(b.p, np, who.pos + Vector3(0, 1.15, 0)) < 0.5 or _seg_dist(b.p, np, who.pos + Vector3(0, 1.62, 0)) < 0.3:
				hit = who; break
		if b.by != main.player and not main.player.car and _seg_dist(b.p, np, main.player.pos + Vector3(0, 1.3, 0)) < 0.5:
			hit = main.player
		var res = W.collide_point(np, 0.08)
		b.p = np
		b.n.translation = np
		if hit != null or res[1] or b.t > 4:
			_poof(np)
			if hit != null: _hit_by_snow(hit, b)
			b.n.queue_free(); balls.erase(b)

func _seg_dist(a, b, c):
	var ab = b - a
	var L2 = ab.length_squared()
	if L2 < 1e-8: return a.distance_to(c)
	var t = clamp((c - a).dot(ab) / L2, 0.0, 1.0)
	return (a + ab * t).distance_to(c)

func _poof(at):
	main.sfx.play3d("imp_snow", at, 0.5)
	main.sfx.dust(at, 6)

func _hit_by_snow(who, b):
	var P = main.player
	if who == P:
		main.hud.hurt_flash(0.0); P.shake = max(P.shake, 0.15)
		main.hud.say("Passerby", G.pick(["Got you!", "Ha! Right in the face.", "Snow war!"]))
		return
	if b.by != P: return
	G.S["stats"]["snowballs"] = int(G.S["stats"].get("snowballs", 0)) + 1
	main.peds.snowball_hit(who, b.v)
