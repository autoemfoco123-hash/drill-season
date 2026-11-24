extends Spatial
# A person built from simple shapes, ported from the web game's buildHuman / animHuman.
# Every moving part (spine, head, each limb segment) is a pivot; all the shapes go into
# ONE skinned mesh where each pivot is a bone, so a whole person is a single draw call
# (old Intel GPUs choke on draw calls long before they choke on triangles).

var root
var hips
var spine
var head_g
var L = {}
var R = {}
var AL = {}
var AR = {}
var finger = null
var shadow = null
var gun_slot = null
var phase = 0.0
var foot = 0          # counts footfalls of the walk cycle (the player's footstep sounds follow it)
var _fc = 0
var cr = 0.0
var opts = {}
var _geo = { "v": [], "n": [], "c": [], "i": [], "b": [] }
var _bones = []         # pivots, parents always before children
var _bone_parent = []
var skel = null
var _rest = []          # each pivot's built position, to put the body back together after a ragdoll
var rag = null          # the ragdoll while it is active (see ragdoll_start)
var getup = 0.0         # 1 -> 0 while standing back up after a ragdoll

func _init():
	phase = randf() * 10.0

# ---------- geometry ----------
func _prim(kind, p):
	var key = kind + str(p)
	if G._mats.has("prim:" + key):
		return G._mats["prim:" + key]
	var m
	var pre = Basis()
	if kind == "capsule":
		m = CapsuleMesh.new(); m.radius = p[0]; m.mid_height = p[1]; m.radial_segments = 8; m.rings = 1
		pre = Basis(Vector3(1, 0, 0), PI / 2)
	elif kind == "sphere":
		m = SphereMesh.new(); m.radius = p[0]; m.height = p[0] * 2; m.radial_segments = 10; m.rings = 6
	elif kind == "hemi":
		m = SphereMesh.new(); m.radius = p[0]; m.height = p[0]; m.is_hemisphere = true; m.radial_segments = 10; m.rings = 4
	elif kind == "cyl":
		m = CylinderMesh.new(); m.top_radius = p[0]; m.bottom_radius = p[1]; m.height = p[2]; m.radial_segments = 8; m.rings = 1
	elif kind == "ring":
		# no torus in Godot 3: a short tube with the torus' axis (Z) stands in for it
		m = CylinderMesh.new(); m.top_radius = p[0] + p[1] * 0.4; m.bottom_radius = p[0] + p[1] * 0.4; m.height = p[1] * 2; m.radial_segments = 12; m.rings = 1
		pre = Basis(Vector3(1, 0, 0), PI / 2)
	else:
		m = CubeMesh.new(); m.size = Vector3(p[0], p[1], p[2])
	var a = m.get_mesh_arrays()
	var v = a[Mesh.ARRAY_VERTEX]
	var n = a[Mesh.ARRAY_NORMAL]
	if pre != Basis():
		for i in range(v.size()):
			v[i] = pre.xform(v[i]); n[i] = pre.xform(n[i])
	var out = [v, n, a[Mesh.ARRAY_INDEX]]
	G._mats["prim:" + key] = out
	return out

func _basis_xyz(rx, ry, rz):
	return Basis(Vector3(1, 0, 0), rx) * Basis(Vector3(0, 1, 0), ry) * Basis(Vector3(0, 0, 1), rz)

func _add(pivot, kind, p, col, pos = Vector3(), rot = Vector3(), scl = Vector3(1, 1, 1)):
	var g = _geo
	var bi = _bones.find(pivot)
	var pr = _prim(kind, p)
	var b = _basis_xyz(rot.x, rot.y, rot.z) * Basis().scaled(scl)
	var nb = b.inverse().transposed()
	var base = g.v.size()
	var c = col if typeof(col) == TYPE_COLOR else G.hex_color(col)
	var vv = pr[0]
	var nn = pr[1]
	for i in range(vv.size()):
		g.v.append(b.xform(vv[i]) + pos)
		g.n.append(nb.xform(nn[i]).normalized())
		g.c.append(c)
		g.b.append(bi)
	for idx in pr[2]:
		g.i.append(base + idx)

func _finish():
	skel = Skeleton.new()
	add_child(skel)
	for i in range(_bones.size()):
		skel.add_bone("b%d" % i)
		if _bone_parent[i] >= 0:
			skel.set_bone_parent(i, _bone_parent[i])
		skel.set_bone_rest(i, Transform())
	var g = _geo
	var n = g.v.size()
	var bones = PoolIntArray()
	var weights = PoolRealArray()
	bones.resize(n * 4); weights.resize(n * 4)
	for k in range(n):
		bones[k * 4] = g.b[k]; bones[k * 4 + 1] = 0; bones[k * 4 + 2] = 0; bones[k * 4 + 3] = 0
		weights[k * 4] = 1.0; weights[k * 4 + 1] = 0.0; weights[k * 4 + 2] = 0.0; weights[k * 4 + 3] = 0.0
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PoolVector3Array(g.v)
	arr[Mesh.ARRAY_NORMAL] = PoolVector3Array(g.n)
	arr[Mesh.ARRAY_COLOR] = PoolColorArray(g.c)
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = weights
	arr[Mesh.ARRAY_INDEX] = PoolIntArray(g.i)
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi = MeshInstance.new()
	mi.mesh = am
	mi.material_override = G.vc_mat()
	mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	_geo = { "v": [], "n": [], "c": [], "i": [], "b": [] }
	for b in _bones: _rest.append(b.translation)
	sync_bones()

# copy the pivots' poses onto the skeleton (bones have identity rests, so pose == pivot transform)
func sync_bones():
	if skel == null: return
	for i in range(_bones.size()):
		skel.set_bone_pose(i, _bones[i].transform)

func _pivot(parent, pos):
	var s = Spatial.new()
	s.translation = pos
	parent.add_child(s)
	_bone_parent.append(_bones.find(parent))
	_bones.append(s)
	return s

# o: the same options as the web game (skin, hair, head, top, jacket, pants, ...)
# ---------- the face: skull, jaw and chin, ears, nose, eyes, brows, lips, and the beard ----------
const BEARDS = ["None", "Full beard", "Goatee", "Stubble", "Chin strap", "Mustache"]

func _mixc(a, b, t):
	var ca = a if typeof(a) == TYPE_COLOR else G.hex_color(a)
	var cb = b if typeof(b) == TYPE_COLOR else G.hex_color(b)
	return ca.linear_interpolate(cb, t)

