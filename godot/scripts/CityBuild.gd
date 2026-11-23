extends Node
# The city's buildings, built here in detail from assets/world/buildings.json (footprint,
# height, style and street side of each one, exported from the generator in src/40_world.js),
# and the street furniture around them.
#
# Low poly, but modelled: brick, brownstone, greystone, siding, cream brick and warehouse
# fronts with windows that have depth (surrounds, sills with snow on them, lintels, glass that
# shows the sky by day and lit rooms at night), storefronts with sign bands and awnings,
# doors with steps, cornices with brackets and dentils, parapets with coping, roofs with their
# clutter (AC units, vents, hatches, chimneys, water towers, antennas), fire escapes; on the
# streets curbs, crosswalks, hydrants, bins, newspaper boxes, bus shelters, signs, bare trees,
# and utility poles with wires down the alleys.
#
# Every piece is a small template built once and stamped (Transform.xform on whole arrays,
# native and fast) into one merged mesh per 96 m chunk and material: GLES2 has no hardware
# instancing, so merged meshes are what old GPUs draw fastest. The fine detail is a separate
# mesh per chunk, hidden past a distance that depends on the quality setting.

var main
const CH = 96.0
const TILE = 6.0                 # metres per wall texture tile
const STY = ["brick", "brown", "grey", "siding", "cream", "ware"]
const UP = Vector3(0, 1, 0)
var chunks = {}
var mats = {}
var glass_mat
var sign_mat
var keep = []                    # AABBs nothing may cover (shop windows, signs, special doors)
var bx = []                      # every building as { x0, z0, x1, z1, h }
var R = RandomNumberGenerator.new()
var mods = {}                    # templates, by key
var det_r = 150.0
var _t = 0.0
var info = { "tris": 0, "windows": 0, "chunks": 0, "props": 0, "ms": 0 }

# ---------------------------------------------------------------- geometry buffers
# (the appends live in the class itself: a pool array reached through another object is a
# copy in Godot 3, so b.v.append() from outside would be lost)
class Buf:
	var v = PoolVector3Array()
	var n = PoolVector3Array()
	var c = PoolColorArray()
	var u = PoolVector2Array()
	var u2 = PoolVector2Array()
	func tri3(p0, p1, p2, nr, col, uv):
		v.append(p0); v.append(p1); v.append(p2)
		n.append(nr); n.append(nr); n.append(nr)
		c.append(col); c.append(col); c.append(col)
		if uv == null:
			u.append(Vector2()); u.append(Vector2()); u.append(Vector2())
		else:
			u.append(uv[0]); u.append(uv[1]); u.append(uv[2])
	func add_u2(x, k):
		for _i in range(k): u2.append(x)
	func cat(sv, sn, sc, su, su2):
		v.append_array(sv); n.append_array(sn); c.append_array(sc); u.append_array(su)
		if su2.size() > 0: u2.append_array(su2)
	func set_col(i, col):
		c.set(i, col)

# one quad, corners in order round the face; turned to face along nr (Godot's front faces
# wind clockwise)
func quad(b, p0, p1, p2, p3, nr, col, uv = null, u2 = null):
	if (p1 - p0).cross(p2 - p0).dot(nr) > 0:
		var t = p1
		p1 = p3; p3 = t
		if uv != null: uv = [uv[0], uv[3], uv[2], uv[1]]
	if uv == null:
		b.tri3(p0, p1, p2, nr, col, null)
		b.tri3(p0, p2, p3, nr, col, null)
	else:
		b.tri3(p0, p1, p2, nr, col, [uv[0], uv[1], uv[2]])
		b.tri3(p0, p2, p3, nr, col, [uv[0], uv[2], uv[3]])
	if u2 != null: b.add_u2(u2, 6)

func tri(b, p0, p1, p2, nr, col, uv = null):
	if (p1 - p0).cross(p2 - p0).dot(nr) > 0:
		var t = p1
		p1 = p2; p2 = t
		if uv != null: uv = [uv[0], uv[2], uv[1]]
	b.tri3(p0, p1, p2, nr, col, uv)

# a box: centre c, half sizes e, turned by bs; skip is a mask of faces to leave out
# (1 +x, 2 -x, 4 +y, 8 -y, 16 +z, 32 -z); top colours the +y face (snow)
const SKIP_BACK = 32
func box(b, c, e, col, bs = Basis(), skip = 0, top = null):
	var ax = [bs.x, bs.y, bs.z]
	var ee = [e.x, e.y, e.z]
	for f in range(6):
		if skip & (1 << f): continue
		var i = f / 2
		var nr = ax[i] * (1.0 if f % 2 == 0 else -1.0)
		var a1 = ax[(i + 1) % 3] * ee[(i + 1) % 3]
		var a2 = ax[(i + 2) % 3] * ee[(i + 2) % 3]
		var fc = c + nr * ee[i]
		quad(b, fc - a1 - a2, fc + a1 - a2, fc + a1 + a2, fc - a1 + a2, nr, top if (top != null and f == 2) else col)

# a box between two corners (axis aligned in the template's space)
func boxr(b, lo, hi, col, skip = 0, top = null):
	box(b, (lo + hi) * 0.5, (hi - lo) * 0.5, col, Basis(), skip, top)

# an upright prism (seg sides), radius r at the bottom and r2 at the top; cap colours the top
func prism(b, c, r, hgt, seg, col, cap = null, r2 = -1.0):
	if r2 < 0: r2 = r
	for k in range(seg):
		var a0 = TAU * k / seg
		var a1 = TAU * (k + 1) / seg
		var d0 = Vector3(cos(a0), 0, sin(a0))
		var d1 = Vector3(cos(a1), 0, sin(a1))
		var nr = (d0 + d1).normalized()
		nr = (nr * hgt + UP * (r - r2)).normalized()
		if r2 > 0.001:
			quad(b, c + d0 * r, c + d1 * r, c + d1 * r2 + UP * hgt, c + d0 * r2 + UP * hgt, nr, col)
		else:
			tri(b, c + d0 * r, c + d1 * r, c + UP * hgt, nr, col)
		if cap != null and r2 > 0.001:
			tri(b, c + UP * hgt, c + d0 * r2 + UP * hgt, c + d1 * r2 + UP * hgt, UP, cap)

# a beam from a to b with a square section of half size e (rails, braces, branches, wires)
func beam(b, a, p, e, col, skip = 0):
	var d = p - a
	var L = d.length()
	if L < 0.001: return
	var y = d / L
	var x = y.cross(Vector3(0, 0, 1)) if abs(y.z) < 0.9 else y.cross(Vector3(1, 0, 0))
	x = x.normalized()
	var z = x.cross(y)
	box(b, (a + p) * 0.5, Vector3(e, L * 0.5, e), col, Basis(x, y, z), skip | 12)

func _buf(m, key):
	if not m.has(key): m[key] = Buf.new()
	return m[key]

# stamp a template into a chunk at xf
func stamp(ch, mod, xf):
	var nb = Transform(xf.basis.orthonormalized(), Vector3())
	for key in mod:
		var s = mod[key]
		if s.v.size() == 0: continue
		var d = _buf(ch.bufs, key)
		d.cat(xf.xform(s.v), nb.xform(s.n), s.c, s.u, s.u2)

func _chunk(x, z):
	var k = Vector2(floor(x / CH), floor(z / CH))
	if not chunks.has(k):
		chunks[k] = { "bufs": {}, "c": Vector3((k.x + 0.5) * CH, 0, (k.y + 0.5) * CH), "base": null, "det": null }
	return chunks[k]

# ---------------------------------------------------------------- palettes
func C(h): return Color(h)
var PAL = []
func _palettes():
	PAL = [
		# brick: limestone trim, soldier-course lintels, white/black/cream sashes, metal cornices
		{ "stone": C("#cfc7b8"), "lintel": C("#5b2a21"), "frame": [C("#efe9dd"), C("#202326"), C("#e4d8c0")], "corn": [C("#2e3d35"), C("#202326"), C("#d8ccb4"), C("#6b2a20")], "base": C("#b9b1a2"), "kind": "soldier" },
		{ "stone": C("#c4baa8"), "lintel": C("#3a2419"), "frame": [C("#e6dccb"), C("#1b1d20"), C("#3b2a20")], "corn": [C("#1b1d20"), C("#2d3a33"), C("#4a3226")], "base": C("#a89e8e"), "kind": "soldier" },
		{ "stone": C("#bdb7aa"), "lintel": C("#a39d90"), "frame": [C("#f0ebe0"), C("#2a2d30")], "corn": [C("#b3ad9f")], "base": C("#8f897c"), "kind": "hood" },
		{ "stone": C("#e4e8ec"), "lintel": C("#eef1f4"), "frame": [C("#f4f6f8")], "corn": [C("#f4f6f8")], "base": C("#5a5f66"), "kind": "flat" },
		{ "stone": C("#e2d6bd"), "lintel": C("#cdbf9f"), "frame": [C("#f2ede2"), C("#2a2d30")], "corn": [C("#ddd0b4")], "base": C("#b5a88c"), "kind": "key" },
		{ "stone": C("#9a9c9e"), "lintel": C("#55595e"), "frame": [C("#2c3034"), C("#3e5a4a")], "corn": [C("#4a4e53")], "base": C("#7a7d80"), "kind": "steel" },
	]

const SNOW = Color(0.95, 0.97, 1.0)
const SNOW2 = Color(0.86, 0.9, 0.95)
const BLACK = Color(0.075, 0.08, 0.09)

# ---------------------------------------------------------------- materials
func _materials():
	for i in range(STY.size()):
		var m = SpatialMaterial.new()
		var t = load("res://assets/tex/wall_%s.png" % STY[i])
		if t:
			t.flags = Texture.FLAG_MIPMAPS | Texture.FLAG_FILTER | Texture.FLAG_REPEAT | Texture.FLAG_ANISOTROPIC_FILTER
			m.albedo_texture = t
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.9
		G.toon(m)
		mats["w%d" % i] = m
	var tm = SpatialMaterial.new()
	tm.vertex_color_use_as_albedo = true
	tm.roughness = 0.85
	G.toon(tm)
	mats["t"] = tm
	mats["d"] = tm
	glass_mat = ShaderMaterial.new()
	glass_mat.shader = load("res://scripts/window.shader")
	mats["g"] = glass_mat
	sign_mat = SpatialMaterial.new()
	var st = load("res://assets/tex/signs.png")
	if st:
		st.flags = Texture.FLAG_MIPMAPS | Texture.FLAG_FILTER | Texture.FLAG_ANISOTROPIC_FILTER
		sign_mat.albedo_texture = st
		sign_mat.emission_enabled = true
		sign_mat.emission_texture = st
		sign_mat.emission = Color(1, 1, 1)
		sign_mat.emission_energy = 0.0
	sign_mat.params_use_alpha_scissor = true
	sign_mat.params_alpha_scissor_threshold = 0.5
	sign_mat.vertex_color_use_as_albedo = true
	sign_mat.roughness = 0.6
	G.toon(sign_mat)
	mats["s"] = sign_mat

