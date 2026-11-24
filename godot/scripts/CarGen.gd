extends Reference
# The city's cars, modelled in code: low poly, but shaped like real cars. Each body is lofted
# from cross-sections along its length (rocker, flank, shoulder line, the rounded top edge,
# the crowned hood and deck), with the wheel arches cut by the lower edge rising over each
# wheel and a dark liner inside. The cabin sits on the belt line with tumblehome, its glass
# and pillars where a real car has them: a raked windshield, a fastback or upright rear
# glass, black B pillars, body-colour C and D pillars. Then the faces: grilles, light bars,
# headlights, the full-width "racetrack" tail lamp, bumpers, splitters, diffusers and quad
# tips, hood bulges and scoops, ducktails, mirrors, door seams and handles, roof rails, and
# wheels with spokes, brake discs and calipers.
#
# The makes are the city's own (Kessler and friends): the shapes follow the kinds of cars
# that rule these streets (a modern four-door muscle fastback, a three-row muscle SUV, a
# chrome-grille gangster sedan, a big body-on-frame SUV, a crew-cab pickup, a muscle coupe,
# a beater hatch, a cargo van), with no real maker's badges, names or exact designs.
#
# The doors are their own nodes (Doors/D[F|R][L|R], on the hinge at the front edge): the
# body shell between the seams, the mirror and the handle, an inner panel, and the side glass
# on a child ("Win") that slides down into the door. Behind them: a floor, seats, a dash and a
# headliner, for when a door or a window is open.
#
# geom(model) gives the cabin measures the first-person interior is built from, so the
# dashboard, the glass and the seats line up with the body you see from outside.

const MB = preload("res://scripts/MeshBuild.gd")

# z runs nose (+) to tail (-); y up from the ground; x across. Lists of [z, y] go tail to nose.
const P = {
	# a modern four-door muscle fastback: long hood, short deck, a light bar across the nose
	"bruiser": { "r": 0.37, "tw": 0.28, "zF": 1.55, "zR": -1.55, "yb": 0.3,
		"top": [[-2.52, 0.74], [-2.42, 0.93], [-1.6, 0.96], [-1.2, 0.95], [1.15, 0.94], [2.2, 0.86], [2.52, 0.7]],
		"sh": [[-2.5, 0.72], [-1.6, 0.86], [0.0, 0.8], [1.55, 0.86], [2.5, 0.7]],
		"taper": [0.45, 0.1, 0.35, 0.06], "zWB": 1.15, "zWT": 0.32, "zRB": -0.55, "zRG": -1.6, "roof": 1.42,
		"zB": -0.12, "gb": 0.1, "gr": 0.27, "front": "bar", "rear": "racetrack", "hood": "bulge", "spoil": "duck",
		"tips": 4, "rim": "five", "skirt": true, "awd": true },
	# a three-row muscle SUV: long roof, upright tail, slim lamps, a scoop in the hood
	"boulder": { "r": 0.41, "tw": 0.3, "zF": 1.62, "zR": -1.55, "yb": 0.42,
		"top": [[-2.56, 0.98], [-2.46, 1.1], [-1.9, 1.12], [1.5, 1.1], [2.28, 1.02], [2.56, 0.84]],
		"sh": [[-2.5, 0.98], [-1.55, 1.04], [0.0, 1.0], [1.6, 1.04], [2.5, 0.9]],
		"taper": [0.42, 0.1, 0.25, 0.05], "zWB": 1.5, "zWT": 0.85, "zRB": -2.25, "zRG": -2.45, "roof": 1.82,
		"zB": 0.05, "zC": -1.15, "gb": 0.1, "gr": 0.22, "front": "slim", "rear": "racetrack", "hood": "scoop", "spoil": "roof",
		"tips": 4, "rim": "split", "rails": true, "skirt": true, "awd": true },
	# the gangster sedan: high belt, slit windows, a big upright chrome grille
	"sedan": { "r": 0.35, "tw": 0.26, "zF": 1.45, "zR": -1.55, "yb": 0.3,
		"top": [[-2.35, 0.78], [-2.25, 0.96], [-1.3, 0.98], [1.15, 0.98], [2.15, 0.92], [2.35, 0.74]],
		"sh": [[-2.3, 0.82], [0.0, 0.84], [2.3, 0.8]],
		"taper": [0.3, 0.06, 0.25, 0.05], "zWB": 1.2, "zWT": 0.55, "zRB": -0.55, "zRG": -1.3, "roof": 1.42,
		"zB": 0.02, "gb": 0.1, "gr": 0.25, "front": "upright", "rear": "pair", "hood": "flat", "chrome": true,
		"tips": 2, "rim": "chrome", "skirt": false },
	"taxi": { "base": "sedan", "taxi": true, "rim": "steel", "chrome": false },
	# a police interceptor on the fastback: push bar, light bar, steel wheels
	"police": { "base": "bruiser", "push": true, "bar": true, "rim": "steel", "spoil": "", "tips": 2 },
	# the big body-on-frame SUV: square, tall, a chrome grille, vertical tail lamps
	"suv": { "r": 0.42, "tw": 0.3, "zF": 1.55, "zR": -1.5, "yb": 0.45,
		"top": [[-2.42, 1.02], [-2.36, 1.14], [1.45, 1.14], [2.25, 1.08], [2.42, 0.86]],
		"sh": [[-2.4, 1.0], [0.0, 1.02], [2.4, 0.96]],
		"taper": [0.25, 0.06, 0.12, 0.03], "zWB": 1.45, "zWT": 0.85, "zRB": -2.25, "zRG": -2.36, "roof": 1.9,
		"zB": 0.1, "zC": -1.05, "gb": 0.08, "gr": 0.18, "front": "bars", "rear": "vertical", "hood": "flat", "chrome": true,
		"tips": 2, "rim": "chrome", "rails": true, "skirt": false },
	# a crew-cab pickup with a bed
	"pickup": { "r": 0.42, "tw": 0.3, "zF": 1.75, "zR": -1.7, "yb": 0.48,
		"top": [[-2.67, 1.12], [-2.6, 1.16], [-0.55, 1.16], [1.6, 1.18], [2.5, 1.12], [2.67, 0.9]],
		"sh": [[-2.6, 1.06], [0.0, 1.06], [2.6, 1.0]],
		"taper": [0.22, 0.05, 0.05, 0.0], "zWB": 1.4, "zWT": 0.8, "zRB": -0.4, "zRG": -0.5, "roof": 1.88,
		"zB": 0.45, "gb": 0.09, "gr": 0.2, "front": "bars", "rear": "vertical", "hood": "flat", "chrome": true,
		"tips": 1, "rim": "split", "bed": -0.55, "skirt": false },
	# a muscle coupe: two doors, quad round lamps, a scoop, a wing
	"coupe": { "r": 0.36, "tw": 0.28, "zF": 1.45, "zR": -1.45, "yb": 0.28,
		"top": [[-2.25, 0.76], [-2.15, 0.9], [-1.25, 0.92], [1.1, 0.9], [2.05, 0.82], [2.25, 0.66]],
		"sh": [[-2.2, 0.76], [-1.4, 0.84], [0.0, 0.76], [1.4, 0.82], [2.2, 0.68]],
		"taper": [0.32, 0.08, 0.3, 0.06], "zWB": 1.12, "zWT": 0.45, "zRB": -0.3, "zRG": -1.25, "roof": 1.3,
		"gb": 0.1, "gr": 0.25, "front": "quad", "rear": "bar", "hood": "scoop", "spoil": "wing",
		"tips": 2, "rim": "five", "skirt": true },
	# a beater hatchback
	"hatch": { "r": 0.32, "tw": 0.24, "zF": 1.25, "zR": -1.28, "yb": 0.3,
		"top": [[-1.97, 0.86], [-1.9, 0.98], [0.85, 0.96], [1.8, 0.82], [1.97, 0.62]],
		"sh": [[-1.95, 0.86], [0.0, 0.8], [1.95, 0.74]],
		"taper": [0.35, 0.1, 0.12, 0.05], "zWB": 0.9, "zWT": 0.1, "zRB": -1.6, "zRG": -1.88, "roof": 1.46,
		"zB": -0.32, "gb": 0.1, "gr": 0.25, "front": "small", "rear": "pair", "hood": "flat",
		"tips": 1, "rim": "steel", "skirt": false },
	# a cargo van
	"van": { "r": 0.38, "tw": 0.27, "zF": 1.65, "zR": -1.75, "yb": 0.42,
		"top": [[-2.6, 1.98], [1.22, 2.0], [1.28, 1.2], [1.9, 1.18], [2.45, 1.08], [2.6, 0.86]],
		"sh": [[-2.6, 1.05], [0.0, 1.05], [2.6, 0.98]],
		"taper": [0.25, 0.06, 0.05, 0.02], "zWB": 2.0, "zWT": 1.4, "zRB": 1.3, "zRG": 1.25, "roof": 2.04,
		"zB": 1.3, "gb": 0.1, "gr": 0.15, "front": "small", "rear": "vertical", "hood": "flat", "van": true,
		"tips": 1, "rim": "steel", "skirt": false },
}