func _face(o, cS, cHair, cH, skimask):
	var hg = head_g
	var shade = _mixc(cS, 0x1a0e08, 0.22)
	# neck, skull, jaw and chin
	_add(spine, "cyl", [0.056, 0.064, 0.13], cS, Vector3(0, 0.73, 0.005))
	_add(hg, "sphere", [0.13], cS, Vector3(0, 0.07, -0.006), Vector3(), Vector3(0.93, 1.0, 0.98))
	_add(hg, "sphere", [0.105], cS, Vector3(0, 0.0, 0.024), Vector3(), Vector3(0.95, 0.82, 1.0))
	_add(hg, "sphere", [0.048], cS, Vector3(0, -0.056, 0.074), Vector3(), Vector3(1.12, 0.78, 0.9))
	# cheekbones
	for s in [-1, 1]:
		_add(hg, "sphere", [0.04], cS, Vector3(s * 0.06, 0.04, 0.085), Vector3(), Vector3(1.0, 0.7, 0.8))
	if skimask:
		_add(hg, "sphere", [0.136], cH, Vector3(0, 0.05, 0.0), Vector3(), Vector3(0.98, 1.12, 1.04))
		for s in [-1, 1]:
			_add(hg, "box", [0.05, 0.026, 0.01], cS, Vector3(s * 0.045, 0.08, 0.133))
			_add(hg, "sphere", [0.011], 0x2a1a10, Vector3(s * 0.045, 0.08, 0.137), Vector3(), Vector3(1, 1, 0.45))
		_add(hg, "box", [0.05, 0.018, 0.01], cS, Vector3(0, -0.012, 0.137))
		return
	# ears
	for s in [-1, 1]:
		_add(hg, "sphere", [0.033], cS, Vector3(s * 0.123, 0.052, -0.008), Vector3(0, s * 0.25, 0), Vector3(0.42, 1.0, 0.72))
		_add(hg, "sphere", [0.016], shade, Vector3(s * 0.127, 0.05, -0.004), Vector3(), Vector3(0.3, 0.9, 0.6))
	# nose: bridge, tip and the wings of the nostrils
	_add(hg, "box", [0.022, 0.05, 0.028], cS, Vector3(0, 0.058, 0.118), Vector3(-0.32, 0, 0))
	_add(hg, "sphere", [0.021], cS, Vector3(0, 0.03, 0.133), Vector3(), Vector3(1.15, 0.95, 1.0))
	for s in [-1, 1]:
		_add(hg, "sphere", [0.013], shade, Vector3(s * 0.016, 0.022, 0.126), Vector3(), Vector3(1.0, 0.8, 0.9))
	# eyes: whites, irises, upper lids; brows
	for s in [-1, 1]:
		_add(hg, "sphere", [0.019], 0xe9e4dc, Vector3(s * 0.045, 0.078, 0.108), Vector3(), Vector3(1.2, 0.8, 0.6))
		_add(hg, "sphere", [0.0105], 0x24160d, Vector3(s * 0.045, 0.077, 0.116), Vector3(), Vector3(1, 1, 0.45))
		_add(hg, "box", [0.046, 0.009, 0.014], shade, Vector3(s * 0.045, 0.092, 0.112), Vector3(0.25, 0, s * 0.06))
		_add(hg, "box", [0.054, 0.014, 0.016], cHair, Vector3(s * 0.047, 0.112, 0.114), Vector3(0.15, 0, s * 0.1))
	# lips
	var lip = _mixc(cS, 0x5a2420, 0.35)
	var beard = int(o.get("beard", 0)) if typeof(o.get("beard", 0)) != TYPE_BOOL else (1 if o.get("beard") else 0)
	if o.get("mask") != null: beard = 0
	var lz = 0.137 if beard == 1 else 0.126
	_add(hg, "box", [0.05, 0.011, 0.012], _mixc(lip, 0x000000, 0.25), Vector3(0, -0.011, lz))
	_add(hg, "box", [0.044, 0.013, 0.012], lip, Vector3(0, -0.024, lz - 0.003))
	if o.get("grill", false):
		_add(hg, "box", [0.04, 0.008, 0.006], 0xe2b64a, Vector3(0, -0.0175, lz + 0.004))
	# the beard
	var bc = cHair
	if beard == 1 or beard == 3:
		if beard == 3: bc = _mixc(cS, cHair, 0.55)
		_add(hg, "sphere", [0.112], bc, Vector3(0, -0.006, 0.026), Vector3(), Vector3(0.96, 0.84, 1.03))
		_add(hg, "sphere", [0.052], bc, Vector3(0, -0.062, 0.078), Vector3(), Vector3(1.15, 0.85, 0.95))
		for s in [-1, 1]:
			_add(hg, "box", [0.018, 0.07, 0.04], bc, Vector3(s * 0.112, 0.045, 0.01), Vector3(0, 0, s * 0.05))
	if beard == 1 or beard == 2 or beard == 5:
		_add(hg, "box", [0.062, 0.013, 0.016], cHair, Vector3(0, 0.004, lz + 0.002), Vector3(0, 0, 0))
		for s in [-1, 1]:
			_add(hg, "box", [0.012, 0.03, 0.012], cHair, Vector3(s * 0.033, -0.01, lz - 0.002))
	if beard == 2:
		_add(hg, "sphere", [0.034], cHair, Vector3(0, -0.06, 0.098), Vector3(), Vector3(1.0, 1.15, 0.85))
	if beard == 4:
		for k in range(11):
			var a = -PI * 0.5 + PI * k / 10.0
			_add(hg, "box", [0.026, 0.018, 0.022], cHair, Vector3(sin(a) * 0.1, -0.03 - cos(a) * 0.04, 0.03 + cos(a) * 0.075), Vector3(0, a, 0))
	if o.get("mask") != null:
		_add(hg, "sphere", [0.138], o["mask"], Vector3(0, 0.03, 0.01), Vector3(), Vector3(0.97, 0.6, 1.03))
	if o.get("glasses", false):
		_add(hg, "box", [0.21, 0.048, 0.02], 0x0b0b0d, Vector3(0, 0.085, 0.124))

