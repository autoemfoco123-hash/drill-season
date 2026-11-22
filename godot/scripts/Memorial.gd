extends Node
# The memorial garden in Calder Park, west of the pavilion: a replica of XXXTentacion's
# mausoleum, built from a photo his family shared: grey granite, a pediment engraved
# "XXXTENTACION / JAHSEH D. ONFROY", two columns, bronze double doors with scrollwork, a
# granite step, red mulch, a lawn, palms, red rose cascades on easels and black and silver
# roses, candles on the step. Inside, a crypt plate with his name and dates.
# Paying respects lights a candle and the sky answers: a storm rolls in, lightning strikes the
# pediment, the doors swing open, light pours out and a figure of light appears inside, comes
# out to the step, opens angel wings under a halo, then rises and turns into doves.
# (A figure of light, not a likeness: no face, no body of a real person.)
# During real thundersnow, lightning can strike it on its own when you are near.
# Textures are painted by tools/make-memorial.py; sounds by tools/make-sfx.py.

var main
var root
var flames = []
var g_light = null
var in_light = null
var doors = []
var plate_mat = null
var g_cd = 0.0
var fx = []                    # running tributes
var last_strike = { "garden": -999.0 }
var glow_shader = null
var tributes = 0

const MC = Vector3(-81.2, 0, 47.0)          # the mausoleum (faces +x, the gate)
const G_SPOT = Vector3(-78.4, 0, 47.0)

func setup(m):
	main = m
	glow_shader = load("res://scripts/glow.shader")
	G.D["LOC"]["garden"] = { "x": MC.x + 3.0, "z": MC.z, "name": "Memorial garden" }
	G.D["INTERACT"].append({ "id": "garden", "x": G_SPOT.x, "y": 0, "z": G_SPOT.z, "r": 2.6 })
	root = Spatial.new(); main.add_child(root)
	_build_garden()

# ---------- the garden: a replica of the mausoleum, from the family's photo ----------
# local frame: the mausoleum faces +x (the gate), its front wall at x = 1.5, 3 m wide (z)
func _L(x, y, z):
	return MC + Vector3(x, y, z)