# ---------------------------------------------------------------- setup
func setup(m):
	main = m
	var t0 = OS.get_ticks_msec()
	_palettes()
	_materials()
	var f = File.new()
	if f.open("res://assets/world/buildings.json", File.READ) != OK:
		push_error("assets/world/buildings.json missing")
		return
	var r = JSON.parse(f.get_as_text()); f.close()
	if r.error != OK: return
	var D = r.result
	for k in D.get("KEEP", []):
		keep.append(AABB(Vector3(k[0], k[1], k[2]), Vector3(k[3] - k[0], k[4] - k[1], k[5] - k[2])).grow(0.15))
	for B in D["BUILDINGS"]:
		bx.append({ "x0": float(B[0]), "z0": float(B[1]), "x1": float(B[2]), "z1": float(B[3]), "h": float(B[4]) })
	for B in D["BUILDINGS"]:
		_building(B)
	_streets(D.get("ALLEYS", []))
	_commit()
	info.ms = OS.get_ticks_msec() - t0
	set_quality(G.S.get("settings", {}).get("quality", "high") if typeof(G.S) == TYPE_DICTIONARY else "high")

func set_quality(q):
	det_r = 175.0 if q == "high" else (130.0 if q == "medium" else 85.0)
	_t = 0.0

func set_night(n, lamps):
	if glass_mat: glass_mat.set_shader_param("night", clamp(n * 1.1, 0.0, 1.0))
	if sign_mat: sign_mat.emission_energy = lerp(0.0, 1.25, lamps)

func _process(dt):
	_t -= dt
	if _t > 0: return
	_t = 0.25
	var cam = get_viewport().get_camera()
	if cam == null: return
	var p = cam.global_transform.origin
	for k in chunks:
		var ch = chunks[k]
		if ch.det:
			var d = Vector2(ch.c.x - p.x, ch.c.z - p.z).length()
			ch.det.visible = d < det_r

func _commit():
	var flags = Mesh.ARRAY_COMPRESS_NORMAL | Mesh.ARRAY_COMPRESS_COLOR | Mesh.ARRAY_COMPRESS_TEX_UV | Mesh.ARRAY_COMPRESS_TEX_UV2
	for k in chunks:
		var ch = chunks[k]
		var base = ArrayMesh.new()
		var det = ArrayMesh.new()
		for key in ch.bufs:
			var b = ch.bufs[key]
			if b.v.size() == 0: continue
			var a = []
			a.resize(Mesh.ARRAY_MAX)
			a[Mesh.ARRAY_VERTEX] = b.v
			a[Mesh.ARRAY_NORMAL] = b.n
			a[Mesh.ARRAY_COLOR] = b.c
			a[Mesh.ARRAY_TEX_UV] = b.u
			if b.u2.size() == b.v.size(): a[Mesh.ARRAY_TEX_UV2] = b.u2
			var target = det if key == "d" else base
			target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], flags)
			target.surface_set_material(target.get_surface_count() - 1, mats[key])
			info.tris += b.v.size() / 3
		for pair in [["base", base], ["det", det]]:
			if pair[1].get_surface_count() == 0: continue
			var mi = MeshInstance.new()
			mi.mesh = pair[1]
			mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
			mi.name = "%s_%d_%d" % [pair[0], int(k.x), int(k.y)]
			add_child(mi)
			ch[pair[0]] = mi
		ch.bufs = {}
		info.chunks += 1

# ---------------------------------------------------------------- the buildings
func _kept(lo, hi):
	var a = AABB(lo, hi - lo)
	for k in keep:
		if k.intersects(a): return true
	return false

# how tall the neighbours are along a face: for each metre, the highest other building right
# outside it (0 = open)
func _cover(p0, t, nr, L, self_b):
	var out = []
	var n = int(ceil(L))
	for i in range(n):
		var p = p0 + t * (i + 0.5) * L / n + nr * 0.6
		var hh = 0.0
		for o in W.query(p.x - 0.1, p.z - 0.1, p.x + 0.1, p.z + 0.1):
			if o.tag != "building": continue
			if abs(o.x0 - self_b.x0) < 0.01 and abs(o.z0 - self_b.z0) < 0.01 and abs(o.x1 - self_b.x1) < 0.01: continue
			if p.x > o.x0 and p.x < o.x1 and p.z > o.z0 and p.z < o.z1: hh = max(hh, o.y1)
		out.append(hh)
	return out

func _covered_at(cov, L, s0, s1, y):
	var n = cov.size()
	if n == 0: return false
	var i0 = int(clamp(floor(s0 / L * n), 0, n - 1))
	var i1 = int(clamp(floor(s1 / L * n), 0, n - 1))
	for i in range(i0, i1 + 1):
		if cov[i] > y: return true
	return false

func _street_face(fc, nr):
	if abs(nr.x) > 0.5:
		for x in G.D["XL"]:
			var d = (float(x) - fc.x) * nr.x
			if d > 0 and d < 12.5: return true
	else:
		for z in G.D["ZL"]:
			var d = (float(z) - fc.z) * nr.z
			if d > 0 and d < 12.5 and fc.x < float(G.D["ROAD_X_END"]) + 2: return true
	return false

func _building(B):
	var x0 = float(B[0])
	var z0 = float(B[1])
	var x1 = float(B[2])
	var z1 = float(B[3])
	var h = float(B[4])
	var st = int(B[5])
	R.seed = int(abs(x0 * 73.13 + z0 * 131.7 + h * 17.0)) + 11
	var ch = _chunk((x0 + x1) * 0.5, (z0 + z1) * 0.5)
	var P = PAL[st]
	var tall = h >= 20.0
	var garage = h < 4.2
	var me = { "x0": x0, "z0": z0, "x1": x1, "z1": z1 }
	# a little variety from building to building in the same material
	var tint = Color(1, 1, 1).linear_interpolate(Color(R.randf_range(0.86, 1.06), R.randf_range(0.86, 1.02), R.randf_range(0.84, 1.0)), 0.7)
	var faces = [
		{ "nr": Vector3(0, 0, -1), "t": Vector3(-1, 0, 0), "p0": Vector3(x1, 0, z0), "L": x1 - x0 },
		{ "nr": Vector3(0, 0, 1), "t": Vector3(1, 0, 0), "p0": Vector3(x0, 0, z1), "L": x1 - x0 },
		{ "nr": Vector3(-1, 0, 0), "t": Vector3(0, 0, 1), "p0": Vector3(x0, 0, z0), "L": z1 - z0 },
		{ "nr": Vector3(1, 0, 0), "t": Vector3(0, 0, -1), "p0": Vector3(x1, 0, z1), "L": z1 - z0 },
	]
	var gable = st == 3 and not garage and not tall and h < 9.5 and min(x1 - x0, z1 - z0) < 11.0
	var par = 0.0 if gable else (1.0 if tall else (0.85 if st == 5 else (0.35 if st == 3 else 0.55)))
	var any_street = false
	for F in faces:
		F["fc"] = F.p0 + F.t * F.L * 0.5
		F["street"] = _street_face(F.fc, F.nr)
		F["cov"] = _cover(F.p0, F.t, F.nr, F.L, me)
		any_street = any_street or F.street
	# floors: a taller ground floor, then even upper floors up to the cornice
	var shop = false
	for F in faces:
		if F.street and F.L >= 7.0 and not tall and not garage and st in [0, 1, 2, 4] and R.randf() < (0.5 if st != 2 else 0.22):
			shop = true
	var gf = 3.45 if shop else (3.2 if tall else 3.0)
	if garage: gf = h
	var top_zone = 0.95 if st in [0, 1, 2] else 0.7
	var avail = h - gf - top_zone
	var nup = 0 if garage else int(max(0, round(avail / (2.8 if tall else 2.95))))
	var fh = clamp(avail / nup, 2.45, 3.5) if nup > 0 else 0.0
	var floors = []
	for k in range(nup): floors.append(gf + k * fh)
	var wall_key = "w%d" % st
	var fire_done = false
	var door_done = false
	for F in faces:
		var L = F.L
		var nr = F.nr
		var t = F.t
		var p0 = F.p0
		var party = true
		for c in F.cov:
			if c < h - 0.5: party = false
		# the wall: darker toward the ground (grime and slush), up to the parapet
		_wall(ch, wall_key, p0, t, nr, L, h + par, tint)
		if party: continue
		var basis = Basis(t, UP, nr)
		var fwd = F.street
		var bays = 2.3 if st != 5 else 3.4
		if tall: bays = 2.6
		var n = int(max(1, floor((L - 1.0) / bays)))
		if L < 2.4: n = 0
		var sp = L / max(n, 1)
		var win = _win_size(st, tall)
		# ground floor
		if fwd and shop:
			_storefront(ch, F, h, P, st)
		elif garage:
			if not fwd and not _covered_at(F.cov, L, 0, L, 0.5) and L >= 3.0:
				var ng = int(max(1, floor(L / 3.4)))
				for g in range(ng):
					var s = L * (g + 0.5) / ng
					stamp(ch, _mod_rollup(2.6, 2.3), Transform(basis, p0 + t * s))
		elif n > 0:
			var door_i = -1
			if (fwd or (tall and not door_done)) and L >= 3.0:
				door_i = 0 if (n >= 2 and R.randf() < 0.5) else n - 1
				if n >= 3 and st == 2: door_i = 0
			for i in range(n):
				var s = sp * (i + 0.5)
				if i == door_i:
					var dw = 1.9 if tall else (3.4 if st == 5 else 1.05)
					var dh = 2.5 if (tall or st == 5) else 2.2
					var lo = p0 + t * (s - dw) - nr * 0.1
					var hi = p0 + t * (s + dw) + nr * 1.2 + UP * 3.2
					if not _kept(_vmin(lo, hi), _vmax(lo, hi)) and not _covered_at(F.cov, L, s - dw, s + dw, 0.2):
						if st == 5:
							stamp(ch, _mod_rollup(3.4, 3.0), Transform(basis, p0 + t * s))
						else:
							var steps = 0 if tall else (2 if st in [0, 1, 2, 4] else 1)
							stamp(ch, _mod_door(st, dw, dh, steps, R.randi() % 5, tall), Transform(basis, p0 + t * s))
							_glass(ch, p0 + t * s + nr * 0.012 + UP * (steps * 0.17 + dh + 0.08), t, nr, dw * (2.0 if tall else 1.0) - 0.1, 0.32, _room(0.6), 0)
						door_done = true
						continue
				var gy = 1.0 if st != 5 else 1.5
				var gh = min(win.y, gf - gy - 0.5)
				if gh > 0.7:
					_window(ch, F, s, gy, win.x, gh, st, P, false)
		# upper floors
		for k in range(nup):
			var y = floors[k] + 0.85
			var wh = min(win.y, fh - 1.05)
			if wh < 0.7: continue
			for i in range(n):
				_window(ch, F, sp * (i + 0.5), y, win.x, wh, st, P, k == nup - 1 and st == 2 and fwd)
		# fire escape: brick walk-ups of three floors and more, out front or on an open side
		if st in [0, 1] and nup >= 2 and n >= 3 and not fire_done and (fwd or not F.street) and R.randf() < (0.55 if fwd else 0.25):
			var c0 = int(R.randi() % (n - 1))
			var s_mid = sp * (c0 + 1)
			var wd = min(sp * 2.0 - 0.5, 5.2)
			if not _covered_at(F.cov, L, s_mid - wd * 0.5, s_mid + wd * 0.5, floors[0] - 0.5):
				_fire_escape(ch, F, s_mid, wd, floors, fh)
				fire_done = true
		# the top: cornice on the street fronts, coping all round
		if fwd and not gable: _cornice(ch, F, h, par, st, P)
		if fwd and not garage: _bands(ch, F, h, gf, st, P, shop)
	# parapet, coping and the snowy roof (or a gable roof on small frame houses)
	if gable: _gable_roof(ch, x0, z0, x1, z1, h, faces, wall_key, tint)
	else: _roof(ch, x0, z0, x1, z1, h, par, st, P, tall, garage)