func build(o):
	opts = o
	_idle_t = randf() * 40.0      # everyone breathes and looks around on their own time
	var top = o.get("top", "parka" if o.get("coat", false) else "puffer")
	var head = o.get("head", "cap" if o.get("cap", false) else ("beanie" if o.get("hat") != null else "none"))
	var build_k = int(o.get("build", 1))
	var bw = 0.92 if build_k == 0 else (1.15 if build_k == 2 else 1.0)
	var cJ = o.get("jacket", 0x262b33)
	var cJ2 = o.get("jacket2", cJ)
	var cP = o.get("pants", 0x1b2533)
	var cS = o.get("skin", 0x6b4630)
	var cH = o.get("hat", 0x15171a) if o.get("hat") != null else 0x15171a
	var cShoe = o.get("shoes", 0x15171a)
	var cHair = o.get("hairCol", 0x0f0d0c)
	var cDark = 0x0b0b0d
	var cGold = 0xd4a640
	var cSleeve = cJ2 if top in ["varsity", "jersey"] else cJ
	var cHand = o.get("gloves", cS)
	root = _pivot(self, Vector3())
	hips = _pivot(root, Vector3(0, 0.92, 0))
	spine = _pivot(hips, Vector3())
	_add(spine, "capsule", [0.25, 0.36], cJ, Vector3(0, 0.36, 0), Vector3(), Vector3(1.12 * bw, 1, 0.8 * bw))
	if top == "puffer":
		for y in [0.2, 0.42]:
			_add(spine, "ring", [0.255, 0.045], cJ2, Vector3(0, y, 0), Vector3(PI / 2, 0, 0), Vector3(1.13 * bw, 0.82, 1))
	if top == "parka":
		_add(spine, "cyl", [0.27, 0.34, 0.6], cJ, Vector3(0, 0.05, 0), Vector3(), Vector3(bw, 1, 0.82 * bw))
		_add(spine, "ring", [0.255, 0.045], cJ2, Vector3(0, 0.42, 0), Vector3(PI / 2, 0, 0), Vector3(1.13 * bw, 0.82, 1))
	if top == "hoodie":
		_add(spine, "box", [0.075, 0.1, 0.03], cJ2, Vector3(0, 0.2, 0.2 * bw), Vector3(), Vector3(2.2, 1, 1))
	if top == "jersey":
		# an oversized jersey over a hoodie: big front numbers, trim at the neck and hem
		for nx in [-0.045, 0.045]:
			_add(spine, "box", [0.022, 0.13, 0.01], cJ2, Vector3(nx, 0.34, 0.205 * bw))
		_add(spine, "ring", [0.14, 0.022], cJ2, Vector3(0, 0.6, 0), Vector3(PI / 2, 0, 0), Vector3(1, 1, 0.7))
		_add(spine, "ring", [0.255, 0.02], cJ2, Vector3(0, 0.06, 0), Vector3(PI / 2, 0, 0), Vector3(1.13 * bw, 0.82, 1))
	if top == "shearling":
		# a long coat with a thick fur collar and fur down the front
		_add(spine, "cyl", [0.27, 0.35, 0.62], cJ, Vector3(0, 0.04, 0), Vector3(), Vector3(bw, 1, 0.82 * bw))
		_add(spine, "ring", [0.16, 0.055], cJ2, Vector3(0, 0.6, 0), Vector3(PI / 2, 0, 0), Vector3(1.05, 1, 0.78))
		for fx in [-0.06, 0.06]:
			_add(spine, "box", [0.04, 0.5, 0.025], cJ2, Vector3(fx, 0.3, 0.2 * bw))
	if top in ["track", "leather", "varsity"]:
		_add(spine, "box", [0.012, 0.42, 0.012], cJ2 if top == "track" else cDark, Vector3(0, 0.36, 0.205 * bw))
	if top in ["leather", "varsity"]:
		_add(spine, "ring", [0.145, 0.032], cJ2, Vector3(0, 0.6, 0), Vector3(PI / 2, 0, 0), Vector3(1, 1, 0.7))
	if o.get("chain", false):
		for k in range(10):
			var a = PI * 0.15 + k / 9.0 * PI * 0.7
			_add(spine, "sphere", [0.02], cGold, Vector3(cos(a) * 0.13, 0.58 - sin(a) * 0.1, 0.16 + sin(a) * 0.04))
	var bag = o.get("bag", null)
	if o.get("pack") != null or bag == "back":
		_add(spine, "box", [0.3, 0.36, 0.14], o.get("pack", o.get("bagCol", 0x15171a)) if o.get("pack") != null else o.get("bagCol", 0x15171a), Vector3(0, 0.36, -0.24 * bw))
	if bag == "cross":
		var cb = o.get("bagCol", 0x15171a)
		_add(spine, "box", [0.03, 0.66, 0.012], cb, Vector3(0, 0.36, 0.205 * bw), Vector3(0, 0, 0.75))
		_add(spine, "box", [0.21, 0.15, 0.075], cb, Vector3(-0.17, 0.12, 0.17 * bw))
	if o.get("badge", false):
		_add(spine, "box", [0.06, 0.07, 0.02], cGold, Vector3(0.12, 0.52, 0.2))
	head_g = _pivot(spine, Vector3(0, 0.78, 0))
	var skimask = head == "skimask"
	_face(o, cS, cHair, cH, skimask)
	var hair = o.get("hair", "none")
	var covers = head in ["beanie", "durag", "skimask", "hood", "bucket"]
	if hair != "none" and not skimask:
		if hair == "afro":
			if covers or head in ["cap", "capback"]:
				_add(head_g, "sphere", [0.19], cHair, Vector3(0, 0.06, -0.02), Vector3(), Vector3(0.9, 0.62, 0.9))
			else:
				_add(head_g, "sphere", [0.19], cHair, Vector3(0, 0.125, -0.05), Vector3(), Vector3(0.95, 0.86, 0.84))
		elif not covers:
			var bz = hair == "buzz"
			_add(head_g, "hemi", [0.137], cHair, Vector3(0, 0.07, -0.003), Vector3(), Vector3(0.99 if bz else 1.04, 0.96 if bz else 1.08, 0.99 if bz else 1.06))
		if hair == "twists" and not covers:
			for k in range(9):
				var a2 = k / 9.0 * TAU
				_add(head_g, "sphere", [0.05], cHair, Vector3(cos(a2) * 0.08, 0.17 + (k % 2) * 0.02, sin(a2) * 0.08 - 0.01))
		if hair == "locs":
			for k in range(8):
				var a3 = PI * 0.15 + k / 7.0 * PI * 0.7
				_add(head_g, "cyl", [0.019, 0.014, 0.27], cHair, Vector3(cos(a3) * 0.12, -0.05, -sin(a3) * 0.1), Vector3(-0.2, 0, 0))
		if hair == "braids":
			for s2 in [-1, 1]:
				_add(head_g, "cyl", [0.024, 0.015, 0.32], cHair, Vector3(s2 * 0.06, -0.06, -0.11), Vector3(0.35, 0, s2 * 0.1))
		if hair == "dreads":
			# long dreads around the sides and back, down past the shoulders
			for k in range(15):
				var a4 = PI * 0.02 + k / 14.0 * PI * 0.96
				var ln = 0.36 + (k % 3) * 0.045
				_add(head_g, "cyl", [0.021, 0.015, ln], cHair, Vector3(cos(a4) * 0.13, 0.11 - ln * 0.5, -sin(a4) * 0.118 - 0.01), Vector3(sin(a4) * 0.16, 0, cos(a4) * 0.16))
		if hair == "hightop" and not covers and not head in ["cap", "capback"]:
			_add(head_g, "cyl", [0.118, 0.132, 0.17], cHair, Vector3(0, 0.215, -0.012))
		if hair == "freeform" and not covers:
			# chunky locs that stand up and out
			for k in range(11):
				var a5 = k / 11.0 * TAU
				var r5 = 0.065 + (k % 2) * 0.035
				var ln5 = 0.12 + (k % 3) * 0.035
				_add(head_g, "cyl", [0.03, 0.022, ln5], cHair, Vector3(cos(a5) * r5, 0.18 + ln5 * 0.3, sin(a5) * r5 - 0.02), Vector3(sin(a5) * 0.55, 0, -cos(a5) * 0.55))
		if hair == "cornrows" and not covers:
			# partings between the rows, following the curve of the head
			var part = _mixc(cS, 0x000000, 0.2)
			for rx in [-0.06, -0.03, 0.0, 0.03, 0.06]:
				var rr = sqrt(max(0.0, 0.145 * 0.145 - rx * rx))
				for j in range(5):
					var t = -1.0 + j * 0.5
					_add(head_g, "box", [0.006, 0.005, 0.05], part, Vector3(rx, 0.07 + rr * cos(t) * 1.05, rr * sin(t) * 1.03), Vector3(-t, 0, 0))
	if head == "beanie":
		_add(head_g, "hemi", [0.142], cH, Vector3(0, 0.065, 0), Vector3(), Vector3(1, 1.25, 1))
		if o.get("pom", false):
			var pc = o["pom"] if typeof(o["pom"]) == TYPE_INT and o["pom"] > 1 else o.get("hat", 0xffffff)
			_add(head_g, "sphere", [0.045], pc, Vector3(0, 0.23, 0))
	elif head == "cap" or head == "capback":
		_add(head_g, "cyl", [0.15, 0.145, 0.09], cH, Vector3(0, 0.15, 0))
		_add(head_g, "box", [0.22, 0.02, 0.12], cH, Vector3(0, 0.11, 0.12 if head == "cap" else -0.12))
	elif head == "durag":
		_add(head_g, "hemi", [0.142], cH, Vector3(0, 0.06, 0), Vector3(), Vector3(1, 1.2, 1))
		_add(head_g, "box", [0.06, 0.24, 0.012], cH, Vector3(0, -0.06, -0.135), Vector3(0.15, 0, 0))
	elif head == "bucket":
		_add(head_g, "cyl", [0.125, 0.148, 0.11], cH, Vector3(0, 0.165, 0))
		_add(head_g, "cyl", [0.225, 0.225, 0.016], cH, Vector3(0, 0.115, 0), Vector3(-0.05, 0, 0))
	elif head == "hood":
		_add(head_g, "hemi", [0.172], cJ2, Vector3(0, 0.0, -0.035), Vector3(-0.5, 0, 0), Vector3(1, 1.3, 1.05))
	elif head == "goggles":
		# ski goggles pushed up on the forehead, strap around the head
		_add(head_g, "ring", [0.143, 0.011], cH, Vector3(0, 0.13, -0.004), Vector3(PI / 2 - 0.3, 0, 0))
		_add(head_g, "box", [0.21, 0.07, 0.035], cH, Vector3(0, 0.15, 0.118), Vector3(-0.35, 0, 0))
		_add(head_g, "box", [0.19, 0.052, 0.02], 0xd8742a, Vector3(0, 0.152, 0.134), Vector3(-0.35, 0, 0))
	elif head == "headphones":
		_add(head_g, "box", [0.3, 0.025, 0.04], cH, Vector3(0, 0.2, 0))
		for s3 in [-1, 1]:
			_add(head_g, "cyl", [0.058, 0.058, 0.045], cH, Vector3(s3 * 0.14, 0.06, 0), Vector3(0, 0, PI / 2))
	if o.get("hood", false) or ((top == "hoodie" or top == "parka") and head != "hood"):
		_add(head_g, "sphere", [0.13], cJ2, Vector3(0, -0.03, -0.1), Vector3(), Vector3(1.1, 0.45, 0.55))
	var leg_s = 1.16 if o.get("pantsStyle", "") == "ski" else 1.0
	var shoe = o.get("shoe", "sneaker")
	for side in [-1, 1]:
		var thigh = _pivot(hips, Vector3(0.115 * side * bw, 0.02, 0))
		_add(thigh, "capsule", [0.088, 0.3], cP, Vector3(0, -0.22, 0), Vector3(), Vector3(leg_s * bw, 1, leg_s * bw))
		if o.get("pantsStyle", "") in ["joggers", "track"]:
			_add(thigh, "box", [0.022, 0.24, 0.022], o.get("pants2", 0xe8e8ea), Vector3(side * 0.088 * bw, -0.22, 0), Vector3(), Vector3(1, 1.5, 1))
		var knee = _pivot(thigh, Vector3(0, -0.45, 0))
		_add(knee, "capsule", [0.078, 0.3], cP, Vector3(0, -0.2, 0), Vector3(), Vector3(leg_s, 1, leg_s))
		if shoe == "boot":
			_add(knee, "box", [0.145, 0.19, 0.29], cShoe, Vector3(0, -0.39, 0.04))
		else:
			_add(knee, "box", [0.13, 0.09, 0.27], cShoe, Vector3(0, -0.42, 0.045))
			_add(knee, "box", [0.138, 0.03, 0.28], 0xe8e8ea if shoe == "high" else 0xf2f2f2, Vector3(0, -0.468, 0.045))
			if shoe == "high":
				_add(knee, "cyl", [0.078, 0.084, 0.13], cShoe, Vector3(0, -0.33, 0.01))
		var leg = { "thigh": thigh, "knee": knee }
		if side < 0: L = leg
		else: R = leg
	for side2 in [-1, 1]:
		var sh = _pivot(spine, Vector3(0.31 * side2 * bw, 0.6, 0))
		_add(sh, "capsule", [0.078, 0.22], cSleeve, Vector3(0, -0.15, 0), Vector3(), Vector3(bw, 1, bw))
		var elbow = _pivot(sh, Vector3(0, -0.3, 0))
		_add(elbow, "capsule", [0.066, 0.2], cSleeve, Vector3(0, -0.13, 0), Vector3(), Vector3(bw, 1, bw))
		if o.get("watch", false) and side2 < 0:
			_add(elbow, "box", [0.065, 0.032, 0.065], cGold, Vector3(0, -0.24, 0))
		var hand = _pivot(elbow, Vector3(0, -0.29, 0))
		_add(hand, "sphere", [0.055], cHand)
		var arm = { "sh": sh, "elbow": elbow, "hand": hand }
		if side2 < 0: AL = arm
		else: AR = arm
	_finish()
	# the middle finger, only shown for the gesture
	var fm = CapsuleMesh.new(); fm.radius = 0.017; fm.mid_height = 0.085; fm.radial_segments = 6; fm.rings = 1
	finger = MeshInstance.new(); finger.mesh = fm; finger.material_override = G.mat(G.hex_color(cHand))
	finger.translation = Vector3(0, -0.1, 0.006); finger.rotation = Vector3(PI / 2, 0, 0); finger.visible = false
	AL.hand.add_child(finger)
	gun_slot = Spatial.new(); AR.hand.add_child(gun_slot)
	# a soft dark spot under the feet
	var sm = CylinderMesh.new(); sm.top_radius = 0.42; sm.bottom_radius = 0.42; sm.height = 0.01; sm.radial_segments = 12
	var smat = SpatialMaterial.new(); smat.flags_unshaded = true; smat.flags_transparent = true; smat.albedo_color = Color(0, 0, 0, 0.3)
	shadow = MeshInstance.new(); shadow.mesh = sm; shadow.material_override = smat; shadow.translation = Vector3(0, 0.03, 0)
	shadow.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	if o.get("scale") != null:
		root.scale = Vector3.ONE * o["scale"]
		sync_bones()
	return self