static func spec(model):
	var p = P.get(model, P["sedan"]).duplicate(true)
	if p.has("base"):
		var b = P[p.base].duplicate(true)
		for k in p: b[k] = p[k]
		p = b
	return p

static func _interp(pts, z):
	if z <= pts[0][0]: return float(pts[0][1])
	for i in range(pts.size() - 1):
		var a = pts[i]
		var b = pts[i + 1]
		if z <= b[0]:
			var t = (z - a[0]) / max(0.0001, b[0] - a[0])
			return lerp(float(a[1]), float(b[1]), t)
	return float(pts[pts.size() - 1][1])

# the cabin measures for the interior (CAR_GEOM) and the wheelbase
static func geom(model, sp):
	var p = spec(model)
	var L = float(sp.len)
	var zN = L / 2.0 - 0.05
	var zM = (p.zWB + zN) / 2.0
	return { "zWB": p.zWB, "yWB": _interp(p.top, p.zWB), "zWT": p.zWT, "yWT": p.roof, "zRB": p.zRB, "roofY": p.roof,
		"zMid": zM, "yMid": _interp(p.top, zM), "zNose": zN, "yNose": _interp(p.top, zN) - 0.05, "wbLen": p.zF - p.zR, "r": p.r }

# ---------------------------------------------------------------- the build
var mb
var p
var L
var W
var hw
var tips = []           # where the exhaust tips are (backfire flames)

func build(model, sp):
	p = spec(model)
	L = float(sp.len)
	W = float(sp.wid)
	hw = W / 2.0 - 0.02
	mb = MB.new()
	var root = Spatial.new()
	_mats()
	_doors_plan()
	_body()
	_cabin()
	_front()
	_rear()
	_sides()
	_interior()
	if p.get("bar", false): _lightbar()
	if p.get("push", false): _pushbar()
	if p.get("taxi", false): _taxi_sign()
	mb.commit(root)
	_wheels(root)
	_doors_commit(root)
	root.set_meta("tips", tips)
	return root

# ---------------------------------------------------------------- doors
# the front doors run from the B pillar (or about 1.2 m back) to the windshield's base; the
# rear doors from the C pillar (or just past the rear wheel) to the B pillar
static func door_spans(p):
	var out = []
	var zf = float(p.zWB)
	var zb = float(p.zB) if p.has("zB") else zf - 1.2
	out.append([zb, zf, "F"])
	if not p.get("van", false) and p.get("bed", null) == null:
		if p.has("zC"): out.append([float(p.zC), zb, "R"])
		elif p.rear != "vertical" and p.has("zB") and float(p.zB) - float(p.zR) > 1.2: out.append([float(p.zR) + float(p.r) + 0.12, zb, "R"])
	return out

var doors = []
func _doors_plan():
	doors = []
	for sp in door_spans(p):
		for s in [-1, 1]:
			var m = MB.new(); m.mats = mb.mats
			var w = MB.new(); w.mats = mb.mats
			var h = Vector3(s * _halfw(sp[1]), 0.0, sp[1])
			var zm = (sp[0] + sp[1]) / 2.0
			doors.append({ "name": "D" + sp[2] + ("L" if s > 0 else "R"), "s": s, "z0": sp[0], "z1": sp[1], "mb": m, "win": w, "h": h,
				"wh": max(0.2, float(p.roof) - _interp(p.top, zm) - 0.06) })

