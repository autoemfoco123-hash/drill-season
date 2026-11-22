extends Node
# The tribute to XXXTentacion in the memorial garden in Calder Park (Garden.gd builds the
# place: the replica of his mausoleum from the photo his family shared, and the Poison Tree).
#
# Paying respects (E at the step) lights a candle, and the sky answers: a storm gathers in
# seconds and lightning strikes the pediment. The camera takes over (skip with Space): the
# bronze doors swing open, light pours out of the tomb, and a figure of light appears inside,
# walks out to the step, unfolds feathered wings under a golden halo while sparks circle it,
# then rises into the storm as rose petals swirl up and white doves fly off. The Poison
# Tree's veins and fruit flare violet with every strike.
# (A figure of light, not a likeness: no face, no body of a real person.)
# During real thundersnow, lightning can strike it on its own when you are near.

const Garden = preload("res://scripts/Garden.gd")
const MeshBuild = preload("res://scripts/MeshBuild.gd")

var main
var root
var garden
var g_cd = 0.0
var fx = []                    # running tributes
var last_strike = { "garden": -999.0 }
var glow_shader = null
var tributes = 0
var tree_flash = 0.0

const MC = Vector3(-81.2, 0, 47.0)          # the mausoleum (faces +x, the gate)
const G_SPOT = Vector3(-78.4, 0, 47.0)

func setup(m):
	main = m
	glow_shader = load("res://scripts/glow.shader")
	G.D["LOC"]["garden"] = { "x": MC.x + 3.0, "z": MC.z, "name": "Memorial garden" }
	G.D["INTERACT"].append({ "id": "garden", "x": G_SPOT.x, "y": 0, "z": G_SPOT.z, "r": 2.6 })
	root = Spatial.new(); main.add_child(root)
	garden = Garden.new().build(main, MC)

func L(x, y, z):
	return MC + Vector3(x, y, z)

# ---------- interaction ----------
func label(_id = "garden"):
	return "Pay respects · XXXTentacion" if g_cd <= 0 else "Long live"

func pay_respects(_id = "garden"):
	if g_cd > 0: return
	g_cd = 70.0
	var P = main.player
	P.body_yaw = -PI / 2; P.cam_yaw = PI / 2
	P.emote("pray", 4.5)
	main.hud.banner("Long live", "Jahseh Dwayne Ricardo Onfroy · 1998–2018")
	main.sfx.play("chime", 0.3, 0.9)
	# the sky answers
	main.sky.summon(70.0, "garden", 5.5)
	G.S["flags"]["candles"] = int(G.S["flags"].get("candles", 0)) + 1
	main.story.post_feed("@" + str(G.S["name"]), "lit a candle at the memorial garden in Calder Park. long live X")
	G.save_game()

# for the sky: is the mausoleum close enough to be struck, and where
func target_near(r):
	var c = main.camera.global_transform.origin
	if Vector2(c.x - MC.x, c.z - MC.z).length() < r and G.REAL_T - last_strike["garden"] > 60.0: return "garden"
	return ""

func target_pos(_k):
	return L(1.86, 4.2, 0)

# ---------- materials ----------
func _glow_mat(mode, tint):
	var m = ShaderMaterial.new(); m.shader = glow_shader
	m.set_shader_param("mode", mode); m.set_shader_param("tint", tint); m.set_shader_param("alpha", 0.0)
	return m

func _add_mat(tex, col):
	var m = SpatialMaterial.new()
	m.flags_unshaded = true; m.flags_transparent = true; m.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	m.params_cull_mode = SpatialMaterial.CULL_DISABLED; m.flags_no_depth_test = false
	m.albedo_texture = tex; m.albedo_color = col
	m.vertex_color_use_as_albedo = true
	return m

func _billboard(tex, size, col):
	var q = QuadMesh.new(); q.size = Vector2(size, size)
	var m = _add_mat(tex, col); m.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED
	var mi = MeshInstance.new(); mi.mesh = q; mi.material_override = m; mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	return mi

