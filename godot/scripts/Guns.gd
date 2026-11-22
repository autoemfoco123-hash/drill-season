extends Node
# Guns (autoload "GUN"): stats with workbench parts, and the models built from boxes and
# cylinders exactly like the web game's buildGun, so optics, barrels, mags, muzzle devices,
# finishes and charms all show up. Origin at the grip, barrel toward +Z, up +Y.

var _mats = {}
var _prims = {}
var _cache = {}

func part_of(cat, id):
	for p in G.D["PARTS"][cat]:
		if p.id == id: return p
	return G.D["PARTS"][cat][0]

func def_cfg():
	return G.D["DEF_CFG"].duplicate()

func cfg_of(id):
	var g = G.S.get("guns", {}).get(id)
	if g == null or typeof(g.get("cfg")) != TYPE_DICTIONARY:
		return def_cfg()
	var c = def_cfg()
	for k in g.cfg.keys(): c[k] = g.cfg[k]
	return c

# the gun's numbers with its parts on (same rules as the web game's gunStats)
func stats(id, cfg = null):
	var W = G.D["WEAPONS"][id]
	if cfg == null: cfg = cfg_of(id)
	var s = W.duplicate(true)
	for cat in ["optic", "barrel", "mag", "muzzle"]:
		var p = part_of(cat, cfg.get(cat, ""))
		if p.has("mods"):
			for k in p.mods.keys():
				if k == "zoom": s.zoom = float(s.zoom) + float(p.mods[k])
				else: s[k] = float(s[k]) * float(p.mods[k])
	s.mag = int(round(float(s.mag)))
	s.heatPerShot = float(s.noise) * 0.45
	return s

func _mat(name):
	if _mats.has(name): return _mats[name]
	var m = SpatialMaterial.new()
	var spec = {
		"poly": [0x1b1e23, 0.15, 0.72], "dark": [0x0d0e10, 0.7, 0.45], "white": [0xf2f2ee, 0.0, 0.4], "silver": [0xc8ccd2, 1.0, 0.25],
		"gold": [0xd9a93a, 1.0, 0.2], "ice": [0xbfe6ff, 0.1, 0.05], "brown": [0x6a4424, 0.0, 0.7] }
	if name == "glass":
		m.albedo_color = Color(0.4, 0.78, 1.0, 0.35); m.flags_transparent = true; m.roughness = 0.05
	elif name == "dot":
		m.albedo_color = Color(1, 0.19, 0.12); m.flags_unshaded = true
	elif name.begins_with("fin:"):
		var F = part_of("finish", name.substr(4))
		m.albedo_color = G.hex_color(F.c); m.roughness = float(F.r); m.metallic = float(F.m) * 0.6; m.metallic_specular = 0.6
		if F.has("e"):
			m.emission_enabled = true; m.emission = G.hex_color(F.e)
	else:
		var sp = spec[name]
		m.albedo_color = G.hex_color(sp[0]); m.metallic = sp[1] * 0.6; m.roughness = sp[2]
	_mats[name] = m
	return m

func _prim(kind):
	if _prims.has(kind): return _prims[kind]
	var m
	if kind == "box":
		m = CubeMesh.new(); m.size = Vector3.ONE
	elif kind == "cyl":
		m = CylinderMesh.new(); m.top_radius = 1; m.bottom_radius = 1; m.height = 1; m.radial_segments = 10; m.rings = 1
	elif kind == "cone":
		m = CylinderMesh.new(); m.top_radius = 0; m.bottom_radius = 1; m.height = 1; m.radial_segments = 8; m.rings = 1
	elif kind == "ring":
		m = CylinderMesh.new(); m.top_radius = 1.1; m.bottom_radius = 1.1; m.height = 0.5; m.radial_segments = 10; m.rings = 1
	else:
		m = SphereMesh.new(); m.radius = 1; m.height = 2; m.radial_segments = 10; m.rings = 6
	var a = m.get_mesh_arrays()
	_prims[kind] = [a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_NORMAL], a[Mesh.ARRAY_INDEX]]
	return _prims[kind]

class Builder:
	var parts = {}   # material name -> {v, n, i}
	func add(owner, kind, mat, xf):
		var pr = owner._prim(kind)
		if not parts.has(mat): parts[mat] = { "v": [], "n": [], "i": [] }
		var g = parts[mat]
		var base = g.v.size()
		var nb = xf.basis.inverse().transposed()
		for k in range(pr[0].size()):
			g.v.append(xf.xform(pr[0][k]))
			g.n.append(nb.xform(pr[1][k]).normalized())
		for idx in pr[2]: g.i.append(base + idx)
	func mesh(owner):
		var am = ArrayMesh.new()
		for mat in parts.keys():
			var g = parts[mat]
			var arr = []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = PoolVector3Array(g.v)
			arr[Mesh.ARRAY_NORMAL] = PoolVector3Array(g.n)
			arr[Mesh.ARRAY_INDEX] = PoolIntArray(g.i)
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(am.get_surface_count() - 1, owner._mat(mat))
		return am

