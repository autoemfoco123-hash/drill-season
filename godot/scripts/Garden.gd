extends Reference
# The memorial garden in Calder Park, built once at startup (Memorial.gd runs it).
#
# The mausoleum is a replica of XXXTentacion's, modelled on a photo his family shared:
# grey granite panels on a two-tier plinth with front steps, fluted Ionic columns, an
# entablature with fasciae, dentils and a cornice, the pediment with "XXXTENTACION /
# JAHSEH D. ONFROY" cut into it under raking cornices, and bronze double doors with
# scrollwork over dark glass and gold handles. Inside: a black granite crypt front with
# his name and dates, a shelf with vases of red roses and an eternal light.
# Around it, as in the photo: a bed of red mulch, a lawn, royal palms behind, cascades of red
# roses on easels (one with a satin sash), black and silver roses, a small bouquet in a white
# pot, petals and candles on the step. A wrought-iron fence on a granite curb with pillars,
# lanterns and an arch over the gate. Beside the tomb, in a black granite planter, the Poison
# Tree: a bare, twisted tree with roots, poison fruit and violet veins that glow at night.
# Everything static is merged into a few meshes (MeshBuild.gd) so it stays cheap to draw.

const MeshBuild = preload("res://scripts/MeshBuild.gd")

var main
var root
var mc
var B
var rng = RandomNumberGenerator.new()
var doors = []
var plate_mat
var in_light
var spots = []
var candle_light
var tree_spot
var bark_mat
var fruit_mat
var lantern_mat
var eternal_mat
var flame_mat
var flames = []
var mist
var tree_pos
var tex = {}

func L(x, y, z):
	return mc + Vector3(x, y, z)

func _t(name, repeat = true):
	if tex.has(name): return tex[name]
	var t = load("res://assets/art/" + name + ".png")
	if t:
		t.flags = Texture.FLAG_MIPMAPS | Texture.FLAG_FILTER | (Texture.FLAG_REPEAT if repeat else 0) | Texture.FLAG_ANISOTROPIC_FILTER
	tex[name] = t
	return t

func _m(albedo, rough, albedo_tex = null, normal_tex = null, metal = 0.0):
	var m = SpatialMaterial.new()
	m.albedo_color = albedo; m.roughness = rough; m.metallic = metal
	if albedo_tex: m.albedo_texture = albedo_tex
	if normal_tex:
		m.normal_enabled = true; m.normal_texture = normal_tex; m.normal_scale = 1.0
	return m

func _ma(albedo_tex, albedo = Color(1, 1, 1), rough = 0.75):
	var m = _m(albedo, rough, albedo_tex)
	m.params_use_alpha_scissor = true; m.params_alpha_scissor_threshold = 0.45
	m.params_cull_mode = SpatialMaterial.CULL_DISABLED
	return m

func build(m, center):
	main = m
	mc = center
	rng.seed = 1998
	root = Spatial.new(); root.name = "MemorialGarden"; main.add_child(root)
	B = MeshBuild.new()
	B.mat("gr", _m(Color(0.74, 0.74, 0.76), 0.36, _t("granite"), _t("granite_n")), true)
	B.mat("grd", _m(Color(0.3, 0.3, 0.33), 0.3, _t("granite"), _t("granite_n")), true)
	B.mat("bgr", _m(Color(0.05, 0.05, 0.06), 0.12, null, null, 0.3))
	B.mat("tymp", _m(Color(0.74, 0.74, 0.76), 0.4, _t("pediment", false), _t("pediment_n", false)), true)
	B.mat("bronze", _m(Color(0.16, 0.11, 0.07), 0.38, null, null, 0.75))
	B.mat("gold", _m(Color(0.86, 0.66, 0.26), 0.22, null, null, 1.0))
	var glass = _m(Color(0.02, 0.025, 0.035), 0.04, null, null, 0.6); glass.params_cull_mode = SpatialMaterial.CULL_DISABLED
	B.mat("glass", glass)
	var gm = _ma(_t("grille", false), Color(1, 1, 1), 0.35); gm.metallic = 0.7
	B.mat("grille", gm)
	B.mat("lawn", _m(Color(1, 1, 1), 0.95, _t("grass")))
	B.mat("mulch", _m(Color(1, 1, 1), 1.0, _t("mulch")))
	B.mat("pavers", _m(Color(1, 1, 1), 0.7, _t("pavers")))
	B.mat("edge", _m(Color(0.06, 0.06, 0.06), 0.5, null, null, 0.6))
	B.mat("iron", _m(Color(0.035, 0.035, 0.04), 0.45, null, null, 0.55))
	B.mat("hedge", _m(Color(1, 1, 1), 0.9, _t("hedge")))
	B.mat("white", _m(Color(0.92, 0.92, 0.9), 0.25))
	B.mat("trunk", _m(Color(1, 1, 1), 0.95, _t("palm_trunk")))
	B.mat("shaft", _m(Color(0.42, 0.52, 0.32), 0.6))
	B.mat("frond", _ma(_t("palm_frond", false)))
	B.mat("soil", _m(Color(0.18, 0.08, 0.16), 1.0, _t("mulch")))
	B.mat("ribbon", _m(Color(1, 1, 1), 0.3, _t("ribbon", false)))
	bark_mat = _m(Color(1, 1, 1), 0.85, _t("bark"), _t("bark_n"))
	bark_mat.emission_enabled = true; bark_mat.emission_texture = _t("bark_glow"); bark_mat.emission = Color(1, 1, 1); bark_mat.emission_energy = 0.3
	bark_mat.emission_operator = SpatialMaterial.EMISSION_OP_MULTIPLY
	B.mat("bark", bark_mat, true)
	fruit_mat = _m(Color(0.32, 0.02, 0.12), 0.15, null, null, 0.1)
	fruit_mat.emission_enabled = true; fruit_mat.emission = Color(0.55, 0.05, 0.4); fruit_mat.emission_energy = 0.4
	B.mat("fruit", fruit_mat)
	lantern_mat = SpatialMaterial.new(); lantern_mat.flags_unshaded = true; lantern_mat.albedo_color = Color(0.45, 0.36, 0.22)
	B.mat("lantern", lantern_mat)
	eternal_mat = SpatialMaterial.new(); eternal_mat.flags_unshaded = true; eternal_mat.albedo_color = Color(1.0, 0.25, 0.15)
	B.mat("eternal", eternal_mat)
	_ground()
	_mausoleum()
	_interior()
	_fence()
	_palm(L(-2.25, 0, -3.0), 8.6, Vector3(-0.25, 0, -0.2), 15)
	_palm(L(-2.15, 0, 2.6), 9.6, Vector3(-0.3, 0, 0.1), 16)
	_poison_tree()
	_flowers()
	B.commit(root)
	_doors()
	_grass_tufts()
	_candles()
	_lights()
	_collision()
	return self