func _build_garden():
	var hedge = _mat(Color(0.09, 0.2, 0.11), 1.0)
	var snow = _mat(Color(0.93, 0.95, 0.98), 0.9)
	var x0 = -84.6
	var x1 = -71.6
	var z0 = 41.5
	var z1 = 52.5
	var segs = [[x0, z0 - 0.3, x1, z0 + 0.3], [x0, z1 - 0.3, x1, z1 + 0.3], [x0 - 0.3, z0, x0 + 0.3, z1],
		[x1 - 0.3, z0, x1 + 0.3, MC.z - 1.0], [x1 - 0.3, MC.z + 1.0, x1 + 0.3, z1]]
	for s in segs:
		var c = Vector3((s[0] + s[2]) / 2, 0, (s[1] + s[3]) / 2)
		var sz = Vector3(s[2] - s[0], 0.78, s[3] - s[1])
		_box(sz.x, sz.y, sz.z, c + Vector3(0, sz.y / 2, 0), hedge)
		_box(sz.x + 0.06, 0.08, sz.z + 0.06, c + Vector3(0, sz.y + 0.03, 0), snow)
		W.add_box(s[0], 0, s[1], s[2], 0.8, s[3], "cover")
	# the grounds: a green lawn, a bed of red mulch around the tomb, a stone path to the gate
	_box(x1 - (MC.x + 4.0), 0.03, z1 - z0 - 0.6, Vector3((x1 + MC.x + 4.0) / 2, 0.015, MC.z), _mat(Color(0.3, 0.5, 0.2), 1.0))
	_box(6.2, 0.05, 7.0, _L(1.0, 0.025, 0), _mat(Color(0.43, 0.13, 0.07), 1.0))
	var path = _mat(Color(0.55, 0.55, 0.57), 0.85)
	for i in range(6):
		_box(0.62, 0.06, 1.3, Vector3(x1 - 0.6 - i * 0.85, 0.03, MC.z), path)
	# the tomb
	var gt = load("res://assets/art/granite.png")
	gt.flags = Texture.FLAG_REPEAT | Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS
	var gr = SpatialMaterial.new(); gr.albedo_texture = gt; gr.uv1_triplanar = true; gr.uv1_scale = Vector3(0.7, 0.7, 0.7)
	gr.roughness = 0.45; gr.albedo_color = Color(0.6, 0.6, 0.62); gr.params_cull_mode = SpatialMaterial.CULL_DISABLED
	var dark = gr.duplicate(); dark.albedo_color = Color(0.3, 0.3, 0.32)
	_box(3.5, 0.22, 3.5, _L(0.0, 0.11, 0), gr)                 # plinth
	_box(0.5, 0.12, 2.0, _L(2.0, 0.06, 0), gr)                 # the front step
	_box(0.25, 2.38, 3.0, _L(-1.48, 1.41, 0), gr)              # back wall
	for sd in [-1, 1]:
		_box(3.1, 2.38, 0.25, _L(0.0, 1.41, sd * 1.375), gr)   # side walls
		_box(0.25, 2.38, 0.85, _L(1.375, 1.41, sd * 1.075), gr) # front, beside the door
	_box(0.25, 0.33, 1.3, _L(1.375, 2.435, 0), gr)             # lintel
	_box(2.75, 0.04, 2.5, _L(0.0, 0.24, 0), dark)              # inside floor
	_box(3.3, 0.14, 3.2, _L(0.0, 2.67, 0), gr)                 # ceiling slab
	_box(0.5, 0.36, 3.24, _L(1.5, 2.78, 0), gr)                # frieze band over the door
	_box(3.7, 0.1, 3.56, _L(0.05, 3.01, 0), gr)                # cornice
	for sd in [-1, 1]:
		_cyl(0.135, 2.2, _L(1.66, 1.42, sd * 1.36), gr, 16)
		_box(0.36, 0.12, 0.36, _L(1.66, 0.28, sd * 1.36), gr)
		_box(0.38, 0.16, 0.38, _L(1.66, 2.58, sd * 1.36), gr)
	# the pediment: roof prism, a raised frame, and the engraved tympanum
	var rise = 0.95
	var hw = 1.78
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xf = 1.84
	var xb = -1.75
	var yb = 3.06
	var A = [Vector3(xf, yb, hw), Vector3(xf, yb, -hw), Vector3(xf, yb + rise, 0)]
	var B = [Vector3(xb, yb, hw), Vector3(xb, yb, -hw), Vector3(xb, yb + rise, 0)]
	_tri(st, A[0], A[1], A[2]); _tri(st, B[0], B[2], B[1])
	_quad(st, A[0], A[2], B[2], B[0]); _quad(st, A[2], A[1], B[1], B[2]); _quad(st, A[1], A[0], B[0], B[1])
	var roof = MeshInstance.new(); roof.mesh = st.commit(); roof.material_override = gr; roof.translation = MC
	root.add_child(roof)
	var ang = atan2(rise, hw)
	var L = sqrt(hw * hw + rise * rise) + 0.12
	for sd in [-1, 1]:
		var fr = _box(0.12, 0.12, L, Vector3(), gr)
		fr.transform = Transform(Basis(Vector3(1, 0, 0), sd * ang), _L(xf + 0.05, yb + rise / 2 + 0.03, sd * hw / 2))
	_box(0.14, 0.1, hw * 2 + 0.1, _L(xf + 0.05, yb + 0.03, 0), gr)
	var pt = load("res://assets/art/pediment.png")
	var pm = SpatialMaterial.new(); pm.albedo_texture = pt; pm.roughness = 0.5; pm.params_cull_mode = SpatialMaterial.CULL_DISABLED
	var ts = SurfaceTool.new(); ts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var thw = hw - 0.14
	var trs = rise - 0.12
	ts.add_normal(Vector3(1, 0, 0)); ts.add_uv(Vector2(0, 1)); ts.add_vertex(Vector3(xf + 0.012, yb + 0.06, thw))
	ts.add_normal(Vector3(1, 0, 0)); ts.add_uv(Vector2(0.5, 0)); ts.add_vertex(Vector3(xf + 0.012, yb + 0.06 + trs, 0))
	ts.add_normal(Vector3(1, 0, 0)); ts.add_uv(Vector2(1, 1)); ts.add_vertex(Vector3(xf + 0.012, yb + 0.06, -thw))
	var tym = MeshInstance.new(); tym.mesh = ts.commit(); tym.material_override = pm; tym.translation = MC
	root.add_child(tym)
	# the bronze doors (they open when the light comes)
	var bronze = _mat(Color(0.12, 0.09, 0.07), 0.4); bronze.metallic = 0.6
	doors = []
	for sd in [1, -1]:
		var piv = Spatial.new(); piv.translation = _L(1.42, 0.24, sd * 0.65)
		root.add_child(piv)
		_box(0.05, 2.04, 0.64, Vector3(0, 1.02, -sd * 0.32), bronze, piv)
		var dm = SpatialMaterial.new(); dm.albedo_texture = load("res://assets/art/door_l.png" if sd > 0 else "res://assets/art/door_r.png")
		dm.roughness = 0.3; dm.metallic = 0.35
		var q = QuadMesh.new(); q.size = Vector2(0.64, 2.04)
		var mi = MeshInstance.new(); mi.mesh = q; mi.material_override = dm
		mi.transform = Transform(Basis(Vector3(0, 1, 0), PI / 2), Vector3(0.03, 1.02, -sd * 0.32))
		piv.add_child(mi)
		doors.append([piv, sd])
	# the crypt plate on the back wall inside
	var ht = load("res://assets/art/headstone.png")
	plate_mat = SpatialMaterial.new(); plate_mat.albedo_texture = ht; plate_mat.roughness = 0.2
	plate_mat.emission_enabled = true; plate_mat.emission_texture = ht; plate_mat.emission = Color(1, 1, 1); plate_mat.emission_energy = 0.1
	var pq = QuadMesh.new(); pq.size = Vector2(1.3, 1.0)
	var pmi = MeshInstance.new(); pmi.mesh = pq; pmi.material_override = plate_mat
	pmi.transform = Transform(Basis(Vector3(0, 1, 0), PI / 2), _L(-1.34, 1.35, 0))
	root.add_child(pmi)
	W.add_box(MC.x - 1.8, 0, MC.z - 1.8, MC.x + 1.85, 4.0, MC.z + 1.8, "solid")
	var crng = RandomNumberGenerator.new(); crng.seed = 2018
	_candles(crng, 10 + int(min(24, G.S.get("flags", {}).get("candles", 0))), _L(2.55, 0, 0), Vector2(0.18, 1.0))
	_flowers()
	_palms()
	# lanterns at the gate
	var post = _mat(Color(0.05, 0.05, 0.06), 0.4); post.metallic = 0.5
	var lamp_em = SpatialMaterial.new(); lamp_em.flags_unshaded = true; lamp_em.albedo_color = Color(1, 0.85, 0.55)
	for z in [MC.z - 1.3, MC.z + 1.3]:
		_cyl(0.05, 1.5, Vector3(x1 + 0.05, 0.75, z), post)
		_box(0.22, 0.28, 0.22, Vector3(x1 + 0.05, 1.62, z), lamp_em)
		_box(0.28, 0.04, 0.28, Vector3(x1 + 0.05, 1.78, z), post)
	# a bench on the lawn, facing the tomb
	var wood = _mat(Color(0.32, 0.2, 0.12), 0.8)
	var bz = z1 - 1.4
	_box(0.45, 0.06, 1.6, Vector3(MC.x + 6.6, 0.46, bz), wood)
	_box(0.06, 0.4, 1.6, Vector3(MC.x + 6.85, 0.72, bz), wood)
	for dz in [-0.7, 0.7]:
		_box(0.4, 0.46, 0.06, Vector3(MC.x + 6.6, 0.23, bz + dz), post)
	g_light = OmniLight.new(); g_light.omni_range = 9; g_light.light_color = Color(1, 0.84, 0.62); g_light.light_energy = 0; g_light.visible = false
	g_light.translation = _L(4.5, 3.4, 1.5)
	root.add_child(g_light)
	in_light = OmniLight.new(); in_light.omni_range = 6; in_light.light_color = Color(1, 0.92, 0.75); in_light.light_energy = 0; in_light.visible = false
	in_light.translation = _L(0.2, 1.6, 0)
	root.add_child(in_light)