func _vmin(a, b): return Vector3(min(a.x, b.x), min(a.y, b.y), min(a.z, b.z))
func _vmax(a, b): return Vector3(max(a.x, b.x), max(a.y, b.y), max(a.z, b.z))

func _win_size(st, tall):
	if tall: return Vector2(1.3, 1.5)
	return [Vector2(1.05, 1.65), Vector2(1.0, 1.7), Vector2(1.0, 1.78), Vector2(0.95, 1.45), Vector2(1.1, 1.6), Vector2(2.5, 1.6)][st]

# a room's light at night: warm lamps mostly, the blue of a TV now and then, many dark
func _room(p_lit):
	var lit = R.randf() < p_lit
	var c = [Color(1.0, 0.76, 0.44), Color(1.0, 0.84, 0.6), Color(0.98, 0.9, 0.78), Color(0.55, 0.68, 1.0), Color(0.9, 0.55, 0.3)][R.randi() % 5]
	c.a = R.randf_range(0.6, 1.0) if lit else 0.0
	return c

func _glass(ch, c, t, nr, w, hh, room, kind):
	var g = _buf(ch.bufs, "g")
	var a = c - t * w * 0.5
	var b = c + t * w * 0.5
	var u2 = Vector2(kind / 3.0, R.randf())
	quad(g, a, b, b + UP * hh, a + UP * hh, nr, room, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)], u2)

func _wall(ch, key, p0, t, nr, L, top, tint):
	var b = _buf(ch.bufs, key)
	var p1 = p0 + t * L
	var y1 = min(3.0, top)
	var dark = Color(tint.r * 0.74, tint.g * 0.74, tint.b * 0.76)
	var u1 = L / TILE
	quad(b, p0, p1, p1 + UP * y1, p0 + UP * y1, nr, dark, [Vector2(0, 0), Vector2(u1, 0), Vector2(u1, -y1 / TILE), Vector2(0, -y1 / TILE)])
	# (the vertex colours ramp dark -> light up the first 3 m)
	var n0 = b.c.size()
	var vv = b.v
	for i in range(6):
		if vv[vv.size() - 6 + i].y > 0.1: b.set_col(n0 - 6 + i, tint)
	if top > y1:
		quad(b, p0 + UP * y1, p1 + UP * y1, p1 + UP * top, p0 + UP * top, nr, tint, [Vector2(0, -y1 / TILE), Vector2(u1, -y1 / TILE), Vector2(u1, -top / TILE), Vector2(0, -top / TILE)])

# one window: the template (surround, sill with snow, lintel, sash bars, now and then an air
# conditioner) and its glass
func _window(ch, F, s, y, w, wh, st, P, crown):
	var L = F.L
	if s - w * 0.5 < 0.25 or s + w * 0.5 > L - 0.25: return
	var t = F.t
	var nr = F.nr
	var c = F.p0 + t * s + UP * y
	var lo = c - t * (w * 0.5 + 0.2) - UP * 0.2
	var hi = c + t * (w * 0.5 + 0.2) + UP * (wh + 0.4) + nr * 0.3
	if _kept(_vmin(lo, hi), _vmax(lo, hi)): return
	if _covered_at(F.cov, L, s - w * 0.5 - 0.2, s + w * 0.5 + 0.2, y - 0.3): return
	var fr = P.frame[R.randi() % P.frame.size()]
	var mk = _mod_window(st, w, wh, fr, P, crown)
	stamp(ch, mk, Transform(Basis(t, UP, nr), c))
	var kind = R.randi() % 4
	var p_lit = 0.12 if st == 5 else 0.42
	_glass(ch, c + nr * 0.012, t, nr, w, wh, _room(p_lit), kind)
	info.windows += 1
	if st != 5 and not crown and R.randf() < 0.09 and y > 2.5:
		stamp(ch, _mod_ac(), Transform(Basis(t, UP, nr), c + t * (R.randf_range(-0.15, 0.15) * w)))

# ---------------------------------------------------------------- templates
func _key(parts):
	var s = ""
	for p in parts: s += str(p) + "|"
	return s

func _mod_window(st, w, wh, fr, P, crown):
	var k = _key(["win", st, stepify(w, 0.05), stepify(wh, 0.05), fr.to_html(false), crown])
	if mods.has(k): return mods[k]
	var d = Buf.new()
	var kind = P.kind
	var sw = 0.09 if kind in ["soldier", "flat", "steel"] else 0.13      # surround width
	var sp = 0.09 if kind != "steel" else 0.06                           # how far it stands out
	var surround = P.stone if kind in ["hood", "key"] else fr
	if kind == "soldier": surround = fr
	# surround (its inner faces are the reveal of the opening)
	boxr(d, Vector3(-w * 0.5 - sw, 0, 0), Vector3(-w * 0.5, wh, sp), surround, SKIP_BACK)
	boxr(d, Vector3(w * 0.5, 0, 0), Vector3(w * 0.5 + sw, wh, sp), surround, SKIP_BACK)
	boxr(d, Vector3(-w * 0.5 - sw, wh, 0), Vector3(w * 0.5 + sw, wh + sw, sp), surround, SKIP_BACK)
	# sash bars: a meeting rail, and a centre bar on the older styles; a steel grid on warehouses
	var bar = fr.darkened(0.08)
	if kind == "steel":
		for i in range(1, 4):
			boxr(d, Vector3(-w * 0.5 + w * i / 4.0 - 0.025, 0, 0), Vector3(-w * 0.5 + w * i / 4.0 + 0.025, wh, 0.035), bar, SKIP_BACK | 12)
		for j in range(1, 3):
			boxr(d, Vector3(-w * 0.5, wh * j / 3.0 - 0.025, 0), Vector3(w * 0.5, wh * j / 3.0 + 0.025, 0.035), bar, SKIP_BACK | 3)
	else:
		boxr(d, Vector3(-w * 0.5, wh * 0.5 - 0.035, 0), Vector3(w * 0.5, wh * 0.5 + 0.035, 0.05), bar, SKIP_BACK | 3)
		if kind in ["hood", "key", "soldier"] and w < 1.25:
			boxr(d, Vector3(-0.02, 0, 0), Vector3(0.02, wh, 0.03), bar, SKIP_BACK | 12)
	# sill, with snow on it
	var sl = P.stone if kind != "flat" else fr
	boxr(d, Vector3(-w * 0.5 - sw - 0.05, -0.08, 0), Vector3(w * 0.5 + sw + 0.05, 0.0, 0.17), sl, SKIP_BACK)
	boxr(d, Vector3(-w * 0.5 - sw - 0.02, 0.0, 0.0), Vector3(w * 0.5 + sw + 0.02, 0.035, 0.15), SNOW, SKIP_BACK | 8, SNOW)
	if kind == "hood" or crown:
		boxr(d, Vector3(-0.09 - w * 0.5 + 0.12, -0.2, 0), Vector3(-w * 0.5 + 0.12, -0.08, 0.12), sl, SKIP_BACK)
		boxr(d, Vector3(w * 0.5 - 0.12, -0.2, 0), Vector3(w * 0.5 - 0.03, -0.08, 0.12), sl, SKIP_BACK)
	# lintel
	var top = wh + sw
	match kind:
		"soldier":
			boxr(d, Vector3(-w * 0.5 - sw - 0.08, top, 0), Vector3(w * 0.5 + sw + 0.08, top + 0.24, 0.045), P.lintel, SKIP_BACK)
		"hood":
			boxr(d, Vector3(-w * 0.5 - sw - 0.14, top, 0), Vector3(w * 0.5 + sw + 0.14, top + 0.17, 0.17), P.lintel, SKIP_BACK, SNOW)
			boxr(d, Vector3(-w * 0.5 - sw - 0.06, top - 0.04, 0), Vector3(w * 0.5 + sw + 0.06, top, 0.12), P.stone, SKIP_BACK)
		"key":
			boxr(d, Vector3(-w * 0.5 - sw - 0.1, top, 0), Vector3(w * 0.5 + sw + 0.1, top + 0.2, 0.07), P.lintel, SKIP_BACK)
			boxr(d, Vector3(-0.12, top - 0.06, 0), Vector3(0.12, top + 0.3, 0.1), P.stone, SKIP_BACK)
		"flat":
			boxr(d, Vector3(-w * 0.5 - sw - 0.05, top, 0), Vector3(w * 0.5 + sw + 0.05, top + 0.13, 0.06), fr, SKIP_BACK, SNOW)
		"steel":
			boxr(d, Vector3(-w * 0.5 - 0.1, top, 0), Vector3(w * 0.5 + 0.1, top + 0.16, 0.03), P.lintel, SKIP_BACK)
	# greystone top floor: a little pediment over the window
	if crown:
		var a = Vector3(-w * 0.5 - sw - 0.16, top + 0.17, 0.16)
		var b = Vector3(w * 0.5 + sw + 0.16, top + 0.17, 0.16)
		var c = Vector3(0, top + 0.55, 0.16)
		tri(d, a, b, c, Vector3(0, 0, 1), P.lintel)
		quad(d, a, c, c - Vector3(0, 0, 0.16), a - Vector3(0, 0, 0.16), Vector3(-0.7, 0.7, 0).normalized(), SNOW)
		quad(d, c, b, b - Vector3(0, 0, 0.16), c - Vector3(0, 0, 0.16), Vector3(0.7, 0.7, 0).normalized(), SNOW)
	# frame houses: shutters on some
	if kind == "flat" and fr.r > 0.9 and abs(w - 0.95) < 0.01 and int(wh * 100) % 2 == 0:
		var sc = Color("#2b3f33")
		boxr(d, Vector3(-w * 0.5 - sw - 0.46, 0, 0), Vector3(-w * 0.5 - sw - 0.02, wh, 0.035), sc, SKIP_BACK)
		boxr(d, Vector3(w * 0.5 + sw + 0.02, 0, 0), Vector3(w * 0.5 + sw + 0.46, wh, 0.035), sc, SKIP_BACK)
	var m = { "d": d }
	mods[k] = m
	return m

func _mod_ac():
	if mods.has("ac"): return mods.ac
	var d = Buf.new()
	var body = Color("#d9d6cc")
	boxr(d, Vector3(-0.3, 0.03, -0.05), Vector3(0.3, 0.42, 0.45), body, SKIP_BACK, SNOW)
	boxr(d, Vector3(-0.26, 0.08, 0.45), Vector3(0.26, 0.36, 0.47), Color("#7d7b74"), SKIP_BACK)
	for i in range(4):
		boxr(d, Vector3(-0.24, 0.12 + i * 0.06, 0.47), Vector3(0.24, 0.135 + i * 0.06, 0.49), Color("#5b5952"), SKIP_BACK)
	mods.ac = { "d": d }
	return mods.ac