func _box(B, w, h, d, x, y, z, m, rx = 0.0):
	B.add(self, "box", m, Transform(Basis(Vector3(1, 0, 0), rx) * Basis().scaled(Vector3(w, h, d)), Vector3(x, y, z)))

func _cyl(B, r, length, x, y, z, m):
	B.add(self, "cyl", m, Transform(Basis(Vector3(1, 0, 0), PI / 2) * Basis().scaled(Vector3(r, length, r)), Vector3(x, y, z + length / 2)))

# a Spatial with the gun mesh; get_node("Muzzle") is the barrel tip, get_node("Charm") swings
func build(id, cfg = null):
	if cfg == null: cfg = cfg_of(id)
	var key = id + JSON.print(cfg)
	var out = Spatial.new()
	var info
	if _cache.has(key):
		info = _cache[key]
	else:
		info = _make(id, cfg)
		_cache[key] = info
	var mi = MeshInstance.new(); mi.mesh = info.mesh; mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	out.add_child(mi)
	var mz = Position3D.new(); mz.name = "Muzzle"; mz.translation = info.muzzle; out.add_child(mz)
	if info.charm:
		var ch = Spatial.new(); ch.name = "Charm"; ch.translation = info.charm_at
		var cm = MeshInstance.new(); cm.mesh = info.charm; ch.add_child(cm)
		out.add_child(ch)
	G.toon_tree(out, true)
	return out