# ---------------------------------------------------------------- ground
func _ground():
	B.boxp("lawn", L(3.1, 0.006, 0), Vector3(13.0, 0.012, 11.0), 0.55)
	B.boxp("mulch", L(-0.1, 0.02, 0), Vector3(6.4, 0.03, 7.4), 0.8)
	for e in [[L(-0.1, 0.03, -3.7), Vector3(6.42, 0.05, 0.02)], [L(-0.1, 0.03, 3.7), Vector3(6.42, 0.05, 0.02)], [L(-3.3, 0.03, 0), Vector3(0.02, 0.05, 7.4)]]:
		B.boxp("edge", e[0], e[1])
	B.boxp("edge", L(3.1, 0.03, -2.0), Vector3(0.02, 0.05, 3.4)); B.boxp("edge", L(3.1, 0.03, 2.0), Vector3(0.02, 0.05, 3.4))
	B.boxp("pavers", L(6.35, 0.03, 0), Vector3(6.5, 0.04, 1.4), 0.83)
	for sd in [-1, 1]:
		B.boxp("gr", L(6.35, 0.035, sd * 0.74), Vector3(6.5, 0.05, 0.08))
	# boxwood hedges inside the fence and four topiary balls
	for h in [[L(3.1, 0, -5.0), Vector3(12.2, 0, 0.6)], [L(5.85, 0, 5.0), Vector3(6.7, 0, 0.6)], [L(-2.95, 0, 0), Vector3(0.6, 0, 9.4)]]:
		B.boxp("hedge", h[0] + Vector3(0, 0.3, 0), Vector3(h[1].x, 0.6, h[1].z), 1.6)
		B.boxp("hedge", h[0] + Vector3(0, 0.66, 0), Vector3(h[1].x * (0.98 if h[1].x > 1 else 0.75), 0.12, h[1].z * (0.98 if h[1].z > 1 else 0.75)), 1.6)
	for p in [L(8.9, 0, -1.4), L(8.9, 0, 1.4), L(3.6, 0, -2.05), L(3.6, 0, 2.05)]:
		var prof = []
		for i in range(9):
			var a = -PI / 2 + PI * i / 8.0
			prof.append([0.34 * cos(a), 0.36 + 0.34 * sin(a)])
		B.lathe("hedge", Transform(Basis(), p), prof, 14, Vector2(2.2, 2.2))

# ---------------------------------------------------------------- the mausoleum
func _flute(a, r, _y):
	return r * (1.0 - 0.075 * pow(max(0.0, cos(a * 20.0)), 2))