# ---------- lightning tributes ----------
func lightning(k):
	last_strike[k] = G.REAL_T
	tributes += 1
	tree_flash = 1.0
	var hit = target_pos(k)
	var e = { "k": k, "t": 0.0, "nodes": [], "doves": [], "banner": false, "petals_on": false }
	e.bolt = _bolt(hit)
	e.nodes.append(e.bolt)
	var base = L(2.3, 0, 0)
	e.base = base
	# the impact: a white flash on the pediment and sparks falling off it
	var imp = OmniLight.new(); imp.omni_range = 14; imp.light_color = Color(0.85, 0.9, 1.0); imp.light_energy = 8.0; imp.translation = hit + Vector3(1.2, 0.5, 0)
	root.add_child(imp); e.nodes.append(imp); e.imp = imp
	var sp = _sparks(hit, Color(0.85, 0.92, 1.0), 60, 1.6, Vector3(0, -6, 0), 2.6)
	sp.one_shot = true; sp.explosiveness = 0.9
	e.nodes.append(sp)
	# the column of light from the sky
	var col = MeshInstance.new(); var cm = CylinderMesh.new(); cm.top_radius = 2.0; cm.bottom_radius = 0.8; cm.height = 46; cm.radial_segments = 24; cm.rings = 1
	col.mesh = cm; col.translation = base + Vector3(-0.2, 23, 0)
	e.col_mat = _glow_mat(3, Color(0.8, 0.88, 1.0)); col.material_override = e.col_mat
	root.add_child(col); e.nodes.append(col)
	# rays of light pouring out of the doorway
	e.ray_mat = _glow_mat(4, Color(1.0, 0.92, 0.75))
	var rays = _rays(); rays.material_override = e.ray_mat
	root.add_child(rays); e.nodes.append(rays)
	# the light: cold white, then warm
	var l = OmniLight.new(); l.omni_range = 12; l.light_color = Color(0.85, 0.9, 1.0); l.light_energy = 3.0; l.translation = base + Vector3(1.4, 3.0, 0)
	root.add_child(l); e.nodes.append(l); e.light = l
	# the figure appears inside the tomb, behind the doors
	e.figure = _figure(L(-0.5, 0.24, 0))
	e.nodes.append(e.figure.root)
	fx.append(e)
	main.sfx.play3d("thunder_near", hit, 1.0, 1.0, "Amb")
	main.sfx.play("thunder_near", 0.75, 0.95)
	_later(0.5, "heaven", 0.6)
	# the camera takes over when you are there to see it
	if G.MODE == "play" and main.player.pos.distance_to(MC) < 45 and not main.player.car:
		# step back onto the lawn, out of the doorway, and keep praying
		var P = main.player
		P.place(MC.x + 4.0, 0, MC.z + 3.0, atan2(2.5, 3.0))
		P.emote("pray", 14.0)
		main.cutscene.play(_shots())
	return e

func _shots():
	return [
		{ "dur": 2.0, "from": L(9.6, 0.9, -3.2), "to": L(8.8, 1.0, -2.7), "look": L(1.6, 2.7, 0), "look_to": L(1.6, 2.3, 0), "fov": 50 },
		{ "dur": 2.6, "from": L(6.6, 1.55, 1.3), "to": L(4.9, 1.45, 0.7), "look": L(1.2, 1.4, 0), "look_to": L(1.6, 1.4, 0), "fov": 46 },
		{ "dur": 3.8, "from": L(6.2, 0.6, -2.3), "to": L(6.0, 0.75, 1.3), "look": L(2.15, 1.8, 0), "look_to": L(2.15, 2.0, 0), "fov": 50, "title": "Long live", "sub": "Jahseh Dwayne Ricardo Onfroy · 1998–2018" },
		{ "dur": 4.2, "from": L(8.0, 1.2, 0.9), "to": L(7.4, 0.9, 0.6), "look": L(2.2, 2.6, 0), "look_to": L(2.2, 9.5, 0), "fov": 54 },
	]

func _later(delay, nm, vol):
	yield(get_tree().create_timer(delay), "timeout")
	main.sfx.play(nm, vol)