# ---------- animation (same numbers as the web game) ----------
var _cur = {}            # each joint's angles as shown now (eased toward the pose)
var _last_yaw = 0.0
var _lean = 0.0
var _spd = 0.0
var _idle_t = 0.0
var _skip = 0
var _skip_dt = 0.0
# the layers on top of the gait (see animate)
var _prev_sp = 0.0
var _acc_l = 0.0          # forward acceleration, smoothed: lean into it, rock back when stopping
var _exert = 0.0          # 0..1, builds while running: heavier, faster breathing afterwards
var _br_ph = 0.0
var _air = 0.0
var _was_air = false
var _land = 0.0
var _turn = 0.0           # turning on the spot: small steps
var _look = 0.0
var _sway = Vector2()      # sitting in a car: what the car's doing to you (side, fore-aft)

# one leg: the thigh swings, the knee folds on the way forward. ex adds the other layers:
# (thigh forward, knee bend, thigh out to the side)
func _leg(leg, p, side, thA, swK, kB, run, amp, still, c, k, ex = Vector3()):
	var th = sin(p) * thA - run * 0.1 * amp
	var f = max(0.0, -cos(p - 0.2))
	var kn = kB + swK * f * sqrt(f)
	_srot(leg.thigh, Vector3(lerp(th, -1.25 + th * 0.3, c) + ex.x, 0, side * 0.03 * still + ex.z), k)
	_srot(leg.knee, Vector3(lerp(kn, 2.0, c) + ex.y, 0, 0), k)

func _rot(n, x, y, z):
	n.transform.basis = _basis_xyz(x, y, z)
	_cur[n] = Vector3(x, y, z)

# ease a joint toward an angle, so poses blend instead of snapping
func _srot(n, t, k):
	var c = _cur.get(n)
	if c != null and k < 1.0:
		t = c.linear_interpolate(t, k)
	_rot(n, t.x, t.y, t.z)