func _door_at(za, zb, s):
	for d in doors:
		if d.s == int(s) and za >= d.z0 - 0.025 and zb <= d.z1 + 0.025 and zb > d.z0 + 0.01 and za < d.z1 - 0.01: return d
	return null

func _door_pt(c):
	for d in doors:
		if sign(c.x) == d.s and c.z >= d.z0 + 0.02 and c.z <= d.z1 - 0.02 and abs(c.x) > W * 0.3: return d
	return null

func _doors_commit(root):
	var dn = Spatial.new(); dn.name = "Doors"
	root.add_child(dn)
	var info = {}
	for d in doors:
		# the inside of the door: a panel, an armrest, and the rear edge closing it off
		var s = d.s
		var zm = (d.z0 + d.z1) / 2.0
		var xi = s * (_halfw(zm) - 0.08)
		var xo = s * (_halfw(zm) - 0.01)
		var y0 = p.yb + 0.14
		var y1 = _interp(p.top, zm) - 0.02
		var h = d.h
		d.mb.quad("trim", Vector3(xi, y0, d.z0 + 0.02) - h, Vector3(xi, y1, d.z0 + 0.02) - h, Vector3(xi, y1, d.z1 - 0.03) - h, Vector3(xi, y0, d.z1 - 0.03) - h, Vector3(-s, 0, 0), Vector2(), Vector2(), Vector2(), Vector2())
		d.mb.quad("trim", Vector3(xi, y0, d.z0 + 0.02) - h, Vector3(xo, y0, d.z0 + 0.02) - h, Vector3(xo, y1, d.z0 + 0.02) - h, Vector3(xi, y1, d.z0 + 0.02) - h, Vector3(0, 0, -1), Vector2(), Vector2(), Vector2(), Vector2())
		d.mb.box("liner", Transform(Basis(), Vector3(xi - s * 0.04, (y0 + y1) / 2.0 + 0.04, zm) - h), Vector3(0.08, 0.05, (d.z1 - d.z0) * 0.6), 0.5, false)
		var n = Spatial.new(); n.name = d.name
		n.translation = h
		d.mb.commit(n)
		var wn = Spatial.new(); wn.name = "Win"
		d.win.commit(wn)
		n.add_child(wn)
		dn.add_child(n)
		info[d.name] = [d.s, d.z0, d.z1, d.wh]
	root.set_meta("doors", info)

# what's behind the doors: a floor, the seats, the dash and a headliner (only seen with a door
# or a window open: the glass is dark)
func _interior():
	var yWB = _interp(p.top, p.zWB)
	var eyeY = yWB + (p.roof - yWB) * 0.62
	var eyeZ = p.zWB - 0.95
	var hy = eyeY - 0.7
	var xD = W * 0.21
	var zr = max(p.zRG + 0.2, p.zR + p.r + 0.15)
	mb.quad("liner", Vector3(-hw + 0.1, p.yb + 0.16, zr), Vector3(hw - 0.1, p.yb + 0.16, zr), Vector3(hw - 0.1, p.yb + 0.16, p.zWB), Vector3(-hw + 0.1, p.yb + 0.16, p.zWB), Vector3(0, 1, 0), Vector2(), Vector2(), Vector2(), Vector2())
	mb.quad("liner", Vector3(-hw + 0.12, p.roof - 0.04, p.zRB), Vector3(hw - 0.12, p.roof - 0.04, p.zRB), Vector3(hw - 0.12, p.roof - 0.04, p.zWT), Vector3(-hw + 0.12, p.roof - 0.04, p.zWT), Vector3(0, -1, 0), Vector2(), Vector2(), Vector2(), Vector2())
	for s in [-1, 1]:
		_box("trim", Vector3(s * xD, hy - 0.06, eyeZ - 0.05), Vector3(0.5, 0.14, 0.5))
		_box("trim", Vector3(s * xD, hy + 0.3, eyeZ - 0.34), Vector3(0.5, 0.62, 0.12), Vector3(-0.2, 0, 0))
	_box("liner", Vector3(0, yWB - 0.08, p.zWB - 0.22), Vector3(W - 0.24, 0.24, 0.4))
	if doors.size() > 2:
		var rz = eyeZ - 0.8
		_box("trim", Vector3(0, hy - 0.1, rz - 0.05), Vector3(W - 0.34, 0.14, 0.48))
		_box("trim", Vector3(0, hy + 0.25, rz - 0.34), Vector3(W - 0.34, 0.56, 0.12), Vector3(-0.15, 0, 0))

# the wheels are their own nodes so they can roll and steer (Vehicles.gd turns them):
# Wheels/W[F|R][L|R] sits on the hub and steers about y; its "spin" child rolls about x. The
# caliper stays on the knuckle, outside the spin.
func _wheels(root):
	var body = mb
	var parts = {}
	for s in [-1, 1]:
		var got = []
		for part in ["spin", "cal"]:
			mb = MB.new(); mb.mats = body.mats
			_wheel(0.0, 0.0, s, 0.0, part)
			var n = Spatial.new(); n.name = part
			mb.commit(n)
			got.append(n)
		parts[s] = got
	mb = body
	var wr = Spatial.new(); wr.name = "Wheels"
	root.add_child(wr)
	for w in [[p.zF, "F"], [p.zR, "R"]]:
		for s in [-1, 1]:
			var piv = Spatial.new(); piv.name = "W" + w[1] + ("L" if s > 0 else "R")
			piv.translation = Vector3(s * (hw - p.tw / 2 + 0.01), p.r, w[0])
			piv.add_child(parts[s][1].duplicate())
			piv.add_child(parts[s][0].duplicate())
			wr.add_child(piv)

func _cm(col, gloss = false, unshaded = false):
	var m = SpatialMaterial.new()
	m.albedo_color = col
	m.roughness = 0.25 if gloss else 0.7
	if unshaded: m.flags_unshaded = true
	else: G.toon(m, true)
	return m

