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
var cr = 0.0
var opts = {}
var _geo = { "v": [], "n": [], "c": [], "i": [], "b": [] }
var _bones = []         # pivots, parents always before children
var _bone_parent = []
var skel = null

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
func build(o):
	opts = o
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
	var cSleeve = cJ2 if top == "varsity" else cJ
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
	_add(head_g, "sphere", [0.13], cS, Vector3(0, 0.06, 0), Vector3(), Vector3(0.95, 1.05, 1))
	var skimask = head == "skimask"
	if skimask:
		_add(head_g, "sphere", [0.13], cH, Vector3(0, 0.062, 0), Vector3(), Vector3(1.0, 1.1, 1.05))
	for s in [-1, 1]:
		_add(head_g, "sphere", [0.019], cDark, Vector3(s * 0.045, 0.085, 0.128 if skimask else 0.118))
		if not skimask:
			_add(head_g, "box", [0.052, 0.013, 0.014], cHair, Vector3(s * 0.047, 0.118, 0.115), Vector3(0, 0, s * 0.08))
	if o.get("beard", false) and not skimask and o.get("mask") == null:
		_add(head_g, "box", [0.17, 0.075, 0.07], cHair, Vector3(0, -0.005, 0.07))
	if o.get("mask") != null:
		_add(head_g, "sphere", [0.138], o["mask"], Vector3(0, 0.03, 0.01), Vector3(), Vector3(0.97, 0.6, 1.03))
	if o.get("glasses", false):
		_add(head_g, "box", [0.21, 0.048, 0.02], cDark, Vector3(0, 0.087, 0.135 if skimask else 0.124))
	var hair = o.get("hair", "none")
	var covers = head in ["beanie", "durag", "skimask", "hood", "bucket"]
	if hair != "none" and not skimask:
		if hair == "afro":
			if covers or head in ["cap", "capback"]:
				_add(head_g, "sphere", [0.19], cHair, Vector3(0, 0.06, -0.02), Vector3(), Vector3(0.9, 0.62, 0.9))
			else:
				_add(head_g, "sphere", [0.19], cHair, Vector3(0, 0.13, -0.01))
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
	var fm = CapsuleMesh.new(); fm.radius = 0.015; fm.mid_height = 0.072; fm.radial_segments = 6; fm.rings = 1
	finger = MeshInstance.new(); finger.mesh = fm; finger.material_override = G.mat(G.hex_color(cHand))
	finger.translation = Vector3(0, -0.09, 0.006); finger.rotation = Vector3(PI / 2, 0, 0); finger.visible = false
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
func _rot(n, x, y, z):
	n.transform.basis = _basis_xyz(x, y, z)

func animate(dt, pose):
	var sp = pose.get("speed", 0.0)
	phase += dt * ((3.2 + sp * 1.25) if sp > 0.2 else 0.0)
	var ph = phase
	var amp = clamp(sp / 5.0, 0.0, 1.15)
	var crouch = 1.0 if pose.get("crouch", false) else 0.0
	if typeof(pose.get("crouch")) == TYPE_REAL:
		crouch = pose["crouch"]
	cr = lerp(cr, crouch, 1 - exp(-dt * 12))
	var c = cr
	hips.translation.y = lerp(0.92, 0.56, c) - abs(sin(ph)) * 0.04 * amp
	var swing = sin(ph) * 0.75 * amp
	var spine_x = lerp(0.06 * amp, 0.35, c)
	var spine_y = 0.0
	var spine_z = 0.0
	_rot(L.thigh, lerp(swing, -1.25 + swing * 0.3, c), 0, 0)
	_rot(R.thigh, lerp(-swing, -1.25 - swing * 0.3, c), 0, 0)
	_rot(L.knee, lerp(max(0, -sin(ph + 0.6)) * 1.1 * amp + 0.05, 2.0, c), 0, 0)
	_rot(R.knee, lerp(max(0, sin(ph + 0.6)) * 1.1 * amp + 0.05, 2.0, c), 0, 0)
	var aim = pose.get("aim", 0.0)
	var pitch = pose.get("pitch", 0.0)
	var arm_swing = sin(ph) * 0.55 * amp
	var relax_r = -0.45 if pose.get("carry", false) else -arm_swing
	var ar = Vector3(lerp(relax_r, -PI / 2 - pitch - spine_x, aim), 0, lerp(0.08, 0.0, aim))
	var are = lerp(-0.5 if pose.get("carry", false) else -0.25, -0.05, aim)
	var two = 1.0 if pose.get("twoHand", false) else 0.85
	var al = Vector3(lerp(arm_swing, -PI / 2 - pitch - spine_x + 0.15, aim * two), 0, lerp(-0.08, -0.55, aim))
	var ale = lerp(-0.25, -0.35, aim)
	if pose.get("wave", false):
		al = Vector3(-2.6, 0, -0.3 + sin(G.REAL_T * 8) * 0.25); ale = -0.4
	if pose.get("flip", false):
		al = Vector3(-1.5 + sin(G.REAL_T * 9) * 0.06, 0, -0.22); ale = -1.3
	if pose.get("mug", false):
		al = Vector3(-0.9, 0, -0.1); ale = -1.4
	if pose.get("hands", false):
		al = Vector3(-2.9, 0, -0.25); ale = -0.35; ar = Vector3(-2.9, 0, 0.25); are = -0.35
	if pose.get("pose", false):
		ar = Vector3(-1.9, 0, 0.3); are = -1.2; al.x = -0.4; spine_x = -0.08
	if pose.get("fists", false) and pose.get("down", 0.0) == 0:
		var gk = 1.0 if pose.get("guard", false) else 0.6
		al = Vector3(lerp(al.x, -1.0, gk), 0, lerp(al.z, 0.32, gk)); ale = lerp(ale, -1.95, gk)
		ar = Vector3(lerp(ar.x, -1.0, gk), 0, lerp(ar.z, -0.32, gk)); are = lerp(are, -1.95, gk)
		var pt = pose.get("punch", 0.0)
		if pt > 0:
			var s = -1 if pose.get("punchSide", 1) < 0 else 1
			var e = sin(clamp(pt, 0, 1) * PI)
			var hook = pose.get("hook", false)
			var px = lerp(-1.0, -1.4 if hook else -1.62, e)
			var pe = lerp(-1.95, -1.15 if hook else -0.08, e)
			var pz = -s * lerp(0.32, 0.95 if hook else 0.1, e)
			if s < 0:
				al = Vector3(px, 0, pz); ale = pe
			else:
				ar = Vector3(px, 0, pz); are = pe
			spine_y = -s * 0.42 * e
	_rot(AR.sh, ar.x, 0, ar.z); _rot(AR.elbow, are, 0, 0)
	_rot(AL.sh, al.x, 0, al.z); _rot(AL.elbow, ale, 0, 0)
	finger.visible = pose.get("flip", false)
	if pose.get("shiver", false):
		spine_z = sin(G.REAL_T * 40) * 0.015
	_rot(spine, spine_x, spine_y, spine_z)
	_rot(head_g, lerp(0, -pitch * 0.6, aim), 0, 0)
	var dn = pose.get("down", 0.0)
	_rot(root, -dn * PI / 2 * 0.96, 0, 0)
	root.translation = Vector3(0, dn * 0.18, -dn * 0.5)
	shadow.visible = dn < 0.5
	sync_bones()