func _mausoleum():
	# plinth, steps
	B.boxp("gr", L(0.05, 0.06, 0), Vector3(3.9, 0.12, 3.9))
	B.boxp("gr", L(0.0, 0.18, 0), Vector3(3.7, 0.12, 3.7))
	B.boxp("gr", L(2.0, 0.08, 0), Vector3(0.3, 0.16, 2.2))
	B.boxp("gr", L(2.35, 0.04, 0), Vector3(0.4, 0.08, 2.4))
	# walls
	B.boxp("gr", L(-1.49, 1.43, 0), Vector3(0.22, 2.38, 3.0))
	for sd in [-1, 1]:
		B.boxp("gr", L(-0.05, 1.43, sd * 1.39), Vector3(3.1, 2.38, 0.22))
		B.boxp("gr", L(1.39, 1.43, sd * 1.1), Vector3(0.22, 2.38, 0.8))
		# water table
		B.boxp("gr", L(1.42, 0.33, sd * 1.1), Vector3(0.28, 0.18, 0.8))
		B.boxp("gr", L(-0.05, 0.33, sd * 1.42), Vector3(3.16, 0.18, 0.28))
		# antae behind the columns, pilasters on the back corners
		B.boxp("gr", L(1.53, 1.5, sd * 1.28), Vector3(0.06, 2.24, 0.36))
		B.boxp("gr", L(-1.62, 1.5, sd * 1.28), Vector3(0.06, 2.24, 0.36))
		B.boxp("gr", L(-1.42, 1.5, sd * 1.52), Vector3(0.36, 2.24, 0.06))
		B.boxp("gr", L(1.32, 1.5, sd * 1.52), Vector3(0.36, 2.24, 0.06))
	B.boxp("gr", L(-1.52, 0.33, 0), Vector3(0.28, 0.18, 3.06))
	B.boxp("gr", L(1.39, 2.47, 0), Vector3(0.22, 0.3, 1.4))
	# the door surround: an architrave with two fasciae
	var ap = [[0, 0], [0.04, 0], [0.04, 0.05], [0.06, 0.06], [0.06, 0.13], [0.03, 0.16], [0, 0.16]]
	B.extrude("gr", ap, L(1.5, 0.24, 0.7), L(1.5, 2.48, 0.7), Vector3(1, 0, 0), Vector3(0, 0, 1))
	B.extrude("gr", ap, L(1.5, 0.24, -0.7), L(1.5, 2.48, -0.7), Vector3(1, 0, 0), Vector3(0, 0, -1))
	B.extrude("gr", ap, L(1.5, 2.32, -0.86), L(1.5, 2.32, 0.86), Vector3(1, 0, 0), Vector3(0, 1, 0))
	# columns: Attic base, fluted shaft with entasis, Ionic capital with volutes
	for sd in [-1, 1]:
		var c = L(1.72, 0, sd * 1.28)
		var xf = Transform(Basis(), c)
		B.boxp("gr", c + Vector3(0, 0.29, 0), Vector3(0.4, 0.1, 0.4))
		B.lathe("gr", xf, [[0.19, 0.34], [0.195, 0.36], [0.19, 0.38], [0.17, 0.40], [0.158, 0.42], [0.154, 0.45], [0.168, 0.47], [0.168, 0.49], [0.152, 0.51], [0.15, 0.52]], 24)
		var prof = []
		for i in range(9):
			var t = i / 8.0
			prof.append([0.15 - 0.018 * t * t + 0.004 * sin(t * PI), 0.52 + t * 1.84])
		B.lathe("gr", xf, prof, 80, Vector2(1, 1), self, "_flute")
		B.lathe("gr", xf, [[0.132, 2.36], [0.15, 2.375], [0.15, 2.395], [0.135, 2.41], [0.14, 2.42], [0.17, 2.46], [0.19, 2.5], [0.19, 2.52]], 24)
		B.boxp("gr", c + Vector3(0, 2.555, 0), Vector3(0.44, 0.07, 0.44))
		for s2 in [-1, 1]:
			var vc = c + Vector3(0, 2.47, s2 * 0.18)
			B.tube("gr", [vc + Vector3(-0.21, 0, 0), vc + Vector3(0.21, 0, 0)], [0.052, 0.052], 12)
			for fx in [-1, 1]:
				for R in [[0.05, 0.013], [0.03, 0.011], [0.013, 0.009]]:
					B.torus("gr", Transform(Basis(Vector3(0, 0, 1), PI / 2), vc + Vector3(fx * 0.212, 0, 0)), R[0], R[1], 16, 6)
	# entablature: two fasciae, frieze, dentils, cornice
	B.boxp("gr", L(0.1, 2.71, 0), Vector3(3.5, 0.17, 3.12))
	B.boxp("gr", L(0.11, 2.865, 0), Vector3(3.54, 0.14, 3.16))
	B.boxp("gr", L(0.1, 3.02, 0), Vector3(3.5, 0.17, 3.12))
	var z = -1.52
	while z <= 1.53:
		B.boxp("gr", L(1.875, 3.13, z), Vector3(0.05, 0.05, 0.045))
		B.boxp("gr", L(-1.675, 3.13, z), Vector3(0.05, 0.05, 0.045))
		z += 0.09
	var x = -1.6
	while x <= 1.83:
		for sd in [-1, 1]:
			B.boxp("gr", L(x, 3.13, sd * 1.585), Vector3(0.045, 0.05, 0.05))
		x += 0.09
	var corn = [[0, 0], [0.05, 0], [0.05, 0.03], [0.085, 0.05], [0.11, 0.085], [0.125, 0.12], [0.13, 0.15], [0, 0.15]]
	B.extrude("gr", corn, L(1.85, 3.10, -1.72), L(1.85, 3.10, 1.72), Vector3(1, 0, 0), Vector3(0, 1, 0))
	B.extrude("gr", corn, L(-1.65, 3.10, 1.72), L(-1.65, 3.10, -1.72), Vector3(-1, 0, 0), Vector3(0, 1, 0))
	for sd in [-1, 1]:
		B.extrude("gr", corn, L(-1.78, 3.10, sd * 1.56), L(1.98, 3.10, sd * 1.56), Vector3(0, 0, sd), Vector3(0, 1, 0))
	B.boxp("gr", L(0.1, 3.27, 0), Vector3(3.72, 0.04, 3.36))
	# pediment: gable mass, roof, raking cornices, the engraved tympanum
	var yb = 3.29
	var rise = 0.92
	var hw = 1.84
	var xf_ = 1.86
	var xb = -1.68
	B.tri("gr", L(xf_ - 0.04, yb, hw), L(xf_ - 0.04, yb, -hw), L(xf_ - 0.04, yb + rise, 0), Vector3(1, 0, 0))
	B.tri("gr", L(xb, yb, hw), L(xb, yb, -hw), L(xb, yb + rise, 0), Vector3(-1, 0, 0))
	for sd in [-1, 1]:
		var e0 = L(xb - 0.1, yb - 0.02, sd * (hw + 0.1))
		var e1 = L(xf_ + 0.12, yb - 0.02, sd * (hw + 0.1))
		var a1 = L(xf_ + 0.12, yb + rise + 0.17, 0)
		var a0 = L(xb - 0.1, yb + rise + 0.17, 0)
		var n = (Vector3(0, hw + 0.1, sd * (rise + 0.19))).normalized()
		B.quad("gr", e0, e1, a1, a0, n, Vector2(0, 0), Vector2(1.8, 0), Vector2(1.8, 1), Vector2(0, 1))
		B.quad("gr", e0, e1, e1 + Vector3(0, -0.04, 0), e0 + Vector3(0, -0.04, 0), Vector3(0, 0, sd), Vector2(), Vector2(), Vector2(), Vector2())
	var rake = [[0, 0], [0.06, 0], [0.06, 0.04], [0.1, 0.07], [0.12, 0.11], [0.12, 0.15], [0, 0.15]]
	for sd in [-1, 1]:
		var corner = L(xf_, yb, sd * hw)
		var apex = L(xf_, yb + rise, 0)
		var up = Vector3(0, hw, sd * rise).normalized()
		B.extrude("gr", rake, corner, apex, Vector3(1, 0, 0), up)
		B.extrude("gr", rake, L(xb, yb, sd * hw), L(xb, yb + rise, 0), Vector3(-1, 0, 0), up)
	B.extrude("gr", [[0, 0], [0.05, 0], [0.05, 0.08], [0, 0.08]], L(xf_ - 0.02, yb, -hw), L(xf_ - 0.02, yb, hw), Vector3(1, 0, 0), Vector3(0, 1, 0))
	var hwt = 1.58
	var rt = rise * hwt / hw - 0.02
	B.tri("tymp", L(xf_ - 0.015, yb + 0.08, hwt), L(xf_ - 0.015, yb + 0.08, -hwt), L(xf_ - 0.015, yb + 0.08 + rt, 0), Vector3(1, 0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0))
	# bronze sconces on the piers, either side of the door
	for sd in [-1, 1]:
		var s = L(1.55, 1.95, sd * 1.06)
		B.boxp("bronze", s + Vector3(0.02, -0.2, 0), Vector3(0.06, 0.05, 0.1))
		B.boxp("bronze", s + Vector3(0.09, 0, 0), Vector3(0.16, 0.03, 0.16))
		B.boxp("bronze", s + Vector3(0.09, 0.27, 0), Vector3(0.18, 0.03, 0.18))
		B.boxp("lantern", s + Vector3(0.09, 0.135, 0), Vector3(0.13, 0.24, 0.13))
		for c in [Vector3(0.02, 0, 0.07), Vector3(0.02, 0, -0.07), Vector3(0.16, 0, 0.07), Vector3(0.16, 0, -0.07)]:
			B.boxp("bronze", s + c + Vector3(0, 0.135, 0), Vector3(0.015, 0.27, 0.015))
		B.lathe("bronze", Transform(Basis(), s + Vector3(0.09, 0.285, 0)), [[0.09, 0], [0.05, 0.06], [0.01, 0.1], [0.0, 0.12]], 8)

func _interior():
	B.boxp("grd", L(-0.05, 0.25, 0), Vector3(2.75, 0.02, 2.56))
	B.box("grd", Transform(Basis(), L(-0.05, 2.6, 0)), Vector3(2.8, 0.04, 2.6), 0.5, false)
	B.boxp("grd", L(-1.37, 1.43, 0), Vector3(0.01, 2.36, 2.54))
	for sd in [-1, 1]:
		B.boxp("grd", L(-0.05, 1.43, sd * 1.275), Vector3(2.62, 2.36, 0.01))
	# black granite crypt front, the plate, a shelf with vases and an eternal light
	B.boxp("bgr", L(-1.34, 1.42, 0), Vector3(0.04, 1.9, 2.1))
	B.boxp("gr", L(-1.25, 0.78, 0), Vector3(0.22, 0.05, 2.0))
	for sd in [-1, 1]:
		B.lathe("bronze", Transform(Basis(), L(-1.25, 0.805, sd * 0.72)), [[0.05, 0], [0.07, 0.03], [0.075, 0.1], [0.05, 0.16], [0.045, 0.2], [0.06, 0.24]], 12)
	B.lathe("bronze", Transform(Basis(), L(-1.25, 0.805, 0)), [[0.04, 0], [0.04, 0.02], [0.03, 0.03]], 8)
	B.lathe("eternal", Transform(Basis(), L(-1.25, 0.835, 0)), [[0.035, 0], [0.04, 0.05], [0.035, 0.11], [0.0, 0.11]], 10)
	var ht = _t("headstone", false)
	plate_mat = _m(Color(1, 1, 1), 0.15, ht)
	plate_mat.emission_enabled = true; plate_mat.emission_texture = ht; plate_mat.emission = Color(1, 1, 1); plate_mat.emission_energy = 0.08
	plate_mat.emission_operator = SpatialMaterial.EMISSION_OP_MULTIPLY
	B.mat("plate", plate_mat)
	var px = -1.315
	B.quad("plate", L(px, 1.0, 0.65), L(px, 1.0, -0.65), L(px, 2.0, -0.65), L(px, 2.0, 0.65), Vector3(1, 0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))