func _mod_door(st, dw, dh, steps, col_i, tall):
	var k = _key(["door", st, dw, dh, steps, col_i, tall])
	if mods.has(k): return mods[k]
	var d = Buf.new()
	var t = Buf.new()
	var P = PAL[st]
	var cols = [Color("#5a1d18"), Color("#1d1f22"), Color("#3b2a1e"), Color("#203a2c"), Color("#1d2c48")]
	var door = cols[col_i]
	var y0 = steps * 0.17
	var w = dw * (2.0 if tall else 1.0)
	# steps (they belong with the base: seen from afar too)
	for i in range(steps):
		boxr(t, Vector3(-w * 0.5 - 0.3, i * 0.17, 0), Vector3(w * 0.5 + 0.3, (i + 1) * 0.17, 0.34 * (steps - i)), P.base.lightened(0.08), SKIP_BACK, Color(0.9, 0.92, 0.95))
	# surround and pediment
	var sw = 0.16
	var fr = P.stone if st in [2, 4] else P.frame[0]
	boxr(d, Vector3(-w * 0.5 - sw, y0, 0), Vector3(-w * 0.5, y0 + dh + 0.42, 0.12), fr, SKIP_BACK)
	boxr(d, Vector3(w * 0.5, y0, 0), Vector3(w * 0.5 + sw, y0 + dh + 0.42, 0.12), fr, SKIP_BACK)
	boxr(d, Vector3(-w * 0.5 - sw - 0.1, y0 + dh + 0.42, 0), Vector3(w * 0.5 + sw + 0.1, y0 + dh + 0.62, 0.2), fr, SKIP_BACK, SNOW)
	boxr(d, Vector3(-w * 0.5, y0 + dh, 0), Vector3(w * 0.5, y0 + dh + 0.06, 0.08), fr, SKIP_BACK)
	if tall:
		# a glass lobby door pair in a dark frame
		var al = Color("#2a2e33")
		for sx in [-1, 1]:
			boxr(d, Vector3(sx * w * 0.25 - 0.04, y0, 0), Vector3(sx * w * 0.25 + 0.04, y0 + dh, 0.06), al, SKIP_BACK)
		boxr(d, Vector3(-0.03, y0, 0), Vector3(0.03, y0 + dh, 0.06), al, SKIP_BACK)
		boxr(d, Vector3(-w * 0.5, y0 + 1.0, 0), Vector3(w * 0.5, y0 + 1.06, 0.06), al, SKIP_BACK)
	else:
		# a panelled door, its knob, and a lamp beside it
		boxr(d, Vector3(-w * 0.5, y0, 0), Vector3(w * 0.5, y0 + dh, 0.035), door, SKIP_BACK)
		for j in range(2):
			boxr(d, Vector3(-w * 0.5 + 0.14, y0 + 0.2 + j * 1.0, 0.035), Vector3(w * 0.5 - 0.14, y0 + 0.95 + j * 1.0, 0.05), door.lightened(0.08), SKIP_BACK)
		boxr(d, Vector3(w * 0.5 - 0.16, y0 + 1.0, 0.035), Vector3(w * 0.5 - 0.1, y0 + 1.06, 0.09), Color("#c9a64a"), SKIP_BACK)
		boxr(d, Vector3(w * 0.5 + sw + 0.08, y0 + 1.9, 0), Vector3(w * 0.5 + sw + 0.24, y0 + 2.15, 0.14), Color("#ffe2a8"), SKIP_BACK)
	var m = { "d": d, "t": t }
	mods[k] = m
	return m

func _mod_rollup(w, hh):
	var k = _key(["roll", w, hh])
	if mods.has(k): return mods[k]
	var d = Buf.new()
	var t = Buf.new()
	var steel = Color("#8c9298")
	boxr(t, Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, hh, 0.02), steel, SKIP_BACK)
	for i in range(int(hh / 0.16)):
		boxr(d, Vector3(-w * 0.5, i * 0.16 + 0.12, 0.02), Vector3(w * 0.5, i * 0.16 + 0.15, 0.045), steel.darkened(0.25), SKIP_BACK | 3)
	boxr(d, Vector3(-w * 0.5 - 0.14, 0, 0), Vector3(-w * 0.5, hh + 0.14, 0.12), Color("#3a3e43"), SKIP_BACK)
	boxr(d, Vector3(w * 0.5, 0, 0), Vector3(w * 0.5 + 0.14, hh + 0.14, 0.12), Color("#3a3e43"), SKIP_BACK)
	boxr(d, Vector3(-w * 0.5 - 0.14, hh, 0), Vector3(w * 0.5 + 0.14, hh + 0.45, 0.3), Color("#3a3e43"), SKIP_BACK, SNOW)
	var m = { "d": d, "t": t }
	mods[k] = m
	return m

# ---------------------------------------------------------------- storefronts
const SHOPS = 16
func _storefront(ch, F, h, P, st):
	var L = F.L
	var t = F.t
	var nr = F.nr
	var basis = Basis(t, UP, nr)
	var nb = int(max(1, round(L / 3.3)))
	var bw = L / nb
	var door_b = R.randi() % nb
	var paint = [Color("#1d1f22"), Color("#5a1d18"), Color("#203a2c"), Color("#1d2c48"), Color("#6b5a3a"), P.stone][R.randi() % 6]
	var awn = R.randf() < 0.55
	var awn_c = [Color("#a3161c"), Color("#1d5a33"), Color("#1d2c6b"), Color("#1a1a1a"), Color("#c76a12"), Color("#6b1d4a")][R.randi() % 6]
	var stripes = R.randf() < 0.5
	var room = Color(1.0, 0.93, 0.8, 1.0)
	for i in range(nb):
		var s = bw * (i + 0.5)
		var c = F.p0 + t * s
		var lo = c - t * bw * 0.5
		var hi = c + t * bw * 0.5 + UP * 3.5 + nr * 0.3
		if _kept(_vmin(lo, hi), _vmax(lo, hi)): continue
		if _covered_at(F.cov, L, s - bw * 0.5, s + bw * 0.5, 0.3): continue
		var door = i == door_b
		stamp(ch, _mod_bay(stepify(bw, 0.1), paint, door, i == 0), Transform(basis, c))
		if door:
			var side = (bw - 1.3) * 0.5
			if side > 0.3:
				_glass(ch, c + nr * 0.012 - t * (0.65 + side * 0.5) + UP * 0.55, t, nr, side - 0.08, 1.75, room, 0)
				_glass(ch, c + nr * 0.012 + t * (0.65 + side * 0.5) + UP * 0.55, t, nr, side - 0.08, 1.75, room, 0)
			_glass(ch, c + nr * 0.012 + UP * 0.08, t, nr, 1.0, 2.05, room, 0)
		else:
			_glass(ch, c + nr * 0.012 + UP * 0.55, t, nr, bw - 0.42, 1.75, room, 0)
		_glass(ch, c + nr * 0.012 + UP * 2.38, t, nr, bw - 0.42, 0.3, room, 0)
		if awn:
			stamp(ch, _mod_awning(stepify(bw, 0.1), awn_c, stripes), Transform(basis, c))
	# the sign: one shop name across the sign band
	var sw = min(L - 0.8, 7.5)
	var mid = L * 0.5
	var lo2 = F.p0 + t * (mid - sw * 0.5) + UP * 2.78
	var hi2 = F.p0 + t * (mid + sw * 0.5) + UP * 3.4 + nr * 0.3
	if not _kept(_vmin(lo2, hi2), _vmax(lo2, hi2)):
		var row = R.randi() % SHOPS
		var a = F.p0 + t * (mid - sw * 0.5) + UP * 2.82 + nr * 0.215
		var b = a + t * sw
		var v0 = row / 16.0
		var v1 = (row + 1) / 16.0
		quad(_buf(ch.bufs, "s"), a, b, b + UP * 0.56, a + UP * 0.56, nr, Color(1, 1, 1), [Vector2(0, v1), Vector2(0.5, v1), Vector2(0.5, v0), Vector2(0, v0)])

func _mod_bay(bw, paint, door, first):
	var k = _key(["bay", bw, paint.to_html(false), door, first])
	if mods.has(k): return mods[k]
	var t = Buf.new()
	var d = Buf.new()
	var dark = paint.darkened(0.25)
	# pilasters at the bay's edges
	boxr(t, Vector3(bw * 0.5 - 0.17, 0, 0), Vector3(bw * 0.5 + 0.17, 3.45, 0.13), paint, SKIP_BACK)
	if first: boxr(t, Vector3(-bw * 0.5 - 0.17, 0, 0), Vector3(-bw * 0.5 + 0.17, 3.45, 0.13), paint, SKIP_BACK)
	# sign band and its little cornice with snow
	boxr(t, Vector3(-bw * 0.5, 2.72, 0), Vector3(bw * 0.5, 3.45, 0.21), dark, SKIP_BACK)
	boxr(t, Vector3(-bw * 0.5 - 0.02, 3.45, 0), Vector3(bw * 0.5 + 0.02, 3.55, 0.3), paint, SKIP_BACK, SNOW)
	var al = Color("#2b2f33")
	if door:
		var side = (bw - 1.3) * 0.5
		# glass door in a dark frame, with a push bar
		boxr(d, Vector3(-0.65, 0, 0), Vector3(-0.55, 2.2, 0.07), al, SKIP_BACK)
		boxr(d, Vector3(0.55, 0, 0), Vector3(0.65, 2.2, 0.07), al, SKIP_BACK)
		boxr(d, Vector3(-0.55, 2.13, 0), Vector3(0.55, 2.2, 0.07), al, SKIP_BACK)
		boxr(d, Vector3(-0.4, 1.0, 0.0), Vector3(0.4, 1.05, 0.09), Color("#b8bcc0"), SKIP_BACK)
		if side > 0.3:
			for sx in [-1, 1]:
				var x0 = sx * 0.65
				var x1 = sx * (0.65 + side)
				boxr(t, Vector3(min(x0, x1), 0, 0), Vector3(max(x0, x1), 0.55, 0.09), paint, SKIP_BACK)
	else:
		boxr(t, Vector3(-bw * 0.5 + 0.17, 0, 0), Vector3(bw * 0.5 - 0.17, 0.55, 0.09), paint, SKIP_BACK, paint.lightened(0.1))
		boxr(d, Vector3(-0.03, 0.55, 0), Vector3(0.03, 2.3, 0.06), al, SKIP_BACK)
	# frame round the glass and the transom bar
	boxr(d, Vector3(-bw * 0.5 + 0.17, 2.3, 0), Vector3(bw * 0.5 - 0.17, 2.38, 0.07), al, SKIP_BACK)
	boxr(d, Vector3(-bw * 0.5 + 0.17, 2.68, 0), Vector3(bw * 0.5 - 0.17, 2.72, 0.07), al, SKIP_BACK)
	boxr(d, Vector3(-bw * 0.5 + 0.17, 0.53, 0), Vector3(bw * 0.5 - 0.17, 0.58, 0.07), al, SKIP_BACK)
	var m = { "t": t, "d": d }
	mods[k] = m
	return m

