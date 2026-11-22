extends Reference
# Builds detailed static geometry as one mesh per material, so a building with columns,
# moldings, dentils and doors costs a handful of draw calls (old Intel GPUs and phones).
# Faces are wound for Godot (clockwise = front), whatever order the corners come in:
# every quad and triangle is checked against the normal it should face.

var sts = {}
var mats = {}
var tang = {}

func mat(k, m, tangents = false):
	mats[k] = m
	tang[k] = tangents

func _st(k):
	if not sts.has(k):
		var s = SurfaceTool.new(); s.begin(Mesh.PRIMITIVE_TRIANGLES); sts[k] = s
	return sts[k]

func _v(s, p, n, uv):
	s.add_normal(n); s.add_uv(uv); s.add_vertex(p)

# a triangle facing n (normal per corner optional)
func tri(k, a, b, c, n, ua = Vector2(), ub = Vector2(), uc = Vector2(), na = null, nb = null, nc = null):
	var s = _st(k)
	if (b - a).cross(c - a).dot(n) > 0:
		var t = b; b = c; c = t
		var tu = ub; ub = uc; uc = tu
		var tn = nb; nb = nc; nc = tn
	_v(s, a, na if na != null else n, ua); _v(s, b, nb if nb != null else n, ub); _v(s, c, nc if nc != null else n, uc)

func quad(k, a, b, c, d, n, ua, ub, uc, ud, na = null, nb = null, nc = null, nd = null):
	tri(k, a, b, c, n, ua, ub, uc, na, nb, nc)
	tri(k, a, c, d, n, ua, uc, ud, na, nc, nd)

# a box: xf places its centre, size in metres; uv = metres * uvs (+ the box origin, so
# neighbouring boxes do not all start their texture at the same corner)
const FACES = [
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)]]

func box(k, xf, size, uvs = 0.5, skip_bottom = true):
	var h = size * 0.5
	var o = xf.origin
	for f in FACES:
		var n = f[0]
		if skip_bottom and n.y < -0.5: continue
		var u = f[1]
		var w = f[2]
		var c = Vector3(n.x * h.x, n.y * h.y, n.z * h.z)
		var hu = abs(u.x) * h.x + abs(u.y) * h.y + abs(u.z) * h.z
		var hw = abs(w.x) * h.x + abs(w.y) * h.y + abs(w.z) * h.z
		var pts = [c - u * hu - w * hw, c + u * hu - w * hw, c + u * hu + w * hw, c - u * hu + w * hw]
		var uv = []
		var P = []
		for p in pts:
			var wp = xf.xform(p)
			P.append(wp)
			uv.append(Vector2(p.dot(u) + o.dot(u), -(p.dot(w) + o.dot(w))) * uvs)
		var N = xf.basis.xform(n).normalized()
		quad(k, P[0], P[1], P[2], P[3], N, uv[0], uv[1], uv[2], uv[3])

func boxp(k, center, size, uvs = 0.5):
	box(k, Transform(Basis(), center), size, uvs)

# a solid of revolution around xf's Y axis: profile = [[radius, y], ...] bottom to top.
# rfun(theta, radius, y) can reshape the radius (flutes); smooth around, crisp along.
func lathe(k, xf, profile, seg = 16, uv_scale = Vector2(1, 1), rfun_obj = null, rfun = ""):
	for i in range(profile.size() - 1):
		var p0 = profile[i]
		var p1 = profile[i + 1]
		var dr = p1[0] - p0[0]
		var dy = p1[1] - p0[1]
		var L = sqrt(dr * dr + dy * dy)
		if L < 1e-5: continue
		var nr = dy / L
		var ny = -dr / L
		for j in range(seg):
			var a0 = TAU * j / seg
			var a1 = TAU * (j + 1) / seg
			var q = []
			var nn = []
			for c in [[a0, p0], [a1, p0], [a1, p1], [a0, p1]]:
				var a = c[0]
				var r = c[1][0]
				var y = c[1][1]
				var rr = r
				var tn = 0.0
				if rfun_obj != null and r > 0.0001:
					rr = rfun_obj.call(rfun, a, r, y)
					var r2 = rfun_obj.call(rfun, a + 0.01, r, y)
					tn = -(r2 - rr) / (0.01 * max(rr, 0.0001))
				var radial = Vector3(cos(a), 0, sin(a))
				var tang_v = Vector3(-sin(a), 0, cos(a))
				q.append(xf.xform(radial * rr + Vector3(0, y, 0)))
				nn.append(xf.basis.xform((radial * nr + tang_v * tn * nr + Vector3(0, ny, 0))).normalized())
			var fn = (nn[0] + nn[1] + nn[2] + nn[3]).normalized()
			var u0 = float(j) / seg * uv_scale.x
			var u1 = float(j + 1) / seg * uv_scale.x
			quad(k, q[0], q[1], q[2], q[3], fn, Vector2(u0, -p0[1] * uv_scale.y), Vector2(u1, -p0[1] * uv_scale.y), Vector2(u1, -p1[1] * uv_scale.y), Vector2(u0, -p1[1] * uv_scale.y), nn[0], nn[1], nn[2], nn[3])