func _sparks(at, col, amount, life, grav, vel):
	var sp = CPUParticles.new()
	var q = QuadMesh.new(); q.size = Vector2(0.1, 0.1)
	var m = _add_mat(garden._t("glow", false), col); m.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED
	q.material = m; sp.mesh = q
	sp.amount = amount; sp.lifetime = life; sp.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 0.3
	sp.direction = Vector3(0, 1, 0); sp.spread = 180; sp.initial_velocity = vel; sp.initial_velocity_random = 0.6; sp.gravity = grav
	sp.scale_amount = 1.0; sp.scale_amount_random = 0.6
	var ramp = Gradient.new(); ramp.set_color(0, Color(1, 1, 1, 1)); ramp.set_color(1, Color(1, 1, 1, 0)); sp.color_ramp = ramp
	sp.translation = at; sp.emitting = true
	root.add_child(sp)
	return sp

# rays: tapered sheets fanning out of the doorway onto the step and the lawn
func _rays():
	var b = MeshBuild.new()
	b.mat("r", null)
	var o = L(1.42, 1.25, 0)
	for k in range(7):
		var yaw = (k - 3) * 0.16
		var pitch = -0.14 - 0.05 * abs(k - 3)
		var d = Vector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch))
		var side = d.cross(Vector3.UP).normalized()
		var up = side.cross(d).normalized()
		var Lr = 6.5
		var w0 = 0.35
		var w1 = 1.6
		for ax in [side, up]:
			var a = o - ax * w0
			var bb = o + ax * w0
			var c = o + d * Lr + ax * w1
			var e = o + d * Lr - ax * w1
			b.quad("r", a, bb, c, e, d.cross(ax).normalized(), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	var mi = MeshInstance.new()
	mi.mesh = b.sts["r"].commit()
	mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	return mi

# the bolt: a jagged line of camera-facing quads from the clouds to the pediment, with branches
func _bolt(hit):
	var cam = main.camera.global_transform.origin
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top = hit + Vector3(rand_range(-10, 10), 80, rand_range(-10, 10))
	var pts = [top]
	var n = 30
	for i in range(1, n):
		var u = float(i) / n
		var p = top.linear_interpolate(hit, u)
		var j = 2.4 * (1.0 - u * 0.85)
		pts.append(p + Vector3(rand_range(-j, j), rand_range(-0.8, 0.8), rand_range(-j, j)))
	pts.append(hit)
	_strip(st, pts, 0.16, cam)
	for b in range(4):
		var i0 = int(rand_range(3, n - 8))
		var bp = [pts[i0]]
		var dirv = Vector3(rand_range(-1, 1), -1.1, rand_range(-1, 1)).normalized()
		for k in range(8):
			bp.append(bp[-1] + dirv * rand_range(1.4, 2.8) + Vector3(rand_range(-0.9, 0.9), 0, rand_range(-0.9, 0.9)))
		_strip(st, bp, 0.07, cam)
	var mi = MeshInstance.new(); mi.mesh = st.commit()
	var m = SpatialMaterial.new(); m.flags_unshaded = true; m.flags_transparent = true; m.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	m.params_cull_mode = SpatialMaterial.CULL_DISABLED; m.albedo_color = Color(0.9, 0.94, 1.0, 1.0)
	m.vertex_color_use_as_albedo = true
	mi.material_override = m; mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi

func _strip(st, pts, w, cam):
	# a bright core, then a soft glow that fades to nothing at its edges
	for i in range(pts.size() - 1):
		var a = pts[i]
		var b = pts[i + 1]
		var dir = (b - a).cross(cam - a).normalized()
		var side = dir * w
		var c = Color(0.95, 0.97, 1.0, 1.0)
		for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
			st.add_color(c); st.add_vertex(v)
		var g = dir * w * 8.0
		var cg = Color(0.6, 0.7, 1.0, 0.35)
		var c0 = Color(0.6, 0.7, 1.0, 0.0)
		for half in [-1, 1]:
			var ea = a + g * half
			var eb = b + g * half
			for pv in [[a, cg], [ea, c0], [eb, c0], [a, cg], [eb, c0], [b, cg]]:
				st.add_color(pv[1]); st.add_vertex(pv[0])

# a figure of light: a glowing silhouette with an aura, feathered wings, a golden halo and
# sparks of light circling up around it
func _figure(base):
	var f = {}
	f.root = Spatial.new(); f.root.translation = base
	root.add_child(f.root)
	f.h = load("res://scripts/Human.gd").new().build({})
	f.h.rotation.y = PI / 2
	f.root.add_child(f.h)
	f.body = _glow_mat(0, Color(0.88, 0.94, 1.0))
	_override(f.h, f.body)
	var gt = garden._t("glow", false)
	f.aura = _billboard(gt, 3.4, Color(0.75, 0.85, 1.0, 0.0)); f.aura.translation = Vector3(0, 1.2, 0); f.root.add_child(f.aura)
	f.core = _billboard(gt, 1.3, Color(1.0, 0.97, 0.9, 0.0)); f.core.translation = Vector3(0.1, 1.25, 0); f.root.add_child(f.core)
	# wings: feathered quads hinged at the shoulders, folded behind the back until they open
	f.wing_mat = _add_mat(garden._t("wing", false), Color(1.0, 0.97, 0.9, 0.0))
	f.wings = []
	var ws = 2.3
	for s in [-1, 1]:
		var piv = Spatial.new(); piv.translation = Vector3(-0.14, 1.45, s * 0.1)
		f.root.add_child(piv)
		var q = QuadMesh.new(); q.size = Vector2(ws, ws)
		var w = MeshInstance.new(); w.mesh = q; w.material_override = f.wing_mat; w.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		# the texture's root (left edge, a third down) sits on the shoulder, the tips spread outward
		w.transform = Transform(Basis(Vector3(0, 1, 0), -PI / 2 if s > 0 else PI / 2), Vector3(0, -0.18 * ws, s * ws / 2))
		piv.add_child(w)
		f.wings.append([piv, s])
	# halo: a torus of gold light with a soft glow
	var hb = MeshBuild.new()
	hb.mat("h", null)
	hb.torus("h", Transform(Basis(Vector3(1, 0, 0), 0.25), Vector3()), 0.17, 0.016, 32, 8)
	f.halo = MeshInstance.new(); f.halo.mesh = hb.sts["h"].commit()
	f.halo_mat = _add_mat(null, Color(1.0, 0.85, 0.45, 0.0)); f.halo.material_override = f.halo_mat
	f.halo.translation = Vector3(0, 1.98, 0); f.root.add_child(f.halo)
	f.halo_glow = _billboard(gt, 0.7, Color(1.0, 0.85, 0.45, 0.0)); f.halo_glow.translation = Vector3(0, 1.98, 0); f.root.add_child(f.halo_glow)
	# motes of light spiralling up around the figure
	f.motes = CPUParticles.new()
	var mq = QuadMesh.new(); mq.size = Vector2(0.09, 0.09)
	var mm = _add_mat(gt, Color(1.0, 0.92, 0.7, 1.0)); mm.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED
	mq.material = mm; f.motes.mesh = mq
	f.motes.amount = 120; f.motes.lifetime = 3.0; f.motes.local_coords = true
	f.motes.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE; f.motes.emission_sphere_radius = 0.75
	f.motes.direction = Vector3(0, 1, 0); f.motes.spread = 25; f.motes.initial_velocity = 0.5; f.motes.gravity = Vector3(0, 0.6, 0)
	f.motes.tangential_accel = 2.5; f.motes.radial_accel = -0.3
	var ramp = Gradient.new(); ramp.set_color(0, Color(1, 1, 1, 0)); ramp.add_point(0.2, Color(1, 1, 1, 1)); ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	f.motes.color_ramp = ramp
	f.motes.translation = Vector3(0, 0.6, 0); f.motes.emitting = false
	f.root.add_child(f.motes)
	return f

func _override(n, m):
	if n is MeshInstance: n.material_override = m
	for c in n.get_children(): _override(c, m)

# rose petals swirling up around the figure as it rises
func _petals(at):
	var p = CPUParticles.new()
	var q = QuadMesh.new(); q.size = Vector2(0.07, 0.07)
	var m = SpatialMaterial.new(); m.albedo_texture = garden._t("petal", false); m.albedo_color = Color(0.7, 0.03, 0.08)
	m.params_use_alpha_scissor = true; m.params_alpha_scissor_threshold = 0.4; m.params_cull_mode = SpatialMaterial.CULL_DISABLED
	m.params_billboard_mode = SpatialMaterial.BILLBOARD_PARTICLES
	q.material = m; p.mesh = q
	p.amount = 140; p.lifetime = 4.0
	p.emission_shape = CPUParticles.EMISSION_SHAPE_BOX; p.emission_box_extents = Vector3(0.9, 0.6, 2.4)
	p.direction = Vector3(0, 1, 0); p.spread = 40; p.initial_velocity = 1.0; p.gravity = Vector3(0, 0.7, 0)
	p.tangential_accel = 3.0; p.angular_velocity = 240; p.angular_velocity_random = 1.0; p.angle_random = 1.0
	p.scale_amount = 1.0; p.scale_amount_random = 0.5
	p.translation = at; p.emitting = true
	root.add_child(p)
	return p

func _dove(at):
	var d = Spatial.new(); d.translation = at
	var white = SpatialMaterial.new(); white.albedo_color = Color(0.97, 0.97, 1.0); white.roughness = 0.6
	white.emission_enabled = true; white.emission = Color(0.9, 0.92, 1.0); white.emission_energy = 0.3
	var b = MeshBuild.new()
	b.mat("w", white)
	# body, head, beak and a fanned tail
	b.lathe("w", Transform(Basis(Vector3(1, 0, 0), PI / 2), Vector3()), [[0.0, -0.13], [0.04, -0.1], [0.06, -0.03], [0.055, 0.04], [0.035, 0.1], [0.0, 0.14]], 8)
	b.lathe("w", Transform(Basis(), Vector3(0, 0.05, -0.15)), [[0.0, -0.035], [0.032, -0.02], [0.034, 0.01], [0.02, 0.03], [0.0, 0.036]], 8)
	b.tri("w", Vector3(-0.07, 0.01, 0.12), Vector3(0.07, 0.01, 0.12), Vector3(0, 0.0, 0.26), Vector3.UP)
	var body = MeshInstance.new(); body.mesh = b.sts["w"].commit(); body.material_override = white
	d.add_child(body)
	var wm = SpatialMaterial.new(); wm.albedo_texture = garden._t("wing", false); wm.albedo_color = Color(1, 1, 1)
	wm.params_use_alpha_scissor = true; wm.params_alpha_scissor_threshold = 0.3; wm.params_cull_mode = SpatialMaterial.CULL_DISABLED
	wm.emission_enabled = true; wm.emission = Color(0.8, 0.82, 0.9); wm.emission_energy = 0.25
	var wings = []
	for s in [-1, 1]:
		var piv = Spatial.new(); piv.translation = Vector3(s * 0.04, 0.03, -0.02); d.add_child(piv)
		var q = QuadMesh.new(); q.size = Vector2(0.4, 0.4)
		var w = MeshInstance.new(); w.mesh = q; w.material_override = wm
		# lie flat, root at the body, tip outward
		w.transform = Transform(Basis(Vector3(1, 0, 0), -PI / 2).rotated(Vector3.UP, 0.0 if s > 0 else PI), Vector3(s * 0.2, 0, 0.06))
		if s < 0: w.scale = Vector3(1, 1, 1)
		piv.add_child(w); wings.append([piv, s])
	root.add_child(d)
	var a = rand_range(0, TAU)
	return { "n": d, "w": wings, "a": a, "r": rand_range(1.2, 2.6), "c": at, "ph": randf() * 6, "t": 0.0, "up": rand_range(1.6, 2.6) }

func _release_doves(e, at, n):
	for k in range(n):
		e.doves.append(_dove(at + Vector3(rand_range(-0.4, 0.4), rand_range(0, 0.8), rand_range(-0.4, 0.4))))
	main.sfx.play("wings", 0.55)

func _run_fx(dt):
	var i = fx.size() - 1
	while i >= 0:
		var e = fx[i]
		e.t += dt
		var t = e.t
		if is_instance_valid(e.bolt):
			e.bolt.visible = t < 0.6 and not (t > 0.24 and t < 0.29)
		e.imp.light_energy = 8.0 * exp(-t * 9.0)
		var ca = clamp(t / 0.6, 0.0, 1.0) * clamp((11.0 - t) / 2.5, 0.0, 1.0)
		e.col_mat.set_shader_param("alpha", ca * 0.5)
		e.col_mat.set_shader_param("t", G.REAL_T)
		e.light.light_energy = (3.5 * exp(-t * 5.0) + 0.7 * ca) if t < 12 else 0.0
		e.light.light_color = Color(0.85, 0.9, 1.0).linear_interpolate(Color(1.0, 0.84, 0.6), clamp(t / 3.0, 0.0, 1.0))
		_run_figure(e, dt, t)
		if not e.banner and t > 1.6:
			e.banner = true
			if main.camera.global_transform.origin.distance_to(target_pos(e.k)) < 90 and G.MODE == "play":
				main.hud.banner("Long live XXXTentacion", "Jahseh Dwayne Ricardo Onfroy · 1998–2018")
		for d in e.doves:
			d.t += dt
			# circle the tomb once, climbing, then fly off into the storm
			d.a += dt * (1.6 - min(1.2, d.t * 0.2))
			d.r += dt * 0.9
			var np = d.c + Vector3(cos(d.a) * d.r, d.t * d.up, sin(d.a) * d.r)
			var vel = np - d.n.translation
			d.n.translation = np
			if vel.length() > 0.001 and abs(vel.normalized().y) < 0.98: d.n.look_at(np + vel.normalized(), Vector3.UP)
			for w in d.w:
				w[0].rotation.z = w[1] * (0.2 + sin(G.REAL_T * 16.0 + d.ph) * 0.8)
		if t > 17.0:
			for n in e.nodes:
				if is_instance_valid(n): n.queue_free()
			for d in e.doves: d.n.queue_free()
			fx.remove(i)
		i -= 1

func _ease(x):
	return x * x * (3.0 - 2.0 * x)

func _run_figure(e, dt, t):
	var f = e.figure
	var g = garden
	# the doors swing open, light pours out, the figure appears inside, comes out to the
	# step, opens its wings, hovers with open arms, then ascends and turns into doves
	var dopen = _ease(clamp((t - 0.25) / 1.4, 0.0, 1.0)) * (1.0 - _ease(clamp((t - 13.5) / 1.6, 0.0, 1.0)))
	for d in g.doors:
		d[0].rotation.y = d[1] * 1.75 * dopen
	g.in_light.visible = dopen > 0.01
	g.in_light.light_energy = 0.45 * dopen
	g.plate_mat.emission_energy = 0.08 + 0.6 * dopen
	e.ray_mat.set_shader_param("alpha", dopen * clamp((11.5 - t) / 2.0, 0.0, 1.0) * 0.28)
	e.ray_mat.set_shader_param("t", G.REAL_T)
	var a = clamp((t - 0.9) / 1.4, 0.0, 1.0) * clamp((11.0 - t) / 1.5, 0.0, 1.0)
	var walk = _ease(clamp((t - 1.8) / 2.6, 0.0, 1.0))
	var lift = max(0.0, t - 8.2)
	f.root.translation = MC + Vector3(lerp(-0.5, 2.15, walk), lerp(0.25, 0.18, walk) + lift * lift * 0.42 + sin(t * 1.4) * 0.04 * walk, 0)
	f.body.set_shader_param("alpha", a * 0.55)
	f.body.set_shader_param("t", G.REAL_T)
	f.aura.material_override.albedo_color.a = a * 0.2
	f.core.material_override.albedo_color.a = a * 0.22 * (0.85 + 0.15 * sin(t * 3.0))
	var wa = clamp((t - 4.2) / 1.6, 0.0, 1.0)
	f.wing_mat.albedo_color.a = a * _ease(wa) * 0.5
	var ha = a * clamp((t - 2.2) / 1.0, 0.0, 1.0)
	f.halo_mat.albedo_color.a = ha
	f.halo_glow.material_override.albedo_color.a = ha * 0.6
	f.halo.rotation.y = t * 0.6
	for w in f.wings:
		# folded back along the body, then spread wide with a slow beat
		var fold = lerp(1.3, 0.12, _ease(wa))
		var beat = sin(t * 1.7) * 0.12 * wa + (sin(t * 5.0) * 0.25 if lift > 0 else 0.0)
		w[0].rotation = Vector3(w[1] * (-0.15 - beat), -w[1] * fold, 0)
	f.h.animate(dt, { "speed": 0.0, "emote": "ascend" if t > 4.0 else "", "et": max(0.0, t - 4.0) })
	f.motes.emitting = t > 2.0 and t < 10.5
	if t > 7.6 and not e.petals_on:
		e.petals_on = true
		var pp = _petals(L(2.3, 0.6, 0))
		e.nodes.append(pp)
		e.petals = pp
	if e.petals_on and t > 11.0: e.petals.emitting = false
	if t > 9.6 and e.doves.size() == 0:
		_release_doves(e, f.root.translation + Vector3(0, 1.3, 0), 9)

func update(dt):
	g_cd = max(0.0, g_cd - dt)
	_run_fx(dt)
	var g = garden
	var cam = main.camera.global_transform.origin
	var dg = Vector2(cam.x - MC.x, cam.z - MC.z).length()
	var night = main.DN.night
	var near = dg < 90
	if dg < 120:
		for f in g.flames:
			var k = 1.0 + sin(G.REAL_T * 13 + f[1]) * 0.18 + sin(G.REAL_T * 31 + f[1] * 2) * 0.1
			f[0].scale = Vector3(1, k, 1)
	# lights only at night and only near (old GPUs pay for every light)
	var lit = night > 0.15 and dg < 75
	for s in g.spots:
		s.visible = lit
		s.light_energy = 1.6 * night if lit else 0.0
	g.tree_spot.visible = lit
	g.tree_spot.light_energy = (1.6 + 0.4 * sin(G.REAL_T * 0.8)) * night + tree_flash * 3.0 if lit else 0.0
	g.candle_light.visible = lit and dg < 35
	g.candle_light.light_energy = (0.8 + sin(G.REAL_T * 17) * 0.08 + sin(G.REAL_T * 7.3) * 0.06) * night
	var lanterns = lerp(0.35, 1.0, night)
	g.lantern_mat.albedo_color = Color(1.0 * lanterns, 0.8 * lanterns, 0.5 * lanterns)
	var fl = 0.85 + 0.15 * sin(G.REAL_T * 9.0)
	g.eternal_mat.albedo_color = Color(1.0 * fl, 0.25 * fl, 0.12 * fl)
	# the Poison Tree: veins and fruit pulse at night, and flare when lightning strikes
	tree_flash = max(0.0, tree_flash - dt * 0.35)
	if near:
		var pulse = 0.5 + 0.5 * sin(G.REAL_T * 1.3)
		g.bark_mat.emission_energy = lerp(0.15, 0.9 + 0.5 * pulse, night) + tree_flash * 4.0
		g.fruit_mat.emission_energy = lerp(0.25, 0.9 + 0.6 * pulse, night) + tree_flash * 3.0
		g.mist.emitting = night > 0.3 and dg < 60
	# people walking past stop for a moment to pray
	if G.MODE == "play" and dg < 40:
		for p in main.peds.PEDS:
			if p.state != "walk" or p.emote_left > 0: continue
			if Vector2(p.pos.x - G_SPOT.x, p.pos.z - G_SPOT.z).length() < 4.5 and randf() < dt * 0.25:
				p.yaw = atan2(MC.x - p.pos.x, MC.z - p.pos.z)
				p.emote = "pray" if randf() < 0.6 else "salute"; p.emote_t = 0; p.emote_left = 3.0