func _mod_awning(bw, col, stripes):
	var k = _key(["awn", bw, col.to_html(false), stripes])
	if mods.has(k): return mods[k]
	var t = Buf.new()
	var w = bw * 0.5 - 0.12
	var top = Vector3(0, 3.38, 0.22)
	var low = Vector3(0, 2.7, 1.25)
	var nr = (UP * (low.z - top.z) + Vector3(0, 0, 1) * (top.y - low.y)).normalized()
	var n = int(max(1, round(bw / 0.4))) if stripes else 1
	for i in range(n):
		var xa = -w + 2.0 * w * i / n
		var xb = -w + 2.0 * w * (i + 1) / n
		var c = col if (i % 2 == 0 or not stripes) else Color("#eeeae2")
		quad(t, Vector3(xa, top.y, top.z), Vector3(xb, top.y, top.z), Vector3(xb, low.y, low.z), Vector3(xa, low.y, low.z), nr, c)
		quad(t, Vector3(xa, top.y, top.z), Vector3(xb, top.y, top.z), Vector3(xb, low.y, low.z), Vector3(xa, low.y, low.z), -nr, c.darkened(0.35))
		# the valance
		quad(t, Vector3(xa, low.y, low.z), Vector3(xb, low.y, low.z), Vector3(xb, low.y - 0.26, low.z), Vector3(xa, low.y - 0.26, low.z), Vector3(0, 0, 1), c)
		quad(t, Vector3(xa, low.y, low.z), Vector3(xb, low.y, low.z), Vector3(xb, low.y - 0.26, low.z), Vector3(xa, low.y - 0.26, low.z), Vector3(0, 0, -1), c.darkened(0.35))
	# the ends
	for sx in [-1, 1]:
		var x = sx * w
		tri(t, Vector3(x, top.y, top.z), Vector3(x, low.y, low.z), Vector3(x, low.y, top.z), Vector3(sx, 0, 0), col.darkened(0.15))
		tri(t, Vector3(x, top.y, top.z), Vector3(x, low.y, low.z), Vector3(x, low.y, top.z), Vector3(-sx, 0, 0), col.darkened(0.4))
	# snow along the top of the slope
	quad(t, Vector3(-w, top.y + 0.01, top.z), Vector3(w, top.y + 0.01, top.z), Vector3(w, top.y - 0.25 + 0.01, top.z + 0.38), Vector3(-w, top.y - 0.25 + 0.01, top.z + 0.38), nr, SNOW)
	var m = { "t": t }
	mods[k] = m
	return m

# ---------------------------------------------------------------- cornices, bands, roofs
func _cornice(ch, F, h, par, st, P):
	var t = F.t
	var nr = F.nr
	var L = F.L
	var basis = Basis(t, UP, nr)
	var o = F.p0 + t * L * 0.5
	var xf = Transform(basis, o)
	var tb = Buf.new()
	var db = Buf.new()
	var hw = L * 0.5
	match st:
		0, 1:
			if R.randf() < 0.5:
				# a pressed-metal cornice on brackets, with dentils
				var cc = P.corn[R.randi() % P.corn.size()]
				boxr(tb, Vector3(-hw - 0.3, h - 0.55, 0), Vector3(hw + 0.3, h + 0.2, 0.48), cc, SKIP_BACK, SNOW)
				boxr(tb, Vector3(-hw - 0.32, h + 0.2, 0), Vector3(hw + 0.32, h + 0.28, 0.55), cc.lightened(0.08), SKIP_BACK, SNOW)
				var nbk = int(max(2, round(L / 1.3)))
				for i in range(nbk + 1):
					var x = -hw + L * i / nbk
					boxr(db, Vector3(x - 0.08, h - 1.0, 0), Vector3(x + 0.08, h - 0.55, 0.38), cc.darkened(0.12), SKIP_BACK)
				var nd = int(L / 0.32)
				for i in range(nd):
					var x = -hw + (i + 0.5) * L / nd
					boxr(db, Vector3(x - 0.07, h - 0.7, 0), Vector3(x + 0.07, h - 0.55, 0.2), cc.darkened(0.05), SKIP_BACK)
				boxr(tb, Vector3(-hw, h - 1.05, 0), Vector3(hw, h - 0.95, 0.08), cc, SKIP_BACK)
			else:
				# corbelled brick: three courses stepping out
				for k in range(3):
					boxr(tb, Vector3(-hw - 0.04 * k, h - 0.55 + k * 0.14, 0), Vector3(hw + 0.04 * k, h - 0.41 + k * 0.14, 0.05 + k * 0.06), P.lintel, SKIP_BACK)
				var nd = int(L / 0.42)
				for i in range(nd):
					var x = -hw + (i + 0.5) * L / nd
					boxr(db, Vector3(x - 0.09, h - 0.78, 0), Vector3(x + 0.09, h - 0.55, 0.06), P.lintel, SKIP_BACK)
		2:
			# greystone: frieze, dentils, a deep stone cap
			boxr(tb, Vector3(-hw, h - 0.95, 0), Vector3(hw, h - 0.62, 0.05), P.stone, SKIP_BACK)
			var nd = int(L / 0.3)
			for i in range(nd):
				var x = -hw + (i + 0.5) * L / nd
				boxr(db, Vector3(x - 0.06, h - 0.62, 0), Vector3(x + 0.06, h - 0.48, 0.16), P.stone, SKIP_BACK)
			boxr(tb, Vector3(-hw - 0.2, h - 0.48, 0), Vector3(hw + 0.2, h - 0.2, 0.38), P.lintel, SKIP_BACK)
			boxr(tb, Vector3(-hw - 0.24, h - 0.2, 0), Vector3(hw + 0.24, h - 0.08, 0.45), P.stone, SKIP_BACK, SNOW)
		4:
			# cream brick: a tile band, and the parapet raised in the middle over the front
			boxr(tb, Vector3(-hw, h - 0.62, 0), Vector3(hw, h - 0.46, 0.05), P.stone, SKIP_BACK)
			if L > 6.0:
				var pw = L * 0.36
				var wk = "w4"
				var wb = _buf(ch.bufs, wk)
				var top0 = h + par
				var top1 = h + par + 0.75
				var a = xf.xform(Vector3(-pw * 0.5, top0, 0.0))
				var b = xf.xform(Vector3(pw * 0.5, top0, 0.0))
				quad(wb, a, b, b + UP * (top1 - top0), a + UP * (top1 - top0), nr, Color(1, 1, 1), [Vector2(0, 0), Vector2(pw / TILE, 0), Vector2(pw / TILE, -0.75 / TILE), Vector2(0, -0.75 / TILE)])
				quad(wb, b, a, a + UP * (top1 - top0), b + UP * (top1 - top0), -nr, Color(0.8, 0.8, 0.8))
				boxr(tb, Vector3(-pw * 0.5 - 0.08, top1, -0.32), Vector3(pw * 0.5 + 0.08, top1 + 0.1, 0.1), P.stone, 0, SNOW)
				boxr(tb, Vector3(-0.35, top0 + 0.15, 0), Vector3(0.35, top0 + 0.55, 0.04), P.lintel, SKIP_BACK)
		3:
			boxr(tb, Vector3(-hw - 0.05, h - 0.32, 0), Vector3(hw + 0.05, h, 0.06), P.frame[0], SKIP_BACK)
			boxr(tb, Vector3(-hw - 0.15, h, 0), Vector3(hw + 0.15, h + par, 0.14), P.frame[0], SKIP_BACK)
		5:
			boxr(tb, Vector3(-hw, h - 0.4, 0), Vector3(hw, h - 0.28, 0.04), P.lintel, SKIP_BACK)
	stamp(ch, { "t": tb, "d": db }, xf)

func _bands(ch, F, h, gf, st, P, shop):
	var t = F.t
	var nr = F.nr
	var L = F.L
	var xf = Transform(Basis(t, UP, nr), F.p0 + t * L * 0.5)
	var tb = Buf.new()
	var db = Buf.new()
	var hw = L * 0.5
	if st != 5 and st != 3 and not shop:
		boxr(tb, Vector3(-hw - 0.03, 0, 0), Vector3(hw + 0.03, 0.5, 0.05), P.base, SKIP_BACK, P.base.lightened(0.1))
	if st in [0, 1, 2, 4] and h > gf + 2.0:
		boxr(tb, Vector3(-hw - 0.03, gf - 0.08, 0), Vector3(hw + 0.03, gf + 0.06, 0.06), P.stone, SKIP_BACK, SNOW2)
	# quoins up the corners of greystone and cream fronts
	if st in [2, 4]:
		var y = 0.55
		var k = 0
		while y < h - 1.1:
			var wq = 0.42 if k % 2 == 0 else 0.26
			for sx in [-1, 1]:
				var xa = sx * hw
				var xb = sx * (hw - wq)
				boxr(db, Vector3(min(xa, xb), y, 0), Vector3(max(xa, xb), y + 0.26, 0.03), P.stone, SKIP_BACK)
			y += 0.3
			k += 1
	stamp(ch, { "t": tb, "d": db }, xf)