# ---------------------------------------------------------------- doors (they move)
func _doors():
	for sd in [1, -1]:
		var piv = Spatial.new(); piv.translation = L(1.36, 0.24, sd * 0.7)
		root.add_child(piv)
		var d = MeshBuild.new()
		for k in ["bronze", "gold", "glass", "grille"]:
			d.mat(k, B.mats[k])
		var W = 0.7
		var H = 2.08
		var zc = -sd * W / 2
		d.boxp("bronze", Vector3(0, H / 2, -sd * 0.035), Vector3(0.06, H, 0.07))
		d.boxp("bronze", Vector3(0, H / 2, -sd * (W - 0.035)), Vector3(0.06, H, 0.07))
		d.boxp("bronze", Vector3(0, 0.07, zc), Vector3(0.06, 0.14, W))
		d.boxp("bronze", Vector3(0, H - 0.05, zc), Vector3(0.06, 0.1, W))
		for y in [H * 0.34, H * 0.67]:
			d.boxp("bronze", Vector3(0, y, zc), Vector3(0.05, 0.035, W - 0.1))
		var z0 = -sd * 0.07
		var z1 = -sd * (W - 0.07)
		var ya = 0.14
		var yb = H - 0.1
		d.quad("glass", Vector3(0, ya, z0), Vector3(0, ya, z1), Vector3(0, yb, z1), Vector3(0, yb, z0), Vector3(1, 0, 0), Vector2(), Vector2(), Vector2(), Vector2())
		for fx in [1, -1]:
			var x = fx * 0.02
			var u0 = 0.0 if sd > 0 else 1.0
			var u1 = 1.0 - u0
			d.quad("grille", Vector3(x, ya, z0), Vector3(x, ya, z1), Vector3(x, yb, z1), Vector3(x, yb, z0), Vector3(fx, 0, 0), Vector2(u1, 1), Vector2(u0, 1), Vector2(u0, 0), Vector2(u1, 0))
		# long gold pull handle at the meeting edge, both faces
		for fx in [1, -1]:
			var hz = -sd * (W - 0.1)
			d.tube("gold", [Vector3(fx * 0.075, 0.92, hz), Vector3(fx * 0.075, 1.5, hz)], [0.014, 0.014], 10, 1.0, true)
			for y in [0.96, 1.46]:
				d.tube("gold", [Vector3(fx * 0.03, y, hz), Vector3(fx * 0.075, y, hz)], [0.01, 0.01], 8)
			d.boxp("gold", Vector3(fx * 0.033, 1.21, hz), Vector3(0.008, 0.1, 0.04))
		d.commit(piv)
		doors.append([piv, sd])

# ---------------------------------------------------------------- iron fence, curb, pillars, gate and arch
func _fence():
	var x0 = -3.4
	var x1 = 9.6
	var z0 = -5.5
	var z1 = 5.5
	var runs = [[Vector2(x0, z0), Vector2(x1, z0)], [Vector2(x0, z1), Vector2(x1, z1)], [Vector2(x0, z0), Vector2(x0, z1)],
		[Vector2(x1, z0), Vector2(x1, -1.25)], [Vector2(x1, 1.25), Vector2(x1, z1)]]
	var picket_xf = []
	for r in runs:
		var a = r[0]
		var b = r[1]
		var len_ = a.distance_to(b)
		var dir = (b - a).normalized()
		var mid = (a + b) / 2
		var size = Vector3(abs(b.x - a.x) + 0.3, 0.35, abs(b.y - a.y) + 0.3)
		B.boxp("gr", L(mid.x, 0.175, mid.y), size)
		B.boxp("gr", L(mid.x, 0.36, mid.y), Vector3(size.x + 0.04 if size.x > 1 else 0.34, 0.03, size.z + 0.04 if size.z > 1 else 0.34))
		var npil = int(ceil(len_ / 3.2))
		for i in range(npil + 1):
			var p = a + dir * len_ * i / npil
			var tall = (abs(p.x - x1) < 0.01 and abs(abs(p.y) - 1.25) < 0.01)
			var h = 2.15 if tall else 1.65
			B.boxp("gr", L(p.x, h / 2, p.y), Vector3(0.44, h, 0.44))
			B.boxp("gr", L(p.x, h + 0.04, p.y), Vector3(0.52, 0.08, 0.52))
			B.lathe("gr", Transform(Basis(), L(p.x, h + 0.08, p.y)), [[0.12, 0], [0.12, 0.03], [0.06, 0.05], [0.1, 0.12], [0.1, 0.17], [0.0, 0.25]], 12)
			if tall:
				# lantern on the gate pillars
				var lp = L(p.x, h + 0.33, p.y)
				B.boxp("lantern", lp + Vector3(0, 0.2, 0), Vector3(0.2, 0.32, 0.2))
				B.boxp("iron", lp + Vector3(0, 0.38, 0), Vector3(0.28, 0.04, 0.28))
				B.lathe("iron", Transform(Basis(), lp + Vector3(0, 0.4, 0)), [[0.14, 0], [0.08, 0.07], [0.02, 0.14], [0.0, 0.18]], 8)
				B.boxp("iron", lp, Vector3(0.26, 0.04, 0.26))
			if i < npil:
				var q = a + dir * len_ * (i + 1) / npil
				var s0 = p + dir * 0.26
				var s1 = q - dir * 0.26
				for y in [0.55, 1.42]:
					B.boxp("iron", L((s0.x + s1.x) / 2, y, (s0.y + s1.y) / 2), Vector3(max(abs(s1.x - s0.x), 0.025), 0.03, max(abs(s1.y - s0.y), 0.025)))
				var seg_len = s0.distance_to(s1)
				var cnt = int(seg_len / 0.13)
				for k in range(cnt + 1):
					var pp = s0 + (s1 - s0) * k / max(1, cnt)
					picket_xf.append(Transform(Basis(), L(pp.x, 0.38, pp.y)))
	# gate leaves standing open, and the arch with his name
	for sd in [-1, 1]:
		var hinge = Vector2(x1, sd * 1.03)
		var dirv = Vector3(-sin(1.15), 0, -sd * cos(1.15))
		var p0 = L(hinge.x, 0, hinge.y)
		for y in [0.25, 0.7, 1.5]:
			B.tube("iron", [p0 + Vector3(0, y, 0), p0 + dirv * 1.0 + Vector3(0, y, 0)], [0.02, 0.02], 6)
		for k in range(8):
			var pp = p0 + dirv * (0.06 + k * 0.13)
			picket_xf.append(Transform(Basis(), pp + Vector3(0, 0.08, 0)))
	var arch = []
	var arch2 = []
	for i in range(17):
		var t = i / 16.0
		var zz = lerp(-1.25, 1.25, t)
		arch.append(L(x1, 2.62 + 0.62 * sin(t * PI), zz))
		arch2.append(L(x1, 2.28 + 0.48 * sin(t * PI), zz))
	B.tube("iron", arch, _const(0.03, 17), 8)
	B.tube("iron", arch2, _const(0.022, 17), 8)
	for i in range(1, 16, 2):
		B.tube("iron", [arch2[i], arch[i]], [0.012, 0.012], 5)
	var at = _ma(_t("arch", false), Color(1, 1, 1), 0.3); at.metallic = 0.8
	B.mat("archtext", at)
	for fx in [1, -1]:
		var x = x1 + fx * 0.03
		var u0 = 0.0 if fx > 0 else 1.0
		B.quad("archtext", L(x, 2.42, 1.05), L(x, 2.42, -1.05), L(x, 2.75, -1.05), L(x, 2.75, 1.05), Vector3(fx, 0, 0), Vector2(u0, 1), Vector2(1 - u0, 1), Vector2(1 - u0, 0), Vector2(u0, 0))
	# pickets: one bar with a spear tip, drawn many times
	var pm = MeshBuild.new()
	pm.mat("iron", B.mats["iron"])
	pm.boxp("iron", Vector3(0, 0.56, 0), Vector3(0.022, 1.12, 0.022))
	pm.lathe("iron", Transform(Basis(), Vector3(0, 1.1, 0)), [[0.02, 0], [0.024, 0.02], [0.012, 0.03], [0.03, 0.06], [0.0, 0.16]], 4)
	_multi(pm.sts["iron"].commit(), picket_xf, B.mats["iron"])

