extends Node
# Weather and small effects: falling snow that drifts with the wind, flames in the fire
# barrels near you, steam from the street vents, and snowballs (which people take personally).

var main
var snow
var fires = []
var steams = []
var balls = []
var _near_t = 0.0

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

func set_quality(q):
	snow.amount = 900 if q == "high" else (650 if q == "medium" else 420)

func update(dt):
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