func _make(id, cfg):
	var B = Builder.new()
	var fin = "fin:" + str(cfg.get("finish", "gunmetal"))
	var bl = cfg.get("barrel", "standard")
	var tipZ = 0.0
	var boreY = 0.0
	var railY = 0.0
	var railZ = 0.0
	var charmAt = Vector3()
	if id == "k9":
		_box(B, 0.032, 0.11, 0.048, 0, -0.012, -0.018, "poly", 0.22)
		_box(B, 0.03, 0.03, 0.17, 0, 0.05, 0.04, "poly")
		_box(B, 0.035, 0.032, 0.19, 0, 0.079, 0.04, fin)
		for i in range(4): _box(B, 0.036, 0.022, 0.004, 0, 0.08, -0.035 + i * 0.008, "dark")
		_box(B, 0.006, 0.006, 0.05, 0, 0.022, 0.055, "poly"); _box(B, 0.006, 0.03, 0.006, 0, 0.034, 0.078, "poly")
		var ext = 0.0 if bl == "short" else (0.055 if bl == "long" else 0.016)
		tipZ = 0.135 + ext; boreY = 0.075; railY = 0.096; railZ = 0.0
		if ext > 0: _cyl(B, 0.008, ext, 0, boreY, 0.135, "dark")
		if cfg.get("mag") == "ext": _box(B, 0.03, 0.04, 0.042, 0, -0.085, -0.032, "poly", 0.22)
		charmAt = Vector3(0, -0.07, -0.05)
	elif id == "draft":
		_box(B, 0.046, 0.065, 0.3, 0, 0.06, 0.05, fin)
		_box(B, 0.02, 0.008, 0.22, 0, 0.096, 0.05, "dark")
		_box(B, 0.032, 0.1, 0.045, 0, -0.01, -0.01, "poly", 0.25)
		var ext_mag = cfg.get("mag") == "ext"
		_box(B, 0.03, 0.22 if ext_mag else 0.15, 0.044, 0, -0.07 if ext_mag else -0.035, 0.11, "poly", 0.12)
		var ln = 0.03 if bl == "short" else (0.13 if bl == "long" else 0.07)
		_cyl(B, 0.019, 0.08, 0, 0.06, 0.2, "dark")
		_cyl(B, 0.009, ln, 0, 0.06, 0.28, "dark")
		tipZ = 0.28 + ln; boreY = 0.06; railY = 0.104; railZ = 0.03
		_box(B, 0.024, 0.07, 0.026, 0, 0.0, 0.23, "poly")
		_box(B, 0.008, 0.01, 0.22, 0.014, 0.065, -0.2, "dark"); _box(B, 0.008, 0.01, 0.22, -0.014, 0.065, -0.2, "dark")
		_box(B, 0.034, 0.095, 0.016, 0, 0.045, -0.31, "poly")
		charmAt = Vector3(0, 0.03, -0.12)
	else:
		_box(B, 0.05, 0.072, 0.24, 0, 0.05, 0.07, fin)
		_box(B, 0.032, 0.1, 0.045, 0, -0.01, -0.01, "poly", 0.32)
		_box(B, 0.044, 0.095, 0.3, 0, 0.03, -0.19, "poly", -0.06)
		var ln2 = 0.36 if bl == "short" else (0.66 if bl == "long" else 0.5)
		_cyl(B, 0.012, ln2, 0, 0.07, 0.19, fin)
		var tl = min(ln2 - 0.04, 0.5 if cfg.get("mag") == "ext" else 0.36)
		_cyl(B, 0.012, tl, 0, 0.038, 0.19, "dark")
		_cyl(B, 0.022, 0.15, 0, 0.038, 0.24, "poly")
		_box(B, 0.006, 0.01, 0.006, 0, 0.087, 0.18 + ln2, "white")
		tipZ = 0.19 + ln2; boreY = 0.07; railY = 0.09; railZ = 0.06
		charmAt = Vector3(0, -0.01, -0.07)
	var opt = cfg.get("optic", "iron")
	if opt == "iron":
		_box(B, 0.014, 0.012, 0.006, 0, railY + 0.004, railZ - 0.05, "dark")
		_box(B, 0.004, 0.012, 0.004, 0, railY + 0.004, tipZ - 0.02, "dark")
	elif opt == "reflex":
		_box(B, 0.022, 0.01, 0.034, 0, railY + 0.005, railZ, "dark")
		_box(B, 0.03, 0.004, 0.004, 0, railY + 0.036, railZ + 0.012, "dark")
		_box(B, 0.004, 0.03, 0.004, 0.014, railY + 0.022, railZ + 0.012, "dark"); _box(B, 0.004, 0.03, 0.004, -0.014, railY + 0.022, railZ + 0.012, "dark")
		_box(B, 0.026, 0.026, 0.002, 0, railY + 0.022, railZ + 0.012, "glass")
		_box(B, 0.003, 0.003, 0.003, 0, railY + 0.022, railZ + 0.014, "dot")
	else:
		_box(B, 0.04, 0.008, 0.06, 0, railY + 0.004, railZ, "dark")
		_box(B, 0.004, 0.034, 0.06, 0.018, railY + 0.025, railZ, "dark"); _box(B, 0.004, 0.034, 0.06, -0.018, railY + 0.025, railZ, "dark")
		_box(B, 0.04, 0.005, 0.06, 0, railY + 0.044, railZ, "dark")
		_box(B, 0.032, 0.03, 0.002, 0, railY + 0.025, railZ + 0.03, "glass")
		_box(B, 0.004, 0.004, 0.003, 0, railY + 0.025, railZ + 0.031, "dot")
	var mz = cfg.get("muzzle", "none")
	if mz == "comp":
		_cyl(B, 0.017 if id == "plow" else 0.012, 0.03, 0, boreY, tipZ, "dark"); _box(B, 0.03, 0.004, 0.012, 0, boreY + 0.012, tipZ + 0.015, "poly"); tipZ += 0.03
	elif mz == "supp":
		var Ls = 0.2 if id == "plow" else 0.14
		_cyl(B, 0.022 if id == "plow" else 0.017, Ls, 0, boreY, tipZ, "dark"); tipZ += Ls
	var charm_mesh = null
	var charm_at = Vector3()
	var ch = cfg.get("charm", "none")
	if ch != "none":
		B.add(self, "ring", "silver", Transform(Basis().scaled(Vector3.ONE * 0.006), charmAt + Vector3(0.02, 0, 0)))
		charm_at = charmAt + Vector3(0.02, -0.03, 0)
		var C = Builder.new()
		if ch == "dice": _box(C, 0.016, 0.016, 0.016, 0, 0, 0, "white")
		elif ch == "flake":
			for i in range(3): C.add(self, "box", "ice", Transform(Basis(Vector3(0, 0, 1), i * PI / 3) * Basis().scaled(Vector3(0.032, 0.004, 0.004)), Vector3()))
		elif ch == "mic":
			C.add(self, "cyl", "dark", Transform(Basis().scaled(Vector3(0.005, 0.03, 0.005)), Vector3(0, -0.005, 0)))
			C.add(self, "sphere", "silver", Transform(Basis().scaled(Vector3.ONE * 0.009), Vector3(0, 0.014, 0)))
		elif ch == "feather":
			C.add(self, "cone", "brown", Transform(Basis(Vector3(0, 0, 1), PI) * Basis().scaled(Vector3(0.007, 0.045, 0.002)), Vector3(0, -0.01, 0)))
		elif ch == "crown":
			C.add(self, "cyl", "gold", Transform(Basis().scaled(Vector3(0.012, 0.01, 0.012)), Vector3()))
			for i in range(5):
				var a = i / 5.0 * TAU
				C.add(self, "cone", "gold", Transform(Basis().scaled(Vector3(0.003, 0.01, 0.003)), Vector3(cos(a) * 0.011, 0.009, sin(a) * 0.011)))
		charm_mesh = C.mesh(self)
	return { "mesh": B.mesh(self), "muzzle": Vector3(0, boreY, tipZ), "charm": charm_mesh, "charm_at": charm_at }