func _const(v, n):
	var a = []
	for i in range(n): a.append(v)
	return a

func _multi(mesh, xfs, mat, colors = null):
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	if colors != null: mm.color_format = MultiMesh.COLOR_8BIT
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in range(xfs.size()):
		mm.set_instance_transform(i, xfs[i])
		if colors != null: mm.set_instance_color(i, colors[i])
	var mmi = MultiMeshInstance.new(); mmi.multimesh = mm; mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	return mmi

# ---------------------------------------------------------------- royal palms
func _palm(base, h, lean, nf):
	var pts = []
	var radii = []
	for i in range(13):
		var t = i / 12.0
		pts.append(base + lean * t * t * 1.6 + Vector3(0, t * (h - 1.3), 0))
		radii.append(0.34 - 0.12 * min(1.0, t * 6.0) + 0.03 * sin(t * PI) - 0.03 * t)
	B.tube("trunk", pts, radii, 10, 1.0)
	var top = pts[pts.size() - 1]
	var shaft = [top, top + Vector3(0, 0.7, 0) + lean * 0.05, top + Vector3(0, 1.3, 0) + lean * 0.08]
	B.tube("shaft", shaft, [radii[radii.size() - 1] + 0.01, 0.19, 0.12], 10)
	var crown = shaft[2]
	for k in range(nf):
		var az = TAU * k / nf + rng.randf_range(-0.2, 0.2)
		var pitch = lerp(1.05, -0.25, rng.randf())
		var Lf = rng.randf_range(3.0, 3.9)
		var dh = Vector3(cos(az), 0, sin(az))
		var right = dh.cross(Vector3.UP).normalized()
		var spine = []
		for i in range(11):
			var t = i / 10.0
			spine.append(crown + dh * cos(pitch) * Lf * t + Vector3(0, sin(pitch) * Lf * t - 1.6 * Lf * t * t * 0.35, 0))
		for i in range(10):
			var t0 = i / 10.0
			var t1 = (i + 1) / 10.0
			var w0 = 0.6 * sin(PI * min(1.0, t0 * 1.15 + 0.05)) * (1.0 - t0 * 0.3)
			var w1 = 0.6 * sin(PI * min(1.0, t1 * 1.15 + 0.05)) * (1.0 - t1 * 0.3)
			for s in [-1, 1]:
				var e0 = spine[i] + (right * s * 0.87 + Vector3(0, -0.5, 0)) * w0
				var e1 = spine[i + 1] + (right * s * 0.87 + Vector3(0, -0.5, 0)) * w1
				var n = (spine[i + 1] - spine[i]).cross(right * s).normalized()
				if n.y < 0: n = -n
				var v_e = 0.0 if s < 0 else 1.0
				B.quad("frond", spine[i], spine[i + 1], e1, e0, n, Vector2(t0, 0.5), Vector2(t1, 0.5), Vector2(t1, v_e), Vector2(t0, v_e))
	# collision for the trunk
	W.add_box(base.x - 0.3, 0, base.z - 0.3, base.x + 0.3, 3.0, base.z + 0.3, "solid")

# ---------------------------------------------------------------- the Poison Tree
func _poison_tree():
	tree_pos = L(0.45, 0, 3.95)
	var P = tree_pos
	var xf = Transform(Basis(), P)
	B.lathe("bgr", xf, [[1.2, 0.0], [1.25, 0.02], [1.25, 0.07], [1.2, 0.09], [1.2, 0.44], [1.26, 0.46], [1.26, 0.53], [1.07, 0.53], [1.05, 0.49]], 32)
	B.lathe("soil", xf, [[0.0, 0.47], [1.06, 0.47]], 24, Vector2(3, 3))
	# trunk with a flared base, then branches that fork and twist
	var tips = []
	var base = P + Vector3(0, 0.47, 0)
	B.tube("bark", [base + Vector3(0, -0.05, 0), base + Vector3(0.02, 0.25, 0.01), base + Vector3(0.0, 0.6, -0.04)], [0.34, 0.24, 0.2], 9, 0.8)
	_grow(base + Vector3(0.0, 0.6, -0.04), Vector3(0.12, 1, -0.08).normalized(), 1.5, 0.2, 5, tips)
	# roots spreading over the soil
	for k in range(7):
		var a = TAU * k / 7 + rng.randf_range(-0.2, 0.2)
		var out = Vector3(cos(a), 0, sin(a))
		var p0 = base + Vector3(0, 0.12, 0)
		var pts = [p0, p0 + out * 0.3 + Vector3(0, -0.06, 0), p0 + out * 0.62 + Vector3(0, -0.12, 0) + out.cross(Vector3.UP) * 0.08, p0 + out * 0.9 + Vector3(0, -0.2, 0)]
		B.tube("bark", pts, [0.1, 0.07, 0.045, 0.02], 6, 0.8)
	# poison fruit hanging from some of the outer twigs
	tips.shuffle()
	var nfruit = 0
	for t in tips:
		if nfruit >= 18: break
		if t[0].y < P.y + 2.2: continue
		var stem_top = t[0]
		var f = stem_top + Vector3(0, -0.16, 0)
		B.tube("bark", [stem_top, f + Vector3(0, 0.05, 0)], [0.008, 0.006], 4)
		B.lathe("fruit", Transform(Basis(), f), [[0.0, -0.065], [0.045, -0.058], [0.068, -0.03], [0.072, 0.0], [0.066, 0.03], [0.045, 0.055], [0.018, 0.058], [0.0, 0.048]], 12)
		nfruit += 1
	# the plaque on a black granite stand facing the lawn
	var sp = P + Vector3(1.55, 0, 0)
	B.boxp("bgr", sp + Vector3(0, 0.2, 0), Vector3(0.18, 0.4, 0.66))
	var pmat = _m(Color(1, 1, 1), 0.15, _t("plaque", false))
	B.mat("plaque", pmat)
	var tilt = Basis(Vector3(0, 0, 1), -0.35)
	var c = sp + Vector3(0.02, 0.48, 0)
	B.box("bgr", Transform(tilt, c), Vector3(0.05, 0.36, 0.7))
	var n = tilt.xform(Vector3(1, 0, 0))
	var uq = tilt.xform(Vector3(0, 1, 0))
	var f0 = c + n * 0.026
	B.quad("plaque", f0 - uq * 0.17 + Vector3(0, 0, 0.34), f0 - uq * 0.17 - Vector3(0, 0, 0.34), f0 + uq * 0.17 - Vector3(0, 0, 0.34), f0 + uq * 0.17 + Vector3(0, 0, 0.34), n, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))