func _tri(st, a, b, c):
	var n = (b - a).cross(c - a).normalized()
	for v in [a, b, c]:
		st.add_normal(n); st.add_uv(Vector2(v.z, v.y)); st.add_vertex(v)

func _quad(st, a, b, c, d):
	_tri(st, a, b, c); _tri(st, a, c, d)

# the flowers in the photo: big cascades of red roses on easels to the right of the door,
# black and silver roses on the left and at the front, a small black-and-white bouquet in a pot
func _flowers():
	var rose = SphereMesh.new(); rose.radius = 0.055; rose.height = 0.09; rose.radial_segments = 8; rose.rings = 4
	var leaf = SphereMesh.new(); leaf.radius = 0.06; leaf.height = 0.03; leaf.radial_segments = 6; leaf.rings = 2
	var R = []
	var Lv = []
	var rng = RandomNumberGenerator.new(); rng.seed = 123
	var red = Color(0.72, 0.03, 0.08)
	var blk = Color(0.05, 0.045, 0.05)
	var wht = Color(0.92, 0.92, 0.94)
	var slv = Color(0.36, 0.37, 0.4)
	var grn = Color(0.16, 0.34, 0.15)
	# [centre (local), radii, roses, mix of colours, leaf colour, easel?]
	var sprays = [
		[Vector3(2.05, 1.45, -0.8), Vector3(0.22, 0.62, 0.42), 130, [[red, 1.0]], grn, true],
		[Vector3(1.55, 1.55, -2.35), Vector3(0.3, 0.72, 0.62), 170, [[red, 1.0]], grn, true],
		[Vector3(2.0, 1.25, 1.8), Vector3(0.25, 0.7, 0.4), 95, [[blk, 0.88], [wht, 0.12]], slv, true],
		[Vector3(2.7, 0.45, -1.75), Vector3(0.35, 0.4, 0.5), 60, [[blk, 0.86], [wht, 0.14]], slv, false],
		[Vector3(2.15, 0.55, 0.95), Vector3(0.18, 0.28, 0.2), 30, [[blk, 0.6], [wht, 0.4]], slv, false],
		[Vector3(1.75, 0.35, 2.6), Vector3(0.3, 0.32, 0.35), 34, [[blk, 0.85], [wht, 0.15]], slv, false]]
	var stand = _mat(Color(0.08, 0.08, 0.09), 0.5)
	for s in sprays:
		var c = s[0]
		for i in range(s[2]):
			var u = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			if u.length() > 1: u = u.normalized() * rng.randf()
			# a teardrop: wider at the top, cascading down
			var wz = 0.55 + 0.45 * (u.y + 1) / 2
			var p = c + Vector3(u.x * s[1].x, u.y * s[1].y, u.z * s[1].z * wz)
			var pick = rng.randf()
			var col = s[3][0][0]
			var acc = 0.0
			for cc in s[3]:
				acc += cc[1]
				if pick <= acc:
					col = cc[0]; break
			var b = Basis(Vector3(rng.randf_range(-1, 1), 1, rng.randf_range(-1, 1)).normalized(), rng.randf() * TAU)
			R.append([Transform(b, p), col.lightened(rng.randf_range(-0.05, 0.12))])
		for i in range(int(s[2] * 0.7)):
			var u2 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.8, 1.15)
			var p2 = c + Vector3(u2.x * s[1].x, u2.y * s[1].y, u2.z * s[1].z)
			var b2 = Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf() * TAU).scaled(Vector3(1.6, 1, 0.8))
			Lv.append([Transform(b2, p2), s[4].lightened(rng.randf_range(-0.1, 0.1))])
		if s[5]:
			for lg in [[-0.25, -0.2], [-0.25, 0.2], [0.22, 0.0]]:
				var top = c + Vector3(0, -s[1].y * 0.4, 0)
				var foot = Vector3(c.x + lg[0], 0, c.z + lg[1])
				var mid = (top + foot) / 2
				var leg = _box(0.025, top.distance_to(foot), 0.025, Vector3(), stand)
				var yv = (top - foot).normalized()
				var xv = yv.cross(Vector3(0, 0, 1)).normalized()
				if xv.length() < 0.1: xv = Vector3(1, 0, 0)
				leg.transform = Transform(Basis(xv, yv, xv.cross(yv)), MC + mid)
	# a white pot under the small bouquet
	_cyl(0.13, 0.28, _L(2.15, 0.14, 0.95), _mat(Color(0.9, 0.9, 0.9), 0.3))
	_multi(rose, R)
	_multi(leaf, Lv)