func animate(dt, pose):
	if rag != null:
		ragdoll_update(dt)
		return
	if pose.get("seat", false):
		_seated(dt, pose)
		return
	if getup > 0:
		getup = max(0.0, getup - dt * 1.6)
		pose["down"] = max(pose.get("down", 0.0), getup)
	# far from the camera: animate every third frame (nobody can tell at that distance)
	var first = _cur.empty()
	if not first and pose.get("emote", "") == "" and pose.get("down", 0.0) == 0 and getup <= 0:
		var gp = global_transform.origin
		if (gp - G.cam_pos).length_squared() > 900.0:
			_skip_dt += dt
			_skip = (_skip + 1) % 3
			if _skip != 0: return
			dt = _skip_dt
	_skip_dt = 0.0
	# ---- the gait: walk and run cycles blended by speed, the stride matched to the ground ----
	if first: _last_yaw = rotation.y
	var sp = pose.get("speed", 0.0)
	_spd = lerp(_spd, sp, 1 - exp(-dt * 8)) if not first else sp
	var s = _spd
	var run = clamp((s - 2.2) / 2.6, 0.0, 1.0)          # 0 walking .. 1 running
	var amp = clamp(s / 1.3, 0.0, 1.0)                  # 0 standing .. 1 on the move
	var stride = lerp(1.45, 3.1, run)                   # metres per cycle (two steps)
	if s > 0.12: phase += dt * TAU * s / stride
	# turning on the spot: the feet step round instead of sliding
	var yr = G.ang_diff(_last_yaw, rotation.y) / max(dt, 0.001) if not first else 0.0
	_last_yaw = rotation.y
	_turn = lerp(_turn, clamp(abs(yr) / 3.5, 0.0, 1.0) * (1.0 - amp), 1 - exp(-dt * 10))
	if s <= 0.12 and _turn > 0.05: phase += dt * TAU * 1.3 * _turn
	var leg_amp = max(amp, _turn * 0.45)
	# accelerating and stopping: the body leans into it and rocks back
	var acc_raw = (_spd - _prev_sp) / max(dt, 0.001) if not first else 0.0
	_prev_sp = _spd
	_acc_l = lerp(_acc_l, clamp(acc_raw, -10.0, 10.0), 1 - exp(-dt * 6))
	# breathing: slow and small standing, quick and deep after a run
	_exert = clamp(_exert + dt * (run * amp * 0.12 - 0.035), 0.0, 1.0)
	_br_ph += dt * TAU * lerp(0.26, 0.85, _exert)
	var breath = sin(_br_ph)
	# off the ground: knees tuck; touching down: a soft dip
	var in_air = pose.get("air", false) == true
	if _was_air and not in_air: _land = 1.0
	_was_air = in_air
	_air = lerp(_air, 1.0 if in_air else 0.0, 1 - exp(-dt * 10))
	_land *= exp(-dt * 7.0)
	# a foot lands each time the cycle passes a quarter turn (the thigh at its furthest forward)
	var fc = int(floor((phase - PI * 0.5) / PI))
	if first: _fc = fc
	elif fc != _fc:
		_fc = fc; foot += 1
	var ph = phase
	_idle_t += dt
	# where you look: the head goes most of the way, the chest a little (not past the shoulders)
	var lk = float(pose.get("look", 0.0))
	var lk_k = clamp(lk, -1.25, 1.25) * clamp((2.7 - abs(lk)) / 0.7, 0.0, 1.0)
	_look = lerp(_look, lk_k, 1 - exp(-dt * 7)) if not first else lk_k
	var kl = 1.0 if first else 1 - exp(-dt * 22)        # legs follow fast
	var ka = 1.0 if first else 1 - exp(-dt * 14)        # arms a little softer
	var kb = 1.0 if first else 1 - exp(-dt * 9)         # body and head softest
	var crouch = 1.0 if pose.get("crouch", false) else 0.0
	if typeof(pose.get("crouch")) == TYPE_REAL:
		crouch = pose["crouch"]
	cr = lerp(cr, crouch, 1 - exp(-dt * 12))
	var c = cr
	# leaning into turns
	_lean = lerp(_lean, clamp(-yr * s * 0.035, -0.28, 0.28), 1 - exp(-dt * 6))
	var still = 1.0 - amp
	# standing about: the weight drifts from one leg to the other every few seconds (the free
	# knee bends, the hip drops on that side, the shoulders tilt back the other way)
	var aim0 = pose.get("aim", 0.0)
	var wsk = still * (1.0 - aim0) * (1.0 - c) * (1.0 - _turn)
	var ws0 = sin(_idle_t * 0.42 + float(get_instance_id() % 97))
	var ws = sign(ws0) * sqrt(abs(ws0)) * wsk
	# hips: bob (low between steps when walking, low on landing when running), sway, twist
	var bob = lerp(-0.035 * abs(sin(ph)), -0.06 * (1.0 - abs(sin(ph))), run) * amp
	var br_amp = lerp(0.006, 0.02, _exert) * (1.0 - amp * 0.6)
	hips.translation.y = lerp(0.92, 0.56, c) + bob - run * 0.035 * amp - abs(ws) * 0.012 - _land * 0.1 - _air * 0.05 - _turn * 0.012 * abs(sin(ph))
	hips.translation.x = -0.025 * cos(ph) * (1.0 - run) * amp + ws * 0.035
	var hip_roll = ws * 0.075
	_srot(hips, Vector3(0, 0.1 * sin(ph) * amp, 0.04 * cos(ph) * (1.0 - run) * amp + hip_roll), kb)
	# legs: the thigh swings, the knee folds on the swing forward (more when running); the
	# layers add the free knee, the tuck in the air and the dip on landing, and keep the feet
	# planted under a shifting pelvis
	var thA = lerp(0.42, 0.8, run) * leg_amp
	var swK = lerp(1.0, 1.75, run) * leg_amp
	var kB = lerp(0.07, 0.28, run) * leg_amp + 0.05
	var plant = -hip_roll - ws * 0.038
	var exL = Vector3(-0.09 * max(0.0, ws) - 0.55 * _air - 0.3 * _land, 0.24 * max(0.0, ws) + 1.0 * _air + 0.62 * _land, plant)
	var exR = Vector3(-0.09 * max(0.0, -ws) - 0.25 * _air - 0.3 * _land, 0.24 * max(0.0, -ws) + 0.75 * _air + 0.62 * _land, plant)
	_leg(L, ph, -1.0, thA, swK, kB, run, leg_amp, still, c, kl, exL)
	_leg(R, ph + PI, 1.0, thA, swK, kB, run, leg_amp, still, c, kl, exR)
	var acc_lean = clamp(_acc_l * 0.016, -0.13, 0.17) * (1.0 - c) * (1.0 - _air)
	var spine_x = lerp(0.05 + run * 0.2, 0.35, c) * max(amp, c) + lerp(0.04, 0.0, amp) + breath * br_amp + acc_lean + _land * 0.22 + _air * 0.08
	var spine_y = -0.16 * sin(ph) * amp + _look * 0.3 * (1.0 - run * 0.7)
	var spine_z = -ws * 0.09
	# arms: swing opposite the legs, elbows bend more when running, a little out to the sides
	var aim = pose.get("aim", 0.0)
	var pitch = pose.get("pitch", 0.0)
	var armA = lerp(0.38, 0.95, run) * amp
	var elb = lerp(-0.2, -1.45, run * amp)
	var sway = sin(_idle_t * 1.7) * 0.02 * still + breath * br_amp * 0.6 + _air * 0.45
	var relax_l = Vector3(-armA * sin(ph) - run * 0.15 * amp, 0, -0.07 - run * 0.06 - sway)
	var relax_r = Vector3(armA * sin(ph) - run * 0.15 * amp, 0, 0.07 + run * 0.06 + sway)
	var ale_rel = elb - 0.18 * max(0.0, sin(ph)) * (1.0 - run) * amp
	var are_rel = elb - 0.18 * max(0.0, -sin(ph)) * (1.0 - run) * amp
	if pose.get("carry", false):
		relax_r = Vector3(-0.45, 0, 0.08); are_rel = -0.5
	var ar = Vector3(lerp(relax_r.x, -PI / 2 - pitch - spine_x, aim), 0, lerp(relax_r.z, 0.0, aim))
	var are = lerp(are_rel, -0.05, aim)
	var two = 1.0 if pose.get("twoHand", false) else 0.85
	var al = Vector3(lerp(relax_l.x, -PI / 2 - pitch - spine_x + 0.15, aim * two), 0, lerp(relax_l.z, -0.55, aim))
	var ale = lerp(ale_rel, -0.35, aim)
	if pose.get("wave", false):
		al = Vector3(-2.6, 0, -0.3 + sin(G.REAL_T * 8) * 0.25); ale = -0.4
	if pose.get("flip", false):
		# arm up and out to the side, so the finger shows from behind and while running
		al = Vector3(-2.5 + sin(G.REAL_T * 9) * 0.06, 0, -0.55); ale = -0.6
	if pose.get("mug", false):
		al = Vector3(-0.9, 0, -0.1); ale = -1.4
	if pose.get("hands", false):
		al = Vector3(-2.9, 0, -0.25); ale = -0.35; ar = Vector3(-2.9, 0, 0.25); are = -0.35
	if pose.get("pose", false):
		ar = Vector3(-1.9, 0, 0.3); are = -1.2; al.x = -0.4; spine_x = -0.08
	# reloading: the gun comes down and in, the other hand goes to it, down for a fresh mag
	# and back up; firing kicks the arms up a little
	var ru = pose.get("reload", -1.0)
	if ru >= 0.0 and not pose.get("hands", false):
		# the gun comes down in front of the chest (like holding a phone), the other hand meets
		# it, drops to the hip for a fresh mag, and comes back
		var tl = min(clamp(ru / 0.15, 0.0, 1.0), clamp((1.0 - ru) / 0.12, 0.0, 1.0))
		ar = Vector3(lerp(ar.x, -0.9, tl), 0, lerp(ar.z, 0.12, tl)); are = lerp(are, -0.75, tl)
		var dn2 = clamp(min((ru - 0.25) / 0.12, (0.72 - ru) / 0.12), 0.0, 1.0)
		if tl > 0.3:
			al = Vector3(lerp(-0.8, 0.1, dn2), 0, lerp(-0.3, -0.08, dn2))
			ale = lerp(-0.6, -0.25, dn2)
	var kick = pose.get("kick", 0.0)
	if kick > 0.01:
		ar.x -= 0.16 * kick
		if pose.get("twoHand", false): al.x -= 0.12 * kick
		spine_x -= 0.03 * kick
	var snap = false
	if pose.get("fists", false) and pose.get("down", 0.0) == 0:
		var gk = 1.0 if pose.get("guard", false) else 0.6
		al = Vector3(lerp(al.x, -1.0, gk), 0, lerp(al.z, 0.32, gk)); ale = lerp(ale, -1.95, gk)
		ar = Vector3(lerp(ar.x, -1.0, gk), 0, lerp(ar.z, -0.32, gk)); are = lerp(are, -1.95, gk)
		var pt = pose.get("punch", 0.0)
		if pt > 0:
			snap = true
			var sd = -1 if pose.get("punchSide", 1) < 0 else 1
			var e = sin(clamp(pt, 0, 1) * PI)
			var hook = pose.get("hook", false)
			var px = lerp(-1.0, -1.4 if hook else -1.62, e)
			var pe = lerp(-1.95, -1.15 if hook else -0.08, e)
			var pz = -sd * lerp(0.32, 0.95 if hook else 0.1, e)
			if sd < 0:
				al = Vector3(px, 0, pz); ale = pe
			else:
				ar = Vector3(px, 0, pz); are = pe
			spine_y = -sd * 0.42 * e
	var kk = 1.0 if snap else ka
	_srot(AR.sh, Vector3(ar.x, 0, ar.z), kk); _srot(AR.elbow, Vector3(are, 0, 0), kk)
	_srot(AL.sh, Vector3(al.x, 0, al.z), kk); _srot(AL.elbow, Vector3(ale, 0, 0), kk)
	finger.visible = pose.get("flip", false)
	if pose.get("shiver", false):
		spine_z += sin(G.REAL_T * 40) * 0.015
	_srot(spine, Vector3(spine_x, spine_y, spine_z), 1.0 if snap else kb)
	# the head keeps the eyes level, follows where you look (up and down too), glances around
	# when standing, and tilts: into a turn, with the weight shift, a cock now and then
	var glance = (sin(_idle_t * 0.37) * 0.22 + sin(_idle_t * 0.11) * 0.12) * still * (1.0 - aim) * (1.0 - min(1.0, abs(_look) * 2.0))
	var head_x = lerp(-spine_x * 0.7 - pitch * 0.4, -pitch * 0.6, aim) - breath * br_amp * 0.5
	var head_y = -spine_y * 0.8 + glance + _look * 0.75 * (1.0 - aim)
	var cock = sin(_idle_t * 0.23 + 1.3) * sin(_idle_t * 0.61) * 0.09 * still * (1.0 - aim)
	var head_z = _lean * 0.4 + ws * 0.11 + cock - _look * 0.1 * (1.0 - aim)
	_srot(head_g, Vector3(head_x, head_y, head_z), kb)
	var em = pose.get("emote", "")
	if em != "":
		_emote(em, float(pose.get("et", 0.0)))
	var dn = pose.get("down", 0.0)
	_rot(root, -dn * PI / 2 * 0.96, 0, _lean * (1.0 - dn))
	root.translation = Vector3(0, dn * 0.18, -dn * 0.5)
	shadow.visible = dn < 0.5
	sync_bones()


# riding in a car: thighs along the seat, shins down, hands in the lap; the body sways
# out of the corners and rocks with the throttle and the brakes, the head looks around
func _seated(dt, pose):
	var k = 1.0 if _cur.empty() else 1 - exp(-dt * 10)
	var sw = pose.get("sway", Vector2())
	_sway = _sway.linear_interpolate(Vector2(clamp(sw.x, -10.0, 10.0), clamp(sw.y, -10.0, 10.0)), min(1.0, dt * 4.0))
	_idle_t += dt
	var lat = _sway.x * 0.014
	var lon = _sway.y * 0.011
	hips.translation = Vector3(0, 0.92, 0)
	_srot(hips, Vector3(0, 0, 0), k)
	_srot(L.thigh, Vector3(-1.42, 0, -0.1), k); _srot(R.thigh, Vector3(-1.42, 0, 0.1), k)
	_srot(L.knee, Vector3(1.38, 0, 0), k); _srot(R.knee, Vector3(1.38, 0, 0), k)
	var breath = sin(_idle_t * 1.7) * 0.01
	_srot(spine, Vector3(-0.14 - lon + breath, sin(_idle_t * 0.21) * 0.06, lat), k)
	_srot(AL.sh, Vector3(-0.5, 0, -0.08), k); _srot(AL.elbow, Vector3(-0.95, 0, 0), k)
	_srot(AR.sh, Vector3(-0.5, 0, 0.08), k); _srot(AR.elbow, Vector3(-0.95, 0, 0), k)
	var glance = sin(_idle_t * 0.37 + float(get_instance_id() % 13)) * 0.4 + sin(_idle_t * 0.13) * 0.3 + float(pose.get("look", 0.0))
	_srot(head_g, Vector3(0.1 + lon * 0.5, clamp(glance, -1.2, 1.2), -lat * 0.6), k)
	_rot(root, 0, 0, 0)
	root.translation = Vector3()
	finger.visible = false
	shadow.visible = false
	sync_bones()