func _grow(p, d, length, r, depth, tips):
	var segs = 6 if depth == 5 else 4
	var pts = [p]
	var radii = [r]
	var cur = p
	var dir = d
	for i in range(segs):
		var wob = 0.2 if depth == 5 else 0.36
		dir = (dir + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.7), rng.randf_range(-1, 1)) * wob).normalized()
		cur = cur + dir * length / segs
		pts.append(cur)
		radii.append(r * lerp(1.0, 0.72, float(i + 1) / segs))
	B.tube("bark", pts, radii, 7 if depth >= 3 else 5, 0.8)
	var r_end = radii[radii.size() - 1]
	if depth == 0:
		tips.append([cur, dir])
		return
	var n = 2 if depth >= 4 else (2 if rng.randf() < 0.45 else 3)
	var perp = dir.cross(Vector3.UP)
	if perp.length() < 0.1: perp = Vector3(1, 0, 0)
	perp = perp.normalized()
	var az0 = rng.randf() * TAU
	for k in range(n):
		var axis = perp.rotated(dir, az0 + TAU * k / n)
		var nd = dir.rotated(axis, rng.randf_range(0.45, 0.85))
		nd = (nd + Vector3(0, 0.18 if depth >= 3 else -0.08, 0)).normalized()
		_grow(cur, nd, length * rng.randf_range(0.68, 0.8), r_end * 0.8, depth - 1, tips)

# ---------------------------------------------------------------- flowers (as in the photo)
func _rose_mesh():
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layers = [[5, 0.016, 0.034, 0.3], [6, 0.03, 0.03, 0.6], [7, 0.045, 0.022, 1.0]]
	for li in range(layers.size()):
		var Ly = layers[li]
		var n = Ly[0]
		var shade = 0.5 + 0.5 * li / 2.0
		for i in range(n):
			var a = TAU * i / n + li * 0.7
			var w = TAU / n * 0.72
			var grid = []
			for vv in range(3):
				var row = []
				for uu in range(3):
					var t = vv / 2.0
					var s = uu / 2.0 - 0.5
					var ang = a + s * w * (1.0 + 0.25 * t)
					var rr = Ly[1] * (0.5 + 0.5 * t) + Ly[3] * 0.018 * t * t
					var y = Ly[2] * t - Ly[3] * 0.008 * t * t
					row.append(Vector3(cos(ang) * rr, y, sin(ang) * rr))
				grid.append(row)
			for vv in range(2):
				for uu in range(2):
					var q = [grid[vv][uu], grid[vv][uu + 1], grid[vv + 1][uu + 1], grid[vv + 1][uu]]
					for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
						for p in tri:
							var nn = (Vector3(p.x, 0, p.z).normalized() * 0.55 + Vector3(0, 0.85, 0)).normalized()
							var cshade = shade * (0.75 + 0.25 * vv)
							st.add_color(Color(cshade, cshade, cshade)); st.add_normal(nn); st.add_vertex(p)
	return st.commit()