func _roof(ch, x0, z0, x1, z1, h, par, st, P, tall, garage):
	var tb = _buf(ch.bufs, "t")
	var wb = _buf(ch.bufs, "w%d" % st)
	var th = 0.25
	var cop = P.stone if st != 5 else Color("#6d7177")
	if st == 3: cop = P.frame[0]
	if par > 0.01:
		# the parapet's inner faces and its coping with snow on it
		var ix0 = x0 + th
		var ix1 = x1 - th
		var iz0 = z0 + th
		var iz1 = z1 - th
		var col = Color(0.8, 0.8, 0.82)
		for e in [[Vector3(ix0, h, iz0), Vector3(ix1, h, iz0), Vector3(0, 0, 1)], [Vector3(ix1, h, iz1), Vector3(ix0, h, iz1), Vector3(0, 0, -1)], [Vector3(ix0, h, iz1), Vector3(ix0, h, iz0), Vector3(1, 0, 0)], [Vector3(ix1, h, iz0), Vector3(ix1, h, iz1), Vector3(-1, 0, 0)]]:
			var a = e[0]
			var b = e[1]
			var l = a.distance_to(b)
			quad(wb, a, b, b + UP * par, a + UP * par, e[2], col, [Vector2(0, 0), Vector2(l / TILE, 0), Vector2(l / TILE, -par / TILE), Vector2(0, -par / TILE)])
		var y = h + par
		boxr(tb, Vector3(x0 - 0.06, y, z0 - 0.06), Vector3(x1 + 0.06, y + 0.09, z0 + th + 0.02), cop, 0, SNOW)
		boxr(tb, Vector3(x0 - 0.06, y, z1 - th - 0.02), Vector3(x1 + 0.06, y + 0.09, z1 + 0.06), cop, 0, SNOW)
		boxr(tb, Vector3(x0 - 0.06, y, z0 + th), Vector3(x0 + th + 0.02, y + 0.09, z1 - th), cop, 0, SNOW)
		boxr(tb, Vector3(x1 - th - 0.02, y, z0 + th), Vector3(x1 + 0.06, y + 0.09, z1 - th), cop, 0, SNOW)
	# the roof: snow over tar, drifted against the parapet
	var rb = tb
	quad(rb, Vector3(x0, h + 0.02, z0), Vector3(x1, h + 0.02, z0), Vector3(x1, h + 0.02, z1), Vector3(x0, h + 0.02, z1), UP, Color(0.9, 0.92, 0.95))
	if garage: return
	# what's up there
	var db = _buf(ch.bufs, "d")
	var w = x1 - x0
	var d = z1 - z0
	if w < 4.5 or d < 4.5: return
	var used = []
	var spots = int(clamp(w * d / 45.0, 1, 7))
	for i in range(spots):
		var px = R.randf_range(x0 + 1.6, x1 - 1.6)
		var pz = R.randf_range(z0 + 1.6, z1 - 1.6)
		var ok = true
		for u in used:
			if Vector2(px - u.x, pz - u.y).length() < 2.4: ok = false
		if not ok: continue
		used.append(Vector2(px, pz))
		var p = Vector3(px, h, pz)
		var r = R.randf()
		if r < 0.32:
			stamp(ch, _mod_hvac(), Transform(Basis(UP, R.randi() % 4 * PI * 0.5), p))
		elif r < 0.55:
			for k in range(R.randi() % 3 + 1):
				prism(db, p + Vector3(k * 0.4, 0, R.randf_range(-0.3, 0.3)), 0.09, R.randf_range(0.5, 1.1), 6, Color("#8e9296"), Color("#3a3d40"))
		elif r < 0.7:
			boxr(db, p + Vector3(-0.45, 0, -0.45), p + Vector3(0.45, 0.45, 0.45), Color("#6e7378"), 0, SNOW)
		elif r < 0.84 and st != 5:
			# a TV antenna
			beam(db, p, p + UP * 2.4, 0.025, Color("#3a3d40"))
			for k in range(3):
				var yy = 1.4 + k * 0.35
				beam(db, p + Vector3(-0.5 + k * 0.1, yy, 0), p + Vector3(0.5 - k * 0.1, yy, 0), 0.012, Color("#3a3d40"))
		else:
			# a satellite dish
			boxr(db, p + Vector3(-0.05, 0, -0.05), p + Vector3(0.05, 0.6, 0.05), Color("#3a3d40"))
			prism(db, p + Vector3(0, 0.55, 0), 0.05, 0.25, 8, Color("#d7d9dc"), null, 0.42)
	# chimneys on the old brick and stone houses, against a side wall
	if st in [0, 1, 2, 4] and not tall and R.randf() < 0.75:
		var cx = x0 + 0.55 if R.randf() < 0.5 else x1 - 0.55
		var cz = R.randf_range(z0 + 1.0, z1 - 1.0)
		var cc = P.lintel if st in [0, 1] else Color("#7a4a38")
		boxr(db, Vector3(cx - 0.35, h, cz - 0.42), Vector3(cx + 0.35, h + par + 1.2, cz + 0.42), cc, 0)
		boxr(db, Vector3(cx - 0.42, h + par + 1.2, cz - 0.5), Vector3(cx + 0.42, h + par + 1.32, cz + 0.5), P.stone, 0, SNOW)
		for k in range(2):
			prism(db, Vector3(cx, h + par + 1.32, cz - 0.18 + k * 0.36), 0.1, 0.28, 6, Color("#8a5a40"), Color("#1a1a1a"))
	# a water tower on warehouses and the tall blocks
	if (st == 5 and h > 7.0 and R.randf() < 0.45) or (tall and R.randf() < 0.7):
		var tx = clamp(R.randf_range(x0 + 3, x1 - 3), x0 + 2.5, x1 - 2.5)
		var tz = clamp(R.randf_range(z0 + 3, z1 - 3), z0 + 2.5, z1 - 2.5)
		stamp(ch, _mod_tank(), Transform(Basis(), Vector3(tx, h, tz)))
	if tall:
		# the lift and stair house
		var mx = R.randf_range(x0 + 4, x1 - 8)
		var mz = R.randf_range(z0 + 2, z1 - 5)
		_box_walls(ch, "w%d" % st, Vector3(mx, h, mz), Vector3(mx + 4.5, h + 3.0, mz + 3.2), Color(0.95, 0.95, 0.95))
		boxr(tb, Vector3(mx - 0.1, h + 3.0, mz - 0.1), Vector3(mx + 4.6, h + 3.15, mz + 3.3), cop, 0, SNOW)

func _box_walls(ch, key, lo, hi, col):
	var b = _buf(ch.bufs, key)
	var pts = [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z)]
	var nrs = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
	var hh = hi.y - lo.y
	for i in range(4):
		var a = pts[i]
		var c = pts[(i + 1) % 4]
		var l = a.distance_to(c)
		quad(b, a, c, c + UP * hh, a + UP * hh, nrs[i], col, [Vector2(0, 0), Vector2(l / TILE, 0), Vector2(l / TILE, -hh / TILE), Vector2(0, -hh / TILE)])

func _gable_roof(ch, x0, z0, x1, z1, h, faces, wall_key, tint):
	# the ridge runs front to back (the gable faces the street)
	var along_z = true
	for F in faces:
		if F.street and abs(F.nr.x) > 0.5: along_z = false
	var tb = _buf(ch.bufs, "t")
	var wb = _buf(ch.bufs, wall_key)
	var ov = 0.35
	var span = (x1 - x0) if along_z else (z1 - z0)
	var rise = span * 0.42
	var eave = Color("#2d3238")
	if along_z:
		var xm = (x0 + x1) * 0.5
		for z in [z0, z1]:
			var nr = Vector3(0, 0, -1) if z == z0 else Vector3(0, 0, 1)
			tri(wb, Vector3(x0, h, z), Vector3(x1, h, z), Vector3(xm, h + rise, z), nr, tint, [Vector2(0, 0), Vector2(span / TILE, 0), Vector2(span * 0.5 / TILE, -rise / TILE)])
		for sx in [-1, 1]:
			var xe = x0 - ov if sx < 0 else x1 + ov
			var nr = Vector3(sx * rise, span * 0.5, 0).normalized()
			var a = Vector3(xe, h - ov * rise / (span * 0.5), z0 - ov)
			var b = Vector3(xe, h - ov * rise / (span * 0.5), z1 + ov)
			var c = Vector3(xm, h + rise + 0.04, z1 + ov)
			var d = Vector3(xm, h + rise + 0.04, z0 - ov)
			quad(tb, a, b, c, d, nr, SNOW)
			quad(tb, a, b, c, d, -nr, eave)
	else:
		var zm = (z0 + z1) * 0.5
		for x in [x0, x1]:
			var nr = Vector3(-1, 0, 0) if x == x0 else Vector3(1, 0, 0)
			tri(wb, Vector3(x, h, z0), Vector3(x, h, z1), Vector3(x, h + rise, zm), nr, tint, [Vector2(0, 0), Vector2(span / TILE, 0), Vector2(span * 0.5 / TILE, -rise / TILE)])
		for sz in [-1, 1]:
			var ze = z0 - ov if sz < 0 else z1 + ov
			var nr = Vector3(0, span * 0.5, sz * rise).normalized()
			var a = Vector3(x0 - ov, h - ov * rise / (span * 0.5), ze)
			var b = Vector3(x1 + ov, h - ov * rise / (span * 0.5), ze)
			var c = Vector3(x1 + ov, h + rise + 0.04, zm)
			var d = Vector3(x0 - ov, h + rise + 0.04, zm)
			quad(tb, a, b, c, d, nr, SNOW)
			quad(tb, a, b, c, d, -nr, eave)

func _mod_hvac():
	if mods.has("hvac"): return mods.hvac
	var d = Buf.new()
	var body = Color("#a9adb1")
	boxr(d, Vector3(-0.7, 0, -0.9), Vector3(0.7, 0.95, 0.9), body, 8, SNOW)
	prism(d, Vector3(0, 0.95, 0.35), 0.42, 0.06, 10, Color("#4a4e52"), Color("#2a2d30"))
	for i in range(5):
		boxr(d, Vector3(-0.7 - 0.02, 0.15 + i * 0.15, -0.8), Vector3(-0.7, 0.2 + i * 0.15, 0.8), Color("#7d8185"), 8)
	boxr(d, Vector3(0.7, 0.1, -0.2), Vector3(1.0, 0.35, 0.2), Color("#7d8185"))
	mods.hvac = { "d": d }
	return mods.hvac

func _mod_tank():
	if mods.has("tank"): return mods.tank
	var d = Buf.new()
	var wood = Color("#6a4a34")
	var steel = Color("#2c2a28")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			beam(d, Vector3(sx * 1.25, 0, sz * 1.25), Vector3(sx * 1.05, 3.0, sz * 1.05), 0.09, steel)
	beam(d, Vector3(-1.2, 1.4, -1.2), Vector3(1.2, 1.4, 1.2), 0.04, steel)
	beam(d, Vector3(1.2, 1.4, -1.2), Vector3(-1.2, 1.4, 1.2), 0.04, steel)
	boxr(d, Vector3(-1.4, 2.95, -1.4), Vector3(1.4, 3.1, 1.4), steel, 0, SNOW)
	prism(d, Vector3(0, 3.1, 0), 1.65, 2.7, 12, wood)
	for k in range(3):
		prism(d, Vector3(0, 3.4 + k * 0.85, 0), 1.68, 0.06, 12, steel)
	prism(d, Vector3(0, 5.8, 0), 1.85, 1.1, 12, Color("#3d2c22"), null, 0.0)
	prism(d, Vector3(0, 5.9, 0), 1.55, 0.95, 12, SNOW, null, 0.0)
	beam(d, Vector3(1.65, 3.2, 0), Vector3(1.65, 5.8, 0), 0.03, steel)
	mods.tank = { "d": d }
	return mods.tank

# ---------------------------------------------------------------- fire escapes
func _fire_escape(ch, F, s_mid, wd, floors, fh):
	var t = F.t
	var nr = F.nr
	var basis = Basis(t, UP, nr)
	var base = F.p0 + t * s_mid
	var m = _mod_fe_floor(stepify(wd, 0.1), stepify(fh, 0.05))
	for k in range(floors.size()):
		var last = k == floors.size() - 1
		var xf = Transform(basis, base + UP * (floors[k] - 0.05))
		stamp(ch, m, xf)
		if not last:
			stamp(ch, _mod_fe_stair(stepify(wd, 0.1), stepify(fh, 0.05), k % 2 == 0), xf)
	# the drop ladder under the lowest platform
	stamp(ch, _mod_fe_ladder(stepify(wd, 0.1)), Transform(basis, base + UP * (floors[0] - 0.05)))

func _mod_fe_floor(wd, fh):
	var k = _key(["fe", wd, fh])
	if mods.has(k): return mods[k]
	var d = Buf.new()
	var hw = wd * 0.5
	boxr(d, Vector3(-hw, -0.06, 0), Vector3(hw, 0.0, 1.05), BLACK, SKIP_BACK)
	boxr(d, Vector3(-hw + 0.03, 0.0, 0.03), Vector3(hw - 0.03, 0.04, 1.0), SNOW, SKIP_BACK | 8, SNOW)
	# railing: top and middle rails, balusters
	for y in [0.95, 0.5]:
		boxr(d, Vector3(-hw, y, 1.0), Vector3(hw, y + 0.04, 1.05), BLACK)
		boxr(d, Vector3(-hw, y, 0), Vector3(-hw + 0.04, y + 0.04, 1.05), BLACK)
		boxr(d, Vector3(hw - 0.04, y, 0), Vector3(hw, y + 0.04, 1.05), BLACK)
	var nb = int(wd / 0.42)
	for i in range(nb + 1):
		var x = -hw + wd * i / nb
		boxr(d, Vector3(x - 0.012, 0, 1.015), Vector3(x + 0.012, 0.95, 1.04), BLACK, 12)
	boxr(d, Vector3(-hw, 0.95, 1.0), Vector3(hw, 0.99, 1.05), SNOW, 0, SNOW)
	# braces back to the wall
	for sx in [-1, 1]:
		beam(d, Vector3(sx * (hw - 0.1), -0.06, 0.95), Vector3(sx * (hw - 0.1), -0.75, 0.02), 0.025, BLACK)
	var m = { "d": d }
	mods[k] = m
	return m