# a molding: profile = [[out, up], ...] swept straight from a to b; o = outward, u = up
func extrude(k, profile, a, b, o, u, uvs = 0.5):
	var along = (b - a)
	var L = along.length()
	for i in range(profile.size() - 1):
		var p0 = profile[i]
		var p1 = profile[i + 1]
		var d0 = p1[0] - p0[0]
		var d1 = p1[1] - p0[1]
		var l = sqrt(d0 * d0 + d1 * d1)
		if l < 1e-5: continue
		var n = (o * (d1 / l) + u * (-d0 / l)).normalized()
		var A0 = a + o * p0[0] + u * p0[1]
		var A1 = a + o * p1[0] + u * p1[1]
		quad(k, A0, A0 + along, A1 + along, A1, n, Vector2(0, -p0[1] - p0[0]) * uvs, Vector2(L, -p0[1] - p0[0]) * uvs, Vector2(L, -p1[1] - p1[0]) * uvs, Vector2(0, -p1[1] - p1[0]) * uvs)

# a tube along a polyline with radii per point (branches, trunks, rails, arches)
func tube(k, pts, radii, sides = 7, uv_v = 1.0, cap = false):
	var prev_ring = []
	var vacc = 0.0
	var ref = Vector3(0.31, 0.93, 0.17)
	var t1 = Vector3()
	for i in range(pts.size()):
		var d
		if i == 0: d = (pts[1] - pts[0]).normalized()
		elif i == pts.size() - 1: d = (pts[i] - pts[i - 1]).normalized()
		else: d = (pts[i + 1] - pts[i - 1]).normalized()
		if i == 0:
			t1 = d.cross(ref)
			if t1.length() < 0.1: t1 = d.cross(Vector3(1, 0, 0))
			t1 = t1.normalized()
		else:
			t1 = (t1 - d * t1.dot(d)).normalized()
			vacc += pts[i].distance_to(pts[i - 1])
		var t2 = d.cross(t1)
		var ring = []
		for j in range(sides + 1):
			var a = TAU * j / sides
			var nrm = (t1 * cos(a) + t2 * sin(a))
			ring.append([pts[i] + nrm * radii[i], nrm, Vector2(float(j) / sides, -vacc * uv_v)])
		if i > 0:
			for j in range(sides):
				var A = prev_ring[j]
				var B = prev_ring[j + 1]
				var C = ring[j + 1]
				var D = ring[j]
				quad(k, A[0], B[0], C[0], D[0], (A[1] + C[1]).normalized(), A[2], B[2], C[2], D[2], A[1], B[1], C[1], D[1])
		prev_ring = ring
	if cap:
		var e = pts[pts.size() - 1]
		var dn = (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
		for j in range(sides):
			tri(k, e, prev_ring[j][0], prev_ring[j + 1][0], dn)

func torus(k, xf, R, r, seg = 24, rseg = 8):
	for i in range(seg):
		var a0 = TAU * i / seg
		var a1 = TAU * (i + 1) / seg
		for j in range(rseg):
			var b0 = TAU * j / rseg
			var b1 = TAU * (j + 1) / rseg
			var q = []
			var nn = []
			for c in [[a0, b0], [a1, b0], [a1, b1], [a0, b1]]:
				var rad = Vector3(cos(c[0]), 0, sin(c[0]))
				var n = rad * cos(c[1]) + Vector3(0, sin(c[1]), 0)
				q.append(xf.xform(rad * R + n * r)); nn.append(xf.basis.xform(n).normalized())
			quad(k, q[0], q[1], q[2], q[3], (nn[0] + nn[2]).normalized(), Vector2(float(i) / seg, float(j) / rseg), Vector2(float(i + 1) / seg, float(j) / rseg), Vector2(float(i + 1) / seg, float(j + 1) / rseg), Vector2(float(i) / seg, float(j + 1) / rseg), nn[0], nn[1], nn[2], nn[3])

func commit(parent, shadows = false):
	var out = {}
	for k in sts.keys():
		var s = sts[k]
		if tang.get(k, false): s.generate_tangents()
		var mi = MeshInstance.new()
		mi.mesh = s.commit()
		mi.material_override = mats.get(k)
		mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance.SHADOW_CASTING_SETTING_OFF
		mi.name = str(k)
		parent.add_child(mi)
		out[k] = mi
	sts.clear()
	return out