func _leaf_mesh(w, h):
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts = []
	for i in range(3):
		var t = i / 2.0
		var bend = -0.25 * h * t * t
		pts.append([Vector3(-w / 2, t * h, bend), Vector3(w / 2, t * h, bend), t])
	for i in range(2):
		var a = pts[i]
		var b = pts[i + 1]
		var quad = [[a[0], Vector2(0, 1 - a[2])], [a[1], Vector2(1, 1 - a[2])], [b[1], Vector2(1, 1 - b[2])], [b[0], Vector2(0, 1 - b[2])]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.add_normal(Vector3(0, 0, 1)); st.add_uv(quad[idx][1]); st.add_vertex(quad[idx][0])
	return st.commit()

func _basis_up(up, roll):
	var y = up.normalized()
	var x = y.cross(Vector3(0, 0, 1))
	if x.length() < 0.1: x = y.cross(Vector3(1, 0, 0))
	x = x.normalized()
	var z = x.cross(y)
	return Basis(x, y, z).rotated(y, roll)

func _spray(R, Lf, Sv, c, W, H, D, n, cols, silver, cascade):
	for i in range(n):
		var u = 0.0
		var v = 0.0
		for tries in range(20):
			u = rng.randf_range(-1, 1); v = rng.randf_range(-1, 1)
			var wv = sqrt(max(0.0, 1.0 - v * v)) if v > 0 else (1.0 + v * (0.85 if cascade else 0.3))
			if abs(u) <= wv: break
		var bulge = D * sqrt(max(0.0, 1.0 - u * u - v * v * 0.55))
		var p = c + Vector3(bulge, v * H / 2, u * W / 2)
		var nrm = Vector3(0.75 + bulge / D * 0.4, v * 0.4, u * 0.7)
		var pick = rng.randf()
		var col = cols[0][0]
		var acc = 0.0
		for cc in cols:
			acc += cc[1]
			if pick <= acc:
				col = cc[0]
				break
		var sc = rng.randf_range(0.85, 1.2)
		R.append([Transform(_basis_up(nrm, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), p), col.lightened(rng.randf_range(-0.04, 0.1))])
	for i in range(int(n * 0.65)):
		var v = rng.randf_range(-1, 1)
		var s = -1.0 if rng.randf() < 0.5 else 1.0
		var wv = sqrt(max(0.0, 1.0 - v * v)) if v > 0 else (1.0 + v * (0.85 if cascade else 0.3))
		var u = s * wv * rng.randf_range(0.7, 1.08)
		var p = c + Vector3(D * 0.35, v * H / 2, u * W / 2)
		var outv = Vector3(0, v * 0.6, u).normalized()
		var face = Vector3(1, 0, 0)
		var y = (outv + face * 0.3).normalized()
		var x = y.cross(face).normalized()
		var bas = Basis(x, y, x.cross(y)).rotated(y, rng.randf_range(-0.6, 0.6))
		var sc = rng.randf_range(0.9, 1.3)
		(Sv if silver else Lf).append([Transform(bas.scaled(Vector3(sc, sc, sc)), p), Color(1, 1, 1).darkened(rng.randf_range(0, 0.25))])

func _easel(top, legs_spread, h):
	for lg in [[-0.28, -0.22], [-0.28, 0.22], [0.25, 0.0]]:
		var foot = Vector3(top.x + lg[0] * legs_spread, 0, top.z + lg[1] * legs_spread)
		B.tube("iron", [top, foot], [0.012, 0.014], 5)
	B.tube("iron", [top + Vector3(-0.05, -h * 0.45, -0.18), top + Vector3(-0.05, -h * 0.45, 0.18)], [0.01, 0.01], 5)

func _flowers():
	var R = []
	var Lf = []
	var Sv = []
	var red = Color(0.62, 0.02, 0.07)
	var red2 = Color(0.75, 0.04, 0.1)
	var blk = Color(0.06, 0.04, 0.06)
	var wht = Color(0.93, 0.93, 0.95)
	# right of the door: the big cascade of red roses on an easel, with the sash
	var c1 = L(2.1, 1.45, -0.95)
	_spray(R, Lf, Sv, c1, 0.62, 1.45, 0.2, 190, [[red, 0.6], [red2, 0.4]], false, true)
	_easel(c1 + Vector3(-0.15, -0.1, 0), 1.0, 1.4)
	# further right: the second large red arrangement on a stand
	var c2 = L(1.62, 1.6, -2.45)
	_spray(R, Lf, Sv, c2, 0.9, 1.3, 0.26, 230, [[red, 0.55], [red2, 0.45]], false, false)
	_easel(c2 + Vector3(-0.18, -0.1, 0), 1.1, 1.5)
	# left of the door: the tall spray of black roses and silver leaves
	var c3 = L(2.05, 1.3, 1.85)
	_spray(R, Lf, Sv, c3, 0.6, 1.35, 0.18, 140, [[blk, 0.86], [wht, 0.14]], true, true)
	_easel(c3 + Vector3(-0.15, -0.1, 0), 1.0, 1.3)
	# front right on the ground: black and silver
	_spray(R, Lf, Sv, L(2.75, 0.38, -1.85), 0.8, 0.6, 0.2, 70, [[blk, 0.85], [wht, 0.15]], true, false)
	# the small bouquet in a white pot, left of the step
	B.lathe("white", Transform(Basis(), L(2.2, 0, 0.98)), [[0.09, 0], [0.11, 0.02], [0.15, 0.22], [0.16, 0.27], [0.14, 0.28]], 16)
	_spray(R, Lf, Sv, L(2.22, 0.48, 0.98), 0.32, 0.36, 0.12, 34, [[blk, 0.6], [wht, 0.4]], true, false)
	# a few red roses laid on the step
	for i in range(5):
		var p = L(2.3 + rng.randf_range(-0.08, 0.08), 0.1, rng.randf_range(-0.45, 0.45))
		R.append([Transform(_basis_up(Vector3(0.3, 0.9, rng.randf_range(-0.3, 0.3)), rng.randf() * TAU), p), red2])
		B.tube("shaft", [p, p + Vector3(0.05, 0.0, rng.randf_range(-0.25, 0.25)).normalized() * 0.32], [0.005, 0.004], 4)
	# roses in the shelf vases inside, and a ring of black and red roses under the Poison Tree
	for sd in [-1, 1]:
		var vp = L(-1.25, 1.1, sd * 0.72)
		for i in range(7):
			R.append([Transform(_basis_up(Vector3(rng.randf_range(-0.4, 0.4), 1, rng.randf_range(-0.4, 0.4)), rng.randf() * TAU), vp + Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(0, 0.1), rng.randf_range(-0.06, 0.06))), red])
	for i in range(46):
		var a = rng.randf() * TAU
		var rr = rng.randf_range(0.55, 0.98)
		var p = tree_pos + Vector3(cos(a) * rr, 0.5, sin(a) * rr)
		R.append([Transform(_basis_up(Vector3(cos(a) * 0.3, 1, sin(a) * 0.3), rng.randf() * TAU), p), blk if rng.randf() < 0.6 else red])
	# the sash across the red cascade
	var pts = []
	for i in range(13):
		var t = i / 12.0
		var u = lerp(-0.95, 0.9, t)
		var v = lerp(0.45, -0.35, t)
		var bulge = 0.2 * sqrt(max(0.0, 1.0 - u * u - v * v * 0.55))
		pts.append(c1 + Vector3(bulge + 0.06, v * 1.45 / 2, u * 0.62 / 2))
	for i in range(12):
		var a = pts[i]
		var b = pts[i + 1]
		var along = (b - a).normalized()
		var side = along.cross(Vector3(1, 0, 0)).normalized() * 0.055
		B.quad("ribbon", a - side, b - side, b + side, a + side, Vector3(1, 0, 0), Vector2(i / 12.0, 1), Vector2((i + 1) / 12.0, 1), Vector2((i + 1) / 12.0, 0), Vector2(i / 12.0, 0))
	# draw them
	var rm = SpatialMaterial.new(); rm.vertex_color_use_as_albedo = true; rm.roughness = 0.55; rm.params_cull_mode = SpatialMaterial.CULL_DISABLED
	var rx = []
	var rc = []
	for r in R:
		rx.append(r[0]); rc.append(r[1])
	_multi(_rose_mesh(), rx, rm, rc)
	var lm = _ma(_t("leaf", false)); lm.vertex_color_use_as_albedo = true
	var lx = []
	var lc = []
	for l in Lf:
		lx.append(l[0]); lc.append(l[1])
	if lx.size() > 0: _multi(_leaf_mesh(0.08, 0.14), lx, lm, lc)
	var sm = _ma(_t("silver_leaf", false)); sm.vertex_color_use_as_albedo = true
	var sx = []
	var sc = []
	for s in Sv:
		sx.append(s[0]); sc.append(s[1])
	if sx.size() > 0: _multi(_leaf_mesh(0.09, 0.17), sx, sm, sc)
	# petals scattered on the step and the plinth
	var pxs = []
	var pcs = []
	for i in range(60):
		var p = L(rng.randf_range(1.86, 2.55), 0.0, rng.randf_range(-1.1, 1.1))
		p.y = 0.165 if mc.x + 1.85 < p.x and p.x < mc.x + 2.15 else (0.085 if p.x >= mc.x + 2.15 else 0.245)
		pxs.append(Transform(Basis(Vector3(1, 0, 0), -PI / 2).rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(0.05, 0.05, 0.05) * rng.randf_range(0.7, 1.2)), p))
		pcs.append(red.lightened(rng.randf_range(0, 0.15)))
	var qm = QuadMesh.new(); qm.size = Vector2(1, 1)
	var petm = _ma(_t("petal", false)); petm.vertex_color_use_as_albedo = true
	_multi(qm, pxs, petm, pcs)