# ---------- ragdoll ----------
# A verlet ragdoll: 15 points (pelvis, chest, head, hips, knees, feet, shoulders, elbows,
# hands) held together by distance constraints, falling under gravity and pushed out of the
# city's boxes. Every frame the pivots are aimed along the points, so the same skinned mesh
# flops around. Cheap enough for a dozen bodies on an old CPU.
const RAG_LINKS = [[0, 1], [1, 2], [0, 3], [0, 6], [3, 6], [3, 4], [4, 5], [6, 7], [7, 8], [1, 9], [1, 12], [9, 12], [9, 10], [10, 11], [12, 13], [13, 14],
	[0, 9], [0, 12], [3, 1], [6, 1], [2, 9], [2, 12]]
const RAG_MIN = [[3, 5, 0.55], [6, 8, 0.55], [9, 11, 0.45], [12, 14, 0.45], [2, 0, 0.9], [5, 1, 0.6], [8, 1, 0.6]]

func ragdoll_active():
	return rag != null and not rag.rest

func is_ragdoll():
	return rag != null

func _gp(n, off = Vector3()):
	return n.global_transform.xform(off)

# impulse: metres per second added to the whole body (plus a bit of spin from 'twist')
func ragdoll_start(vel = Vector3(), impulse = Vector3(), twist = 0.0):
	if skel == null: return
	if rag != null:
		# already flopping: just add the new push
		for i in range(rag.p.size()):
			rag.o[i] -= (impulse + Vector3(0, impulse.length() * 0.15, 0)) / 60.0
		rag.rest = false; rag.still = 0.0
		return
	getup = 0.0
	var pts = [_gp(hips), _gp(spine, Vector3(0, 0.6, 0)), _gp(head_g, Vector3(0, 0.06, 0)),
		_gp(L.thigh), _gp(L.knee), _gp(L.knee, Vector3(0, -0.42, 0.04)), _gp(R.thigh), _gp(R.knee), _gp(R.knee, Vector3(0, -0.42, 0.04)),
		_gp(AL.sh), _gp(AL.elbow), _gp(AL.hand), _gp(AR.sh), _gp(AR.elbow), _gp(AR.hand)]
	var old = []
	var dt0 = 1.0 / 60.0
	var c = pts[0]
	var up = Vector3.UP
	for i in range(pts.size()):
		# the higher a point, the more the push tips it over; twist spins the body
		var v = vel + impulse * (0.7 + 0.5 * clamp((pts[i].y - c.y) / 0.8, -0.5, 1.0)) + up.cross(pts[i] - c) * twist
		old.append(pts[i] - v * dt0)
	var lens = []
	for l in RAG_LINKS: lens.append(pts[l[0]].distance_to(pts[l[1]]))
	var mins = []
	for m in RAG_MIN: mins.append(pts[m[0]].distance_to(pts[m[1]]) * m[2])
	rag = { "p": pts, "o": old, "len": lens, "min": mins, "acc": 0.0, "still": 0.0, "rest": false, "t": 0.0, "xh": global_transform.basis.x }
	if shadow: shadow.visible = false
	if finger: finger.visible = false

func ragdoll_update(dt):
	if rag == null: return
	rag.t += dt
	if not rag.rest:
		rag.acc = min(rag.acc + dt, 0.05)
		var h = 1.0 / 60.0
		while rag.acc >= h:
			rag.acc -= h
			_rag_step(h)
	_rag_pose()

func _rag_step(h):
	var P = rag.p
	var O = rag.o
	var g = Vector3(0, -W.GRAV * h * h, 0)
	var moving = 0.0
	for i in range(P.size()):
		var cur = P[i]
		var v = (cur - O[i]) * 0.992
		O[i] = cur
		P[i] = cur + v + g
		moving = max(moving, v.length() / h)
	for _it in range(4):
		for k in range(RAG_LINKS.size()):
			var a = RAG_LINKS[k][0]
			var b = RAG_LINKS[k][1]
			var d = P[b] - P[a]
			var L0 = d.length()
			if L0 < 1e-5: continue
			var diff = (L0 - rag.len[k]) / L0 * 0.5
			P[a] += d * diff; P[b] -= d * diff
		for k in range(RAG_MIN.size()):
			var a2 = RAG_MIN[k][0]
			var b2 = RAG_MIN[k][1]
			var d2 = P[b2] - P[a2]
			var L1 = d2.length()
			if L1 < rag.min[k] and L1 > 1e-5:
				var diff2 = (L1 - rag.min[k]) / L1 * 0.5
				P[a2] += d2 * diff2; P[b2] -= d2 * diff2
		for i in range(P.size()):
			var r = 0.14 if i == 2 else (0.1 if i < 2 else 0.06)
			var res = W.collide_point(P[i], r)
			if res[1]:
				var np = res[0]
				# a hard landing makes a thud
				if _it == 0 and (i == 0 or i == 2):
					var sp = (P[i] - O[i]).length() / h
					if sp > 3.5 and G.REAL_T - rag.get("thump", -9.0) > 0.35 and G.main and G.main.sfx:
						rag["thump"] = G.REAL_T
						G.main.sfx.thump(np, sp)
				# friction on whatever it lies on
				var vel = np - O[i]
				O[i] = np - Vector3(vel.x * 0.55, vel.y, vel.z * 0.55)
				P[i] = np
	if moving < 0.35:
		rag.still += h
		if rag.still > 0.6 and rag.t > 1.0: rag.rest = true
	else:
		rag.still = 0.0

func _frame(origin, y, xhint):
	y = y.normalized()
	var x = xhint - y * xhint.dot(y)
	if x.length() < 0.05:
		x = y.cross(Vector3(0, 0, 1))
		if x.length() < 0.05: x = Vector3(1, 0, 0)
	x = x.normalized()
	return Transform(Basis(x, y, x.cross(y)), origin)

func _rag_pose():
	var P = rag.p
	var up = P[1] - P[0]
	var xs = P[12] - P[9]
	if xs.length() < 0.05: xs = rag.xh
	rag.xh = xs.normalized()
	var xh = P[6] - P[3]
	root.global_transform = _frame(P[0] - (P[1] - P[0]).normalized() * 0.0, Vector3.UP, rag.xh)
	hips.global_transform = _frame(P[0], up, xh if xh.length() > 0.05 else rag.xh)
	spine.global_transform = _frame(P[0], up, rag.xh)
	var neck = spine.global_transform.xform(Vector3(0, 0.78, 0))
	head_g.global_transform = _frame(neck, P[2] - P[1], rag.xh)
	var legs = [[L, 3, 4, 5], [R, 6, 7, 8]]
	for lg in legs:
		var Lg = lg[0]
		Lg.thigh.global_transform = _frame(P[lg[1]], P[lg[1]] - P[lg[2]], rag.xh)
		Lg.knee.global_transform = _frame(Lg.thigh.global_transform.xform(Vector3(0, -0.45, 0)), P[lg[2]] - P[lg[3]], rag.xh)
	var arms = [[AL, 9, 10, 11], [AR, 12, 13, 14]]
	for am in arms:
		var A = am[0]
		A.sh.global_transform = _frame(P[am[1]], P[am[1]] - P[am[2]], rag.xh)
		A.elbow.global_transform = _frame(A.sh.global_transform.xform(Vector3(0, -0.3, 0)), P[am[2]] - P[am[3]], rag.xh)
		A.hand.global_transform = _frame(A.elbow.global_transform.xform(Vector3(0, -0.29, 0)), P[am[2]] - P[am[3]], rag.xh)
	sync_bones()

# where the body lies (on the ground under the pelvis)
func ragdoll_center():
	if rag == null: return global_transform.origin
	var c = rag.p[0]
	return Vector3(c.x, max(0.0, W.ground_at(c.x, c.z, c.y + 0.3)), c.z)

# put the body back together and start the stand-up animation
func ragdoll_stop():
	if rag == null: return
	var c = ragdoll_center()
	var f = rag.p[1] - rag.p[0]
	var yaw = atan2(f.x, f.z) if Vector2(f.x, f.z).length() > 0.05 else rotation.y
	rag = null
	for i in range(_bones.size()):
		_bones[i].transform = Transform(Basis(), _rest[i])
	translation = c
	rotation = Vector3(0, yaw + PI, 0)
	_cur.clear()
	getup = 1.0
	if shadow: shadow.visible = true
	sync_bones()
	return c


# ---------- emotes (dances and gestures), layered over the normal pose ----------
const EMOTES = ["dance1", "dance2", "dance3", "hype", "clap", "laugh", "shrug", "salute", "point", "facepalm", "flex", "sit", "snowangel", "pray", "ascend"]