func _mats():
	mb.mat("paint", _cm(Color(1, 1, 1), true))
	mb.mat("paint_b", _cm(Color(1, 1, 1), true))     # (named paint*: the car's colour goes on it too)
	var gl = _cm(Color(0.035, 0.045, 0.06), false)
	gl.roughness = 0.6
	gl.params_cull_mode = SpatialMaterial.CULL_DISABLED
	mb.mat("glass", gl)
	mb.mat("trim", _cm(Color(0.045, 0.045, 0.05)))
	mb.mat("chrome", _cm(Color(0.82, 0.84, 0.88), true))
	mb.mat("tire", _cm(Color(0.04, 0.04, 0.045)))
	mb.mat("rim", _cm(Color(0.62, 0.64, 0.68) if p.rim in ["chrome", "steel"] else Color(0.12, 0.12, 0.13), true))
	mb.mat("disc", _cm(Color(0.36, 0.37, 0.39), true))
	mb.mat("caliper", _cm(Color(0.75, 0.08, 0.06) if p.get("awd", false) else Color(0.3, 0.31, 0.33)))
	mb.mat("lightw", _cm(Color(1.0, 0.98, 0.92), false, true))
	mb.mat("lightr", _cm(Color(0.62, 0.05, 0.04), false, true))      # running lamps; braking swaps in a bright one
	mb.mat("rev", _cm(Color(0.4, 0.4, 0.42), false, true))           # reverse lamps, lit when you back up
	mb.mat("lightb", _cm(Color(0.1, 0.3, 1.0), false, true))
	mb.mat("amber", _cm(Color(1.0, 0.55, 0.08), false, true))
	mb.mat("liner", _cm(Color(0.02, 0.02, 0.022)))
	mb.mat("taxi", _cm(Color(0.98, 0.78, 0.1)))

# ---------------------------------------------------------------- the body
func _halfw(z):
	var t = p.taper
	var w = hw
	var zf = L / 2.0 - t[0]
	if z > zf: w -= pow((z - zf) / t[0], 2.0) * t[1]
	var zr = -L / 2.0 + t[2]
	if z < zr: w -= pow((zr - z) / t[2], 2.0) * t[3]
	return w

func _arch(z, y0):
	for zw in [p.zF, p.zR]:
		var ra = p.r + 0.07
		var d = z - zw
		if abs(d) < ra:
			return max(y0, p.r + sqrt(ra * ra - d * d) * 0.97)
	return y0

# one cross-section (right side, bottom to top)
func _section(z):
	var w = _halfw(z)
	var top = _interp(p.top, z)
	var yb = p.yb + (0.06 if abs(z) > L / 2.0 - 0.35 else 0.0)
	var a0y = _arch(z, yb)
	var a1y = _arch(z, yb + 0.12) + (0.02 if a0y > yb + 0.001 else 0.0)
	var sh = max(_interp(p.sh, z), a1y + 0.06)
	sh = min(sh, top - 0.06)
	var pts = [Vector2(w - 0.07, a0y), Vector2(w, max(a1y, a0y + 0.02)), Vector2(w + 0.012, sh - 0.04), Vector2(w, sh),
		Vector2(w - 0.03, top - 0.03), Vector2(w - 0.1, top), Vector2(0.0, top + 0.03)]
	return pts

func _stations():
	var zs = []
	var n = 34
	for i in range(n + 1): zs.append(-L / 2.0 + L * i / n)
	for k in ["zWB", "zWT", "zRB", "zRG", "zB", "zC"]:
		if p.has(k): zs.append(float(p[k]))
	for sp in door_spans(p):
		zs.append(sp[0]); zs.append(sp[1])
	for zw in [p.zF, p.zR]:
		for d in [-0.48, -0.4, -0.3, -0.18, -0.06, 0.06, 0.18, 0.3, 0.4, 0.48]:
			zs.append(zw + d * (p.r + 0.07) / 0.48)
	zs.sort()
	var out = []
	for z in zs:
		if z < -L / 2.0 - 0.001 or z > L / 2.0 + 0.001: continue
		if out.size() > 0 and abs(z - out[out.size() - 1]) < 0.02: continue
		out.append(z)
	return out

func _q(k, a, b, c, d, hint, dr = null, win = false):
	var n = (b - a).cross(d - a)
	if n.length() < 1e-6: n = (c - b).cross(d - b)
	n = n.normalized()
	if n.dot(hint) < 0: n = -n
	if dr != null:
		var h = dr.h
		(dr.win if win else dr.mb).quad(k, a - h, b - h, c - h, d - h, n, Vector2(), Vector2(), Vector2(), Vector2())
		return
	mb.quad(k, a, b, c, d, n, Vector2(), Vector2(), Vector2(), Vector2())

func _body():
	var zs = _stations()
	var bed = p.get("bed", null)
	for i in range(zs.size() - 1):
		var za = zs[i]
		var zb = zs[i + 1]
		var A = _section(za)
		var B = _section(zb)
		for s in [-1.0, 1.0]:
			for k in range(A.size() - 1):
				# the pickup's bed: no lid over it
				if bed != null and k == A.size() - 2 and zb <= bed + 0.001: continue
				var a0 = Vector3(A[k].x * s, A[k].y, za)
				var a1 = Vector3(A[k + 1].x * s, A[k + 1].y, za)
				var b0 = Vector3(B[k].x * s, B[k].y, zb)
				var b1 = Vector3(B[k + 1].x * s, B[k + 1].y, zb)
				var mid = (a0 + b1) * 0.5
				var hint = Vector3(mid.x * 2.0, mid.y - 0.55, 0.0)
				if k >= A.size() - 3: hint = Vector3(mid.x * 0.6, 1.0, 0.0)
				# the flank between the seams is a door
				var dr = _door_at(za, zb, s) if k < A.size() - 2 else null
				_q("paint", a0, a1, b1, b0, hint, dr)
	# nose and tail caps
	for e in [[zs[zs.size() - 1], 1.0], [zs[0], -1.0]]:
		var S = _section(e[0])
		var poly = PoolVector2Array()
		for q in S: poly.append(q)
		for j in range(S.size() - 1, -1, -1): poly.append(Vector2(-S[j].x, S[j].y))
		var tris = Geometry.triangulate_polygon(poly)
		for t in range(0, tris.size(), 3):
			var a = poly[tris[t]]
			var b = poly[tris[t + 1]]
			var c = poly[tris[t + 2]]
			mb.tri("paint", Vector3(a.x, a.y, e[0]), Vector3(b.x, b.y, e[0]), Vector3(c.x, c.y, e[0]), Vector3(0, 0, e[1]))
	# wheel-well liners: dark half pipes inside each arch, closed on the inner side
	for zw in [p.zF, p.zR]:
		var ra = p.r + 0.07
		for s in [-1.0, 1.0]:
			var xo = s * (_halfw(zw) - 0.02)
			var xi = s * (_halfw(zw) - 0.36)
			var segs = 10
			for j in range(segs):
				var t0 = PI * j / segs
				var t1 = PI * (j + 1) / segs
				var p0 = Vector3(0, p.r + sin(t0) * ra, zw + cos(t0) * ra)
				var p1 = Vector3(0, p.r + sin(t1) * ra, zw + cos(t1) * ra)
				_q("liner", Vector3(xo, p0.y, p0.z), Vector3(xo, p1.y, p1.z), Vector3(xi, p1.y, p1.z), Vector3(xi, p0.y, p0.z), Vector3(0, p.r - (p0.y + p1.y) * 0.5, zw - (p0.z + p1.z) * 0.5))
				mb.tri("liner", Vector3(xi, p.r, zw), Vector3(xi, p0.y, p0.z), Vector3(xi, p1.y, p1.z), Vector3(-s, 0, 0))
	if bed != null: _bed(bed)