# ---------------------------------------------------------------- grass tufts on the lawn
func _grass_tufts():
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(2):
		var a = k * PI / 2
		var dx = Vector3(cos(a), 0, sin(a)) * 0.2
		var q = [[-dx, Vector2(0, 1)], [dx, Vector2(1, 1)], [dx + Vector3(0, 0.2, 0), Vector2(1, 0)], [-dx + Vector3(0, 0.2, 0), Vector2(0, 0)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.add_normal(Vector3(0, 1, 0)); st.add_uv(q[idx][1]); st.add_vertex(q[idx][0])
	var mesh = st.commit()
	var xs = []
	var cs = []
	var tries = 0
	while xs.size() < 1500 and tries < 6000:
		tries += 1
		var x = rng.randf_range(-3.0, 9.3)
		var z = rng.randf_range(-4.6, 4.6)
		if x < 3.15 and abs(z) < 3.75: continue
		if x > 3.0 and abs(z) < 0.85: continue
		var s = rng.randf_range(0.7, 1.3)
		xs.append(Transform(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), L(x, 0.01, z)))
		cs.append(Color(1, 1, 1).darkened(rng.randf_range(0, 0.3)))
	var gm = _ma(_t("grass_card", false)); gm.vertex_color_use_as_albedo = true
	_multi(mesh, xs, gm, cs)

# ---------------------------------------------------------------- candles on the step
func _candles():
	var n = 10 + int(min(24, G.S.get("flags", {}).get("candles", 0)))
	var wax = _m(Color(0.95, 0.92, 0.84), 0.6)
	var glass_r = _m(Color(0.75, 0.12, 0.16), 0.2); glass_r.emission_enabled = true; glass_r.emission = Color(0.5, 0.08, 0.05); glass_r.emission_energy = 0.5
	var glass_w = _m(Color(0.9, 0.88, 0.8), 0.2); glass_w.emission_enabled = true; glass_w.emission = Color(0.5, 0.35, 0.15); glass_w.emission_energy = 0.5
	flame_mat = SpatialMaterial.new(); flame_mat.flags_unshaded = true; flame_mat.albedo_color = Color(1, 0.78, 0.35)
	var cr = RandomNumberGenerator.new(); cr.seed = 2018
	for i in range(n):
		var p = L(cr.randf_range(2.2, 2.52), 0.08, cr.randf_range(-1.0, 1.0))
		var tall = cr.randf_range(0.1, 0.26)
		var jar = cr.randf() < 0.6
		var cm = CylinderMesh.new(); cm.top_radius = 0.05 if jar else 0.04; cm.bottom_radius = cm.top_radius; cm.height = tall; cm.radial_segments = 10; cm.rings = 1
		var mi = MeshInstance.new(); mi.mesh = cm; mi.material_override = (glass_r if cr.randf() < 0.6 else glass_w) if jar else wax
		mi.translation = p + Vector3(0, tall / 2, 0); mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		var f = MeshInstance.new(); var sm = SphereMesh.new(); sm.radius = 0.02; sm.height = 0.06; sm.radial_segments = 6; sm.rings = 3; f.mesh = sm
		f.material_override = flame_mat; f.translation = p + Vector3(0, tall + 0.04, 0); f.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		root.add_child(f); flames.append([f, cr.randf() * 10])

# ---------------------------------------------------------------- lights (night only, and only when you are near)
func _lights():
	for sd in [-1, 1]:
		var s = SpotLight.new()
		s.light_color = Color(1.0, 0.86, 0.66); s.light_energy = 0; s.spot_range = 11; s.spot_angle = 34; s.spot_attenuation = 0.8
		s.visible = false
		root.add_child(s)
		s.look_at_from_position(L(4.6, 0.15, sd * 1.6), L(1.7, 3.0, sd * 0.4), Vector3.UP)
		spots.append(s)
	tree_spot = SpotLight.new()
	tree_spot.light_color = Color(0.75, 0.35, 1.0); tree_spot.light_energy = 0; tree_spot.spot_range = 9; tree_spot.spot_angle = 38; tree_spot.visible = false
	root.add_child(tree_spot)
	tree_spot.look_at_from_position(tree_pos + Vector3(2.2, 0.2, -1.2), tree_pos + Vector3(0, 2.6, 0), Vector3.UP)
	candle_light = OmniLight.new(); candle_light.omni_range = 2.6; candle_light.light_color = Color(1, 0.7, 0.35); candle_light.light_energy = 0; candle_light.visible = false
	candle_light.translation = L(2.4, 0.4, 0)
	root.add_child(candle_light)
	in_light = OmniLight.new(); in_light.omni_range = 6; in_light.light_color = Color(1, 0.92, 0.75); in_light.light_energy = 0; in_light.visible = false
	in_light.translation = L(0.2, 1.6, 0)
	root.add_child(in_light)
	# violet mist drifting low around the planter at night
	mist = CPUParticles.new()
	var q = QuadMesh.new(); q.size = Vector2(1.1, 1.1)
	var mm = SpatialMaterial.new(); mm.flags_unshaded = true; mm.flags_transparent = true; mm.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	mm.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED; mm.albedo_texture = _t("glow", false); mm.albedo_color = Color(0.45, 0.15, 0.6, 0.18)
	q.material = mm; mist.mesh = q
	mist.amount = 22; mist.lifetime = 7.0; mist.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE; mist.emission_sphere_radius = 1.2
	mist.direction = Vector3(0, 1, 0); mist.spread = 80; mist.initial_velocity = 0.12; mist.gravity = Vector3(0, 0.02, 0)
	mist.scale_amount = 1.0; mist.scale_amount_random = 0.5
	mist.translation = tree_pos + Vector3(0, 0.75, 0); mist.emitting = false
	root.add_child(mist)

func _collision():
	W.add_box(mc.x - 1.95, 0, mc.z - 1.95, mc.x + 1.95, 4.2, mc.z + 1.95, "solid")
	W.add_box(tree_pos.x - 1.25, 0, tree_pos.z - 1.25, tree_pos.x + 1.25, 0.55, tree_pos.z + 1.25, "cover")
	W.add_box(tree_pos.x - 0.3, 0, tree_pos.z - 0.3, tree_pos.x + 0.3, 3.0, tree_pos.z + 0.3, "solid")
	var x0 = mc.x - 3.4
	var x1 = mc.x + 9.6
	var z0 = mc.z - 5.5
	var z1 = mc.z + 5.5
	for b in [[x0, z0 - 0.25, x1, z0 + 0.25], [x0, z1 - 0.25, x1, z1 + 0.25], [x0 - 0.25, z0, x0 + 0.25, z1], [x1 - 0.25, z0, x1 + 0.25, mc.z - 1.25], [x1 - 0.25, mc.z + 1.25, x1 + 0.25, z1]]:
		W.add_box(b[0], 0, b[1], b[2], 1.7, b[3], "solid")