func _emote(em, t):
	var k = clamp(t / 0.25, 0.0, 1.0)     # ease in over a quarter second
	if em == "dance1":
		var b = t * TAU * 1.1
		var s = sin(b)
		hips.translation.y = 0.89 - abs(s) * 0.06
		hips.translation.x = s * 0.06
		_rot(L.thigh, -0.25 - max(0, s) * 0.4, 0, -0.08); _rot(L.knee, 0.3 + max(0, s) * 0.7, 0, 0)
		_rot(R.thigh, -0.25 - max(0, -s) * 0.4, 0, 0.08); _rot(R.knee, 0.3 + max(0, -s) * 0.7, 0, 0)
		_rot(AL.sh, -0.5 + s * 0.45, 0, -0.35); _rot(AL.elbow, -1.6, 0, 0)
		_rot(AR.sh, -0.5 - s * 0.45, 0, 0.35); _rot(AR.elbow, -1.6, 0, 0)
		_rot(spine, 0.1, s * 0.28, s * 0.06); _rot(head_g, -0.1 + abs(s) * 0.18, 0, 0)
	elif em == "dance2":
		var a = t * 5.0
		hips.translation.y = 0.9 - abs(sin(a * 0.5)) * 0.05
		_rot(AL.sh, 0, 0, -1.45 - sin(a) * 0.35 * k); _rot(AL.elbow, -0.5 - sin(a + 1.2) * 0.6, 0, 0)
		_rot(AR.sh, 0, 0, 1.45 - sin(a + 2.4) * 0.35 * k); _rot(AR.elbow, -0.5 - sin(a + 3.6) * 0.6, 0, 0)
		_rot(spine, 0.05, 0, sin(a) * 0.09); _rot(head_g, 0, 0, -sin(a) * 0.12)
		_rot(L.knee, 0.2 + max(0, sin(a * 0.5)) * 0.3, 0, 0); _rot(R.knee, 0.2 + max(0, -sin(a * 0.5)) * 0.3, 0, 0)
	elif em == "griddy":
		# the griddy: a heel tapped out front on every beat with a skip between, the arms pumping
		# like a sprint; every two bars the hands come up round the eyes like goggles
		var u = t * 2.6
		var w = sin(u * PI)                             # +1 right heel out .. -1 left heel out
		var r = max(0.0, w)
		var l = max(0.0, -w)
		var u8 = fmod(u, 8.0)
		var g = clamp((u8 - 5.7) * 4.0, 0.0, 1.0) * clamp((8.0 - u8) * 4.0, 0.0, 1.0)
		hips.translation.y = lerp(0.92, 0.86 + (1.0 - abs(w)) * 0.05, k)
		hips.translation.x = -w * 0.025 * k
		_rot(hips, 0, w * 0.12 * k, 0)
		_rot(R.thigh, lerp(-0.3, -0.42, r) * k, 0, 0.04); _rot(R.knee, lerp(0.65, 0.05, r) * k + 0.05, 0, 0)
		_rot(L.thigh, lerp(-0.3, -0.42, l) * k, 0, -0.04); _rot(L.knee, lerp(0.65, 0.05, l) * k + 0.05, 0, 0)
		var sw = w * 0.85
		_rot(AL.sh, lerp(-0.15 - sw, -1.45, g) * k, 0, lerp(-0.12, 0.5, g) * k); _rot(AL.elbow, lerp(-1.5, -2.35, g) * k, 0, 0)
		_rot(AR.sh, lerp(-0.15 + sw, -1.45, g) * k, 0, lerp(0.12, -0.5, g) * k); _rot(AR.elbow, lerp(-1.5, -2.35, g) * k, 0, 0)
		_rot(spine, lerp(-0.06, 0.02, g) * k, -w * 0.1 * k, 0)
		_rot(head_g, (-0.05 + abs(w) * 0.06) * k, 0, 0)
	elif em == "shmoney":
		# the shmoney: a loose bounce on the knees, rocking side to side, one arm swinging and
		# rolling out at the side on every beat, the other bent at the ribs; the arms swap every
		# two bars, with a lean back and a shoulder shake
		var u = t * 2.2
		var b = u * PI
		var u16 = fmod(u, 16.0)
		var a = clamp((u16 - 7.6) * 2.5, 0.0, 1.0) * clamp((16.0 - u16) * 2.5, 0.0, 1.0)   # 0 right arm swings .. 1 left
		var sw = sin(b)
		var rock = sin(b * 0.5)
		hips.translation.y = lerp(0.92, 0.87 - abs(sw) * 0.035, k)
		hips.translation.x = rock * 0.06 * k
		_rot(hips, 0, rock * 0.14 * k, -rock * 0.04 * k)
		_rot(L.thigh, -0.18 * k, 0, -0.1); _rot(L.knee, (0.38 + max(0.0, rock) * 0.25) * k, 0, 0)
		_rot(R.thigh, -0.18 * k, 0, 0.1); _rot(R.knee, (0.38 + max(0.0, -rock) * 0.25) * k, 0, 0)
		var sx = -0.35 - sw * 0.6                       # the swinging arm, out at the side
		var ex = -0.45 - max(0.0, sw) * 0.75            # its forearm rolling forward
		var ox = -0.35 - abs(sw) * 0.1                  # the bent arm
		_rot(AR.sh, lerp(sx, ox, a) * k, 0, lerp(0.32, 0.45, a) * k); _rot(AR.elbow, lerp(ex, -1.7, a) * k, 0, 0)
		_rot(AL.sh, lerp(ox, sx, a) * k, 0, -lerp(0.45, 0.32, a) * k); _rot(AL.elbow, lerp(-1.7, ex, a) * k, 0, 0)
		var side = 1.0 - 2.0 * a
		_rot(spine, (-0.1 + abs(sw) * 0.05) * k, (side * 0.15 + rock * 0.08) * k, sin(b * 2.0) * 0.04 * k)
		_rot(head_g, (0.05 + abs(sw) * 0.1) * k, -side * 0.12 * k, 0)
	elif em == "woah":
		# the woah: a bounce, then every other beat the arms whip across the chest and stop dead
		# with a dip and a lean, the head turned away; one side, then the other
		var u = t * 2.2
		var side = 1.0 if int(floor(u / 2.0)) % 2 == 0 else -1.0
		var f2 = fmod(u, 2.0) / 2.0
		var hit = 1.0 - pow(1.0 - clamp(f2 * 6.0, 0.0, 1.0), 3.0)    # snaps in fast ...
		hit *= clamp((1.0 - f2) * 4.0, 0.0, 1.0)                     # ... holds, lets go before the next
		var bob = abs(sin(u * PI))
		hips.translation.y = lerp(0.92, 0.88 - hit * 0.06 - bob * 0.015, k)
		_rot(hips, 0, side * hit * 0.25 * k, 0)
		_rot(L.thigh, -0.2 * k, 0, -0.12); _rot(L.knee, (0.35 + hit * 0.35) * k, 0, 0)
		_rot(R.thigh, -0.2 * k, 0, 0.12); _rot(R.knee, (0.35 + hit * 0.35) * k, 0, 0)
		# loose: [x, z, elbow]; the lead arm across the chest, the other punched down and out
		var lead = [-0.9, -0.62, -1.4]
		var low = [0.15, 0.6, -0.15]
		var rr = lead if side > 0 else low
		var ll = low if side > 0 else lead
		_rot(AR.sh, lerp(-0.3, rr[0], hit) * k, 0, lerp(0.15, rr[1], hit) * k); _rot(AR.elbow, lerp(-1.2, rr[2], hit) * k, 0, 0)
		_rot(AL.sh, lerp(-0.3, ll[0], hit) * k, 0, -lerp(0.15, ll[1], hit) * k); _rot(AL.elbow, lerp(-1.2, ll[2], hit) * k, 0, 0)
		_rot(spine, (0.06 + hit * 0.08) * k, side * hit * 0.2 * k, side * hit * 0.1 * k)
		_rot(head_g, (0.04 + bob * 0.06) * k, -side * hit * 0.35 * k, 0)
	elif em == "hitfolks":
		# hit dem folks: bent at the waist, both arms swinging down together across the body to
		# one side on a beat, up through the chest, then down to the other side, knees giving
		var u = t * 2.3
		var s0 = sin(u * PI)
		var sv = sign(s0) * pow(abs(s0), 0.6)
		var a = abs(sv)
		hips.translation.y = lerp(0.92, 0.86 - a * 0.04, k)
		_rot(hips, 0, -sv * 0.15 * k, 0)
		_rot(L.thigh, -0.35 * k, 0, -0.14); _rot(L.knee, (0.65 + a * 0.15) * k, 0, 0)
		_rot(R.thigh, -0.35 * k, 0, 0.14); _rot(R.knee, (0.65 + a * 0.15) * k, 0, 0)
		# [x, z, elbow] for each arm: up at the chest between swings, down to the side on one
		var mid_r = [-1.0, 0.1, -1.3]
		var mid_l = [-1.0, -0.1, -1.3]
		# (positive z takes the right arm out and the left arm across)
		var to_r = [[-0.4, 0.35, -0.25], [-0.95, 0.55, -0.3]] if sv >= 0 else [[-0.95, -0.55, -0.3], [-0.4, -0.35, -0.25]]
		_rot(AR.sh, lerp(mid_r[0], to_r[0][0], a) * k, 0, lerp(mid_r[1], to_r[0][1], a) * k); _rot(AR.elbow, lerp(mid_r[2], to_r[0][2], a) * k, 0, 0)
		_rot(AL.sh, lerp(mid_l[0], to_r[1][0], a) * k, 0, lerp(mid_l[1], to_r[1][1], a) * k); _rot(AL.elbow, lerp(mid_l[2], to_r[1][2], a) * k, 0, 0)
		_rot(spine, (0.42 + a * 0.06) * k, sv * 0.35 * k, 0)
		_rot(head_g, (0.05 - a * 0.08) * k, -sv * 0.1 * k, 0)
	elif em == "sturdy":
		# the sturdy: sitting low, chest over the toes, a heavy drop on every beat. The feet trade a
		# stomp out front, side to side with a little hop between, the hips turn into the stomping
		# leg while the arms swing the other way; every two bars both fists pump down
		var u = t * 2.3                                 # beats
		var f = u - floor(u)
		var hit = exp(-f * 7.0)                         # the drop as each beat lands
		var sd = clamp(cos(u * PI) * 1.7, -1.0, 1.0)    # +1 right foot out .. -1 left foot out
		var r = max(0.0, sd)
		var l = max(0.0, -sd)
		var pump = 1.0 if int(floor(u)) % 8 >= 6 else 0.0
		var pk = 1.0 - pump
		hips.translation.y = lerp(0.92, 0.79 + (1.0 - abs(sd)) * 0.05 - hit * (0.03 + pump * 0.03), k)
		hips.translation.x = sd * 0.07 * k
		_rot(hips, 0, -sd * 0.3 * k, sd * 0.05 * k)
		_rot(R.thigh, lerp(-0.5, -0.72, r) * k, 0, (0.16 + r * 0.1) * k); _rot(R.knee, (lerp(1.1, 0.25, r) + hit * 0.12 * (1.0 - r)) * k + 0.05, 0, 0)
		_rot(L.thigh, lerp(-0.5, -0.72, l) * k, 0, -(0.16 + l * 0.1) * k); _rot(L.knee, (lerp(1.1, 0.25, l) + hit * 0.12 * (1.0 - l)) * k + 0.05, 0, 0)
		var dn = hit * 0.55 * pump
		_rot(AL.sh, (lerp(-0.25, -1.0, r) + 0.4 * l) * k * pk + (-0.45 + dn) * pump, 0, lerp(-0.2, 0.3, r) * k * pk - 0.35 * pump); _rot(AL.elbow, (-1.2 - 0.3 * r) * pk - 1.7 * pump, 0, 0)
		_rot(AR.sh, (lerp(-0.25, -1.0, l) + 0.4 * r) * k * pk + (-0.45 + dn) * pump, 0, lerp(0.2, -0.3, l) * k * pk + 0.35 * pump); _rot(AR.elbow, (-1.2 - 0.3 * l) * pk - 1.7 * pump, 0, 0)
		_rot(spine, (0.3 + hit * 0.06) * k, sd * 0.18 * k, sd * 0.04 * k)
		_rot(head_g, (0.06 + hit * 0.18) * k, -sd * 0.1 * k, 0)
	elif em == "dance3":
		# the robot: snaps between square poses
		var q = int(floor(t * 3.2)) % 6
		var P = [[-1.57, 0.0, -1.57, 0.0, -1.57, -1.57], [0.0, 0.0, -1.57, -1.57, 0.0, -1.57], [-1.57, -0.6, 0.0, -1.57, 0.6, 0.0],
			[0.0, -1.5, -1.57, 0.0, 1.5, -1.57], [-1.57, 0.0, -1.57, -1.57, 0.0, 0.0], [-2.9, -0.2, 0.0, 0.0, 0.0, -1.57]][q]
		_rot(AL.sh, P[0], 0, P[1]); _rot(AL.elbow, P[2], 0, 0)
		_rot(AR.sh, P[3], 0, P[4]); _rot(AR.elbow, P[5], 0, 0)
		_rot(head_g, 0, [0.5, -0.5, 0.0, 0.5, -0.5, 0.0][q], 0); _rot(spine, 0, [0.3, -0.3, 0.0, -0.3, 0.3, 0.0][q], 0)
		hips.translation.y = 0.9 if q % 2 == 0 else 0.86
	elif em == "hype":
		var j = abs(sin(t * 7.0))
		hips.translation.y = 0.92 + j * 0.16
		_rot(L.knee, 0.6 - j * 0.5, 0, 0); _rot(R.knee, 0.6 - j * 0.5, 0, 0)
		_rot(L.thigh, -0.4 + j * 0.3, 0, 0); _rot(R.thigh, -0.4 + j * 0.3, 0, 0)
		_rot(AL.sh, -2.6 - j * 0.3, 0, -0.3); _rot(AL.elbow, -0.4 - (1 - j) * 1.2, 0, 0)
		_rot(AR.sh, -2.6 - (1 - j) * 0.3, 0, 0.3); _rot(AR.elbow, -0.4 - j * 1.2, 0, 0)
		_rot(head_g, -0.3, 0, 0)
	elif em == "clap":
		var cc = 0.5 + 0.5 * sin(t * 14.0)
		_rot(AL.sh, -1.15 * k, 0, 0.15 + 0.25 * cc); _rot(AL.elbow, -1.05 * k, 0, 0)
		_rot(AR.sh, -1.15 * k, 0, -0.15 - 0.25 * cc); _rot(AR.elbow, -1.05 * k, 0, 0)
	elif em == "laugh":
		var lb = abs(sin(t * 9.0))
		_rot(spine, 0.12 + lb * 0.18, 0, 0); _rot(head_g, -0.35 + lb * 0.25, 0, 0)
		_rot(AL.sh, -0.5, 0, 0.12); _rot(AL.elbow, -1.7, 0, 0)
		_rot(AR.sh, -0.5, 0, -0.12); _rot(AR.elbow, -1.7, 0, 0)
	elif em == "shrug":
		_rot(AL.sh, -0.25 * k, 0, -0.5 * k); _rot(AL.elbow, -1.5 * k, 0, 0)
		_rot(AR.sh, -0.25 * k, 0, 0.5 * k); _rot(AR.elbow, -1.5 * k, 0, 0)
		_rot(head_g, 0, 0, 0.18 * k); _rot(spine, -0.05, 0, 0)
	elif em == "salute":
		_rot(AR.sh, -1.25 * k, 0, 0.95 * k); _rot(AR.elbow, -2.3 * k, 0, 0)
		_rot(spine, -0.06, 0, 0); _rot(head_g, -0.05, 0, 0)
	elif em == "point":
		_rot(AR.sh, -1.55 * k, 0, 0.04); _rot(AR.elbow, -0.05, 0, 0)
		_rot(spine, 0.02, -0.15, 0)
	elif em == "facepalm":
		_rot(AL.sh, -1.3 * k, 0, 0.38 * k); _rot(AL.elbow, -2.45 * k, 0, 0)
		_rot(head_g, 0.4 * k, 0, 0.1 * sin(t * 2)); _rot(spine, 0.12 * k, 0, 0)
	elif em == "flex":
		var fl = 0.15 * sin(t * 6)
		_rot(AL.sh, 0, 0, -1.5 * k); _rot(AL.elbow, 0, 0, (-1.45 + fl) * k)
		_rot(AR.sh, 0, 0, 1.5 * k); _rot(AR.elbow, 0, 0, (1.45 - fl) * k)
		_rot(head_g, -0.15, 0.3 * sin(t * 1.5), 0)
	elif em == "sit":
		hips.translation.y = lerp(0.92, 0.3, k)
		_rot(L.thigh, -1.5 * k, 0, -0.12); _rot(R.thigh, -1.5 * k, 0, 0.12)
		_rot(L.knee, 1.45 * k, 0, 0); _rot(R.knee, 1.45 * k, 0, 0)
		_rot(AL.sh, -0.7 * k, 0, 0); _rot(AL.elbow, -0.5 * k, 0, 0)
		_rot(AR.sh, -0.7 * k, 0, 0); _rot(AR.elbow, -0.5 * k, 0, 0)
		_rot(spine, 0.15 * k, 0, 0)
	elif em == "pray":
		_rot(AL.sh, -0.8 * k, 0, 0.45 * k); _rot(AL.elbow, -1.9 * k, 0, 0)
		_rot(AR.sh, -0.8 * k, 0, -0.45 * k); _rot(AR.elbow, -1.9 * k, 0, 0)
		_rot(head_g, 0.42 * k, 0, 0); _rot(spine, 0.08 * k, 0, 0)
	elif em == "ascend":
		var br = 0.06 * sin(t * 1.6)
		_rot(AL.sh, -0.2 * k, 0, -(1.0 + br) * k); _rot(AL.elbow, -0.25 * k, 0, 0)
		_rot(AR.sh, -0.2 * k, 0, (1.0 + br) * k); _rot(AR.elbow, -0.25 * k, 0, 0)
		_rot(head_g, -0.32 * k, 0, 0); _rot(spine, -0.08 * k, 0, 0)
		_rot(L.knee, 0.15, 0, 0); _rot(R.knee, 0.25, 0, 0)
	elif em == "snowangel":
		var fa = 0.5 + 0.5 * sin(t * 3.2)
		_rot(AL.sh, 0, 0, -(0.3 + 1.6 * fa)); _rot(AL.elbow, -0.1, 0, 0)
		_rot(AR.sh, 0, 0, 0.3 + 1.6 * fa); _rot(AR.elbow, -0.1, 0, 0)
		_rot(L.thigh, 0, 0, -(0.05 + 0.4 * fa)); _rot(R.thigh, 0, 0, 0.05 + 0.4 * fa)
		_rot(L.knee, 0.05, 0, 0); _rot(R.knee, 0.05, 0, 0)
		_rot(spine, 0, 0, 0); _rot(head_g, 0, 0, 0)