func _bed(zf):
	var zt = -L / 2.0 + 0.04
	var y0 = p.yb + 0.28
	var top = _interp(p.top, (zf + zt) / 2.0)
	var w = _halfw((zf + zt) / 2.0) - 0.07
	mb.box("trim", Transform(Basis(), Vector3(0, y0, (zf + zt) / 2.0)), Vector3(w * 2.0, 0.04, zf - zt), 0.5, false)
	for s in [-1, 1]:
		mb.box("paint", Transform(Basis(), Vector3(s * (w - 0.02), (y0 + top) / 2.0, (zf + zt) / 2.0)), Vector3(0.04, top - y0, zf - zt), 0.5, false)
		mb.box("trim", Transform(Basis(), Vector3(s * (w + 0.03), top + 0.01, (zf + zt) / 2.0)), Vector3(0.12, 0.03, zf - zt), 0.5, false)
	mb.box("paint", Transform(Basis(), Vector3(0, (y0 + top) / 2.0, zf - 0.02)), Vector3(w * 2.0, top - y0, 0.04), 0.5, false)
	mb.box("paint", Transform(Basis(), Vector3(0, (y0 + top) / 2.0, zt + 0.02)), Vector3(w * 2.0, top - y0, 0.04), 0.5, false)

# the cabin: belt line to roof, with tumblehome; glass and pillars where they belong
func _gtop(z):
	if z >= p.zWB or z <= p.zRG: return -1.0
	var belt = _interp(p.top, z)
	if z > p.zWT: return lerp(p.roof, belt, (z - p.zWT) / max(0.01, p.zWB - p.zWT))
	if z < p.zRB: return lerp(p.roof, belt, (p.zRB - z) / max(0.01, p.zRB - p.zRG))
	return p.roof

func _cabin():
	var zs = []
	for z in _stations():
		if z >= p.zRG - 0.001 and z <= p.zWB + 0.001: zs.append(z)
	if zs.empty() or zs[0] > p.zRG + 0.001: zs.push_front(p.zRG)
	if zs[zs.size() - 1] < p.zWB - 0.001: zs.append(p.zWB)
	for i in range(zs.size() - 1):
		var za = zs[i]
		var zb = zs[i + 1]
		var zm = (za + zb) * 0.5
		var A = _gsec(za)
		var B = _gsec(zb)
		var wind = zm > p.zWT                   # the windshield slope
		var back = zm < p.zRB                    # the rear glass slope
		var side_k = "glass"
		if wind: side_k = "paint"                # the A pillar
		elif back and not p.get("van", false): side_k = "paint" if p.zRB - p.zRG > 0.3 else "glass"
		if p.has("zB") and abs(zm - p.zB) < 0.075: side_k = "trim"
		if p.has("zC") and abs(zm - p.zC) < 0.08: side_k = "trim"
		if zm < p.zRB + 0.12 and zm > p.zRB - 0.02 and p.zRB - p.zRG < 0.3: side_k = "paint"   # a D pillar
		if p.get("van", false) and zm < p.zB - 0.05: side_k = "paint"
		for s in [-1.0, 1.0]:
			for k in range(A.size() - 1):
				var key = side_k if k == 0 else ("glass" if (wind or back) else "paint_b")
				var a0 = Vector3(A[k].x * s, A[k].y, za)
				var a1 = Vector3(A[k + 1].x * s, A[k + 1].y, za)
				var b0 = Vector3(B[k].x * s, B[k].y, zb)
				var b1 = Vector3(B[k + 1].x * s, B[k + 1].y, zb)
				var hint = Vector3(s * (1.0 if k == 0 else 0.4), 0.7 if k == 0 else 1.0, 0.0)
				if wind and k > 0: hint = Vector3(0, 0.6, 0.8)
				if back and k > 0: hint = Vector3(0, 0.6, -0.8)
				# the side glass over a door winds down into it
				var dw = _door_at(za, zb, s) if k == 0 and key == "glass" else null
				_q(key, a0, a1, b1, b0, hint, dw, true)
	# a chrome or black strip along the belt
	var bk = "chrome" if p.get("chrome", false) else "trim"
	for s in [-1, 1]:
		var z0 = p.zRG + 0.1
		var z1 = p.zWB - 0.05
		var y = _interp(p.top, (z0 + z1) / 2.0)
		mb.box(bk, Transform(Basis(), Vector3(s * (_halfw((z0 + z1) / 2.0) - p.gb + 0.01), y + 0.015, (z0 + z1) / 2.0)), Vector3(0.025, 0.025, z1 - z0), 0.5, false)

func _gsec(z):
	var belt = _interp(p.top, z)
	var top = _gtop(z)
	if top < 0: top = belt
	var w = _halfw(z)
	var wb = w - p.gb
	var wr = w - p.gr
	var h = max(0.0, top - belt)
	return [Vector2(wb, belt - 0.005), Vector2(lerp(wb, wr, 0.85), belt + h * 0.9), Vector2(wr, top), Vector2(0.0, top + min(0.03, h * 0.1))]