func _multi(mesh, items):
	var mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.color_format = MultiMesh.COLOR_8BIT
	mm.mesh = mesh; mm.instance_count = items.size()
	for i in range(items.size()):
		mm.set_instance_transform(i, items[i][0]); mm.set_instance_color(i, items[i][1])
	var mmi = MultiMeshInstance.new(); mmi.multimesh = mm; mmi.translation = MC
	var m = SpatialMaterial.new(); m.vertex_color_use_as_albedo = true; m.roughness = 0.65
	mmi.material_override = m; mmi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)

# the palms behind the tomb
func _palms():
	var trunk = _mat(Color(0.45, 0.4, 0.33), 1.0)
	var frond = _mat(Color(0.2, 0.42, 0.16), 0.8); frond.params_cull_mode = SpatialMaterial.CULL_DISABLED
	for pl in [[Vector3(-2.7, 0, -2.0), 6.4, 0.3], [Vector3(-2.4, 0, 2.5), 7.4, -0.25]]:
		var base = MC + pl[0]
		var h = pl[1]
		var top = base
		for i in range(9):
			var u = float(i) / 9.0
			var p = base + Vector3(sin(u * 1.4) * pl[2] * 1.5, u * h + h / 18.0, 0)
			_cyl(0.2 - u * 0.07, h / 9.0 + 0.05, p, trunk, 8)
			top = base + Vector3(sin(1.4) * pl[2] * 1.5, h, 0)
		for k in range(11):
			var a = k / 11.0 * TAU + pl[2]
			var d = Vector3(cos(a), 0, sin(a))
			var prev = top
			for seg in range(3):
				var droop = 0.25 + seg * 0.45
				var nxt = prev + d * 0.85 + Vector3(0, 0.35 - droop * 0.9, 0)
				var f = _box(0.9, 0.025, 0.42 - seg * 0.1, Vector3(), frond)
				var xv = (nxt - prev).normalized()
				var zv = xv.cross(Vector3.UP).normalized()
				f.transform = Transform(Basis(xv, zv.cross(xv), zv), (prev + nxt) / 2)
				prev = nxt
		W.add_box(base.x - 0.25, 0, base.z - 0.25, base.x + 0.25, 3.0, base.z + 0.25, "solid")