func _mod_fe_stair(wd, fh, left):
	var k = _key(["fes", wd, fh, left])
	if mods.has(k): return mods[k]
	var d = Buf.new()
	var hw = wd * 0.5
	var sx = -1.0 if left else 1.0
	var run = min(wd * 0.62, 2.6)
	var a = Vector3(sx * (hw - 0.15), 0.0, 0.0)
	var b = Vector3(sx * (hw - 0.15 - run), fh, 0.0)
	for z in [0.14, 0.62]:
		beam(d, a + Vector3(0, 0, z), b + Vector3(0, 0, z), 0.03, BLACK)
	var n = int(fh / 0.22)
	for i in range(1, n):
		var p = a.linear_interpolate(b, float(i) / n)
		boxr(d, Vector3(p.x - 0.11, p.y - 0.02, 0.14), Vector3(p.x + 0.11, p.y + 0.02, 0.62), BLACK, 0, SNOW)
	beam(d, a + Vector3(0, 0.9, 0.66), b + Vector3(0, 0.9, 0.66), 0.02, BLACK)
	var m = { "d": d }
	mods[k] = m
	return m

func _mod_fe_ladder(wd):
	var k = _key(["fel", wd])
	if mods.has(k): return mods[k]
	var d = Buf.new()
	var x = wd * 0.5 - 0.55
	for sx in [x - 0.22, x + 0.22]:
		boxr(d, Vector3(sx - 0.02, -1.9, 0.9), Vector3(sx + 0.02, 0.9, 0.94), BLACK)
	for i in range(9):
		boxr(d, Vector3(x - 0.22, -1.8 + i * 0.3, 0.9), Vector3(x + 0.22, -1.78 + i * 0.3, 0.93), BLACK, 3)
	var m = { "d": d }
	mods[k] = m
	return m

# ---------------------------------------------------------------- streets
# curbs, crosswalks, hydrants, bins, newspaper boxes, bus shelters, sign posts, bare trees,
# and utility poles strung with wires down the alleys. Things that stand at the curb or by
# the walls, not in the middle of the sidewalk where people walk (8 m from the road's middle).
func _free(x, z, r):
	for o in W.query(x - r, z - r, x + r, z + r):
		if x + r > o.x0 and x - r < o.x1 and z + r > o.z0 and z - r < o.z1: return false
	for l in G.D["LAMPS"]:
		if abs(float(l[0]) - x) < 1.6 and abs(float(l[2]) - z) < 1.6: return false
	for it in G.D["INTERACT"]:
		if Vector2(float(it.x) - x, float(it.z) - z).length() < float(it.r) + 3.0: return false
	for k in keep:
		if k.grow(0.8).has_point(Vector3(x, 0.5, z)): return false
	for ps in G.D["PARK_SPOTS"]:
		if Vector2(float(ps.x) - x, float(ps.z) - z).length() < 3.6: return false
	return true

func _near_cross(v, lines, m):
	for l in lines:
		if abs(v - float(l)) < m: return true
	return false

func _streets(alleys):
	R.seed = 4242
	var XL = G.D["XL"]
	var ZL = G.D["ZL"]
	var H = float(G.D["MAP_HALF"])
	var xe = float(G.D["ROAD_X_END"])
	var hw = float(G.D["ROAD_HW"])
	# curbs: granite edges along every road (looks only: cars and feet go over them)
	for z in ZL:
		for sgn in [-1, 1]:
			_curb_run(Vector3(-H, 0, float(z) + sgn * hw), Vector3(xe, 0, float(z) + sgn * hw), Vector3(0, 0, -sgn), XL, true)
	for x in XL:
		for sgn in [-1, 1]:
			_curb_run(Vector3(float(x) + sgn * hw, 0, -H), Vector3(float(x) + sgn * hw, 0, H), Vector3(-sgn, 0, 0), ZL, false)
	# crosswalks on every side of every crossing
	for x in XL:
		for z in ZL:
			if float(x) > xe + 1 and false: continue
			_crosswalks(float(x), float(z), hw)
	# along each sidewalk: things at the curb and by the walls
	var runs = []
	for z in ZL:
		for sgn in [-1, 1]:
			runs.append({ "a": Vector3(-H + 6, 0, float(z)), "b": Vector3(xe - 6, 0, float(z)), "side": Vector3(0, 0, sgn), "cross": XL })
	for x in XL:
		for sgn in [-1, 1]:
			runs.append({ "a": Vector3(float(x), 0, -H + 6), "b": Vector3(float(x), 0, H - 6), "side": Vector3(sgn, 0, 0), "cross": ZL })
	for rn in runs:
		_sidewalk(rn)
	# utility poles and wires down the alleys
	for al in alleys:
		_alley(float(al[0]), float(al[1]), float(al[2]))

func _curb_run(a, b, inward, cross, along_x):
	var tb = null
	var L = a.distance_to(b)
	var dir = (b - a) / L
	var s = 0.0
	# break at the crossings (the corners round off there)
	var cuts = []
	for c in cross:
		var cv = float(c)
		var sc = (cv - (a.x if along_x else a.z)) * (1.0 if (dir.x if along_x else dir.z) > 0 else -1.0)
		cuts.append(sc)
	cuts.sort()
	var segs = []
	var start = 0.0
	for sc in cuts:
		if sc - 10.0 > start: segs.append([start, sc - 10.0])
		start = max(start, sc + 10.0)
	if start < L: segs.append([start, L])
	for sg in segs:
		var p0 = a + dir * sg[0]
		var p1 = a + dir * sg[1]
		# chunk by chunk so each piece lives with the chunk it's in
		var s0 = sg[0]
		while s0 < sg[1] - 0.01:
			var s1 = min(sg[1], s0 + 24.0)
			var q0 = a + dir * s0
			var q1 = a + dir * s1
			var ch = _chunk((q0.x + q1.x) * 0.5, (q0.z + q1.z) * 0.5)
			tb = _buf(ch.bufs, "t")
			var o = -inward * 0.18
			var top = Color(0.72, 0.73, 0.74)
			quad(tb, q0 + UP * 0.1, q1 + UP * 0.1, q1 + UP * 0.1 + o, q0 + UP * 0.1 + o, UP, top)
			quad(tb, q0 + o + UP * 0.1, q1 + o + UP * 0.1, q1 + o, q0 + o, inward, Color(0.6, 0.61, 0.62))
			s0 = s1

func _crosswalks(x, z, hw):
	var ch = _chunk(x, z)
	var tb = _buf(ch.bufs, "t")
	var paint = Color(0.88, 0.89, 0.9)
	for side in [[Vector3(1, 0, 0), Vector3(0, 0, 1)], [Vector3(-1, 0, 0), Vector3(0, 0, 1)], [Vector3(0, 0, 1), Vector3(1, 0, 0)], [Vector3(0, 0, -1), Vector3(1, 0, 0)]]:
		var out = side[0]
		var across = side[1]
		var c = Vector3(x, 0.03, z) + out * (hw + 2.2)
		# stripes across the road, then a stop line
		var n = 9
		for i in range(n):
			var off = -hw + 0.7 + i * (2.0 * hw - 1.4) / (n - 1)
			var p = c + across * off
			var a = p - across * 0.28 - out * 1.5
			var b = p + across * 0.28 - out * 1.5
			quad(tb, a, b, b + out * 3.0, a + out * 3.0, UP, paint)
		var sl = c + out * 2.3
		quad(tb, sl - across * hw * 0.98, sl + across * 0.0, sl + across * 0.0 + out * 0.4, sl - across * hw * 0.98 + out * 0.4, UP, paint)

func _sidewalk(rn):
	var a = rn.a
	var b = rn.b
	var L = a.distance_to(b)
	var dir = (b - a) / L
	var side = rn.side
	var t_face = -side         # things by the curb face the road
	var s = R.randf_range(4.0, 12.0)
	while s < L:
		var p = a + dir * s
		var along = p.x if abs(dir.x) > 0.5 else p.z
		if _near_cross(along, rn.cross, 13.0):
			s += 3.0
			continue
		var near_corner = _near_cross(along, rn.cross, 22.0)
		var r = R.randf()
		var pc = p + side * 6.65            # at the curb
		var pw = p + side * 9.55            # by the walls
		var basis = Basis(dir.cross(UP) * -1.0 if false else dir, UP, -side)
		basis = Basis(UP.cross(-side), UP, -side)
		if r < 0.2:
			if _free(pc.x, pc.z, 0.5): _place(pc, basis, _mod_hydrant(), Vector3(0.22, 0.75, 0.22), "pole")
		elif r < 0.36:
			if _free(pc.x, pc.z, 0.6): _place(pc, basis, _mod_bin(), Vector3(0.3, 0.95, 0.3), "pole")
		elif r < 0.5 and near_corner:
			var bw = Basis(UP.cross(side), UP, side)
			if _free(pw.x, pw.z, 0.8):
				for k in range(R.randi() % 3 + 1):
					var q = pw + dir * (k * 0.55 - 0.5)
					_place(q, bw, _mod_newsbox(R.randi() % 4), Vector3(0.25, 0.55, 0.22), "pole")
		elif r < 0.6:
			if _free(pc.x, pc.z, 0.5): _place(pc, basis, _mod_sign(R.randi() % 3), Vector3(0.06, 1.5, 0.06), "pole")
		elif r < 0.72:
			if _free(pc.x + side.x * 0.4, pc.z + side.z * 0.4, 0.9): _place(pc + side * 0.4, basis, _mod_tree(R.randi() % 3), Vector3(0.15, 1.5, 0.15), "pole")
		elif r < 0.78 and not near_corner:
			var q = p + side * 7.35
			if _free(q.x, q.z, 1.9): _place(q, basis, _mod_shelter(), Vector3(1.6, 1.25, 0.55), "cover", true)
		elif r < 0.84 and near_corner:
			var bw2 = Basis(UP.cross(side), UP, side)
			if _free(pw.x, pw.z, 0.6): _place(pw, bw2, _mod_mailbox(), Vector3(0.3, 0.65, 0.28), "pole")
		s += R.randf_range(7.0, 16.0)

func _place(p, basis, mod, half, tag, solid_glass = false):
	var ch = _chunk(p.x, p.z)
	stamp(ch, mod, Transform(basis, p))
	var e = Vector3(abs(basis.x.x) * half.x + abs(basis.z.x) * half.z, half.y, abs(basis.x.z) * half.x + abs(basis.z.z) * half.z)
	W.add_box(p.x - e.x, 0, p.z - e.z, p.x + e.x, half.y * 2.0, p.z + e.z, tag)
	info.props += 1