# ---------------------------------------------------------------- faces
func _box(k, c, s, rot = Vector3(), on_door = false):
	var b = Basis(Vector3(1, 0, 0), rot.x) * Basis(Vector3(0, 1, 0), rot.y) * Basis(Vector3(0, 0, 1), rot.z)
	var dr = _door_pt(c) if on_door else null
	if dr != null:
		dr.mb.box(k, Transform(b, c - dr.h), s, 0.5, false)
		return
	mb.box(k, Transform(b, c), s, 0.5, false)

func _front():
	var zn = L / 2.0
	var wn = _halfw(zn)
	var yt = _interp(p.top, zn)
	var yb = p.yb + 0.06
	var z = zn + 0.012
	var mid = (yt + yb) / 2.0
	match p.front:
		"bar":
			# a light bar right across the nose, the lamps at its ends, a wide grille and a slot
			_box("lightw", Vector3(0, yt - 0.06, z), Vector3(wn * 2.0 - 0.16, 0.022, 0.02))
			for s in [-1, 1]:
				_box("lightw", Vector3(s * (wn - 0.22), yt - 0.1, z), Vector3(0.3, 0.05, 0.02))
			_box("trim", Vector3(0, mid + 0.02, z), Vector3(wn * 2.0 - 0.5, 0.2, 0.02))
			for gy in [-0.05, 0.0, 0.05]:
				_box("trim", Vector3(0, mid + 0.02 + gy, z + 0.012), Vector3(wn * 2.0 - 0.55, 0.012, 0.012))
			_box("trim", Vector3(0, yb + 0.08, z), Vector3(wn * 2.0 - 0.3, 0.1, 0.02))
			_box("trim", Vector3(0, yb + 0.01, z + 0.04), Vector3(wn * 2.0 - 0.1, 0.02, 0.08))
		"slim":
			# slim lamps with a C of light inside, a wide mesh grille with a bar across
			for s in [-1, 1]:
				_box("lightw", Vector3(s * (wn - 0.24), yt - 0.09, z), Vector3(0.34, 0.045, 0.02))
				_box("lightw", Vector3(s * (wn - 0.08), yt - 0.14, z), Vector3(0.02, 0.1, 0.02))
				_box("amber", Vector3(s * (wn - 0.28), yb + 0.14, z), Vector3(0.16, 0.03, 0.02))
			_box("trim", Vector3(0, mid + 0.06, z), Vector3(wn * 2.0 - 0.7, 0.28, 0.02))
			for gx in range(-4, 5):
				_box("trim", Vector3(gx * 0.12, mid + 0.06, z + 0.012), Vector3(0.01, 0.26, 0.012))
			_box("paint", Vector3(0, mid + 0.06, z + 0.018), Vector3(wn * 2.0 - 0.72, 0.035, 0.02))
			_box("trim", Vector3(0, yb + 0.1, z), Vector3(wn * 2.0 - 0.3, 0.14, 0.02))
			_box("chrome", Vector3(0, yb + 0.02, z + 0.03), Vector3(0.9, 0.03, 0.06))
		"upright":
			# a tall chrome-framed mesh grille, square lamps, a chrome strip in the bumper
			_box("chrome", Vector3(0, mid + 0.03, z), Vector3(0.82, 0.36, 0.02))
			_box("trim", Vector3(0, mid + 0.03, z + 0.01), Vector3(0.74, 0.29, 0.02))
			for gx in range(-5, 6):
				_box("chrome", Vector3(gx * 0.065, mid + 0.03, z + 0.022), Vector3(0.008, 0.27, 0.008))
			for gy in range(-3, 4):
				_box("chrome", Vector3(0, mid + 0.03 + gy * 0.04, z + 0.022), Vector3(0.72, 0.008, 0.008))
			for s in [-1, 1]:
				_box("lightw", Vector3(s * (wn - 0.2), yt - 0.1, z), Vector3(0.28, 0.1, 0.02))
				_box("amber", Vector3(s * (wn - 0.07), yt - 0.1, z - 0.02), Vector3(0.04, 0.08, 0.04))
			_box("chrome", Vector3(0, yb + 0.11, z), Vector3(wn * 2.0 - 0.2, 0.03, 0.02))
		"bars":
			# a big grille with heavy chrome bars, stacked lamps
			_box("trim", Vector3(0, mid + 0.04, z), Vector3(wn * 2.0 - 0.62, 0.38, 0.02))
			for gy in [-0.08, 0.06]:
				_box("chrome", Vector3(0, mid + 0.04 + gy, z + 0.015), Vector3(wn * 2.0 - 0.6, 0.06, 0.02))
			for s in [-1, 1]:
				_box("lightw", Vector3(s * (wn - 0.16), yt - 0.1, z), Vector3(0.24, 0.08, 0.02))
				_box("lightw", Vector3(s * (wn - 0.16), yt - 0.2, z), Vector3(0.22, 0.05, 0.02))
			_box("chrome", Vector3(0, yb + 0.1, z), Vector3(wn * 2.0 - 0.1, 0.12, 0.03))
		"quad":
			# a full-width black grille with four round lamps set in it
			_box("trim", Vector3(0, mid + 0.04, z), Vector3(wn * 2.0 - 0.12, 0.24, 0.02))
			for s in [-1, 1]:
				for o in [0.14, 0.36]:
					var c = Vector3(s * (wn - o), mid + 0.04, z + 0.012)
					mb.lathe("lightw", Transform(Basis(Vector3(1, 0, 0), PI / 2), c), [[0.0, -0.01], [0.075, -0.01], [0.075, 0.01], [0.0, 0.01]], 12)
			_box("trim", Vector3(0, yb + 0.06, z), Vector3(wn * 2.0 - 0.4, 0.09, 0.02))
		"small":
			_box("trim", Vector3(0, mid + 0.02, z), Vector3(wn * 2.0 - 0.8, 0.12, 0.02))
			for s in [-1, 1]:
				_box("lightw", Vector3(s * (wn - 0.2), yt - 0.09, z), Vector3(0.26, 0.09, 0.02))
				_box("amber", Vector3(s * (wn - 0.05), yt - 0.09, z - 0.03), Vector3(0.03, 0.06, 0.06))
			_box("trim", Vector3(0, yb + 0.06, z), Vector3(wn * 2.0 - 0.2, 0.1, 0.02))
	# the hood: a power bulge or a scoop
	var zh = (p.zWB + zn) / 2.0
	var yh = _interp(p.top, zh) + 0.03
	if p.hood == "bulge":
		_box("paint", Vector3(0, yh + 0.012, zh - 0.05), Vector3(0.7, 0.04, (zn - p.zWB) * 0.75), Vector3(atan2(_interp(p.top, p.zWB) - _interp(p.top, zn - 0.2), zn - p.zWB) * 0.8, 0, 0))
	elif p.hood == "scoop":
		_box("paint", Vector3(0, yh + 0.03, zh), Vector3(0.5, 0.06, 0.6))
		_box("trim", Vector3(0, yh + 0.035, zh + 0.301), Vector3(0.42, 0.04, 0.01))