func _candles(rng, n, c, ext):
	var wax = _mat(Color(0.95, 0.92, 0.84), 0.6)
	var glass_r = _mat(Color(0.75, 0.12, 0.16), 0.2); glass_r.emission_enabled = true; glass_r.emission = Color(0.5, 0.08, 0.05); glass_r.emission_energy = 0.4
	var glass_b = glass_r.duplicate(); glass_b.albedo_color = Color(0.2, 0.35, 0.8); glass_b.emission = Color(0.1, 0.18, 0.5)
	var flame_m = SpatialMaterial.new(); flame_m.flags_unshaded = true; flame_m.albedo_color = Color(1, 0.75, 0.3)
	for i in range(n):
		var p = c + Vector3(rng.randf_range(-ext.x, ext.x), 0.0, rng.randf_range(-ext.y, ext.y))
		var tall = rng.randf_range(0.12, 0.3)
		var jar = rng.randf() < 0.6
		_cyl(0.055 if jar else 0.045, tall, p + Vector3(0, tall / 2 + 0.02, 0), (glass_r if rng.randf() < 0.6 else glass_b) if jar else wax)
		var f = MeshInstance.new(); var sm = SphereMesh.new(); sm.radius = 0.022; sm.height = 0.07; sm.radial_segments = 6; sm.rings = 3; f.mesh = sm
		f.material_override = flame_m; f.translation = p + Vector3(0, tall + 0.06, 0); f.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		root.add_child(f); flames.append([f, rng.randf() * 10])

func _mat(c, r):
	var m = SpatialMaterial.new(); m.albedo_color = c; m.roughness = r
	return m

func _box(sx, sy, sz, p, mat, parent = null):
	var mi = MeshInstance.new(); var cm = CubeMesh.new(); cm.size = Vector3(sx, sy, sz); mi.mesh = cm; mi.material_override = mat
	mi.translation = p; mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	(parent if parent else root).add_child(mi)
	return mi

func _cyl(r, h, p, mat, seg = 8):
	var mi = MeshInstance.new(); var cm = CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = seg; cm.rings = 1
	mi.mesh = cm; mi.material_override = mat; mi.translation = p; mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi

func _sphere(r, p, mat, parent = null):
	var mi = MeshInstance.new(); var sm = SphereMesh.new(); sm.radius = r; sm.height = r * 2; sm.radial_segments = 8; sm.rings = 4
	mi.mesh = sm; mi.material_override = mat; mi.translation = p; mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	(parent if parent else root).add_child(mi)
	return mi

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
	return MC + Vector3(1.85, 4.0, 0)