func _alley(x0, x1, z):
	var zp = z - 2.75
	var x = x0 + 4.0
	var prev = null
	while x < x1 - 2:
		if _free(x, zp, 0.4):
			var top = Vector3(x, 8.6, zp)
			_place(Vector3(x, 0, zp), Basis(), _mod_pole(R.randf() < 0.3), Vector3(0.14, 4.4, 0.14), "pole")
			if prev != null:
				var ch = _chunk((x + prev.x) * 0.5, zp)
				var db = _buf(ch.bufs, "d")
				for k in range(3):
					var o = Vector3(0, -k * 0.35, (k - 1) * 0.55)
					_wire(db, prev + o, top + o, 0.35 + k * 0.08)
			prev = top
		x += R.randf_range(24.0, 30.0)

func _wire(b, a, p, sag):
	var n = 6
	var last = a
	for i in range(1, n + 1):
		var t = float(i) / n
		var q = a.linear_interpolate(p, t) - UP * sag * 4.0 * t * (1.0 - t)
		beam(b, last, q, 0.012, Color(0.06, 0.06, 0.07))
		last = q

# ---------------------------------------------------------------- street furniture templates
func _mod_hydrant():
	if mods.has("hyd"): return mods.hyd
	var d = Buf.new()
	var y = Color("#d9b21c")
	var dk = Color("#8a7012")
	prism(d, Vector3(0, 0, 0), 0.17, 0.08, 8, dk, dk)
	prism(d, Vector3(0, 0.08, 0), 0.12, 0.5, 8, y, null, 0.11)
	prism(d, Vector3(0, 0.58, 0), 0.15, 0.05, 8, y, y)
	prism(d, Vector3(0, 0.63, 0), 0.12, 0.12, 8, y, SNOW, 0.04)
	boxr(d, Vector3(-0.22, 0.34, -0.05), Vector3(0.22, 0.44, 0.05), dk)
	boxr(d, Vector3(-0.06, 0.32, 0), Vector3(0.06, 0.46, 0.2), dk)
	mods.hyd = { "d": d }
	return mods.hyd

func _mod_bin():
	if mods.has("bin"): return mods.bin
	var t = Buf.new()
	var g = Color("#24432f")
	prism(t, Vector3(0, 0, 0), 0.29, 0.92, 10, g, null, 0.31)
	prism(t, Vector3(0, 0.92, 0), 0.33, 0.06, 10, g.darkened(0.2), SNOW)
	for k in range(3):
		prism(t, Vector3(0, 0.15 + k * 0.3, 0), 0.3, 0.03, 10, g.lightened(0.12))
	mods.bin = { "t": t }
	return mods.bin

func _mod_newsbox(c):
	var k = "news%d" % c
	if mods.has(k): return mods[k]
	var t = Buf.new()
	var d = Buf.new()
	var col = [Color("#1d4fa8"), Color("#b3121a"), Color("#e8c21a"), Color("#e8e8e4")][c]
	boxr(t, Vector3(-0.23, 0.32, -0.2), Vector3(0.23, 1.02, 0.2), col, 0, SNOW)
	for sx in [-0.2, 0.2]:
		boxr(d, Vector3(sx - 0.02, 0, -0.15), Vector3(sx + 0.02, 0.32, 0.15), Color("#2a2d30"))
	boxr(d, Vector3(-0.17, 0.6, 0.2), Vector3(0.17, 0.92, 0.215), Color("#c9d6e2"))
	mods[k] = { "t": t, "d": d }
	return mods[k]

func _mod_mailbox():
	if mods.has("mail"): return mods.mail
	var t = Buf.new()
	var b = Color("#1d3a6e")
	for sx in [-0.22, 0.22]:
		for sz in [-0.2, 0.2]:
			boxr(t, Vector3(sx - 0.03, 0, sz - 0.03), Vector3(sx + 0.03, 0.25, sz + 0.03), b.darkened(0.3))
	boxr(t, Vector3(-0.27, 0.25, -0.25), Vector3(0.27, 1.05, 0.25), b)
	prism(t, Vector3(0, 1.05, 0), 0.27, 0.12, 8, b, SNOW, 0.2)
	boxr(t, Vector3(-0.18, 0.85, 0.25), Vector3(0.18, 0.92, 0.27), Color("#c9ccd0"))
	mods.mail = { "t": t }
	return mods.mail

func _mod_sign(kind):
	var k = "sign%d" % kind
	if mods.has(k): return mods[k]
	var d = Buf.new()
	var s = Buf.new()
	var pole = Color("#6b7075")
	boxr(d, Vector3(-0.03, 0, -0.03), Vector3(0.03, 2.7, 0.03), pole)
	# atlas cells (right half of signs.png): bus, no parking, one way
	var cells = [[Vector2(0.625, 0), Vector2(0.75, 0.125), 0.6, 0.6], [Vector2(0.75, 0), Vector2(0.875, 0.125), 0.5, 0.5], [Vector2(0.875, 0.03), Vector2(1.0, 0.093), 0.8, 0.4]]
	var cl = cells[kind]
	var w = cl[2]
	var hh = cl[3]
	var y0 = 2.65 - hh
	var a = Vector3(-w * 0.5, y0, 0.04)
	var b = Vector3(w * 0.5, y0, 0.04)
	quad(s, a, b, b + UP * hh, a + UP * hh, Vector3(0, 0, 1), Color(1, 1, 1), [Vector2(cl[0].x, cl[1].y), Vector2(cl[1].x, cl[1].y), Vector2(cl[1].x, cl[0].y), Vector2(cl[0].x, cl[0].y)])
	boxr(d, Vector3(-w * 0.5, y0, -0.0), Vector3(w * 0.5, y0 + hh, 0.035), Color("#9a9ea2"), 0, SNOW)
	mods[k] = { "d": d, "s": s }
	return mods[k]

func _mod_tree(v):
	var k = "tree%d" % v
	if mods.has(k): return mods[k]
	var d = Buf.new()
	var t = Buf.new()
	var bark = Color("#3b3029")
	var rng = RandomNumberGenerator.new()
	rng.seed = 77 + v * 13
	# the grate and its curb
	boxr(t, Vector3(-0.75, 0.0, -0.75), Vector3(0.75, 0.05, 0.75), Color("#2a2c2e"))
	boxr(t, Vector3(-0.8, 0.0, -0.8), Vector3(0.8, 0.09, -0.72), Color("#9a9a96"))
	boxr(t, Vector3(-0.8, 0.0, 0.72), Vector3(0.8, 0.09, 0.8), Color("#9a9a96"))
	# trunk, limbs, twigs: a winter tree, snow along the tops of the big limbs
	prism(t, Vector3(), 0.16, 2.4, 6, bark, null, 0.11)
	var limbs = 4 + v
	for i in range(limbs):
		var ang = TAU * i / limbs + rng.randf_range(-0.3, 0.3)
		var y = rng.randf_range(2.0, 2.5)
		var a = Vector3(0, y, 0)
		var dir = Vector3(cos(ang) * 0.6, 1.0, sin(ang) * 0.6).normalized()
		var ln = rng.randf_range(1.6, 2.6)
		var b = a + dir * ln
		beam(t, a, b, 0.06, bark)
		beam(d, a + UP * 0.05, b + UP * 0.05, 0.035, SNOW)
		for j in range(2):
			var m = a.linear_interpolate(b, rng.randf_range(0.45, 0.9))
			var d2 = (dir + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.1, 0.6), rng.randf_range(-0.8, 0.8))).normalized()
			var e = m + d2 * rng.randf_range(0.7, 1.3)
			beam(d, m, e, 0.025, bark)
			beam(d, e, e + (d2 + Vector3(rng.randf_range(-0.5, 0.5), 0.4, rng.randf_range(-0.5, 0.5))).normalized() * 0.5, 0.014, bark)
	beam(t, Vector3(0, 2.3, 0), Vector3(0.05, 3.6, 0.04), 0.08, bark)
	mods[k] = { "d": d, "t": t }
	return mods[k]

func _mod_shelter():
	if mods.has("shelter"): return mods.shelter
	var t = Buf.new()
	var d = Buf.new()
	var g = Buf.new()
	var steel = Color("#2e3338")
	var w = 1.6
	for sx in [-w, w]:
		for sz in [-0.55, 0.55]:
			boxr(t, Vector3(sx - 0.04, 0, sz - 0.04), Vector3(sx + 0.04, 2.4, sz + 0.04), steel)
	boxr(t, Vector3(-w - 0.15, 2.4, -0.75), Vector3(w + 0.15, 2.5, 0.75), steel, 0, SNOW)
	# glass back and ends (seen through: the city's glass at a low tint)
	var gc = Color(0.55, 0.62, 0.7, 0.0)
	quad(g, Vector3(-w, 0.15, -0.55), Vector3(w, 0.15, -0.55), Vector3(w, 2.3, -0.55), Vector3(-w, 2.3, -0.55), Vector3(0, 0, 1), gc, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)], Vector2(0, 0.3))
	quad(g, Vector3(-w, 0.15, -0.55), Vector3(w, 0.15, -0.55), Vector3(w, 2.3, -0.55), Vector3(-w, 2.3, -0.55), Vector3(0, 0, -1), gc, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)], Vector2(0, 0.6))
	for sx in [-w, w]:
		quad(g, Vector3(sx, 0.15, -0.55), Vector3(sx, 0.15, 0.3), Vector3(sx, 2.3, 0.3), Vector3(sx, 2.3, -0.55), Vector3(sign(sx), 0, 0), gc, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)], Vector2(0, 0.2))
		quad(g, Vector3(sx, 0.15, -0.55), Vector3(sx, 0.15, 0.3), Vector3(sx, 2.3, 0.3), Vector3(sx, 2.3, -0.55), Vector3(-sign(sx), 0, 0), gc, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)], Vector2(0, 0.8))
	# the bench and an ad panel lit from inside
	boxr(d, Vector3(-1.1, 0.45, -0.5), Vector3(1.1, 0.5, -0.15), Color("#5a5f66"))
	for sx in [-0.9, 0.9]:
		boxr(d, Vector3(sx - 0.03, 0, -0.35), Vector3(sx + 0.03, 0.45, -0.3), steel)
	boxr(t, Vector3(w - 0.05, 0.3, -0.5), Vector3(w + 0.05, 2.1, 0.25), Color("#e9e4d8"))
	mods.shelter = { "t": t, "d": d, "g": g }
	return mods.shelter

func _mod_pole(transformer):
	var k = "pole%s" % str(transformer)
	if mods.has(k): return mods[k]
	var t = Buf.new()
	var d = Buf.new()
	var wood = Color("#4a3a2c")
	prism(t, Vector3(), 0.15, 9.0, 6, wood, Color("#2a2420"), 0.11)
	boxr(t, Vector3(-0.08, 8.5, -1.0), Vector3(0.08, 8.68, 1.0), wood)
	for z in [-0.85, -0.3, 0.3, 0.85]:
		prism(d, Vector3(0, 8.68, z), 0.04, 0.12, 6, Color("#cfd6da"))
	if transformer:
		prism(t, Vector3(0.36, 6.6, 0), 0.26, 0.9, 8, Color("#7d8288"), SNOW)
		boxr(d, Vector3(0.1, 7.0, -0.05), Vector3(0.2, 7.1, 0.05), Color("#2a2d30"))
	boxr(d, Vector3(-0.1, 2.6, -0.1), Vector3(0.1, 3.1, 0.1), Color("#c9c4b0"))
	mods[k] = { "t": t, "d": d }
	return mods[k]