func _rear():
	var zt = -L / 2.0
	var wt = _halfw(zt)
	var yt = _interp(p.top, zt)
	var yb = p.yb + 0.06
	var z = zt - 0.012
	var ly = yt - 0.1
	match p.rear:
		"racetrack":
			# one lamp in a ring right round the tail
			_box("lightr", Vector3(0, ly + 0.045, z), Vector3(wt * 2.0 - 0.12, 0.022, 0.02))
			_box("lightr", Vector3(0, ly - 0.045, z), Vector3(wt * 2.0 - 0.12, 0.022, 0.02))
			for s in [-1, 1]:
				_box("lightr", Vector3(s * (wt - 0.07), ly, z), Vector3(0.022, 0.11, 0.02))
			_box("trim", Vector3(0, ly, z + 0.004), Vector3(wt * 2.0 - 0.16, 0.068, 0.02))
		"bar":
			_box("lightr", Vector3(0, ly, z), Vector3(wt * 2.0 - 0.1, 0.07, 0.02))
		"pair":
			for s in [-1, 1]:
				_box("lightr", Vector3(s * (wt - 0.2), ly, z), Vector3(0.32, 0.12, 0.02))
				_box("rev", Vector3(s * (wt - 0.2), ly - 0.075, z), Vector3(0.12, 0.03, 0.02))
			_box("chrome" if p.get("chrome", false) else "trim", Vector3(0, ly, z), Vector3(wt * 2.0 - 0.75, 0.05, 0.02))
		"vertical":
			for s in [-1, 1]:
				_box("lightr", Vector3(s * (wt - 0.06), yt - 0.22, z), Vector3(0.1, 0.36, 0.02))
	if p.rear != "pair":
		for s in [-1, 1]:
			_box("rev", Vector3(s * (wt * 0.42), yb + 0.2, z), Vector3(0.14, 0.035, 0.02))
	# the bumper, the diffuser and the tips
	_box("trim", Vector3(0, yb + 0.07, z), Vector3(wt * 2.0 - 0.2, 0.12, 0.03))
	var n = int(p.get("tips", 2))
	var xs = []
	if n == 4: xs = [-0.55, -0.42, 0.42, 0.55]
	elif n == 2: xs = [-0.5, 0.5]
	elif n == 1: xs = [0.45]
	for x in xs:
		var c = Vector3(x * wt / 0.95, yb + 0.06, z - 0.02)
		tips.append(c + Vector3(0, 0, -0.06))
		mb.lathe("chrome", Transform(Basis(Vector3(1, 0, 0), PI / 2), c), [[0.035, -0.05], [0.045, -0.05], [0.045, 0.05], [0.035, 0.05]], 10)
		mb.lathe("trim", Transform(Basis(Vector3(1, 0, 0), PI / 2), c + Vector3(0, 0, 0.02)), [[0.0, -0.01], [0.036, -0.01], [0.036, 0.01], [0.0, 0.01]], 10)
	# spoilers
	var sp = p.get("spoil", "")
	if sp == "duck":
		_box("paint", Vector3(0, yt + 0.02, zt + 0.06), Vector3(wt * 2.0 - 0.2, 0.04, 0.12), Vector3(-0.25, 0, 0))
	elif sp == "wing":
		_box("paint", Vector3(0, yt + 0.16, zt + 0.12), Vector3(wt * 2.0 - 0.1, 0.03, 0.2), Vector3(-0.1, 0, 0))
		for s in [-1, 1]:
			_box("paint", Vector3(s * (wt - 0.25), yt + 0.08, zt + 0.12), Vector3(0.04, 0.14, 0.1))
	elif sp == "roof":
		_box("paint", Vector3(0, p.roof - 0.01, p.zRB - 0.06), Vector3((_halfw(p.zRB) - p.gr) * 2.0 + 0.05, 0.04, 0.22), Vector3(-0.15, 0, 0))
	if p.get("van", false):
		_box("trim", Vector3(0, (yt + yb) / 2.0 + 0.2, z), Vector3(0.012, yt - yb - 0.4, 0.02))
	elif p.zRB - p.zRG < 0.3:
		# a tailgate: the rear glass is upright; a handle under it
		_box("chrome" if p.get("chrome", false) else "trim", Vector3(0, yt - 0.25, z), Vector3(0.3, 0.04, 0.02))