# ---------- lightning tributes ----------
func lightning(k):
	last_strike[k] = G.REAL_T
	tributes += 1
	var hit = target_pos(k)
	var e = { "k": k, "t": 0.0, "nodes": [], "doves": [], "banner": false }
	e.bolt = _bolt(hit)
	e.nodes.append(e.bolt)
	# the column of light from the sky
	var base = MC + Vector3(2.3, 0, 0)
	var col = MeshInstance.new(); var cm = CylinderMesh.new(); cm.top_radius = 1.8; cm.bottom_radius = 0.75; cm.height = 46; cm.radial_segments = 20; cm.rings = 1
	col.mesh = cm; col.translation = base + Vector3(0, 23, 0)
	e.col_mat = _glow_mat(3, Color(0.8, 0.88, 1.0)); col.material_override = e.col_mat
	root.add_child(col); e.nodes.append(col)
	# a burst of sparks rising
	var sp = CPUParticles.new()
	var sq = QuadMesh.new(); sq.size = Vector2(0.07, 0.07)
	var smat = SpatialMaterial.new(); smat.flags_unshaded = true; smat.flags_transparent = true; smat.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	smat.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED; smat.albedo_color = Color(1, 0.92, 0.7, 0.9)
	sq.material = smat; sp.mesh = sq
	sp.amount = 70; sp.lifetime = 3.2; sp.explosiveness = 0.15; sp.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 0.9
	sp.direction = Vector3(0, 1, 0); sp.spread = 35; sp.initial_velocity = 1.6; sp.initial_velocity_random = 0.5; sp.gravity = Vector3(0, 0.5, 0)
	sp.scale_amount_random = 0.6; sp.translation = base + Vector3(0, 1.0, 0); sp.emitting = true
	root.add_child(sp); e.nodes.append(sp); e.sparks = sp
	# the light: a cold white flash, then a warm glow
	var l = OmniLight.new(); l.omni_range = 12; l.light_color = Color(0.85, 0.9, 1.0); l.light_energy = 3.0; l.translation = base + Vector3(1.0, 3.5, 0)
	root.add_child(l); e.nodes.append(l); e.light = l
	# the figure appears inside the tomb, behind the doors
	e.figure = _figure(MC + Vector3(-0.5, 0.24, 0))
	e.nodes.append(e.figure.root)
	fx.append(e)
	main.sfx.play3d("thunder_near", hit, 1.0, 1.0, "Amb")
	main.sfx.play("thunder_near", 0.75, 0.95)
	_later(0.5, "heaven", 0.55)
	return e

func _later(delay, nm, vol):
	yield(get_tree().create_timer(delay), "timeout")
	main.sfx.play(nm, vol)

func _glow_mat(mode, tint):
	var m = ShaderMaterial.new(); m.shader = glow_shader
	m.set_shader_param("mode", mode); m.set_shader_param("tint", tint); m.set_shader_param("alpha", 0.0)
	return m

# the bolt: a jagged line of camera-facing quads from the clouds to the target, plus branches
func _bolt(hit):
	var cam = main.camera.global_transform.origin
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top = hit + Vector3(rand_range(-10, 10), 80, rand_range(-10, 10))
	var pts = [top]
	var n = 26
	for i in range(1, n):
		var u = float(i) / n
		var p = top.linear_interpolate(hit, u)
		var j = 2.2 * (1.0 - u * 0.8)
		pts.append(p + Vector3(rand_range(-j, j), rand_range(-0.8, 0.8), rand_range(-j, j)))
	pts.append(hit)
	_strip(st, pts, 0.16, cam)
	for b in range(3):
		var i0 = int(rand_range(3, n - 8))
		var bp = [pts[i0]]
		var dirv = Vector3(rand_range(-1, 1), -1.2, rand_range(-1, 1)).normalized()
		for k in range(7):
			bp.append(bp[-1] + dirv * rand_range(1.6, 3.0) + Vector3(rand_range(-0.9, 0.9), 0, rand_range(-0.9, 0.9)))
		_strip(st, bp, 0.08, cam)
	var mi = MeshInstance.new(); mi.mesh = st.commit()
	var m = SpatialMaterial.new(); m.flags_unshaded = true; m.flags_transparent = true; m.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	m.params_cull_mode = SpatialMaterial.CULL_DISABLED; m.albedo_color = Color(0.9, 0.94, 1.0, 1.0)
	m.vertex_color_use_as_albedo = true
	mi.material_override = m; mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi

func _strip(st, pts, w, cam):
	for i in range(pts.size() - 1):
		var a = pts[i]
		var b = pts[i + 1]
		for layer in [[w, 1.0], [w * 6.0, 0.25]]:
			var side = (b - a).cross(cam - a).normalized() * layer[0]
			var c = Color(0.92, 0.95, 1.0, layer[1])
			for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
				st.add_color(c); st.add_vertex(v)