func _sides():
	for s in [-1, 1]:
		var x = s * (hw + 0.012)
		# a black sill or a sculpted skirt
		_box("trim", Vector3(s * (hw - 0.05), p.yb + 0.04, (p.zF + p.zR) / 2.0), Vector3(0.06, 0.07, p.zF - p.zR - 2.0 * (p.r + 0.1)))
		# mirrors on the doors
		var zm = p.zWB - 0.12
		var ym = _interp(p.top, zm) + 0.1
		_box("paint", Vector3(s * (_halfw(zm) + 0.1), ym, zm), Vector3(0.18, 0.1, 0.12), Vector3(), true)
		_box("trim", Vector3(s * (_halfw(zm) + 0.02), ym - 0.04, zm), Vector3(0.06, 0.03, 0.05), Vector3(), true)
		# door seams and handles
		var cuts = [p.zWB - 0.05]
		if p.has("zB"): cuts.append(p.zB)
		if p.has("zC"): cuts.append(p.zC)
		elif not p.get("van", false) and p.rear != "vertical" and p.has("zB") and p.zB - p.zR > 1.2: cuts.append(p.zR + p.r + 0.12)
		for zc in cuts:
			var w = _halfw(zc)
			var y1 = _interp(p.top, zc) - 0.02
			_box("trim", Vector3(s * (w + 0.004), (p.yb + 0.12 + y1) / 2.0, zc), Vector3(0.006, y1 - p.yb - 0.14, 0.008), Vector3(), true)
		for i in range(cuts.size() - 1):
			var zh = cuts[i] - 0.18
			var yh = _interp(p.top, zh) - 0.12
			_box("chrome" if p.get("chrome", false) else "paint", Vector3(s * (_halfw(zh) + 0.012), yh, zh), Vector3(0.02, 0.03, 0.14), Vector3(), true)
		# roof rails
		if p.get("rails", false):
			var z0 = p.zRB + 0.15
			var z1 = p.zWT - 0.1
			_box("trim", Vector3(s * (_halfw((z0 + z1) / 2.0) - p.gr - 0.02), p.roof + 0.06, (z0 + z1) / 2.0), Vector3(0.04, 0.04, z1 - z0))
			for zz in [z0, z1]:
				_box("trim", Vector3(s * (_halfw(zz) - p.gr - 0.02), p.roof + 0.03, zz), Vector3(0.05, 0.06, 0.08))
		# the side marker lamps
		_box("amber", Vector3(s * (_halfw(L / 2.0 - 0.2) + 0.006), _interp(p.top, L / 2.0 - 0.2) - 0.14, L / 2.0 - 0.2), Vector3(0.01, 0.03, 0.08))
		_box("lightr", Vector3(s * (_halfw(-L / 2.0 + 0.2) + 0.006), _interp(p.top, -L / 2.0 + 0.2) - 0.14, -L / 2.0 + 0.2), Vector3(0.01, 0.03, 0.08))

# ---------------------------------------------------------------- wheels
func _wheel(x, z, s, yc = -1.0, part = ""):
	var r = p.r
	if yc < 0: yc = r
	var w = p.tw
	var spin = part != "cal"
	var cal = part != "spin"
	var xf = Transform(Basis(Vector3(0, 0, 1), PI / 2), Vector3(x, yc, z))
	var rr = r * (0.68 if p.rim in ["five", "split"] else 0.62)
	var face = x + s * (w / 2 - 0.015)
	if cal:
		_box("caliper", Vector3(face - s * 0.04, yc + rr * 0.55, z - 0.05), Vector3(0.05, rr * 0.4, rr * 0.5))
	if not spin: return
	# the tire: tread, rounded shoulders, sidewalls down to the rim
	mb.lathe("tire", xf, [[rr, -w / 2], [r * 0.93, -w / 2], [r, -w / 2 + 0.03], [r, w / 2 - 0.03], [r * 0.93, w / 2], [rr, w / 2]], 18)
	# a few tread blocks, so you can see it roll
	for k in range(8):
		var a0 = TAU * k / 8.0
		mb.box("trim", Transform(Basis(Vector3(1, 0, 0), -a0), Vector3(x, yc + sin(a0) * (r - 0.004), z + cos(a0) * (r - 0.004))), Vector3(w * 0.8, 0.012, 0.05), 0.5, false)
	var hub = Transform(Basis(Vector3(0, 0, 1), PI / 2), Vector3(face, yc, z))
	# behind the spokes: the disc
	mb.lathe("disc", Transform(Basis(Vector3(0, 0, 1), PI / 2), Vector3(face - s * 0.06, yc, z)), [[0.0, -0.01], [rr * 0.85, -0.01], [rr * 0.85, 0.01], [0.0, 0.01]], 14)
	# the rim: a lip, then spokes or a steel dish
	mb.lathe("rim", hub, [[rr * 0.92, -0.02], [rr, -0.02], [rr, 0.015], [rr * 0.92, 0.015]], 16)
	match p.rim:
		"steel":
			mb.lathe("rim", hub, [[0.0, -0.012], [rr * 0.92, -0.012], [rr * 0.92, 0.0], [0.0, 0.0]], 14)
			for k in range(6):
				var a = TAU * k / 6.0
				_box("trim", Vector3(face + s * 0.003, yc + sin(a) * rr * 0.6, z + cos(a) * rr * 0.6), Vector3(0.008, 0.03, 0.03))
		_:
			var n = { "five": 5, "split": 10, "chrome": 6 }.get(p.rim, 5)
			var thick = 0.055 if n <= 6 else 0.03
			for k in range(n):
				var a = TAU * k / n + (0.12 if p.rim == "split" and k % 2 == 1 else 0.0)
				var c = Vector3(face, yc + sin(a) * rr * 0.5, z + cos(a) * rr * 0.5)
				mb.box("rim", Transform(Basis(Vector3(1, 0, 0), -a), c), Vector3(0.025, thick, rr * 0.92), 0.5, false)
	mb.lathe("rim", Transform(Basis(Vector3(0, 0, 1), PI / 2), Vector3(face + s * 0.005, yc, z)), [[0.0, -0.01], [rr * 0.2, -0.01], [rr * 0.2, 0.01], [0.0, 0.01]], 10)

# ---------------------------------------------------------------- police, taxi
func _lightbar():
	var z = (p.zWT + p.zRB) / 2.0 + 0.1
	var y = p.roof + 0.05
	_box("trim", Vector3(0, y, z), Vector3(1.2, 0.05, 0.26))
	_box("lightr", Vector3(-0.32, y + 0.05, z), Vector3(0.5, 0.06, 0.2))
	_box("lightb", Vector3(0.32, y + 0.05, z), Vector3(0.5, 0.06, 0.2))
	_box("lightw", Vector3(0, y + 0.05, z), Vector3(0.12, 0.05, 0.18))

func _pushbar():
	var zn = L / 2.0 + 0.12
	var yb = p.yb + 0.1
	for s in [-1, 1]:
		_box("trim", Vector3(s * 0.32, yb + 0.25, zn), Vector3(0.05, 0.5, 0.05))
	for y in [yb + 0.12, yb + 0.42]:
		_box("trim", Vector3(0, y, zn + 0.01), Vector3(0.72, 0.05, 0.05))

func _taxi_sign():
	var z = (p.zWT + p.zRB) / 2.0
	_box("taxi", Vector3(0, p.roof + 0.1, z), Vector3(0.6, 0.16, 0.22))
	_box("trim", Vector3(0, p.roof + 0.02, z), Vector3(0.64, 0.03, 0.26))