# a figure of light over the grave: a glowing silhouette, angel wings and a halo
func _figure(base):
	var f = {}
	f.root = Spatial.new(); f.root.translation = base + Vector3(0, -0.6, 0)
	root.add_child(f.root)
	f.h = load("res://scripts/Human.gd").new().build({})
	f.h.rotation.y = PI / 2
	f.root.add_child(f.h)
	f.body = _glow_mat(0, Color(0.85, 0.92, 1.0))
	_override(f.h, f.body)
	f.wing_mat = _glow_mat(2, Color(0.92, 0.95, 1.0))
	f.wings = []
	for s in [-1, 1]:
		var piv = Spatial.new(); piv.translation = Vector3(-0.12, 1.42, s * 0.12)
		f.root.add_child(piv)
		var q = QuadMesh.new(); q.size = Vector2(1.7, 1.5)
		var w = MeshInstance.new(); w.mesh = q; w.material_override = f.wing_mat
		# quad in the yz plane, root at the spine, tip outward along z
		w.transform = Transform(Basis(Vector3(0, 1, 0), -PI / 2 if s > 0 else PI / 2), Vector3(0, -0.2, s * 0.85))
		if s < 0: w.scale = Vector3(1, 1, 1)
		piv.add_child(w)
		f.wings.append([piv, s])
	f.halo_mat = _glow_mat(1, Color(1.0, 0.9, 0.6))
	var hq = QuadMesh.new(); hq.size = Vector2(0.42, 0.42)
	f.halo = MeshInstance.new(); f.halo.mesh = hq; f.halo.material_override = f.halo_mat
	f.halo.transform = Transform(Basis(Vector3(1, 0, 0), -PI / 2), Vector3(0, 1.98, 0))
	f.root.add_child(f.halo)
	f.t = 0.0
	return f

func _override(n, m):
	if n is MeshInstance: n.material_override = m
	for c in n.get_children(): _override(c, m)

func _dove(at):
	var d = Spatial.new(); d.translation = at
	var white = SpatialMaterial.new(); white.albedo_color = Color(0.97, 0.97, 1.0); white.emission_enabled = true; white.emission = Color(0.9, 0.92, 1.0); white.emission_energy = 0.35
	white.params_cull_mode = SpatialMaterial.CULL_DISABLED
	var b = _sphere(0.1, Vector3(), white, d); b.scale = Vector3(0.8, 0.75, 1.7)
	_sphere(0.06, Vector3(0, 0.07, -0.16), white, d)
	var wings = []
	for s in [-1, 1]:
		var piv = Spatial.new(); piv.translation = Vector3(s * 0.05, 0.03, 0); d.add_child(piv)
		# a swept triangle: the wing tapers to a point toward the tail
		var q = PrismMesh.new(); q.size = Vector3(0.34, 0.24, 0.012); q.left_to_right = 0.0 if s > 0 else 1.0
		var w = MeshInstance.new(); w.mesh = q; w.material_override = white
		w.transform = Transform(Basis(Vector3(1, 0, 0), -PI / 2), Vector3(s * 0.17, 0, 0.04))
		piv.add_child(w); wings.append([piv, s])
	root.add_child(d)
	var a = rand_range(0, TAU)
	return { "n": d, "w": wings, "v": Vector3(cos(a) * rand_range(1.5, 3.0), rand_range(2.2, 3.6), sin(a) * rand_range(1.5, 3.0)), "ph": randf() * 6, "t": 0.0 }

func _run_fx(dt):
	var i = fx.size() - 1
	while i >= 0:
		var e = fx[i]
		e.t += dt
		var t = e.t
		# bolt flickers for a third of a second
		if is_instance_valid(e.bolt):
			e.bolt.visible = t < 0.6 and not (t > 0.24 and t < 0.29)
		# column fades in, holds, fades out
		var ca = clamp(t / 0.6, 0.0, 1.0) * clamp((10.5 - t) / 2.5, 0.0, 1.0)
		e.col_mat.set_shader_param("alpha", ca * 0.55)
		e.col_mat.set_shader_param("t", G.REAL_T)
		if t > 3.0: e.sparks.emitting = false
		e.light.light_energy = (3.5 * exp(-t * 5.0) + 0.6 * ca) if t < 11 else 0.0
		e.light.light_color = Color(0.85, 0.9, 1.0).linear_interpolate(Color(1.0, 0.84, 0.6), clamp(t / 3.0, 0.0, 1.0))
		_run_figure(e, dt, t)
		if not e.banner and t > 1.6:
			e.banner = true
			if main.camera.global_transform.origin.distance_to(target_pos(e.k)) < 90 and G.MODE == "play":
				main.hud.banner("Long live XXXTentacion", "Jahseh Dwayne Ricardo Onfroy · 1998–2018")
		for d in e.doves:
			d.t += dt
			d.v.y += dt * 0.4
			d.n.translation += d.v * dt
			d.n.look_at(d.n.translation + d.v, Vector3.UP)
			for w in d.w:
				w[0].rotation.z = w[1] * sin(G.REAL_T * 15.0 + d.ph) * 0.9
		if t > 16.0:
			for n in e.nodes:
				if is_instance_valid(n): n.queue_free()
			for d in e.doves: d.n.queue_free()
			fx.remove(i)
		i -= 1

func _release_doves(e, at, n):
	for k in range(n):
		e.doves.append(_dove(at + Vector3(rand_range(-0.4, 0.4), rand_range(0, 0.8), rand_range(-0.4, 0.4))))
	main.sfx.play("wings", 0.55)

func _run_figure(e, dt, t):
	var f = e.figure
	# the doors swing open, light pours out, the figure appears inside, comes out to the
	# step, opens its wings, hovers with open arms, then ascends and turns into doves
	var dopen = _ease(clamp((t - 0.25) / 1.4, 0.0, 1.0)) * (1.0 - _ease(clamp((t - 13.0) / 1.6, 0.0, 1.0)))
	for d in doors:
		d[0].rotation.y = d[1] * 1.75 * dopen
	in_light.visible = dopen > 0.01
	in_light.light_energy = 0.7 * dopen
	plate_mat.emission_energy = 0.1 + 0.9 * dopen
	var a = clamp((t - 0.9) / 1.4, 0.0, 1.0) * clamp((10.5 - t) / 1.5, 0.0, 1.0)
	var walk = _ease(clamp((t - 1.8) / 2.6, 0.0, 1.0))
	var lift = max(0.0, t - 8.0)
	f.root.translation = MC + Vector3(lerp(-0.5, 2.15, walk), 0.13 + walk * 0.12 + lift * lift * 0.4 + sin(t * 1.4) * 0.04 * walk, 0)
	f.body.set_shader_param("alpha", a)
	f.body.set_shader_param("t", G.REAL_T)
	var wa = clamp((t - 4.2) / 1.4, 0.0, 1.0)
	f.wing_mat.set_shader_param("alpha", a * wa)
	f.halo_mat.set_shader_param("alpha", a * clamp((t - 2.0) / 1.0, 0.0, 1.0))
	for w in f.wings:
		# unfold from folded back to open, then a slow beat
		var open = lerp(-1.25, 0.15, wa) + sin(t * 1.8) * 0.08 * wa
		w[0].rotation = Vector3(0, -w[1] * open, 0)
	f.h.animate(dt, { "speed": 0.0, "emote": "ascend" if t > 4.0 else "", "et": max(0.0, t - 4.0) })
	if t > 9.3 and e.doves.size() == 0:
		_release_doves(e, f.root.translation + Vector3(0, 1.3, 0), 9)

func _ease(x):
	return x * x * (3.0 - 2.0 * x)

func update(dt):
	g_cd = max(0.0, g_cd - dt)
	_run_fx(dt)
	var cam = main.camera.global_transform.origin
	var dg = Vector2(cam.x - MC.x, cam.z - MC.z).length()
	var night = main.DN.night
	if dg < 120:
		for f in flames:
			var k = 1.0 + sin(G.REAL_T * 13 + f[1]) * 0.18 + sin(G.REAL_T * 31 + f[1] * 2) * 0.1
			f[0].scale = Vector3(1, k, 1)
	var gon = night > 0.2 and dg < 50
	g_light.visible = gon
	g_light.light_energy = 0.55 * night if gon else 0.0
	# people walking past stop for a moment to pray
	if G.MODE == "play" and dg < 40:
		for p in main.peds.PEDS:
			if p.state != "walk" or p.emote_left > 0: continue
			if Vector2(p.pos.x - G_SPOT.x, p.pos.z - G_SPOT.z).length() < 4.5 and randf() < dt * 0.25:
				p.yaw = atan2(MC.x - p.pos.x, MC.z - p.pos.z)
				p.emote = "pray" if randf() < 0.6 else "salute"; p.emote_t = 0; p.emote_left = 3.0
